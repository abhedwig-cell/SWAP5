from __future__ import annotations

import json
import math
import os
import sys
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/"tests"/"fgc"/"support"))
sys.path.insert(0,str(ROOT/"tests"/"research"))

from fgc44_real_swap_ctypes import Fgc44RealSwap
from test_gc_fixed_interface_fgc44_safeguarded_newton_g08 import AREA_M2,DAY_TO_S,initialize_case,solve_term

PREREG=ROOT/"integration"/"research"/"GC_FIXED_INTERFACE_G19_PREREGISTRATION.json"
G11=ROOT/"integration"/"research"/"GC_FIXED_INTERFACE_G11_RESULT.json"
MERIT_ABS_TOL=1.0e-18
HEAD_TOL=1.0e-12


def require(cond:bool,msg:str)->None:
    if not cond:
        raise AssertionError(msg)


def fit_groundwater(libmf6:Path,swaplib:Path,p:dict[str,object],href:float,sy:float)->tuple[float,float,float,list[dict[str,object]]]:
    rows=[]
    for q in [float(x) for x in p["frozen_g11"]["groundwater_q_probes_m_per_s"]]:
        h,qgw,it=solve_term(
            libmf6,swaplib,
            float(p["frozen_g11"]["duration_day"]),href,
            float(p["frozen_g11"]["groundwater_k_m_per_day"]),
            float(p["frozen_g11"]["groundwater_ss_per_m"]),sy,
            float(p["frozen_g11"]["groundwater_initial_head_bias_m"]),
            0.0,-q*AREA_M2*DAY_TO_S,
        )
        tol=64.0*sys.float_info.epsilon*max(1.0,abs(q))
        require(abs(qgw-q)<=tol,f"G19 constant-flux probe mismatch {qgw} versus {q}")
        rows.append({"q_m_per_s":q,"head_m":float(h),"mf_iterations":int(it)})
    xm=sum(float(x["head_m"]) for x in rows)/len(rows)
    ym=sum(float(x["q_m_per_s"]) for x in rows)/len(rows)
    denom=sum((float(x["head_m"])-xm)**2 for x in rows)
    require(denom>0.0,"G19 degenerate groundwater fit")
    a=sum((float(x["head_m"])-xm)*(float(x["q_m_per_s"])-ym) for x in rows)/denom
    b=ym-a*xm
    err=max(abs(a*float(x["head_m"])+b-float(x["q_m_per_s"])) for x in rows)
    require(math.isfinite(a) and a>0.0,"G19 groundwater slope invalid")
    require(err<=float(p["frozen_g11"]["groundwater_fit_error_gate_m_per_s"]),f"G19 groundwater fit error {err}")
    return float(a),float(b),float(err),rows


def main()->None:
    prereg=json.loads(PREREG.read_text())
    require(prereg["work_unit"]=="GC-FIXED-INTERFACE-G19","wrong G19 preregistration")
    require(prereg["status"]=="PREREGISTERED_BEFORE_EXECUTION","G19 preregistration not frozen")
    g11=json.loads(G11.read_text())
    frozen=prereg["frozen_g11"]

    p4=next(x for x in g11["policy_results"] if x["policy"]=="P4_E3")
    first=p4["trace"][0]
    require(float(frozen["current_head_m"])==float(first["current_head_m"]),"G19 current-head authority drift")
    require(float(frozen["raw_head_m"])==float(first["raw_head_m"]),"G19 raw-head authority drift")
    require(float(frozen["first_accepted_head_m"])==float(first["accepted_head_m"]),"G19 accepted-head authority drift")
    require(float(frozen["e3_tangent_per_s"])==float(first["tangent_per_s"]),"G19 tangent authority drift")
    require(int(frozen["raw_status"])==int(first["raw_status"])==6,"G19 raw-status authority drift")
    require(int(frozen["contraction_count"])==int(first["cumulative_contractions"])==2,"G19 contraction authority drift")
    require(float(frozen["current_residual_m_per_s"])==float(first["current_residual_m_per_s"]),"G19 current-residual authority drift")

    libmf6=Path(os.environ["LIBMF6"]).resolve()
    swaplib=Path(os.environ["FGC44_SWAP_LIB"]).resolve()
    require(libmf6.is_file(),"missing live MODFLOW library")
    require(swaplib.is_file(),"missing FGC44 SWAP library")

    swap=Fgc44RealSwap(swaplib)
    _,_,href,origin,diag=initialize_case(
        swap,float(frozen["duration_day"]),float(frozen["predictor_qbot_cm_per_day"])
    )
    h0=float(frozen["current_head_m"])
    require(abs(href-h0)<=1e-14,"G19 reference head drift")
    sy=0.5*float(diag["u"])
    a,b,fit_err,gw_rows=fit_groundwater(libmf6,swaplib,prereg,href,sy)
    print("FGC44_G19_GW_FIT_JSON="+json.dumps({
        "a_per_s":a,"intercept":b,"max_fit_error_m_per_s":fit_err,"points":gw_rows
    },sort_keys=True,separators=(",",":")))

    swap.g16_begin_session()
    require(swap.g16_counts()==(0,0,0,0),"G19 dirty G16 session")
    center=swap.g16_observe_head(h0)
    require(int(center["participant_status"])==0 and bool(center["q_available"]),"G19 center observation unavailable")
    require(not swap.g15_has_live_candidate(),"G19 center observation leaked candidate")
    require(swap.state()==origin,"G19 center observation changed authority")

    qs0=float(center["q_swap_m_per_s"])
    g0=a*h0+b
    r0=qs0-g0
    p=float(frozen["e3_tangent_per_s"])
    raw_ref=float(frozen["raw_head_m"])
    current_ref_residual=float(frozen["current_residual_m_per_s"])
    require(abs(r0-current_ref_residual)<=1e-15,
            f"G19 measured current residual drift {r0} versus {current_ref_residual}")

    lambdas=(1.0,0.5,0.25)
    rows=[]
    for lam in lambdas:
        qref=g0+lam*r0
        hcof=p*AREA_M2*DAY_TO_S
        rhs=hcof*h0-qref*AREA_M2*DAY_TO_S
        analytic=(b-qref+p*h0)/(p-a)
        expected=h0+lam*(raw_ref-h0)
        require(abs(analytic-expected)<=HEAD_TOL,
                f"G19 analytical affine identity failed lambda={lam}: {analytic} versus {expected}")
        head,qgw,mf_iters=solve_term(
            libmf6,swaplib,
            float(frozen["duration_day"]),href,
            float(frozen["groundwater_k_m_per_day"]),
            float(frozen["groundwater_ss_per_m"]),sy,
            float(frozen["groundwater_initial_head_bias_m"]),
            hcof,rhs,
        )
        require(abs(head-expected)<=HEAD_TOL,
                f"G19 live response-space head mismatch lambda={lam}: {head} versus {expected}")
        obs=swap.g16_observe_head(float(head))
        require(not swap.g15_has_live_candidate(),f"G19 lambda={lam} leaked candidate")
        require(swap.state()==origin,f"G19 lambda={lam} changed accepted/ledger authority")
        require(not swap.swap_preflight() and not swap.ledger_preflight(),
                f"G19 lambda={lam} acquired publication authority")
        status=int(obs["participant_status"])
        residual=None
        accepted=False
        if status==0:
            require(bool(obs["q_available"]),f"G19 lambda={lam} status0 without q")
            residual=float(obs["q_swap_m_per_s"])-(a*float(head)+b)
            accepted=abs(residual)<=abs(r0)+MERIT_ABS_TOL
        else:
            require(not bool(obs["q_available"]),f"G19 lambda={lam} failed status retained q authority")
        row={
            "lambda":lam,"q_reference_m_per_s":qref,
            "analytic_head_m":analytic,"expected_head_m":expected,"live_head_m":float(head),
            "live_minus_expected_m":float(head)-expected,
            "q_groundwater_term_m_per_s":float(qgw),"mf_iterations":int(mf_iters),
            "participant_status":status,"coupled_residual_m_per_s":residual,
            "p4_acceptance_rule":bool(accepted),
        }
        rows.append(row)
        print("FGC44_G19_LAMBDA_JSON="+json.dumps(row,sort_keys=True,separators=(",",":")))

    by={float(x["lambda"]):x for x in rows}
    require(int(by[1.0]["participant_status"])==int(frozen["raw_status"])==6,"G19 lambda1 raw status mismatch")
    require(abs(float(by[1.0]["live_head_m"])-raw_ref)<=HEAD_TOL,"G19 lambda1 raw head mismatch")
    require(not bool(by[0.5]["p4_acceptance_rule"]),"G19 lambda1/2 unexpectedly passes frozen P4 acceptance")
    require(abs(float(by[0.25]["live_head_m"])-float(frozen["first_accepted_head_m"]))<=HEAD_TOL,
            "G19 lambda1/4 does not reproduce first accepted P4 head")
    require(int(by[0.25]["participant_status"])==0,"G19 lambda1/4 participant status is not 0")
    require(bool(by[0.25]["p4_acceptance_rule"]),"G19 lambda1/4 fails frozen P4 acceptance")
    require(abs(float(by[0.25]["coupled_residual_m_per_s"]))<abs(r0),
            "G19 lambda1/4 does not reduce coupled residual")

    counts=swap.g16_counts()
    require(counts[0]==counts[1]+counts[2],"G19 G16 accounting identity failed")
    require(counts[1]==counts[3],"G19 G16 physical-trial/cache identity failed")
    swap.g16_end_session()
    require(swap.state()==origin and not swap.g15_has_live_candidate(),"G19 session close changed authority")
    require(not swap.swap_preflight() and not swap.ledger_preflight(),"G19 session close left publication authority")

    summary={
        "groundwater_fit_error_m_per_s":fit_err,
        "physical_tangent_per_s":p,
        "center_residual_m_per_s":r0,
        "lambda_count":len(rows),
        "lambda_1_raw_reproduction":"PASS",
        "lambda_half_rejected":"PASS",
        "lambda_quarter_accepted":"PASS",
        "lambda_quarter_head_error_m":float(by[0.25]["live_head_m"])-float(frozen["first_accepted_head_m"]),
        "g16_logical_requests":counts[0],"g16_participant_trials":counts[1],
        "g16_cache_hits":counts[2],"g16_unique_heads":counts[3],
        "diagnostic_non_authority":"PASS",
        "continuous_prepared_solve_claim":"NOT_MADE",
    }
    print("FGC44_G19_SUMMARY_JSON="+json.dumps(summary,sort_keys=True,separators=(",",":")))
    print("GC_FIXED_INTERFACE_G19_AFFINE_IDENTITY=PASS")
    print("GC_FIXED_INTERFACE_G19_LIVE_FRESH_SOLVE_BRIDGE=PASS")
    print("GC_FIXED_INTERFACE_G19_DIAGNOSTIC_NON_AUTHORITY=PASS")
    print("GC_FIXED_INTERFACE_G19_EXECUTION=PASS")


if __name__=="__main__":
    main()
