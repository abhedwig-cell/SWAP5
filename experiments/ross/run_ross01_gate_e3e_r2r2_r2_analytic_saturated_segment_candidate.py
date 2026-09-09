from __future__ import annotations

import json
import math
import sys
from pathlib import Path

import mpmath as mp

HERE=Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0,str(HERE))

import run_ross01_gate_e2c_r2_endpoint_clustered_local_face as e2c_r2
import run_ross01_gate_e3e_r2r2_fresh_5cm_reference_characterization as fresh
import run_ross01_gate_e3e_r2r2_r1_exact_physical_upper_bracket as exact_ref

old_e3e=fresh.old_e3e
r2=fresh.r2

CONTRACT="F-ROSS01_GATE_E3E_R2R2_R2_ANALYTIC_SATURATED_SEGMENT_CANDIDATE_REMEDIATION_PRECOMMIT.json"
CATALOG=Path("integration/f-ross/F-ROSS01_GATE_C1_MATERIAL_CATALOG.json")
MATERIALS=("B01","B12","O13","O14")
HYBRID_MAX=0.01
ABS_MAX=0.0005
MAX_K=530
MAX_ROOT=66
REF_RES=1e-8

DEFECT={
    "B01": {"id":"fresh_near_0023","h_surface":0.8418598139923603,"h_top_node":-1.7857563818019415e-08},
    "O14": {"id":"fresh_near_0003","h_surface":0.37579678846033,"h_top_node":-1.9219207863995577e-08},
}


def split_candidate(hs: float, ht: float):
    if not (hs > 0.0 and ht < 0.0):
        return old_e3e.candidate_q(hs,ht)
    ks=float(old_e3e.e2c.c1.core.KSAT)
    unsat_residual=e2c_r2.endpoint_clustered_residual_factory(0.0,ht)
    def residual(q: float) -> float:
        if not q > ks:
            return math.inf
        sat=hs*ks/(q-ks)
        unsat_path=unsat_residual(q)+float(old_e3e.e2c.LENGTH)
        return sat+unsat_path-float(old_e3e.e2c.LENGTH)
    lo=math.nextafter(ks,math.inf)
    hi=ks*(1.0+(hs-ht)/float(old_e3e.e2c.LENGTH))
    flo=residual(lo); fhi=residual(hi); evals=2
    if not (math.isfinite(flo) and math.isfinite(fhi)):
        raise FloatingPointError(("split_nonfinite_bracket",flo,fhi))
    if flo==0.0:
        q=lo
    elif fhi==0.0:
        q=hi
    else:
        if flo*fhi>0.0:
            raise RuntimeError(("split_bracket_failure",hs,ht,lo,hi,flo,fhi))
        for _ in range(old_e3e.e2c.BISECTION_STEPS):
            mid=0.5*(lo+hi); fm=residual(mid); evals+=1
            if not math.isfinite(fm):
                raise FloatingPointError(("split_nonfinite_mid",mid,fm))
            if fm==0.0:
                lo=hi=mid
                break
            if flo*fm<=0.0:
                hi=mid; fhi=fm
            else:
                lo=mid; flo=fm
        q=0.5*(lo+hi)
    return q, {
        "branch":"SURFACE_SATURATED_ANALYTIC_SPLIT_BISECTION",
        "root_residual_evaluations":evals,
        "constitutive_K_evaluations":int(unsat_residual.k_eval_count),
    }


def reference_b(hs: float, ht: float, row: dict):
    hsm=mp.mpf(str(hs)); htm=mp.mpf(str(ht)); ks=mp.mpf(str(row["ksatfit_cm_per_day"]))
    d,_,res,_=exact_ref.exact_solve_b(hsm,htm,row)
    return float(ks*(1+d)),float(res)


def reference_a(hs: float, ht: float, row: dict):
    hsm=mp.mpf(str(hs)); htm=mp.mpf(str(ht)); ks=mp.mpf(str(row["ksatfit_cm_per_day"]))
    d,_,res=exact_ref.exact_solve_a(hsm,htm,row)
    return float(ks*(1+d)),float(res)


def probes_for(material: str):
    byid={p["id"]:p for p in fresh.build_fresh(material)}
    probes=[]
    if material in DEFECT:
        probes.append(dict(DEFECT[material],kind="defect_or_negative_control"))
    for pid in ("fresh_near_0011","fresh_dry_0007"):
        p=byid[pid]
        probes.append({"id":pid,"h_surface":p["h_surface"],"h_top_node":p["h_top_node"],"kind":"ordinary_control"})
    return probes


def run_material(row: dict):
    material=row["sfu"]
    old_e3e.configure_5cm(row)
    ks=float(old_e3e.e2c.c1.core.KSAT)
    rows=[]; unresolved=0; nonfinite=0; maxk=0; maxroot=0
    for p in probes_for(material):
        hs=float(p["h_surface"]); ht=float(p["h_top_node"])
        try:
            qr,rr=reference_b(hs,ht,row)
        except Exception as exc:
            rows.append({"probe_id":p["id"],"reference_error":repr(exc),"pass":False}); continue
        try:
            qc,cost=split_candidate(hs,ht)
        except RuntimeError as exc:
            unresolved+=1; rows.append({"probe_id":p["id"],"candidate_error":repr(exc),"pass":False}); continue
        except (FloatingPointError,OverflowError,ValueError) as exc:
            nonfinite+=1; rows.append({"probe_id":p["id"],"candidate_error":repr(exc),"pass":False}); continue
        hybrid,absolute,wrong=old_e3e.e2c._metric(qr,float(qc),ks)
        maxk=max(maxk,int(cost["constitutive_K_evaluations"])); maxroot=max(maxroot,int(cost["root_residual_evaluations"]))
        tests={
            "reference_residual":abs(rr)<=REF_RES,
            "candidate_finite":math.isfinite(qc),
            "analytic_split_branch":cost["branch"]=="SURFACE_SATURATED_ANALYTIC_SPLIT_BISECTION",
            "hybrid_metric":hybrid<=HYBRID_MAX,
            "abs_error_over_ksat":absolute<=ABS_MAX,
            "wrong_sign":wrong==0,
            "k_cost":int(cost["constitutive_K_evaluations"])<=MAX_K,
            "root_cost":int(cost["root_residual_evaluations"])<=MAX_ROOT,
            "defect_not_ksat_fallback":p["id"]!="fresh_near_0023" or abs(float(qc)-ks)>1e-10*ks,
        }
        rowout={
            "probe_id":p["id"],"kind":p["kind"],"h_surface_cm":hs,"h_top_node_cm":ht,
            "q_reference_cm_per_day":qr,"q_candidate_cm_per_day":float(qc),"candidate_branch":cost["branch"],
            "reference_path_residual_cm":rr,"hybrid_metric":hybrid,"abs_error_over_ksatfit":absolute,"wrong_sign":wrong,
            "root_residual_evaluations":int(cost["root_residual_evaluations"]),"constitutive_K_evaluations":int(cost["constitutive_K_evaluations"]),
            "tests":tests,"failed_metrics":[k for k,v in tests.items() if not v],"pass":all(tests.values())
        }
        if p["id"] in ("fresh_near_0023","fresh_near_0003"):
            qa,ra=reference_a(hs,ht,row)
            rowout["oracle_a_q_cm_per_day"]=qa
            rowout["oracle_a_path_residual_cm"]=ra
            rowout["oracle_pair_abs_error_over_ksat"]=abs(qa-qr)/ks
            rowout["oracle_pair_pass"]=abs(qa-qr)/ks<=1e-9 and abs(ra)<=1e-10
            rowout["pass"]=rowout["pass"] and rowout["oracle_pair_pass"]
            if not rowout["oracle_pair_pass"]:
                rowout["failed_metrics"].append("oracle_pair")
        rows.append(rowout)
    valid=[r for r in rows if "hybrid_metric" in r]
    tests={
        "all_witnesses_resolved":len(valid)==len(probes_for(material)),
        "candidate_unresolved_zero":unresolved==0,
        "candidate_nonfinite_zero":nonfinite==0,
        "all_rows_pass":len(rows)==len(probes_for(material)) and all(r.get("pass",False) for r in rows),
        "max_hybrid_metric":max((r["hybrid_metric"] for r in valid),default=math.inf)<=HYBRID_MAX,
        "max_abs_error":max((r["abs_error_over_ksatfit"] for r in valid),default=math.inf)<=ABS_MAX,
        "wrong_sign_zero":sum(r["wrong_sign"] for r in valid)==0,
        "max_k_cost":maxk<=MAX_K,
        "max_root_cost":maxroot<=MAX_ROOT,
    }
    return {
        "material":material,"witness_count":len(probes_for(material)),"valid_count":len(valid),"rows":rows,
        "candidate_unresolved_count":unresolved,"candidate_nonfinite_count":nonfinite,
        "max_hybrid_metric":max((r["hybrid_metric"] for r in valid),default=math.inf),
        "max_abs_error_over_ksatfit":max((r["abs_error_over_ksatfit"] for r in valid),default=math.inf),
        "wrong_sign_count":sum(r["wrong_sign"] for r in valid),"max_constitutive_K_evaluations":maxk,"max_root_residual_evaluations":maxroot,
        "tests":tests,"failed_metrics":[k for k,v in tests.items() if not v],"pass":all(tests.values())
    }


def main():
    if len(sys.argv)!=3:
        raise SystemExit("usage: run_ross01_gate_e3e_r2r2_r2_analytic_saturated_segment_candidate.py MATERIAL OUTPUT.json")
    material=sys.argv[1]; out=Path(sys.argv[2])
    if material not in MATERIALS: raise SystemExit(material)
    catalog=json.loads(CATALOG.read_text(encoding="utf-8")); row=next(r for r in catalog["rows"] if r["sfu"]==material)
    mr=run_material(row); passed=mr["pass"]
    payload={"schema_version":1,"workstream":"F-ROSS","work_unit":"F-ROSS01","gate":"E3E_R2R2_R2_ANALYTIC_SATURATED_SEGMENT_CANDIDATE_REMEDIATION","contract":CONTRACT,"material":material,"production_implementation":False,"qualification_target":"POSITIVE_SURFACE_TO_UNSATURATED_5CM_FACE_CANDIDATE_BRANCH_ONLY","material_result":mr,"pass":passed,"decision":"QUALIFIED_ANALYTIC_SATURATED_SEGMENT_SURFACE_FACE_REMEDIATION_READY_FOR_IDENTICAL_320_CASE_FRESH_RERUN" if passed else "ANALYTIC_SATURATED_SEGMENT_SURFACE_FACE_REMEDIATION_NOT_QUALIFIED_FURTHER_CANDIDATE_RESEARCH_REQUIRED","hard_nonclaims":["No 320-case requalification yet.","No h_surface=0 endpoint change.","No endpoint tangent qualification.","No surface ledger/runtime/MultiSWAP/groundwater admission."]}
    out.parent.mkdir(parents=True,exist_ok=True); out.write_text(json.dumps(payload,indent=2,sort_keys=True)+"\n",encoding="utf-8")
    print(json.dumps({"material":material,"pass":passed,"witness_count":mr["witness_count"],"max_hybrid_metric":mr["max_hybrid_metric"],"max_abs_error_over_ksatfit":mr["max_abs_error_over_ksatfit"],"max_k":mr["max_constitutive_K_evaluations"],"max_root":mr["max_root_residual_evaluations"],"failed_metrics":mr["failed_metrics"],"decision":payload["decision"]},sort_keys=True),flush=True)
    if not passed: raise SystemExit(1)

if __name__=="__main__": main()
