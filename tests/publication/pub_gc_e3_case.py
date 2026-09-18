from __future__ import annotations

import json
import math
import os
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path
from typing import Any

import flopy
import numpy as np
from xmipy import XmiWrapper

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/"src"/"adapter"))
sys.path.insert(0,str(ROOT/"tests"/"fgc"/"support"))

from modflow6_fgc34_ctypes_publisher import Fgc34CtypesPublisher
from modflow6_prepared_solve_session import Modflow6PreparedSolveSession, PreparedSolveStatus
from fgc44_real_swap_ctypes import Fgc44RealSwap

DAY_TO_S=86400.0
AREA_M2=1.0
FLUX_TOL=1.0e-15

@dataclass(frozen=True)
class Binding:
    groundwater_cell_id:int
    package_slot:int
    modflow_node_id:int

@dataclass(frozen=True)
class Term:
    groundwater_cell_id:int
    hcof_m2_per_day:float
    rhs_m3_per_day:float

class CountingKernel:
    def __init__(self,kernel:XmiWrapper)->None:
        self.kernel=kernel
        self.prepare_solve_calls=0
        self.solve_calls=0
        self.finalize_solve_calls=0
        self.finalize_time_step_calls=0
    def __getattr__(self,name): return getattr(self.kernel,name)
    def prepare_solve(self,solution_id:int)->None:
        self.prepare_solve_calls+=1; self.kernel.prepare_solve(solution_id)
    def solve(self,solution_id:int)->bool:
        self.solve_calls+=1; return bool(self.kernel.solve(solution_id))
    def finalize_solve(self,solution_id:int)->None:
        self.finalize_solve_calls+=1; self.kernel.finalize_solve(solution_id)
    def finalize_time_step(self)->None:
        self.finalize_time_step_calls+=1; self.kernel.finalize_time_step()

def build_model(workdir:Path, reference_head:float, window_day:float, sy:float)->None:
    sim=flopy.mf6.MFSimulation(sim_name="PUB_GC_E3",version="mf6",sim_ws=str(workdir))
    flopy.mf6.ModflowTdis(sim,time_units="DAYS",nper=1,perioddata=[(window_day,1,1.0)])
    flopy.mf6.ModflowIms(sim,complexity="MODERATE",outer_dvclose=1e-11,inner_dvclose=1e-12,
                         outer_maximum=100,inner_maximum=100)
    gwf=flopy.mf6.ModflowGwf(sim,modelname="GWF_1",save_flows=True,newtonoptions="NEWTON")
    flopy.mf6.ModflowGwfdis(gwf,nlay=1,nrow=1,ncol=3,delr=1.0,delc=1.0,top=0.0,botm=-2.0)
    flopy.mf6.ModflowGwfic(gwf,strt=reference_head)
    flopy.mf6.ModflowGwfnpf(gwf,icelltype=1,k=1.0,save_flows=True)
    flopy.mf6.ModflowGwfsto(gwf,iconvert=1,ss=0.02,sy=sy,transient={0:True})
    flopy.mf6.ModflowGwfchd(
        gwf,
        stress_period_data={0:[((0,0,0),reference_head+0.002),((0,0,2),reference_head-0.002)]},
        pname="CHD_ENDS",
    )
    flopy.mf6.ModflowGwfapi(gwf,maxbound=1,pname="API_SWAP",filename="api_swap.api")
    sim.write_simulation(silent=True)

def new_swap(swaplib:Path, window_day:float)->tuple[Fgc44RealSwap,float,float,float,dict[str,Any]]:
    swap=Fgc44RealSwap(swaplib)
    swap.set_duration(window_day)
    hcof,rhs,href=swap.initialize()
    diag=swap.e1_diagnostics()
    return swap,hcof,rhs,href,diag

def solve_fixed_boundary(
    libmf6:Path, swap:Fgc44RealSwap, hcof:float, rhs:float, href:float,
    diag:dict[str,Any], window_day:float, sy:float, mode:str
)->dict[str,Any]:
    if mode=="constant":
        qref_m3_per_day=hcof*href-rhs
        term=Term(7001,0.0,-qref_m3_per_day)
    elif mode=="affine":
        term=Term(7001,hcof,rhs)
    else:
        raise ValueError(mode)

    with tempfile.TemporaryDirectory(prefix=f"pub-gc-e3-{mode}-") as tmp:
        workdir=Path(tmp)
        build_model(workdir,href,window_day,sy)
        raw=XmiWrapper(lib_path=libmf6,working_directory=workdir)
        kernel=CountingKernel(raw)
        publisher=Fgc34CtypesPublisher(swaplib)
        initialized=False
        session=None
        try:
            raw.initialize(); initialized=True
            raw.prepare_time_step(0.0)
            session=Modflow6PreparedSolveSession(kernel,"GWF_1","API_SWAP",publisher,solution_id=1)
            if session.acquire_after_prepare_time_step()!=PreparedSolveStatus.OK:
                raise RuntimeError(session.last_error)
            if session.open_prepared_solve()!=PreparedSolveStatus.OK:
                raise RuntimeError(session.last_error)
            accepted_xold=session.accepted_xold.copy()
            binding=[Binding(7001,1,2)]
            last=None
            for outer in range(1,min(100,session.max_solve_iterations)+1):
                status,it=session.publish_and_solve_iteration(binding,[term])
                if status!=PreparedSolveStatus.OK or it is None:
                    raise RuntimeError(session.last_error or f"missing iterate {outer}")
                if not np.array_equal(it.accepted_head_old_m,accepted_xold):
                    raise RuntimeError("MODFLOW XOLD drifted")
                last=it
                if it.modflow_converged:
                    break
            if last is None or not last.modflow_converged:
                return {
                    "status":"MODFLOW_NOT_CONVERGED",
                    "modflow_solve_calls":kernel.solve_calls,
                    "predictor_hcof_m2_per_day":hcof,
                    "predictor_rhs_m3_per_day":rhs,
                    "reference_head_m":href,
                    "predictor":diag,
                }
            head=float(last.head_m[1])
            q_gw=(term.hcof_m2_per_day*head-term.rhs_m3_per_day)/(AREA_M2*DAY_TO_S)
            try:
                q_swap=swap.trial(head)
                residual=q_swap-q_gw
                swap.discard()
                trial_status="OK"
            except Exception as exc:
                q_swap=math.nan
                residual=math.nan
                trial_status=f"SWAP_TRIAL_FAIL:{type(exc).__name__}:{exc}"
            if session.finalize_prepared_solve()!=PreparedSolveStatus.OK:
                raise RuntimeError(session.last_error)
            raw.finalize(); initialized=False
            state=swap.state()
            return {
                "status":"OK" if trial_status=="OK" else trial_status,
                "head_m":head,
                "q_gw_m_per_s":q_gw,
                "q_swap_diagnostic_m_per_s":q_swap,
                "interface_residual_m_per_s":residual,
                "modflow_solve_calls":kernel.solve_calls,
                "operational_swap_window_evaluations":1,
                "evidence_only_swap_corrector_evaluations":1 if trial_status=="OK" else 0,
                "predictor_hcof_m2_per_day":hcof,
                "predictor_rhs_m3_per_day":rhs,
                "reference_head_m":href,
                "predictor":diag,
                "authority_state_after":state,
            }
        finally:
            if initialized:
                try:
                    if session is not None and session.solve_open:
                        session.finalize_prepared_solve()
                except Exception:
                    pass
                try: raw.finalize()
                except Exception: pass

def solve_strong(
    libmf6:Path, swap:Fgc44RealSwap, hcof:float, rhs:float, href:float,
    diag:dict[str,Any], window_day:float, sy:float
)->dict[str,Any]:
    origin_state=swap.state()
    with tempfile.TemporaryDirectory(prefix="pub-gc-e3-strong-") as tmp:
        workdir=Path(tmp)
        build_model(workdir,href,window_day,sy)
        raw=XmiWrapper(lib_path=libmf6,working_directory=workdir)
        kernel=CountingKernel(raw)
        publisher=Fgc34CtypesPublisher(swaplib)
        initialized=False
        session=None
        try:
            raw.initialize(); initialized=True
            raw.prepare_time_step(0.0)
            session=Modflow6PreparedSolveSession(kernel,"GWF_1","API_SWAP",publisher,solution_id=1)
            if session.acquire_after_prepare_time_step()!=PreparedSolveStatus.OK:
                raise RuntimeError(session.last_error)
            if session.open_prepared_solve()!=PreparedSolveStatus.OK:
                raise RuntimeError(session.last_error)
            accepted_xold=session.accepted_xold.copy()
            binding=[Binding(7001,1,2)]
            current_hcof=hcof
            current_rhs=rhs
            trace=[]
            final=None
            for outer in range(1,min(40,session.max_solve_iterations)+1):
                term=Term(7001,current_hcof,current_rhs)
                status,it=session.publish_and_solve_iteration(binding,[term])
                if status!=PreparedSolveStatus.OK or it is None:
                    return {
                        "status":"MODFLOW_ITERATION_FAIL",
                        "message":session.last_error,
                        "trace":trace,
                        "operational_swap_window_evaluations":1+len(trace),
                        "modflow_solve_calls":kernel.solve_calls,
                        "reference_head_m":href,
                        "predictor":diag,
                    }
                if not np.array_equal(it.accepted_head_old_m,accepted_xold):
                    raise RuntimeError("MODFLOW XOLD drifted")
                head=float(it.head_m[1])
                q_gw=(current_hcof*head-current_rhs)/(AREA_M2*DAY_TO_S)
                try:
                    q_swap=swap.trial(head)
                except Exception as exc:
                    return {
                        "status":"SWAP_TRIAL_FAIL",
                        "message":f"{type(exc).__name__}:{exc}",
                        "head_m":head,
                        "q_gw_m_per_s":q_gw,
                        "trace":trace,
                        "operational_swap_window_evaluations":1+len(trace)+1,
                        "modflow_solve_calls":kernel.solve_calls,
                        "reference_head_m":href,
                        "predictor":diag,
                    }
                residual=q_swap-q_gw
                trace.append({
                    "iteration":outer,
                    "head_m":head,
                    "q_gw_m_per_s":q_gw,
                    "q_swap_m_per_s":q_swap,
                    "residual_m_per_s":residual,
                    "modflow_converged":bool(it.modflow_converged),
                })
                if it.modflow_converged and abs(residual)<=FLUX_TOL:
                    final=trace[-1]
                    break
                if swap.state()!=origin_state:
                    raise RuntimeError("rejected corrector changed authoritative state")
                swap.discard()
                if swap.state()!=origin_state:
                    raise RuntimeError("discard changed authoritative state")
                current_rhs=current_hcof*head-q_swap*AREA_M2*DAY_TO_S

            if final is None:
                return {
                    "status":"COUPLING_NOT_CONVERGED",
                    "trace":trace,
                    "operational_swap_window_evaluations":1+len(trace),
                    "modflow_solve_calls":kernel.solve_calls,
                    "reference_head_m":href,
                    "predictor":diag,
                }
            # E3 is a convergence experiment, not a publication transaction.
            swap.discard()
            if swap.state()!=origin_state:
                raise RuntimeError("final E3 discard changed authoritative state")
            if session.finalize_prepared_solve()!=PreparedSolveStatus.OK:
                raise RuntimeError(session.last_error)
            raw.finalize(); initialized=False
            return {
                "status":"CONVERGED",
                "iterations":len(trace),
                "head_m":final["head_m"],
                "q_gw_m_per_s":final["q_gw_m_per_s"],
                "q_swap_m_per_s":final["q_swap_m_per_s"],
                "interface_residual_m_per_s":final["residual_m_per_s"],
                "trace":trace,
                "operational_swap_window_evaluations":1+len(trace),
                "modflow_solve_calls":kernel.solve_calls,
                "predictor_hcof_m2_per_day":hcof,
                "predictor_rhs_m3_per_day":rhs,
                "reference_head_m":href,
                "predictor":diag,
                "authority_state_after":swap.state(),
            }
        finally:
            if initialized:
                try:
                    if session is not None and session.solve_open:
                        session.finalize_prepared_solve()
                except Exception:
                    pass
                try: raw.finalize()
                except Exception: pass

def main()->None:
    libmf6=Path(os.environ["LIBMF6"]).resolve()
    swaplib=Path(os.environ["FGC44_SWAP_LIB"]).resolve()
    window=float(os.environ["E3_WINDOW_DAY"])
    sy=float(os.environ["E3_SY"])
    result_path=Path(os.environ["E3_RESULT_PATH"])

    treatment=os.environ["E3_TREATMENT"]
    result:dict[str,Any]={
        "schema":"pub-gc-e3-treatment-v1",
        "window_day":window,
        "window_seconds":window*DAY_TO_S,
        "specific_yield":sy,
        "treatment":treatment,
        "flux_tolerance_m_per_s":FLUX_TOL,
    }
    try:
        swap,hcof,rhs,href,diag=new_swap(swaplib,window)
        result["predictor_reference_head_m"]=href
        result["predictor_hcof_m2_per_day"]=hcof
        result["predictor_rhs_m3_per_day"]=rhs
        result["predictor"]=diag

        if treatment=="constant":
            result["outcome"]=solve_fixed_boundary(
                libmf6,swap,hcof,rhs,href,diag,window,sy,"constant"
            )
        elif treatment=="affine":
            result["outcome"]=solve_fixed_boundary(
                libmf6,swap,hcof,rhs,href,diag,window,sy,"affine"
            )
        elif treatment=="strong":
            result["outcome"]=solve_strong(
                libmf6,swap,hcof,rhs,href,diag,window,sy
            )
        else:
            raise ValueError(f"unknown treatment {treatment}")
        result["harness_status"]="OK"
    except Exception as exc:
        result["harness_status"]="ERROR"
        result["harness_error"]=f"{type(exc).__name__}:{exc}"

    result_path.parent.mkdir(parents=True,exist_ok=True)
    result_path.write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    print(json.dumps(result,sort_keys=True))

if __name__=="__main__":
    main()
