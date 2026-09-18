from __future__ import annotations

from dataclasses import dataclass
from enum import IntEnum
import math
from typing import Any, Protocol


class ServiceStatus(IntEnum):
    OK = 0
    INVALID_REQUEST = 1
    ORIGIN_FAILED = 2
    PREDICTOR_FAILED = 3
    GROUNDWATER_FAILED = 4
    SWAP_CORRECTOR_FAILED = 5
    NOT_CONVERGED = 6
    FINALIZE_FAILED = 7


@dataclass(frozen=True)
class AffineResponse:
    reference_head_m: float
    q_at_reference_m_per_s: float
    dq_dh_per_s: float

    def valid(self) -> bool:
        return all(
            math.isfinite(value)
            for value in (
                self.reference_head_m,
                self.q_at_reference_m_per_s,
                self.dq_dh_per_s,
            )
        )

    def evaluate(self, head_m: float) -> float:
        return self.q_at_reference_m_per_s + self.dq_dh_per_s * (
            head_m - self.reference_head_m
        )


@dataclass(frozen=True)
class GroundwaterIterate:
    valid: bool
    head_m: float
    boundary_q_m_per_s: float
    modflow_converged: bool
    failure: str = ""


@dataclass(frozen=True)
class SwapCorrector:
    candidate: Any
    prescribed_head_m: float
    q_m_per_s: float


@dataclass(frozen=True)
class ServiceConfig:
    flux_tolerance_m_per_s: float
    max_coupling_iterations: int

    def valid(self) -> bool:
        return (
            math.isfinite(self.flux_tolerance_m_per_s)
            and self.flux_tolerance_m_per_s > 0.0
            and self.max_coupling_iterations > 0
        )


@dataclass
class ServiceResult:
    status: ServiceStatus = ServiceStatus.INVALID_REQUEST
    ready_for_publication: bool = False
    request_smaller_window: bool = False
    iterations: int = 0
    final_swap_candidate: Any = None
    final_head_m: float = 0.0
    final_flux_residual_m_per_s: float = 0.0
    frozen_slope_per_s: float = 0.0
    failure_stage: str = "none"


class SwapParticipant(Protocol):
    def capture_origin(self) -> Any: ...
    def build_predictor_response(self, origin: Any) -> AffineResponse: ...
    def corrector_trial_from_origin(
        self, origin: Any, prescribed_head_m: float
    ) -> SwapCorrector: ...
    def discard_candidate(self, candidate: Any) -> bool: ...


class PreparedGroundwaterParticipant(Protocol):
    def open_window(self) -> bool: ...
    def solve_iteration(self, response: AffineResponse) -> GroundwaterIterate: ...
    def finalize_converged_solve(self) -> bool: ...
    def invalidate_abandoned_solve(self) -> None: ...


def run_prepared_solve_coupling_window(
    swap: SwapParticipant,
    groundwater: PreparedGroundwaterParticipant,
    config: ServiceConfig,
) -> ServiceResult:
    result = ServiceResult()
    if not config.valid():
        return result

    try:
        origin = swap.capture_origin()
    except Exception:
        return _fail(result, ServiceStatus.ORIGIN_FAILED, True, "swap-origin")
    if origin is None:
        return _fail(result, ServiceStatus.ORIGIN_FAILED, True, "swap-origin")

    try:
        predictor = swap.build_predictor_response(origin)
    except Exception:
        return _fail(result, ServiceStatus.PREDICTOR_FAILED, True, "predictor")
    if not isinstance(predictor, AffineResponse) or not predictor.valid():
        return _fail(result, ServiceStatus.PREDICTOR_FAILED, True, "predictor")

    try:
        opened = bool(groundwater.open_window())
    except Exception:
        opened = False
    if not opened:
        return _fail(
            result, ServiceStatus.GROUNDWATER_FAILED, True, "groundwater-open"
        )

    slope = predictor.dq_dh_per_s
    reference_head = predictor.reference_head_m
    reference_q = predictor.q_at_reference_m_per_s
    result.frozen_slope_per_s = slope

    for iteration_index in range(1, config.max_coupling_iterations + 1):
        result.iterations = iteration_index
        response = AffineResponse(reference_head, reference_q, slope)

        try:
            gw = groundwater.solve_iteration(response)
        except Exception:
            groundwater.invalidate_abandoned_solve()
            return _fail(
                result,
                ServiceStatus.GROUNDWATER_FAILED,
                True,
                "groundwater-solve",
            )

        if not _valid_groundwater(gw):
            groundwater.invalidate_abandoned_solve()
            return _fail(
                result,
                ServiceStatus.GROUNDWATER_FAILED,
                True,
                gw.failure if isinstance(gw, GroundwaterIterate) and gw.failure else "groundwater-solve",
            )

        try:
            sw = swap.corrector_trial_from_origin(origin, gw.head_m)
        except Exception:
            groundwater.invalidate_abandoned_solve()
            return _fail(
                result,
                ServiceStatus.SWAP_CORRECTOR_FAILED,
                True,
                "swap-corrector",
            )

        if not _valid_swap(sw, gw.head_m):
            _discard_swap(swap, sw)
            groundwater.invalidate_abandoned_solve()
            return _fail(
                result,
                ServiceStatus.SWAP_CORRECTOR_FAILED,
                True,
                "swap-corrector",
            )

        residual = sw.q_m_per_s - gw.boundary_q_m_per_s
        if not math.isfinite(residual):
            _discard_swap(swap, sw)
            groundwater.invalidate_abandoned_solve()
            return _fail(
                result,
                ServiceStatus.SWAP_CORRECTOR_FAILED,
                True,
                "coupling-residual",
            )

        result.final_head_m = gw.head_m
        result.final_flux_residual_m_per_s = residual

        flux_converged = abs(residual) <= config.flux_tolerance_m_per_s
        coupled_converged = flux_converged and gw.modflow_converged

        if coupled_converged:
            try:
                finalized = bool(groundwater.finalize_converged_solve())
            except Exception:
                finalized = False
            if not finalized:
                _discard_swap(swap, sw)
                groundwater.invalidate_abandoned_solve()
                return _fail(
                    result,
                    ServiceStatus.FINALIZE_FAILED,
                    True,
                    "groundwater-finalize-solve",
                )

            result.status = ServiceStatus.OK
            result.ready_for_publication = True
            result.request_smaller_window = False
            result.final_swap_candidate = sw.candidate
            result.failure_stage = "none"
            return result

        if not _discard_swap(swap, sw):
            groundwater.invalidate_abandoned_solve()
            return _fail(
                result,
                ServiceStatus.SWAP_CORRECTOR_FAILED,
                True,
                "swap-discard",
            )

        reference_head = gw.head_m
        reference_q = sw.q_m_per_s

    groundwater.invalidate_abandoned_solve()
    return _fail(
        result,
        ServiceStatus.NOT_CONVERGED,
        True,
        "max-coupling-iterations",
    )


def _valid_groundwater(value: Any) -> bool:
    return (
        isinstance(value, GroundwaterIterate)
        and value.valid
        and math.isfinite(value.head_m)
        and math.isfinite(value.boundary_q_m_per_s)
    )


def _valid_swap(value: Any, expected_head: float) -> bool:
    return (
        isinstance(value, SwapCorrector)
        and value.candidate is not None
        and math.isfinite(value.prescribed_head_m)
        and math.isfinite(value.q_m_per_s)
        and value.prescribed_head_m == expected_head
    )


def _discard_swap(swap: SwapParticipant, value: Any) -> bool:
    if not isinstance(value, SwapCorrector) or value.candidate is None:
        return True
    try:
        return bool(swap.discard_candidate(value.candidate))
    except Exception:
        return False


def _fail(
    result: ServiceResult,
    status: ServiceStatus,
    retry: bool,
    stage: str,
) -> ServiceResult:
    result.status = status
    result.ready_for_publication = False
    result.request_smaller_window = retry
    result.final_swap_candidate = None
    result.failure_stage = stage
    return result
