from __future__ import annotations

import json
import math
import os
import sys
from pathlib import Path

import numpy as np

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/"tests"/"research"))
sys.path.insert(0,str(ROOT/"tests"/"fgc"/"support"))

from fgc44_real_swap_ctypes import Fgc44RealSwap
from test_gc_fixed_interface_fgc44_safeguarded_newton_g08 import (
    AREA_M2,DAY_TO_S,initialize_case,solve_term,trial_discard
)
from test_gc_fixed_interface_fgc44_stencil_class_tangent_g09d import estimate_e3

PREREG=ROOT/"integration"/"research"/"GC_FIXED_INTERFACE_G11_PREREGISTRATION.json"

DURATION_DAY=1.0e-2
QBOT_CM_PER_DAY=1.0e-6
HREF_EXPECTED=-0.7149999311459918
U_EXPECTED=0.00119027208545508
START_DH=0.0
TARGET_DH=-1.0e-5
K=1.0e-10
SS=0.0
HEAD_BIAS=-3.332218778007957e-5
QPROBES=(-2e-10,-1e-10,0.0,1e-10,2e-10)
FIT_TOL=1.0e-16
FLUX_TOL=1.0e-15
MERIT_ABS_TOL=1.0e-18
MAX_OUTER=12
MAX_BACKTRACK=12


def require(cond:bool,msg:str)->None:
    if not cond:
        raise AssertionError(msg)


def load_prereg()->dict[str,object]:
    p=json.loads(PREREG.read_text())
    require(p["work_unit"]=="GC-FIXED-INTERFACE-G11","wrong G11 preregistration")
    require(p["status"]=="PREREGISTERED_BEFORE_EXECUTION","G11 preregistration not frozen")
    c=p["frozen_carrier"]
    require(float(c["duration_day"])==DURATION_DAY,"G11 duration drifted")
    require(float(c["predictor_qbot_cm_per_day"])==QBOT_CM_PER_DAY,"G11 qbot drifted")
    require(float(c["reference_head_m"])==HREF_EXPECTED,"G11 href drifted")
    require(float(c["predictor_u"])==U_EXPECTED,"G11 u drifted")
    require(float(c["start_dh_m"])==START_DH,"G11 start drifted")
    require(float(c["target_edge_dh_m"])==TARGET_DH,"G11 target edge drifted")
    g=p["groundwater_stress"]
    require(float(g["k_m_per_day"])==K,"G11 K drifted")
    require(float(g["ss_per_m"])==SS,"G11 ss drifted")
    require(float(g["initial_head_bias_m"])==HEAD_BIAS,"G11 head bias drifted")
    require(tuple(float(x) for x in g["q_probes_m_per_s"])==QPROBES,"G11 probes drifted")
    require(float(p["groundwater_oracle"]["max_fit_error_m_per_s"])==FIT_TOL,"G11 fit gate drifted")
    return p


def fit_groundwater(libmf6:Path,swaplib:Path,href:float,sy:float)->tuple[float,float,float]:
    points=[]
    for q in QPROBES:
        h,qgw,iters=solve_term(
            libmf6,swaplib,DURATION_DAY,href,K,SS,sy,HEAD_BIAS,
            0.0,-q*AREA_M2*DAY_TO_S,
        )
        require(abs(qgw-q)<=64.0*np.finfo(float).eps*max(1.0,abs(q)),
                f"G11 constant-flux probe drift requested={q} got={qgw}")
        row={"q_m_per_s":q,"head_m":h,"mf_iterations":iters}
        points.append((float(h),float(qgw)))
        print("FGC44_G11_GW_POINT="+json.dumps(row,sort_keys=True,separators=(",",":")))
    heads=np.asarray([x[0] for x in points],dtype=float)
    flux=np.asarray([x[1] for x in points],dtype=float)
    a,b=np.polyfit(heads,flux,1)
    err=float(np.max(np.abs(a*heads+b-flux)))
    a=float(a); b=float(b)
    require(math.isfinite(a) and a>0.0,"G11 groundwater slope invalid")
    require(err<=FIT_TOL,f"G11 groundwater fit error {err}")
    print("FGC44_G11_GW_FIT="+json.dumps({
        "a_per_s":a,"intercept":b,"max_fit_error_m_per_s":err,"point_count":len(points)
    },sort_keys=True,separators=(",",":")))
    return a,b,err


def residual_at(
    swap:Fgc44RealSwap,
    origin:tuple[int,float,int,float],
    head:float,
    a:float,
    b:float,
)->tuple[int,float|None,float|None]:
    status,q=trial_discard(swap,origin,head)
    if status!=0:
        return int(status),None,None
    res=float(q)-(a*head+b)
    return 0,float(q),res


def run_policy(
    policy:str,
    libmf6:Path,
    swaplib:Path,
    swap:Fgc44RealSwap,
    a:float,
    b:float,
    sy:float,
)->dict[str,object]:
    _,_,href,origin,_=initialize_case(swap,DURATION_DAY,QBOT_CM_PER_DAY)
    head=href
    contractions=0
    raw_inadmissible=0
    merit_increases=0
    trace=[]
    first_raw=None

    for outer in range(1,MAX_OUTER+1):
        status,q,res=residual_at(swap,origin,head,a,b)
        if status!=0 or q is None or res is None:
            return {"classification":"CURRENT_HEAD_INADMISSIBLE","outer":outer,"status":status}
        if abs(res)<=FLUX_TOL:
            return {
                "classification":"CONVERGED","outer":outer-1,
                "final_head_m":head,"final_dh_m":head-href,
                "final_residual_m_per_s":res,
                "contractions":contractions,"raw_inadmissible":raw_inadmissible,
                "merit_increases":merit_increases,"first_raw":first_raw,"trace":trace,
            }

        est=estimate_e3(swap,origin,head)
        if est["classification"]!="AVAILABLE":
            return {"classification":"TANGENT_UNAVAILABLE","outer":outer,"estimator":est}

        p=float(est["slope_per_s"])
        slope_day=p*AREA_M2*DAY_TO_S
        rhs=slope_day*head-q*AREA_M2*DAY_TO_S
        raw_head,_,mf_iters=solve_term(
            libmf6,swaplib,DURATION_DAY,href,K,SS,sy,HEAD_BIAS,slope_day,rhs
        )
        raw_status,_,raw_res=residual_at(swap,origin,raw_head,a,b)
        if raw_status!=0:
            raw_inadmissible+=1
        raw_bad=(
            raw_status!=0 or raw_res is None
            or abs(raw_res)>abs(res)+MERIT_ABS_TOL
        )
        if first_raw is None:
            first_raw={
                "outer":outer,"head_m":raw_head,"dh_m":raw_head-href,
                "status":raw_status,"residual_m_per_s":raw_res,
                "current_residual_m_per_s":res,"bad":raw_bad,
                "tangent_per_s":p,"tangent_mode":est["mode"],
                "tangent_d_m":est["selected_d_m"],
            }

        if policy=="P1_E3":
            if raw_status!=0 or raw_res is None:
                return {
                    "classification":"RAW_PROPOSAL_INADMISSIBLE","outer":outer,
                    "raw_head_m":raw_head,"raw_status":raw_status,
                    "contractions":contractions,"raw_inadmissible":raw_inadmissible,
                    "first_raw":first_raw,"trace":trace,
                }
            candidate=raw_head
            candidate_res=raw_res
            if abs(candidate_res)>abs(res)+MERIT_ABS_TOL:
                merit_increases+=1

        elif policy=="P4_E3":
            candidate=raw_head
            candidate_status=raw_status
            candidate_res=raw_res
            accepted=(
                candidate_status==0 and candidate_res is not None
                and abs(candidate_res)<=abs(res)+MERIT_ABS_TOL
            )
            local=0
            while not accepted and local<MAX_BACKTRACK:
                candidate=head+0.5*(candidate-head)
                local+=1
                candidate_status,_,candidate_res=residual_at(swap,origin,candidate,a,b)
                accepted=(
                    candidate_status==0 and candidate_res is not None
                    and abs(candidate_res)<=abs(res)+MERIT_ABS_TOL
                )
            contractions+=local
            if not accepted or candidate_res is None:
                return {
                    "classification":"SAFEGUARD_EXHAUSTED","outer":outer,
                    "raw_head_m":raw_head,"raw_status":raw_status,
                    "contractions":contractions,"raw_inadmissible":raw_inadmissible,
                    "first_raw":first_raw,"trace":trace,
                }
        else:
            raise ValueError(policy)

        trace.append({
            "outer":outer,
            "current_head_m":head,"current_dh_m":head-href,
            "current_residual_m_per_s":res,
            "raw_head_m":raw_head,"raw_dh_m":raw_head-href,
            "raw_status":raw_status,"raw_residual_m_per_s":raw_res,
            "accepted_head_m":candidate,"accepted_dh_m":candidate-href,
            "accepted_residual_m_per_s":candidate_res,
            "cumulative_contractions":contractions,
            "tangent_per_s":p,"tangent_mode":est["mode"],
            "tangent_d_m":est["selected_d_m"],
            "mf_iterations":mf_iters,
        })
        head=candidate

    status,_,res=residual_at(swap,origin,head,a,b)
    return {
        "classification":"OUTER_BUDGET_EXHAUSTED","outer":MAX_OUTER,
        "status":status,"final_head_m":head,"final_dh_m":head-href,
        "final_residual_m_per_s":res,"contractions":contractions,
        "raw_inadmissible":raw_inadmissible,"merit_increases":merit_increases,
        "first_raw":first_raw,"trace":trace,
    }


def main()->None:
    p=load_prereg()
    libmf6=Path(os.environ["LIBMF6"]).resolve()
    swaplib=Path(os.environ["FGC44_SWAP_LIB"]).resolve()
    require(libmf6.is_file(),"missing live MODFLOW library")
    require(swaplib.is_file(),"missing real SWAP bridge library")

    swap=Fgc44RealSwap(swaplib)
    _,_,href,origin,diag=initialize_case(swap,DURATION_DAY,QBOT_CM_PER_DAY)
    require(origin==(0,0.0,0,0.0),"G11 dirty SWAP origin")
    require(math.isclose(href,HREF_EXPECTED,rel_tol=0.0,abs_tol=1e-14),"G11 href authority drift")
    require(math.isclose(float(diag["u"]),U_EXPECTED,rel_tol=0.0,abs_tol=1e-14),"G11 u authority drift")
    require(math.isclose(float(diag["q_bot_predictor_cm_per_day"]),QBOT_CM_PER_DAY,rel_tol=0.0,abs_tol=1e-14),
            "G11 qbot authority drift")
    sy=0.5*float(diag["u"])

    a,b,fit_error=fit_groundwater(libmf6,swaplib,href,sy)

    target_head=href+TARGET_DH
    target_status,target_q,target_res=residual_at(swap,origin,target_head,a,b)
    require(target_status==0,"G11 frozen target edge no longer SWAP-admissible")
    require(target_res is not None,"G11 missing target-edge residual")
    calibration_limit=float(p["reference_contract"]["target_check"].split("<=")[1].split("m/s")[0].strip())
    require(abs(target_res)<=calibration_limit,
            f"G11 stress calibration missed without retuning: residual={target_res}")
    print("FGC44_G11_TARGET="+json.dumps({
        "head_m":target_head,"dh_m":TARGET_DH,"status":target_status,
        "q_swap_m_per_s":target_q,"q_groundwater_m_per_s":a*target_head+b,
        "residual_m_per_s":target_res,"calibration_limit_m_per_s":calibration_limit,
    },sort_keys=True,separators=(",",":")))

    start_status,start_q,start_res=residual_at(swap,origin,href,a,b)
    require(start_status==0 and start_res is not None,"G11 href start unavailable")

    results=[]
    for policy in ("P1_E3","P4_E3"):
        res=run_policy(policy,libmf6,swaplib,swap,a,b,sy)
        row={"policy":policy,**res}
        results.append(row)
        print("FGC44_G11_POLICY_JSON="+json.dumps(row,sort_keys=True,separators=(",",":")))

    p1=next(x for x in results if x["policy"]=="P1_E3")
    p4=next(x for x in results if x["policy"]=="P4_E3")
    require(p1.get("first_raw") is not None and p4.get("first_raw") is not None,
            "G11 missing first raw proposal")
    h1=float(p1["first_raw"]["head_m"]); h4=float(p4["first_raw"]["head_m"])
    require(abs(h1-h4)<=1e-12,"G11 P1/P4 first raw proposals differ")
    raw_dh=float(p4["first_raw"]["dh_m"])
    require(raw_dh<TARGET_DH,
            f"G11 first Newton proposal did not overshoot frozen negative edge: {raw_dh}")
    require(bool(p4["first_raw"]["bad"]),
            "G11 raw proposal did not trigger preregistered safeguard condition")
    require(int(p4.get("contractions",0))>=1,
            "G11 P4 did not exercise factor-1/2 safeguard")
    require(p4["classification"]=="CONVERGED",
            f"G11 P4 did not converge after safeguard activation: {p4}")
    require(abs(float(p4["final_residual_m_per_s"]))<=FLUX_TOL,
            "G11 P4 final residual above tolerance")
    require(swap.state()==origin,"G11 diagnostics mutated accepted SWAP/ledger authority")

    summary={
        "gw_fit_error_m_per_s":fit_error,
        "gw_slope_per_s":a,
        "target_edge_residual_m_per_s":target_res,
        "start_residual_m_per_s":start_res,
        "first_raw_dh_m":raw_dh,
        "first_raw_status":p4["first_raw"]["status"],
        "first_raw_residual_m_per_s":p4["first_raw"]["residual_m_per_s"],
        "first_raw_bad":p4["first_raw"]["bad"],
        "p1_classification":p1["classification"],
        "p4_classification":p4["classification"],
        "p4_contractions":p4["contractions"],
        "p4_final_dh_m":p4["final_dh_m"],
        "p4_final_residual_m_per_s":p4["final_residual_m_per_s"],
        "safeguard_recovery":"EXERCISED_AND_CONVERGED",
    }
    print("FGC44_G11_SUMMARY_JSON="+json.dumps(summary,sort_keys=True,separators=(",",":")))
    print("FGC44_G11_TRANSACTION_AUTHORITY=PASS")
    print("FGC44_G11_LIVE_SAFEGUARD_RECOVERY=PASS")
    print("GC_FIXED_INTERFACE_G11_EXECUTION=PASS")


if __name__=="__main__":
    main()
