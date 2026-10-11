from __future__ import annotations

import importlib.util
import sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
MODULE_PATH = ROOT / "tests" / "fgc" / "support" / "fgc39_prepared_solve_service_harness.py"
SPEC = importlib.util.spec_from_file_location("fgc39_under_test", MODULE_PATH)
assert SPEC is not None and SPEC.loader is not None
MOD = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = MOD
SPEC.loader.exec_module(MOD)

AffineResponse = MOD.AffineResponse
GroundwaterIterate = MOD.GroundwaterIterate
ServiceConfig = MOD.ServiceConfig
ServiceStatus = MOD.ServiceStatus
SwapCorrector = MOD.SwapCorrector
run_window = MOD.run_prepared_solve_coupling_window


def require(value: bool, message: str) -> None:
    if not value:
        raise AssertionError(message)


class SwapOracle:
    def __init__(
        self,
        predictor: AffineResponse,
        q_by_head: dict[float, float],
        *,
        corrector_raises: bool = False,
    ) -> None:
        self.origin = object()
        self.predictor = predictor
        self.q_by_head = q_by_head
        self.corrector_raises = corrector_raises
        self.capture_calls = 0
        self.predictor_origins: list[Any] = []
        self.corrector_origins: list[Any] = []
        self.corrector_heads: list[float] = []
        self.discards: list[tuple[float, float]] = []

    def capture_origin(self) -> Any:
        self.capture_calls += 1
        return self.origin

    def build_predictor_response(self, origin: Any) -> AffineResponse:
        self.predictor_origins.append(origin)
        return self.predictor

    def corrector_trial_from_origin(
        self, origin: Any, prescribed_head_m: float
    ) -> SwapCorrector:
        self.corrector_origins.append(origin)
        self.corrector_heads.append(prescribed_head_m)
        if self.corrector_raises:
            raise RuntimeError("corrector-failure")
        q = self.q_by_head[prescribed_head_m]
        return SwapCorrector((prescribed_head_m, q), prescribed_head_m, q)

    def discard_candidate(self, candidate: tuple[float, float]) -> bool:
        self.discards.append(candidate)
        return True


class GroundwaterOracle:
    def __init__(
        self,
        values: list[GroundwaterIterate],
        *,
        finalize_ok: bool = True,
    ) -> None:
        self.values = values
        self.finalize_ok = finalize_ok
        self.open_calls = 0
        self.solve_calls = 0
        self.responses: list[AffineResponse] = []
        self.finalize_calls = 0
        self.invalidate_calls = 0

    def open_window(self) -> bool:
        self.open_calls += 1
        return True

    def solve_iteration(self, response: AffineResponse) -> GroundwaterIterate:
        self.responses.append(response)
        value = self.values[self.solve_calls]
        self.solve_calls += 1
        return value

    def finalize_converged_solve(self) -> bool:
        self.finalize_calls += 1
        return self.finalize_ok

    def invalidate_abandoned_solve(self) -> None:
        self.invalidate_calls += 1


def test_reference_update_and_convergence_ordering() -> None:
    predictor = AffineResponse(1.0, 0.10, 0.025)
    swap = SwapOracle(
        predictor,
        {
            1.10: 0.14,
            1.20: 0.18,
            1.25: 0.2000002,
        },
    )
    gw = GroundwaterOracle(
        [
            # First: flux not converged and MODFLOW false.
            GroundwaterIterate(True, 1.10, 0.12, False),
            # Second: MODFLOW true but flux not converged.
            GroundwaterIterate(True, 1.20, 0.15, True),
            # Third: both converge.
            GroundwaterIterate(True, 1.25, 0.20, True),
        ]
    )

    result = run_window(
        swap,
        gw,
        ServiceConfig(flux_tolerance_m_per_s=1.0e-6, max_coupling_iterations=5),
    )

    require(result.status == ServiceStatus.OK, "expected converged service")
    require(result.iterations == 3, "wrong iteration count")
    require(result.final_swap_candidate == (1.25, 0.2000002), "wrong retained candidate")
    require(swap.discards == [(1.10, 0.14), (1.20, 0.18)], "wrong discard set")

    require(gw.open_calls == 1, "prepared solve opened more than once")
    require(gw.finalize_calls == 1, "prepared solve not finalized once")
    require(gw.invalidate_calls == 0, "successful prepared solve invalidated")

    require(swap.capture_calls == 1, "SWAP origin captured more than once")
    require(all(origin is swap.origin for origin in swap.predictor_origins), "predictor origin drift")
    require(all(origin is swap.origin for origin in swap.corrector_origins), "corrector origin drift")

    # Independent oracle for the reference update sequence:
    # initial predictor -> after iteration 1 use H1/qswap1 -> after iteration 2 use H2/qswap2.
    expected = [
        (1.0, 0.10, 0.025),
        (1.10, 0.14, 0.025),
        (1.20, 0.18, 0.025),
    ]
    actual = [
        (x.reference_head_m, x.q_at_reference_m_per_s, x.dq_dh_per_s)
        for x in gw.responses
    ]
    require(actual == expected, f"reference update mismatch: {actual!r}")
    print("FVQ112_REFERENCE_UPDATE_ORACLE=PASS")
    print("FVQ112_CONJUNCTIVE_CONVERGENCE_ORDERING=PASS")
    print("FVQ112_ONE_PREPARED_SESSION_AND_SAME_SWAP_ORIGIN=PASS")
    print("FVQ112_FIXED_TANGENT_ORACLE=PASS")


def test_flux_match_before_modflow_must_continue() -> None:
    predictor = AffineResponse(0.0, 0.0, 0.2)
    swap = SwapOracle(predictor, {0.4: 0.08, 0.5: 0.1000001})
    gw = GroundwaterOracle(
        [
            GroundwaterIterate(True, 0.4, 0.08, False),
            GroundwaterIterate(True, 0.5, 0.10, True),
        ]
    )
    result = run_window(
        swap,
        gw,
        ServiceConfig(flux_tolerance_m_per_s=1.0e-6, max_coupling_iterations=4),
    )
    require(result.status == ServiceStatus.OK, "flux-first fixture did not converge")
    require(result.iterations == 2, "service stopped at flux-only convergence")
    require(swap.discards == [(0.4, 0.08)], "first candidate not discarded")
    print("FVQ112_FLUX_ONLY_CONVERGENCE_REJECTED=PASS")


def test_finalize_failure_is_not_publication_ready() -> None:
    predictor = AffineResponse(0.5, 0.1, 0.0)
    swap = SwapOracle(predictor, {0.5: 0.1000001})
    gw = GroundwaterOracle(
        [GroundwaterIterate(True, 0.5, 0.1, True)],
        finalize_ok=False,
    )
    result = run_window(
        swap,
        gw,
        ServiceConfig(flux_tolerance_m_per_s=1.0e-6, max_coupling_iterations=2),
    )
    require(result.status == ServiceStatus.FINALIZE_FAILED, "finalize failure status")
    require(not result.ready_for_publication, "finalize failure became publication-ready")
    require(result.request_smaller_window, "finalize failure did not request retry")
    require(swap.discards == [(0.5, 0.1000001)], "final candidate not discarded")
    require(gw.finalize_calls == 1, "finalize call count")
    require(gw.invalidate_calls == 1, "failed finalized session not invalidated")
    print("FVQ112_FINALIZE_FAILURE_FAIL_CLOSED=PASS")


def test_corrector_exception_invalidates_groundwater() -> None:
    predictor = AffineResponse(0.0, 0.0, 0.1)
    swap = SwapOracle(predictor, {0.3: 0.03}, corrector_raises=True)
    gw = GroundwaterOracle([GroundwaterIterate(True, 0.3, 0.03, False)])
    result = run_window(
        swap,
        gw,
        ServiceConfig(flux_tolerance_m_per_s=1.0e-6, max_coupling_iterations=2),
    )
    require(result.status == ServiceStatus.SWAP_CORRECTOR_FAILED, "corrector failure status")
    require(not result.ready_for_publication, "corrector failure publication-ready")
    require(gw.finalize_calls == 0, "failed corrector finalized groundwater")
    require(gw.invalidate_calls == 1, "failed corrector did not invalidate groundwater")
    print("FVQ112_CORRECTOR_FAILURE_INVALIDATES_SESSION=PASS")


def main() -> None:
    test_reference_update_and_convergence_ordering()
    test_flux_match_before_modflow_must_continue()
    test_finalize_failure_is_not_publication_ready()
    test_corrector_exception_invalidates_groundwater()
    print("FVQ112_INDEPENDENT_COUPLING_SERVICE_CONTRACT_GATE=PASS")


if __name__ == "__main__":
    main()
