from __future__ import annotations

import json
import math
import os
import sys
import tempfile
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
    print("E3_JSON="+json.dumps(record,sort_keys=True,separators=(",",":")))

def finite(*values:float)->bool:
    return all(math.isfinite(float(v)) for v in values)

def build_model(workdir:Path, href:float, window_day:float, k_m_per_day:float, chd_offset_m:float)->None:
    sim=flopy.mf6.MFSimulation(sim_name="PUB_GC_E3",version="mf6",sim_ws=str(workdir))
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
    flopy.mf6.ModflowGwfnpf(gwf,icelltype=1,k=k_m_per_day,save_flows=True)
    flopy.mf6.ModflowGwfsto(gwf,iconvert=1,ss=0.02,sy=0.15,transient={0:True})
    flopy.mf6.ModflowGwfchd(
        gwf,
        stress_period_data={0:[
            ((0,0,0),href+chd_offset_m),
            ((0,0,2),href-chd_offset_m),
        ]},
        pname="CHD_ENDS",
    )
    flopy.mf6.ModflowGwfapi(gwf,maxbound=1,pname="API_SWAP",filename="api_swap.api")
    sim.write_simulation(silent=True)

def make_session(libmf6:Path, publisher:Fgc34CtypesPublisher, href:float, window_day:float, k:float, chd_offset_m:float):
    tmp=tempfile.TemporaryDirectory(prefix="pub-gc-e3-")
    workdir=Path(tmp.name)
    build_model(workdir,href,window_day,k,chd_offset_m)
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

def qgw_from_term(hcof:float,rhs:float,head:float)->float:
    return (hcof*head-rhs)/(AREA_M2*DAY_TO_S)

def loose_run(libmf6:Path,publisher:Fgc34CtypesPublisher,swap:Fgc44RealSwap,
              href:float,window_day:float,k:float,chd_offset_m:float,hcof:float,rhs:float,origin_state):
    tmp=raw=session=None
    try:
        tmp,raw,session=make_session(libmf6,publisher,href,window_day,k,chd_offset_m)
        binding=[Binding(7001,1,2)]
        term=Term(7001,hcof,rhs)
        final_it=None
        mf_calls=0
        for _ in range(100):
            status,it=session.publish_and_solve_iteration(binding,[term])
            mf_calls+=1
            if status!=PreparedSolveStatus.OK or it is None:
                return {"status":"MODFLOW_LOOSE_ERROR","failure_stage":"modflow-loose","modflow_iterations":mf_calls}
            final_it=it
            if it.modflow_converged:
                break
        if final_it is None or not final_it.modflow_converged:
            return {"status":"MODFLOW_LOOSE_NOT_CONVERGED","failure_stage":"modflow-loose","modflow_iterations":mf_calls}
        head=float(final_it.head_m[1])
        qgw=qgw_from_term(hcof,rhs,head)
        try:
            qswap=swap.trial(head)
        except RuntimeError as exc:
            return {
                "status":"SWAP_LOOSE_TRIAL_FAILED","failure_stage":"swap-loose-trial",
                "modflow_iterations":mf_calls,"head_m":head,"q_gw_m_per_s":qgw,
                "message":str(exc),
            }
        if swap.state()!=origin_state:
            raise AssertionError("loose SWAP trial changed authoritative state")
        residual=qswap-qgw
        swap.discard()
        if swap.state()!=origin_state:
            raise AssertionError("loose SWAP discard changed authoritative state")
        if not finite(head,qgw,qswap,residual):
            raise AssertionError("nonfinite loose measurement")
        session.finalize_prepared_solve()
        return {
            "status":"OK",
            "failure_stage":"",
            "modflow_iterations":mf_calls,
            "head_m":head,
            "q_gw_m_per_s":qgw,
            "q_swap_m_per_s":qswap,
            "residual_m_per_s":residual,
        }
    finally:
        if raw is not None:
            try: raw.finalize()
            except Exception: pass
        if tmp is not None:
            tmp.cleanup()

def iterative_run(libmf6:Path,publisher:Fgc34CtypesPublisher,swap:Fgc44RealSwap,
                  href:float,window_day:float,k:float,chd_offset_m:float,hcof:float,rhs:float,origin_state):
    tmp=raw=session=None
    try:
        tmp,raw,session=make_session(libmf6,publisher,href,window_day,k,chd_offset_m)
        binding=[Binding(7001,1,2)]
        current_hcof=hcof
        current_rhs=rhs
        last=None
        for outer in range(1,min(MAX_COUPLING_OUTER,session.max_solve_iterations)+1):
            status,it=session.publish_and_solve_iteration(
                binding,[Term(7001,current_hcof,current_rhs)]
            )
            if status!=PreparedSolveStatus.OK or it is None:
                return {
                    "status":"MODFLOW_ITERATIVE_ERROR",
                    "failure_stage":"modflow-iterative",
                    "coupling_outer_iterations":outer,
                    "message":session.last_error,
                }
            head=float(it.head_m[1])
            qgw=qgw_from_term(current_hcof,current_rhs,head)
            try:
                qswap=swap.trial(head)
            except RuntimeError as exc:
                if swap.state()!=origin_state:
                    raise AssertionError("failed SWAP trial changed authoritative state")
                return {
                    "status":"SWAP_ITERATIVE_TRIAL_FAILED",
                    "failure_stage":"swap-iterative-trial",
                    "coupling_outer_iterations":outer,
                    "head_m":head,
                    "q_gw_m_per_s":qgw,
                    "message":str(exc),
                }
            if swap.state()!=origin_state:
                raise AssertionError("iterative SWAP trial changed authoritative state")
            residual=qswap-qgw
            if not finite(head,qgw,qswap,residual):
                raise AssertionError("nonfinite iterative measurement")
            last=(outer,head,qgw,qswap,residual,bool(it.modflow_converged))
            if it.modflow_converged and abs(residual)<=FLUX_TOL:
                swap.discard()
                if swap.state()!=origin_state:
                    raise AssertionError("final E3 discard changed authoritative state")
                session.finalize_prepared_solve()
                return {
                    "status":"CONVERGED",
                    "failure_stage":"",
                    "coupling_outer_iterations":outer,
                    "head_m":head,
                    "q_gw_m_per_s":qgw,
                    "q_swap_m_per_s":qswap,
                    "residual_m_per_s":residual,
                }
            swap.discard()
            if swap.state()!=origin_state:
                raise AssertionError("iterative discard changed authoritative state")
            current_rhs=current_hcof*head-qswap*AREA_M2*DAY_TO_S

        if last is None:
            return {
                "status":"COUPLING_ITERATION_LIMIT",
                "failure_stage":"coupling-iteration-limit",
                "coupling_outer_iterations":0,
            }
        outer,head,qgw,qswap,residual,mf=last
        return {
            "status":"COUPLING_ITERATION_LIMIT",
            "failure_stage":"coupling-iteration-limit",
            "coupling_outer_iterations":outer,
            "head_m":head,
            "q_gw_m_per_s":qgw,
            "q_swap_m_per_s":qswap,
            "residual_m_per_s":residual,
            "modflow_converged_last":mf,
        }
    finally:
        if raw is not None:
            try: raw.finalize()
            except Exception: pass
        if tmp is not None:
            tmp.cleanup()

def main()->None:
    window_day=float(os.environ["E3_WINDOW_DAY"])
    qbot=float(os.environ["E3_QBOT_CM_PER_DAY"])
    k=float(os.environ["E3_K_M_PER_DAY"])
    chd_offset_m=float(os.environ.get("E3_CHD_OFFSET_M","0.002"))
    libmf6=Path(os.environ["LIBMF6"]).resolve()
    swaplib=Path(os.environ["FGC44_SWAP_LIB"]).resolve()

    record={
        "window_day":window_day,
        "predictor_qbot_cm_per_day":qbot,
        "k_m_per_day":k,
        "chd_offset_m":chd_offset_m,
    }

    swap=Fgc44RealSwap(swaplib)
    try:
        hcof,rhs,href=swap.initialize_configured(window_day,qbot)
    except RuntimeError as exc:
        record.update({
            "status":"SWAP_PREDICTOR_UNAVAILABLE",
            "failure_stage":"swap-predictor",
            "message":str(exc),
        })
        emit(record)
        return

    if not finite(hcof,rhs,href) or abs(hcof)==0.0:
        raise AssertionError("invalid configured predictor")
    origin_state=swap.state()
    if origin_state!=(0,0.0,0,0.0):
        raise AssertionError("configured case not at accepted origin")

    publisher=Fgc34CtypesPublisher(swaplib)
    record.update({
        "predictor_hcof_m2_per_day":hcof,
        "predictor_rhs_m3_per_day":rhs,
        "predictor_reference_head_m":href,
    })

    loose=loose_run(libmf6,publisher,swap,href,window_day,k,chd_offset_m,hcof,rhs,origin_state)
    record["loose"]=loose
    if loose["status"]!="OK":
        record["status"]=loose["status"]
        record["failure_stage"]=loose.get("failure_stage","")
        if swap.state()!=origin_state:
            raise AssertionError("loose failure changed authoritative state")
        emit(record)
        return

    iterative=iterative_run(libmf6,publisher,swap,href,window_day,k,chd_offset_m,hcof,rhs,origin_state)
    record["iterative"]=iterative
    record["status"]=iterative["status"]
    record["failure_stage"]=iterative.get("failure_stage","")

    if iterative["status"]=="CONVERGED":
        delta_h=float(iterative["head_m"])-float(loose["head_m"])
        delta_q=float(iterative["q_swap_m_per_s"])-float(loose["q_swap_m_per_s"])
        qscale=max(abs(float(loose["q_swap_m_per_s"])),abs(float(loose["q_gw_m_per_s"])),1e-20)
        record["delta_h_iter_minus_loose_m"]=delta_h
        record["delta_qswap_iter_minus_loose_m_per_s"]=delta_q
        record["delta_h_from_origin_loose_m"]=float(loose["head_m"])-href
        record["delta_h_from_origin_iterative_m"]=float(iterative["head_m"])-href
        record["loose_relative_flux_mismatch"]=abs(float(loose["residual_m_per_s"]))/qscale
        if abs(float(iterative["residual_m_per_s"]))>FLUX_TOL:
            raise AssertionError("case labeled converged above flux tolerance")

    if swap.state()!=origin_state:
        raise AssertionError("E3 case changed authoritative SWAP or ledger state")

    emit(record)

if __name__=="__main__":
    main()
