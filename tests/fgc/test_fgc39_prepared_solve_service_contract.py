from __future__ import annotations

import importlib.util
import sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
MODULE_PATH = ROOT / "tests" / "fgc" / "support" / "fgc39_prepared_solve_service_harness.py"
SPEC = importlib.util.spec_from_file_location("fgc39_harness", MODULE_PATH)
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


class SwapDouble:
    def __init__(self, q_values: list[float]) -> None:
        self.origin = object()
        self.q_values = q_values
        self.predictor_calls = 0
        self.origins: list[Any] = []
        self.discarded: list[int] = []
        self.candidates: list[int] = []

    def capture_origin(self) -> Any:
        return self.origin

    def build_predictor_response(self, origin: Any) -> AffineResponse:
        assert origin is self.origin
        self.predictor_calls += 1
        return AffineResponse(0.5, 0.2, 0.1)

    def corrector_trial_from_origin(
        self, origin: Any, prescribed_head_m: float
    ) -> SwapCorrector:
        assert origin is self.origin
        self.origins.append(origin)
        token = len(self.candidates) + 1
        self.candidates.append(token)
        q = self.q_values[token - 1]
        return SwapCorrector(token, prescribed_head_m, q)

    def discard_candidate(self, candidate: int) -> bool:
        self.discarded.append(candidate)
        return True


class GroundwaterDouble:
    def __init__(self, iterations: list[GroundwaterIterate]) -> None:
        self.iterations = iterations
        self.responses: list[AffineResponse] = []
        self.open_calls = 0
        self.solve_calls = 0
        self.finalize_calls = 0
        self.invalidate_calls = 0

    def open_window(self) -> bool:
        self.open_calls += 1
        return True

    def solve_iteration(self, response: AffineResponse) -> GroundwaterIterate:
        self.responses.append(response)
        value = self.iterations[self.solve_calls]
        self.solve_calls += 1
        return value

    def finalize_converged_solve(self) -> bool:
        self.finalize_calls += 1
        return True

    def invalidate_abandoned_solve(self) -> None:
        self.invalidate_calls += 1


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def test_conjunctive_convergence_and_continuous_groundwater() -> None:
    # Iteration 1: flux matches, MODFLOW not converged -> MUST continue.
    # Iteration 2: MODFLOW converged, flux does not match -> MUST continue.
    # Iteration 3: both conditions true -> close exactly once.
    gw_values = [
        GroundwaterIterate(True, 0.5, 0.2, False),
        GroundwaterIterate(True, 0.6, 0.21, True),
        GroundwaterIterate(True, 0.7, 0.26, True),
    ]
    swap = SwapDouble([0.2, 0.25, 0.2600001])
    gw = GroundwaterDouble(gw_values)

    result = run_window(
        swap,
        gw,
        ServiceConfig(flux_tolerance_m_per_s=1.0e-6, max_coupling_iterations=8),
    )

    require(result.status == ServiceStatus.OK, f"unexpected status {result.status}")
    require(result.ready_for_publication, "converged window not publication-ready")
    require(result.iterations == 3, "service closed before conjunctive convergence")
    require(result.final_swap_candidate == 3, "wrong SWAP candidate retained")

    require(swap.predictor_calls == 1, "predictor/tangent rebuilt")
    require(all(origin is swap.origin for origin in swap.origins), "SWAP origin drift")
    require(swap.discarded == [1, 2], "nonconverged SWAP candidates not discarded")

    require(gw.open_calls == 1, "groundwater solve session opened more than once")
    require(gw.solve_calls == 3, "unexpected groundwater solve count")
    require(gw.finalize_calls == 1, "groundwater solve not finalized exactly once")
    require(gw.invalidate_calls == 0, "successful groundwater session invalidated")

    require(
        all(response.dq_dh_per_s == 0.1 for response in gw.responses),
        "tangent slope changed within coupling window",
    )
    require(
        gw.responses[0].reference_head_m == 0.5
        and gw.responses[0].q_at_reference_m_per_s == 0.2,
        "initial predictor response changed",
    )
    require(
        gw.responses[1].reference_head_m == 0.5
        and gw.responses[1].q_at_reference_m_per_s == 0.2,
        "iteration-1 reference update mismatch",
    )
    require(
        gw.responses[2].reference_head_m == 0.6
        and gw.responses[2].q_at_reference_m_per_s == 0.25,
        "iteration-2 reference update mismatch",
    )

    print("FGC39_ONE_PREPARED_GROUNDWATER_SESSION=PASS")
    print("FGC39_SAME_SWAP_ORIGIN=PASS")
    print("FGC39_FIXED_TANGENT=PASS")
    print("FGC39_CONJUNCTIVE_MODFLOW_AND_FLUX_CONVERGENCE=PASS")
    print("FGC39_ONLY_SWAP_CANDIDATES_DISCARDED=PASS")
    print("FGC39_FINAL_SOLVE_FINALIZED_ONCE=PASS")


def test_coupling_budget_fail_closed() -> None:
    gw_values = [
        GroundwaterIterate(True, 0.5, 0.2, False),
        GroundwaterIterate(True, 0.6, 0.21, False),
    ]
    swap = SwapDouble([0.23, 0.24])
    gw = GroundwaterDouble(gw_values)

    result = run_window(
        swap,
        gw,
        ServiceConfig(flux_tolerance_m_per_s=1.0e-9, max_coupling_iterations=2),
    )

    require(result.status == ServiceStatus.NOT_CONVERGED, "budget exhaustion status mismatch")
    require(result.request_smaller_window, "budget exhaustion did not request retry")
    require(not result.ready_for_publication, "failed window became publication-ready")
    require(swap.discarded == [1, 2], "failed SWAP candidates not discarded")
    require(gw.open_calls == 1 and gw.finalize_calls == 0, "failed solve finalized")
    require(gw.invalidate_calls == 1, "failed prepared solve not invalidated")

    print("FGC39_COUPLING_BUDGET_FAIL_CLOSED=PASS")


def test_backend_limit_fail_closed() -> None:
    gw_values = [
        GroundwaterIterate(
            False,
            0.0,
            0.0,
            False,
            failure="modflow-solve-iteration-limit",
        )
    ]
    swap = SwapDouble([0.2])
    gw = GroundwaterDouble(gw_values)

    result = run_window(
        swap,
        gw,
        ServiceConfig(flux_tolerance_m_per_s=1.0e-6, max_coupling_iterations=5),
    )

    require(result.status == ServiceStatus.GROUNDWATER_FAILED, "backend-limit status mismatch")
    require(result.request_smaller_window, "backend limit did not request retry")
    require(not swap.candidates, "SWAP corrector ran after failed groundwater iteration")
    require(gw.finalize_calls == 0, "failed backend finalized solve")
    require(gw.invalidate_calls == 1, "failed backend session not invalidated")

    print("FGC39_BACKEND_ITERATION_LIMIT_FAIL_CLOSED=PASS")


def main() -> None:
    test_conjunctive_convergence_and_continuous_groundwater()
    test_coupling_budget_fail_closed()
    test_backend_limit_fail_closed()
    print("FGC39_PREPARED_SOLVE_COUPLING_SERVICE_GATE=PASS")


if __name__ == "__main__":
    main()
