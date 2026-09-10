from __future__ import annotations

import json
import math
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import run_ross01_gate_e3h_a6_o14_postcap_reference_topology as a6

CONTRACT = "F-ROSS01_GATE_E3H_A6_R1_O14_INDEPENDENT_UNSATURATED_ATTRACTOR_CONFIRMATION_PRECOMMIT.json"
MATERIAL = "O14"
SCHEDULE = ((40, 0.025),)
STEADY_STARTS = (
    (-0.3,-4.0,-9.0),
    (-0.8,-4.5,-9.5),
    (-2.0,-7.0,-12.0),
    (-0.1,-2.0,-6.0),
)
MASS_TOL = 1.0e-9
SAT_MARGIN = -0.001
STEADY_MARGIN = -0.01
FINAL_STEADY_TOL = 0.005
COMMON_STEADY_TOL = 0.001


def run_profile(row: dict, profile_id: str) -> dict:
    a6.SCHEDULE = SCHEDULE
    a6.STEADY_STARTS = STEADY_STARTS
    cap = a6.CAP_STATES[profile_id]
    a6.configure(row)
    tendency = a6.initial_tendency(cap, row)
    traj = a6.transient(cap, row)
    steady = a6.steady_roots(row)
    rep = steady["representative"]
    final = traj.get("final_heads_cm")
    final_steady_diff = math.inf
    if final is not None and rep is not None:
        final_steady_diff = max(abs(float(x)-float(y)) for x,y in zip(final,rep["heads_cm"]))
    tests = {
        "transient_complete": traj["complete"] is True,
        "transient_step_count": traj["accepted_step_count"] == 40,
        "transient_horizon": abs(float(traj["horizon_day"])-1.0) <= 1e-14,
        "transient_mass": float(traj["max_abs_balance_residual_cm"]) <= MASS_TOL,
        "top_stays_below_saturation_margin": float(traj["max_top_head_cm"]) < SAT_MARGIN,
        "top_saturation_approach_count_zero": int(traj["top_saturation_approach_count"]) == 0,
        "runoff_nonnegative": float(traj["cumulative_runoff_cm"]) >= 0.0,
        "steady_reproducible": rep is not None and int(steady["reproducible_cluster_count"]) >= 1,
        "steady_minimum_independent_starts": rep is not None and int(steady["clusters"][0]["member_count"]) >= 2,
        "steady_top_negative_margin": rep is not None and float(rep["heads_cm"][0]) < STEADY_MARGIN,
        "final_matches_steady": final_steady_diff <= FINAL_STEADY_TOL,
    }
    return {
        "profile_id": profile_id,
        "cap_heads_cm": list(cap),
        "initial_top_storage_rate_cm_per_day": tendency["top_storage_rate_cm_per_day"],
        "initial_top_tendency_sign_is_admission_criterion": False,
        "transient_summary": {k:v for k,v in traj.items() if k != "records"},
        "steady": steady,
        "final_to_steady_max_abs_head_difference_cm": final_steady_diff,
        "tests": tests,
        "failed_metrics": [k for k,v in tests.items() if not v],
        "pass": all(tests.values()),
    }


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit("usage: run_ross01_gate_e3h_a6_r1_o14_independent_attractor_confirmation.py PROFILE OUTPUT.json")
    profile = sys.argv[1]
    if profile not in a6.CAP_STATES:
        raise SystemExit(profile)
    catalog = json.loads(a6.CATALOG.read_text(encoding="utf-8"))
    row = next(r for r in catalog["rows"] if r["sfu"] == MATERIAL)
    pr = run_profile(row, profile)
    payload = {
        "schema_version": 1,
        "workstream": "F-ROSS",
        "work_unit": "F-ROSS01",
        "gate": "E3H_A6_R1_O14_INDEPENDENT_POST_CAP_UNSATURATED_ATTRACTOR_CONFIRMATION",
        "contract": CONTRACT,
        "production_implementation": False,
        "qualification_use": True,
        "material": MATERIAL,
        "profile_result": pr,
        "pass": pr["pass"],
        "decision": (
            "QUALIFIED_RESTRICTED_O14_POST_CAP_UNSATURATED_ATTRACTOR_WITHIN_FROZEN_1CM_SURFACE_CAP_TOPOLOGY_READY_FOR_RUNOFF_CONTINUATION_COMPOSITION"
            if pr["pass"] else
            "O14_POST_CAP_UNSATURATED_ATTRACTOR_NOT_INDEPENDENTLY_CONFIRMED_PRESERVE_A6_CHARACTERIZATION_ONLY"
        ),
        "hard_nonclaims": [
            "No production Ross candidate continuation qualification.",
            "No claim for a different surface cap, bottom boundary or O14 parameterization.",
            "No automatic runoff event detector qualification.",
            "No response tangent, MultiSWAP, MODFLOW or groundwater admission."
        ],
    }
    out = Path(sys.argv[2])
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(payload, indent=2, sort_keys=True)+"\n", encoding="utf-8")
    rep = pr["steady"]["representative"]
    print(json.dumps({
        "profile": profile,
        "pass": pr["pass"],
        "decision": payload["decision"],
        "initial_top_storage_rate_cm_per_day": pr["initial_top_storage_rate_cm_per_day"],
        "max_top_head_cm": pr["transient_summary"].get("max_top_head_cm"),
        "final_heads_cm": pr["transient_summary"].get("final_heads_cm"),
        "steady_heads_cm": None if rep is None else rep["heads_cm"],
        "final_to_steady_max_abs_head_difference_cm": pr["final_to_steady_max_abs_head_difference_cm"],
        "max_abs_balance_residual_cm": pr["transient_summary"].get("max_abs_balance_residual_cm"),
        "failed_metrics": pr["failed_metrics"],
    }, sort_keys=True), flush=True)
    if not pr["pass"]:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
