from __future__ import annotations

import importlib.util
import math
import sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
MODULE_PATH = ROOT / "tests" / "fgc" / "support" / "fgc37_internal_coupling_service_harness.py"
SPEC = importlib.util.spec_from_file_location("fgc37_service_harness", MODULE_PATH)
assert SPEC is not None and SPEC.loader is not None
MOD = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = MOD
SPEC.loader.exec_module(MOD)

AffineCellResponse = MOD.AffineCellResponse
CoupledServiceConfig = MOD.CoupledServiceConfig
CoupledServiceStatus = MOD.CoupledServiceStatus
GroundwaterTrial = MOD.GroundwaterTrial
SwapCorrectorTrial = MOD.SwapCorrectorTrial
run_window = MOD.run_internal_coupling_service_window


class SwapDouble:
    def __init__(self, events: list[str]) -> None:
        self.events = events
        self.origin = object()
        self.predictor_calls = 0
        self.corrector_origins: list[Any] = []
        self.corrector_heads: list[float] = []
        self.discarded: list[int] = []
        self.committed: list[int] = []
        self.preflight_ok = True
        self.commit_ok = True
        self.next_candidate = 0

    def capture_origin(self) -> Any:
        self.events.append("swap:capture")
        return self.origin

    def build_predictor_response(self, origin: Any) -> AffineCellResponse:
        assert origin is self.origin
        self.predictor_calls += 1
        self.events.append("swap:predictor")
        return AffineCellResponse(0.5, 0.225, 0.2)

    def corrector_trial_from_origin(
        self, origin: Any, prescribed_head_m: float
    ) -> SwapCorrectorTrial:
        assert origin is self.origin
        self.corrector_origins.append(origin)
        self.corrector_heads.append(prescribed_head_m)
        self.next_candidate += 1
        token = self.next_candidate
        self.events.append(f"swap:trial:{token}")
        q = 0.05 + 0.3 * prescribed_head_m + 0.1 * prescribed_head_m**2
        return SwapCorrectorTrial(
            candidate=token,
            prescribed_head_m=prescribed_head_m,
            q_u_m_per_s=q,
            accepted_window_exchange_m=q * 86400.0,
        )

    def discard_candidate(self, candidate: int) -> bool:
        self.events.append(f"swap:discard:{candidate}")
        self.discarded.append(candidate)
        return True

    def publication_preflight(self, candidate: int) -> bool:
        self.events.append(f"swap:preflight:{candidate}")
        return self.preflight_ok

    def commit_candidate(self, candidate: int) -> bool:
        self.events.append(f"swap:commit:{candidate}")
        if self.commit_ok:
            self.committed.append(candidate)
        return self.commit_ok


class GroundwaterDouble:
    def __init__(self, events: list[str]) -> None:
        self.events = events
        self.origin = object()
        self.trial_origins: list[Any] = []
        self.responses: list[AffineCellResponse] = []
        self.discarded: list[int] = []
        self.prepared: list[int] = []
        self.aborted: list[int] = []
        self.committed: list[int] = []
        self.next_candidate = 0
        self.fail_prepare = False
        self.preflight_ok = True

    def capture_origin(self) -> Any:
        self.events.append("gw:capture")
        return self.origin

    def trial_from_origin(
        self, origin: Any, response: AffineCellResponse
    ) -> GroundwaterTrial:
        assert origin is self.origin
        self.trial_origins.append(origin)
        self.responses.append(response)
        self.next_candidate += 1
        token = self.next_candidate
        self.events.append(f"gw:trial:{token}")

        hbase = 0.45
        beta = 0.8
        slope = response.dq_u_dh_per_s
        head = (
            hbase
            + beta
            * (
                response.q_u_at_reference_m_per_s
                - slope * response.reference_head_m
            )
        ) / (1.0 - beta * slope)
        q = response.evaluate(head)
        return GroundwaterTrial(token, head, q)

    def discard_candidate(self, candidate: int) -> bool:
        self.events.append(f"gw:discard:{candidate}")
        self.discarded.append(candidate)
        return True

    def prepare_candidate(self, candidate: int) -> int:
        self.events.append(f"gw:prepare:{candidate}")
        if self.fail_prepare:
            raise RuntimeError("configured groundwater prepare failure")
        self.prepared.append(candidate)
        return candidate

    def abort_prepared(self, prepared: int) -> None:
        self.events.append(f"gw:abort:{prepared}")
        self.aborted.append(prepared)

    def publication_preflight(self, prepared: int) -> bool:
        self.events.append(f"gw:preflight:{prepared}")
        return self.preflight_ok

    def commit_prepared(self, prepared: int) -> None:
        self.events.append(f"gw:commit:{prepared}")
        self.committed.append(prepared)


class LedgerDouble:
    def __init__(self, events: list[str]) -> None:
        self.events = events
        self.staged: list[int] = []
        self.discarded: list[int] = []
        self.prepared: list[int] = []
        self.aborted: list[int] = []
        self.committed: list[int] = []
        self.fail_stage = False
        self.fail_prepare = False
        self.preflight_ok = True

    def stage(self, trial: SwapCorrectorTrial) -> int:
        token = int(trial.candidate)
        self.events.append(f"ledger:stage:{token}")
        if self.fail_stage:
            raise RuntimeError("configured ledger stage failure")
        self.staged.append(token)
        return token

    def discard_staged(self, staged: int) -> None:
        self.events.append(f"ledger:discard:{staged}")
        self.discarded.append(staged)

    def prepare(self, staged: int) -> int:
        self.events.append(f"ledger:prepare:{staged}")
        if self.fail_prepare:
            raise RuntimeError("configured ledger prepare failure")
        self.prepared.append(staged)
        return staged

    def abort_prepared(self, prepared: int) -> None:
        self.events.append(f"ledger:abort:{prepared}")
        self.aborted.append(prepared)

    def publication_preflight(self, prepared: int) -> bool:
        self.events.append(f"ledger:preflight:{prepared}")
        return self.preflight_ok

    def commit_prepared(self, prepared: int) -> None:
        self.events.append(f"ledger:commit:{prepared}")
        self.committed.append(prepared)


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def require_close(actual: float, expected: float, tolerance: float, message: str) -> None:
    if not math.isfinite(actual) or abs(actual - expected) > tolerance:
        raise AssertionError(
            f"{message}: actual={actual:.16g}, expected={expected:.16g}"
        )


def test_multiteration_convergence_and_same_origins() -> None:
    events: list[str] = []
    swap = SwapDouble(events)
    gw = GroundwaterDouble(events)
    ledger = LedgerDouble(events)

    result = run_window(
        swap,
        gw,
        ledger,
        CoupledServiceConfig(flux_tolerance_m_per_s=1.0e-6, max_outer_iterations=12),
    )

    require(result.status == CoupledServiceStatus.OK, f"unexpected status {result.status}")
    require(result.completed and result.committed, "successful route did not commit")
    require(result.outer_iterations == 9, "unexpected iteration count")
    require(swap.predictor_calls == 1, "predictor/tangent was rebuilt")
    require(all(origin is swap.origin for origin in swap.corrector_origins), "SWAP origin drift")
    require(all(origin is gw.origin for origin in gw.trial_origins), "groundwater origin drift")
    require(
        all(response.dq_u_dh_per_s == 0.2 for response in gw.responses),
        "tangent slope changed within coupling window",
    )

    require(len(swap.discarded) == 8, "nonconverged SWAP candidates not all discarded")
    require(len(gw.discarded) == 8, "nonconverged groundwater candidates not all discarded")
    require(swap.committed == [9], "exactly one final SWAP candidate not committed")
    require(gw.committed == [9], "exactly one final groundwater candidate not committed")
    require(ledger.committed == [9], "exactly one ledger publication not committed")

    require_close(result.final_head_m, 0.695681025257381, 1.0e-12, "final head mismatch")
    require_close(
        result.final_flux_residual_m_per_s,
        2.348958041964444e-7,
        1.0e-15,
        "final residual mismatch",
    )

    for k in range(1, 9):
        idx_gw_discard = events.index(f"gw:discard:{k}")
        idx_swap_discard = events.index(f"swap:discard:{k}")
        idx_next_gw_trial = events.index(f"gw:trial:{k+1}")
        require(
            idx_gw_discard < idx_next_gw_trial and idx_swap_discard < idx_next_gw_trial,
            f"candidate {k} survived into next iteration",
        )

    final = 9
    require(
        events.index(f"gw:prepare:{final}")
        < events.index(f"ledger:prepare:{final}")
        < events.index(f"swap:preflight:{final}")
        < events.index(f"swap:commit:{final}")
        < events.index(f"gw:commit:{final}")
        < events.index(f"ledger:commit:{final}"),
        "final publication order differs from existing SWAP5 governance",
    )

    print("FGC37_SAME_ACCEPTED_ORIGINS=PASS")
    print("FGC37_FIXED_TANGENT_WITHIN_WINDOW=PASS")
    print("FGC37_MULTITERATION_FLUX_CONVERGENCE=PASS")
    print("FGC37_NONCONVERGED_CANDIDATES_DISCARDED=PASS")
    print("FGC37_EXISTING_PUBLICATION_ORDER_PRESERVED=PASS")
    print("FGC37_EXACTLY_ONCE_FINAL_COMMIT=PASS")


def test_bounded_not_converged() -> None:
    events: list[str] = []
    swap = SwapDouble(events)
    gw = GroundwaterDouble(events)
    ledger = LedgerDouble(events)

    result = run_window(
        swap,
        gw,
        ledger,
        CoupledServiceConfig(flux_tolerance_m_per_s=1.0e-12, max_outer_iterations=3),
    )

    require(result.status == CoupledServiceStatus.NOT_CONVERGED, "bounded failure status mismatch")
    require(result.request_smaller_window, "nonconvergence did not request smaller window")
    require(not result.committed, "nonconverged route committed")
    require(len(swap.discarded) == 3, "last SWAP candidate not discarded on max iterations")
    require(len(gw.discarded) == 3, "last groundwater candidate not discarded on max iterations")
    require(not swap.committed and not gw.committed and not ledger.committed, "failure published state")

    print("FGC37_BOUNDED_NOT_CONVERGED_FAIL_CLOSED=PASS")


def test_prepare_failure_aborts_and_commits_nothing() -> None:
    events: list[str] = []
    swap = SwapDouble(events)
    gw = GroundwaterDouble(events)
    ledger = LedgerDouble(events)
    ledger.fail_prepare = True

    result = run_window(
        swap,
        gw,
        ledger,
        CoupledServiceConfig(flux_tolerance_m_per_s=1.0e-6, max_outer_iterations=12),
    )

    require(result.status == CoupledServiceStatus.LEDGER_PREPARE_FAILED, "prepare failure status mismatch")
    require(result.request_smaller_window, "prepare failure did not request smaller window")
    require(not result.committed, "prepare failure committed")
    require(gw.prepared == [9], "groundwater not prepared before ledger prepare")
    require(gw.aborted == [9], "prepared groundwater not aborted")
    require(9 in swap.discarded, "final SWAP candidate not discarded after prepare failure")
    require(not swap.committed and not gw.committed and not ledger.committed, "prepare failure published state")

    print("FGC37_PREPARE_FAILURE_ABORTS_ALL=PASS")


def main() -> None:
    test_multiteration_convergence_and_same_origins()
    test_bounded_not_converged()
    test_prepare_failure_aborts_and_commits_nothing()
    print("FGC37_COUPLED_HOST_CONTRACT_GATE=PASS")


if __name__ == "__main__":
    main()
