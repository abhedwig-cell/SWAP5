from __future__ import annotations

from dataclasses import dataclass
from enum import IntEnum
import math
from typing import Any, Protocol, Sequence

from modflow6_prepared_solve_session import (
    Modflow6PreparedSolveSession,
    PreparedSolveIteration,
    PreparedSolveStatus,
)


class GroundwaterApplicationServiceStatus(IntEnum):
    OK = 0
    INVALID_CONFIG = 1
    INVALID_PLAN = 2
    ORIGIN_FAILED = 3
    GROUNDWATER_OPEN_FAILED = 4
    GROUNDWATER_ITERATION_FAILED = 5
    SWAP_TRIAL_FAILED = 6
    RUNTIME_EVALUATION_FAILED = 7
    NOT_CONVERGED = 8
    GROUNDWATER_FINALIZE_FAILED = 9
    SWAP_PREFLIGHT_FAILED = 10
    LEDGER_PREPARE_FAILED = 11
    LEDGER_PREFLIGHT_FAILED = 12
    MODFLOW_PREFLIGHT_FAILED = 13
    PREPUBLICATION_ABORT_FAILED = 14


class GroundwaterApplicationPublicationInvariantError(RuntimeError):
    """Failure at/after the first irreversible multi-participant publication."""


@dataclass(frozen=True)
class GroundwaterApplicationServiceConfig:
    flux_tolerance_m_per_s: float
    max_coupling_iterations: int

    def valid(self) -> bool:
        return (
            math.isfinite(self.flux_tolerance_m_per_s)
            and self.flux_tolerance_m_per_s > 0.0
            and self.max_coupling_iterations > 0
        )


@dataclass(frozen=True)
class GroundwaterApplicationPlanView:
    bindings: tuple[Any, ...]
    terms: tuple[Any, ...]
    cell_ids: tuple[int, ...]

    def valid(self) -> bool:
        n = len(self.bindings)
        if n <= 0 or len(self.terms) != n or len(self.cell_ids) != n:
            return False
        if len(set(self.cell_ids)) != n:
            return False
        seen_slots: set[int] = set()
        seen_nodes: set[int] = set()
        for index, (binding, term, cell_id) in enumerate(
            zip(self.bindings, self.terms, self.cell_ids, strict=True), start=1
        ):
            try:
                binding_cell = int(binding.groundwater_cell_id)
                term_cell = int(term.groundwater_cell_id)
                package_slot = int(binding.package_slot)
                node_id = int(binding.modflow_node_id)
                hcof = float(term.hcof_m2_per_day)
                rhs = float(term.rhs_m3_per_day)
            except Exception:
                return False
            if binding_cell != cell_id or term_cell != cell_id or cell_id <= 0:
                return False
            if package_slot != index or package_slot in seen_slots:
                return False
            if node_id <= 0 or node_id in seen_nodes:
                return False
            if not math.isfinite(hcof) or not math.isfinite(rhs):
                return False
            if hasattr(term, "valid") and not bool(term.valid):
                return False
            seen_slots.add(package_slot)
            seen_nodes.add(node_id)
        return True


@dataclass(frozen=True)
class GroundwaterApplicationCorrectorBatch:
    valid: bool
    cell_q_swap_m_per_s: tuple[float, ...]
    cell_dq_swap_dh_per_s: tuple[float, ...] = ()


@dataclass
class GroundwaterApplicationServiceResult:
    status: GroundwaterApplicationServiceStatus = (
        GroundwaterApplicationServiceStatus.INVALID_CONFIG
    )
    published: bool = False
    request_smaller_window: bool = False
    iterations: int = 0
    final_heads_m: tuple[float, ...] = ()
    final_residuals_m_per_s: tuple[float, ...] = ()
    failure_stage: str = "none"


class GroundwaterApplicationRuntime(Protocol):
    """SWAP-side application port.

    F-GC49A/F-GC49B are the production authorities intended to back this port.
    This Python service never owns committed SWAP state, predictor/corrector
    physics, cell aggregation, linear-response mathematics, or ledgers.
    """

    def materialize_plan(self) -> GroundwaterApplicationPlanView: ...

    def capture_origins(self) -> bool: ...

    def evaluate_groundwater_fluxes(
        self, terms: Sequence[Any], cell_heads_m: Sequence[float]
    ) -> Sequence[float]: ...

    def trial_cell_heads(
        self, cell_heads_m: Sequence[float]
    ) -> GroundwaterApplicationCorrectorBatch: ...

    def discard_candidates(self) -> bool: ...

    def relinearize_terms(
        self,
        cell_heads_m: Sequence[float],
        cell_q_swap_m_per_s: Sequence[float],
        cell_dq_swap_dh_per_s: Sequence[float],
    ) -> Sequence[Any]: ...

    def swap_preflight(self) -> bool: ...

    def prepare_ledgers(self) -> bool: ...

    def ledgers_preflight(self) -> bool: ...

    def abort_prepublication(self) -> bool: ...

    def commit_swaps(self) -> bool: ...

    def commit_ledgers(self) -> bool: ...


def run_groundwater_application_window(
    runtime: GroundwaterApplicationRuntime,
    groundwater: Modflow6PreparedSolveSession,
    config: GroundwaterApplicationServiceConfig,
) -> GroundwaterApplicationServiceResult:
    result = GroundwaterApplicationServiceResult()

    if not config.valid():
        return result

    try:
        plan = runtime.materialize_plan()
    except Exception:
        return _fail(
            result,
            GroundwaterApplicationServiceStatus.INVALID_PLAN,
            False,
            "application-plan",
        )
    if not isinstance(plan, GroundwaterApplicationPlanView) or not plan.valid():
        return _fail(
            result,
            GroundwaterApplicationServiceStatus.INVALID_PLAN,
            False,
            "application-plan",
        )

    try:
        origins_captured = bool(runtime.capture_origins())
    except Exception:
        origins_captured = False
    if not origins_captured:
        return _abort_and_fail(
            runtime,
            groundwater,
            result,
            GroundwaterApplicationServiceStatus.ORIGIN_FAILED,
            True,
            "swap-origin",
        )

    if groundwater.acquire_after_prepare_time_step() != PreparedSolveStatus.OK:
        return _abort_and_fail(
            runtime,
            groundwater,
            result,
            GroundwaterApplicationServiceStatus.GROUNDWATER_OPEN_FAILED,
            True,
            "groundwater-acquire",
        )
    if groundwater.open_prepared_solve() != PreparedSolveStatus.OK:
        return _abort_and_fail(
            runtime,
            groundwater,
            result,
            GroundwaterApplicationServiceStatus.GROUNDWATER_OPEN_FAILED,
            True,
            "groundwater-prepare-solve",
        )

    current_terms: tuple[Any, ...] = tuple(plan.terms)
    ncell = len(plan.cell_ids)

    for iteration_index in range(1, config.max_coupling_iterations + 1):
        result.iterations = iteration_index

        solve_status, iterate = groundwater.publish_and_solve_iteration(
            plan.bindings, current_terms
        )
        if solve_status != PreparedSolveStatus.OK or not isinstance(
            iterate, PreparedSolveIteration
        ):
            return _abort_and_fail(
                runtime,
                groundwater,
                result,
                GroundwaterApplicationServiceStatus.GROUNDWATER_ITERATION_FAILED,
                True,
                "groundwater-solve",
            )

        try:
            heads = _extract_cell_heads(iterate, plan.bindings)
        except Exception:
            return _abort_and_fail(
                runtime,
                groundwater,
                result,
                GroundwaterApplicationServiceStatus.GROUNDWATER_ITERATION_FAILED,
                True,
                "groundwater-head-routing",
            )

        try:
            q_groundwater = tuple(
                float(value)
                for value in runtime.evaluate_groundwater_fluxes(
                    current_terms, heads
                )
            )
        except Exception:
            return _abort_and_fail(
                runtime,
                groundwater,
                result,
                GroundwaterApplicationServiceStatus.RUNTIME_EVALUATION_FAILED,
                True,
                "groundwater-flux-evaluation",
            )
        if not _finite_vector(q_groundwater, ncell):
            return _abort_and_fail(
                runtime,
                groundwater,
                result,
                GroundwaterApplicationServiceStatus.RUNTIME_EVALUATION_FAILED,
                True,
                "groundwater-flux-evaluation",
            )

        try:
            corrector = runtime.trial_cell_heads(heads)
        except Exception:
            return _abort_and_fail(
                runtime,
                groundwater,
                result,
                GroundwaterApplicationServiceStatus.SWAP_TRIAL_FAILED,
                True,
                "swap-corrector",
            )
        if (
            not isinstance(corrector, GroundwaterApplicationCorrectorBatch)
            or not corrector.valid
            or not _finite_vector(corrector.cell_q_swap_m_per_s, ncell)
        ):
            return _abort_and_fail(
                runtime,
                groundwater,
                result,
                GroundwaterApplicationServiceStatus.SWAP_TRIAL_FAILED,
                True,
                "swap-corrector",
            )

        residuals = tuple(
            q_swap - q_gw
            for q_swap, q_gw in zip(
                corrector.cell_q_swap_m_per_s, q_groundwater, strict=True
            )
        )
        if not _finite_vector(residuals, ncell):
            return _abort_and_fail(
                runtime,
                groundwater,
                result,
                GroundwaterApplicationServiceStatus.RUNTIME_EVALUATION_FAILED,
                True,
                "cell-residual",
            )

        result.final_heads_m = heads
        result.final_residuals_m_per_s = residuals

        cell_flux_converged = all(
            abs(value) <= config.flux_tolerance_m_per_s for value in residuals
        )
        coupled_converged = bool(iterate.modflow_converged) and cell_flux_converged

        if coupled_converged:
            if (
                groundwater.finalize_prepared_solve()
                != PreparedSolveStatus.OK
            ):
                return _abort_and_fail(
                    runtime,
                    groundwater,
                    result,
                    GroundwaterApplicationServiceStatus.GROUNDWATER_FINALIZE_FAILED,
                    True,
                    "groundwater-finalize-solve",
                )
            return _publish_converged_window(runtime, groundwater, result)

        if not _finite_vector(corrector.cell_dq_swap_dh_per_s, ncell):
            return _abort_and_fail(
                runtime,
                groundwater,
                result,
                GroundwaterApplicationServiceStatus.RUNTIME_EVALUATION_FAILED,
                True,
                "swap-response-tangent",
            )

        try:
            discarded = bool(runtime.discard_candidates())
        except Exception:
            discarded = False
        if not discarded:
            return _abort_and_fail(
                runtime,
                groundwater,
                result,
                GroundwaterApplicationServiceStatus.PREPUBLICATION_ABORT_FAILED,
                True,
                "swap-discard",
            )

        try:
            next_terms = tuple(
                runtime.relinearize_terms(
                    heads,
                    corrector.cell_q_swap_m_per_s,
                    corrector.cell_dq_swap_dh_per_s,
                )
            )
        except Exception:
            return _abort_and_fail(
                runtime,
                groundwater,
                result,
                GroundwaterApplicationServiceStatus.RUNTIME_EVALUATION_FAILED,
                True,
                "term-relinearize",
            )
        if len(next_terms) != ncell:
            return _abort_and_fail(
                runtime,
                groundwater,
                result,
                GroundwaterApplicationServiceStatus.RUNTIME_EVALUATION_FAILED,
                True,
                "term-reanchor",
            )
        current_terms = next_terms

    return _abort_and_fail(
        runtime,
        groundwater,
        result,
        GroundwaterApplicationServiceStatus.NOT_CONVERGED,
        True,
        "max-coupling-iterations",
    )


def _publish_converged_window(
    runtime: GroundwaterApplicationRuntime,
    groundwater: Modflow6PreparedSolveSession,
    result: GroundwaterApplicationServiceResult,
) -> GroundwaterApplicationServiceResult:
    try:
        swap_ready = bool(runtime.swap_preflight())
    except Exception:
        swap_ready = False
    if not swap_ready:
        return _abort_and_fail(
            runtime,
            groundwater,
            result,
            GroundwaterApplicationServiceStatus.SWAP_PREFLIGHT_FAILED,
            True,
            "swap-preflight",
        )

    try:
        ledger_prepared = bool(runtime.prepare_ledgers())
    except Exception:
        ledger_prepared = False
    if not ledger_prepared:
        return _abort_and_fail(
            runtime,
            groundwater,
            result,
            GroundwaterApplicationServiceStatus.LEDGER_PREPARE_FAILED,
            True,
            "ledger-prepare",
        )

    try:
        ledgers_ready = bool(runtime.ledgers_preflight())
    except Exception:
        ledgers_ready = False
    if not ledgers_ready:
        return _abort_and_fail(
            runtime,
            groundwater,
            result,
            GroundwaterApplicationServiceStatus.LEDGER_PREFLIGHT_FAILED,
            True,
            "ledger-preflight",
        )

    if not groundwater.timestep_ready_for_finalize():
        return _abort_and_fail(
            runtime,
            groundwater,
            result,
            GroundwaterApplicationServiceStatus.MODFLOW_PREFLIGHT_FAILED,
            True,
            "modflow-timestep-preflight",
        )

    timestep_status = groundwater.finalize_time_step_once()
    if timestep_status != PreparedSolveStatus.OK:
        raise GroundwaterApplicationPublicationInvariantError(
            "MODFLOW finalize_time_step failed at the irreversible publication point: "
            f"{timestep_status.name}"
        )

    try:
        swap_committed = bool(runtime.commit_swaps())
    except Exception as exc:
        raise GroundwaterApplicationPublicationInvariantError(
            "SWAP publication failed after MODFLOW timestep publication"
        ) from exc
    if not swap_committed:
        raise GroundwaterApplicationPublicationInvariantError(
            "SWAP publication rejected after MODFLOW timestep publication"
        )

    try:
        ledgers_committed = bool(runtime.commit_ledgers())
    except Exception as exc:
        raise GroundwaterApplicationPublicationInvariantError(
            "ledger publication failed after MODFLOW/SWAP publication"
        ) from exc
    if not ledgers_committed:
        raise GroundwaterApplicationPublicationInvariantError(
            "ledger publication rejected after MODFLOW/SWAP publication"
        )

    result.status = GroundwaterApplicationServiceStatus.OK
    result.published = True
    result.request_smaller_window = False
    result.failure_stage = "none"
    return result


def _extract_cell_heads(
    iterate: PreparedSolveIteration, bindings: Sequence[Any]
) -> tuple[float, ...]:
    heads: list[float] = []
    for binding in bindings:
        node_id = int(binding.modflow_node_id)
        if node_id <= 0 or node_id > len(iterate.head_m):
            raise ValueError("MODFLOW node id outside head vector")
        head = float(iterate.head_m[node_id - 1])
        if not math.isfinite(head):
            raise ValueError("non-finite MODFLOW cell head")
        heads.append(head)
    return tuple(heads)


def _finite_vector(values: Sequence[float], expected: int) -> bool:
    return len(values) == expected and all(math.isfinite(float(v)) for v in values)


def _abort_and_fail(
    runtime: GroundwaterApplicationRuntime,
    groundwater: Modflow6PreparedSolveSession,
    result: GroundwaterApplicationServiceResult,
    status: GroundwaterApplicationServiceStatus,
    retry: bool,
    stage: str,
) -> GroundwaterApplicationServiceResult:
    abort_ok = True
    try:
        abort_ok = bool(runtime.abort_prepublication())
    except Exception:
        abort_ok = False
    groundwater.invalidate_without_finalize()
    if not abort_ok:
        status = GroundwaterApplicationServiceStatus.PREPUBLICATION_ABORT_FAILED
        stage = f"{stage}-abort"
    return _fail(result, status, retry, stage)


def _fail(
    result: GroundwaterApplicationServiceResult,
    status: GroundwaterApplicationServiceStatus,
    retry: bool,
    stage: str,
) -> GroundwaterApplicationServiceResult:
    result.status = status
    result.published = False
    result.request_smaller_window = retry
    result.failure_stage = stage
    return result
