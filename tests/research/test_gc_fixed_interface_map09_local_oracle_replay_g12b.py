from __future__ import annotations

import json
import math
import os
import sys
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/"tests"/"research"))
sys.path.insert(0,str(ROOT/"tests"/"research"/"support"))

from gc_map09_e6_ctypes import Map09ActiveDrainageSwap
from test_gc_fixed_interface_map09_active_drainage_g12 import (
    HREF_EXPECTED,QREF_EXPECTED,STARTS,FLUX_TOL,
    initialize_checked,estimate_e3_map,residual_at,run_policy,
)
from test_gc_fixed_interface_map09_groundwater_calibration_g12a import local_fit

PREREG=ROOT/"integration"/"research"/"GC_FIXED_INTERFACE_G12B_PREREGISTRATION.json"
G12A_RESULT=ROOT/"integration"/"research"/"GC_FIXED_INTERFACE_G12A_RESULT.json"

SLOPE_REL_TOL=1.0e-8
QHREF_ABS_TOL=2.0e-16
FIT_TOL=1.0e-16
ROOT_BISECTIONS=50
HEAD_TOL=5.0e-10


def require(cond:bool,msg:str)->None:
    if not cond:
        raise AssertionError(msg)


def load_authority()->tuple[dict[str,object],list[dict[str,object]]]:
    p=json.loads(PREREG.read_text())
    require(p["work_unit"]=="GC-FIXED-INTERFACE-G12B","wrong G12B preregistration")
    require(p["status"]=="PREREGISTERED_BEFORE_EXECUTION","G12B preregistration not frozen")
    require(tuple(float(x) for x in p["frozen_carrier"]["starts_dh_m"])==STARTS,
            "G12B starts drifted")
    require(int(p["reference_root"]["rule"].split("Perform ")[1].split(" fixed")[0])==ROOT_BISECTIONS,
            "G12B root bisection count drifted")
    require(float(p["reference_root"]["head_tolerance_m"])==HEAD_TOL,
            "G12B head tolerance drifted")
    a=json.loads(G12A_RESULT.read_text())
    require(a["decision"]=="QUALIFIED_DIAGNOSTIC_G12_MISS_IS_ONE_SHOT_BIAS_ANCHORING_NOT_LOCAL_AFFINE_FIT_ERROR",
            "G12B parent G12A authority not qualified")
    return p,[dict(x) for x in a["regime_results"]]


def reference_root(
    swap:Map09ActiveDrainageSwap,
    origin:tuple[int,float,int,float],
    href:float,
    a:float,
    q_at_href:float,
)->dict[str,object]:
    lo=href+STARTS[0]
    hi=href+STARTS[1]
    slo,_,rlo=residual_at(swap,origin,lo,href,a,q_at_href)
    shi,_,rhi=residual_at(swap,origin,hi,href,a,q_at_href)
    require(slo==0 and shi==0 and rlo is not None and rhi is not None,
            "G12B reference-root bracket head inadmissible")
    require(rlo==0.0 or rhi==0.0 or rlo*rhi<0.0,
            f"G12B reference-root bracket has no sign change: {rlo}, {rhi}")
    trace=[]
    if rlo==0.0:
        return {"head_m":lo,"residual_m_per_s":rlo,"bisections":0,"trace":trace}
    if rhi==0.0:
        return {"head_m":hi,"residual_m_per_s":rhi,"bisections":0,"trace":trace}

    mid=0.5*(lo+hi)
    rmid=float("nan")
    for i in range(1,ROOT_BISECTIONS+1):
        mid=0.5*(lo+hi)
        sm,_,rmid0=residual_at(swap,origin,mid,href,a,q_at_href)
        require(sm==0 and rmid0 is not None,
                f"G12B reference-root midpoint inadmissible at iteration {i}")
        rmid=float(rmid0)
        trace.append({"iteration":i,"head_m":mid,"residual_m_per_s":rmid})
        if rlo*rmid<=0.0:
            hi=mid
            rhi=rmid
        else:
            lo=mid
            rlo=rmid
    return {
        "head_m":mid,
        "residual_m_per_s":rmid,
        "bisections":ROOT_BISECTIONS,
        "final_bracket_width_m":hi-lo,
        "trace":trace,
    }


def main()->None:
    _,authorities=load_authority()
    libmf6=Path(os.environ["LIBMF6"]).resolve()
    swaplib=Path(os.environ["MAP09_SWAP_LIB"]).resolve()
    require(libmf6.is_file(),"missing G12B MODFLOW library")
    require(swaplib.is_file(),"missing G12B MAP09 SWAP library")

    swap=Map09ActiveDrainageSwap(swaplib)
    href,pred,origin=initialize_checked(swap)
    require(math.isclose(href,HREF_EXPECTED,rel_tol=0.0,abs_tol=1e-14),
            "G12B href authority drift")
    status,qref=swap.try_trial(href)
    require(status==0 and math.isfinite(qref),"G12B href corrector unavailable")
    swap.discard()
    require(math.isclose(qref,QREF_EXPECTED,rel_tol=0.0,abs_tol=1e-18),
            "G12B qref authority drift")
    require(swap.state()==origin,"G12B href trial mutated authority")

    estimator_rows=[]
    for label,dh in (("HREF",0.0),("NEG",STARTS[0]),("POS",STARTS[1])):
        e3=estimate_e3_map(swap,origin,href+dh)
        require(e3["classification"]=="AVAILABLE",f"G12B E3_MAP unavailable {label}")
        row={"label":label,"dh_m":dh,"e3":e3}
        estimator_rows.append(row)
        print("GC_G12B_ESTIMATOR_JSON="+json.dumps(row,sort_keys=True,separators=(",",":")))

    replay_authorities=[]
    policy_rows=[]
    root_rows=[]
    for auth in authorities:
        regime_id=str(auth["regime_id"])
        sy=float(auth["sy"])
        bias=float(auth["one_shot_calibration"]["frozen_bias_m"])
        a0=float(auth["local_fit"]["a_per_s"])
        qh0=float(auth["local_fit"]["q_at_href_m_per_s"])
        regime={
            "id":regime_id,
            "k_m_per_day":float(auth["k_m_per_day"]),
            "ss_per_m":float(auth["ss_per_m"]),
        }
        measured=local_fit(libmf6,swaplib,href,qref,regime,sy,bias)
        a=float(measured["a_per_s"])
        qh=float(measured["q_at_href_m_per_s"])
        slope_rel=abs(a-a0)/max(abs(a),abs(a0))
        qdiff=abs(qh-qh0)
        require(float(measured["max_fit_error_m_per_s"])<=FIT_TOL,
                f"G12B local fit error {regime_id}")
        require(slope_rel<=SLOPE_REL_TOL,
                f"G12B slope authority drift {regime_id}: {slope_rel}")
        require(qdiff<=QHREF_ABS_TOL,
                f"G12B q_at_href authority drift {regime_id}: {qdiff}")

        gw={
            "regime_id":regime_id,
            "k_m_per_day":regime["k_m_per_day"],
            "ss_per_m":regime["ss_per_m"],
            "sy":sy,
            "head_bias_m":bias,
            "a_per_s":a,
            "q_at_href_m_per_s":qh,
            "fit_error_m_per_s":float(measured["max_fit_error_m_per_s"]),
        }
        authority_row={
            **gw,
            "parent_a_per_s":a0,
            "parent_q_at_href_m_per_s":qh0,
            "slope_relative_difference":slope_rel,
            "q_at_href_absolute_difference_m_per_s":qdiff,
        }
        replay_authorities.append(authority_row)
        print("GC_G12B_GROUNDWATER_JSON="+json.dumps(authority_row,sort_keys=True,separators=(",",":")))

        root=reference_root(swap,origin,href,a,qh)
        root_row={"regime_id":regime_id,**root}
        root_rows.append(root_row)
        print("GC_G12B_ROOT_JSON="+json.dumps(root_row,sort_keys=True,separators=(",",":")))

        for side,dh in (("NEG",STARTS[0]),("POS",STARTS[1])):
            for policy in ("P1_E3_MAP","P4_E3_MAP"):
                res=run_policy(policy,libmf6,swaplib,swap,origin,href,dh,gw)
                row={
                    "regime_id":regime_id,
                    "start_side":side,
                    "start_dh_m":dh,
                    "policy":policy,
                    "reference_root_m":root["head_m"],
                    **res,
                }
                if res.get("final_head_m") is not None:
                    row["head_error_m"]=float(res["final_head_m"])-float(root["head_m"])
                policy_rows.append(row)
                print("GC_G12B_POLICY_JSON="+json.dumps(row,sort_keys=True,separators=(",",":")))
                if policy=="P4_E3_MAP":
                    require(res["classification"]=="CONVERGED",
                            f"G12B P4 failed {regime_id} {side}: {res}")
                    require(abs(float(res["final_residual_m_per_s"]))<=FLUX_TOL,
                            f"G12B P4 residual gate failed {regime_id} {side}")
                    require(abs(float(row["head_error_m"]))<=HEAD_TOL,
                            f"G12B P4 head/root gate failed {regime_id} {side}: {row['head_error_m']}")

    require(swap.state()==origin,"G12B diagnostics mutated accepted MAP09 authority")
    p1=[x for x in policy_rows if x["policy"]=="P1_E3_MAP"]
    p4=[x for x in policy_rows if x["policy"]=="P4_E3_MAP"]
    require(len(p4)==6,"G12B incomplete P4 matrix")

    summary={
        "active_drainage_coverage":bool(swap.drainage_coverage()),
        "estimator_available_count":len(estimator_rows),
        "groundwater_regime_count":len(replay_authorities),
        "reference_root_count":len(root_rows),
        "policy_case_count":len(policy_rows),
        "p1_case_count":len(p1),
        "p1_converged_count":sum(x["classification"]=="CONVERGED" for x in p1),
        "p4_case_count":len(p4),
        "p4_converged_count":sum(x["classification"]=="CONVERGED" for x in p4),
        "p4_total_contractions":sum(int(x.get("contractions",0)) for x in p4),
        "p4_raw_inadmissible_total":sum(int(x.get("raw_inadmissible",0)) for x in p4),
        "max_p4_head_error_m":max(abs(float(x["head_error_m"])) for x in p4),
        "max_groundwater_fit_error_m_per_s":max(float(x["fit_error_m_per_s"]) for x in replay_authorities),
        "max_groundwater_authority_q_difference_m_per_s":max(float(x["q_at_href_absolute_difference_m_per_s"]) for x in replay_authorities),
    }
    print("GC_G12B_SUMMARY_JSON="+json.dumps(summary,sort_keys=True,separators=(",",":")))
    print("GC_G12B_MAP09_PROCESS_BINDING=PASS")
    print("GC_G12B_GROUNDWATER_AUTHORITY=PASS")
    print("GC_G12B_REFERENCE_ROOTS=PASS")
    print("GC_G12B_TRANSACTION_AUTHORITY=PASS")
    print("GC_FIXED_INTERFACE_G12B_EXECUTION=PASS")


if __name__=="__main__":
    main()
