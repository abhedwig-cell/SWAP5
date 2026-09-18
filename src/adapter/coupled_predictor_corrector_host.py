from __future__ import annotations

from dataclasses import dataclass
from enum import IntEnum
import math
from typing import Any, Protocol


class CoupledHostStatus(IntEnum):
    OK = 0
    INVALID_REQUEST = 1
    ORIGIN_CAPTURE_FAILED = 2
    PREDICTOR_FAILED = 3
    GROUNDWATER_TRIAL_FAILED = 4
    SWAP_CORRECTOR_FAILED = 5
    CLEANUP_FAILED = 6
    NOT_CONVERGED = 7
    LEDGER_STAGE_FAILED = 8
    GROUNDWATER_PREPARE_FAILED = 9
    LEDGER_PREPARE_FAILED = 10
    PUBLICATION_PREFLIGHT_FAILED = 11
    SWAP_COMMIT_FAILED = 12


@dataclass(frozen=True)
class AffineCellResponse:
    reference_head_m: float
    q_u_at_reference_m_per_s: float
    dq_u_dh_per_s: float

    def valid(self) -> bool:
        return (
            math.isfinite(self.reference_head_m)
            and math.isfinite(self.q_u_at_reference_m_per_s)
            and math.isfinite(self.dq_u_dh_per_s)
        )

    def evaluate(self, head_m: float) -> float:
        return self.q_u_at_reference_m_per_s + self.dq_u_dh_per_s * (
            head_m - self.reference_head_m
        )


@dataclass(frozen=True)
class GroundwaterTrial:
    candidate: Any
    solved_head_m: float
    realized_boundary_q_m_per_s: float


@dataclass(frozen=True)
class SwapCorrectorTrial:
    candidate: Any
    prescribed_head_m: float
    q_u_m_per_s: float
    accepted_window_exchange_m: float


@dataclass(frozen=True)
class CoupledHostConfig:
    flux_tolerance_m_per_s: float
    max_outer_iterations: int

    def valid(self) -> bool:
        return (
            math.isfinite(self.flux_tolerance_m_per_s)
            and self.flux_tolerance_m_per_s > 0.0
            and self.max_outer_iterations > 0
        )


@dataclass
class CoupledHostResult:
    status: CoupledHostStatus = CoupledHostStatus.INVALID_REQUEST
    completed: bool = False
    committed: bool = False
    request_smaller_window: bool = False
    outer_iterations: int = 0
    failure_stage: str = "none"
    final_head_m: float = 0.0
    final_q_swap_m_per_s: float = 0.0
    final_q_groundwater_m_per_s: float = 0.0
    final_flux_residual_m_per_s: float = 0.0
    frozen_dq_u_dh_per_s: float = 0.0


class SwapParticipant(Protocol):
    def capture_origin(self) -> Any: ...

    def build_predictor_response(self, origin: Any) -> AffineCellResponse: ...

    def corrector_trial_from_origin(
        self, origin: Any, prescribed_head_m: float
    ) -> SwapCorrectorTrial: ...

    def discard_candidate(self, candidate: Any) -> bool: ...

    def publication_preflight(self, candidate: Any) -> bool: ...

    def commit_candidate(self, candidate: Any) -> bool: ...


class GroundwaterParticipant(Protocol):
    def capture_origin(self) -> Any: ...

    def trial_from_origin(
        self, origin: Any, response: AffineCellResponse
    ) -> GroundwaterTrial: ...

    def discard_candidate(self, candidate: Any) -> bool: ...

    def prepare_candidate(self, candidate: Any) -> Any: ...

    def abort_prepared(self, prepared: Any) -> None: ...

    def publication_preflight(self, prepared: Any) -> bool: ...

    def commit_prepared(self, prepared: Any) -> None: ...


class LedgerParticipant(Protocol):
    def stage(self, trial: SwapCorrectorTrial) -> Any: ...

    def discard_staged(self, staged: Any) -> None: ...

    def prepare(self, staged: Any) -> Any: ...

    def abort_prepared(self, prepared: Any) -> None: ...

    def publication_preflight(self, prepared: Any) -> bool: ...

    def commit_prepared(self, prepared: Any) -> None: ...


def run_coupled_predictor_corrector_window(
    swap: SwapParticipant,
    groundwater: GroundwaterParticipant,
    ledger: LedgerParticipant,
    config: CoupledHostConfig,
) -> CoupledHostResult:
    """Run one bounded tangent-coupled window against transactional participants.

    This function deliberately knows nothing about xmipy, XMI pointers or MODFLOW
    lifecycle calls. A concrete groundwater participant must independently prove
    that every trial starts from the supplied accepted origin.
    """

    result = CoupledHostResult()
    if not config.valid():
        return _fail(result, CoupledHostStatus.INVALID_REQUEST, False, "request-contract")

    try:
        swap_origin = swap.capture_origin()
        groundwater_origin = groundwater.capture_origin()
    except Exception:
        return _fail(
            result,
            CoupledHostStatus.ORIGIN_CAPTURE_FAILED,
            True,
            "origin-capture",
        )

    if swap_origin is None or groundwater_origin is None:
        return _fail(
            result,
            CoupledHostStatus.ORIGIN_CAPTURE_FAILED,
            True,
            "origin-capture",
        )

    try:
        predictor = swap.build_predictor_response(swap_origin)
    except Exception:
        return _fail(result, CoupledHostStatus.PREDICTOR_FAILED, True, "predictor")

    if not isinstance(predictor, AffineCellResponse) or not predictor.valid():
        return _fail(result, CoupledHostStatus.PREDICTOR_FAILED, True, "predictor")

    frozen_slope = predictor.dq_u_dh_per_s
    reference_head = predictor.reference_head_m
    reference_q = predictor.q_u_at_reference_m_per_s
    result.frozen_dq_u_dh_per_s = frozen_slope

    final_groundwater: GroundwaterTrial | None = None
    final_swap: SwapCorrectorTrial | None = None

    for iteration in range(1, config.max_outer_iterations + 1):
        result.outer_iterations = iteration
        response = AffineCellResponse(reference_head, reference_q, frozen_slope)

        try:
            groundwater_trial = groundwater.trial_from_origin(
                groundwater_origin, response
            )
        except Exception:
            return _fail(
                result,
                CoupledHostStatus.GROUNDWATER_TRIAL_FAILED,
                True,
                "groundwater-trial",
            )

        if not _valid_groundwater_trial(groundwater_trial):
            _best_effort_discard_groundwater(groundwater, groundwater_trial)
            return _fail(
                result,
                CoupledHostStatus.GROUNDWATER_TRIAL_FAILED,
                True,
                "groundwater-trial",
            )

        try:
            swap_trial = swap.corrector_trial_from_origin(
                swap_origin, groundwater_trial.solved_head_m
            )
        except Exception:
            if not _discard_groundwater(groundwater, groundwater_trial):
                return _fail(
                    result,
                    CoupledHostStatus.CLEANUP_FAILED,
                    True,
                    "swap-trial-groundwater-cleanup",
                )
            return _fail(
                result,
                CoupledHostStatus.SWAP_CORRECTOR_FAILED,
                True,
                "swap-corrector",
            )

        if not _valid_swap_trial(swap_trial, groundwater_trial.solved_head_m):
            cleanup_ok = _discard_pair(
                swap, swap_trial, groundwater, groundwater_trial
            )
            return _fail(
                result,
                CoupledHostStatus.SWAP_CORRECTOR_FAILED
                if cleanup_ok
                else CoupledHostStatus.CLEANUP_FAILED,
                True,
                "swap-corrector" if cleanup_ok else "swap-corrector-cleanup",
            )

        residual = swap_trial.q_u_m_per_s - groundwater_trial.realized_boundary_q_m_per_s
        if not math.isfinite(residual):
            cleanup_ok = _discard_pair(
                swap, swap_trial, groundwater, groundwater_trial
            )
            return _fail(
                result,
                CoupledHostStatus.SWAP_CORRECTOR_FAILED
                if cleanup_ok
                else CoupledHostStatus.CLEANUP_FAILED,
                True,
                "flux-residual" if cleanup_ok else "flux-residual-cleanup",
            )

        result.final_head_m = groundwater_trial.solved_head_m
        result.final_q_swap_m_per_s = swap_trial.q_u_m_per_s
        result.final_q_groundwater_m_per_s = (
            groundwater_trial.realized_boundary_q_m_per_s
        )
        result.final_flux_residual_m_per_s = residual

        if abs(residual) <= config.flux_tolerance_m_per_s:
            final_groundwater = groundwater_trial
            final_swap = swap_trial
            break

        cleanup_ok = _discard_pair(
            swap, swap_trial, groundwater, groundwater_trial
        )
        if not cleanup_ok:
            return _fail(
                result,
                CoupledHostStatus.CLEANUP_FAILED,
                True,
                "nonconverged-discard",
            )

        reference_head = groundwater_trial.solved_head_m
        reference_q = swap_trial.q_u_m_per_s

    if final_groundwater is None or final_swap is None:
        return _fail(
            result,
            CoupledHostStatus.NOT_CONVERGED,
            True,
            "max-outer-iterations",
        )

    staged_ledger: Any = None
    prepared_groundwater: Any = None
    prepared_ledger: Any = None

    try:
        staged_ledger = ledger.stage(final_swap)
    except Exception:
        cleanup_ok = _discard_pair(swap, final_swap, groundwater, final_groundwater)
        return _fail(
            result,
            CoupledHostStatus.LEDGER_STAGE_FAILED
            if cleanup_ok
            else CoupledHostStatus.CLEANUP_FAILED,
            True,
            "ledger-stage" if cleanup_ok else "ledger-stage-cleanup",
        )

    try:
        prepared_groundwater = groundwater.prepare_candidate(
            final_groundwater.candidate
        )
    except Exception:
        cleanup_ok = _discard_pair(swap, final_swap, groundwater, final_groundwater)
        try:
            ledger.discard_staged(staged_ledger)
        except Exception:
            cleanup_ok = False
        return _fail(
            result,
            CoupledHostStatus.GROUNDWATER_PREPARE_FAILED
            if cleanup_ok
            else CoupledHostStatus.CLEANUP_FAILED,
            True,
            "groundwater-prepare"
            if cleanup_ok
            else "groundwater-prepare-cleanup",
        )

    try:
        prepared_ledger = ledger.prepare(staged_ledger)
    except Exception:
        cleanup_ok = True
        try:
            groundwater.abort_prepared(prepared_groundwater)
        except Exception:
            cleanup_ok = False
        try:
            ledger.discard_staged(staged_ledger)
        except Exception:
            cleanup_ok = False
        try:
            if not swap.discard_candidate(final_swap.candidate):
                cleanup_ok = False
        except Exception:
            cleanup_ok = False
        return _fail(
            result,
            CoupledHostStatus.LEDGER_PREPARE_FAILED
            if cleanup_ok
            else CoupledHostStatus.CLEANUP_FAILED,
            True,
            "ledger-prepare" if cleanup_ok else "ledger-prepare-cleanup",
        )

    try:
        publication_ready = (
            swap.publication_preflight(final_swap.candidate)
            and groundwater.publication_preflight(prepared_groundwater)
            and ledger.publication_preflight(prepared_ledger)
        )
    except Exception:
        publication_ready = False

    if not publication_ready:
        cleanup_ok = _abort_prepared_pair(
            groundwater,
            prepared_groundwater,
            ledger,
            prepared_ledger,
        )
        try:
            if not swap.discard_candidate(final_swap.candidate):
                cleanup_ok = False
        except Exception:
            cleanup_ok = False
        return _fail(
            result,
            CoupledHostStatus.PUBLICATION_PREFLIGHT_FAILED
            if cleanup_ok
            else CoupledHostStatus.CLEANUP_FAILED,
            True,
            "publication-preflight"
            if cleanup_ok
            else "publication-preflight-abort",
        )

    try:
        swap_committed = swap.commit_candidate(final_swap.candidate)
    except Exception:
        swap_committed = False

    if not swap_committed:
        cleanup_ok = _abort_prepared_pair(
            groundwater,
            prepared_groundwater,
            ledger,
            prepared_ledger,
        )
        return _fail(
            result,
            CoupledHostStatus.SWAP_COMMIT_FAILED
            if cleanup_ok
            else CoupledHostStatus.CLEANUP_FAILED,
            True,
            "swap-commit" if cleanup_ok else "swap-commit-abort",
        )

    # Existing SWAP5 publication governance treats failures after the first
    # irreversible SWAP commit as ownership/programming invariant violations.
    try:
        groundwater.commit_prepared(prepared_groundwater)
        ledger.commit_prepared(prepared_ledger)
    except Exception as exc:
        raise RuntimeError(
            "F-GC37 atomic publication invariant failed after SWAP commit"
        ) from exc

    result.status = CoupledHostStatus.OK
    result.completed = True
    result.committed = True
    result.request_smaller_window = False
    result.failure_stage = "none"
    return result


def _valid_groundwater_trial(trial: Any) -> bool:
    return (
        isinstance(trial, GroundwaterTrial)
        and trial.candidate is not None
        and math.isfinite(trial.solved_head_m)
        and math.isfinite(trial.realized_boundary_q_m_per_s)
    )


def _valid_swap_trial(trial: Any, expected_head_m: float) -> bool:
    return (
        isinstance(trial, SwapCorrectorTrial)
        and trial.candidate is not None
        and math.isfinite(trial.prescribed_head_m)
        and math.isfinite(trial.q_u_m_per_s)
        and math.isfinite(trial.accepted_window_exchange_m)
        and trial.prescribed_head_m == expected_head_m
    )


def _discard_groundwater(
    groundwater: GroundwaterParticipant, trial: GroundwaterTrial
) -> bool:
    try:
        return bool(groundwater.discard_candidate(trial.candidate))
    except Exception:
        return False


def _best_effort_discard_groundwater(
    groundwater: GroundwaterParticipant, trial: Any
) -> None:
    if isinstance(trial, GroundwaterTrial) and trial.candidate is not None:
        _discard_groundwater(groundwater, trial)


def _discard_pair(
    swap: SwapParticipant,
    swap_trial: SwapCorrectorTrial,
    groundwater: GroundwaterParticipant,
    groundwater_trial: GroundwaterTrial,
) -> bool:
    ok = True
    try:
        if not groundwater.discard_candidate(groundwater_trial.candidate):
            ok = False
    except Exception:
        ok = False
    try:
        if not swap.discard_candidate(swap_trial.candidate):
            ok = False
    except Exception:
        ok = False
    return ok


def _abort_prepared_pair(
    groundwater: GroundwaterParticipant,
    prepared_groundwater: Any,
    ledger: LedgerParticipant,
    prepared_ledger: Any,
) -> bool:
    ok = True
    try:
        groundwater.abort_prepared(prepared_groundwater)
    except Exception:
        ok = False
    try:
        ledger.abort_prepared(prepared_ledger)
    except Exception:
        ok = False
    return ok


def _fail(
    result: CoupledHostResult,
    status: CoupledHostStatus,
    request_smaller_window: bool,
    stage: str,
) -> CoupledHostResult:
    result.status = status
    result.completed = False
    result.committed = False
    result.request_smaller_window = request_smaller_window
    result.failure_stage = stage
    return result
