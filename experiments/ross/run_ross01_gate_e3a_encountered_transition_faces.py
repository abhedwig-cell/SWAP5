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

import run_ross01_gate_e2c_r3_endpoint_limit_holdout as r3

CONTRACT = "F-ROSS01_GATE_E3A_ENCOUNTERED_TRANSITION_FACE_SCOPE_PRECOMMIT.json"
CATALOG = Path("integration/f-ross/F-ROSS01_GATE_C1_MATERIAL_CATALOG.json")
MATERIALS = ("B01", "B12", "O13", "O14")
SOBOL_PER_CLASS = 512
HYBRID_MAX = 0.01
HYBRID_P99 = 0.002
ABS_KSAT_MAX = 0.0005
ENDPOINT_HYBRID_MAX = 0.002
ENDPOINT_ABS_MAX = 0.0005
MAX_K = 530
MAX_ROOT = 66
CTX = mp.get_context("fork")


def seed(material: str, face_class: str) -> int:
    text = f"F-ROSS01-E3A:{material}:{face_class}"
    return int(hashlib.sha256(text.encode()).hexdigest()[:8], 16)


def probes(material: str, face_class: str) -> list[dict]:
    sob = qmc.Sobol(d=2, scramble=True, seed=seed(material, face_class)).random_base2(m=9)
    out = []
    if face_class == "NEAR_UNSAT_NEAR_UNSAT":
        for i, (a, b) in enumerate(sob):
            ha = -1.0 + float(a) * (1.0 - 1.0e-12)
            hb = -1.0 + float(b) * (1.0 - 1.0e-12)
            out.append({"id": f"near_{i:04d}", "kind": "sobol", "h_above": ha, "h_below": hb})
        targeted = [
            (-1.0,-1.0),(-0.9,-0.1),(-0.1,-0.9),(-0.5,-0.5),
            (-1.0,-1.0e-12),(-1.0e-12,-1.0),(-0.75,-0.25),(-0.25,-0.75),
            (-0.99,-0.98),(-0.98,-0.99),(-0.02,-0.01),(-0.01,-0.02),
            (-0.2,-0.2),(-0.8,-0.8)
        ]
    elif face_class == "DRY_ABOVE_WET_BELOW_TRANSITION_BAND":
        for i, (a, b) in enumerate(sob):
            # Log-distribute the dry upper head over the one-decade transition band.
            ha = -(10.0 ** float(a))
            hb = -1.0 + float(b) * (1.0 - 1.0e-12)
            out.append({"id": f"reverse_{i:04d}", "kind": "sobol", "h_above": ha, "h_below": hb})
        targeted = [
            (-1.0,-1.0),(-1.01,-0.99),(-1.1,-0.9),(-1.25,-0.5),
            (-1.5,-0.75),(-2.0,-0.5),(-5.0,-0.5),(-10.0,-0.5),
            (-10.0,0.0),(-9.0,-0.1),(-2.0,-0.01),(-1.2,-0.8),
            (-1.8,-0.75),(-1.25,-0.49)
        ]
    else:
        raise ValueError(face_class)
    for j, (ha, hb) in enumerate(targeted):
        out.append({"id": f"target_{j:02d}", "kind": "targeted", "h_above": float(ha), "h_below": float(hb)})
    return out


def safe_ref(pair):
    ha, hb = pair
    try:
        return pair, float(r3.e2c.c1.core.steady_q(float(ha), float(hb))), None
    except Exception as exc:
        return pair, None, repr(exc)


def characterize_class(material: str, face_class: str, row: dict) -> dict:
    r3.e2c.configure(row)
    ksat = float(r3.e2c.c1.core.KSAT)
    ps = probes(material, face_class)
    pairs = sorted({(float(p["h_above"]), float(p["h_below"])) for p in ps})
    refs = {}
    ref_errors = []
    with CTX.Pool(min(8, mp.cpu_count())) as pool:
        for pair, value, err in pool.imap_unordered(safe_ref, pairs, chunksize=8):
            if err is None:
                refs[pair] = value
            else:
                ref_errors.append({"pair": list(pair), "error": err})

    rows = []
    unresolved = 0
    nonfinite = 0
    max_k = 0
    max_root = 0
    for p in ps:
        ha, hb = float(p["h_above"]), float(p["h_below"])
        qref = refs.get((ha, hb))
        if qref is None:
            continue
        try:
            qcand, cost = r3.endpoint_limit_candidate(ha, hb)
        except RuntimeError:
            unresolved += 1
            continue
        except (FloatingPointError, OverflowError, ValueError):
            nonfinite += 1
            continue
        if not (math.isfinite(qref) and math.isfinite(qcand)):
            nonfinite += 1
            continue
        hybrid, absolute, wrong_sign = r3.e2c._metric(qref, qcand, ksat)
        max_k = max(max_k, int(cost["constitutive_K_evaluations"]))
        max_root = max(max_root, int(cost["root_residual_evaluations"]))
        rows.append({
            "probe_id": p["id"], "kind": p["kind"], "h_above": ha, "h_below": hb,
            "q_ref": qref, "q_candidate": qcand, "branch": cost["branch"],
            "hybrid_metric": hybrid, "abs_error_over_ksatfit": absolute,
            "wrong_sign": wrong_sign,
            "constitutive_K_evaluations": cost["constitutive_K_evaluations"],
            "root_residual_evaluations": cost["root_residual_evaluations"],
        })
    hybrids = sorted(r["hybrid_metric"] for r in rows)
    p99 = hybrids[int(0.99*(len(hybrids)-1))] if hybrids else math.inf
    max_hybrid = max(hybrids) if hybrids else math.inf
    max_abs = max((r["abs_error_over_ksatfit"] for r in rows), default=math.inf)
    wrong_sign = sum(r["wrong_sign"] for r in rows)
    endpoint = [r for r in rows if r["branch"] == "ENDPOINT_K_LIMIT"]
    endpoint_hybrid = max((r["hybrid_metric"] for r in endpoint), default=0.0)
    endpoint_abs = max((r["abs_error_over_ksatfit"] for r in endpoint), default=0.0)
    tests = {
        "reference_failure_count": len(ref_errors) == 0,
        "candidate_unresolved_count": unresolved == 0,
        "candidate_nonfinite_count": nonfinite == 0,
        "wrong_sign_count": wrong_sign == 0,
        "max_hybrid_metric": max_hybrid <= HYBRID_MAX,
        "p99_hybrid_metric": p99 <= HYBRID_P99,
        "max_abs_error_over_ksatfit": max_abs <= ABS_KSAT_MAX,
        "endpoint_limit_max_hybrid_metric": endpoint_hybrid <= ENDPOINT_HYBRID_MAX,
        "endpoint_limit_max_abs_error_over_ksatfit": endpoint_abs <= ENDPOINT_ABS_MAX,
        "max_constitutive_K_evaluations": max_k <= MAX_K,
        "max_root_residual_evaluations": max_root <= MAX_ROOT,
    }
    return {
        "material": material, "face_class": face_class, "probe_count": len(ps),
        "valid_probe_count": len(rows), "reference_failure_count": len(ref_errors),
        "candidate_unresolved_count": unresolved, "candidate_nonfinite_count": nonfinite,
        "wrong_sign_count": wrong_sign, "endpoint_limit_count": len(endpoint),
        "max_hybrid_metric": max_hybrid, "p99_hybrid_metric": p99,
        "max_abs_error_over_ksatfit": max_abs,
        "endpoint_limit_max_hybrid_metric": endpoint_hybrid,
        "endpoint_limit_max_abs_error_over_ksatfit": endpoint_abs,
        "max_constitutive_K_evaluations": max_k,
        "max_root_residual_evaluations": max_root,
        "tests": tests, "failed_metrics": [k for k,v in tests.items() if not v],
        "pass": all(tests.values()),
        "worst_probe": max(rows, key=lambda r:r["hybrid_metric"]) if rows else None,
    }


def main():
    if len(sys.argv) != 2:
        raise SystemExit("usage: run_ross01_gate_e3a_encountered_transition_faces.py OUTPUT.json")
    out = Path(sys.argv[1])
    catalog = json.loads(CATALOG.read_text(encoding="utf-8"))
    by = {r["sfu"]: r for r in catalog["rows"]}
    results = []
    classes = ("NEAR_UNSAT_NEAR_UNSAT", "DRY_ABOVE_WET_BELOW_TRANSITION_BAND")
    for material in MATERIALS:
        for face_class in classes:
            rr = characterize_class(material, face_class, by[material])
            results.append(rr)
            print(json.dumps({
                "material": material, "face_class": face_class, "pass": rr["pass"],
                "failed_metrics": rr["failed_metrics"], "candidate_unresolved_count": rr["candidate_unresolved_count"],
                "max_abs_error_over_ksatfit": rr["max_abs_error_over_ksatfit"],
                "max_hybrid_metric": rr["max_hybrid_metric"]
            }, sort_keys=True), flush=True)
    class_pass = {c: all(r["pass"] for r in results if r["face_class"] == c) for c in classes}
    full = all(class_pass.values())
    partial = any(class_pass.values()) and not full
    decision = (
        "QUALIFIED_E3_ENCOUNTERED_NEAR_SATURATION_FACE_SCOPE_READY_FOR_EVENT_AND_SOLVER_REMEDIATION"
        if full else
        "CHARACTERIZED_E3_FACE_SCOPE_PARTIAL_GENERALIZATION_REQUIRES_CLASS_SPECIFIC_CLOSURE"
        if partial else
        "E3_ENCOUNTERED_FACE_SCOPE_NOT_QUALIFIED_RESEARCH_REQUIRED"
    )
    result = {
        "schema_version":1,"workstream":"F-ROSS","work_unit":"F-ROSS01",
        "gate":"E3A_ENCOUNTERED_TRANSITION_FACE_SCOPE_QUALIFICATION","contract":CONTRACT,
        "candidate":"UNCHANGED_E2C_R3_ENDPOINT_LIMIT_CANDIDATE_GENERALIZED_BY_SCOPE_ONLY",
        "production_implementation":False,"new_persistent_state_bytes":0,"scratch_owner":"worker",
        "new_constitutive_physics":False,"new_quadrature_or_root_tuning":False,
        "results":results,"class_pass":class_pass,"pass":full,"partial":partial,"decision":decision,
        "hard_nonclaims":["No E3 column requalification.","No wetting-event admission.","No O14 qualification-solver remediation.","No response tangent/runtime/MultiSWAP qualification."]
    }
    out.parent.mkdir(parents=True,exist_ok=True)
    out.write_text(json.dumps(result,indent=2,sort_keys=True)+"\n",encoding="utf-8")
    print(json.dumps({"pass":full,"partial":partial,"decision":decision,"class_pass":class_pass},sort_keys=True))
    if not full:
        raise SystemExit(1)

if __name__ == "__main__":
    main()
