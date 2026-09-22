from __future__ import annotations

import ast
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
from test_fgc44_real_swap_modflow_end_to_end import Binding
from test_gc_fixed_interface_fgc44_safeguarded_newton_g08 import initialize_case
from test_gc_fixed_interface_g17_safeguarded_orchestration import (
    DiagnosticSession,SCALES_M,REL_TOL,FLUX_TOL,MERIT_ABS_TOL,MAX_OUTER,MAX_BACKTRACK,
)
from test_gc_fixed_interface_g21_dynamic_response_globalization import (
    LifecycleCountingKernel,settle_response,
)
from test_gc_fixed_interface_g21d_under_relaxation_causal import build_model_variant,scalar

PREREG=ROOT/"integration"/"research"/"GC_FIXED_INTERFACE_G21E_PREREGISTRATION.json"
G21D=ROOT/"integration"/"research"/"GC_FIXED_INTERFACE_G21D_RESULT.json"
G17=ROOT/"integration"/"research"/"GC_FIXED_INTERFACE_G17_RESULT.json"
HEAD_ENDPOINT_GATE=5.0e-10
TRAJECTORY_GATE=1.0e-12


def require(cond:bool,msg:str)->None:
    if not cond:
        raise AssertionError(msg)


def source_ownership_audit()->dict[str,object]:
    source=Path(__file__).read_text()
    tree=ast.parse(source)
    forbidden=[]
    state_writes=[]
    for node in ast.walk(tree):
        if isinstance(node,ast.Call) and isinstance(node.func,ast.Attribute):
            if node.func.attr in {
                "set_value","set_value_ptr","set_head","set_current_head","set_x",
                "restore_iterate","restore_previous_x","rollback_iteration","rollback_solve",
                "restart_from_xold",
            }:
                forbidden.append(node.func.attr)
        if isinstance(node,(ast.Assign,ast.AnnAssign,ast.AugAssign)):
            targets=node.targets if isinstance(node,ast.Assign) else [node.target]
            for target in targets:
                if isinstance(target,ast.Subscript):
                    value=target.value
                    if isinstance(value,ast.Attribute) and isinstance(value.value,ast.Name):
                        if value.value.id=="session" and value.attr in {"head","xold","accepted_xold"}:
                            state_writes.append(f"session.{value.attr}[]")
    require(not forbidden,f"G21E forbidden state-control calls {forbidden}")
    require(not state_writes,f"G21E direct session state writes {state_writes}")
    return {"forbidden_state_control_calls":forbidden,"direct_session_state_writes":state_writes}


def run_arm(
    label:str,
    under_relaxation:str|None,
    expected_nonmeth:int,
    libmf6:Path,
    swaplib:Path,
    frozen:dict[str,object],
    g17_trace:list[dict[str,object]],
    g17_final_head:float,
)->dict[str,object]:
    swap=Fgc44RealSwap(swaplib)
    _,_,href,origin,diag=initialize_case(
        swap,float(frozen["duration_day"]),float(frozen["predictor_qbot_cm_per_day"])
    )
    require(origin==(0,0.0,0,0.0),f"G21E {label} dirty SWAP origin")
    h=float(frozen["initial_head_m"])
    require(abs(href-h)<=1e-14,f"G21E {label} initial head drift")
    sy=0.5*float(diag["u"])
    a=float(frozen["groundwater_a_per_s"])
    b=float(frozen["groundwater_intercept"])

    require(swap.g15_trial_call_count()==0,f"G21E {label} ordinary path dirty before diagnostics")
    swap.g16_begin_session()
    require(swap.g16_counts()==(0,0,0,0),f"G21E {label} dirty G16 session")
    diagnostics=DiagnosticSession(swap,origin,a,b)

    response_statuses=[]
    accepted_trace=[]
    total_contractions=0
    settled=False
    classification="OUTER_BUDGET_EXHAUSTED"
    final_residual=None
    nonmeth=None
    kernel=None
    session=None

    with tempfile.TemporaryDirectory(prefix=f"fgc44-g21e-{label.lower()}-") as tmp:
        workdir=Path(tmp)
        build_model_variant(
            workdir,float(frozen["duration_day"]),href,
            float(frozen["groundwater_k_m_per_day"]),float(frozen["groundwater_ss_per_m"]),
            sy,float(frozen["groundwater_initial_head_bias_m"]),under_relaxation,
        )
        raw=XmiWrapper(lib_path=libmf6,working_directory=workdir)
        kernel=LifecycleCountingKernel(raw)
        publisher=Fgc34CtypesPublisher(swaplib)
        initialized=False
        try:
            raw.initialize(); initialized=True
            require("6.8.0" in raw.get_version(),f"G21E {label} wrong MODFLOW version")
            kernel.prepare_time_step(0.0)
            session=Modflow6PreparedSolveSession(kernel,"GWF_1","API_SWAP",publisher,solution_id=1)
            require(session.acquire_after_prepare_time_step()==PreparedSolveStatus.OK,session.last_error)
            require(session.open_prepared_solve()==PreparedSolveStatus.OK,session.last_error)
            require(session.accepted_xold is not None,f"G21E {label} missing XOLD")
            xold=session.accepted_xold.copy()
            nonmeth=int(round(scalar(kernel,"NONMETH")))
            require(nonmeth==expected_nonmeth,f"G21E {label} NONMETH={nonmeth} expected={expected_nonmeth}")
            binding=[Binding(7001,1,2)]

            for outer in range(1,MAX_OUTER+1):
                current_obs,current_res=diagnostics.residual(h)
                require(current_res is not None and int(current_obs["participant_status"])==0,
                        f"G21E {label} current head unavailable outer={outer}")
                if settled and abs(float(current_res))<=FLUX_TOL:
                    classification="CONVERGED"
                    final_residual=float(current_res)
                    break

                est=diagnostics.estimate_e3(h)
                require(est["classification"]=="AVAILABLE",f"G21E {label} E3 unavailable outer={outer}: {est}")
                p=float(est["slope_per_s"])
                g_current=a*h+b
                attempts=[]
                accepted=False
                for contraction in range(0,MAX_BACKTRACK+1):
                    lam=0.5**contraction
                    qref=g_current+lam*float(current_res)
                    candidate_head,mf_calls,qgw_term=settle_response(session,binding,xold,h,qref,p)
                    obs=diagnostics.observe(candidate_head)
                    status=int(obs["participant_status"])
                    response_statuses.append(status)
                    candidate_res=None
                    merit=False
                    if status==0:
                        require(bool(obs["q_available"]),f"G21E {label} status0 without q")
                        candidate_res=float(obs["q_swap_m_per_s"])-(a*candidate_head+b)
                        merit=abs(candidate_res)<=abs(float(current_res))+MERIT_ABS_TOL
                        require(abs(qgw_term-(a*candidate_head+b))<=1e-15,
                                f"G21E {label} settled groundwater response mismatch")
                    else:
                        require(not bool(obs["q_available"]),f"G21E {label} failed observation retained q")

                    attempt={
                        "lambda":lam,"head_m":candidate_head,"participant_status":status,
                        "residual_m_per_s":candidate_res,"merit_accept":bool(merit),
                        "modflow_solve_calls":mf_calls,
                        "cumulative_modflow_solve_calls":session.iteration_count,
                    }
                    attempts.append(attempt)
                    if status==0 and merit:
                        reference_head=None
                        reference_error=None
                        strict_fidelity=None
                        if outer<=len(g17_trace):
                            reference_head=float(g17_trace[outer-1]["accepted_head_m"])
                            reference_error=candidate_head-reference_head
                            strict_fidelity=abs(reference_error)<=TRAJECTORY_GATE
                        row={
                            "outer":outer,
                            "accepted_head_m":candidate_head,
                            "accepted_residual_m_per_s":candidate_res,
                            "contractions":contraction,
                            "accepted_lambda":lam,
                            "tangent_mode":str(est["mode"]),
                            "tangent_d_m":float(est["selected_d_m"]),
                            "tangent_per_s":p,
                            "g17_reference_head_m":reference_head,
                            "g17_head_error_m":reference_error,
                            "strict_trajectory_fidelity":strict_fidelity,
                            "attempts":attempts,
                        }
                        accepted_trace.append(row)
                        total_contractions+=contraction
                        h=candidate_head
                        settled=True
                        accepted=True
                        print("FGC44_G21E_OUTER_JSON="+json.dumps(
                            {"configuration":label,**row},sort_keys=True,separators=(",",":")
                        ))
                        break
                if not accepted:
                    classification="SAFEGUARD_EXHAUSTED"
                    break

            if classification=="CONVERGED":
                require(final_residual is not None,f"G21E {label} missing residual")
                require(session.finalize_prepared_solve()==PreparedSolveStatus.OK,session.last_error)
                require(kernel.finalize_solve_calls==1,f"G21E {label} finalize_solve count")
            else:
                session.invalidate_without_finalize()
                require(session.invalid,f"G21E {label} failed arm not invalidated")
            require(kernel.prepare_time_step_calls==1 and kernel.prepare_solve_calls==1,
                    f"G21E {label} repeated prepared lifecycle")
            require(kernel.finalize_time_step_calls==0,f"G21E {label} finalized timestep")
            require(np.array_equal(session.xold,xold),f"G21E {label} XOLD drift")
            raw.finalize(); initialized=False
        finally:
            if initialized:
                try: raw.finalize()
                except Exception: pass

    counts=swap.g16_counts()
    require(counts[0]==counts[1]+counts[2],f"G21E {label} G16 accounting identity")
    require(counts[1]==counts[3],f"G21E {label} G16 unique-head accounting")
    require(swap.g15_trial_call_count()==0,f"G21E {label} ordinary publication trial used")
    swap.g16_end_session()
    require(swap.state()==origin and not swap.g15_has_live_candidate(),f"G21E {label} accepted authority changed")
    require(not swap.swap_preflight() and not swap.ledger_preflight(),f"G21E {label} publication preflight leaked")

    endpoint_error=h-g17_final_head
    residual_gate=classification=="CONVERGED" and final_residual is not None and abs(final_residual)<=FLUX_TOL
    endpoint_gate=classification=="CONVERGED" and abs(endpoint_error)<=HEAD_ENDPOINT_GATE
    physical_reference_qualified=bool(residual_gate and endpoint_gate)
    strict_flags=[x["strict_trajectory_fidelity"] for x in accepted_trace if x["strict_trajectory_fidelity"] is not None]
    return {
        "configuration":label,
        "under_relaxation":"NONE" if under_relaxation=="NONE" else "MODERATE_DEFAULT",
        "nonmeth":nonmeth,
        "classification":classification,
        "physical_reference_qualified":physical_reference_qualified,
        "final_head_m":h,
        "g17_final_head_m":g17_final_head,
        "final_head_error_m":endpoint_error,
        "final_residual_m_per_s":final_residual,
        "residual_gate":bool(residual_gate),
        "endpoint_gate_5e_10":bool(endpoint_gate),
        "accepted_outer_updates":len(accepted_trace),
        "total_contractions":total_contractions,
        "response_attempt_status_topology":response_statuses,
        "accepted_trace":accepted_trace,
        "strict_trajectory_all_available_pass":all(strict_flags) if strict_flags else False,
        "prepare_time_step_calls":kernel.prepare_time_step_calls,
        "prepare_solve_calls":kernel.prepare_solve_calls,
        "modflow_solve_calls":kernel.solve_calls,
        "finalize_solve_calls":kernel.finalize_solve_calls,
        "finalize_time_step_calls":kernel.finalize_time_step_calls,
        "xold_fixed":True,
        "g16_logical_requests":counts[0],
        "g16_participant_trials":counts[1],
        "g16_cache_hits":counts[2],
        "g16_unique_heads":counts[3],
        "ordinary_publication_trials":swap.g15_trial_call_count(),
        "diagnostic_non_authority":"PASS",
    }


def main()->None:
    prereg=json.loads(PREREG.read_text())
    g21d=json.loads(G21D.read_text())
    g17=json.loads(G17.read_text())
    require(prereg["work_unit"]=="GC-FIXED-INTERFACE-G21E","wrong G21E preregistration")
    require(prereg["status"]=="PREREGISTERED_BEFORE_EXECUTION","G21E preregistration not frozen")
    require(g21d["decision"]=="QUALIFIED_DIAGNOSTIC_DELTA_BAR_DELTA_CAUSAL_SUPPORT_IN_FROZEN_REAL_FGC44_CASE",
            "G21E G21D authority drift")
    require(float(prereg["independent_reference"]["physical_head_comparison_guard_m"])==HEAD_ENDPOINT_GATE,
            "G21E endpoint guard drift")
    require(float(prereg["independent_reference"]["strict_trajectory_reference_guard_m"])==TRAJECTORY_GATE,
            "G21E trajectory guard drift")
    audit=source_ownership_audit()
    print("FGC44_G21E_SOURCE_AUDIT_JSON="+json.dumps(audit,sort_keys=True,separators=(",",":")))

    libmf6=Path(os.environ["LIBMF6"]).resolve()
    swaplib=Path(os.environ["FGC44_SWAP_LIB"]).resolve()
    require(libmf6.is_file() and swaplib.is_file(),"G21E missing live libraries")

    frozen=prereg["frozen_case"]
    g17_trace=list(json.loads((ROOT/"integration"/"research"/"GC_FIXED_INTERFACE_G21_PREREGISTRATION.json").read_text())["frozen_g17_reference"]["accepted_outer_trace"])
    g17_final=float(prereg["independent_reference"]["final_head_m"])

    standard=run_arm("STANDARD_DBD",None,3,libmf6,swaplib,frozen,g17_trace,g17_final)
    nour=run_arm("NOUR","NONE",0,libmf6,swaplib,frozen,g17_trace,g17_final)

    sp=bool(standard["physical_reference_qualified"])
    np_=bool(nour["physical_reference_qualified"])
    if sp and np_:
        comparison="BOTH_PHYSICALLY_CONVERGED"
    elif np_ and not sp:
        comparison="NOUR_ONLY_PHYSICALLY_CONVERGED"
    elif sp and not np_:
        comparison="STANDARD_ONLY_PHYSICALLY_CONVERGED"
    elif standard["classification"] in {"CONVERGED","SAFEGUARD_EXHAUSTED","OUTER_BUDGET_EXHAUSTED"} and nour["classification"] in {"CONVERGED","SAFEGUARD_EXHAUSTED","OUTER_BUDGET_EXHAUSTED"}:
        comparison="NEITHER_PHYSICALLY_CONVERGED"
    else:
        comparison="MIXED_OR_UNRESOLVED"

    summary={
        "comparison_classification":comparison,
        "standard":standard,
        "no_under_relaxation":nour,
        "modflow_solve_call_difference_nour_minus_standard":int(nour["modflow_solve_calls"])-int(standard["modflow_solve_calls"]),
        "production_configuration_selection":"NOT_MADE",
        "production_policy_claim":"NOT_MADE",
    }
    print("FGC44_G21E_SUMMARY_JSON="+json.dumps(summary,sort_keys=True,separators=(",",":")))
    print("GC_FIXED_INTERFACE_G21E_MATCHED_DYNAMIC_COMPARISON=PASS")
    print("GC_FIXED_INTERFACE_G21E_EXECUTION=PASS")


if __name__=="__main__":
    main()
