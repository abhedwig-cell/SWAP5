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
from test_gc_fixed_interface_fgc44_safeguarded_newton_g08 import build_model, initialize_case

PREREG=ROOT/"integration"/"research"/"GC_FIXED_INTERFACE_G21B_PREREGISTRATION.json"
G21A=ROOT/"integration"/"research"/"GC_FIXED_INTERFACE_G21A_RESULT.json"

TAIL_CALLS=12
HEAD_GATE=1.0e-12


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


def response_term(anchor:float,qref:float,p:float)->tuple[float,float]:
    hcof=p*AREA_M2*DAY_TO_S
    rhs=hcof*anchor-qref*AREA_M2*DAY_TO_S
    return float(hcof),float(rhs)


def solve_once(session:Modflow6PreparedSolveSession,binding:list[Binding],xold:np.ndarray,
               hcof:float,rhs:float)->dict[str,object]:
    status,it=session.publish_and_solve_iteration(binding,[Term(7001,hcof,rhs)])
    require(status==PreparedSolveStatus.OK,session.last_error)
    require(it is not None,"G21B missing MODFLOW iteration")
    require(np.array_equal(it.accepted_head_old_m,xold),"G21B accepted XOLD drift")
    require(session.hcof is not None and session.rhs is not None,"G21B package response view missing")
    require(float(session.hcof[0])==hcof,"G21B HCOF changed inside fixed response tail")
    require(float(session.rhs[0])==rhs,"G21B RHS changed inside fixed response tail")
    return {
        "cumulative_iteration":int(session.iteration_count),
        "head_m":float(it.head_m[1]),
        "head_vector_m":[float(x) for x in it.head_m],
        "modflow_converged":bool(it.modflow_converged),
    }


def settle_first(session:Modflow6PreparedSolveSession,binding:list[Binding],xold:np.ndarray,
                 anchor:float,qref:float,p:float)->tuple[float,int]:
    hcof,rhs=response_term(anchor,qref,p)
    start=session.iteration_count
    while session.iteration_count<session.max_solve_iterations:
        row=solve_once(session,binding,xold,hcof,rhs)
        if bool(row["modflow_converged"]):
            return float(row["head_m"]),session.iteration_count-start
    raise AssertionError("G21B response did not reach first convergence")


def fixed_tail(session:Modflow6PreparedSolveSession,binding:list[Binding],xold:np.ndarray,
               anchor:float,qref:float,p:float,reference_head:float)->dict[str,object]:
    hcof,rhs=response_term(anchor,qref,p)
    rows=[]
    first_convergence_call=None
    require(session.head is not None,"G21B missing pre-tail head vector")
    previous_vector=np.asarray(session.head,dtype=float).copy()
    for local_call in range(1,TAIL_CALLS+1):
        row=solve_once(session,binding,xold,hcof,rhs)
        current_vector=np.asarray(row["head_vector_m"],dtype=float)
        row["tail_call"]=local_call
        row["error_to_fresh_reference_m"]=float(row["head_m"])-reference_head
        row["max_abs_head_vector_increment_m"]=float(np.max(np.abs(current_vector-previous_vector)))
        previous_vector=current_vector.copy()
        rows.append(row)
        if first_convergence_call is None and bool(row["modflow_converged"]):
            first_convergence_call=local_call
    require(first_convergence_call is not None,"G21B fixed response never reported MODFLOW convergence")
    return {
        "hcof_m2_per_day":hcof,
        "rhs_m3_per_day":rhs,
        "first_convergence_call":int(first_convergence_call),
        "first_convergence_head_m":float(rows[first_convergence_call-1]["head_m"]),
        "first_convergence_error_m":float(rows[first_convergence_call-1]["error_to_fresh_reference_m"]),
        "final_head_m":float(rows[-1]["head_m"]),
        "final_error_m":float(rows[-1]["error_to_fresh_reference_m"]),
        "max_post_response_head_vector_increment_m":max(float(x["max_abs_head_vector_increment_m"]) for x in rows),
        "hcof_hex":float(hcof).hex(),
        "rhs_hex":float(rhs).hex(),
        "rows":rows,
    }


def run_arm(label:str,libmf6:Path,swaplib:Path,case:dict[str,float],
            outer1:dict[str,object],outer2:dict[str,float],sy:float,history:bool)->dict[str,object]:
    with tempfile.TemporaryDirectory(prefix=f"fgc44-g21b-{label.lower()}-") as tmp:
        workdir=Path(tmp)
        build_model(
            workdir,case["duration_day"],case["href"],case["k_m_per_day"],
            case["ss_per_m"],sy,case["bias_m"]
        )
        raw=XmiWrapper(lib_path=libmf6,working_directory=workdir)
        kernel=LifecycleCountingKernel(raw)
        publisher=Fgc34CtypesPublisher(swaplib)
        initialized=False
        try:
            raw.initialize(); initialized=True
            require("6.8.0" in raw.get_version(),"G21B wrong MODFLOW version")
            kernel.prepare_time_step(0.0)
            session=Modflow6PreparedSolveSession(kernel,"GWF_1","API_SWAP",publisher,solution_id=1)
            require(session.acquire_after_prepare_time_step()==PreparedSolveStatus.OK,session.last_error)
            require(session.open_prepared_solve()==PreparedSolveStatus.OK,session.last_error)
            require(session.accepted_xold is not None,"G21B accepted XOLD missing")
            xold=session.accepted_xold.copy()
            binding=[Binding(7001,1,2)]
            history_rows=[]

            if history:
                h0=float(outer1["anchor_head_m"])
                p0=float(outer1["tangent_per_s"])
                r0=float(outer1["current_residual_m_per_s"])
                g0=float(case["a_per_s"])*h0+float(case["b"])
                expected=[float(x) for x in outer1["expected_settled_heads_m"]]
                for index,lam in enumerate([float(x) for x in outer1["lambda_sequence"]]):
                    qref=g0+lam*r0
                    hh,calls=settle_first(session,binding,xold,h0,qref,p0)
                    error=hh-expected[index]
                    require(abs(error)<=HEAD_GATE,f"G21B history lambda {lam} replay drift {error}")
                    history_rows.append({"lambda":lam,"head_m":hh,"first_convergence_calls":calls,
                                         "reference_head_m":expected[index],"error_m":error})

            tail=fixed_tail(
                session,binding,xold,
                float(outer2["anchor_head_m"]),float(outer2["qref_m_per_s"]),
                float(outer2["tangent_per_s"]),float(outer2["fresh_reference_head_m"])
            )
            require(kernel.prepare_time_step_calls==1 and kernel.prepare_solve_calls==1,
                    "G21B repeated prepared-solve lifecycle")
            require(np.array_equal(session.xold,xold),"G21B XOLD changed at end of tail")
            require(session.finalize_prepared_solve()==PreparedSolveStatus.OK,session.last_error)
            require(kernel.finalize_solve_calls==1,"G21B finalize_solve count mismatch")
            require(kernel.finalize_time_step_calls==0 and not session.timestep_finalized,
                    "G21B unexpectedly finalized MODFLOW timestep")
            result={
                "label":label,
                "history":history_rows,
                "prepare_time_step_calls":kernel.prepare_time_step_calls,
                "prepare_solve_calls":kernel.prepare_solve_calls,
                "total_solve_calls":kernel.solve_calls,
                "finalize_solve_calls":kernel.finalize_solve_calls,
                "finalize_time_step_calls":kernel.finalize_time_step_calls,
                "xold_bitwise_fixed":bool(np.array_equal(session.xold,xold)),
                "tail":tail,
            }
            raw.finalize(); initialized=False
            return result
        finally:
            if initialized:
                try: raw.finalize()
                except Exception: pass


def main()->None:
    prereg=json.loads(PREREG.read_text())
    g21a=json.loads(G21A.read_text())
    require(prereg["work_unit"]=="GC-FIXED-INTERFACE-G21B","wrong G21B preregistration")
    require(prereg["status"]=="PREREGISTERED_BEFORE_EXECUTION","G21B preregistration not frozen")
    require(g21a["decision"]=="QUALIFIED_DIAGNOSTIC_PREPARED_SOLVE_PATH_DOMINATES_G21_OUTER2_DIVERGENCE",
            "G21B parent G21A authority drift")
    require(TAIL_CALLS==12,"G21B tail length drift")

    frozen=prereg["frozen_case"]
    outer1=prereg["frozen_outer1_response_history"]
    outer2=prereg["frozen_outer2_response"]
    require(float(outer2["first_convergence_path_effect_m"])>HEAD_GATE,
            "G21B parent path effect is not above diagnostic threshold")

    libmf6=Path(os.environ["LIBMF6"]).resolve()
    swaplib=Path(os.environ["FGC44_SWAP_LIB"]).resolve()
    require(libmf6.is_file() and swaplib.is_file(),"G21B missing live libraries")

    swap=Fgc44RealSwap(swaplib)
    _,_,href,origin,diag=initialize_case(
        swap,float(frozen["duration_day"]),float(frozen["predictor_qbot_cm_per_day"])
    )
    require(origin==(0,0.0,0,0.0),"G21B dirty SWAP origin")
    sy=0.5*float(diag["u"])
    case={
        "duration_day":float(frozen["duration_day"]),
        "href":float(href),
        "k_m_per_day":float(frozen["groundwater_k_m_per_day"]),
        "ss_per_m":float(frozen["groundwater_ss_per_m"]),
        "bias_m":float(frozen["groundwater_initial_head_bias_m"]),
        "a_per_s":float(frozen["groundwater_a_per_s"]),
        "b":float(frozen["groundwater_intercept"]),
    }

    outer2_numeric={
        "anchor_head_m":float(outer2["anchor_head_m"]),
        "qref_m_per_s":float(outer2["qref_m_per_s"]),
        "tangent_per_s":float(outer2["tangent_per_s"]),
        "fresh_reference_head_m":float(outer2["fresh_reference_head_m"]),
    }

    fresh=run_arm("FRESH",libmf6,swaplib,case,outer1,outer2_numeric,sy,False)
    history=run_arm("HISTORY",libmf6,swaplib,case,outer1,outer2_numeric,sy,True)

    require(abs(float(fresh["tail"]["first_convergence_head_m"])-float(outer2["fresh_reference_head_m"]))<=HEAD_GATE,
            "G21B fresh first-converged head drift")
    require(abs(float(history["tail"]["first_convergence_head_m"])-float(outer2["first_continuous_convergence_head_m"]))<=HEAD_GATE,
            "G21B history first-converged head drift")
    require(int(history["tail"]["first_convergence_call"])==int(outer2["first_convergence_solve_calls"]),
            "G21B history first-convergence call count drift")

    for arm in (fresh,history):
        print("FGC44_G21B_ARM_JSON="+json.dumps(arm,sort_keys=True,separators=(",",":")))
        for row in arm["tail"]["rows"]:
            marker={"arm":arm["label"],**row}
            print("FGC44_G21B_TAIL_JSON="+json.dumps(marker,sort_keys=True,separators=(",",":")))

    require(fresh["tail"]["hcof_hex"]==history["tail"]["hcof_hex"] and
            fresh["tail"]["rhs_hex"]==history["tail"]["rhs_hex"],
            "G21B fresh/history outer-2 response terms are not bitwise identical")
    matched=[]
    for frow,hrow in zip(fresh["tail"]["rows"],history["tail"]["rows"],strict=True):
        require(int(frow["tail_call"])==int(hrow["tail_call"]),"G21B matched tail index drift")
        m={
            "tail_call":int(frow["tail_call"]),
            "fresh_head_m":float(frow["head_m"]),
            "history_head_m":float(hrow["head_m"]),
            "history_minus_fresh_head_m":float(hrow["head_m"])-float(frow["head_m"]),
            "fresh_error_to_reference_m":float(frow["error_to_fresh_reference_m"]),
            "history_error_to_reference_m":float(hrow["error_to_fresh_reference_m"]),
            "fresh_converged":bool(frow["modflow_converged"]),
            "history_converged":bool(hrow["modflow_converged"]),
            "fresh_head_vector_increment_m":float(frow["max_abs_head_vector_increment_m"]),
            "history_head_vector_increment_m":float(hrow["max_abs_head_vector_increment_m"]),
        }
        matched.append(m)
        print("FGC44_G21B_MATCHED_JSON="+json.dumps(m,sort_keys=True,separators=(",",":")))

    fresh_final=float(fresh["tail"]["final_head_m"])
    history_final=float(history["tail"]["final_head_m"])
    reference=float(outer2["fresh_reference_head_m"])
    history_first_error=float(history["tail"]["first_convergence_error_m"])
    history_final_error=history_final-reference
    final_cross=history_final-fresh_final

    if abs(history_first_error)>HEAD_GATE and abs(history_final_error)<=HEAD_GATE and abs(final_cross)<=HEAD_GATE:
        classification="FIRST_CONVERGENCE_TOLERANCE_DOMINATED"
    elif abs(history_final_error)>HEAD_GATE and abs(final_cross)>HEAD_GATE:
        classification="PERSISTENT_PREPARED_PATH"
    else:
        classification="MIXED_OR_OTHER"

    summary={
        "classification":classification,
        "tail_calls":TAIL_CALLS,
        "fresh_first_convergence_call":int(fresh["tail"]["first_convergence_call"]),
        "fresh_first_convergence_head_m":float(fresh["tail"]["first_convergence_head_m"]),
        "fresh_final_head_m":fresh_final,
        "fresh_final_error_to_reference_m":fresh_final-reference,
        "history_first_convergence_call":int(history["tail"]["first_convergence_call"]),
        "history_first_convergence_head_m":float(history["tail"]["first_convergence_head_m"]),
        "history_first_error_to_reference_m":history_first_error,
        "history_final_head_m":history_final,
        "history_final_error_to_reference_m":history_final_error,
        "final_history_minus_fresh_m":final_cross,
        "path_effect_below_1e_12_by_call_12":abs(history_final_error)<=HEAD_GATE and abs(final_cross)<=HEAD_GATE,
        "fresh_total_solve_calls":int(fresh["total_solve_calls"]),
        "history_total_solve_calls":int(history["total_solve_calls"]),
        "xold_fixed_both":bool(fresh["xold_bitwise_fixed"]) and bool(history["xold_bitwise_fixed"]),
        "finalize_time_step_calls_total":int(fresh["finalize_time_step_calls"])+int(history["finalize_time_step_calls"]),
        "fresh_max_head_vector_increment_m":float(fresh["tail"]["max_post_response_head_vector_increment_m"]),
        "history_max_head_vector_increment_m":float(history["tail"]["max_post_response_head_vector_increment_m"]),
        "matched_tail":matched,
        "coupling_policy_claim":"NONE_DIAGNOSTIC_ONLY",
    }
    print("FGC44_G21B_SUMMARY_JSON="+json.dumps(summary,sort_keys=True,separators=(",",":")))
    print("GC_FIXED_INTERFACE_G21B_FIXED_RESPONSE_CONTINUATION=PASS")
    print("GC_FIXED_INTERFACE_G21B_EXECUTION=PASS")


if __name__=="__main__":
    main()
