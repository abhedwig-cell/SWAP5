from __future__ import annotations

from dataclasses import dataclass
from enum import IntEnum
import math
from typing import Any, Protocol, Sequence

from modflow6_groundwater_application_service import GroundwaterApplicationPlanView
from modflow6_prepared_solve_session import (
    Modflow6PreparedSolveSession,
    PreparedSolveIteration,
    PreparedSolveStatus,
)


class TriangleApplicationStatus(IntEnum):
    OK = 0
    INVALID_CONFIG = 1
    INVALID_PLAN = 2
    ORIGIN_FAILED = 3
    GROUNDWATER_OPEN_FAILED = 4
    GROUNDWATER_ITERATION_FAILED = 5
    JOINT_SWAP_TRIAL_FAILED = 6
    RIBASIM_TRIAL_FAILED = 7
    RUNTIME_EVALUATION_FAILED = 8
    NOT_CONVERGED = 9
    GROUNDWATER_FINALIZE_FAILED = 10
    SWAP_PREFLIGHT_FAILED = 11
    RIBASIM_PREFLIGHT_FAILED = 12
    LEDGER_PREPARE_FAILED = 13
    LEDGER_PREFLIGHT_FAILED = 14
    MODFLOW_PREFLIGHT_FAILED = 15
    PREPUBLICATION_ABORT_FAILED = 16


class TrianglePublicationInvariantError(RuntimeError):
    """Failure at or after the first irreversible triangle publication."""


@dataclass(frozen=True)
class TriangleApplicationConfig:
    groundwater_flux_tolerance_m_per_s: float
    surface_exchange_tolerance_cm: float
    max_coupling_iterations: int
    initial_surface_head_cm: float

    def valid(self) -> bool:
        return (
            math.isfinite(self.groundwater_flux_tolerance_m_per_s)
            and self.groundwater_flux_tolerance_m_per_s > 0.0
            and math.isfinite(self.surface_exchange_tolerance_cm)
            and self.surface_exchange_tolerance_cm >= 0.0
            and self.max_coupling_iterations > 0
            and math.isfinite(self.initial_surface_head_cm)
        )


@dataclass(frozen=True)
class TriangleCorrectorBatch:
    valid: bool
    cell_q_swap_m_per_s: tuple[float, ...]
    cell_dq_swap_dh_per_s: tuple[float, ...]
    requested_surface_exchange_cm: float


@dataclass(frozen=True)
class RibasimCandidateReceipt:
    valid: bool
    requested_surface_exchange_cm: float
    realized_surface_exchange_cm: float


@dataclass
class TriangleApplicationResult:
    status: TriangleApplicationStatus = TriangleApplicationStatus.INVALID_CONFIG
    published: bool = False
    request_smaller_window: bool = False
    iterations: int = 0
    surface_recompositions: int = 0
    final_heads_m: tuple[float, ...] = ()
    final_groundwater_residuals_m_per_s: tuple[float, ...] = ()
    final_surface_request_cm: float = 0.0
    final_surface_realized_cm: float = 0.0
    failure_stage: str = "none"


class TriangleSwapRuntime(Protocol):
    def materialize_plan(self) -> GroundwaterApplicationPlanView: ...
    def capture_origins(self) -> bool: ...
    def evaluate_groundwater_fluxes(
        self, terms: Sequence[Any], cell_heads_m: Sequence[float]
    ) -> Sequence[float]: ...
    def trial_joint(
        self, cell_heads_m: Sequence[float], surface_head_cm: float
    ) -> TriangleCorrectorBatch: ...
    def recompose_surface_head(
        self, previous_surface_head_cm: float, receipt: RibasimCandidateReceipt
    ) -> float: ...
    def discard_candidate(self) -> bool: ...
    def relinearize_terms(
        self,
        cell_heads_m: Sequence[float],
        cell_q_swap_m_per_s: Sequence[float],
        cell_dq_swap_dh_per_s: Sequence[float],
    ) -> Sequence[Any]: ...
    def swap_preflight(self, realized_surface_exchange_cm: float) -> bool: ...
    def prepare_ledgers(self) -> bool: ...
    def ledgers_preflight(self) -> bool: ...
    def abort_prepublication(self) -> bool: ...
    def commit_swap(self, realized_surface_exchange_cm: float) -> bool: ...
    def commit_ledgers(self) -> bool: ...


class RibasimCandidateRuntime(Protocol):
    def capture_origin(self) -> bool: ...
    def trial_from_origin(self, requested_surface_exchange_cm: float) -> RibasimCandidateReceipt: ...
    def discard_candidate(self) -> bool: ...
    def publication_ready(self) -> bool: ...
    def abort_prepublication(self) -> bool: ...
    def commit_candidate(self) -> bool: ...


def run_triangle_application_window(
    runtime: TriangleSwapRuntime,
    groundwater: Modflow6PreparedSolveSession,
    ribasim: RibasimCandidateRuntime,
    config: TriangleApplicationConfig,
) -> TriangleApplicationResult:
    result = TriangleApplicationResult()
    if not config.valid():
        return result

    try:
        plan = runtime.materialize_plan()
    except Exception:
        return _fail(result, TriangleApplicationStatus.INVALID_PLAN, False, "application-plan")
    if not isinstance(plan, GroundwaterApplicationPlanView) or not plan.valid():
        return _fail(result, TriangleApplicationStatus.INVALID_PLAN, False, "application-plan")

    try:
        origins_ok = bool(runtime.capture_origins()) and bool(ribasim.capture_origin())
    except Exception:
        origins_ok = False
    if not origins_ok:
        return _abort_and_fail(
            runtime, groundwater, ribasim, result,
            TriangleApplicationStatus.ORIGIN_FAILED, True, "origin-capture"
        )

    if groundwater.acquire_after_prepare_time_step() != PreparedSolveStatus.OK:
        return _abort_and_fail(
            runtime, groundwater, ribasim, result,
            TriangleApplicationStatus.GROUNDWATER_OPEN_FAILED, True, "groundwater-acquire"
        )
    if groundwater.open_prepared_solve() != PreparedSolveStatus.OK:
        return _abort_and_fail(
            runtime, groundwater, ribasim, result,
            TriangleApplicationStatus.GROUNDWATER_OPEN_FAILED, True, "groundwater-prepare-solve"
        )

    current_terms = tuple(plan.terms)
    surface_head_cm = float(config.initial_surface_head_cm)
    ncell = len(plan.cell_ids)

    for iteration_index in range(1, config.max_coupling_iterations + 1):
        result.iterations = iteration_index

        solve_status, iterate = groundwater.publish_and_solve_iteration(plan.bindings, current_terms)
        if solve_status != PreparedSolveStatus.OK or not isinstance(iterate, PreparedSolveIteration):
            return _abort_and_fail(
                runtime, groundwater, ribasim, result,
                TriangleApplicationStatus.GROUNDWATER_ITERATION_FAILED, True, "groundwater-solve"
            )

        try:
            heads = _extract_cell_heads(iterate, plan.bindings)
            q_groundwater = tuple(
                float(value)
                for value in runtime.evaluate_groundwater_fluxes(current_terms, heads)
            )
        except Exception:
            return _abort_and_fail(
                runtime, groundwater, ribasim, result,
                TriangleApplicationStatus.RUNTIME_EVALUATION_FAILED, True, "groundwater-evaluation"
            )
        if not _finite_vector(q_groundwater, ncell):
            return _abort_and_fail(
                runtime, groundwater, ribasim, result,
                TriangleApplicationStatus.RUNTIME_EVALUATION_FAILED, True, "groundwater-evaluation"
            )

        try:
            corrector = runtime.trial_joint(heads, surface_head_cm)
        except Exception:
            corrector = None
        if (
            not isinstance(corrector, TriangleCorrectorBatch)
            or not corrector.valid
            or not _finite_vector(corrector.cell_q_swap_m_per_s, ncell)
            or not _finite_vector(corrector.cell_dq_swap_dh_per_s, ncell)
            or not math.isfinite(corrector.requested_surface_exchange_cm)
        ):
            return _abort_and_fail(
                runtime, groundwater, ribasim, result,
                TriangleApplicationStatus.JOINT_SWAP_TRIAL_FAILED, True, "joint-swap-trial"
            )

        try:
            receipt = ribasim.trial_from_origin(corrector.requested_surface_exchange_cm)
        except Exception:
            receipt = None
        if (
            not isinstance(receipt, RibasimCandidateReceipt)
            or not receipt.valid
            or not math.isfinite(receipt.requested_surface_exchange_cm)
            or not math.isfinite(receipt.realized_surface_exchange_cm)
            or abs(receipt.requested_surface_exchange_cm - corrector.requested_surface_exchange_cm)
            > config.surface_exchange_tolerance_cm
        ):
            return _abort_and_fail(
                runtime, groundwater, ribasim, result,
                TriangleApplicationStatus.RIBASIM_TRIAL_FAILED, True, "ribasim-trial"
            )

        residuals = tuple(
            q_swap - q_gw
            for q_swap, q_gw in zip(
                corrector.cell_q_swap_m_per_s, q_groundwater, strict=True
            )
        )
        if not _finite_vector(residuals, ncell):
            return _abort_and_fail(
                runtime, groundwater, ribasim, result,
                TriangleApplicationStatus.RUNTIME_EVALUATION_FAILED, True, "groundwater-residual"
            )

        surface_residual = (
            receipt.realized_surface_exchange_cm - corrector.requested_surface_exchange_cm
        )
        surface_match = abs(surface_residual) <= config.surface_exchange_tolerance_cm
        groundwater_match = all(
            abs(value) <= config.groundwater_flux_tolerance_m_per_s for value in residuals
        )
        coupled_converged = bool(iterate.modflow_converged) and groundwater_match and surface_match

        result.final_heads_m = heads
        result.final_groundwater_residuals_m_per_s = residuals
        result.final_surface_request_cm = corrector.requested_surface_exchange_cm
        result.final_surface_realized_cm = receipt.realized_surface_exchange_cm

        if coupled_converged:
            if groundwater.finalize_prepared_solve() != PreparedSolveStatus.OK:
                return _abort_and_fail(
                    runtime, groundwater, ribasim, result,
                    TriangleApplicationStatus.GROUNDWATER_FINALIZE_FAILED, True, "groundwater-finalize-solve"
                )
            return _publish_converged_triangle(runtime, groundwater, ribasim, receipt, result)

        try:
            swap_discarded = bool(runtime.discard_candidate())
            ribasim_discarded = bool(ribasim.discard_candidate())
        except Exception:
            swap_discarded = False
            ribasim_discarded = False
        if not swap_discarded or not ribasim_discarded:
            return _abort_and_fail(
                runtime, groundwater, ribasim, result,
                TriangleApplicationStatus.PREPUBLICATION_ABORT_FAILED, True, "candidate-discard"
            )

        if not surface_match:
            try:
                surface_head_cm = float(
                    runtime.recompose_surface_head(surface_head_cm, receipt)
                )
            except Exception:
                return _abort_and_fail(
                    runtime, groundwater, ribasim, result,
                    TriangleApplicationStatus.RUNTIME_EVALUATION_FAILED, True, "surface-recompose"
                )
            if not math.isfinite(surface_head_cm):
                return _abort_and_fail(
                    runtime, groundwater, ribasim, result,
                    TriangleApplicationStatus.RUNTIME_EVALUATION_FAILED, True, "surface-recompose"
                )
            result.surface_recompositions += 1

        try:
            current_terms = tuple(
                runtime.relinearize_terms(
                    heads,
                    corrector.cell_q_swap_m_per_s,
                    corrector.cell_dq_swap_dh_per_s,
                )
            )
        except Exception:
            return _abort_and_fail(
                runtime, groundwater, ribasim, result,
                TriangleApplicationStatus.RUNTIME_EVALUATION_FAILED, True, "groundwater-relinearize"
            )
        if len(current_terms) != ncell:
            return _abort_and_fail(
                runtime, groundwater, ribasim, result,
                TriangleApplicationStatus.RUNTIME_EVALUATION_FAILED, True, "groundwater-relinearize"
            )

    return _abort_and_fail(
        runtime, groundwater, ribasim, result,
        TriangleApplicationStatus.NOT_CONVERGED, True, "max-coupling-iterations"
    )


def _publish_converged_triangle(
    runtime: TriangleSwapRuntime,
    groundwater: Modflow6PreparedSolveSession,
    ribasim: RibasimCandidateRuntime,
    receipt: RibasimCandidateReceipt,
    result: TriangleApplicationResult,
) -> TriangleApplicationResult:
    try:
        swap_ready = bool(runtime.swap_preflight(receipt.realized_surface_exchange_cm))
    except Exception:
        swap_ready = False
    if not swap_ready:
        return _abort_and_fail(
            runtime, groundwater, ribasim, result,
            TriangleApplicationStatus.SWAP_PREFLIGHT_FAILED, True, "swap-preflight"
        )

    try:
        ribasim_ready = bool(ribasim.publication_ready())
    except Exception:
        ribasim_ready = False
    if not ribasim_ready:
        return _abort_and_fail(
            runtime, groundwater, ribasim, result,
            TriangleApplicationStatus.RIBASIM_PREFLIGHT_FAILED, True, "ribasim-preflight"
        )

    try:
        ledger_prepared = bool(runtime.prepare_ledgers())
    except Exception:
        ledger_prepared = False
    if not ledger_prepared:
        return _abort_and_fail(
            runtime, groundwater, ribasim, result,
            TriangleApplicationStatus.LEDGER_PREPARE_FAILED, True, "ledger-prepare"
        )

    try:
        ledgers_ready = bool(runtime.ledgers_preflight())
    except Exception:
        ledgers_ready = False
    if not ledgers_ready:
        return _abort_and_fail(
            runtime, groundwater, ribasim, result,
            TriangleApplicationStatus.LEDGER_PREFLIGHT_FAILED, True, "ledger-preflight"
        )

    if not groundwater.timestep_ready_for_finalize():
        return _abort_and_fail(
            runtime, groundwater, ribasim, result,
            TriangleApplicationStatus.MODFLOW_PREFLIGHT_FAILED, True, "modflow-timestep-preflight"
        )

    # First irreversible publication remains MODFLOW, preserving F-GC49 authority.
    status = groundwater.finalize_time_step_once()
    if status != PreparedSolveStatus.OK:
        raise TrianglePublicationInvariantError(
            f"MODFLOW finalize_time_step failed at first irreversible publication: {status.name}"
        )

    try:
        ribasim_committed = bool(ribasim.commit_candidate())
    except Exception as exc:
        raise TrianglePublicationInvariantError(
            "Ribasim publication failed after MODFLOW timestep publication"
        ) from exc
    if not ribasim_committed:
        raise TrianglePublicationInvariantError(
            "Ribasim publication rejected after MODFLOW timestep publication"
        )

    try:
        swap_committed = bool(runtime.commit_swap(receipt.realized_surface_exchange_cm))
    except Exception as exc:
        raise TrianglePublicationInvariantError(
            "SWAP publication failed after MODFLOW/Ribasim publication"
        ) from exc
    if not swap_committed:
        raise TrianglePublicationInvariantError(
            "SWAP publication rejected after MODFLOW/Ribasim publication"
        )

    try:
        ledgers_committed = bool(runtime.commit_ledgers())
    except Exception as exc:
        raise TrianglePublicationInvariantError(
            "ledger publication failed after MODFLOW/Ribasim/SWAP publication"
        ) from exc
    if not ledgers_committed:
        raise TrianglePublicationInvariantError(
            "ledger publication rejected after MODFLOW/Ribasim/SWAP publication"
        )

    result.status = TriangleApplicationStatus.OK
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
    runtime: TriangleSwapRuntime,
    groundwater: Modflow6PreparedSolveSession,
    ribasim: RibasimCandidateRuntime,
    result: TriangleApplicationResult,
    status: TriangleApplicationStatus,
    retry: bool,
    stage: str,
) -> TriangleApplicationResult:
    abort_ok = True
    try:
        abort_ok = bool(runtime.abort_prepublication()) and bool(
            ribasim.abort_prepublication()
        )
    except Exception:
        abort_ok = False
    groundwater.invalidate_without_finalize()
    if not abort_ok:
        status = TriangleApplicationStatus.PREPUBLICATION_ABORT_FAILED
        stage = f"{stage}-abort"
    return _fail(result, status, retry, stage)


def _fail(
    result: TriangleApplicationResult,
    status: TriangleApplicationStatus,
    retry: bool,
    stage: str,
) -> TriangleApplicationResult:
    result.status = status
    result.published = False
    result.request_smaller_window = retry
    result.failure_stage = stage
    return result
