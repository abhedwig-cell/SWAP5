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
    HREF_EXPECTED,
    QREF_EXPECTED,
    STARTS,
    FLUX_TOL,
    initialize_checked,
    trial_discard,
    estimate_e3_map,
    residual_at,
    run_policy,
)
from test_gc_fixed_interface_map09_groundwater_calibration_g12a import (
    resolve_sy,
    one_shot_bias,
    local_fit,
)

PREREG=ROOT/"integration"/"research"/"GC_FIXED_INTERFACE_G12B_PREREGISTRATION.json"
G12_PREREG=ROOT/"integration"/"research"/"GC_FIXED_INTERFACE_G12_PREREGISTRATION.json"
G12A_RESULT=ROOT/"integration"/"research"/"GC_FIXED_INTERFACE_G12A_RESULT.json"

ROOT_BISECTIONS=50
HEAD_TOL=5.0e-10
SLOPE_REL_TOL=1.0e-8
QHREF_ABS_TOL=2.0e-16


def require(cond:bool,msg:str)->None:
    if not cond:
        raise AssertionError(msg)


def load_authority()->tuple[dict[str,object],list[dict[str,object]],dict[str,dict[str,object]]]:
    p=json.loads(PREREG.read_text())
    require(p["work_unit"]=="GC-FIXED-INTERFACE-G12B","wrong G12B preregistration")
    require(p["status"]=="PREREGISTERED_BEFORE_EXECUTION","G12B preregistration not frozen")
    require(int(p["reference_root"]["rule"].split("Perform ")[1].split(" fixed")[0])==ROOT_BISECTIONS,
            "G12B root bisection count drifted")
    require(float(p["convergence"]["head_error_tolerance_m"])==HEAD_TOL,
            "G12B head tolerance drifted")
    g12=json.loads(G12_PREREG.read_text())
    regimes=[dict(x) for x in g12["groundwater_regimes"]]
    g12a=json.loads(G12A_RESULT.read_text())
    require(g12a["decision"]=="QUALIFIED_DIAGNOSTIC_G12_MISS_IS_ONE_SHOT_BIAS_ANCHORING_NOT_LOCAL_AFFINE_FIT_ERROR",
            "G12A diagnostic authority not qualified")
    auth={str(x["regime_id"]):dict(x) for x in g12a["regime_results"]}
    require(set(auth)=={str(x["id"]) for x in regimes},"G12B/G12A regime authority mismatch")
    return p,regimes,auth


def remeasure_groundwater(
    libmf6:Path,
    swaplib:Path,
    href:float,
    qref:float,
    p_href:float,
    regime:dict[str,object],
    authority:dict[str,object],
)->dict[str,object]:
    sy=resolve_sy(str(regime["sy_rule"]),p_href)
    cal=one_shot_bias(libmf6,swaplib,href,qref,regime,sy)
    persisted_cal=authority["one_shot_calibration"]
    require(abs(float(cal["frozen_bias_m"])-float(persisted_cal["frozen_bias_m"]))<=1.0e-15,
            f"G12B one-shot bias drift {regime['id']}")
    fit=local_fit(
        libmf6,swaplib,href,qref,regime,sy,float(cal["frozen_bias_m"])
    )
    persisted=authority["local_fit"]
    slope_rel=abs(float(fit["a_per_s"])-float(persisted["a_per_s"]))/max(
        abs(float(fit["a_per_s"])),abs(float(persisted["a_per_s"]))
    )
    qdiff=abs(float(fit["q_at_href_m_per_s"])-float(persisted["q_at_href_m_per_s"]))
    require(slope_rel<=SLOPE_REL_TOL,
            f"G12B groundwater slope authority mismatch {regime['id']} {slope_rel}")
    require(qdiff<=QHREF_ABS_TOL,
            f"G12B groundwater q_at_href authority mismatch {regime['id']} {qdiff}")
    return {
        "regime_id":str(regime["id"]),
        "k_m_per_day":float(regime["k_m_per_day"]),
        "ss_per_m":float(regime["ss_per_m"]),
        "sy":sy,
        "head_bias_m":float(cal["frozen_bias_m"]),
        "a_per_s":float(fit["a_per_s"]),
        "q_at_href_m_per_s":float(fit["q_at_href_m_per_s"]),
        "fit_error_m_per_s":float(fit["max_fit_error_m_per_s"]),
        "slope_relative_to_g12a":slope_rel,
        "q_at_href_abs_difference_from_g12a_m_per_s":qdiff,
        "points":fit["points"],
    }


def reference_root(
    swap:Map09ActiveDrainageSwap,
    origin:tuple[int,float,int,float],
    href:float,
    gw:dict[str,object],
)->dict[str,object]:
    lo=href-1.0e-6
    hi=href+1.0e-6
    a=float(gw["a_per_s"])
    qh=float(gw["q_at_href_m_per_s"])
    slo,_,rlo=residual_at(swap,origin,lo,href,a,qh)
    shi,_,rhi=residual_at(swap,origin,hi,href,a,qh)
    require(slo==0 and shi==0 and rlo is not None and rhi is not None,
            f"G12B reference bracket inadmissible {gw['regime_id']}")
    require(rlo==0.0 or rhi==0.0 or rlo*rhi<0.0,
            f"G12B reference bracket has no sign change {gw['regime_id']} {rlo} {rhi}")

    trace=[]
    for i in range(1,ROOT_BISECTIONS+1):
        mid=0.5*(lo+hi)
        sm,_,rm=residual_at(swap,origin,mid,href,a,qh)
        require(sm==0 and rm is not None,
                f"G12B reference bisection inadmissible {gw['regime_id']} iter={i}")
        trace.append({"iteration":i,"head_m":mid,"residual_m_per_s":rm})
        if rm==0.0:
            lo=hi=mid
            rlo=rhi=rm
        elif rlo==0.0:
            hi=lo
            rhi=rlo
        elif rlo*rm<=0.0:
            hi=mid
            rhi=rm
        else:
            lo=mid
            rlo=rm
    root=0.5*(lo+hi)
    sr,_,rr=residual_at(swap,origin,root,href,a,qh)
    require(sr==0 and rr is not None,"G12B final reference root inadmissible")
    return {
        "head_m":root,
        "dh_m":root-href,
        "residual_m_per_s":rr,
        "final_bracket_width_m":abs(hi-lo),
        "trace":trace,
    }


def main()->None:
    _,regimes,authority=load_authority()
    libmf6=Path(os.environ["LIBMF6"]).resolve()
    swaplib=Path(os.environ["MAP09_SWAP_LIB"]).resolve()
    require(libmf6.is_file(),"missing G12B MODFLOW library")
    require(swaplib.is_file(),"missing G12B MAP09 SWAP library")

    swap=Map09ActiveDrainageSwap(swaplib)
    href,pred,origin=initialize_checked(swap)
    require(abs(href-HREF_EXPECTED)<=1e-14,"G12B href drift")
    status,qref=trial_discard(swap,origin,href)
    require(status==0 and abs(qref-QREF_EXPECTED)<=1e-18,"G12B qref authority drift")

    estimator_rows=[]
    for label,dh in (("HREF",0.0),("NEG",STARTS[0]),("POS",STARTS[1])):
        e3=estimate_e3_map(swap,origin,href+dh)
        require(e3["classification"]=="AVAILABLE",f"G12B E3 unavailable {label}")
        estimator_rows.append({"label":label,"dh_m":dh,"e3":e3})
        print("GC_G12B_ESTIMATOR_JSON="+json.dumps(estimator_rows[-1],sort_keys=True,separators=(",",":")))
    p_href=float(estimator_rows[0]["e3"]["slope_per_s"])

    gw_rows=[]
    root_rows=[]
    policy_rows=[]
    for regime in regimes:
        rid=str(regime["id"])
        gw=remeasure_groundwater(libmf6,swaplib,href,qref,p_href,regime,authority[rid])
        gw_rows.append(gw)
        print("GC_G12B_GROUNDWATER_JSON="+json.dumps(gw,sort_keys=True,separators=(",",":")))
        root=reference_root(swap,origin,href,gw)
        root_rows.append({"regime_id":rid,**root})
        print("GC_G12B_ROOT_JSON="+json.dumps(root_rows[-1],sort_keys=True,separators=(",",":")))

        for side,dh in (("NEG",STARTS[0]),("POS",STARTS[1])):
            for policy in ("P1_E3_MAP","P4_E3_MAP"):
                result=run_policy(policy,libmf6,swaplib,swap,origin,href,dh,gw)
                head_error=None
                if result.get("final_head_m") is not None:
                    head_error=float(result["final_head_m"])-float(root["head_m"])
                row={
                    "regime_id":rid,
                    "start_side":side,
                    "start_dh_m":dh,
                    "policy":policy,
                    "reference_root_m":root["head_m"],
                    "head_error_from_reference_m":head_error,
                    **result,
                }
                policy_rows.append(row)
                print("GC_G12B_POLICY_JSON="+json.dumps(row,sort_keys=True,separators=(",",":")))

    p1=[x for x in policy_rows if x["policy"]=="P1_E3_MAP"]
    p4=[x for x in policy_rows if x["policy"]=="P4_E3_MAP"]
    require(len(p4)==6,"G12B P4 matrix incomplete")
    require(all(x["classification"]=="CONVERGED" for x in p4),
            f"G12B P4 did not converge all cases: {p4}")
    require(all(x["head_error_from_reference_m"] is not None and
                abs(float(x["head_error_from_reference_m"]))<=HEAD_TOL for x in p4),
            f"G12B P4 head-reference gate failed: {p4}")
    require(swap.state()==origin,"G12B changed accepted MAP09 authority")

    summary={
        "active_drainage_coverage":bool(swap.drainage_coverage()),
        "groundwater_regime_count":len(gw_rows),
        "reference_root_count":len(root_rows),
        "policy_case_count":len(policy_rows),
        "p1_case_count":len(p1),
        "p1_converged_count":sum(x["classification"]=="CONVERGED" for x in p1),
        "p4_case_count":len(p4),
        "p4_converged_count":sum(x["classification"]=="CONVERGED" for x in p4),
        "p4_total_contractions":sum(int(x.get("contractions",0)) for x in p4),
        "p4_raw_inadmissible_total":sum(int(x.get("raw_inadmissible",0)) for x in p4),
        "max_abs_p4_head_error_m":max(abs(float(x["head_error_from_reference_m"])) for x in p4),
        "max_groundwater_fit_error_m_per_s":max(float(x["fit_error_m_per_s"]) for x in gw_rows),
    }
    print("GC_G12B_SUMMARY_JSON="+json.dumps(summary,sort_keys=True,separators=(",",":")))
    print("GC_G12B_G12_FALSIFICATION_PRESERVED=PASS")
    print("GC_G12B_GROUNDWATER_AUTHORITY=PASS")
    print("GC_G12B_REFERENCE_ROOTS=PASS")
    print("GC_G12B_TRANSACTION_AUTHORITY=PASS")
    print("GC_FIXED_INTERFACE_G12B_EXECUTION=PASS")


if __name__=="__main__":
    main()
