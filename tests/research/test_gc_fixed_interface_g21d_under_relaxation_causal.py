from __future__ import annotations

import json
import math
import os
import sys
import tempfile
from pathlib import Path

import flopy
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
from test_gc_fixed_interface_g21b_prepared_solve_convergence import (
    LifecycleCountingKernel, response_term, solve_once, settle_first,
)

PREREG=ROOT/"integration"/"research"/"GC_FIXED_INTERFACE_G21D_PREREGISTRATION.json"
G21B_PREREG=ROOT/"integration"/"research"/"GC_FIXED_INTERFACE_G21B_PREREGISTRATION.json"
G21B_RESULT=ROOT/"integration"/"research"/"GC_FIXED_INTERFACE_G21B_RESULT.json"
TAIL_CALLS=12
HEAD_GATE=1.0e-12


def require(cond:bool,msg:str)->None:
    if not cond:
        raise AssertionError(msg)


def build_model_variant(
    workdir:Path,
    duration_day:float,
    href:float,
    k_m_per_day:float,
    ss_per_m:float,
    sy:float,
    initial_head_bias_m:float,
    under_relaxation:str|None,
)->None:
    center=href+initial_head_bias_m
    sim=flopy.mf6.MFSimulation(sim_name="FGC44_G21D",version="mf6",sim_ws=str(workdir))
    flopy.mf6.ModflowTdis(sim,time_units="DAYS",nper=1,perioddata=[(duration_day,1,1.0)])
    flopy.mf6.ModflowIms(
        sim,
        complexity="MODERATE",
        under_relaxation=under_relaxation,
        outer_dvclose=1e-12,
        inner_dvclose=1e-13,
        outer_maximum=100,
        inner_maximum=100,
    )
    gwf=flopy.mf6.ModflowGwf(sim,modelname="GWF_1",save_flows=True,newtonoptions="NEWTON")
    flopy.mf6.ModflowGwfdis(
        gwf,nlay=1,nrow=1,ncol=3,delr=1.0,delc=1.0,top=0.0,botm=-2.0
    )
    flopy.mf6.ModflowGwfic(gwf,strt=np.asarray([[[center,center,center]]],dtype=float))
    flopy.mf6.ModflowGwfnpf(gwf,icelltype=1,k=k_m_per_day,save_flows=True)
    flopy.mf6.ModflowGwfsto(gwf,iconvert=1,ss=ss_per_m,sy=sy,transient={0:True})
    flopy.mf6.ModflowGwfchd(
        gwf,
        stress_period_data={0:[
            ((0,0,0),center+0.002),
            ((0,0,2),center-0.002),
        ]},
        pname="CHD_ENDS",
    )
    flopy.mf6.ModflowGwfapi(gwf,maxbound=1,pname="API_SWAP",filename="api_swap.api")
    sim.write_simulation(silent=True)


def scalar(kernel:LifecycleCountingKernel,var:str)->float:
    address=kernel.get_var_address(var,"SLN_1")
    arr=np.asarray(kernel.get_value_ptr(address))
    require(arr.size>=1,f"G21D missing scalar {var}")
    return float(arr.reshape(-1)[0])


def run_arm(
    label:str,
    libmf6:Path,
    swaplib:Path,
    case:dict[str,float],
    outer1:dict[str,object],
    outer2:dict[str,float],
    sy:float,
    history:bool,
    under_relaxation:str|None,
)->dict[str,object]:
    with tempfile.TemporaryDirectory(prefix=f"fgc44-g21d-{label.lower()}-") as tmp:
        workdir=Path(tmp)
        build_model_variant(
            workdir,case["duration_day"],case["href"],case["k_m_per_day"],
            case["ss_per_m"],sy,case["bias_m"],under_relaxation
        )
        raw=XmiWrapper(lib_path=libmf6,working_directory=workdir)
        kernel=LifecycleCountingKernel(raw)
        publisher=Fgc34CtypesPublisher(swaplib)
        initialized=False
        try:
            raw.initialize(); initialized=True
            require("6.8.0" in raw.get_version(),"G21D wrong MODFLOW version")
            kernel.prepare_time_step(0.0)
            session=Modflow6PreparedSolveSession(kernel,"GWF_1","API_SWAP",publisher,solution_id=1)
            require(session.acquire_after_prepare_time_step()==PreparedSolveStatus.OK,session.last_error)
            require(session.open_prepared_solve()==PreparedSolveStatus.OK,session.last_error)
            require(session.accepted_xold is not None,"G21D accepted XOLD missing")
            xold=session.accepted_xold.copy()
            nonmeth=int(round(scalar(kernel,"NONMETH")))
            theta=scalar(kernel,"THETA")
            akappa=scalar(kernel,"AKAPPA")
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
                    history_rows.append({
                        "lambda":lam,
                        "head_m":hh,
                        "solve_calls":calls,
                        "standard_reference_head_m":expected[index],
                        "difference_from_standard_reference_m":hh-expected[index],
                    })

            hcof,rhs=response_term(
                float(outer2["anchor_head_m"]),
                float(outer2["qref_m_per_s"]),
                float(outer2["tangent_per_s"]),
            )
            rows=[]
            first_convergence=None
            for local_call in range(1,TAIL_CALLS+1):
                row=solve_once(session,binding,xold,hcof,rhs)
                row["tail_call"]=local_call
                row["error_to_frozen_fresh_reference_m"]=float(row["head_m"])-float(outer2["fresh_reference_head_m"])
                rows.append(row)
                if first_convergence is None and bool(row["modflow_converged"]):
                    first_convergence=local_call
            require(first_convergence is not None,f"G21D {label} no convergence in fixed tail")
            require(np.array_equal(session.xold,xold),f"G21D {label} XOLD drift")
            require(session.hcof is not None and session.rhs is not None,f"G21D {label} missing API views")
            require(float(session.hcof[0])==hcof and float(session.rhs[0])==rhs,
                    f"G21D {label} fixed response drift")
            require(kernel.prepare_time_step_calls==1 and kernel.prepare_solve_calls==1,
                    f"G21D {label} repeated prepared lifecycle")
            require(session.finalize_prepared_solve()==PreparedSolveStatus.OK,session.last_error)
            require(kernel.finalize_solve_calls==1 and kernel.finalize_time_step_calls==0,
                    f"G21D {label} finalization boundary drift")
            result={
                "label":label,
                "history":history_rows,
                "nonmeth":nonmeth,
                "theta":theta,
                "akappa":akappa,
                "first_convergence_call":int(first_convergence),
                "first_convergence_head_m":float(rows[first_convergence-1]["head_m"]),
                "call12_head_m":float(rows[-1]["head_m"]),
                "hcof_m2_per_day":hcof,
                "rhs_m3_per_day":rhs,
                "hcof_hex":float(hcof).hex(),
                "rhs_hex":float(rhs).hex(),
                "xold_hex":[float(x).hex() for x in xold],
                "xold_bitwise_fixed":True,
                "prepare_time_step_calls":kernel.prepare_time_step_calls,
                "prepare_solve_calls":kernel.prepare_solve_calls,
                "total_solve_calls":kernel.solve_calls,
                "finalize_solve_calls":kernel.finalize_solve_calls,
                "finalize_time_step_calls":kernel.finalize_time_step_calls,
                "tail_rows":rows,
            }
            print("FGC44_G21D_ARM_JSON="+json.dumps(result,sort_keys=True,separators=(",",":")))
            raw.finalize(); initialized=False
            return result
        finally:
            if initialized:
                try: raw.finalize()
                except Exception: pass


def pair_summary(name:str,fresh:dict[str,object],history:dict[str,object])->dict[str,object]:
    require(fresh["hcof_hex"]==history["hcof_hex"] and fresh["rhs_hex"]==history["rhs_hex"],
            f"G21D {name} FRESH/HISTORY response mismatch")
    require(fresh["xold_hex"]==history["xold_hex"],f"G21D {name} accepted XOLD mismatch")
    return {
        "configuration":name,
        "fresh_nonmeth":int(fresh["nonmeth"]),
        "history_nonmeth":int(history["nonmeth"]),
        "fresh_first_convergence_call":int(fresh["first_convergence_call"]),
        "history_first_convergence_call":int(history["first_convergence_call"]),
        "fresh_call12_head_m":float(fresh["call12_head_m"]),
        "history_call12_head_m":float(history["call12_head_m"]),
        "history_minus_fresh_call12_m":float(history["call12_head_m"])-float(fresh["call12_head_m"]),
        "hcof_hex":fresh["hcof_hex"],
        "rhs_hex":fresh["rhs_hex"],
    }


def main()->None:
    prereg=json.loads(PREREG.read_text())
    parent_prereg=json.loads(G21B_PREREG.read_text())
    parent_result=json.loads(G21B_RESULT.read_text())
    require(prereg["work_unit"]=="GC-FIXED-INTERFACE-G21D","wrong G21D preregistration")
    require(prereg["status"]=="PREREGISTERED_BEFORE_EXECUTION_AMENDED","G21D amended preregistration not frozen")
    require(parent_result["decision"]=="QUALIFIED_DIAGNOSTIC_PERSISTENT_PREPARED_SOLVE_PATH_MEMORY",
            "G21D G21B authority drift")
    require(TAIL_CALLS==int(prereg["frozen_case"]["tail_calls"])==int(parent_prereg["frozen_case"]["tail_calls"]),
            "G21D tail-length authority drift")

    frozen=parent_prereg["frozen_case"]
    outer1=parent_prereg["frozen_outer1_response_history"]
    outer2=parent_prereg["frozen_outer2_response"]

    libmf6=Path(os.environ["LIBMF6"]).resolve()
    swaplib=Path(os.environ["FGC44_SWAP_LIB"]).resolve()
    require(libmf6.is_file() and swaplib.is_file(),"G21D missing live libraries")

    swap=Fgc44RealSwap(swaplib)
    _,_,href,origin,diag=initialize_case(
        swap,float(frozen["duration_day"]),float(frozen["predictor_qbot_cm_per_day"])
    )
    require(origin==(0,0.0,0,0.0),"G21D dirty SWAP origin")
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
    outer2n={
        "anchor_head_m":float(outer2["anchor_head_m"]),
        "qref_m_per_s":float(outer2["qref_m_per_s"]),
        "tangent_per_s":float(outer2["tangent_per_s"]),
        "fresh_reference_head_m":float(outer2["fresh_reference_head_m"]),
    }

    std_fresh=run_arm("STANDARD_FRESH",libmf6,swaplib,case,outer1,outer2n,sy,False,None)
    std_hist=run_arm("STANDARD_HISTORY",libmf6,swaplib,case,outer1,outer2n,sy,True,None)
    nour_fresh=run_arm("NOUR_FRESH",libmf6,swaplib,case,outer1,outer2n,sy,False,"NONE")
    nour_hist=run_arm("NOUR_HISTORY",libmf6,swaplib,case,outer1,outer2n,sy,True,"NONE")

    standard=pair_summary("STANDARD_DBD",std_fresh,std_hist)
    nour=pair_summary("NOUR",nour_fresh,nour_hist)
    require(int(standard["fresh_nonmeth"])==3 and int(standard["history_nonmeth"])==3,
            "G21D standard pair is not NONMETH=3")
    require(int(nour["fresh_nonmeth"])==0 and int(nour["history_nonmeth"])==0,
            "G21D no-UR pair is not NONMETH=0")
    require(standard["hcof_hex"]==nour["hcof_hex"] and standard["rhs_hex"]==nour["rhs_hex"],
            "G21D intervention changed outer-2 response")

    expected=float(prereg["frozen_case"]["standard_expected_history_minus_fresh_call12_m"])
    std_offset=float(standard["history_minus_fresh_call12_m"])
    nour_offset=float(nour["history_minus_fresh_call12_m"])
    require(abs(std_offset-expected)<=HEAD_GATE,
            f"G21D standard arm no longer reproduces G21B offset: {std_offset-expected}")

    nour_fresh_root_error=abs(float(nour_fresh["call12_head_m"])-float(outer2n["fresh_reference_head_m"]))
    nour_outer1_root_errors=[
        abs(float(row["difference_from_standard_reference_m"])) for row in nour_hist["history"]
    ]
    nour_max_outer1_root_error=max(nour_outer1_root_errors) if nour_outer1_root_errors else 0.0
    root_comparable=(nour_fresh_root_error<=HEAD_GATE and nour_max_outer1_root_error<=HEAD_GATE)

    reduction=abs(std_offset)-abs(nour_offset)
    reduction_fraction=reduction/abs(std_offset) if std_offset!=0.0 else 0.0
    if not root_comparable:
        classification="MIXED_OR_UNRESOLVED"
    elif abs(nour_offset)<=HEAD_GATE:
        classification="DELTA_BAR_DELTA_CAUSAL_SUPPORT"
    elif reduction_fraction>=0.90:
        classification="DELTA_BAR_DELTA_CONTRIBUTES_BUT_NOT_SUFFICIENT"
    else:
        classification="DELTA_BAR_DELTA_NOT_DOMINANT"

    summary={
        "classification":classification,
        "standard":standard,
        "no_under_relaxation":nour,
        "absolute_offset_reduction_m":reduction,
        "absolute_offset_reduction_fraction":reduction_fraction,
        "nour_fresh_root_error_m":nour_fresh_root_error,
        "nour_outer1_root_errors_m":nour_outer1_root_errors,
        "nour_max_outer1_root_error_m":nour_max_outer1_root_error,
        "root_comparability_at_strict_scale":root_comparable,
        "strict_path_scale_m":HEAD_GATE,
        "standard_g21b_reproduction":"PASS",
        "xold_fixed_all_arms":"PASS",
        "outer2_response_identical_all_arms":"PASS",
        "mid_solve_state_mutation":False,
        "finalize_time_step_calls_total":0,
        "production_configuration_claim":"NONE",
    }
    print("FGC44_G21D_SUMMARY_JSON="+json.dumps(summary,sort_keys=True,separators=(",",":")))
    print("GC_FIXED_INTERFACE_G21D_MATCHED_CAUSAL_ISOLATION=PASS")
    print("GC_FIXED_INTERFACE_G21D_EXECUTION=PASS")


if __name__=="__main__":
    main()
