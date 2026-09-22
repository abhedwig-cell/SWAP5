from __future__ import annotations

import json
import os
import re
import sys
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/"tests"/"fgc"/"support"))
sys.path.insert(0,str(ROOT/"tests"/"research"))

from fgc44_real_swap_ctypes import Fgc44RealSwap
from test_gc_fixed_interface_fgc44_safeguarded_newton_g08 import initialize_case

PREREG=ROOT/"integration"/"research"/"GC_FIXED_INTERFACE_G21J_PREREGISTRATION.json"
G21I=ROOT/"integration"/"research"/"GC_FIXED_INTERFACE_G21I_RESULT.json"
HEADCALC=ROOT/"src"/"legacy"/"b1_10_port"/"headcalc.f90"
BRIDGE=ROOT/"tests"/"fgc"/"support"/"mod_fgc44_real_swap_c_bridge.f90"

SW_SOLVE_CONVERGED=1
MASK_HEAD=1
MASK_TOTAL=2
MASK_POND=4
MASK_COMPARTMENT=8
PRIMARY_MASKS=(1,2,3,4,5,6,7)
MASK_NAMES={
    0:"BASELINE",1:"HEAD",2:"TOTAL",3:"HEAD_TOTAL",4:"POND",
    5:"HEAD_POND",6:"TOTAL_POND",7:"HEAD_TOTAL_POND",
    8:"COMPARTMENT",15:"ALL",
}


def require(cond:bool,msg:str)->None:
    if not cond:
        raise AssertionError(msg)


def source_audit()->dict[str,object]:
    headcalc=HEADCALC.read_text()
    bridge=BRIDGE.read_text()
    required_headcalc=(
        "if (dabs(fsi_ws%residual(i)) >  CritDevBalCp)",
        "if (abs(state%h(i)-fsi_ws%old_head(i) ) > CritDevh2Cp)",
        "if (abs(state%h(i)-fsi_ws%old_head(i) )/abs(fsi_ws%old_head(i)) > CritDevh1Cp)",
        "if (abs(deviat) > CritDevPondDt)",
        "if (dabs(sum1) > CritDevBalTot) flnonconv = .TRUE.",
        "if (sump < sumold .OR. Fmax < CritDevBalCp) goto 1",
    )
    for token in required_headcalc:
        require(token in headcalc,f"G21J HeadCalc criterion source drift: {token}")
    marker='integer(c_int) function fgc44_g21j_criterion_probe_c'
    start=bridge.lower().find(marker)
    require(start>=0,"G21J criterion probe missing")
    end=bridge.lower().find("end function fgc44_g21j_criterion_probe_c",start)
    require(end>start,"G21J criterion probe end missing")
    block=bridge[start:end]
    required_bridge=(
        "probe_config=corrector_config",
        "probe_config%transaction%max_retries=0",
        "probe_parameters=corrector_parameters",
        "probe_parameters%max_iterations=int(max_iterations)",
        "probe_parameters%head_abs_tolerance=RELAXED_TOL",
        "probe_parameters%head_rel_tolerance=RELAXED_TOL",
        "probe_parameters%total_balance_tolerance=RELAXED_TOL",
        "probe_parameters%ponding_tolerance=RELAXED_TOL",
        "probe_parameters%compartment_balance_tolerance=RELAXED_TOL",
        "corrector_backend%run_trial",
        "corrector_backend%discard_trial_candidate",
    )
    for token in required_bridge:
        require(token in block,f"G21J bridge source drift: {token}")
    require("corrector_parameters%head_abs_tolerance=" not in block,"G21J mutates saved head tolerance")
    require("corrector_parameters%total_balance_tolerance=" not in block,"G21J mutates saved total tolerance")
    require("corrector_parameters%compartment_balance_tolerance=" not in block,"G21J mutates saved compartment tolerance")
    # The frozen FGC44 fixture explicitly disables macropores, eliminating the
    # extra convergence branch that is otherwise present in HeadCalc.
    require("p%macropore_active=.false." in bridge,"G21J frozen fixture macropore route drift")
    return {
        "compartment_check":"abs(residual_i)>CritDevBalCp",
        "head_check":"absolute_or_relative_head_change",
        "ponding_check":"abs(deviat)>CritDevPondDt_when_applicable",
        "total_check":"abs(sum_residual)>CritDevBalTot",
        "compartment_also_controls_backtracking":True,
        "macropore_active":False,
        "probe_uses_parameter_config_copies":True,
    }


def run_probe(swap:Fgc44RealSwap, origin:tuple[int,float,int,float], head:float,
              duration:float, max_iterations:int, mask:int)->dict[str,object]:
    before=swap.state()
    probe=swap.g21j_criterion_probe(head,duration,max_iterations,mask)
    backend=swap.g21g_backend_observation()
    after=swap.state()
    require(before==origin and after==origin,f"G21J accepted authority mutation mask={mask}")
    require(not swap.g15_has_live_candidate(),f"G21J participant candidate leakage mask={mask}")
    require(not swap.swap_preflight() and not swap.ledger_preflight(),
            f"G21J publication authority leakage mask={mask}")
    return {
        "mask":mask,
        "name":MASK_NAMES[mask],
        "solver_status":int(backend["solver_status"]),
        "nonlinear_iterations":int(backend["nonlinear_iterations"]),
        "jacobian_builds":int(backend["jacobian_builds"]),
        "linear_solves":int(backend["linear_solves"]),
        "backtracking_attempts":int(backend["backtracking_attempts"]),
        "internal_retries":int(backend["internal_retries"]),
        "result_status":int(probe["result_status"]),
        "completed":bool(probe["completed"]),
        "candidate_ready":bool(probe["candidate_ready"]),
        "temporal_rejections":int(probe["temporal_rejections"]),
        "solver_rejections":int(probe["solver_rejections"]),
    }


def minimal_success_masks(success_masks:list[int])->list[int]:
    out=[]
    for m in success_masks:
        if not any(n!=m and (n & m)==n for n in success_masks):
            out.append(m)
    return sorted(out)


def classify(primary:list[dict[str,object]], baseline_bt:int)->tuple[str,list[int],bool]:
    valid=[r for r in primary if int(r["backtracking_attempts"])==baseline_bt]
    path_interference=any(int(r["backtracking_attempts"])!=baseline_bt for r in primary)
    success=[int(r["mask"]) for r in valid if int(r["solver_status"])==SW_SOLVE_CONVERGED]
    mins=minimal_success_masks(success)
    if 1 in mins:
        return "HEAD_CHANGE_BLOCKER",mins,path_interference
    if 2 in mins:
        return "TOTAL_BALANCE_BLOCKER",mins,path_interference
    if 4 in mins:
        return "PONDING_BLOCKER",mins,path_interference
    if mins:
        return "MULTIPLE_NONCOMPARTMENT_CRITERIA_REQUIRED",mins,path_interference
    union=next(r for r in primary if int(r["mask"])==7)
    if int(union["backtracking_attempts"])==baseline_bt and int(union["solver_status"])!=SW_SOLVE_CONVERGED:
        return "COMPARTMENT_BALANCE_NECESSARY_BLOCKER",[],path_interference
    return "MIXED_OR_UNRESOLVED",mins,path_interference


def main()->None:
    prereg=json.loads(PREREG.read_text())
    parent=json.loads(G21I.read_text())
    require(prereg["work_unit"]=="GC-FIXED-INTERFACE-G21J","wrong G21J preregistration")
    require(prereg["status"]=="PREREGISTERED_BEFORE_IMPLEMENTATION","G21J preregistration not frozen")
    require(parent["decision"]=="QUALIFIED_PREFIX_CONVERGENCE_BRANCH_WITHOUT_PRIOR_BACKTRACKING_SPLIT",
            "G21J parent decision drift")
    require(float(prereg["diagnostic_relaxed_tolerance"])==1.0e6,"G21J relaxed tolerance drift")

    source=source_audit()
    print("FGC44_G21J_SOURCE_AUDIT_JSON="+json.dumps(source,sort_keys=True,separators=(",",":")))

    lib=Path(os.environ["FGC44_SWAP_LIB"]).resolve()
    require(lib.is_file(),"G21J missing FGC44 library")
    swap=Fgc44RealSwap(lib)
    _,_,_,origin,_=initialize_case(swap,0.01,1.0e-6)
    require(origin==(0,0.0,0,0.0),"G21J dirty origin")

    boundary_results=[]
    for case in prereg["frozen_cases"]:
        bid=str(case["id"])
        duration=float(case["duration_day"])
        maxit=int(case["max_iterations"])
        fail_head=float(case["status6_head_m"])
        ok_head=float(case["status0_head_m"])
        baseline_bt=int(case["baseline_backtracking"])

        fail_baseline=run_probe(swap,origin,fail_head,duration,maxit,0)
        ok_baseline=run_probe(swap,origin,ok_head,duration,maxit,0)
        require(int(fail_baseline["solver_status"])!=SW_SOLVE_CONVERGED,
                f"G21J {bid} status6 baseline unexpectedly converged")
        require(int(ok_baseline["solver_status"])==SW_SOLVE_CONVERGED,
                f"G21J {bid} status0 baseline failed")
        require(int(fail_baseline["nonlinear_iterations"])==maxit and
                int(ok_baseline["nonlinear_iterations"])==maxit,
                f"G21J {bid} split-prefix nonlinear count drift")
        require(int(fail_baseline["backtracking_attempts"])==baseline_bt and
                int(ok_baseline["backtracking_attempts"])==baseline_bt,
                f"G21J {bid} baseline backtracking drift")

        primary=[run_probe(swap,origin,fail_head,duration,maxit,m) for m in PRIMARY_MASKS]
        classification,mins,path_interference=classify(primary,baseline_bt)

        secondary=[]
        if classification=="COMPARTMENT_BALANCE_NECESSARY_BLOCKER":
            secondary=[
                run_probe(swap,origin,fail_head,duration,maxit,MASK_COMPARTMENT),
                run_probe(swap,origin,fail_head,duration,maxit,15),
            ]

        row={
            "boundary":bid,
            "max_iterations":maxit,
            "status6_head_m":fail_head,
            "status0_head_m":ok_head,
            "baseline_backtracking":baseline_bt,
            "status6_baseline":fail_baseline,
            "status0_baseline":ok_baseline,
            "primary":primary,
            "minimal_success_masks":mins,
            "primary_path_interference":path_interference,
            "secondary":secondary,
            "classification":classification,
        }
        boundary_results.append(row)
        print("FGC44_G21J_BOUNDARY_JSON="+json.dumps(row,sort_keys=True,separators=(",",":")))

    classes=[str(x["classification"]) for x in boundary_results]
    if classes[0]==classes[1]:
        overall=classes[0]
    else:
        overall="BOUNDARY_SPECIFIC_MIXED_CRITERIA"

    # Functional proof that diagnostic parameter copies did not leak into the
    # normal participant path.
    frozen_heads=[
        ("B1","status6",-0.7150100297648301,6),
        ("B1","status0",-0.715010029764824,0),
        ("B2","status0",-0.715010029764793,0),
        ("B2","status6",-0.7150100297647868,6),
    ]
    swap.g16_begin_session()
    post=[]
    for bid,side,head,expected in frozen_heads:
        obs=swap.g16_observe_head(head)
        observed=int(obs["participant_status"])
        require(observed==expected,f"G21J saved config changed {bid} {side}")
        require(swap.state()==origin and not swap.g15_has_live_candidate(),
                f"G21J postprobe G16 authority drift {bid} {side}")
        post.append(observed)
    counts=swap.g16_counts()
    require(counts==(4,4,0,4),f"G21J postprobe G16 accounting drift {counts}")
    swap.g16_end_session()
    require(swap.g16_counts()==(0,0,0,0),"G21J G16 cache not cleared")

    summary={
        "classification":overall,
        "boundary_classifications":classes,
        "boundary_results":boundary_results,
        "saved_config_postprobe_status_vector":post,
        "saved_config_postprobe_g16_counts":list(counts),
        "accepted_state_ledger_mutation":0,
        "participant_candidate_leakage":0,
        "production_policy_claim":"NONE",
    }
    print("FGC44_G21J_SUMMARY_JSON="+json.dumps(summary,sort_keys=True,separators=(",",":")))
    print("GC_FIXED_INTERFACE_G21J_CONVERGENCE_CRITERIA=PASS")
    print("GC_FIXED_INTERFACE_G21J_EXECUTION=PASS")


if __name__=="__main__":
    main()
