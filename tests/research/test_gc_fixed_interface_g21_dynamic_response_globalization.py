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
from test_fgc44_real_swap_modflow_end_to_end import AREA_M2,DAY_TO_S,Binding,CountingKernel,Term
from test_gc_fixed_interface_fgc44_safeguarded_newton_g08 import build_model, initialize_case
from test_gc_fixed_interface_g17_safeguarded_orchestration import (
    DiagnosticSession,SCALES_M,REL_TOL,FLUX_TOL,MERIT_ABS_TOL,MAX_OUTER,MAX_BACKTRACK
)

PREREG=ROOT/"integration"/"research"/"GC_FIXED_INTERFACE_G21_PREREGISTRATION.json"
G20=ROOT/"integration"/"research"/"GC_FIXED_INTERFACE_G20_RESULT.json"
G17=ROOT/"integration"/"research"/"GC_FIXED_INTERFACE_G17_RESULT.json"
G11=ROOT/"integration"/"research"/"GC_FIXED_INTERFACE_G11_RESULT.json"


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


def source_ownership_audit()->dict[str,object]:
    source=Path(__file__).read_text()
    tree=ast.parse(source)
    direct=[]
    forbidden_calls=[]
    forbidden_names={
        "set_value","set_value_ptr","set_head","set_current_head","set_x",
        "restore_iterate","restore_previous_x","rollback_iteration","rollback_solve",
        "invalidate_without_finalize","open_prepared_solve_again","restart_from_xold",
    }
    for node in ast.walk(tree):
        if isinstance(node,(ast.Assign,ast.AnnAssign,ast.AugAssign)):
            targets=node.targets if isinstance(node,ast.Assign) else [node.target]
            for target in targets:
                if isinstance(target,ast.Subscript):
                    v=target.value
                    if isinstance(v,ast.Attribute) and isinstance(v.value,ast.Name):
                        if v.value.id=="session" and v.attr in {"head","xold","accepted_xold"}:
                            direct.append(f"session.{v.attr}[]")
                if isinstance(target,ast.Attribute) and isinstance(target.value,ast.Name):
                    if target.value.id=="session" and target.attr in {"head","xold","accepted_xold"}:
                        direct.append(f"session.{target.attr}")
        if isinstance(node,ast.Call) and isinstance(node.func,ast.Attribute):
            if node.func.attr in forbidden_names:
                forbidden_calls.append(node.func.attr)
    require(not direct,f"G21 direct MODFLOW state assignment found: {direct}")
    require(not forbidden_calls,f"G21 forbidden state-control call found: {forbidden_calls}")
    return {"direct_session_state_assignments":direct,"forbidden_state_control_calls":forbidden_calls}


def settle_response(
    session:Modflow6PreparedSolveSession,
    binding:list[Binding],
    xold:np.ndarray,
    h_anchor:float,
    q_reference:float,
    tangent:float,
)->tuple[float,int,float]:
    hcof=tangent*AREA_M2*DAY_TO_S
    rhs=hcof*h_anchor-q_reference*AREA_M2*DAY_TO_S
    term=[Term(7001,hcof,rhs)]
    start=session.iteration_count
    converged=None
    while session.iteration_count < session.max_solve_iterations:
        status,it=session.publish_and_solve_iteration(binding,term)
        require(status==PreparedSolveStatus.OK,session.last_error)
        require(it is not None,"G21 missing MODFLOW iteration")
        require(not session.invalid and session.solve_open and not session.finalized,
                "G21 prepared-solve lifecycle invalid during response settlement")
        require(np.array_equal(it.accepted_head_old_m,xold),"G21 XOLD drifted")
        if it.modflow_converged:
            converged=it
            break
    require(converged is not None,"G21 response failed to reach MODFLOW convergence")
    head=float(converged.head_m[1])
    qgw=(hcof*head-rhs)/(AREA_M2*DAY_TO_S)
    return head,session.iteration_count-start,float(qgw)


def main()->None:
    prereg=json.loads(PREREG.read_text())
    g20=json.loads(G20.read_text())
    g17=json.loads(G17.read_text())
    g11=json.loads(G11.read_text())
    require(prereg["work_unit"]=="GC-FIXED-INTERFACE-G21","wrong G21 preregistration")
    require(prereg["status"]=="PREREGISTERED_BEFORE_EXECUTION","G21 preregistration not frozen")
    require(g20["decision"]=="QUALIFIED_BOUNDED_CONTINUOUS_FGC38_RESPONSE_SPACE_SAFEGUARD_BRIDGE",
            "G21 parent G20 authority drift")
    require(g17["decision"]=="QUALIFIED_RESEARCH_G16_BACKED_SAFEGUARDED_ORCHESTRATION_AND_FMR_LEDGER_FINAL_HANDOFF",
            "G21 parent G17 authority drift")

    frozen=prereg["frozen_case"]
    policy=prereg["frozen_e3_p4"]
    ref=prereg["frozen_g17_reference"]
    require(tuple(float(x) for x in policy["scale_ladder_m"])==SCALES_M,"G21 E3 scale ladder drift")
    require(float(policy["relative_slope_tolerance"])==REL_TOL,"G21 E3 relative tolerance drift")
    require(float(policy["flux_tolerance_m_per_s"])==FLUX_TOL,"G21 flux tolerance drift")
    require(float(policy["merit_absolute_tolerance_m_per_s"])==MERIT_ABS_TOL,"G21 merit tolerance drift")
    require(int(policy["max_outer"])==MAX_OUTER and int(policy["max_backtrack"])==MAX_BACKTRACK,
            "G21 P4 iteration budget drift")

    g11_p4=next(x for x in g11["policy_results"] if x["policy"]=="P4_E3")
    require(len(g11_p4["trace"])==3,"G21 frozen G11 trace length drift")
    for expected,authority in zip(ref["accepted_outer_trace"],g11_p4["trace"],strict=True):
        require(int(expected["outer"])==int(authority["outer"]),"G21 outer authority drift")
        require(abs(float(expected["accepted_head_m"])-float(authority["accepted_head_m"]))<=1e-15,
                "G21 accepted-head prereg authority drift")
        require(int(expected["contractions"])==int(authority["local_contractions"]),
                "G21 local-contraction prereg authority drift")
        require(str(expected["tangent_mode"])==str(authority["tangent_mode"]),"G21 tangent-mode authority drift")
        require(float(expected["tangent_d_m"])==float(authority["tangent_d_m"]),"G21 tangent-scale authority drift")

    audit=source_ownership_audit()
    print("FGC44_G21_SOURCE_AUDIT_JSON="+json.dumps(audit,sort_keys=True,separators=(",",":")))

    libmf6=Path(os.environ["LIBMF6"]).resolve()
    swaplib=Path(os.environ["FGC44_SWAP_LIB"]).resolve()
    require(libmf6.is_file(),"missing live MODFLOW library")
    require(swaplib.is_file(),"missing FGC44 SWAP library")

    swap=Fgc44RealSwap(swaplib)
    _,_,href,origin,diag=initialize_case(
        swap,float(frozen["duration_day"]),float(frozen["predictor_qbot_cm_per_day"])
    )
    h=float(frozen["initial_head_m"])
    require(abs(href-h)<=1e-14,"G21 initial head drift")
    require(origin==(0,0.0,0,0.0),"G21 dirty SWAP origin")
    sy=0.5*float(diag["u"])
    a=float(frozen["groundwater_a_per_s"])
    b=float(frozen["groundwater_intercept"])

    swap.g16_begin_session()
    require(swap.g16_counts()==(0,0,0,0),"G21 dirty G16 session")
    diag_session=DiagnosticSession(swap,origin,a,b)

    response_attempt_status=[]
    accepted_trace=[]
    total_contractions=0
    settled=False
    final_residual=None

    with tempfile.TemporaryDirectory(prefix="fgc44-g21-mf-") as tmp:
        workdir=Path(tmp)
        build_model(
            workdir,float(frozen["duration_day"]),href,
            float(frozen["groundwater_k_m_per_day"]),float(frozen["groundwater_ss_per_m"]),sy,
            float(frozen["groundwater_initial_head_bias_m"]),
        )
        raw=XmiWrapper(lib_path=libmf6,working_directory=workdir)
        kernel=LifecycleCountingKernel(raw)
        publisher=Fgc34CtypesPublisher(swaplib)
        initialized=False
        try:
            raw.initialize()
            initialized=True
            require("6.8.0" in raw.get_version(),"G21 wrong MODFLOW version")
            kernel.prepare_time_step(0.0)
            require(kernel.prepare_time_step_calls==1,"G21 prepare_time_step count mismatch")
            session=Modflow6PreparedSolveSession(kernel,"GWF_1","API_SWAP",publisher,solution_id=1)
            require(session.acquire_after_prepare_time_step()==PreparedSolveStatus.OK,session.last_error)
            require(session.open_prepared_solve()==PreparedSolveStatus.OK,session.last_error)
            require(kernel.prepare_solve_calls==1,"G21 prepare_solve count mismatch")
            require(session.accepted_xold is not None,"G21 missing accepted XOLD")
            xold=session.accepted_xold.copy()
            binding=[Binding(7001,1,2)]

            classification="OUTER_BUDGET_EXHAUSTED"
            accepted_updates=0
            first_raw_head=None

            for outer in range(1,MAX_OUTER+1):
                current_obs,current_res=diag_session.residual(h)
                require(current_res is not None and int(current_obs["participant_status"])==0,
                        f"G21 current head unavailable outer={outer}")
                if settled and abs(current_res)<=FLUX_TOL:
                    classification="CONVERGED"
                    final_residual=float(current_res)
                    break

                est=diag_session.estimate_e3(h)
                require(est["classification"]=="AVAILABLE",f"G21 E3 unavailable outer={outer}: {est}")
                p=float(est["slope_per_s"])
                expected=ref["accepted_outer_trace"][outer-1] if outer<=len(ref["accepted_outer_trace"]) else None
                require(expected is not None,f"G21 required more accepted outers than frozen G17 trace at outer={outer}")
                require(str(est["mode"])==str(expected["tangent_mode"]),f"G21 E3 mode drift outer={outer}")
                require(float(est["selected_d_m"])==float(expected["tangent_d_m"]),f"G21 E3 scale drift outer={outer}")
                p_ref=float(expected["tangent_per_s"])
                p_rel=abs(p-p_ref)/max(abs(p),abs(p_ref))
                require(p_rel<=1e-4,f"G21 E3 slope drift outer={outer}: rel={p_rel}")

                g_current=a*h+b
                accepted=False
                attempts=[]
                for contraction in range(0,MAX_BACKTRACK+1):
                    lam=0.5**contraction
                    qref=g_current+lam*float(current_res)
                    candidate_head,mf_calls,qgw_term=settle_response(session,binding,xold,h,qref,p)
                    obs=diag_session.observe(candidate_head)
                    status=int(obs["participant_status"])
                    response_attempt_status.append(status)
                    candidate_res=None
                    merit=False
                    if status==0:
                        require(bool(obs["q_available"]),f"G21 status0 without q outer={outer} lambda={lam}")
                        candidate_res=float(obs["q_swap_m_per_s"])-(a*candidate_head+b)
                        merit=abs(candidate_res)<=abs(float(current_res))+MERIT_ABS_TOL
                        require(abs(qgw_term-(a*candidate_head+b))<=1e-15,
                                f"G21 settled groundwater response mismatch outer={outer} lambda={lam}")
                    else:
                        require(not bool(obs["q_available"]),f"G21 failed response retained q authority outer={outer} lambda={lam}")

                    attempt={
                        "outer":outer,"lambda":lam,"head_m":candidate_head,
                        "participant_status":status,"residual_m_per_s":candidate_res,
                        "merit_accept":bool(merit),"modflow_solve_calls":mf_calls,
                        "cumulative_modflow_solve_calls":session.iteration_count,
                    }
                    attempts.append(attempt)
                    print("FGC44_G21_ATTEMPT_JSON="+json.dumps(attempt,sort_keys=True,separators=(",",":")))

                    if outer==1 and contraction==0:
                        first_raw_head=candidate_head
                        require(abs(candidate_head-float(ref["first_raw_head_m"]))<=1e-12,
                                "G21 first raw response head drift")
                        require(status==int(ref["first_raw_status"])==6,"G21 first raw status drift")

                    if status==0 and merit:
                        accepted=True
                        total_contractions+=contraction
                        accepted_updates+=1
                        head_error=candidate_head-float(expected["accepted_head_m"])
                        require(abs(head_error)<=1e-12,f"G21 accepted head drift outer={outer}: {head_error}")
                        require(contraction==int(expected["contractions"]),
                                f"G21 contraction count drift outer={outer}")
                        row={
                            "outer":outer,
                            "accepted_head_m":candidate_head,
                            "reference_head_m":float(expected["accepted_head_m"]),
                            "head_error_m":head_error,
                            "accepted_residual_m_per_s":candidate_res,
                            "contractions":contraction,
                            "accepted_lambda":lam,
                            "tangent_mode":est["mode"],
                            "tangent_d_m":est["selected_d_m"],
                            "tangent_per_s":p,
                            "reference_tangent_per_s":p_ref,
                            "tangent_relative_difference":p_rel,
                            "attempts":attempts,
                        }
                        accepted_trace.append(row)
                        print("FGC44_G21_OUTER_JSON="+json.dumps(row,sort_keys=True,separators=(",",":")))
                        h=candidate_head
                        settled=True
                        break
                require(accepted,f"G21 safeguard exhausted outer={outer}")

            require(classification=="CONVERGED","G21 did not reach conjunctive convergence")
            require(final_residual is not None,"G21 missing final residual")
            require(accepted_updates==3,"G21 accepted outer update count drift")
            require(total_contractions==int(ref["total_contractions"])==2,"G21 total contractions drift")
            require(response_attempt_status==[int(x) for x in ref["response_attempt_status_topology"]],
                    f"G21 response status topology drift {response_attempt_status}")
            require(abs(h-float(ref["final_head_m"]))<=1e-12,"G21 final head drift")
            require(abs(final_residual)<=FLUX_TOL,"G21 final residual above tolerance")

            require(session.finalize_prepared_solve()==PreparedSolveStatus.OK,session.last_error)
            require(session.finalized and not session.solve_open and not session.invalid,
                    "G21 prepared solve final lifecycle invalid")
            require(kernel.prepare_time_step_calls==1 and kernel.prepare_solve_calls==1,
                    "G21 repeated prepare lifecycle")
            require(kernel.finalize_solve_calls==1,"G21 finalize_solve count mismatch")
            require(kernel.finalize_time_step_calls==0,"G21 unexpectedly finalized timestep")
            require(not session.timestep_finalized,"G21 timestep publication flag set")
            require(np.array_equal(session.xold,xold),"G21 final XOLD drift")
            raw.finalize()
            initialized=False
        finally:
            if initialized:
                try:
                    raw.finalize()
                except Exception:
                    pass

    counts=swap.g16_counts()
    require(counts[0]==counts[1]+counts[2],"G21 G16 accounting identity failed")
    require(counts[1]==counts[3],"G21 G16 physical-trial/cache identity failed")
    swap.g16_end_session()
    require(swap.state()==origin and not swap.g15_has_live_candidate(),"G21 session close changed authority")
    require(not swap.swap_preflight() and not swap.ledger_preflight(),"G21 left publication authority")

    summary={
        "classification":"CONVERGED",
        "accepted_outer_updates":len(accepted_trace),
        "total_contractions":total_contractions,
        "first_raw_head_m":first_raw_head,
        "final_head_m":h,
        "final_head_error_m":h-float(ref["final_head_m"]),
        "final_residual_m_per_s":final_residual,
        "response_attempt_status_topology":response_attempt_status,
        "prepare_time_step_calls":kernel.prepare_time_step_calls,
        "prepare_solve_calls":kernel.prepare_solve_calls,
        "total_modflow_solve_calls":kernel.solve_calls,
        "finalize_solve_calls":kernel.finalize_solve_calls,
        "finalize_time_step_calls":kernel.finalize_time_step_calls,
        "xold_fixed":"PASS",
        "g16_logical_requests":counts[0],
        "g16_participant_trials":counts[1],
        "g16_cache_hits":counts[2],
        "g16_unique_heads":counts[3],
        "diagnostic_non_authority":"PASS",
        "production_policy_claim":"NOT_MADE",
        "timestep_publication_claim":"NOT_MADE",
    }
    print("FGC44_G21_SUMMARY_JSON="+json.dumps(summary,sort_keys=True,separators=(",",":")))
    print("GC_FIXED_INTERFACE_G21_DYNAMIC_E3=PASS")
    print("GC_FIXED_INTERFACE_G21_RESPONSE_SPACE_P4=PASS")
    print("GC_FIXED_INTERFACE_G21_CONTINUOUS_PREPARED_SOLVE=PASS")
    print("GC_FIXED_INTERFACE_G21_DIAGNOSTIC_NON_AUTHORITY=PASS")
    print("GC_FIXED_INTERFACE_G21_EXECUTION=PASS")


if __name__=="__main__":
    main()
