from __future__ import annotations

import json
import math
import os
import sys
from pathlib import Path

import numpy as np

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/"tests"/"research"))
sys.path.insert(0,str(ROOT/"tests"/"research"/"support"))

from gc_map09_e6_ctypes import Map09ActiveDrainageSwap
from test_gc_fixed_interface_map09_active_drainage_g12 import (
    DAY_TO_S,
    HREF_EXPECTED,
    QREF_EXPECTED,
    U_EXPECTED,
    initialize_checked,
    estimate_e3_map,
    solve_term_map09,
)

PREREG=ROOT/"integration"/"research"/"GC_FIXED_INTERFACE_G12A_PREREGISTRATION.json"
G12_PREREG=ROOT/"integration"/"research"/"GC_FIXED_INTERFACE_G12_PREREGISTRATION.json"

LOCAL_OFFSETS=(-2e-10,-1e-10,-5e-11,0.0,5e-11,1e-10,2e-10)
BISECT_ITERS=20
FIT_TOL=1e-16


def require(cond:bool,msg:str)->None:
    if not cond:
        raise AssertionError(msg)


def load_authority()->tuple[dict[str,object],list[dict[str,object]]]:
    p=json.loads(PREREG.read_text())
    require(p["work_unit"]=="GC-FIXED-INTERFACE-G12A","wrong G12A preregistration")
    require(p["status"]=="PREREGISTERED_BEFORE_EXECUTION","G12A preregistration not frozen")
    require(tuple(float(x) for x in p["local_probe_offsets_m_per_s"])==LOCAL_OFFSETS,
            "G12A local probe offsets drifted")
    require(int(p["direct_href_inversion"]["fixed_bisection_iterations"])==BISECT_ITERS,
            "G12A bisection count drifted")
    require(float(p["local_fit"]["max_fit_error_m_per_s"])==FIT_TOL,
            "G12A fit tolerance drifted")
    g12=json.loads(G12_PREREG.read_text())
    return p,[dict(x) for x in g12["groundwater_regimes"]]


def resolve_sy(regime:dict[str,object],p_href:float)->float:
    rule=str(regime["sy_rule"])
    duration_s=0.01*DAY_TO_S
    if rule=="0.5*abs(p_href)*duration_seconds":
        return 0.5*abs(p_href)*duration_s
    if rule=="2.0*abs(p_href)*duration_seconds":
        return 2.0*abs(p_href)*duration_s
    if rule=="0.15":
        return 0.15
    raise AssertionError(f"unknown G12A sy rule {rule}")


def solve_q(
    libmf6:Path,
    swaplib:Path,
    href:float,
    regime:dict[str,object],
    sy:float,
    bias:float,
    q:float,
)->tuple[float,int]:
    h,qgot,iters=solve_term_map09(
        libmf6,swaplib,href,
        float(regime["k_m_per_day"]),float(regime["ss_per_m"]),sy,bias,
        0.0,-q*DAY_TO_S,
    )
    # AREA_M2 is 1 in the reused fixture, so -q*DAY_TO_S is the imposed RHS.
    require(
        abs(qgot-q)<=64*np.finfo(float).eps*max(1.0,abs(q)),
        f"G12A constant-flux probe drift requested={q} got={qgot}",
    )
    return float(h),int(iters)


def one_shot_bias(
    libmf6:Path,
    swaplib:Path,
    href:float,
    qref:float,
    regime:dict[str,object],
    sy:float,
)->tuple[float,float]:
    h0,_=solve_q(libmf6,swaplib,href,regime,sy,0.0,qref)
    return href-h0,h0


def local_fit(
    libmf6:Path,
    swaplib:Path,
    href:float,
    qref:float,
    regime:dict[str,object],
    sy:float,
    bias:float,
)->dict[str,object]:
    points=[]
    for dq in LOCAL_OFFSETS:
        q=qref+dq
        h,iters=solve_q(libmf6,swaplib,href,regime,sy,bias,q)
        row={"dq_m_per_s":dq,"q_m_per_s":q,"head_m":h,"mf_iterations":iters}
        points.append(row)
        print("GC_G12A_LOCAL_POINT="+json.dumps(
            {"regime_id":regime["id"],**row},sort_keys=True,separators=(",",":")
        ))
    x=np.asarray([float(x["head_m"])-href for x in points],dtype=float)
    y=np.asarray([float(x["q_m_per_s"]) for x in points],dtype=float)
    a,q_at_href=np.polyfit(x,y,1)
    a=float(a); q_at_href=float(q_at_href)
    fit_error=float(np.max(np.abs(a*x+q_at_href-y)))
    require(math.isfinite(a) and a>0.0,f"G12A nonpositive/nonfinite slope {a}")
    require(fit_error<=FIT_TOL,f"G12A local fit error {fit_error}")
    return {
        "a_per_s":a,
        "q_at_href_m_per_s":q_at_href,
        "fit_error_m_per_s":fit_error,
        "qref_minus_q_at_href_m_per_s":qref-q_at_href,
        "equivalent_head_miss_m":(qref-q_at_href)/a,
        "points":points,
    }


def direct_href_inversion(
    libmf6:Path,
    swaplib:Path,
    href:float,
    qref:float,
    regime:dict[str,object],
    sy:float,
    bias:float,
)->dict[str,object]:
    qlo=qref-2e-10
    qhi=qref+2e-10
    hlo,itlo=solve_q(libmf6,swaplib,href,regime,sy,bias,qlo)
    hhi,ithi=solve_q(libmf6,swaplib,href,regime,sy,bias,qhi)
    elo=hlo-href
    ehi=hhi-href
    require(elo==0.0 or ehi==0.0 or elo*ehi<0.0,
            f"G12A direct-q bracket misses href {regime['id']} elo={elo} ehi={ehi}")
    trace=[{"iteration":0,"q_lo":qlo,"h_lo":hlo,"q_hi":qhi,"h_hi":hhi,
            "e_lo_m":elo,"e_hi_m":ehi,"lo_mf_iterations":itlo,"hi_mf_iterations":ithi}]
    for i in range(1,BISECT_ITERS+1):
        qmid=0.5*(qlo+qhi)
        hmid,iters=solve_q(libmf6,swaplib,href,regime,sy,bias,qmid)
        emid=hmid-href
        trace.append({"iteration":i,"q_mid":qmid,"h_mid":hmid,"e_mid_m":emid,
                      "mf_iterations":iters})
        if elo==0.0:
            qhi=qlo; ehi=elo
        elif elo*emid<=0.0:
            qhi=qmid; ehi=emid
        else:
            qlo=qmid; elo=emid
    q_direct=0.5*(qlo+qhi)
    h_direct,iters=solve_q(libmf6,swaplib,href,regime,sy,bias,q_direct)
    return {
        "q_direct_href_m_per_s":q_direct,
        "head_at_q_direct_m":h_direct,
        "head_error_m":h_direct-href,
        "qref_minus_q_direct_href_m_per_s":qref-q_direct,
        "final_bracket_width_m_per_s":qhi-qlo,
        "final_mf_iterations":iters,
        "trace":trace,
    }


def main()->None:
    p,regimes=load_authority()
    libmf6=Path(os.environ["LIBMF6"]).resolve()
    swaplib=Path(os.environ["MAP09_SWAP_LIB"]).resolve()
    require(libmf6.is_file(),"missing G12A MODFLOW library")
    require(swaplib.is_file(),"missing G12A MAP09 SWAP library")

    swap=Map09ActiveDrainageSwap(swaplib)
    href,pred,origin=initialize_checked(swap)
    require(math.isclose(href,HREF_EXPECTED,rel_tol=0.0,abs_tol=1e-14),"G12A href drift")
    require(math.isclose(float(pred["u"]),U_EXPECTED,rel_tol=0.0,abs_tol=1e-14),"G12A u drift")
    status,qref=swap.try_trial(href)
    require(status==0,"G12A href participant failed")
    swap.discard()
    require(math.isclose(qref,QREF_EXPECTED,rel_tol=0.0,abs_tol=1e-18),"G12A qref drift")
    require(swap.state()==origin,"G12A href trial mutated authority")

    e3=estimate_e3_map(swap,origin,href)
    require(e3["classification"]=="AVAILABLE","G12A inherited E3 href unavailable")
    p_href=float(e3["slope_per_s"])

    rows=[]
    for regime in regimes:
        sy=resolve_sy(regime,p_href)
        bias,h0=one_shot_bias(libmf6,swaplib,href,qref,regime,sy)
        h_at_qref,iters=solve_q(libmf6,swaplib,href,regime,sy,bias,qref)
        fit=local_fit(libmf6,swaplib,href,qref,regime,sy,bias)
        direct=direct_href_inversion(libmf6,swaplib,href,qref,regime,sy,bias)
        row={
            "regime_id":regime["id"],
            "k_m_per_day":float(regime["k_m_per_day"]),
            "ss_per_m":float(regime["ss_per_m"]),
            "sy":sy,
            "zero_bias_qref_head_m":h0,
            "one_shot_bias_m":bias,
            "head_at_qref_after_bias_m":h_at_qref,
            "head_error_at_qref_after_bias_m":h_at_qref-href,
            "qref_recheck_mf_iterations":iters,
            "local_fit":fit,
            "direct_href_inversion":direct,
            "fit_minus_direct_q_href_m_per_s":
                float(fit["q_at_href_m_per_s"])-float(direct["q_direct_href_m_per_s"]),
        }
        rows.append(row)
        print("GC_G12A_REGIME_JSON="+json.dumps(row,sort_keys=True,separators=(",",":")))

    require(len(rows)==3,"G12A regime matrix incomplete")
    require(swap.state()==origin,"G12A diagnostic mutated accepted MAP09 authority")

    summary={
        "regime_count":len(rows),
        "all_fit_errors_le_1e_16":all(float(x["local_fit"]["fit_error_m_per_s"])<=FIT_TOL for x in rows),
        "max_abs_fit_minus_direct_q_href_m_per_s":max(
            abs(float(x["fit_minus_direct_q_href_m_per_s"])) for x in rows
        ),
        "regimes":[{
            "id":x["regime_id"],
            "one_shot_bias_m":x["one_shot_bias_m"],
            "head_error_at_qref_after_bias_m":x["head_error_at_qref_after_bias_m"],
            "qref_minus_q_at_href_m_per_s":x["local_fit"]["qref_minus_q_at_href_m_per_s"],
            "qref_minus_q_direct_href_m_per_s":x["direct_href_inversion"]["qref_minus_q_direct_href_m_per_s"],
            "fit_minus_direct_q_href_m_per_s":x["fit_minus_direct_q_href_m_per_s"],
        } for x in rows],
    }
    print("GC_G12A_SUMMARY_JSON="+json.dumps(summary,sort_keys=True,separators=(",",":")))
    print("GC_G12A_MAP09_AUTHORITY=PASS")
    print("GC_G12A_LOCAL_GROUNDWATER_FITS=PASS")
    print("GC_G12A_DIRECT_HREF_INVERSIONS=PASS")
    print("GC_G12A_TRANSACTION_AUTHORITY=PASS")
    print("GC_FIXED_INTERFACE_G12A_DIAGNOSTIC=PASS")


if __name__=="__main__":
    main()
