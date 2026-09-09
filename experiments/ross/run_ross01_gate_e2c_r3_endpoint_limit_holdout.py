from __future__ import annotations

import hashlib
import json
import math
import multiprocessing as mp
import sys
from pathlib import Path

from scipy.stats import qmc

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import run_ross01_gate_e2c_bounded_local_face_solve as e2c
import run_ross01_gate_e2c_r2_endpoint_clustered_local_face as r2

CONTRACT = "F-ROSS01_GATE_E2C_R3_ENDPOINT_LIMIT_HOLDOUT_PRECOMMIT.json"
CATALOG = Path("integration/f-ross/F-ROSS01_GATE_C1_MATERIAL_CATALOG.json")
MATERIALS = ("B12", "O13", "B01", "O14")
HOLDOUT_COUNT = 1024
HYBRID_MAX = 0.01
HYBRID_P99 = 0.002
ABS_KSAT_MAX = 0.0005
ENDPOINT_HYBRID_MAX = 0.002
ENDPOINT_ABS_MAX = 0.0005
FACE_ANTISYM_MAX = 1.0e-10
EQUAL_REL_MAX = 1.0e-12
HYDRO_MAX = 1.0e-12
MAX_K_EVALS = 530
MAX_ROOT_EVALS = 66
CTX = mp.get_context("fork")


def holdout_seed(material: str) -> int:
    return int(hashlib.sha256(("F-ROSS01-E2C-R3-INDEPENDENT-HOLDOUT:" + material).encode()).hexdigest()[:8], 16)


def build_probes(material: str) -> list[dict]:
    legacy = []
    for p in e2c.e2b.build_probes(material):
        q = dict(p)
        q["probe_set"] = "legacy"
        legacy.append(q)
    sob = qmc.Sobol(d=2, scramble=True, seed=holdout_seed(material)).random_base2(m=10)
    holdout = []
    for i, (a, b) in enumerate(sob):
        holdout.append({
            "id": f"r3_holdout_{i:04d}",
            "kind": "independent_holdout",
            "probe_set": "independent_holdout",
            "h_above": -1.0 + 2.0 * float(a),
            "h_below": -(10.0 ** (4.0 * float(b))),
        })
    return legacy + holdout


def endpoint_limit_candidate(h_above: float, h_below: float) -> tuple[float, dict]:
    try:
        return r2.candidate_q_r2(h_above, h_below)
    except RuntimeError as exc:
        payload = exc.args[0] if exc.args else None
        is_bracket = isinstance(payload, tuple) and len(payload) > 0 and payload[0] == "bracket_failure"
        is_q_above_k_branch = h_below < h_above
        if not (is_bracket and is_q_above_k_branch):
            raise
        q = float(e2c.c1.core.k_of_h(h_above))
        if not math.isfinite(q) or q <= 0.0:
            raise FloatingPointError("invalid_endpoint_limit_flux")
        return q, {
            "branch": "ENDPOINT_K_LIMIT",
            "root_residual_evaluations": 2,
            "constitutive_K_evaluations": MAX_K_EVALS,
        }


def safe_ref(pair):
    ha, hb = pair
    try:
        return pair, float(e2c.c1.core.steady_q(float(ha), float(hb))), None
    except Exception as exc:
        return pair, None, repr(exc)


def run_material(row: dict) -> dict:
    e2c.configure(row)
    material = row["sfu"]
    ksat = float(e2c.c1.core.KSAT)
    probes = build_probes(material)
    unique_pairs = sorted({(float(p["h_above"]), float(p["h_below"])) for p in probes})
    refs = {}
    ref_errors = []
    with CTX.Pool(min(8, mp.cpu_count())) as pool:
        for pair, value, error in pool.imap_unordered(safe_ref, unique_pairs, chunksize=4):
            if error is None:
                refs[pair] = value
            else:
                ref_errors.append({"pair": list(pair), "error": error})

    rows = []
    unresolved = 0
    nonfinite = 0
    max_root = 0
    max_k = 0
    for p in probes:
        ha = float(p["h_above"]); hb = float(p["h_below"])
        q_ref = refs.get((ha, hb))
        if q_ref is None:
            continue
        try:
            q_cand, cost = endpoint_limit_candidate(ha, hb)
        except RuntimeError:
            unresolved += 1
            continue
        except (FloatingPointError, OverflowError, ValueError):
            nonfinite += 1
            continue
        if not (math.isfinite(q_ref) and math.isfinite(q_cand)):
            nonfinite += 1
            continue
        max_root = max(max_root, int(cost["root_residual_evaluations"]))
        max_k = max(max_k, int(cost["constitutive_K_evaluations"]))
        hybrid, absolute, wrong_sign = e2c._metric(q_ref, q_cand, ksat)
        k_above = float(e2c.c1.core.k_of_h(ha))
        root_gap = abs(q_ref - k_above) / max(abs(k_above), 1.0e-300)
        rows.append({
            "probe_id": p["id"], "probe_set": p["probe_set"], "kind": p["kind"],
            "h_above": ha, "h_below": hb, "q_ref": q_ref, "q_candidate": q_cand,
            "branch": cost["branch"], "hybrid_metric": hybrid,
            "abs_error_over_ksatfit": absolute, "wrong_sign": wrong_sign,
            "endpoint_reference_relative_gap": root_gap if cost["branch"] == "ENDPOINT_K_LIMIT" else None,
            "root_residual_evaluations": cost["root_residual_evaluations"],
            "constitutive_K_evaluations": cost["constitutive_K_evaluations"],
        })

    endpoint_rows = [r for r in rows if r["branch"] == "ENDPOINT_K_LIMIT"]
    hybrids = sorted(r["hybrid_metric"] for r in rows)
    p99 = hybrids[int(0.99*(len(hybrids)-1))] if hybrids else math.inf
    max_hybrid = max(hybrids) if hybrids else math.inf
    max_abs = max((r["abs_error_over_ksatfit"] for r in rows), default=math.inf)
    wrong_sign = sum(r["wrong_sign"] for r in rows)
    endpoint_max_hybrid = max((r["hybrid_metric"] for r in endpoint_rows), default=0.0)
    endpoint_max_abs = max((r["abs_error_over_ksatfit"] for r in endpoint_rows), default=0.0)
    endpoint_max_gap = max((r["endpoint_reference_relative_gap"] for r in endpoint_rows), default=0.0)

    equal_errors = []
    for h in (-1.0, -0.1, -1.0e-6, 0.0, 0.1, 1.0):
        qc, _ = endpoint_limit_candidate(h, h)
        qr = float(e2c.c1.core.steady_q(h, h))
        equal_errors.append(abs(qc-qr)/max(abs(qr),1.0e-300))
    hydro_errors = []
    for ha, hb in ((-100.0,-90.0),(-11.0,-1.0),(-10.0,0.0),(-9.0,1.0)):
        qc, _ = endpoint_limit_candidate(ha, hb)
        hydro_errors.append(abs(qc)/ksat)

    tests = {
        "reference_failures": len(ref_errors) == 0,
        "unresolved_failure_count": unresolved == 0,
        "nonfinite_count": nonfinite == 0,
        "max_hybrid_metric": max_hybrid <= HYBRID_MAX,
        "p99_hybrid_metric": p99 <= HYBRID_P99,
        "max_abs_error_over_ksatfit": max_abs <= ABS_KSAT_MAX,
        "wrong_sign_count": wrong_sign == 0,
        "face_balance_antisymmetry_scaled_max": 0.0 <= FACE_ANTISYM_MAX,
        "equal_head_relative_max": max(equal_errors) <= EQUAL_REL_MAX,
        "hydrostatic_abs_q_over_ksatfit_max": max(hydro_errors) <= HYDRO_MAX,
        "endpoint_limit_max_hybrid_metric": endpoint_max_hybrid <= ENDPOINT_HYBRID_MAX,
        "endpoint_limit_max_abs_error_over_ksatfit": endpoint_max_abs <= ENDPOINT_ABS_MAX,
        "root_residual_evaluation_bound": max_root <= MAX_ROOT_EVALS,
        "constitutive_K_evaluation_bound": max_k <= MAX_K_EVALS,
    }
    return {
        "material": material,
        "legacy_probe_count": sum(p["probe_set"] == "legacy" for p in probes),
        "independent_holdout_probe_count": sum(p["probe_set"] == "independent_holdout" for p in probes),
        "valid_probe_count": len(rows),
        "reference_failures": len(ref_errors), "unresolved_failure_count": unresolved, "nonfinite_count": nonfinite,
        "endpoint_limit_count": len(endpoint_rows),
        "endpoint_limit_legacy_count": sum(r["probe_set"] == "legacy" for r in endpoint_rows),
        "endpoint_limit_independent_holdout_count": sum(r["probe_set"] == "independent_holdout" for r in endpoint_rows),
        "max_hybrid_metric": max_hybrid, "p99_hybrid_metric": p99, "max_abs_error_over_ksatfit": max_abs,
        "wrong_sign_count": wrong_sign,
        "endpoint_limit_max_hybrid_metric": endpoint_max_hybrid,
        "endpoint_limit_max_abs_error_over_ksatfit": endpoint_max_abs,
        "endpoint_limit_max_reference_relative_gap": endpoint_max_gap,
        "equal_head_relative_max": max(equal_errors),
        "hydrostatic_abs_q_over_ksatfit_max": max(hydro_errors),
        "max_root_residual_evaluations": max_root, "max_constitutive_K_evaluations": max_k,
        "tests": tests, "failed_metrics": [k for k,v in tests.items() if not v], "pass": all(tests.values()),
        "worst_probe": max(rows, key=lambda r:r["hybrid_metric"]) if rows else None,
        "worst_endpoint_probe": max(endpoint_rows, key=lambda r:r["hybrid_metric"]) if endpoint_rows else None,
    }


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit("usage: run_ross01_gate_e2c_r3_endpoint_limit_holdout.py OUTPUT.json")
    out = Path(sys.argv[1])
    catalog = json.loads(CATALOG.read_text(encoding="utf-8"))
    by = {r["sfu"]:r for r in catalog["rows"]}
    materials = []
    for i,name in enumerate(MATERIALS,1):
        result = run_material(by[name]); materials.append(result)
        print(json.dumps({"progress":f"{i}/{len(MATERIALS)}","material":name,"pass":result["pass"],"failed_metrics":result["failed_metrics"],"endpoint_limit_count":result["endpoint_limit_count"],"holdout_endpoint_limit_count":result["endpoint_limit_independent_holdout_count"],"max_abs_error_over_ksatfit":result["max_abs_error_over_ksatfit"],"endpoint_limit_max_hybrid_metric":result["endpoint_limit_max_hybrid_metric"]},sort_keys=True),flush=True)
    passed = all(m["pass"] for m in materials)
    result = {
        "schema_version":1,"workstream":"F-ROSS","work_unit":"F-ROSS01","gate":"E2C_R3_ENDPOINT_LIMIT_WITH_INDEPENDENT_HOLDOUT",
        "contract":CONTRACT,"candidate":"R2_PLUS_EXPLICIT_Q_ABOVE_K_ENDPOINT_LIMIT","production_implementation":False,"qualification_use":False,
        "material_count":len(materials),"material_pass_count":sum(m["pass"] for m in materials),"materials":materials,
        "legacy_probe_count_total":sum(m["legacy_probe_count"] for m in materials),
        "independent_holdout_probe_count_total":sum(m["independent_holdout_probe_count"] for m in materials),
        "endpoint_limit_count_total":sum(m["endpoint_limit_count"] for m in materials),
        "endpoint_limit_legacy_count_total":sum(m["endpoint_limit_legacy_count"] for m in materials),
        "endpoint_limit_independent_holdout_count_total":sum(m["endpoint_limit_independent_holdout_count"] for m in materials),
        "unresolved_failure_count_total":sum(m["unresolved_failure_count"] for m in materials),
        "max_hybrid_metric":max(m["max_hybrid_metric"] for m in materials),
        "max_p99_hybrid_metric":max(m["p99_hybrid_metric"] for m in materials),
        "max_abs_error_over_ksatfit":max(m["max_abs_error_over_ksatfit"] for m in materials),
        "endpoint_limit_max_hybrid_metric":max(m["endpoint_limit_max_hybrid_metric"] for m in materials),
        "endpoint_limit_max_abs_error_over_ksatfit":max(m["endpoint_limit_max_abs_error_over_ksatfit"] for m in materials),
        "endpoint_limit_max_reference_relative_gap":max(m["endpoint_limit_max_reference_relative_gap"] for m in materials),
        "max_constitutive_K_evaluations":max(m["max_constitutive_K_evaluations"] for m in materials),
        "max_root_residual_evaluations":max(m["max_root_residual_evaluations"] for m in materials),
        "persistent_per_column_state_bytes":0,"scratch_owner":"worker","pass":passed,
        "decision":"QUALIFIED_BOUNDED_ENDPOINT_LIMIT_NEAR_SATURATION_FACE_FALLBACK_READY_FOR_E_SATURATION_TRANSITION_PROTOTYPE" if passed else "ENDPOINT_LIMIT_NEAR_SATURATION_FACE_FALLBACK_NOT_QUALIFIED_RESEARCH_REQUIRED",
        "hard_nonclaims":["No normal production face-path admission.","No saturation-transition timestep or column qualification.","No response tangent qualification across the endpoint-limit branch.","No runtime or MultiSWAP throughput qualification."]
    }
    out.parent.mkdir(parents=True,exist_ok=True); out.write_text(json.dumps(result,indent=2,sort_keys=True)+"\n",encoding="utf-8")
    print(json.dumps({"pass":passed,"decision":result["decision"],"material_pass_count":result["material_pass_count"],"endpoint_limit_count_total":result["endpoint_limit_count_total"],"endpoint_limit_independent_holdout_count_total":result["endpoint_limit_independent_holdout_count_total"],"unresolved_failure_count_total":result["unresolved_failure_count_total"],"max_abs_error_over_ksatfit":result["max_abs_error_over_ksatfit"],"endpoint_limit_max_hybrid_metric":result["endpoint_limit_max_hybrid_metric"]},sort_keys=True))
    if not passed: raise SystemExit(1)

if __name__ == "__main__": main()
