from __future__ import annotations

import json
import math
import os
import subprocess
import sys
import tempfile
from pathlib import Path

import numpy as np
from xmipy import XmiWrapper

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/"src"/"adapter"))
sys.path.insert(0,str(ROOT/"tests"/"fgc"))
sys.path.insert(0,str(ROOT/"tests"/"fgc"/"support"))
sys.path.insert(0,str(ROOT/"tests"/"research"))

from fgc44_real_swap_ctypes import Fgc44RealSwap
from modflow6_fgc34_ctypes_publisher import Fgc34CtypesPublisher
from modflow6_prepared_solve_session import Modflow6PreparedSolveSession,PreparedSolveStatus
from test_fgc44_real_swap_modflow_end_to_end import Binding
from test_gc_fixed_interface_fgc44_safeguarded_newton_g08 import (
    build_model,initialize_case,
)
from test_gc_fixed_interface_g17_safeguarded_orchestration import (
    DiagnosticSession,FLUX_TOL,MERIT_ABS_TOL,MAX_OUTER,MAX_BACKTRACK,
)
from test_gc_fixed_interface_g21_dynamic_response_globalization import (
    LifecycleCountingKernel,settle_response,
)
from test_gc_fixed_interface_g21d_under_relaxation_causal import scalar

PREREG=ROOT/"integration"/"research"/"GC_FIXED_INTERFACE_G23_PREREGISTRATION.json"
G08=ROOT/"integration"/"research"/"GC_FIXED_INTERFACE_G08_RESULT.json"
G21=ROOT/"integration"/"research"/"GC_FIXED_INTERFACE_G21_RESULT.json"
G21E=ROOT/"integration"/"research"/"GC_FIXED_INTERFACE_G21E_RESULT.json"
G21N=ROOT/"integration"/"research"/"GC_FIXED_INTERFACE_G21N_RESULT.json"
G08P=ROOT/"integration"/"research"/"GC_FIXED_INTERFACE_G08_PREREGISTRATION.json"
HEAD_TOL=5.0e-10
Q_REACQ_TOL=1.0e-18

def require(cond:bool,msg:str)->None:
    if not cond:
        raise AssertionError(msg)

def regime_parameters()->dict[str,dict[str,object]]:
    p=json.loads(G08P.read_text())
    return {str(x["id"]):dict(x) for x in p["groundwater_regimes"]}

def g08_authority()->tuple[dict[tuple[str,str],dict[str,object]],dict[tuple[str,str,str],dict[str,object]]]:
    g=json.loads(G08.read_text())
    reg={(str(x["case_id"]),str(x["regime_id"])):dict(x) for x in g["groundwater_regimes"]}
    p4={}
    for x in g["policy_results"]:
        if str(x["policy"])=="P4":
            p4[(str(x["case_id"]),str(x["regime_id"]),str(x["start_side"]))]=dict(x)
    return reg,p4

def publish_endpoint(swap:Fgc44RealSwap,head:float,origin:tuple[int,float,int,float],cached_q:float,duration:float)->dict[str,object]:
    require(not swap.g15_has_live_candidate(),"G23 publication began with live candidate")
    require(not swap.swap_preflight() and not swap.ledger_preflight(),"G23 publication preflight leaked before final trial")
    before=swap.g15_trial_call_count()
    status,q=swap.try_trial(head)
    require(status==0,"G23 endpoint ordinary reacquisition failed")
    require(swap.g15_trial_call_count()==before+1,"G23 endpoint reacquisition not exactly one ordinary trial")
    require(swap.g15_has_live_candidate(),"G23 endpoint trial did not retain candidate")
    require(swap.state()==origin,"G23 endpoint trial mutated accepted authority")
    require(abs(q-cached_q)<=Q_REACQ_TOL,"G23 cached versus reacquired q mismatch")
    require(swap.swap_preflight(),"G23 FMR preflight failed")
    require(not swap.ledger_preflight(),"G23 ledger preflight true before prepare")
    qdiag,bottom_exchange_cm=swap.last_trial_diagnostics()
    require(abs(qdiag-q)<=Q_REACQ_TOL,"G23 endpoint diagnostic q mismatch")
    swap.prepare_ledger()
    require(swap.ledger_preflight(),"G23 ledger prepare/preflight failed")
    require(swap.state()==origin,"G23 ledger prepare mutated accepted authority")
    swap.commit_swap()
    mid=swap.state()
    require(mid[0]==1 and math.isclose(mid[1],duration,rel_tol=0.0,abs_tol=1e-15),
            f"G23 SWAP commit state invalid {mid}")
    require(mid[2]==0 and abs(mid[3])<=1e-30,"G23 ledger committed before explicit ledger commit")
    swap.commit_ledger()
    final=swap.state()
    expected_exchange=bottom_exchange_cm*0.01
    require(final[0]==1 and math.isclose(final[1],duration,rel_tol=0.0,abs_tol=1e-15),
            f"G23 final committed SWAP state invalid {final}")
    require(final[2]==1,"G23 final ledger count invalid")
    require(math.isclose(final[3],expected_exchange,rel_tol=0.0,abs_tol=1e-18),
            "G23 ledger exchange differs from candidate bottom exchange")
    require(not swap.g15_has_live_candidate(),"G23 candidate survived final commit")
    return {
        "q_swap_m_per_s":q,
        "bottom_exchange_cm":bottom_exchange_cm,
        "expected_ledger_exchange_m":expected_exchange,
        "mid_state":list(mid),
        "final_state":list(final),
        "ordinary_trials":swap.g15_trial_call_count()-before,
    }

def run_arm(case:dict[str,object],reg_auth:dict[str,object],reg_param:dict[str,object],
            libmf6:Path,swaplib:Path)->dict[str,object]:
    cid=str(case["id"])
    duration=float(case["duration_day"])
    qbot=float(case["predictor_qbot_cm_per_day"])
    swap=Fgc44RealSwap(swaplib)
    _,_,href,origin,diag=initialize_case(swap,duration,qbot)
    require(origin==(0,0.0,0,0.0),f"G23 {cid} dirty SWAP origin")
    h=href+float(case["start_dh_m"])
    a=float(reg_auth["a_per_s"])
    b=float(reg_auth["gw_intercept"])
    sy=float(reg_auth["sy"])
    reference_root=float(reg_auth["reference_root_m"])
    require(math.isfinite(a) and a>0.0 and math.isfinite(reference_root),f"G23 {cid} invalid G08 oracle")
    require(abs(float(reg_auth["gw_fit_error_m_per_s"]))<=5e-12,f"G23 {cid} G08 groundwater oracle fit drift")

    require(swap.g15_trial_call_count()==0,f"G23 {cid} ordinary trial count dirty")
    swap.g16_begin_session()
    require(swap.g16_counts()==(0,0,0,0),f"G23 {cid} G16 session dirty")
    diagnostic=DiagnosticSession(swap,origin,a,b)
    initial_obs,initial_res=diagnostic.residual(h)
    require(int(initial_obs["participant_status"])==0 and initial_res is not None,
            f"G23 {cid} initial head not participant-admissible")
    initial_est=diagnostic.estimate_e3(h)
    require(initial_est["classification"]=="AVAILABLE",f"G23 {cid} initial E3 unavailable")

    response_statuses=[]
    accepted_trace=[]
    total_contractions=0
    max_prepared_vs_oracle_qgw_abs_m_per_s=0.0
    final_residual=None
    final_obs=None
    classification="OUTER_BUDGET_EXHAUSTED"
    settled=False

    with tempfile.TemporaryDirectory(prefix=f"fgc44-g23-{cid.lower()}-") as tmp:
        workdir=Path(tmp)
        build_model(
            workdir,duration,href,
            float(reg_param["k_m_per_day"]),float(reg_param["ss_per_m"]),sy,
            float(reg_param["initial_head_bias_m"]),
        )
        raw=XmiWrapper(lib_path=libmf6,working_directory=workdir)
        kernel=LifecycleCountingKernel(raw)
        publisher=Fgc34CtypesPublisher(swaplib)
        initialized=False
        try:
            raw.initialize(); initialized=True
            require("6.8.0" in raw.get_version(),f"G23 {cid} wrong MODFLOW version")
            kernel.prepare_time_step(0.0)
            require(kernel.prepare_time_step_calls==1,f"G23 {cid} prepare_time_step count")
            session=Modflow6PreparedSolveSession(kernel,"GWF_1","API_SWAP",publisher,solution_id=1)
            require(session.acquire_after_prepare_time_step()==PreparedSolveStatus.OK,session.last_error)
            require(session.open_prepared_solve()==PreparedSolveStatus.OK,session.last_error)
            require(kernel.prepare_solve_calls==1,f"G23 {cid} prepare_solve count")
            require(session.accepted_xold is not None,f"G23 {cid} missing XOLD")
            xold=session.accepted_xold.copy()
            nonmeth=int(round(scalar(kernel,"NONMETH")))
            require(nonmeth==3,f"G23 {cid} STANDARD solver NONMETH={nonmeth}, expected 3")
            binding=[Binding(7001,1,2)]

            for outer in range(1,MAX_OUTER+1):
                current,current_res=diagnostic.residual(h)
                require(int(current["participant_status"])==0 and current_res is not None,
                        f"G23 {cid} current head unavailable outer={outer}")
                if settled and abs(float(current_res))<=FLUX_TOL:
                    classification="CONVERGED"
                    final_residual=float(current_res)
                    final_obs=current
                    break
                est=diagnostic.estimate_e3(h)
                if est["classification"]!="AVAILABLE":
                    classification="TANGENT_UNAVAILABLE"
                    break
                p=float(est["slope_per_s"])
                g_current=a*h+b
                accepted=False
                attempts=[]
                for contraction in range(MAX_BACKTRACK+1):
                    lam=0.5**contraction
                    qref=g_current+lam*float(current_res)
                    try:
                        candidate_head,mf_calls,qgw=settle_response(session,binding,xold,h,qref,p)
                    except AssertionError as exc:
                        msg=str(exc)
                        if "MXITER" in msg or "response failed to reach MODFLOW convergence" in msg:
                            classification="MODFLOW_RESPONSE_BOUNDED_FAILURE"
                            break
                        raise
                    qgw_oracle=a*candidate_head+b
                    qgw_oracle_difference=qgw-qgw_oracle
                    max_prepared_vs_oracle_qgw_abs_m_per_s=max(
                        max_prepared_vs_oracle_qgw_abs_m_per_s,abs(qgw_oracle_difference)
                    )
                    obs=diagnostic.observe(candidate_head)
                    status=int(obs["participant_status"])
                    response_statuses.append(status)
                    cres=None
                    merit=False
                    if status==0:
                        require(bool(obs["q_available"]),f"G23 {cid} status0 without q")
                        cres=float(obs["q_swap_m_per_s"])-(a*candidate_head+b)
                        merit=abs(cres)<=abs(float(current_res))+MERIT_ABS_TOL
                        # G23 intentionally does not require the continuous prepared-solve
                        # groundwater term to reproduce the independent fresh-solve oracle
                        # along the internal path. Preserve that difference diagnostically;
                        # only the preregistered endpoint gates decide qualification.
                    else:
                        require(not bool(obs["q_available"]),f"G23 {cid} failed observation retained q")
                    attempts.append({
                        "lambda":lam,"head_m":candidate_head,"participant_status":status,
                        "residual_m_per_s":cres,"merit_accept":bool(merit),"modflow_solve_calls":mf_calls,
                        "prepared_qgw_m_per_s":qgw,"oracle_qgw_m_per_s":qgw_oracle,
                        "prepared_minus_oracle_qgw_m_per_s":qgw_oracle_difference,
                    })
                    if status==0 and merit:
                        accepted_trace.append({
                            "outer":outer,"accepted_head_m":candidate_head,
                            "accepted_residual_m_per_s":cres,"accepted_lambda":lam,
                            "contractions":contraction,"tangent_mode":str(est["mode"]),
                            "tangent_d_m":float(est["selected_d_m"]),"tangent_per_s":p,
                            "attempts":attempts,
                        })
                        total_contractions+=contraction
                        h=candidate_head
                        settled=True
                        accepted=True
                        break
                if classification=="MODFLOW_RESPONSE_BOUNDED_FAILURE":
                    break
                if not accepted:
                    classification="SAFEGUARD_EXHAUSTED"
                    break

            if classification=="CONVERGED":
                require(final_residual is not None and final_obs is not None,f"G23 {cid} converged without final observation")
                require(session.finalize_prepared_solve()==PreparedSolveStatus.OK,session.last_error)
                require(kernel.finalize_solve_calls==1,f"G23 {cid} finalize_solve count")
            else:
                session.invalidate_without_finalize()
            require(kernel.prepare_time_step_calls==1 and kernel.prepare_solve_calls==1,f"G23 {cid} repeated prepared lifecycle")
            require(kernel.finalize_time_step_calls==0,f"G23 {cid} finalized time step")
            require(np.array_equal(session.xold,xold),f"G23 {cid} XOLD drift")
            raw.finalize(); initialized=False
        finally:
            if initialized:
                raw.finalize()

    counts=swap.g16_counts()
    require(counts[0]==counts[1]+counts[2] and counts[1]==counts[3],f"G23 {cid} G16 accounting")
    require(swap.g15_trial_call_count()==0,f"G23 {cid} ordinary publication trial during diagnostics")
    require(swap.state()==origin and not swap.g15_has_live_candidate(),f"G23 {cid} diagnostics mutated authority")
    require(not swap.swap_preflight() and not swap.ledger_preflight(),f"G23 {cid} diagnostics leaked publication authority")
    cached_q=float(final_obs["q_swap_m_per_s"]) if final_obs is not None and bool(final_obs["q_available"]) else None
    swap.g16_end_session()
    require(swap.g16_counts()==(0,0,0,0),f"G23 {cid} G16 close did not clear service")

    head_error=h-reference_root
    residual_gate=classification=="CONVERGED" and final_residual is not None and abs(final_residual)<=FLUX_TOL
    endpoint_gate=classification=="CONVERGED" and abs(head_error)<=HEAD_TOL
    publication=None
    if residual_gate and endpoint_gate and cached_q is not None:
        publication=publish_endpoint(swap,h,origin,cached_q,duration)

    return {
        "id":cid,"swap_case":str(case["swap_case"]),"regime":str(case["regime"]),
        "start_side":str(case["start_side"]),"start_dh_m":float(case["start_dh_m"]),
        "classification":classification,"final_head_m":h,"reference_root_m":reference_root,
        "head_error_m":head_error,"final_residual_m_per_s":final_residual,
        "residual_gate":bool(residual_gate),"endpoint_gate":bool(endpoint_gate),
        "physical_gate":bool(residual_gate and endpoint_gate),
        "accepted_outer_updates":len(accepted_trace),"total_contractions":total_contractions,
        "response_status_topology":response_statuses,"accepted_trace":accepted_trace,
        "prepare_time_step_calls":kernel.prepare_time_step_calls,"prepare_solve_calls":kernel.prepare_solve_calls,
        "modflow_solve_calls":kernel.solve_calls,"finalize_solve_calls":kernel.finalize_solve_calls,
        "finalize_time_step_calls":kernel.finalize_time_step_calls,"xold_fixed":True,
        "g16_logical_requests":counts[0],"g16_participant_trials":counts[1],
        "g16_cache_hits":counts[2],"g16_unique_heads":counts[3],
        "diagnostic_non_authority":"PASS",
        "max_prepared_vs_oracle_qgw_abs_m_per_s":max_prepared_vs_oracle_qgw_abs_m_per_s,
        "prepared_vs_oracle_qgw_gate":"DIAGNOSTIC_ONLY_NOT_PREREGISTERED",
        "cached_final_q_m_per_s":cached_q,
        "publication":publication,
        "transaction_gate":publication is not None,
    }

def bitsame(a:float,b:float)->bool:
    return float(a).hex()==float(b).hex()

def run_case_fresh_process(case_id:str)->dict[str,object]:
    try:
        child=subprocess.run(
            [sys.executable,str(Path(__file__).resolve()),"--arm",case_id],
            check=True,capture_output=True,text=True,env=os.environ.copy(),
        )
    except subprocess.CalledProcessError as exc:
        if exc.stdout:
            print(exc.stdout,end="")
        if exc.stderr:
            print(exc.stderr,end="",file=sys.stderr)
        raise
    marker="FGC44_G23_CHILD_ARM_JSON="
    line=next((x for x in child.stdout.splitlines() if x.startswith(marker)),None)
    require(line is not None,f"G23 child marker missing for {case_id}")
    return json.loads(line[len(marker):])

def run_child_arm(case_id:str)->None:
    p=json.loads(PREREG.read_text())
    reg_param=regime_parameters()
    reg_auth,p4=g08_authority()
    case=next(dict(x) for x in p["executed_matrix"] if str(x["id"])==case_id)
    key=(str(case["swap_case"]),str(case["regime"]))
    policy=p4[(key[0],key[1],str(case["start_side"]))]
    require(str(policy["classification"])=="CONVERGED",f"G23 child ineligible arm {case_id}")
    require(float(policy["start_dh_m"])==float(case["start_dh_m"]),f"G23 child start offset drift {case_id}")
    libmf6=Path(os.environ["LIBMF6"]).resolve()
    swaplib=Path(os.environ["FGC44_SWAP_LIB"]).resolve()
    result=run_arm(case,reg_auth[key],reg_param[key[1]],libmf6,swaplib)
    print("FGC44_G23_CHILD_ARM_JSON="+json.dumps(result,sort_keys=True,separators=(",",":")))

def main()->None:
    if len(sys.argv)==3 and sys.argv[1]=="--arm":
        run_child_arm(sys.argv[2])
        return
    p=json.loads(PREREG.read_text())
    require(p["status"]=="PREREGISTERED_BEFORE_IMPLEMENTATION_AMENDED","G23 preregistration not frozen/amended")
    g08=json.loads(G08.read_text())
    g21=json.loads(G21.read_text())
    g21e=json.loads(G21E.read_text())
    g21n=json.loads(G21N.read_text())
    require(g21n["decision"]=="QUALIFIED_MIXED_PATH_AND_WITHIN_PATH_NUMERICAL_MICROSTRUCTURE","G23 G21N authority drift")
    require(g21["decision"]=="FALSIFIED_FULL_G17_PATH_EQUIVALENCE_IN_CONTINUOUS_DYNAMIC_RESPONSE_SPACE_LOOP","G23 G21 falsification authority drift")
    require(g21e["comparison"]["classification"]=="BOTH_PHYSICALLY_CONVERGED","G23 inherited hard stress not physically qualified")
    require(bool(g21e["standard_dbd"]["physical_reference_qualified"]),"G23 G21E STANDARD control drift")
    require(float(p["physical_gates"]["external_interface_residual_abs_m_per_s"])==FLUX_TOL,"G23 flux gate drift")
    require(float(p["physical_gates"]["independent_reference_head_abs_m"])==HEAD_TOL,"G23 head gate drift")

    reg_param=regime_parameters()
    reg_auth,p4=g08_authority()
    eligible={k:v for k,v in p4.items() if str(v["classification"])=="CONVERGED"}
    require(len(eligible)==21,f"G23 expected 21 eligible G08 P4 arms, got {len(eligible)}")
    matrix=list(p["executed_matrix"])
    require(len(matrix)==21,f"G23 preregistered matrix count drift {len(matrix)}")
    matrix_keys={(str(x["swap_case"]),str(x["regime"]),str(x["start_side"])) for x in matrix}
    require(matrix_keys==set(eligible),f"G23 matrix no longer equals complete G08 qualified P4 envelope")

    libmf6=Path(os.environ["LIBMF6"]).resolve()
    swaplib=Path(os.environ["FGC44_SWAP_LIB"]).resolve()
    require(libmf6.is_file() and swaplib.is_file(),"G23 missing live libraries")

    results=[]
    for case in matrix:
        key=(str(case["swap_case"]),str(case["regime"]))
        policy=p4[(key[0],key[1],str(case["start_side"]))]
        require(str(policy["classification"])=="CONVERGED",f"G23 ineligible arm {case['id']}")
        require(float(policy["start_dh_m"])==float(case["start_dh_m"]),f"G23 start offset drift {case['id']}")
        result=run_case_fresh_process(str(case["id"]))
        results.append(result)
        print("FGC44_G23_ARM_JSON="+json.dumps(result,sort_keys=True,separators=(",",":")))

    all_physical=all(bool(x["physical_gate"]) for x in results)
    all_transaction=all(bool(x["transaction_gate"]) for x in results)
    all_diag=all(x["diagnostic_non_authority"]=="PASS" for x in results)

    pairs=[]
    grouped={}
    for x in results:
        grouped.setdefault((x["swap_case"],x["regime"]),{})[x["start_side"]]=x
    for key,sides in sorted(grouped.items()):
        if "NEG" in sides and "POS" in sides:
            spread=abs(float(sides["NEG"]["final_head_m"])-float(sides["POS"]["final_head_m"]))
            ok=bool(sides["NEG"]["physical_gate"] and sides["POS"]["physical_gate"] and spread<=HEAD_TOL)
            pairs.append({"swap_case":key[0],"regime":key[1],"endpoint_spread_m":spread,"gate":ok})
    require(len(pairs)==9,f"G23 expected 9 paired scenarios, got {len(pairs)}")
    pair_gate=all(x["gate"] for x in pairs)

    replay=run_case_fresh_process("C0_MIXED_NEG")
    original=next(x for x in results if x["id"]=="C0_MIXED_NEG")
    replay_gate=(
        bitsame(float(original["final_head_m"]),float(replay["final_head_m"]))
        and bitsame(float(original["cached_final_q_m_per_s"]),float(replay["cached_final_q_m_per_s"]))
        and original["response_status_topology"]==replay["response_status_topology"]
        and original["publication"] is not None and replay["publication"] is not None
        and bitsame(float(original["publication"]["expected_ledger_exchange_m"]),float(replay["publication"]["expected_ledger_exchange_m"]))
    )

    hard_stress=(
        bool(g21e["standard_dbd"]["physical_reference_qualified"])
        and abs(float(g21e["standard_dbd"]["final_residual_m_per_s"]))<=FLUX_TOL
        and bool(g21e["standard_dbd"]["endpoint_gate_5e_10"])
        and str(g21e["gates"]["diagnostic_non_authority_both_arms"])=="PASS"
    )
    all_gate=all_physical and all_transaction and all_diag and pair_gate and replay_gate and hard_stress
    classification="QUALIFIED_ENDPOINT_MATRIX" if all_gate else "PARTIAL_ENDPOINT_ENVELOPE"

    summary={
        "classification":classification,"eligible_arm_count":len(results),
        "physical_pass_count":sum(bool(x["physical_gate"]) for x in results),
        "transaction_pass_count":sum(bool(x["transaction_gate"]) for x in results),
        "diagnostic_non_authority_pass_count":sum(x["diagnostic_non_authority"]=="PASS" for x in results),
        "paired_scenario_count":len(pairs),"paired_scenario_gate":pair_gate,"pairs":pairs,
        "replay_case":"C0_MIXED_NEG","replay_bitwise_gate":replay_gate,
        "replay":{"final_head_m":replay["final_head_m"],"cached_final_q_m_per_s":replay["cached_final_q_m_per_s"],
                  "response_status_topology":replay["response_status_topology"],
                  "ledger_exchange_m":None if replay["publication"] is None else replay["publication"]["expected_ledger_exchange_m"]},
        "inherited_g21e_hard_stress_gate":hard_stress,
        "g21_exact_path_equivalence":"FALSIFIED_PRESERVED",
        "production_change":"NONE",
    }
    print("FGC44_G23_SUMMARY_JSON="+json.dumps(summary,sort_keys=True,separators=(",",":")))
    print("GC_FIXED_INTERFACE_G23_EXECUTION=PASS")

if __name__=="__main__":
    main()
