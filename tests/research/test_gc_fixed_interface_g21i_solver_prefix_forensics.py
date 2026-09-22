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

PREREG=ROOT/"integration"/"research"/"GC_FIXED_INTERFACE_G21I_PREREGISTRATION.json"
G21H=ROOT/"integration"/"research"/"GC_FIXED_INTERFACE_G21H_RESULT.json"
HEADCALC=ROOT/"src"/"legacy"/"b1_10_port"/"headcalc.f90"
BRIDGE=ROOT/"tests"/"fgc"/"support"/"mod_fgc44_real_swap_c_bridge.f90"

SW_SOLVE_CONVERGED=1


def require(cond:bool,msg:str)->None:
    if not cond:
        raise AssertionError(msg)


def source_audit()->dict[str,object]:
    headcalc=HEADCALC.read_text()
    bridge=BRIDGE.read_text()
    required=(
        "MaxIt1 = MaxIt",
        "do solver_numbit = 1, MaxIt1",
        "ctx%diagnostics%nonlinear_iterations = ctx%diagnostics%nonlinear_iterations + 1",
        "do itry = 1, MaxBackTr",
        "ctx%diagnostics%backtracking_attempts = ctx%diagnostics%backtracking_attempts + 1",
        "factor = factor / 3.0d0",
    )
    for token in required:
        require(token in headcalc,f"G21I HeadCalc source drift: {token}")
    marker='integer(c_int) function fgc44_g21i_solver_prefix_c'
    start=bridge.lower().find(marker)
    require(start>=0,"G21I bridge probe missing")
    end=bridge.lower().find("end function fgc44_g21i_solver_prefix_c",start)
    require(end>start,"G21I bridge probe end missing")
    block=bridge[start:end]
    for token in (
        "probe_config=corrector_config",
        "probe_config%transaction%max_retries=0",
        "probe_parameters=corrector_parameters",
        "probe_parameters%max_iterations=int(max_iterations)",
        "corrector_backend%run_trial",
        "corrector_backend%discard_trial_candidate",
    ):
        require(token in block,f"G21I bridge source drift: {token}")
    require("corrector_parameters%max_iterations=" not in block,
            "G21I probe mutates saved corrector max_iterations")
    require("corrector_config%transaction%max_retries=" not in block,
            "G21I probe mutates saved corrector retry policy")
    return {
        "headcalc_loop_bound":"MaxIt1=MaxIt",
        "backtracking_loop":"itry=1..MaxBackTr",
        "backtracking_factor":"factor/=3",
        "probe_parameter_copy":True,
        "probe_config_copy":True,
        "saved_parameter_config_mutation":False,
    }


def main()->None:
    prereg=json.loads(PREREG.read_text())
    parent=json.loads(G21H.read_text())
    require(prereg["work_unit"]=="GC-FIXED-INTERFACE-G21I","wrong G21I preregistration")
    require(prereg["status"]=="PREREGISTERED_BEFORE_IMPLEMENTATION","G21I preregistration not frozen")
    require(parent["decision"]=="QUALIFIED_ISOLATED_FINAL_RETRY_SOLVER_BIFURCATION_CONFIRMED",
            "G21I parent decision drift")

    frozen=prereg["frozen_case"]
    duration=float(frozen["duration_day"])
    prefixes=[int(x) for x in frozen["max_iteration_prefixes"]]
    require(prefixes==list(range(1,17)),"G21I prefix ladder drift")
    heads=frozen["heads"]
    require(len(heads)==4,"G21I frozen head count drift")

    source=source_audit()
    print("FGC44_G21I_SOURCE_AUDIT_JSON="+json.dumps(source,sort_keys=True,separators=(",",":")))

    lib=Path(os.environ["FGC44_SWAP_LIB"]).resolve()
    require(lib.is_file(),"G21I missing FGC44 library")
    swap=Fgc44RealSwap(lib)
    _,_,_,origin,_=initialize_case(swap,0.01,1.0e-6)
    require(origin==(0,0.0,0,0.0),"G21I dirty origin")

    all_rows=[]
    traces={}
    for spec in heads:
        boundary=str(spec["boundary"])
        side=str(spec["side"])
        head=float(spec["head_m"])
        parent_status=int(spec["parent_status"])
        expected_full_status=int(spec["full_solver_status"])
        expected_full_iterations=int(spec["full_nonlinear_iterations"])
        expected_full_backtracking=int(spec["full_backtracking_attempts"])
        trace=[]
        for prefix in prefixes:
            before=swap.state()
            probe=swap.g21i_solver_prefix(head,duration,prefix)
            backend=swap.g21g_backend_observation()
            after=swap.state()
            require(before==origin and after==origin,
                    f"G21I authority mutation {boundary} {side} prefix={prefix}")
            require(not swap.g15_has_live_candidate(),
                    f"G21I participant candidate leakage {boundary} {side} prefix={prefix}")
            require(not swap.swap_preflight() and not swap.ledger_preflight(),
                    f"G21I publication authority leakage {boundary} {side} prefix={prefix}")
            nit=int(backend["nonlinear_iterations"])
            require(nit<=prefix,f"G21I nonlinear iterations exceed prefix {boundary} {side} {nit}>{prefix}")
            row={
                "boundary":boundary,"side":side,"head_m":head,"head_hex":head.hex(),
                "parent_status":parent_status,"max_iterations":prefix,
                "solver_status":int(backend["solver_status"]),
                "nonlinear_iterations":nit,
                "jacobian_builds":int(backend["jacobian_builds"]),
                "linear_solves":int(backend["linear_solves"]),
                "backtracking_attempts":int(backend["backtracking_attempts"]),
                "internal_retries":int(backend["internal_retries"]),
                "result_status":int(probe["result_status"]),
                "completed":bool(probe["completed"]),
                "candidate_ready":bool(probe["candidate_ready"]),
            }
            trace.append(row); all_rows.append(row)
        traces[(boundary,side)]=trace

        full=trace[-1]
        require(full["solver_status"]==expected_full_status,
                f"G21I prefix16 solver status drift {boundary} {side}")
        require(full["nonlinear_iterations"]==expected_full_iterations,
                f"G21I prefix16 nonlinear iteration drift {boundary} {side}")
        require(full["backtracking_attempts"]==expected_full_backtracking,
                f"G21I prefix16 backtracking drift {boundary} {side}")

        if parent_status==6:
            require(all(int(x["solver_status"])!=SW_SOLVE_CONVERGED for x in trace),
                    f"G21I status6 side converged within prefix16 {boundary}")
            for x in trace:
                require(int(x["nonlinear_iterations"])==int(x["max_iterations"]),
                        f"G21I nonconverged prefix not exhausted {boundary} {side} {x}")
        else:
            first_conv=next((int(x["max_iterations"]) for x in trace if int(x["solver_status"])==SW_SOLVE_CONVERGED),None)
            require(first_conv==expected_full_iterations,
                    f"G21I first convergence prefix drift {boundary} {side}: {first_conv} != {expected_full_iterations}")
            canonical=trace[first_conv-1]
            for x in trace[first_conv-1:]:
                require(int(x["solver_status"])==SW_SOLVE_CONVERGED,
                        f"G21I converged arm became nonconverged again {boundary} {side}")
                require(int(x["nonlinear_iterations"])==expected_full_iterations,
                        f"G21I converged prefix extended nonlinear path {boundary} {side}")
                require(int(x["backtracking_attempts"])==expected_full_backtracking,
                        f"G21I converged prefix changed backtracking path {boundary} {side}")
                require(int(x["jacobian_builds"])==int(canonical["jacobian_builds"]) and
                        int(x["linear_solves"])==int(canonical["linear_solves"]),
                        f"G21I converged prefix changed solve diagnostics {boundary} {side}")

        cumulative=[int(x["backtracking_attempts"]) for x in trace]
        increments=[cumulative[0]]+[cumulative[i]-cumulative[i-1] for i in range(1,len(cumulative))]
        require(all(x>=0 for x in increments),f"G21I negative backtracking increment {boundary} {side}")
        print("FGC44_G21I_HEAD_JSON="+json.dumps({
            "boundary":boundary,"side":side,"head_m":head,"parent_status":parent_status,
            "solver_status_by_prefix":[int(x["solver_status"]) for x in trace],
            "nonlinear_iterations_by_prefix":[int(x["nonlinear_iterations"]) for x in trace],
            "backtracking_cumulative_by_prefix":cumulative,
            "backtracking_increment_by_iteration":increments,
        },sort_keys=True,separators=(",",":")))

    boundary_results=[]
    localized=0
    convergence_only=0
    for boundary in ("B1_6_TO_0","B2_0_TO_6"):
        fail_side="status6"
        ok_side="status0"
        fail=traces[(boundary,fail_side)]
        ok=traces[(boundary,ok_side)]
        conv_prefix=next(int(x["max_iterations"]) for x in ok if int(x["solver_status"])==SW_SOLVE_CONVERGED)
        fail_bt=[int(x["backtracking_attempts"]) for x in fail]
        ok_bt=[int(x["backtracking_attempts"]) for x in ok]
        first_div=next((i+1 for i in range(conv_prefix) if fail_bt[i]!=ok_bt[i]),None)
        if first_div is not None:
            localized+=1
            classification="PREFIX_BACKTRACKING_BRANCH_LOCALIZED"
        else:
            convergence_only+=1
            classification="PREFIX_CONVERGENCE_BRANCH_WITHOUT_PRIOR_BACKTRACKING_SPLIT"
        boundary_results.append({
            "boundary":boundary,
            "status0_first_convergence_prefix":conv_prefix,
            "first_cumulative_backtracking_divergence_prefix":first_div,
            "classification":classification,
            "status6_prefix16_backtracking":fail_bt[-1],
            "status0_converged_backtracking":ok_bt[conv_prefix-1],
        })

    if localized==2:
        classification="PREFIX_BACKTRACKING_BRANCH_LOCALIZED"
    elif localized==0 and convergence_only==2:
        classification="PREFIX_CONVERGENCE_BRANCH_WITHOUT_PRIOR_BACKTRACKING_SPLIT"
    else:
        classification="PREFIX_FORENSICS_PARTIAL"

    # Functional saved-configuration postcondition through the normal qualified G16 path.
    swap.g16_begin_session()
    observed=[]
    for spec in heads:
        obs=swap.g16_observe_head(float(spec["head_m"]))
        status=int(obs["participant_status"])
        expected=int(spec["parent_status"])
        require(status==expected,f"G21I saved solver config changed at {spec['boundary']} {spec['side']}")
        observed.append(status)
        require(swap.state()==origin and not swap.g15_has_live_candidate(),
                "G21I postprobe G16 route changed authority")
    counts=swap.g16_counts()
    require(counts==(4,4,0,4),f"G21I postprobe G16 accounting drift {counts}")
    swap.g16_end_session()
    require(swap.g16_counts()==(0,0,0,0),"G21I postprobe G16 cache not cleared")

    summary={
        "classification":classification,
        "boundary_results":boundary_results,
        "probe_count":len(all_rows),
        "prefixes_per_head":16,
        "saved_config_postprobe_status_vector":observed,
        "saved_config_postprobe_g16_counts":list(counts),
        "accepted_state_ledger_mutation":0,
        "participant_candidate_leakage":0,
        "production_policy_claim":"NONE",
    }
    print("FGC44_G21I_SUMMARY_JSON="+json.dumps(summary,sort_keys=True,separators=(",",":")))
    print("GC_FIXED_INTERFACE_G21I_PREFIX_TOMOGRAPHY=PASS")
    print("GC_FIXED_INTERFACE_G21I_EXECUTION=PASS")


if __name__=="__main__":
    main()
