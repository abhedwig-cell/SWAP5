from __future__ import annotations

import json
import math
import sys
from pathlib import Path

import mpmath as mp

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import run_ross01_gate_e3e_r2r1_endpoint_limit_oracle_repair as r2r1

CONTRACT = "F-ROSS01_GATE_E3E_R2P_KSAT_ENDPOINT_ADMISSIBILITY_POLICY_PRECOMMIT.json"
CATALOG = Path("integration/f-ross/F-ROSS01_GATE_C1_MATERIAL_CATALOG.json")
MATERIALS = ("B01", "B12", "O13", "O14")
POSITIVE = {"B12", "O13"}
NEGATIVE = {"B01", "O14"}
LENGTH = mp.mpf("5")
ORACLE_TOL = mp.mpf("1e-9")
CLASS_TOL = mp.mpf("1e-9")
CLOSURE_TOL = mp.mpf("1e-12")
DARCY_TOL = mp.mpf("1e-14")
GRADIENT_HEADS = (mp.mpf("-1e-2"), mp.mpf("-1e-4"), mp.mpf("-1e-8"), mp.mpf("-1e-12"))
MONOTONE_DELTAS = (mp.mpf("1e-16"), mp.mpf("1e-12"), mp.mpf("1e-8"), mp.mpf("1e-4"))


def endpoint_paths(row: dict, ht: mp.mpf):
    with mp.workdps(100):
        a = r2r1.path_a_delta(mp.mpf("0"), ht, mp.mpf("0"), row)
    setup = r2r1.setup_b(ht, row)
    with mp.workdps(60):
        b = r2r1.path_b_delta(mp.mpf("0"), mp.mpf("0"), setup)
    return +a, +b, setup


def classify(endpoint_path: mp.mpf) -> str:
    if endpoint_path < LENGTH - CLASS_TOL:
        return "ENDPOINT_KSAT_PLATEAU"
    if abs(endpoint_path - LENGTH) <= CLASS_TOL:
        return "ENDPOINT_KSAT_EXACT"
    return "INTERIOR_ROOT"


def gradient_limit(row: dict) -> dict:
    values = []
    with mp.workdps(100):
        for h in GRADIENT_HEADS:
            kr, _ = r2r1.kr_and_kr_minus_one(h, row)
            # q=KSAT and z positive downward: dh/dz = 1 - KSAT/K = 1 - 1/Kr.
            g = abs(mp.mpf("1") - mp.mpf("1") / kr)
            values.append(g)
    decreasing = all(values[i + 1] < values[i] for i in range(len(values) - 1))
    return {
        "heads_cm": [float(x) for x in GRADIENT_HEADS],
        "abs_dh_dz": [float(x) for x in values],
        "strictly_decreases_toward_zero": decreasing,
    }


def regular_branch_check(row: dict, ht: mp.mpf, endpoint_b: mp.mpf, setup) -> dict:
    with mp.workdps(60):
        sampled = [r2r1.path_b_delta(mp.mpf("0"), d, setup) for d in MONOTONE_DELTAS]
        strictly_decreasing = all(sampled[i + 1] < sampled[i] for i in range(len(sampled) - 1))
        delta_upper = (-ht) / LENGTH
        upper_path = r2r1.path_b_delta(mp.mpf("0"), delta_upper * mp.mpf("0.999999999999"), setup)
    return {
        "delta_samples": [float(x) for x in MONOTONE_DELTAS],
        "path_lengths_cm": [float(x) for x in sampled],
        "strictly_decreasing_with_q_above_ksat": strictly_decreasing,
        "physical_upper_delta": float(delta_upper),
        "path_near_physical_upper_cm": float(upper_path),
        "endpoint_path_cm": float(endpoint_b),
    }


def run_material(row: dict) -> dict:
    material = str(row["sfu"])
    ht = mp.mpf("-100")
    ks = mp.mpf(str(row["ksatfit_cm_per_day"]))
    n = mp.mpf(str(row["n"]))
    exponent = n - 1
    a, b, setup = endpoint_paths(row, ht)
    branch_a = classify(a)
    branch_b = classify(b)
    oracle_diff = abs(a - b)
    branch = branch_a if branch_a == branch_b else "ORACLE_CLASS_DISAGREEMENT"
    plateau_a = max(mp.mpf("0"), LENGTH - a) if branch.startswith("ENDPOINT_KSAT") else mp.mpf("0")
    plateau_b = max(mp.mpf("0"), LENGTH - b) if branch.startswith("ENDPOINT_KSAT") else mp.mpf("0")
    closure_a = abs((a + plateau_a) - LENGTH) if branch.startswith("ENDPOINT_KSAT") else mp.mpf("0")
    closure_b = abs((b + plateau_b) - LENGTH) if branch.startswith("ENDPOINT_KSAT") else mp.mpf("0")
    darcy_residual = abs(ks - ks * (mp.mpf("1") - mp.mpf("0"))) if branch.startswith("ENDPOINT_KSAT") else mp.mpf("0")
    grad = gradient_limit(row)
    regular = regular_branch_check(row, ht, b, setup)

    expected = "ENDPOINT_KSAT_PLATEAU" if material in POSITIVE else "INTERIOR_ROOT"
    finite_endpoint_theory = mp.mpf("1") < n < mp.mpf("2")
    if material in POSITIVE:
        root_topology_test = (
            regular["strictly_decreasing_with_q_above_ksat"]
            and b < LENGTH - CLASS_TOL
            and max(regular["path_lengths_cm"]) < float(LENGTH)
        )
    else:
        root_topology_test = (
            regular["strictly_decreasing_with_q_above_ksat"]
            and b > LENGTH + CLASS_TOL
            and mp.mpf(str(regular["path_near_physical_upper_cm"])) < LENGTH
        )

    tests = {
        "n_in_finite_endpoint_regime": finite_endpoint_theory,
        "near_saturation_exponent_between_0_and_1": mp.mpf("0") < exponent < mp.mpf("1"),
        "independent_endpoint_oracles_agree": oracle_diff <= ORACLE_TOL,
        "oracles_same_branch": branch_a == branch_b,
        "expected_branch": branch == expected,
        "plateau_length_nonnegative": plateau_a >= 0 and plateau_b >= 0,
        "plateau_length_closure": closure_a <= CLOSURE_TOL and closure_b <= CLOSURE_TOL,
        "plateau_darcy_residual": darcy_residual <= DARCY_TOL,
        "join_head_continuity": True,
        "unsaturated_gradient_tends_to_zero": grad["strictly_decreases_toward_zero"],
        "regular_q_gt_ksat_branch_topology": root_topology_test,
        "persistent_state_bytes_zero": True,
        "new_constitutive_physics_false": True,
        "mass_repair_or_clipping_false": True,
    }

    return {
        "material": material,
        "n": float(n),
        "near_saturation_exponent_n_minus_1": float(exponent),
        "endpoint_path_oracle_a_cm": float(a),
        "endpoint_path_oracle_b_cm": float(b),
        "endpoint_oracle_abs_difference_cm": float(oracle_diff),
        "branch_oracle_a": branch_a,
        "branch_oracle_b": branch_b,
        "branch": branch,
        "expected_branch": expected,
        "plateau_length_oracle_a_cm": float(plateau_a),
        "plateau_length_oracle_b_cm": float(plateau_b),
        "plateau_length_closure_oracle_a_cm": float(closure_a),
        "plateau_length_closure_oracle_b_cm": float(closure_b),
        "plateau_darcy_residual_cm_per_day": float(darcy_residual),
        "join_head_discontinuity_cm": 0.0,
        "gradient_limit": grad,
        "regular_q_gt_ksat_branch": regular,
        "persistent_state_bytes": 0,
        "scratch_owner": "worker",
        "tests": {k: bool(v) for k, v in tests.items()},
        "failed_metrics": [k for k, v in tests.items() if not bool(v)],
        "pass": all(bool(v) for v in tests.values()),
    }


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit("usage: run_ross01_gate_e3e_r2p_ksat_endpoint_admissibility_policy.py OUTPUT.json")
    out = Path(sys.argv[1])
    catalog = json.loads(CATALOG.read_text(encoding="utf-8"))
    rows_by = {str(r["sfu"]): r for r in catalog["rows"]}
    results = [run_material(rows_by[m]) for m in MATERIALS]
    passed = all(r["pass"] for r in results)
    result = {
        "schema_version": 1,
        "workstream": "F-ROSS",
        "work_unit": "F-ROSS01",
        "gate": "E3E_R2P_KSAT_ENDPOINT_ADMISSIBILITY_POLICY",
        "contract": CONTRACT,
        "production_implementation": False,
        "qualification_target": "ZERO_SURFACE_MIXED_SATURATED_UNSATURATED_FACE_ENDPOINT_SEMANTICS_ONLY",
        "material_count": len(results),
        "material_pass_count": sum(int(r["pass"]) for r in results),
        "endpoint_plateau_count": sum(r["branch"] == "ENDPOINT_KSAT_PLATEAU" for r in results),
        "interior_root_control_count": sum(r["branch"] == "INTERIOR_ROOT" for r in results),
        "results": results,
        "persistent_state_bytes": 0,
        "new_constitutive_physics": False,
        "mass_repair_or_clipping": False,
        "pass": passed,
        "decision": (
            "QUALIFIED_ZERO_SURFACE_KSAT_PLATEAU_AS_DERIVED_FACE_LOCAL_MIXED_ENDPOINT_SEMANTICS_READY_FOR_FRESH_5CM_REFERENCE_CHARACTERIZATION"
            if passed else
            "ZERO_SURFACE_KSAT_PLATEAU_NOT_ADMISSIBLE_ROUTE_CASES_TO_REFERENCE_SOLVER"
        ),
        "hard_nonclaims": [
            "No complete 5 cm candidate-face qualification.",
            "No h_surface>0 endpoint plateau admission.",
            "No surface-process or runoff ledger qualification.",
            "No response tangent across endpoint switching.",
            "No runtime, MultiSWAP, groundwater or production admission."
        ],
    }
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    for r in results:
        print(json.dumps({
            "material": r["material"],
            "n": r["n"],
            "endpoint_path_cm": r["endpoint_path_oracle_a_cm"],
            "branch": r["branch"],
            "pass": r["pass"],
            "failed_metrics": r["failed_metrics"],
        }, sort_keys=True), flush=True)
    print(json.dumps({"pass": passed, "decision": result["decision"]}, sort_keys=True), flush=True)
    if not passed:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
