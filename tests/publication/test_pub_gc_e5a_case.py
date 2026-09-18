from __future__ import annotations

import json
import math
import os
import sys
import tempfile
import time
from dataclasses import dataclass
from pathlib import Path

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
MAX_COUPLING_OUTER=40
IQN_HISTORY=5

BASELINES={
    "B1":{"window_day":1.0e-4,"qbot_cm_per_day":1.0e-6,"J_R":-3.402833570476105e-5},
    "B3":{"window_day":1.0e-3,"qbot_cm_per_day":1.0e-4,"J_R":-2.8821767195098304e-4},
    "B4":{"window_day":1.0e-2,"qbot_cm_per_day":1.0e-6,"J_R":-1.190272325146675e-3},
}
METHODS={"FP","AITKEN","IQN_COLD","UA_FROZEN","JR_ORACLE"}

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

def emit(record:dict)->None:
    print("E5A_JSON="+json.dumps(record,sort_keys=True,separators=(",",":")))

def finite(*values:float)->bool:
    return all(math.isfinite(float(v)) for v in values)

def build_model(workdir:Path, href:float, window_day:float, sy:float)->None:
    sim=flopy.mf6.MFSimulation(sim_name="PUB_GC_E5A",version="mf6",sim_ws=str(workdir))
    flopy.mf6.ModflowTdis(sim,time_units="DAYS",nper=1,perioddata=[(window_day,1,1.0)])
    flopy.mf6.ModflowIms(
        sim,complexity="MODERATE",
        outer_dvclose=1e-11,inner_dvclose=1e-12,
        outer_maximum=100,inner_maximum=100,
    )
    gwf=flopy.mf6.ModflowGwf(sim,modelname="GWF_1",save_flows=True,newtonoptions="NEWTON")
    flopy.mf6.ModflowGwfdis(
        gwf,nlay=1,nrow=1,ncol=3,
        delr=1.0,delc=1.0,top=0.0,botm=-2.0,
    )
    flopy.mf6.ModflowGwfic(gwf,strt=href)
    flopy.mf6.ModflowGwfnpf(gwf,icelltype=1,k=1.0,save_flows=True)
    flopy.mf6.ModflowGwfsto(gwf,iconvert=1,ss=0.02,sy=sy,transient={0:True})
    flopy.mf6.ModflowGwfchd(
        gwf,
        stress_period_data={0:[
            ((0,0,0),href),
            ((0,0,2),href),
        ]},
        pname="CHD_ENDS",
    )
    flopy.mf6.ModflowGwfapi(gwf,maxbound=1,pname="API_SWAP",filename="api_swap.api")
    sim.write_simulation(silent=True)

def make_session(libmf6:Path,publisher:Fgc34CtypesPublisher,href:float,window_day:float,sy:float):
    tmp=tempfile.TemporaryDirectory(prefix="pub-gc-e5a-")
    workdir=Path(tmp.name)
    build_model(workdir,href,window_day,sy)
    raw=XmiWrapper(lib_path=libmf6,working_directory=workdir)
    raw.initialize()
    if "6.8.0" not in raw.get_version():
        raw.finalize(); tmp.cleanup()
        raise RuntimeError("wrong MODFLOW version")
    raw.prepare_time_step(0.0)
    session=Modflow6PreparedSolveSession(raw,"GWF_1","API_SWAP",publisher,solution_id=1)
    if session.acquire_after_prepare_time_step()!=PreparedSolveStatus.OK:
        raw.finalize(); tmp.cleanup()
        raise RuntimeError("MODFLOW acquire failed: "+session.last_error)
    if session.open_prepared_solve()!=PreparedSolveStatus.OK:
        raw.finalize(); tmp.cleanup()
        raise RuntimeError("MODFLOW prepare_solve failed: "+session.last_error)
    return tmp,raw,session

def make_term(head_anchor:float,q_anchor:float,slope_per_s:float)->Term:
    if not finite(head_anchor,q_anchor,slope_per_s):
        raise ValueError("nonfinite affine boundary")
    hcof=AREA_M2*DAY_TO_S*slope_per_s
    rhs=hcof*head_anchor-q_anchor*AREA_M2*DAY_TO_S
    if not finite(hcof,rhs):
        raise ValueError("nonfinite affine coefficients")
    return Term(7001,hcof,rhs)

def q_model_from_term(term:Term,head:float)->float:
    return (term.hcof_m2_per_day*head-term.rhs_m3_per_day)/(AREA_M2*DAY_TO_S)

def aitken_next_omega(prev_omega:float,prev_residual:float,residual:float)->float:
    denominator=residual-prev_residual
    floor=1024.0*np.finfo(float).eps*max(abs(residual),abs(prev_residual),1.0e-20)
    if not finite(denominator) or abs(denominator)<=floor:
        candidate=prev_omega
    else:
        candidate=-prev_omega*prev_residual/denominator
    if not finite(candidate):
        candidate=prev_omega if finite(prev_omega) else 1.0
    return min(1.5,max(-1.0,float(candidate)))

def iqn_scalar_slope(samples:list[tuple[float,float]])->float:
    if len(samples)<2:
        return 0.0
    hk,qk=samples[-1]
    previous=samples[max(0,len(samples)-1-IQN_HISTORY):-1]
    num=0.0
    den=0.0
    for hi,qi in previous:
        dh=hi-hk
        floor=1024.0*np.finfo(float).eps*max(1.0,abs(hi),abs(hk))
        if abs(dh)<=floor:
            continue
        dq=qi-qk
        if not finite(dh,dq):
            continue
        num+=dh*dq
        den+=dh*dh
    den_floor=np.finfo(float).tiny
    if not finite(num,den) or den<=den_floor:
        return 0.0
    slope=num/den
    return float(slope) if finite(slope) else 0.0

def run_method(
    method:str,
    baseline_id:str,
    sy:float,
    libmf6:Path,
    swaplib:Path,
)->dict:
    cfg=BASELINES[baseline_id]
    window_day=float(cfg["window_day"])
    qbot=float(cfg["qbot_cm_per_day"])
    jr=float(cfg["J_R"])

    swap=Fgc44RealSwap(swaplib)
    t_start=time.perf_counter()
    try:
        hcof0,rhs0,href=swap.initialize_configured(window_day,qbot)
    except RuntimeError as exc:
        return {
            "status":"SWAP_PREDICTOR_UNAVAILABLE",
            "message":str(exc),
            "baseline_id":baseline_id,
            "specific_yield":sy,
            "method":method,
            "N_predictor":1,
            "N_corrector_attempted":0,
            "N_corrector_successful":0,
            "N_MODFLOW_iteration_calls":0,
            "W_SWAP_upper":1,
            "elapsed_s":time.perf_counter()-t_start,
        }

    if not finite(hcof0,rhs0,href) or abs(hcof0)==0.0:
        raise AssertionError("invalid E5a predictor")
    origin_state=swap.state()
    if origin_state!=(0,0.0,0,0.0):
        raise AssertionError("E5a predictor changed accepted authority")

    qref=q_model_from_term(Term(7001,hcof0,rhs0),href)
    ua_slope=hcof0/(AREA_M2*DAY_TO_S)
    oracle_slope=jr/(window_day*DAY_TO_S)
    if not finite(qref,ua_slope,oracle_slope):
        raise AssertionError("invalid E5a response inputs")

    if method=="UA_FROZEN":
        head_anchor=href; q_anchor=qref; slope=ua_slope
    elif method=="JR_ORACLE":
        head_anchor=href; q_anchor=qref; slope=oracle_slope
    else:
        head_anchor=href; q_anchor=qref; slope=0.0

    aitken_omega=1.0
    previous_residual=None
    iqn_samples:list[tuple[float,float]]=[]
    trace=[]
    corrector_attempted=0
    corrector_successful=0
    mf_calls=0
    tmp=raw=session=None
    publisher=Fgc34CtypesPublisher(swaplib)
    try:
        tmp,raw,session=make_session(libmf6,publisher,href,window_day,sy)
        binding=[Binding(7001,1,2)]

        for outer in range(1,min(MAX_COUPLING_OUTER,session.max_solve_iterations)+1):
            try:
                term=make_term(head_anchor,q_anchor,slope)
            except ValueError as exc:
                return {
                    "status":"NONFINITE_UPDATE","message":str(exc),
                    "failure_stage":"boundary-update",
                    "baseline_id":baseline_id,"specific_yield":sy,"method":method,
                    "N_predictor":1,
                    "N_corrector_attempted":corrector_attempted,
                    "N_corrector_successful":corrector_successful,
                    "N_MODFLOW_iteration_calls":mf_calls,
                    "W_SWAP_upper":1+corrector_attempted,
                    "trace":trace,
                    "elapsed_s":time.perf_counter()-t_start,
                }

            status,it=session.publish_and_solve_iteration(binding,[term])
            mf_calls+=1
            if status!=PreparedSolveStatus.OK or it is None:
                return {
                    "status":"MODFLOW_ERROR","failure_stage":"modflow",
                    "message":session.last_error,
                    "baseline_id":baseline_id,"specific_yield":sy,"method":method,
                    "N_predictor":1,
                    "N_corrector_attempted":corrector_attempted,
                    "N_corrector_successful":corrector_successful,
                    "N_MODFLOW_iteration_calls":mf_calls,
                    "W_SWAP_upper":1+corrector_attempted,
                    "trace":trace,
                    "elapsed_s":time.perf_counter()-t_start,
                }

            head=float(it.head_m[1])
            qmodel=q_model_from_term(term,head)
            corrector_attempted+=1
            try:
                qswap=float(swap.trial(head))
            except RuntimeError as exc:
                if swap.state()!=origin_state:
                    raise AssertionError("failed E5a SWAP trial changed authoritative state")
                trace.append({
                    "outer":outer,"head_m":head,"q_model_m_per_s":qmodel,
                    "q_swap_m_per_s":None,"residual_m_per_s":None,
                    "slope_per_s":slope,
                    "modflow_converged":bool(it.modflow_converged),
                    "trial_status":"FAILED",
                })
                return {
                    "status":"SWAP_CORRECTOR_UNAVAILABLE","failure_stage":"swap-corrector",
                    "message":str(exc),
                    "baseline_id":baseline_id,"specific_yield":sy,"method":method,
                    "N_predictor":1,
                    "N_corrector_attempted":corrector_attempted,
                    "N_corrector_successful":corrector_successful,
                    "N_MODFLOW_iteration_calls":mf_calls,
                    "W_SWAP_upper":1+corrector_attempted,
                    "trace":trace,
                    "elapsed_s":time.perf_counter()-t_start,
                }

            corrector_successful+=1
            if swap.state()!=origin_state:
                raise AssertionError("E5a SWAP trial changed authoritative state")
            residual=qswap-qmodel
            if not finite(head,qmodel,qswap,residual,slope):
                raise AssertionError("nonfinite E5a main-loop quantity")

            step={
                "outer":outer,
                "head_m":head,
                "q_model_m_per_s":qmodel,
                "q_swap_m_per_s":qswap,
                "residual_m_per_s":residual,
                "slope_per_s":slope,
                "modflow_converged":bool(it.modflow_converged),
                "trial_status":"OK",
            }
            if method=="AITKEN":
                step["omega_used"]=aitken_omega
            trace.append(step)

            converged=bool(it.modflow_converged) and abs(residual)<=FLUX_TOL
            swap.discard()
            if swap.state()!=origin_state:
                raise AssertionError("E5a discard changed authoritative state")

            if converged:
                session.finalize_prepared_solve()
                return {
                    "status":"CONVERGED","failure_stage":"",
                    "baseline_id":baseline_id,"specific_yield":sy,"method":method,
                    "window_day":window_day,"predictor_qbot_cm_per_day":qbot,
                    "predictor_reference_head_m":href,
                    "u_A_slope_per_s":ua_slope,
                    "J_R_oracle":jr,
                    "J_R_oracle_slope_per_s":oracle_slope,
                    "outer_iterations":outer,
                    "N_predictor":1,
                    "N_corrector_attempted":corrector_attempted,
                    "N_corrector_successful":corrector_successful,
                    "N_MODFLOW_iteration_calls":mf_calls,
                    "W_SWAP_upper":1+corrector_attempted,
                    "final_head_m":head,
                    "final_q_swap_m_per_s":qswap,
                    "final_q_model_m_per_s":qmodel,
                    "final_residual_m_per_s":residual,
                    "trace":trace,
                    "elapsed_s":time.perf_counter()-t_start,
                }

            if method=="FP":
                head_anchor=head; q_anchor=qswap; slope=0.0
            elif method=="AITKEN":
                if previous_residual is None:
                    omega_next=1.0
                else:
                    omega_next=aitken_next_omega(aitken_omega,previous_residual,residual)
                q_anchor=q_anchor+omega_next*residual
                head_anchor=head
                slope=0.0
                previous_residual=residual
                aitken_omega=omega_next
                if not finite(q_anchor,aitken_omega):
                    return {
                        "status":"NONFINITE_UPDATE","failure_stage":"aitken-update",
                        "baseline_id":baseline_id,"specific_yield":sy,"method":method,
                        "N_predictor":1,"N_corrector_attempted":corrector_attempted,
                        "N_corrector_successful":corrector_successful,
                        "N_MODFLOW_iteration_calls":mf_calls,
                        "W_SWAP_upper":1+corrector_attempted,"trace":trace,
                        "elapsed_s":time.perf_counter()-t_start,
                    }
            elif method=="IQN_COLD":
                iqn_samples.append((head,qswap))
                slope=iqn_scalar_slope(iqn_samples)
                head_anchor=head; q_anchor=qswap
            elif method=="UA_FROZEN":
                head_anchor=head; q_anchor=qswap; slope=ua_slope
            elif method=="JR_ORACLE":
                head_anchor=head; q_anchor=qswap; slope=oracle_slope
            else:
                raise AssertionError("unknown E5a method")

        return {
            "status":"COUPLING_ITERATION_LIMIT","failure_stage":"coupling-iteration-limit",
            "baseline_id":baseline_id,"specific_yield":sy,"method":method,
            "N_predictor":1,
            "N_corrector_attempted":corrector_attempted,
            "N_corrector_successful":corrector_successful,
            "N_MODFLOW_iteration_calls":mf_calls,
            "W_SWAP_upper":1+corrector_attempted,
            "trace":trace,
            "elapsed_s":time.perf_counter()-t_start,
        }
    finally:
        if swap.state()!=origin_state:
            raise AssertionError("E5a method changed authoritative SWAP/ledger state")
        if raw is not None:
            try: raw.finalize()
            except Exception: pass
        if tmp is not None:
            tmp.cleanup()

def main()->None:
    baseline_id=os.environ["E5A_BASELINE_ID"]
    sy=float(os.environ["E5A_SPECIFIC_YIELD"])
    method=os.environ["E5A_METHOD"]
    libmf6=Path(os.environ["LIBMF6"]).resolve()
    swaplib=Path(os.environ["FGC44_SWAP_LIB"]).resolve()

    if baseline_id not in BASELINES:
        raise SystemExit("unknown E5a baseline")
    if method not in METHODS:
        raise SystemExit("unknown E5a method")
    if sy not in (0.02,0.15,0.30):
        raise SystemExit("unregistered E5a specific yield")

    record=run_method(method,baseline_id,sy,libmf6,swaplib)
    emit(record)

if __name__=="__main__":
    main()
