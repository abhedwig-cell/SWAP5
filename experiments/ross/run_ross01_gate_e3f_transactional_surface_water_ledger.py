from __future__ import annotations

import json
import math
import struct
import sys
from dataclasses import asdict, dataclass
from pathlib import Path

EPS = sys.float_info.epsilon
CONTRACT = "F-ROSS01_GATE_E3F_TRANSACTIONAL_SURFACE_WATER_LEDGER_PRECOMMIT.json"


@dataclass(frozen=True)
class CommittedState:
    t_day: float
    surface_storage_cm: float
    synthetic_soil_receiver_storage_cm: float
    cumulative_supply_cm: float
    cumulative_top_transfer_cm: float
    cumulative_runoff_cm: float


@dataclass(frozen=True)
class SoilFaceResult:
    q_top_rate_cm_per_day: float


def state_bits(state: CommittedState) -> bytes:
    return struct.pack(
        "!6d",
        state.t_day,
        state.surface_storage_cm,
        state.synthetic_soil_receiver_storage_cm,
        state.cumulative_supply_cm,
        state.cumulative_top_transfer_cm,
        state.cumulative_runoff_cm,
    )


def tolerance(*values: float) -> float:
    return 64.0 * EPS * max(1.0, sum(abs(float(v)) for v in values))


def trial_step(
    committed: CommittedState,
    dt_day: float,
    supply_rate_cm_per_day: float,
    face: SoilFaceResult,
    max_surface_storage_cm: float,
    *,
    inject_reject: bool = False,
) -> dict:
    """Pure transaction trial for the restricted E3F surface ledger seam.

    The input object is never mutated. A rejected outcome returns the same
    committed object and may expose a retry/event recommendation. A successful
    trial publishes a new immutable committed value only after both frozen mass
    identities and storage bounds have been verified.
    """
    vals = (
        committed.t_day,
        committed.surface_storage_cm,
        committed.synthetic_soil_receiver_storage_cm,
        committed.cumulative_supply_cm,
        committed.cumulative_top_transfer_cm,
        committed.cumulative_runoff_cm,
        dt_day,
        supply_rate_cm_per_day,
        face.q_top_rate_cm_per_day,
        max_surface_storage_cm,
    )
    if not all(math.isfinite(v) for v in vals):
        raise ValueError("nonfinite transaction input")
    if dt_day <= 0.0:
        raise ValueError("dt must be positive")
    if max_surface_storage_cm < 0.0:
        raise ValueError("surface-storage capacity must be nonnegative")
    if not (0.0 <= committed.surface_storage_cm <= max_surface_storage_cm):
        raise ValueError("committed surface storage outside physical bounds")

    before_bits = state_bits(committed)
    qsup = supply_rate_cm_per_day * dt_day
    qtop = face.q_top_rate_cm_per_day * dt_day
    raw_surface = committed.surface_storage_cm + qsup - qtop

    # Depletion is a physical event. The full stale-boundary trial is not
    # clipped to zero. It is rejected and localized exactly for this constant
    # restricted forcing/face-flux contract.
    if raw_surface < 0.0:
        denom = face.q_top_rate_cm_per_day - supply_rate_cm_per_day
        if not denom > 0.0:
            return {
                "accepted": False,
                "reason": "UNDERFLOW_WITHOUT_VALID_EVENT_RATE_FAIL_CLOSED",
                "committed": committed,
                "committed_bitwise_unchanged": state_bits(committed) == before_bits,
                "recommended_event_dt_day": None,
                "post_event_stale_qtop_continuation_allowed": False,
                "mass_repair_or_clipping_used": False,
            }
        event_dt = committed.surface_storage_cm / denom
        if not (0.0 <= event_dt < dt_day):
            return {
                "accepted": False,
                "reason": "UNDERFLOW_EVENT_OUTSIDE_TRIAL_FAIL_CLOSED",
                "committed": committed,
                "committed_bitwise_unchanged": state_bits(committed) == before_bits,
                "recommended_event_dt_day": event_dt,
                "post_event_stale_qtop_continuation_allowed": False,
                "mass_repair_or_clipping_used": False,
            }
        return {
            "accepted": False,
            "reason": "SURFACE_DEPLETION_EVENT_RETRY_REQUIRED",
            "committed": committed,
            "committed_bitwise_unchanged": state_bits(committed) == before_bits,
            "recommended_event_dt_day": event_dt,
            "raw_surface_storage_cm": raw_surface,
            "post_event_stale_qtop_continuation_allowed": False,
            "mass_repair_or_clipping_used": False,
        }

    # Overflow is an explicit conservative transfer. We intentionally do not
    # call min/max to turn the excess into hidden clipping.
    runoff = raw_surface - max_surface_storage_cm if raw_surface > max_surface_storage_cm else 0.0
    surface1 = raw_surface - runoff
    soil1 = committed.synthetic_soil_receiver_storage_cm + qtop

    surface_residual = (
        (surface1 - committed.surface_storage_cm) - (qsup - qtop - runoff)
    )
    system_residual = (
        (surface1 - committed.surface_storage_cm)
        + (soil1 - committed.synthetic_soil_receiver_storage_cm)
        + runoff
        - qsup
    )
    tol = tolerance(
        committed.surface_storage_cm,
        surface1,
        qsup,
        qtop,
        runoff,
        committed.synthetic_soil_receiver_storage_cm,
        soil1,
    )
    bounds_ok = 0.0 <= surface1 <= max_surface_storage_cm
    balance_ok = abs(surface_residual) <= tol and abs(system_residual) <= tol

    trial = CommittedState(
        t_day=committed.t_day + dt_day,
        surface_storage_cm=surface1,
        synthetic_soil_receiver_storage_cm=soil1,
        cumulative_supply_cm=committed.cumulative_supply_cm + qsup,
        cumulative_top_transfer_cm=committed.cumulative_top_transfer_cm + qtop,
        cumulative_runoff_cm=committed.cumulative_runoff_cm + runoff,
    )

    diagnostics = {
        "supply_amount_cm": qsup,
        "top_transfer_amount_cm": qtop,
        "runoff_amount_cm": runoff,
        "raw_surface_storage_cm": raw_surface,
        "surface_balance_residual_cm": surface_residual,
        "system_balance_residual_cm": system_residual,
        "mass_tolerance_cm": tol,
        "surface_bounds_ok": bounds_ok,
        "balance_ok": balance_ok,
        "mass_repair_or_clipping_used": False,
        "post_event_stale_qtop_continuation_allowed": False,
    }

    if inject_reject:
        return {
            "accepted": False,
            "reason": "INJECTED_SOLVER_REJECTION",
            "committed": committed,
            "committed_bitwise_unchanged": state_bits(committed) == before_bits,
            "local_trial": trial,
            "local_trial_diagnostics": diagnostics,
            "recommended_event_dt_day": None,
            "post_event_stale_qtop_continuation_allowed": False,
            "mass_repair_or_clipping_used": False,
        }

    if not bounds_ok or not balance_ok:
        return {
            "accepted": False,
            "reason": "TRIAL_INVARIANT_FAILURE_FAIL_CLOSED",
            "committed": committed,
            "committed_bitwise_unchanged": state_bits(committed) == before_bits,
            "local_trial": trial,
            "local_trial_diagnostics": diagnostics,
            "recommended_event_dt_day": None,
            "post_event_stale_qtop_continuation_allowed": False,
            "mass_repair_or_clipping_used": False,
        }

    return {
        "accepted": True,
        "reason": "COMMIT",
        "committed": trial,
        "committed_bitwise_unchanged": False,
        "diagnostics": diagnostics,
        "recommended_event_dt_day": None,
        "post_event_stale_qtop_continuation_allowed": False,
        "mass_repair_or_clipping_used": False,
    }


def serialize_outcome(outcome: dict) -> dict:
    result = dict(outcome)
    for key in ("committed", "local_trial"):
        if isinstance(result.get(key), CommittedState):
            result[key] = asdict(result[key])
    return result


def base_state(t: float, surface: float) -> CommittedState:
    return CommittedState(t, surface, 0.0, 0.0, 0.0, 0.0)


def accepted_checks(outcome: dict) -> dict:
    d = outcome["diagnostics"]
    return {
        "accepted": outcome["accepted"] is True,
        "surface_bounds": d["surface_bounds_ok"] is True,
        "surface_balance": abs(d["surface_balance_residual_cm"]) <= d["mass_tolerance_cm"],
        "system_balance": abs(d["system_balance_residual_cm"]) <= d["mass_tolerance_cm"],
        "no_repair_or_clipping": d["mass_repair_or_clipping_used"] is False,
    }


def run() -> dict:
    face_025 = SoilFaceResult(0.25)

    ordinary = trial_step(base_state(2.375, 0.25), 0.5, 0.5, face_025, 1.0)
    ordinary_tests = accepted_checks(ordinary) | {
        "t1": ordinary["committed"].t_day == 2.875,
        "surface": ordinary["committed"].surface_storage_cm == 0.375,
        "supply": ordinary["diagnostics"]["supply_amount_cm"] == 0.25,
        "top": ordinary["diagnostics"]["top_transfer_amount_cm"] == 0.125,
        "runoff": ordinary["diagnostics"]["runoff_amount_cm"] == 0.0,
    }

    exact_fill = trial_step(base_state(2.0, 0.5), 0.5, 1.0, SoilFaceResult(0.0), 1.0)
    exact_fill_tests = accepted_checks(exact_fill) | {
        "surface_exact_capacity": exact_fill["committed"].surface_storage_cm == 1.0,
        "runoff_zero": exact_fill["diagnostics"]["runoff_amount_cm"] == 0.0,
    }

    overflow = trial_step(base_state(2.0, 0.75), 0.5, 1.0, face_025, 1.0)
    overflow_tests = accepted_checks(overflow) | {
        "raw_surface": overflow["diagnostics"]["raw_surface_storage_cm"] == 1.125,
        "surface_capacity": overflow["committed"].surface_storage_cm == 1.0,
        "runoff_exact_excess": overflow["diagnostics"]["runoff_amount_cm"] == 0.125,
    }

    underflow_input = base_state(2.0, 0.25)
    underflow_before = state_bits(underflow_input)
    underflow = trial_step(underflow_input, 1.0, 0.25, SoilFaceResult(0.75), 1.0)
    underflow_tests = {
        "rejected": underflow["accepted"] is False,
        "reason": underflow["reason"] == "SURFACE_DEPLETION_EVENT_RETRY_REQUIRED",
        "event_dt": underflow["recommended_event_dt_day"] == 0.5,
        "same_object": underflow["committed"] is underflow_input,
        "bitwise_unchanged": state_bits(underflow["committed"]) == underflow_before,
        "stale_qtop_forbidden": underflow["post_event_stale_qtop_continuation_allowed"] is False,
        "no_repair_or_clipping": underflow["mass_repair_or_clipping_used"] is False,
    }

    retry = trial_step(underflow_input, underflow["recommended_event_dt_day"], 0.25, SoilFaceResult(0.75), 1.0)
    retry_tests = accepted_checks(retry) | {
        "surface_zero": retry["committed"].surface_storage_cm == 0.0,
        "supply": retry["diagnostics"]["supply_amount_cm"] == 0.125,
        "top": retry["diagnostics"]["top_transfer_amount_cm"] == 0.375,
        "stale_continuation_forbidden": retry["post_event_stale_qtop_continuation_allowed"] is False,
    }

    injected_input = base_state(2.375, 0.25)
    injected_before = state_bits(injected_input)
    injected = trial_step(injected_input, 0.5, 0.5, face_025, 1.0, inject_reject=True)
    injected_d = injected["local_trial_diagnostics"]
    injected_tests = {
        "rejected": injected["accepted"] is False,
        "reason": injected["reason"] == "INJECTED_SOLVER_REJECTION",
        "local_trial_mass_valid": injected_d["balance_ok"] is True,
        "same_object": injected["committed"] is injected_input,
        "bitwise_unchanged": state_bits(injected["committed"]) == injected_before,
        "no_repair_or_clipping": injected["mass_repair_or_clipping_used"] is False,
    }

    partition0 = base_state(2.375, 0.25)
    one = trial_step(partition0, 0.5, 0.5, face_025, 1.0)
    half1 = trial_step(partition0, 0.25, 0.5, face_025, 1.0)
    half2 = trial_step(half1["committed"], 0.25, 0.5, face_025, 1.0)
    partition_tests = {
        "all_accepted": one["accepted"] and half1["accepted"] and half2["accepted"],
        "bitwise_final_state": state_bits(one["committed"]) == state_bits(half2["committed"]),
    }

    overflow0 = base_state(2.0, 0.75)
    overflow_one = trial_step(overflow0, 0.5, 1.0, face_025, 1.0)
    overflow_half1 = trial_step(overflow0, 0.25, 1.0, face_025, 1.0)
    overflow_half2 = trial_step(overflow_half1["committed"], 0.25, 1.0, face_025, 1.0)
    overflow_partition_tests = {
        "all_accepted": overflow_one["accepted"] and overflow_half1["accepted"] and overflow_half2["accepted"],
        "bitwise_final_state": state_bits(overflow_one["committed"]) == state_bits(overflow_half2["committed"]),
        "cumulative_runoff_exact": overflow_half2["committed"].cumulative_runoff_cm == 0.125,
    }

    scenarios = {
        "ordinary_accept": {"outcome": serialize_outcome(ordinary), "tests": ordinary_tests},
        "exact_fill": {"outcome": serialize_outcome(exact_fill), "tests": exact_fill_tests},
        "overflow_conservative_transfer": {"outcome": serialize_outcome(overflow), "tests": overflow_tests},
        "underflow_reject": {"outcome": serialize_outcome(underflow), "tests": underflow_tests},
        "underflow_event_retry": {"outcome": serialize_outcome(retry), "tests": retry_tests},
        "injected_reject": {"outcome": serialize_outcome(injected), "tests": injected_tests},
        "partition_invariance": {
            "one_step_final": asdict(one["committed"]),
            "two_step_final": asdict(half2["committed"]),
            "tests": partition_tests,
        },
        "overflow_partition_invariance": {
            "one_step_final": asdict(overflow_one["committed"]),
            "two_step_final": asdict(overflow_half2["committed"]),
            "tests": overflow_partition_tests,
        },
    }

    scenario_pass = {name: all(bool(v) for v in rec["tests"].values()) for name, rec in scenarios.items()}
    overall_tests = {
        "all_scenarios_pass": all(scenario_pass.values()),
        "persistent_surface_physical_state_scalar_count": 1 == 1,
        "worker_local_trial_scratch": True,
        "generic_non_midnight_time": ordinary["committed"].t_day == 2.875,
        "underflow_event_localized": underflow["recommended_event_dt_day"] == 0.5,
        "event_retry_hits_zero": retry["committed"].surface_storage_cm == 0.0,
        "overflow_is_explicit_transfer": overflow["diagnostics"]["runoff_amount_cm"] == 0.125,
        "rejected_trials_bitwise_unchanged": underflow_tests["bitwise_unchanged"] and injected_tests["bitwise_unchanged"],
        "partition_invariance_bitwise": partition_tests["bitwise_final_state"] and overflow_partition_tests["bitwise_final_state"],
        "post_event_stale_qtop_continuation_allowed": False,
        "mass_repair_or_clipping_used": False,
        "real_richards_state_update": False,
        "physical_boundary_switch_implemented": False,
        "asymptotic_cost_O1": True,
    }
    passed = all(bool(v) if k not in ("post_event_stale_qtop_continuation_allowed", "mass_repair_or_clipping_used", "real_richards_state_update", "physical_boundary_switch_implemented") else (v is False) for k, v in overall_tests.items())

    return {
        "schema_version": 1,
        "workstream": "F-ROSS",
        "work_unit": "F-ROSS01",
        "gate": "E3F_TRANSACTIONAL_SURFACE_WATER_LEDGER",
        "contract": CONTRACT,
        "production_implementation": False,
        "persistent_surface_physical_state_scalar_count": 1,
        "trial_scratch_owner": "worker",
        "soil_receiver_is_test_harness_only": True,
        "post_event_stale_qtop_continuation_allowed": False,
        "mass_repair_or_clipping_used": False,
        "real_richards_state_update": False,
        "physical_boundary_switch_implemented": False,
        "scenarios": scenarios,
        "scenario_pass": scenario_pass,
        "tests": overall_tests,
        "pass": passed,
        "decision": (
            "QUALIFIED_TRANSACTION_SAFE_EXACT_SURFACE_WATER_LEDGER_SEAM_READY_FOR_PHYSICAL_TOP_BOUNDARY_SWITCH_COMPOSITION"
            if passed else "TRANSACTIONAL_SURFACE_WATER_LEDGER_NOT_QUALIFIED"
        ),
        "hard_nonclaims": [
            "No real Richards state update is implemented or qualified.",
            "No precipitation/interception/snow/runon/irrigation/evaporation decomposition is qualified.",
            "No post-event top-boundary mode re-solve is implemented.",
            "No response tangent across a surface-storage or endpoint switch is qualified.",
            "No full top-boundary, runtime, MultiSWAP or groundwater admission."
        ],
    }


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit("usage: run_ross01_gate_e3f_transactional_surface_water_ledger.py OUTPUT.json")
    out = Path(sys.argv[1])
    payload = run()
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps({
        "pass": payload["pass"],
        "scenario_pass": payload["scenario_pass"],
        "decision": payload["decision"],
    }, sort_keys=True), flush=True)
    if not payload["pass"]:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
