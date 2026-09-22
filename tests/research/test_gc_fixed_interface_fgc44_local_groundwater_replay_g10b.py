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
    AREA_M2,DAY_TO_S,initialize_case,solve_term,reference_root
)
from test_gc_fixed_interface_fgc44_stencil_class_tangent_g09d import (
    estimate_e3,run_policy
)
from test_gc_fixed_interface_fgc44_nonlinear_b4_g10 import fixed_scan

PREREG=ROOT/"integration"/"research"/"GC_FIXED_INTERFACE_G10B_PREREGISTRATION.json"

DURATION_DAY=1.0e-2
QBOT_CM_PER_DAY=1.0e-6
HREF_EXPECTED=-0.7149999311459918
U_EXPECTED=0.00119027208545508
STARTS=(("NEG",-1.0e-5),("POS",1.0e-5))
K_M_PER_DAY=1.0
SS_PER_M=0.02
SY=0.15
HEAD_BIAS_M=0.0
LOCAL_PROBES=(-2.0e-9,-1.0e-9,-5.0e-10,-2.0e-10,-1.0e-10,-5.0e-11,0.0,
              5.0e-11,1.0e-10,2.0e-10,5.0e-10,1.0e-9,2.0e-9)
DIRECT_ROOT_HEAD=-0.7149997332230622
FIT_ERROR_MAX=1.0e-16
ROOT_HEAD_TOL=5.0e-10


def require(condition:bool,message:str)->None:
    if not condition:
        raise AssertionError(message)


def load_prereg()->dict[str,object]:
    p=json.loads(PREREG.read_text())
    require(p["work_unit"]=="GC-FIXED-INTERFACE-G10B","wrong G10B preregistration")
    require(p["status"]=="PREREGISTERED_BEFORE_EXECUTION","G10B preregistration not frozen")
    c=p["frozen_carrier"]
    require(float(c["duration_day"])==DURATION_DAY,"G10B duration drifted")
    require(float(c["predictor_qbot_cm_per_day"])==QBOT_CM_PER_DAY,"G10B qbot drifted")
    require(float(c["reference_head_m"])==HREF_EXPECTED,"G10B href authority drifted")
    require(float(c["predictor_u"])==U_EXPECTED,"G10B u authority drifted")
    require(tuple(float(x) for x in c["starts_m"])==tuple(x[1] for x in STARTS),"G10B starts drifted")
    g=p["groundwater_regime"]
    require(float(g["k_m_per_day"])==K_M_PER_DAY,"G10B K drifted")
    require(float(g["ss_per_m"])==SS_PER_M,"G10B ss drifted")
    require(float(g["sy"])==SY,"G10B sy drifted")
    require(float(g["initial_head_bias_m"])==HEAD_BIAS_M,"G10B head bias drifted")
    require(tuple(float(x) for x in p["local_response_contract"]["q_probes_m_per_s"])==LOCAL_PROBES,
            "G10B local probe ladder drifted")
    require(float(p["local_response_contract"]["max_allowed_fit_error_m_per_s"])==FIT_ERROR_MAX,
            "G10B fit gate drifted")
    require(float(p["reference_root"]["max_root_head_difference_m"])==ROOT_HEAD_TOL,
            "G10B root gate drifted")
    return p


def main()->None:
    prereg=load_prereg()
    libmf6=Path(os.environ["LIBMF6"]).resolve()
    swaplib=Path(os.environ["FGC44_SWAP_LIB"]).resolve()
    require(libmf6.is_file(),"missing live MODFLOW library")
    require(swaplib.is_file(),"missing real SWAP bridge library")

    swap=Fgc44RealSwap(swaplib)
    _,_,href,origin,diag=initialize_case(swap,DURATION_DAY,QBOT_CM_PER_DAY)
    require(origin==(0,0.0,0,0.0),"G10B dirty SWAP origin")
    require(math.isclose(href,HREF_EXPECTED,rel_tol=0.0,abs_tol=1.0e-14),
            f"G10B B4 href mismatch: {href}")
    require(math.isclose(float(diag["u"]),U_EXPECTED,rel_tol=0.0,abs_tol=1.0e-14),
            f"G10B B4 u mismatch: {diag['u']}")
    require(math.isclose(float(diag["q_bot_predictor_cm_per_day"]),QBOT_CM_PER_DAY,
                         rel_tol=0.0,abs_tol=1.0e-14),
            "G10B B4 qbot mismatch")
    href_e3=estimate_e3(swap,origin,href)
    require(href_e3["classification"]=="AVAILABLE","G10B B4 href E3 unavailable")
    print("FGC44_G10B_CARRIER_BINDING="+json.dumps({
        "reference_head_m":href,
        "predictor_u":float(diag["u"]),
        "qbot_cm_per_day":float(diag["q_bot_predictor_cm_per_day"]),
        "href_e3_slope_per_s":float(href_e3["slope_per_s"]),
        "status":"PASS",
    },sort_keys=True,separators=(",",":")))

    points=[]
    for q in LOCAL_PROBES:
        h,qgw,iters=solve_term(
            libmf6,swaplib,DURATION_DAY,href,
            K_M_PER_DAY,SS_PER_M,SY,HEAD_BIAS_M,
            0.0,-q*AREA_M2*DAY_TO_S,
        )
        require(abs(qgw-q)<=64.0*np.finfo(float).eps*max(1.0,abs(q)),
                f"G10B constant-flux probe drift: requested={q} got={qgw}")
        points.append((float(h),float(qgw)))
        print("FGC44_G10B_GW_POINT="+json.dumps({
            "q_m_per_s":q,"head_m":h,"mf_iterations":iters
        },sort_keys=True,separators=(",",":")))

    heads=np.asarray([x[0] for x in points],dtype=float)
    fluxes=np.asarray([x[1] for x in points],dtype=float)
    a,b=np.polyfit(heads,fluxes,1)
    fit_error=float(np.max(np.abs(a*heads+b-fluxes)))
    a=float(a); b=float(b)
    require(math.isfinite(a) and a>0.0,"G10B local groundwater slope invalid")
    require(fit_error<=FIT_ERROR_MAX,f"G10B local groundwater fit too coarse: {fit_error}")
    print("FGC44_G10B_GW_FIT="+json.dumps({
        "a_per_s":a,"intercept":b,"max_fit_error_m_per_s":fit_error,
        "point_count":len(points)
    },sort_keys=True,separators=(",",":")))

    scan=fixed_scan(swap,origin,href)
    root=reference_root(swap,origin,scan,a,b)
    require(root is not None,"G10B local-affine coupled root unavailable")
    root=float(root)
    root_delta=root-DIRECT_ROOT_HEAD
    require(abs(root_delta)<=ROOT_HEAD_TOL,
            f"G10B local-affine root differs from G10A direct root: {root_delta}")
    print("FGC44_G10B_REFERENCE_ROOT="+json.dumps({
        "local_affine_root_m":root,
        "g10a_direct_root_m":DIRECT_ROOT_HEAD,
        "head_difference_m":root_delta
    },sort_keys=True,separators=(",",":")))

    regime={
        "id":"GW_MIXED",
        "k_m_per_day":K_M_PER_DAY,
        "ss_per_m":SS_PER_M,
        "initial_head_bias_m":HEAD_BIAS_M,
    }
    policy_rows=[]
    for side,start_dh in STARTS:
        for policy in ("P1_E3","P4_E3"):
            res=run_policy(
                policy,libmf6,swaplib,swap,DURATION_DAY,QBOT_CM_PER_DAY,
                regime,SY,a,b,root,start_dh
            )
            row={
                "regime_id":"GW_MIXED_LOCAL",
                "start_side":side,
                "start_dh_m":start_dh,
                "policy":policy,
                "a_per_s":a,
                "gw_intercept":b,
                "gw_fit_error_m_per_s":fit_error,
                "reference_root_m":root,
                **res,
            }
            policy_rows.append(row)
            print("FGC44_G10B_POLICY_JSON="+json.dumps(row,sort_keys=True,separators=(",",":")))
            if policy=="P4_E3":
                require(res["classification"]=="CONVERGED",f"G10B P4 failed {side}: {res}")

    require(swap.state()==origin,"G10B diagnostics mutated accepted SWAP/ledger authority")
    p1=[x for x in policy_rows if x["policy"]=="P1_E3"]
    p4=[x for x in policy_rows if x["policy"]=="P4_E3"]
    require(len(p1)==2 and len(p4)==2,"G10B policy replay incomplete")

    summary={
        "local_fit_error_m_per_s":fit_error,
        "local_fit_slope_per_s":a,
        "reference_root_m":root,
        "root_difference_from_g10a_direct_m":root_delta,
        "policy_case_count":len(policy_rows),
        "p1_converged_count":sum(x["classification"]=="CONVERGED" for x in p1),
        "p4_converged_count":sum(x["classification"]=="CONVERGED" for x in p4),
        "p4_total_contractions":sum(int(x.get("contractions",0)) for x in p4),
        "p4_raw_inadmissible_total":sum(int(x.get("raw_inadmissible",0)) for x in p4),
        "p1_merit_increase_total":sum(int(x.get("merit_increases",0)) for x in p1),
    }
    print("FGC44_G10B_SUMMARY_JSON="+json.dumps(summary,sort_keys=True,separators=(",",":")))
    print("FGC44_G10B_TRANSACTION_AUTHORITY=PASS")
    print("FGC44_G10B_LOCAL_GROUNDWATER_ORACLE=PASS")
    print("GC_FIXED_INTERFACE_G10B_EXECUTION=PASS")


if __name__=="__main__":
    main()
