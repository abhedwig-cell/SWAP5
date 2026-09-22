from __future__ import annotations

import json
import math
import os
import sys
import tempfile
from pathlib import Path

import numpy as np
from xmipy import XmiWrapper

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/"tests"/"research"))
sys.path.insert(0,str(ROOT/"tests"/"fgc"))
sys.path.insert(0,str(ROOT/"tests"/"fgc"/"support"))
sys.path.insert(0,str(ROOT/"src"/"adapter"))

from fgc44_real_swap_ctypes import Fgc44RealSwap
from modflow6_fgc34_ctypes_publisher import Fgc34CtypesPublisher
from modflow6_prepared_solve_session import Modflow6PreparedSolveSession, PreparedSolveStatus
from test_fgc44_real_swap_modflow_end_to_end import AREA_M2,DAY_TO_S,Binding,CountingKernel,Term
from test_gc_fixed_interface_fgc44_safeguarded_newton_g08 import build_model, initialize_case, solve_term
from test_gc_fixed_interface_g17_safeguarded_orchestration import DiagnosticSession

PREREG=ROOT/"integration"/"research"/"GC_FIXED_INTERFACE_G21A_PREREGISTRATION.json"
G21=ROOT/"integration"/"research"/"GC_FIXED_INTERFACE_G21_RESULT.json"
G17=ROOT/"integration"/"research"/"GC_FIXED_INTERFACE_G17_RESULT.json"


def require(cond:bool,msg:str)->None:
    if not cond:
        raise AssertionError(msg)


class LifecycleCountingKernel(CountingKernel):
    def __init__(self,kernel:XmiWrapper)->None:
        super().__init__(kernel)
        self.prepare_time_step_calls=0
    def prepare_time_step(self,dt:float)->None:
        self.prepare_time_step_calls+=1
        self.kernel.prepare_time_step(dt)


def fresh_response(libmf6:Path,swaplib:Path,duration:float,href:float,k:float,ss:float,sy:float,bias:float,
                   anchor:float,qref:float,p:float)->dict[str,float|int]:
    hcof=p*AREA_M2*DAY_TO_S
    rhs=hcof*anchor-qref*AREA_M2*DAY_TO_S
    head,qgw,iters=solve_term(libmf6,swaplib,duration,href,k,ss,sy,bias,hcof,rhs)
    return {"head_m":float(head),"qgw_term_m_per_s":float(qgw),"iterations":int(iters),
            "hcof_m2_per_day":float(hcof),"rhs_m3_per_day":float(rhs)}


def settle(session:Modflow6PreparedSolveSession,binding:list[Binding],xold:np.ndarray,
           anchor:float,qref:float,p:float)->tuple[float,int]:
    hcof=p*AREA_M2*DAY_TO_S
    rhs=hcof*anchor-qref*AREA_M2*DAY_TO_S
    start=session.iteration_count
    converged=None
    while session.iteration_count<session.max_solve_iterations:
        status,it=session.publish_and_solve_iteration(binding,[Term(7001,hcof,rhs)])
        require(status==PreparedSolveStatus.OK,session.last_error)
        require(it is not None,"G21A missing MODFLOW iteration")
        require(np.array_equal(it.accepted_head_old_m,xold),"G21A XOLD drift")
        require(not session.invalid and session.solve_open and not session.finalized,
                "G21A continuous prepared-solve lifecycle invalid")
        if it.modflow_converged:
            converged=it
            break
    require(converged is not None,"G21A response failed to settle")
    return float(converged.head_m[1]),session.iteration_count-start


def main()->None:
    prereg=json.loads(PREREG.read_text())
    g21=json.loads(G21.read_text())
    g17=json.loads(G17.read_text())
    require(prereg["work_unit"]=="GC-FIXED-INTERFACE-G21A","wrong G21A preregistration")
    require(prereg["status"]=="PREREGISTERED_BEFORE_EXECUTION","G21A preregistration not frozen")
    require(g21["decision"]=="FALSIFIED_FULL_G17_PATH_EQUIVALENCE_IN_CONTINUOUS_DYNAMIC_RESPONSE_SPACE_LOOP",
            "G21A parent G21 authority drift")

    pts=prereg["frozen_points"]
    h17=float(pts["g17_outer1_head_m"])
    h21=float(pts["g21_outer1_head_m"])
    h17_outer2=float(pts["g17_outer2_head_m"])
    h21_outer2=float(pts["g21_outer2_head_m"])
    observed=float(pts["outer2_divergence_m"])
    require(abs((h21_outer2-h17_outer2)-observed)<=1e-18,"G21A frozen divergence arithmetic drift")

    # Inherit the frozen physical groundwater carrier from G21.
    g21pr=json.loads((ROOT/"integration"/"research"/"GC_FIXED_INTERFACE_G21_PREREGISTRATION.json").read_text())
    fc=g21pr["frozen_case"]
    duration=float(fc["duration_day"]); qbot=float(fc["predictor_qbot_cm_per_day"])
    a=float(pts["groundwater_a_per_s"]); b=float(pts["groundwater_intercept"])
    k=float(fc["groundwater_k_m_per_day"]); ss=float(fc["groundwater_ss_per_m"])
    bias=float(fc["groundwater_initial_head_bias_m"])

    libmf6=Path(os.environ["LIBMF6"]).resolve()
    swaplib=Path(os.environ["FGC44_SWAP_LIB"]).resolve()
    require(libmf6.is_file() and swaplib.is_file(),"G21A missing live libraries")

    swap=Fgc44RealSwap(swaplib)
    _,_,href,origin,diag=initialize_case(swap,duration,qbot)
    require(origin==(0,0.0,0,0.0),"G21A dirty SWAP origin")
    sy=0.5*float(diag["u"])
    require(swap.g15_trial_call_count()==0,"G21A ordinary participant path dirty")
    swap.g16_begin_session()
    ds=DiagnosticSession(swap,origin,a,b)

    def characterize(label:str,head:float)->dict[str,object]:
        obs,res=ds.residual(head)
        require(int(obs["participant_status"])==0 and res is not None,f"G21A {label} anchor unavailable")
        est=ds.estimate_e3(head)
        require(est["classification"]=="AVAILABLE",f"G21A {label} E3 unavailable")
        row={
            "label":label,"head_m":head,"q_swap_m_per_s":float(obs["q_swap_m_per_s"]),
            "residual_m_per_s":float(res),"mode":str(est["mode"]),
            "scale_m":float(est["selected_d_m"]),"slope_per_s":float(est["slope_per_s"]),
            "confirming_mode":str(est["confirming_mode"]),"confirming_scale_m":float(est["confirming_d_m"]),
            "relative_difference":float(est["relative_difference"]),
        }
        print("FGC44_G21A_ANCHOR_JSON="+json.dumps(row,sort_keys=True,separators=(",",":")))
        return row

    r17=characterize("G17_OUTER1",h17)
    r21=characterize("G21_OUTER1",h21)
    require(swap.state()==origin and not swap.g15_has_live_candidate(),"G21A anchor diagnostics changed authority")

    variants=[]
    configs=[
        ("G17_NATIVE",h17,float(r17["q_swap_m_per_s"]),float(r17["slope_per_s"])),
        ("G21_NATIVE",h21,float(r21["q_swap_m_per_s"]),float(r21["slope_per_s"])),
        ("G21_ANCHOR_G17_TANGENT",h21,float(r21["q_swap_m_per_s"]),float(r17["slope_per_s"])),
        ("G17_ANCHOR_G21_TANGENT",h17,float(r17["q_swap_m_per_s"]),float(r21["slope_per_s"])),
    ]
    for name,anchor,qref,p in configs:
        residual=qref-(a*anchor+b)
        analytic=anchor+residual/(a-p)
        live=fresh_response(libmf6,swaplib,duration,href,k,ss,sy,bias,anchor,qref,p)
        error=float(live["head_m"])-analytic
        require(abs(error)<=1e-12,f"G21A {name} fresh head disagrees with affine root: {error}")
        row={"name":name,"anchor_m":anchor,"qref_m_per_s":qref,"slope_per_s":p,
             "residual_m_per_s":residual,"analytic_head_m":analytic,
             "fresh_head_m":float(live["head_m"]),"fresh_minus_analytic_m":error,
             "fresh_iterations":int(live["iterations"])}
        variants.append(row)
        print("FGC44_G21A_FRESH_JSON="+json.dumps(row,sort_keys=True,separators=(",",":")))

    by={x["name"]:x for x in variants}
    fresh17=float(by["G17_NATIVE"]["fresh_head_m"])
    fresh21=float(by["G21_NATIVE"]["fresh_head_m"])
    require(abs(fresh17-h17_outer2)<=1e-12,
            f"G21A G17 native fresh response no longer reproduces G17 outer2: {fresh17-h17_outer2}")

    # Replay outer 1 in one prepared solve, then apply the *identical* G21-native
    # outer-2 response. This isolates continuous-X path dependence.
    h0=float(fc["initial_head_m"])
    o0,res0=ds.residual(h0)
    require(int(o0["participant_status"])==0 and res0 is not None,"G21A h0 unavailable")
    e0=ds.estimate_e3(h0)
    require(e0["classification"]=="AVAILABLE","G21A h0 E3 unavailable")
    p0=float(e0["slope_per_s"]); g0=a*h0+b

    with tempfile.TemporaryDirectory(prefix="fgc44-g21a-mf-") as tmp:
        workdir=Path(tmp)
        build_model(workdir,duration,href,k,ss,sy,bias)
        raw=XmiWrapper(lib_path=libmf6,working_directory=workdir)
        kernel=LifecycleCountingKernel(raw)
        publisher=Fgc34CtypesPublisher(swaplib)
        initialized=False
        try:
            raw.initialize(); initialized=True
            require("6.8.0" in raw.get_version(),"G21A wrong MODFLOW version")
            kernel.prepare_time_step(0.0)
            session=Modflow6PreparedSolveSession(kernel,"GWF_1","API_SWAP",publisher,solution_id=1)
            require(session.acquire_after_prepare_time_step()==PreparedSolveStatus.OK,session.last_error)
            require(session.open_prepared_solve()==PreparedSolveStatus.OK,session.last_error)
            xold=session.accepted_xold.copy()
            binding=[Binding(7001,1,2)]
            replay=[]
            for lam in (1.0,0.5,0.25):
                qref0=g0+lam*float(res0)
                hh,calls=settle(session,binding,xold,h0,qref0,p0)
                replay.append({"lambda":lam,"head_m":hh,"solve_calls":calls})
            replay_h1=float(replay[-1]["head_m"])
            require(abs(replay_h1-h21)<=1e-12,
                    f"G21A outer1 replay drifted from G21 anchor: {replay_h1-h21}")

            cont21,calls21=settle(session,binding,xold,h21,float(r21["q_swap_m_per_s"]),float(r21["slope_per_s"]))
            require(kernel.prepare_time_step_calls==1 and kernel.prepare_solve_calls==1,
                    "G21A repeated prepared lifecycle")
            require(np.array_equal(session.xold,xold),"G21A final XOLD drift")
            continuous={"outer1_replay":replay,"outer2_head_m":cont21,"outer2_solve_calls":calls21,
                        "total_solve_calls":kernel.solve_calls}
            print("FGC44_G21A_CONTINUOUS_JSON="+json.dumps(continuous,sort_keys=True,separators=(",",":")))
            raw.finalize(); initialized=False
        finally:
            if initialized:
                try: raw.finalize()
                except Exception: pass

    response_effect=fresh21-h17_outer2
    path_effect=cont21-fresh21
    reconstructed=response_effect+path_effect
    reconstruction_error=reconstructed-observed
    require(abs(reconstruction_error)<=1e-12,
            f"G21A measured components do not account for G21 divergence: {reconstruction_error}")

    threshold=1e-12
    response_large=abs(response_effect)>threshold
    path_large=abs(path_effect)>threshold
    if response_large and not path_large:
        classification="RESPONSE_PARAMETER_DOMINATED"
    elif path_large and not response_large:
        classification="PREPARED_SOLVE_PATH_DOMINATED"
    elif response_large and path_large:
        classification="MIXED"
    else:
        classification="UNRESOLVED_SUBTHRESHOLD_COMPONENTS"

    counts=swap.g16_counts()
    require(counts[0]==counts[1]+counts[2] and counts[1]==counts[3],"G21A G16 accounting mismatch")
    require(swap.g15_trial_call_count()==0,"G21A used ordinary publication-path trials")
    require(swap.state()==origin and not swap.g15_has_live_candidate(),"G21A diagnostics changed SWAP authority")
    require(not swap.swap_preflight() and not swap.ledger_preflight(),"G21A diagnostics left publication readiness")
    swap.g16_end_session()

    summary={
        "classification":classification,
        "observed_g21_outer2_divergence_m":observed,
        "g17_native_fresh_minus_g17_reference_m":fresh17-h17_outer2,
        "g21_native_fresh_minus_g17_reference_m":response_effect,
        "identical_response_continuous_minus_fresh_m":path_effect,
        "reconstructed_divergence_m":reconstructed,
        "reconstruction_error_m":reconstruction_error,
        "anchor_head_offset_m":h21-h17,
        "tangent_difference_per_s":float(r21["slope_per_s"])-float(r17["slope_per_s"]),
        "residual_difference_m_per_s":float(r21["residual_m_per_s"])-float(r17["residual_m_per_s"]),
        "g16_logical_requests":counts[0],"g16_participant_trials":counts[1],
        "g16_cache_hits":counts[2],"g16_unique_heads":counts[3],
        "ordinary_publication_trials":swap.g15_trial_call_count(),
        "diagnostic_non_authority":"PASS",
    }
    print("FGC44_G21A_SUMMARY_JSON="+json.dumps(summary,sort_keys=True,separators=(",",":")))
    print("GC_FIXED_INTERFACE_G21A_DECOMPOSITION=PASS")
    print("GC_FIXED_INTERFACE_G21A_EXECUTION=PASS")


if __name__=="__main__":
    main()
