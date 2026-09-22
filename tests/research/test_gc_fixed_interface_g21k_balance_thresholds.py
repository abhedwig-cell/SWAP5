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
from test_gc_fixed_interface_fgc44_safeguarded_newton_g08 import initialize_case

PREREG=ROOT/"integration"/"research"/"GC_FIXED_INTERFACE_G21K_PREREGISTRATION.json"
G21J=ROOT/"integration"/"research"/"GC_FIXED_INTERFACE_G21J_RESULT.json"
HEADCALC=ROOT/"src"/"legacy"/"b1_10_port"/"headcalc.f90"
BRIDGE=ROOT/"tests"/"fgc"/"support"/"mod_fgc44_real_swap_c_bridge.f90"

CONVERGED=1
BASE=1.0e-12
RELAX=1.0e6
DURATION=3.90625e-5


def require(cond:bool,msg:str)->None:
    if not cond:
        raise AssertionError(msg)


def source_audit()->dict[str,object]:
    h=HEADCALC.read_text()
    b=BRIDGE.read_text()
    for token in (
        "if (dabs(fsi_ws%residual(i)) >  CritDevBalCp)",
        "if (dabs(sum1) > CritDevBalTot) flnonconv = .TRUE.",
        "if (sump < sumold .OR. Fmax < CritDevBalCp) goto 1",
    ):
        require(token in h,f"G21K HeadCalc source drift: {token}")
    marker='integer(c_int) function fgc44_g21k_tolerance_probe_c'
    start=b.lower().find(marker); require(start>=0,"G21K bridge probe missing")
    end=b.lower().find("end function fgc44_g21k_tolerance_probe_c",start)
    require(end>start,"G21K bridge probe end missing")
    block=b[start:end]
    for token in (
        "probe_config=corrector_config",
        "probe_config%transaction%max_retries=0",
        "probe_parameters=corrector_parameters",
        "probe_parameters%compartment_balance_tolerance=real(comp_tol,real64)",
        "probe_parameters%total_balance_tolerance=real(total_tol,real64)",
        "probe_parameters%head_abs_tolerance=real(head_abs_tol,real64)",
        "probe_parameters%head_rel_tolerance=real(head_rel_tol,real64)",
        "probe_parameters%ponding_tolerance=real(pond_tol,real64)",
    ):
        require(token in block,f"G21K bridge source drift: {token}")
    return {
        "total_balance_threshold_direct_predicate":True,
        "compartment_threshold_direct_predicate":True,
        "compartment_also_controls_backtracking":True,
        "probe_uses_saved_config_parameter_copies":True,
    }


def probe(swap:Fgc44RealSwap,origin:tuple[int,float,int,float],head:float,maxit:int,
          comp:float,total:float,habs:float,hrel:float,pond:float)->dict[str,object]:
    before=swap.state()
    raw=swap.g21k_tolerance_probe(head,DURATION,maxit,comp,total,habs,hrel,pond)
    backend=swap.g21g_backend_observation()
    after=swap.state()
    require(before==origin and after==origin,"G21K accepted authority mutation")
    require(not swap.g15_has_live_candidate(),"G21K participant candidate leakage")
    require(not swap.swap_preflight() and not swap.ledger_preflight(),"G21K publication authority leakage")
    return {
        "comp_tol":comp,"total_tol":total,"head_abs_tol":habs,"head_rel_tol":hrel,"pond_tol":pond,
        "solver_status":int(backend["solver_status"]),
        "nonlinear_iterations":int(backend["nonlinear_iterations"]),
        "backtracking_attempts":int(backend["backtracking_attempts"]),
        "jacobian_builds":int(backend["jacobian_builds"]),
        "linear_solves":int(backend["linear_solves"]),
        "result_status":int(raw["result_status"]),
        "completed":bool(raw["completed"]),
        "candidate_ready":bool(raw["candidate_ready"]),
    }


def binary_event_bracket(low:float,high:float,event,eval_fn,max_iter:int)->tuple[float,float,dict[str,object],dict[str,object],int]:
    lo=low; hi=high
    lo_row=eval_fn(lo); hi_row=eval_fn(hi)
    require(not event(lo_row),"G21K lower bracket already event")
    require(event(hi_row),"G21K upper bracket not event")
    n=0
    while math.nextafter(lo,math.inf)<hi and n<max_iter:
        mid=(lo+hi)/2.0
        if mid<=lo or mid>=hi:
            break
        row=eval_fn(mid)
        n+=1
        if event(row):
            hi=mid; hi_row=row
        else:
            lo=mid; lo_row=row
    return lo,hi,lo_row,hi_row,n


def main()->None:
    prereg=json.loads(PREREG.read_text())
    parent=json.loads(G21J.read_text())
    require(prereg["work_unit"]=="GC-FIXED-INTERFACE-G21K","wrong G21K preregistration")
    require(prereg["status"]=="PREREGISTERED_BEFORE_IMPLEMENTATION","G21K preregistration not frozen")
    require(parent["decision"]=="QUALIFIED_BOUNDARY_SPECIFIC_CONVERGENCE_CRITERIA","G21K parent drift")
    constants=prereg["constants"]
    require(float(constants["baseline_tolerance"])==BASE,"G21K baseline tolerance drift")
    require(float(constants["diagnostic_nonblocking_tolerance"])==RELAX,"G21K relaxed tolerance drift")
    require(float(constants["duration_day"])==DURATION,"G21K duration drift")
    max_doublings=int(constants["max_doublings"])
    max_bisect=int(constants["max_binary64_bisections"])

    print("FGC44_G21K_SOURCE_AUDIT_JSON="+json.dumps(source_audit(),sort_keys=True,separators=(",",":")))

    lib=Path(os.environ["FGC44_SWAP_LIB"]).resolve()
    require(lib.is_file(),"G21K missing FGC44 library")
    swap=Fgc44RealSwap(lib)
    _,_,_,origin,_=initialize_case(swap,0.01,1.0e-6)
    require(origin==(0,0.0,0,0.0),"G21K dirty origin")

    # B2 total-balance threshold: all other tolerances stay frozen. TOTAL never
    # participates in HeadCalc backtracking, so all evaluated arms must preserve
    # the three-attempt path.
    b2_head=-0.7150100297647868
    def b2_eval(tol:float)->dict[str,object]:
        row=probe(swap,origin,b2_head,3,BASE,tol,BASE,BASE,BASE)
        require(int(row["backtracking_attempts"])==3,
                f"G21K B2 total threshold changed backtracking at {tol}: {row}")
        return row
    b2_base=b2_eval(BASE)
    require(int(b2_base["solver_status"])!=CONVERGED,"G21K B2 baseline unexpectedly converged")
    low=BASE; high=None; ladder=[]
    for k in range(1,max_doublings+1):
        t=BASE*(2.0**k)
        row=b2_eval(t); ladder.append({"tolerance":t,"solver_status":row["solver_status"]})
        if int(row["solver_status"])==CONVERGED:
            high=t; break
        low=t
    require(high is not None,"G21K B2 failed to bracket total-balance threshold")
    b2_event=lambda row:int(row["solver_status"])==CONVERGED
    b2_lo,b2_hi,b2_lo_row,b2_hi_row,b2_n=binary_event_bracket(low,float(high),b2_event,b2_eval,max_bisect)
    b2_adjacent=math.nextafter(b2_lo,math.inf)>=b2_hi
    require(b2_adjacent,"G21K B2 binary64 bracket did not close")
    require(int(b2_lo_row["solver_status"])!=CONVERGED and int(b2_hi_row["solver_status"])==CONVERGED,
            "G21K B2 final bracket polarity invalid")
    b2={
        "classification":"B2_TOTAL_THRESHOLD_RESOLVED",
        "largest_fail_tolerance":b2_lo,
        "smallest_pass_tolerance":b2_hi,
        "adjacent_binary64":b2_adjacent,
        "bisections":b2_n,
        "fail_backtracking":b2_lo_row["backtracking_attempts"],
        "pass_backtracking":b2_hi_row["backtracking_attempts"],
        "midpoint_estimate":0.5*(b2_lo+b2_hi),
        "relative_excess_over_production":0.5*(b2_lo+b2_hi)/BASE-1.0,
        "doubling_ladder":ladder,
    }
    print("FGC44_G21K_B2_JSON="+json.dumps(b2,sort_keys=True,separators=(",",":")))

    # B1 compartment threshold: neutralize the three non-compartment criteria
    # shown irrelevant in G21J. The event is either same-path convergence or a
    # change in the original eight-attempt backtracking trajectory.
    b1_head=-0.7150100297648301
    def b1_eval(tol:float)->dict[str,object]:
        return probe(swap,origin,b1_head,4,tol,RELAX,RELAX,RELAX,RELAX)
    b1_base=b1_eval(BASE)
    require(int(b1_base["solver_status"])!=CONVERGED and int(b1_base["backtracking_attempts"])==8,
            f"G21K B1 noncompartment-relaxed baseline drift {b1_base}")
    def b1_event(row:dict[str,object])->bool:
        return int(row["solver_status"])==CONVERGED or int(row["backtracking_attempts"])!=8
    low=BASE; high=None; ladder1=[]
    for k in range(1,max_doublings+1):
        t=BASE*(2.0**k)
        row=b1_eval(t)
        ladder1.append({"tolerance":t,"solver_status":row["solver_status"],"backtracking":row["backtracking_attempts"]})
        if b1_event(row):
            high=t; break
        low=t
    require(high is not None,"G21K B1 failed to bracket first compartment event")
    b1_lo,b1_hi,b1_lo_row,b1_hi_row,b1_n=binary_event_bracket(low,float(high),b1_event,b1_eval,max_bisect)
    b1_adjacent=math.nextafter(b1_lo,math.inf)>=b1_hi
    require(b1_adjacent,"G21K B1 binary64 event bracket did not close")
    if int(b1_hi_row["solver_status"])==CONVERGED and int(b1_hi_row["backtracking_attempts"])==8:
        b1_class="B1_COMPARTMENT_THRESHOLD_RESOLVED_PATH_PRESERVING"
        threshold_est=0.5*(b1_lo+b1_hi)
    else:
        b1_class="B1_COMPARTMENT_THRESHOLD_OCCLUDED_BY_BACKTRACKING"
        threshold_est=None
    b1={
        "classification":b1_class,
        "largest_no_event_tolerance":b1_lo,
        "smallest_event_tolerance":b1_hi,
        "adjacent_binary64":b1_adjacent,
        "bisections":b1_n,
        "low_solver_status":b1_lo_row["solver_status"],
        "low_backtracking":b1_lo_row["backtracking_attempts"],
        "high_solver_status":b1_hi_row["solver_status"],
        "high_backtracking":b1_hi_row["backtracking_attempts"],
        "path_preserving_threshold_midpoint":threshold_est,
        "doubling_ladder":ladder1,
    }
    print("FGC44_G21K_B1_JSON="+json.dumps(b1,sort_keys=True,separators=(",",":")))

    swap.g16_begin_session()
    frozen=[
        (-0.7150100297648301,6),(-0.715010029764824,0),
        (-0.715010029764793,0),(-0.7150100297647868,6),
    ]
    post=[]
    for head,expected in frozen:
        obs=swap.g16_observe_head(head)
        observed=int(obs["participant_status"])
        require(observed==expected,f"G21K saved config changed at {head}")
        require(swap.state()==origin and not swap.g15_has_live_candidate(),"G21K G16 postcondition authority drift")
        post.append(observed)
    counts=swap.g16_counts()
    require(counts==(4,4,0,4),f"G21K G16 accounting drift {counts}")
    swap.g16_end_session()

    summary={
        "b2":b2,
        "b1":b1,
        "saved_config_postprobe_status_vector":post,
        "saved_config_postprobe_g16_counts":list(counts),
        "accepted_state_ledger_mutation":0,
        "participant_candidate_leakage":0,
        "production_tolerance_change":"NONE",
    }
    print("FGC44_G21K_SUMMARY_JSON="+json.dumps(summary,sort_keys=True,separators=(",",":")))
    print("GC_FIXED_INTERFACE_G21K_BALANCE_THRESHOLDS=PASS")
    print("GC_FIXED_INTERFACE_G21K_EXECUTION=PASS")


if __name__=="__main__":
    main()
