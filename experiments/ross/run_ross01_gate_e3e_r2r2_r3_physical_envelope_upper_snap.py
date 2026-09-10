from __future__ import annotations

import json
import math
import sys
from pathlib import Path

import mpmath as mp

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import run_ross01_gate_e3e_r2r2_fresh_5cm_reference_characterization as fresh
import run_ross01_gate_e3e_r2r2_r2_analytic_saturated_segment_candidate as r2
import run_ross01_gate_e2c_r2_endpoint_clustered_local_face as e2c_r2

CONTRACT = "F-ROSS01_GATE_E3E_R2R2_R3_PHYSICAL_ENVELOPE_CERTIFIED_UPPER_SNAP_PRECOMMIT.json"
CATALOG = Path("integration/f-ross/F-ROSS01_GATE_C1_MATERIAL_CATALOG.json")
MATERIALS = ("B01", "B12", "O13", "O14")
LENGTH = 5.0
HYBRID_MAX = 0.01
ABS_MAX = 0.0005
MAX_K = 530
MAX_ROOT = 66
REF_RES_A = 1.0e-10
REF_RES_B = 1.0e-8
ORACLE_Q_AGREE = 1.0e-9

DEFECT = {
    "B01": {"id": "fresh_near_0023", "h_surface": 0.8418598139923603, "h_top_node": -1.7857563818019415e-08, "kind": "masked_candidate_defect"},
    "O14": {"id": "fresh_near_0003", "h_surface": 0.37579678846033, "h_top_node": -1.9219207863995577e-08, "kind": "same_reference_failure_class_negative_control"},
}


def physical_envelope(hs: float, ht: float, ks: float) -> dict:
    if not (hs > 0.0 and ht < 0.0 and ks > 0.0):
        raise ValueError("physical envelope requires hs>0>ht and KSAT>0")
    q_lower = ks * (1.0 + hs / LENGTH)
    q_upper = ks * (1.0 + (hs - ht) / LENGTH)
    abs_bound = (-ht) / LENGTH
    hybrid_bound = abs_bound / (1.0 + hs / LENGTH + 1.0e-4)
    return {
        "q_lower_cm_per_day": q_lower,
        "q_upper_cm_per_day": q_upper,
        "width_cm_per_day": q_upper - q_lower,
        "abs_error_bound_over_ksat": abs_bound,
        "hybrid_error_bound": hybrid_bound,
    }


def candidate_with_envelope(hs: float, ht: float):
    if not (hs > 0.0 and ht < 0.0):
        q, cost = r2.old_e3e.candidate_q(hs, ht)
        return float(q), dict(cost), None

    ks = float(r2.old_e3e.e2c.c1.core.KSAT)
    unsat_residual = e2c_r2.endpoint_clustered_residual_factory(0.0, ht)

    def residual(q: float) -> float:
        if not q > ks:
            return math.inf
        sat = hs * ks / (q - ks)
        unsat_path = unsat_residual(q) + LENGTH
        return sat + unsat_path - LENGTH

    lo = math.nextafter(ks, math.inf)
    cert = physical_envelope(hs, ht, ks)
    hi = cert["q_upper_cm_per_day"]
    flo = residual(lo)
    fhi = residual(hi)
    evals = 2
    if not (math.isfinite(flo) and math.isfinite(fhi)):
        raise FloatingPointError(("split_nonfinite_bracket", flo, fhi))

    if flo == 0.0:
        return lo, {
            "branch": "SURFACE_SATURATED_ANALYTIC_SPLIT_BISECTION",
            "root_residual_evaluations": evals,
            "constitutive_K_evaluations": int(unsat_residual.k_eval_count),
        }, cert
    if fhi == 0.0:
        return hi, {
            "branch": "SURFACE_SATURATED_ANALYTIC_SPLIT_BISECTION",
            "root_residual_evaluations": evals,
            "constitutive_K_evaluations": int(unsat_residual.k_eval_count),
        }, cert

    if flo * fhi > 0.0:
        if not (flo > 0.0 and fhi > 0.0):
            raise RuntimeError(("split_bracket_failure_not_upper_sign_ambiguity", hs, ht, lo, hi, flo, fhi))
        if cert["abs_error_bound_over_ksat"] > ABS_MAX or cert["hybrid_error_bound"] > HYBRID_MAX:
            raise RuntimeError(("physical_envelope_too_wide", hs, ht, cert, flo, fhi))
        return hi, {
            "branch": "SURFACE_SATURATED_PHYSICAL_ENVELOPE_UPPER_SNAP",
            "root_residual_evaluations": evals,
            "constitutive_K_evaluations": int(unsat_residual.k_eval_count),
            "binary64_lower_residual_cm": flo,
            "binary64_upper_residual_cm": fhi,
        }, cert

    for _ in range(r2.old_e3e.e2c.BISECTION_STEPS):
        mid = 0.5 * (lo + hi)
        fm = residual(mid)
        evals += 1
        if not math.isfinite(fm):
            raise FloatingPointError(("split_nonfinite_mid", mid, fm))
        if fm == 0.0:
            lo = hi = mid
            break
        if flo * fm <= 0.0:
            hi = mid
            fhi = fm
        else:
            lo = mid
            flo = fm
    q = 0.5 * (lo + hi)
    return q, {
        "branch": "SURFACE_SATURATED_ANALYTIC_SPLIT_BISECTION",
        "root_residual_evaluations": evals,
        "constitutive_K_evaluations": int(unsat_residual.k_eval_count),
    }, cert


def probes_for(material: str) -> list[dict]:
    byid = {p["id"]: p for p in fresh.build_fresh(material)}
    probes: list[dict] = []
    if material in DEFECT:
        probes.append(dict(DEFECT[material]))
    for pid in ("fresh_near_0011", "fresh_dry_0007"):
        p = byid[pid]
        probes.append({
            "id": pid,
            "h_surface": float(p["h_surface"]),
            "h_top_node": float(p["h_top_node"]),
            "kind": "ordinary_control",
        })
    return probes


def verify_constitutive_bound(ht: float, ks: float) -> dict:
    # This is an executable guard for the theorem's constitutive premise in the
    # frozen material implementation. The proof itself is algebraic once
    # 0<K(h)<=KSAT holds.
    heads = [ht * (i / 128.0) ** 8 for i in range(129)]
    vals = [float(r2.old_e3e.e2c.c1.core.k_of_h(float(h))) for h in heads]
    positive = all(math.isfinite(v) and v > 0.0 for v in vals)
    below = all(v <= ks * (1.0 + 8.0 * sys.float_info.epsilon) for v in vals)
    return {
        "sample_count": len(vals),
        "min_K": min(vals),
        "max_K": max(vals),
        "positive": positive,
        "not_above_ksat": below,
        "pass": positive and below,
    }


def run_material(row: dict) -> dict:
    material = str(row["sfu"])
    r2.old_e3e.configure_5cm(row)
    ks = float(r2.old_e3e.e2c.c1.core.KSAT)
    rows = []
    max_k = 0
    max_root = 0
    snap_count = 0

    for p in probes_for(material):
        hs = float(p["h_surface"])
        ht = float(p["h_top_node"])
        rb_q, rb_res = r2.reference_b(hs, ht, row)
        qc, cost, cert = candidate_with_envelope(hs, ht)
        hybrid, absolute, wrong = r2.old_e3e.e2c._metric(float(rb_q), float(qc), ks)
        max_k = max(max_k, int(cost["constitutive_K_evaluations"]))
        max_root = max(max_root, int(cost["root_residual_evaluations"]))
        is_snap = cost["branch"] == "SURFACE_SATURATED_PHYSICAL_ENVELOPE_UPPER_SNAP"
        snap_count += int(is_snap)

        theorem = physical_envelope(hs, ht, ks)
        q_in_envelope = (
            float(rb_q) >= theorem["q_lower_cm_per_day"] * (1.0 - 2.0e-14)
            and float(rb_q) <= theorem["q_upper_cm_per_day"] * (1.0 + 2.0e-14)
        )
        actual_within_abs_theorem = absolute <= theorem["abs_error_bound_over_ksat"] + 64.0 * sys.float_info.epsilon
        actual_within_hybrid_theorem = hybrid <= theorem["hybrid_error_bound"] + 64.0 * sys.float_info.epsilon
        constitutive = verify_constitutive_bound(ht, ks)

        tests = {
            "reference_b_residual": abs(float(rb_res)) <= REF_RES_B,
            "candidate_finite": math.isfinite(qc),
            "constitutive_premise": constitutive["pass"],
            "reference_inside_physical_envelope": q_in_envelope,
            "frozen_hybrid_metric": hybrid <= HYBRID_MAX,
            "frozen_abs_error": absolute <= ABS_MAX,
            "wrong_sign": wrong == 0,
            "actual_error_inside_theorem_abs_bound": actual_within_abs_theorem,
            "actual_error_inside_theorem_hybrid_bound": actual_within_hybrid_theorem,
            "k_cost": int(cost["constitutive_K_evaluations"]) <= MAX_K,
            "root_cost": int(cost["root_residual_evaluations"]) <= MAX_ROOT,
        }

        rowout = {
            "probe_id": p["id"],
            "kind": p["kind"],
            "h_surface_cm": hs,
            "h_top_node_cm": ht,
            "q_reference_b_cm_per_day": float(rb_q),
            "reference_b_path_residual_cm": float(rb_res),
            "q_candidate_cm_per_day": float(qc),
            "candidate_branch": cost["branch"],
            "hybrid_metric": hybrid,
            "abs_error_over_ksatfit": absolute,
            "wrong_sign": wrong,
            "physical_envelope": theorem,
            "constitutive_premise_guard": constitutive,
            "root_residual_evaluations": int(cost["root_residual_evaluations"]),
            "constitutive_K_evaluations": int(cost["constitutive_K_evaluations"]),
            "binary64_lower_residual_cm": cost.get("binary64_lower_residual_cm"),
            "binary64_upper_residual_cm": cost.get("binary64_upper_residual_cm"),
            "tests": tests,
        }

        if p["id"] in ("fresh_near_0023", "fresh_near_0003"):
            ra_q, ra_res = r2.reference_a(hs, ht, row)
            qdiff = abs(float(ra_q) - float(rb_q)) / ks
            rowout["q_reference_a_cm_per_day"] = float(ra_q)
            rowout["reference_a_path_residual_cm"] = float(ra_res)
            rowout["oracle_pair_abs_error_over_ksat"] = qdiff
            rowout["tests"]["reference_a_residual"] = abs(float(ra_res)) <= REF_RES_A
            rowout["tests"]["oracle_pair_agreement"] = qdiff <= ORACLE_Q_AGREE

        if material == "B01" and p["id"] == "fresh_near_0023":
            rowout["tests"]["defect_uses_certified_snap"] = is_snap
            rowout["tests"]["defect_not_ksat_fallback"] = abs(float(qc) - ks) > 1.0e-8 * ks

        rowout["failed_metrics"] = [k for k, v in rowout["tests"].items() if not v]
        rowout["pass"] = all(rowout["tests"].values())
        rows.append(rowout)

    valid = [r for r in rows if "hybrid_metric" in r]
    tests = {
        "all_rows_present": len(rows) == len(probes_for(material)),
        "all_rows_pass": all(r["pass"] for r in rows),
        "max_hybrid_metric": max(r["hybrid_metric"] for r in valid) <= HYBRID_MAX,
        "max_abs_error": max(r["abs_error_over_ksatfit"] for r in valid) <= ABS_MAX,
        "wrong_sign_zero": sum(r["wrong_sign"] for r in valid) == 0,
        "max_k_cost": max_k <= MAX_K,
        "max_root_cost": max_root <= MAX_ROOT,
        "B01_snap_exactly_one": material != "B01" or snap_count == 1,
    }
    return {
        "material": material,
        "witness_count": len(rows),
        "snap_count": snap_count,
        "rows": rows,
        "max_hybrid_metric": max(r["hybrid_metric"] for r in valid),
        "max_abs_error_over_ksatfit": max(r["abs_error_over_ksatfit"] for r in valid),
        "wrong_sign_count": sum(r["wrong_sign"] for r in valid),
        "max_constitutive_K_evaluations": max_k,
        "max_root_residual_evaluations": max_root,
        "tests": tests,
        "failed_metrics": [k for k, v in tests.items() if not v],
        "pass": all(tests.values()),
    }


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit("usage: run_ross01_gate_e3e_r2r2_r3_physical_envelope_upper_snap.py MATERIAL OUTPUT.json")
    material = sys.argv[1]
    out = Path(sys.argv[2])
    if material not in MATERIALS:
        raise SystemExit(material)
    catalog = json.loads(CATALOG.read_text(encoding="utf-8"))
    row = next(r for r in catalog["rows"] if r["sfu"] == material)
    mr = run_material(row)
    passed = bool(mr["pass"])
    payload = {
        "schema_version": 1,
        "workstream": "F-ROSS",
        "work_unit": "F-ROSS01",
        "gate": "E3E_R2R2_R3_PHYSICAL_ENVELOPE_CERTIFIED_UPPER_SNAP",
        "contract": CONTRACT,
        "material": material,
        "production_implementation": False,
        "qualification_target": "POSITIVE_SURFACE_TO_UNSATURATED_5CM_FACE_CANDIDATE_BRANCH_ONLY",
        "roundoff_only_hypothesis_retired": True,
        "certificate_kind": "ANALYTIC_PHYSICAL_ROOT_ENVELOPE",
        "material_result": mr,
        "pass": passed,
        "decision": (
            "QUALIFIED_PHYSICAL_ENVELOPE_CERTIFIED_UPPER_SNAP_READY_FOR_IDENTICAL_320_CASE_FRESH_RERUN"
            if passed else
            "PHYSICAL_ENVELOPE_UPPER_SNAP_NOT_QUALIFIED_FURTHER_SURFACE_FACE_RESEARCH_REQUIRED"
        ),
        "hard_nonclaims": [
            "No claim that the former sign ambiguity was pure floating-point roundoff.",
            "No new constitutive physics, Phi tuning, table, smoothing or residual tolerance.",
            "No h_surface=0 endpoint change.",
            "No 320-case face requalification yet.",
            "No surface ledger, response tangent, runtime, MultiSWAP, groundwater or production admission."
        ],
    }
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps({
        "material": material,
        "pass": passed,
        "snap_count": mr["snap_count"],
        "max_hybrid_metric": mr["max_hybrid_metric"],
        "max_abs_error_over_ksatfit": mr["max_abs_error_over_ksatfit"],
        "max_k": mr["max_constitutive_K_evaluations"],
        "max_root": mr["max_root_residual_evaluations"],
        "failed_metrics": mr["failed_metrics"],
        "decision": payload["decision"],
    }, sort_keys=True), flush=True)
    if not passed:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
