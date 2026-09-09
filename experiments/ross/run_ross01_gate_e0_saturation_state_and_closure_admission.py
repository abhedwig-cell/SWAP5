from __future__ import annotations

import json
import math
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import run_ross01_gate_c1 as c1

CONTRACT = "F-ROSS01_GATE_E0_SATURATION_STATE_AND_CLOSURE_ADMISSION_CONTRACT.json"
CATALOG = Path("integration/f-ross/F-ROSS01_GATE_C1_MATERIAL_CATALOG.json")
WITNESS_HEADS = (-1.0, -0.1, -0.001, 0.0, 1.0, 10.0, 100.0)
SAT_HEADS = (0.0, 1.0, 10.0, 100.0)
C1R_H_MAX = -1.0
SATURATION_H = 0.0
THETA_TOL = 2.0e-15


def theta_of_h(h: float) -> float:
    if h >= 0.0:
        return float(c1.core.THETA_S)
    s = float(c1.core.s_of_h(h))
    return float(c1.core.THETA_R + (c1.core.THETA_S - c1.core.THETA_R) * s)


def run_material(row: dict) -> dict:
    c1.configure_core(row)
    theta_s = float(c1.core.THETA_S)
    ksat = float(c1.core.KSAT)

    witnesses = []
    nonfinite = 0
    for h in WITNESS_HEADS:
        s = float(c1.core.s_of_h(h))
        theta = theta_of_h(h)
        k = float(c1.core.k_of_h(h))
        inv_h = float(c1.core.h_of_s(s))
        vals = (s, theta, k, inv_h)
        nonfinite += sum(not math.isfinite(v) for v in vals)
        witnesses.append({
            "h_cm": h,
            "effective_saturation": s,
            "theta": theta,
            "K_cm_per_day": k,
            "inverse_h_from_S_cm": inv_h,
        })

    sat_rows = [w for w in witnesses if w["h_cm"] >= 0.0]
    max_theta_plateau_error = max(abs(w["theta"] - theta_s) for w in sat_rows)
    max_k_plateau_error = max(abs(w["K_cm_per_day"] - ksat) for w in sat_rows)
    max_s_plateau_error = max(abs(w["effective_saturation"] - 1.0) for w in sat_rows)
    inverse_saturated_heads = sorted({w["inverse_h_from_S_cm"] for w in sat_rows})
    positive_heads = [w["h_cm"] for w in sat_rows]
    distinct_positive_heads = len(set(positive_heads)) == len(positive_heads)
    theta_values = [w["theta"] for w in sat_rows]
    k_values = [w["K_cm_per_day"] for w in sat_rows]
    theta_plateau_single_value = max(theta_values) - min(theta_values) <= THETA_TOL
    k_plateau_single_value = max(k_values) - min(k_values) == 0.0
    inverse_collapses_to_boundary = inverse_saturated_heads == [0.0]

    below = next(w for w in witnesses if w["h_cm"] == -1.0)
    just_below = next(w for w in witnesses if w["h_cm"] == -0.001)
    tests = {
        "saturated_S_plateau": max_s_plateau_error == 0.0,
        "saturated_theta_plateau": max_theta_plateau_error <= THETA_TOL and theta_plateau_single_value,
        "saturated_K_plateau": max_k_plateau_error == 0.0 and k_plateau_single_value,
        "distinct_saturated_heads": distinct_positive_heads,
        "inverse_collapses_saturated_states_to_h0": inverse_collapses_to_boundary,
        "theta_at_minus1_is_unsaturated": below["theta"] < theta_s,
        "theta_approaches_theta_s_from_below": below["theta"] < just_below["theta"] < theta_s,
        "no_nonfinite": nonfinite == 0,
    }
    return {
        "material": row["sfu"],
        "theta_s": theta_s,
        "ksatfit_cm_per_day": ksat,
        "max_saturated_S_plateau_error": max_s_plateau_error,
        "max_saturated_theta_plateau_error": max_theta_plateau_error,
        "max_saturated_K_plateau_error": max_k_plateau_error,
        "distinct_saturated_head_count": len(set(positive_heads)),
        "distinct_theta_count_over_saturated_witnesses": len(set(theta_values)),
        "distinct_K_count_over_saturated_witnesses": len(set(k_values)),
        "inverse_saturated_head_values_cm": inverse_saturated_heads,
        "theta_minus1_gap_to_theta_s": theta_s - below["theta"],
        "theta_minus0p001_gap_to_theta_s": theta_s - just_below["theta"],
        "nonfinite_count": nonfinite,
        "tests": tests,
        "witnesses": witnesses,
        "pass": all(tests.values()),
    }


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit("usage: run_ross01_gate_e0_saturation_state_and_closure_admission.py OUTPUT.json")
    out = Path(sys.argv[1])
    catalog = json.loads(CATALOG.read_text())
    rows = [run_material(row) for row in catalog["rows"]]
    pass_count = sum(row["pass"] for row in rows)
    max_theta_error = max(row["max_saturated_theta_plateau_error"] for row in rows)
    max_k_error = max(row["max_saturated_K_plateau_error"] for row in rows)
    max_s_error = max(row["max_saturated_S_plateau_error"] for row in rows)
    nonfinite = sum(row["nonfinite_count"] for row in rows)
    inverse_all_zero = all(row["inverse_saturated_head_values_cm"] == [0.0] for row in rows)
    theta_only_noninjective = all(
        row["distinct_saturated_head_count"] == len(SAT_HEADS)
        and row["distinct_theta_count_over_saturated_witnesses"] == 1
        for row in rows
    )
    k_plateau_noninjective = all(row["distinct_K_count_over_saturated_witnesses"] == 1 for row in rows)
    c1r_gap_exists = C1R_H_MAX < SATURATION_H
    passed = (
        pass_count == len(rows)
        and theta_only_noninjective
        and k_plateau_noninjective
        and inverse_all_zero
        and c1r_gap_exists
        and nonfinite == 0
    )
    result = {
        "schema_version": 1,
        "workstream": "F-ROSS",
        "work_unit": "F-ROSS01",
        "gate": "E0_SATURATION_STATE_AND_CLOSURE_ADMISSION",
        "contract": CONTRACT,
        "production_implementation": False,
        "material_count": len(rows),
        "material_pass_count": pass_count,
        "witness_heads_cm": list(WITNESS_HEADS),
        "saturated_witness_heads_cm": list(SAT_HEADS),
        "qualified_C1R_upper_head_cm": C1R_H_MAX,
        "saturation_boundary_head_cm": SATURATION_H,
        "unqualified_near_saturation_gap_width_cm": SATURATION_H - C1R_H_MAX,
        "max_saturated_S_plateau_error": max_s_error,
        "max_saturated_theta_plateau_error": max_theta_error,
        "max_saturated_K_plateau_error": max_k_error,
        "nonfinite_count": nonfinite,
        "theta_only_state_is_noninjective_in_saturated_regime": theta_only_noninjective,
        "K_plateau_also_does_not_encode_saturated_head": k_plateau_noninjective,
        "inverse_S_to_h_collapses_all_saturated_witnesses_to_h0": inverse_all_zero,
        "C1R_does_not_cover_minus1_to_zero_near_saturation_interval": c1r_gap_exists,
        "state_admission": {
            "pure_theta_only_across_saturation": "REJECTED",
            "required": "retain explicit saturated pressure-head degree of freedom",
            "unified_head_state": "CANDIDATE_NOT_SELECTED_BY_E0",
            "mixed_Ross_state": "CANDIDATE_NOT_SELECTED_BY_E0",
        },
        "rows": rows,
        "pass": passed,
        "decision": (
            "SATURATION_REQUIRES_EXPLICIT_HEAD_DOF_AND_SEPARATE_NEAR_SATURATION_CLOSURE_READY_FOR_E1_TRANSITION_DESIGN"
            if passed else
            "SATURATION_STATE_ASSUMPTION_NOT_CONFIRMED_RECONCILE_CONSTITUTIVE_SEMANTICS_BEFORE_E1"
        ),
    }
    out.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
    print(json.dumps({k: v for k, v in result.items() if k != "rows"}, sort_keys=True), flush=True)
    raise SystemExit(0 if passed else 1)


if __name__ == "__main__":
    main()
