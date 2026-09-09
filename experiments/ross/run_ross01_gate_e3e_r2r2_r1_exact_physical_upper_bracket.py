from __future__ import annotations

import json
import math
import sys
from pathlib import Path

import mpmath as mp

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import run_ross01_gate_e3e_r2r2_fresh_5cm_reference_characterization as r2r2

r2 = r2r2.r2
old_e3e = r2r2.old_e3e

CONTRACT = "F-ROSS01_GATE_E3E_R2R2_R1_EXACT_PHYSICAL_UPPER_BRACKET_ORACLE_REMEDIATION_PRECOMMIT.json"
CATALOG = Path("integration/f-ross/F-ROSS01_GATE_C1_MATERIAL_CATALOG.json")
MATERIALS = ("B01", "O14")
FAILED = {
    "B01": {"probe_id": "fresh_near_0023", "h_surface": 0.8418598139923603, "h_top_node": -1.7857563818019415e-08},
    "O14": {"probe_id": "fresh_near_0003", "h_surface": 0.37579678846033, "h_top_node": -1.9219207863995577e-08},
}
CONTROL_ID = "fresh_near_0011"
Y_MIN = mp.mpf("-24")
Y_SAMPLES = 289
BISECTION_STEPS = 120
Q_TOL = mp.mpf("1e-9")
A_RES_TOL = mp.mpf("1e-10")
B_RES_TOL = mp.mpf("1e-8")
HYBRID_MAX = 0.01
ABS_MAX = 0.0005


def exact_reverse_bracket(residual, delta_upper: mp.mpf):
    y_hi = mp.log10(delta_upper)
    prev_y = y_hi
    prev_f = residual(prev_y)
    if not mp.isfinite(prev_f):
        raise RuntimeError(("nonfinite_exact_upper_residual", str(prev_f)))
    for i in range(1, Y_SAMPLES):
        y = y_hi - (y_hi - Y_MIN) * mp.mpf(i) / mp.mpf(Y_SAMPLES - 1)
        f = residual(y)
        if not mp.isfinite(f):
            raise RuntimeError(("nonfinite_scan_residual", i, str(y), str(f)))
        if f == 0:
            return y, y, f, f
        if prev_f * f < 0:
            return y, prev_y, f, prev_f
        prev_y, prev_f = y, f
    raise RuntimeError(("no_exact_upper_sign_change", str(Y_MIN), str(y_hi), str(prev_f)))


def bisect_y(residual, delta_upper: mp.mpf):
    lo, hi, flo, fhi = exact_reverse_bracket(residual, delta_upper)
    if lo == hi:
        y = lo
    else:
        for _ in range(BISECTION_STEPS):
            mid = (lo + hi) / 2
            fm = residual(mid)
            if flo * fm <= 0:
                hi, fhi = mid, fm
            else:
                lo, flo = mid, fm
        y = (lo + hi) / 2
    delta = mp.power(10, y)
    return +delta, +y, +residual(y)


def exact_solve_a(hs: mp.mpf, ht: mp.mpf, row: dict):
    with mp.workdps(100):
        du = (hs - ht) / r2.LENGTH
        def residual_y(y):
            return r2.path_a_delta(hs, ht, mp.power(10, y), row) - r2.LENGTH
        return bisect_y(residual_y, du)


def exact_solve_b(hs: mp.mpf, ht: mp.mpf, row: dict):
    setup = r2.setup_b(ht, row)
    with mp.workdps(60):
        du = (hs - ht) / r2.LENGTH
        def residual_y(y):
            return r2.path_b_delta(hs, mp.power(10, y), setup) - r2.LENGTH
        delta, y, residual = bisect_y(residual_y, du)
    return delta, y, residual, setup


def evaluate_failed(material: str, row: dict) -> dict:
    p = FAILED[material]
    hs = mp.mpf(str(p["h_surface"])); ht = mp.mpf(str(p["h_top_node"])); ks = mp.mpf(str(row["ksatfit_cm_per_day"]))
    du = (hs - ht) / r2.LENGTH
    old_u = du * r2.UPPER_SAFETY
    setup = r2.setup_b(ht, row)
    with mp.workdps(100):
        a_old = r2.path_a_delta(hs, ht, old_u, row) - r2.LENGTH
        a_exact = r2.path_a_delta(hs, ht, du, row) - r2.LENGTH
    with mp.workdps(60):
        b_old = r2.path_b_delta(hs, old_u, setup) - r2.LENGTH
        b_exact = r2.path_b_delta(hs, du, setup) - r2.LENGTH
    da, ya, ra = exact_solve_a(hs, ht, row)
    db, yb, rb, _ = exact_solve_b(hs, ht, row)
    qa = ks * (1 + da); qb = ks * (1 + db); qu = ks * (1 + du)

    old_e3e.configure_5cm(row)
    qc, cost = old_e3e.candidate_q(float(hs), float(ht))
    qc = mp.mpf(str(qc))
    hybrid, absolute, wrong = old_e3e.e2c._metric(float(qb), float(qc), float(ks))
    tests = {
        "old_safety_residual_positive_oracle_a": a_old > 0,
        "old_safety_residual_positive_oracle_b": b_old > 0,
        "exact_upper_residual_nonpositive_oracle_a": a_exact <= 0,
        "exact_upper_residual_nonpositive_oracle_b": b_exact <= 0,
        "exact_upper_residuals_finite": mp.isfinite(a_exact) and mp.isfinite(b_exact),
        "root_oracles_agree": abs(da-db) <= Q_TOL,
        "oracle_a_residual": abs(ra) <= A_RES_TOL,
        "oracle_b_residual": abs(rb) <= B_RES_TOL,
        "root_above_ksat": da > 0 and db > 0,
        "root_not_above_physical_upper": qa <= qu and qb <= qu,
        "candidate_hybrid_metric": hybrid <= HYBRID_MAX,
        "candidate_abs_error_over_ksat": absolute <= ABS_MAX,
        "candidate_wrong_sign": wrong == 0,
    }
    return {
        "kind": "failed_witness",
        "probe_id": p["probe_id"],
        "h_surface_cm": float(hs), "h_top_node_cm": float(ht),
        "physical_upper_delta": float(du),
        "old_safety_delta": float(old_u),
        "oracle_a_old_safety_residual_cm": float(a_old),
        "oracle_b_old_safety_residual_cm": float(b_old),
        "oracle_a_exact_upper_residual_cm": float(a_exact),
        "oracle_b_exact_upper_residual_cm": float(b_exact),
        "q_oracle_a_cm_per_day": float(qa),
        "q_oracle_b_cm_per_day": float(qb),
        "q_physical_upper_cm_per_day": float(qu),
        "root_gap_from_physical_upper_over_ksat_oracle_a": float(du-da),
        "root_gap_from_physical_upper_over_ksat_oracle_b": float(du-db),
        "oracle_pair_q_difference_over_ksat": float(abs(da-db)),
        "oracle_a_path_residual_cm": float(ra),
        "oracle_b_path_residual_cm": float(rb),
        "q_candidate_cm_per_day": float(qc),
        "candidate_hybrid_metric": hybrid,
        "candidate_abs_error_over_ksatfit": absolute,
        "candidate_wrong_sign": wrong,
        "candidate_root_residual_evaluations": int(cost["root_residual_evaluations"]),
        "candidate_constitutive_K_evaluations": int(cost["constitutive_K_evaluations"]),
        "tests": {k: bool(v) for k,v in tests.items()},
        "failed_metrics": [k for k,v in tests.items() if not bool(v)],
        "pass": all(bool(v) for v in tests.values()),
    }


def evaluate_control(material: str, row: dict) -> dict:
    p = next(x for x in r2r2.build_fresh(material) if x["id"] == CONTROL_ID)
    hs = mp.mpf(str(p["h_surface"])); ht = mp.mpf(str(p["h_top_node"])); ks = mp.mpf(str(row["ksatfit_cm_per_day"]))
    old_a, _, old_ra = r2.solve_interior_a(hs, ht, row)
    old_b, _, old_rb = r2.solve_interior_b(hs, ht, r2.setup_b(ht, row))
    new_a, _, new_ra = exact_solve_a(hs, ht, row)
    new_b, _, new_rb, _ = exact_solve_b(hs, ht, row)
    tests = {
        "old_new_oracle_a_agree": abs(old_a-new_a) <= Q_TOL,
        "old_new_oracle_b_agree": abs(old_b-new_b) <= Q_TOL,
        "new_oracles_agree": abs(new_a-new_b) <= Q_TOL,
        "old_oracles_agree": abs(old_a-old_b) <= Q_TOL,
        "new_a_residual": abs(new_ra) <= A_RES_TOL,
        "new_b_residual": abs(new_rb) <= B_RES_TOL,
        "branch_interior": new_a > 0 and new_b > 0,
    }
    return {
        "kind": "passing_control", "probe_id": CONTROL_ID,
        "h_surface_cm": float(hs), "h_top_node_cm": float(ht),
        "q_old_oracle_a_cm_per_day": float(ks*(1+old_a)),
        "q_old_oracle_b_cm_per_day": float(ks*(1+old_b)),
        "q_exact_upper_oracle_a_cm_per_day": float(ks*(1+new_a)),
        "q_exact_upper_oracle_b_cm_per_day": float(ks*(1+new_b)),
        "old_vs_exact_a_q_difference_over_ksat": float(abs(old_a-new_a)),
        "old_vs_exact_b_q_difference_over_ksat": float(abs(old_b-new_b)),
        "exact_oracle_pair_q_difference_over_ksat": float(abs(new_a-new_b)),
        "tests": {k: bool(v) for k,v in tests.items()},
        "failed_metrics": [k for k,v in tests.items() if not bool(v)],
        "pass": all(bool(v) for v in tests.values()),
    }


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit("usage: run_ross01_gate_e3e_r2r2_r1_exact_physical_upper_bracket.py MATERIAL OUTPUT.json")
    material=sys.argv[1]; out=Path(sys.argv[2])
    if material not in MATERIALS:
        raise SystemExit(f"material must be one of {MATERIALS}")
    catalog=json.loads(CATALOG.read_text(encoding="utf-8"))
    row=next(r for r in catalog["rows"] if r["sfu"]==material)
    failed=evaluate_failed(material,row)
    control=evaluate_control(material,row)
    passed=failed["pass"] and control["pass"]
    payload={
        "schema_version":1,"workstream":"F-ROSS","work_unit":"F-ROSS01",
        "gate":"E3E_R2R2_R1_EXACT_PHYSICAL_UPPER_BRACKET_ORACLE_REMEDIATION",
        "contract":CONTRACT,"material":material,"production_implementation":False,
        "qualification_target":"REFERENCE_ORACLE_UPPER_BRACKET_ONLY",
        "failed_witness":failed,"passing_control":control,"pass":passed,
        "decision":"QUALIFIED_EXACT_PHYSICAL_UPPER_REFERENCE_BRACKET_REMEDIATION_READY_FOR_IDENTICAL_FRESH_R2R2_RERUN" if passed else "EXACT_PHYSICAL_UPPER_REFERENCE_BRACKET_NOT_QUALIFIED_FURTHER_ORACLE_RESEARCH_REQUIRED",
        "hard_nonclaims":["No complete 5 cm face qualification.","No production numerical policy.","No candidate tuning.","No surface ledger, tangent, runtime, MultiSWAP or groundwater admission."]
    }
    out.parent.mkdir(parents=True,exist_ok=True)
    out.write_text(json.dumps(payload,indent=2,sort_keys=True)+"\n",encoding="utf-8")
    print(json.dumps({"material":material,"pass":passed,"failed_witness_pass":failed["pass"],"control_pass":control["pass"],"old_a_res":failed["oracle_a_old_safety_residual_cm"],"exact_a_res":failed["oracle_a_exact_upper_residual_cm"],"old_b_res":failed["oracle_b_old_safety_residual_cm"],"exact_b_res":failed["oracle_b_exact_upper_residual_cm"],"q_pair_diff_over_ksat":failed["oracle_pair_q_difference_over_ksat"],"candidate_hybrid":failed["candidate_hybrid_metric"],"decision":payload["decision"]},sort_keys=True),flush=True)
    if not passed:
        raise SystemExit(1)

if __name__=="__main__":
    main()
