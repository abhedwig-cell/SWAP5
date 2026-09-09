from __future__ import annotations

import json
import math
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import run_ross01_gate_e3a_encountered_transition_faces as e3a

CONTRACT = "F-ROSS01_GATE_E3A_R2_TWO_SIDED_K_ENDPOINT_LIMIT_PRECOMMIT.json"
CATALOG = Path("integration/f-ross/F-ROSS01_GATE_C1_MATERIAL_CATALOG.json")
MATERIALS = ("B01", "B12", "O13", "O14")
CLASSES = ("NEAR_UNSAT_NEAR_UNSAT", "DRY_ABOVE_WET_BELOW_TRANSITION_BAND")
HYBRID_MAX = 0.01
HYBRID_P99 = 0.002
ABS_KSAT_MAX = 0.0005
ENDPOINT_HYBRID_MAX = 0.002
ENDPOINT_ABS_MAX = 0.0005
MAX_K = 530
MAX_ROOT = 66


def candidate_q(ha: float, hb: float):
    r3 = e3a.r3
    try:
        return r3.endpoint_limit_candidate(ha, hb)
    except RuntimeError as exc:
        payload = exc.args[0] if exc.args else None
        is_bracket = isinstance(payload, tuple) and payload and payload[0] == "bracket_failure"
        dh = hb - ha
        structural = hb > ha and dh < float(r3.e2c.LENGTH)
        if not (is_bracket and structural):
            raise
        q = float(r3.e2c.c1.core.k_of_h(ha))
        if not math.isfinite(q) or q <= 0.0:
            raise FloatingPointError("invalid_lower_side_endpoint_flux")
        return q, {
            "branch": "LOWER_SIDE_K_ABOVE_ENDPOINT_LIMIT",
            "root_residual_evaluations": 2,
            "constitutive_K_evaluations": MAX_K,
        }


def characterize(material: str, face_class: str, row: dict) -> dict:
    r3 = e3a.r3
    r3.e2c.configure(row)
    ksat = float(r3.e2c.c1.core.KSAT)
    rows=[]; ref_fail=0; unresolved=0; nonfinite=0; maxk=0; maxroot=0
    for p in e3a.probes(material, face_class):
        ha=float(p["h_above"]); hb=float(p["h_below"])
        try:
            qref=float(r3.e2c.c1.core.steady_q(ha,hb))
        except Exception:
            ref_fail += 1; continue
        try:
            qc,cost=candidate_q(ha,hb)
        except RuntimeError:
            unresolved += 1; continue
        except (FloatingPointError,OverflowError,ValueError):
            nonfinite += 1; continue
        if not (math.isfinite(qref) and math.isfinite(qc)):
            nonfinite += 1; continue
        hybrid,absolute,wrong_sign=r3.e2c._metric(qref,qc,ksat)
        maxk=max(maxk,int(cost["constitutive_K_evaluations"])); maxroot=max(maxroot,int(cost["root_residual_evaluations"]))
        rows.append({"probe_id":p["id"],"kind":p["kind"],"h_above":ha,"h_below":hb,"q_ref":qref,"q_candidate":qc,"branch":cost["branch"],"hybrid_metric":hybrid,"abs_error_over_ksatfit":absolute,"wrong_sign":wrong_sign})
    hs=sorted(r["hybrid_metric"] for r in rows)
    p99=hs[int(0.99*(len(hs)-1))] if hs else math.inf
    mh=max(hs) if hs else math.inf
    ma=max((r["abs_error_over_ksatfit"] for r in rows),default=math.inf)
    wrong=sum(r["wrong_sign"] for r in rows)
    endpoint=[r for r in rows if "ENDPOINT_LIMIT" in r["branch"]]
    eh=max((r["hybrid_metric"] for r in endpoint),default=0.0)
    ea=max((r["abs_error_over_ksatfit"] for r in endpoint),default=0.0)
    lower=[r for r in rows if r["branch"]=="LOWER_SIDE_K_ABOVE_ENDPOINT_LIMIT"]
    tests={
      "reference_failure_count":ref_fail==0,"candidate_unresolved_count":unresolved==0,"candidate_nonfinite_count":nonfinite==0,
      "wrong_sign_count":wrong==0,"max_hybrid_metric":mh<=HYBRID_MAX,"p99_hybrid_metric":p99<=HYBRID_P99,
      "max_abs_error_over_ksatfit":ma<=ABS_KSAT_MAX,"endpoint_limit_max_hybrid_metric":eh<=ENDPOINT_HYBRID_MAX,
      "endpoint_limit_max_abs_error_over_ksatfit":ea<=ENDPOINT_ABS_MAX,"max_constitutive_K_evaluations":maxk<=MAX_K,"max_root_residual_evaluations":maxroot<=MAX_ROOT}
    return {"material":material,"face_class":face_class,"probe_count":len(e3a.probes(material,face_class)),"valid_probe_count":len(rows),
      "reference_failure_count":ref_fail,"candidate_unresolved_count":unresolved,"candidate_nonfinite_count":nonfinite,"wrong_sign_count":wrong,
      "endpoint_limit_count":len(endpoint),"lower_side_endpoint_limit_count":len(lower),"max_hybrid_metric":mh,"p99_hybrid_metric":p99,
      "max_abs_error_over_ksatfit":ma,"endpoint_limit_max_hybrid_metric":eh,"endpoint_limit_max_abs_error_over_ksatfit":ea,
      "max_constitutive_K_evaluations":maxk,"max_root_residual_evaluations":maxroot,"tests":tests,
      "failed_metrics":[k for k,v in tests.items() if not v],"pass":all(tests.values()),
      "worst_lower_side_endpoint_probe":max(lower,key=lambda r:r["hybrid_metric"]) if lower else None}


def main():
    if len(sys.argv)!=2: raise SystemExit("usage: run_ross01_gate_e3a_r2_two_sided_k_endpoint_limit.py OUTPUT.json")
    out=Path(sys.argv[1]); catalog=json.loads(CATALOG.read_text()); by={r["sfu"]:r for r in catalog["rows"]}
    results=[]
    for m in MATERIALS:
      for c in CLASSES:
        rr=characterize(m,c,by[m]); results.append(rr)
        print(json.dumps({"material":m,"face_class":c,"pass":rr["pass"],"unresolved":rr["candidate_unresolved_count"],"lower_side_endpoint_limit_count":rr["lower_side_endpoint_limit_count"],"max_hybrid_metric":rr["max_hybrid_metric"]},sort_keys=True),flush=True)
    passed=all(r["pass"] for r in results)
    result={"schema_version":1,"workstream":"F-ROSS","work_unit":"F-ROSS01","gate":"E3A_R2_TWO_SIDED_K_ENDPOINT_LIMIT_FACE_SCOPE_QUALIFICATION",
      "contract":CONTRACT,"production_implementation":False,"new_persistent_state_bytes":0,"new_constitutive_physics":False,
      "quadrature_changed":False,"root_iteration_count_changed":False,"metric_tolerances_changed":False,"results":results,
      "total_lower_side_endpoint_limit_count":sum(r["lower_side_endpoint_limit_count"] for r in results),"pass":passed,
      "decision":"QUALIFIED_E3_ENCOUNTERED_FACE_SCOPE_WITH_TWO_SIDED_K_ENDPOINT_LIMIT_READY_FOR_EVENT_AND_SOLVER_REMEDIATION" if passed else "TWO_SIDED_K_ENDPOINT_LIMIT_FACE_SCOPE_NOT_QUALIFIED_RESEARCH_REQUIRED",
      "hard_nonclaims":["No E3 column requalification.","No wetting-event admission.","No O14 qualification-solver remediation.","No response tangent/runtime/MultiSWAP qualification."]}
    out.parent.mkdir(parents=True,exist_ok=True); out.write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    print(json.dumps({"pass":passed,"decision":result["decision"],"total_lower_side_endpoint_limit_count":result["total_lower_side_endpoint_limit_count"]},sort_keys=True))
    if not passed: raise SystemExit(1)

if __name__=="__main__": main()
