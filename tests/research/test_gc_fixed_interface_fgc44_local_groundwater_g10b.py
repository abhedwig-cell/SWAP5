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
    AREA_M2, DAY_TO_S, initialize_case, reference_root, solve_term,
)
from test_gc_fixed_interface_fgc44_nonlinear_b4_g10 import (
    fixed_scan, DURATION_DAY, QBOT_CM_PER_DAY,
)
from test_gc_fixed_interface_fgc44_stencil_class_tangent_g09d import run_policy

PREREG=ROOT/"integration"/"research"/"GC_FIXED_INTERFACE_G10B_PREREGISTRATION.json"
DIRECT_ROOT_EXPECTED=-0.7149997332230622


def require(condition:bool,message:str)->None:
    if not condition:
        raise AssertionError(message)


def load_prereg()->dict[str,object]:
    p=json.loads(PREREG.read_text())
    require(p["work_unit"]=="GC-FIXED-INTERFACE-G10B","wrong G10B preregistration")
    require(p["status"]=="PREREGISTERED_BEFORE_EXECUTION","G10B preregistration not frozen")
    require(float(p["frozen_carrier"]["duration_day"])==DURATION_DAY,"G10B duration drifted")
    require(float(p["frozen_carrier"]["predictor_qbot_cm_per_day"])==QBOT_CM_PER_DAY,"G10B qbot drifted")
    return p


def main()->None:
    p=load_prereg()
    libmf6=Path(os.environ["LIBMF6"]).resolve()
    swaplib=Path(os.environ["FGC44_SWAP_LIB"]).resolve()
    require(libmf6.is_file(),"missing live MODFLOW library")
    require(swaplib.is_file(),"missing real SWAP bridge library")

    carrier=p["frozen_carrier"]
    gw=p["groundwater_regime"]
    swap=Fgc44RealSwap(swaplib)
    _,_,href,origin,diag=initialize_case(swap,DURATION_DAY,QBOT_CM_PER_DAY)
    require(origin==(0,0.0,0,0.0),"G10B dirty SWAP origin")
    require(math.isclose(href,float(carrier["reference_head_m"]),rel_tol=0.0,abs_tol=1e-14),"G10B href drift")
    require(math.isclose(float(diag["u"]),float(carrier["predictor_u"]),rel_tol=0.0,abs_tol=1e-14),"G10B u drift")
    require(math.isclose(float(diag["q_bot_predictor_cm_per_day"]),QBOT_CM_PER_DAY,rel_tol=0.0,abs_tol=1e-14),"G10B qbot drift")

    points=[]
    for q in [float(x) for x in p["local_response_contract"]["q_probes_m_per_s"]]:
        h,qgw,iters=solve_term(
            libmf6,swaplib,DURATION_DAY,href,
            float(gw["k_m_per_day"]),float(gw["ss_per_m"]),float(gw["sy"]),
            float(gw["initial_head_bias_m"]),0.0,-q*AREA_M2*DAY_TO_S,
        )
        require(abs(qgw-q)<=64*np.finfo(float).eps*max(1.0,abs(q)),"G10B constant-flux probe drift")
        row={"q_m_per_s":q,"head_m":h,"mf_iterations":iters}
        points.append(row)
        print("FGC44_G10B_GW_POINT="+json.dumps(row,sort_keys=True,separators=(",",":")))

    heads=np.asarray([float(x["head_m"]) for x in points],dtype=float)
    fluxes=np.asarray([float(x["q_m_per_s"]) for x in points],dtype=float)
    a,b=np.polyfit(heads,fluxes,1)
    fit_error=float(np.max(np.abs(a*heads+b-fluxes)))
    require(math.isfinite(a) and a>0.0,"G10B local GW slope invalid")
    require(fit_error<=float(p["local_response_contract"]["max_allowed_fit_error_m_per_s"]),
            f"G10B local GW fit error too large: {fit_error}")
    local_fit={"a_per_s":float(a),"intercept":float(b),"max_fit_error_m_per_s":fit_error,"point_count":len(points)}
    print("FGC44_G10B_LOCAL_FIT="+json.dumps(local_fit,sort_keys=True,separators=(",",":")))

    scan=fixed_scan(swap,origin,href)
    root=reference_root(swap,origin,scan,float(a),float(b))
    require(root is not None,"G10B local-affine root not bracketed on frozen G10 scan")
    root_diff=float(root)-DIRECT_ROOT_EXPECTED
    require(abs(root_diff)<=float(p["reference_root"]["max_root_head_difference_m"]),
            f"G10B local root differs from G10A direct root: {root_diff}")
    root_row={
        "local_affine_root_m":root,
        "g10a_direct_root_m":DIRECT_ROOT_EXPECTED,
        "head_difference_m":root_diff,
    }
    print("FGC44_G10B_ROOT="+json.dumps(root_row,sort_keys=True,separators=(",",":")))

    regime={
        "id":"GW_MIXED_LOCAL",
        "k_m_per_day":float(gw["k_m_per_day"]),
        "ss_per_m":float(gw["ss_per_m"]),
        "initial_head_bias_m":float(gw["initial_head_bias_m"]),
    }
    results=[]
    for start_dh in [float(x) for x in carrier["starts_m"]]:
        side="NEG" if start_dh<0 else "POS"
        for policy in ("P1_E3","P4_E3"):
            res=run_policy(
                policy,libmf6,swaplib,swap,DURATION_DAY,QBOT_CM_PER_DAY,
                regime,float(gw["sy"]),float(a),float(b),float(root),start_dh,
            )
            row={"start_side":side,"start_dh_m":start_dh,"policy":policy,**res}
            results.append(row)
            print("FGC44_G10B_POLICY_JSON="+json.dumps(row,sort_keys=True,separators=(",",":")))
            if policy=="P4_E3":
                require(res["classification"]=="CONVERGED",f"G10B P4 failed {side}: {res}")

    require(swap.state()==origin,"G10B diagnostics mutated accepted SWAP/ledger authority")
    p1=[x for x in results if x["policy"]=="P1_E3"]
    p4=[x for x in results if x["policy"]=="P4_E3"]
    summary={
        "local_fit_gate":"PASS",
        "local_fit_error_m_per_s":fit_error,
        "local_root_head_m":root,
        "root_difference_from_g10a_direct_m":root_diff,
        "p1_converged_count":sum(x["classification"]=="CONVERGED" for x in p1),
        "p1_case_count":len(p1),
        "p4_converged_count":sum(x["classification"]=="CONVERGED" for x in p4),
        "p4_case_count":len(p4),
        "p4_total_contractions":sum(int(x.get("contractions",0)) for x in p4),
        "p4_raw_inadmissible_total":sum(int(x.get("raw_inadmissible",0)) for x in p4),
        "safeguard_recovery_exercised":any(int(x.get("contractions",0))>0 for x in p4),
    }
    print("FGC44_G10B_SUMMARY_JSON="+json.dumps(summary,sort_keys=True,separators=(",",":")))
    print("FGC44_G10B_TRANSACTION_AUTHORITY=PASS")
    print("GC_FIXED_INTERFACE_G10B_EXECUTION=PASS")


if __name__=="__main__":
    main()
