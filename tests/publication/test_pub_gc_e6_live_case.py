from __future__ import annotations

import json, math, os, sys, tempfile
from dataclasses import dataclass
from pathlib import Path

import flopy
from xmipy import XmiWrapper

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/"src"/"adapter"))
sys.path.insert(0,str(ROOT/"tests"/"publication"))
sys.path.insert(0,str(ROOT/"tests"/"fgc"/"support"))

from modflow6_fgc34_ctypes_publisher import Fgc34CtypesPublisher
from modflow6_prepared_solve_session import Modflow6PreparedSolveSession, PreparedSolveStatus
from pub_gc_e6_ctypes import E6ActiveDrainageSwap

DAY_TO_S=86400.0
AREA_M2=1.0
WINDOW_DAY=1.0e-2
FLUX_TOL=1.0e-15
MAX_OUTER=40

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

def build_model(workdir:Path, href:float, sy:float)->None:
    sim=flopy.mf6.MFSimulation(sim_name="PUB_GC_E6",version="mf6",sim_ws=str(workdir))
    flopy.mf6.ModflowTdis(sim,time_units="DAYS",nper=1,perioddata=[(WINDOW_DAY,1,1.0)])
    flopy.mf6.ModflowIms(
        sim,complexity="MODERATE",
        outer_dvclose=1e-11,inner_dvclose=1e-12,
        outer_maximum=100,inner_maximum=100,
    )
    gwf=flopy.mf6.ModflowGwf(sim,modelname="GWF_1",save_flows=True,newtonoptions="NEWTON")
    flopy.mf6.ModflowGwfdis(gwf,nlay=1,nrow=1,ncol=3,delr=1.0,delc=1.0,top=0.0,botm=-2.0)
    flopy.mf6.ModflowGwfic(gwf,strt=href)
    flopy.mf6.ModflowGwfnpf(gwf,icelltype=1,k=1.0,save_flows=True)
    flopy.mf6.ModflowGwfsto(gwf,iconvert=1,ss=0.02,sy=sy,transient={0:True})
    flopy.mf6.ModflowGwfchd(
        gwf,
        stress_period_data={0:[((0,0,0),href+0.002),((0,0,2),href-0.002)]},
        pname="CHD_ENDS",
    )
    flopy.mf6.ModflowGwfapi(gwf,maxbound=1,pname="API_SWAP",filename="api_swap.api")
    sim.write_simulation(silent=True)

def open_session(libmf6:Path,publisher:Fgc34CtypesPublisher,href:float,sy:float):
    tmp=tempfile.TemporaryDirectory(prefix="pub-gc-e6-")
    workdir=Path(tmp.name)
    build_model(workdir,href,sy)
    raw=XmiWrapper(lib_path=libmf6,working_directory=workdir)
    raw.initialize()
    if "6.8.0" not in raw.get_version():
        raise RuntimeError("wrong MODFLOW version")
    raw.prepare_time_step(0.0)
    session=Modflow6PreparedSolveSession(raw,"GWF_1","API_SWAP",publisher,solution_id=1)
    if session.acquire_after_prepare_time_step()!=PreparedSolveStatus.OK:
        raise RuntimeError("MODFLOW acquire failed: "+session.last_error)
    if session.open_prepared_solve()!=PreparedSolveStatus.OK:
        raise RuntimeError("MODFLOW prepare_solve failed: "+session.last_error)
    return tmp,raw,session

def qgw(hcof:float,rhs:float,head:float)->float:
    return (hcof*head-rhs)/(AREA_M2*DAY_TO_S)

def loose_constant(libmf6:Path,publisher:Fgc34CtypesPublisher,swap:E6ActiveDrainageSwap,
                   href:float,sy:float,pred_hcof:float,pred_rhs:float,origin):
    qref_m3_day=pred_hcof*href-pred_rhs
    term=Term(7001,0.0,-qref_m3_day)
    tmp=raw=session=None
    try:
        tmp,raw,session=open_session(libmf6,publisher,href,sy)
        binding=[Binding(7001,1,2)]
        last=None
        calls=0
        for _ in range(100):
            status,it=session.publish_and_solve_iteration(binding,[term]); calls+=1
            if status!=PreparedSolveStatus.OK or it is None:
                return {"status":"MODFLOW_ERROR","modflow_iterations":calls}
            last=it
            if it.modflow_converged: break
        if last is None or not last.modflow_converged:
            return {"status":"MODFLOW_NOT_CONVERGED","modflow_iterations":calls}
        head=float(last.head_m[1])
        q_gw=qgw(0.0,-qref_m3_day,head)
        try:
            q_swap=swap.trial(head)
        except RuntimeError as exc:
            return {"status":"SWAP_TRIAL_FAIL","head_m":head,"q_gw_m_per_s":q_gw,"message":str(exc)}
        assert swap.state()==origin
        residual=q_swap-q_gw
        swap.discard(); assert swap.state()==origin
        session.finalize_prepared_solve()
        return {
            "status":"OK","modflow_iterations":calls,
            "head_m":head,"q_gw_m_per_s":q_gw,"q_swap_m_per_s":q_swap,
            "residual_m_per_s":residual,
        }
    finally:
        if raw is not None:
            try: raw.finalize()
            except Exception: pass
        if tmp is not None: tmp.cleanup()

def strong(libmf6:Path,publisher:Fgc34CtypesPublisher,swap:E6ActiveDrainageSwap,
           href:float,sy:float,hcof:float,rhs:float,origin):
    tmp=raw=session=None
    trace=[]
    try:
        tmp,raw,session=open_session(libmf6,publisher,href,sy)
        binding=[Binding(7001,1,2)]
        current_rhs=rhs
        for outer in range(1,min(MAX_OUTER,session.max_solve_iterations)+1):
            status,it=session.publish_and_solve_iteration(binding,[Term(7001,hcof,current_rhs)])
            if status!=PreparedSolveStatus.OK or it is None:
                return {"status":"MODFLOW_ERROR","iteration":outer,"trace":trace}
            head=float(it.head_m[1])
            q_gw=qgw(hcof,current_rhs,head)
            try:
                q_swap=swap.trial(head)
            except RuntimeError as exc:
                assert swap.state()==origin
                return {"status":"SWAP_TRIAL_FAIL","iteration":outer,"head_m":head,
                        "q_gw_m_per_s":q_gw,"message":str(exc),"trace":trace}
            assert swap.state()==origin
            residual=q_swap-q_gw
            trace.append({"iteration":outer,"head_m":head,"q_gw_m_per_s":q_gw,
                          "q_swap_m_per_s":q_swap,"residual_m_per_s":residual,
                          "modflow_converged":bool(it.modflow_converged)})
            if it.modflow_converged and abs(residual)<=FLUX_TOL:
                swap.discard(); assert swap.state()==origin
                session.finalize_prepared_solve()
                return {"status":"CONVERGED","iterations":outer,"head_m":head,
                        "q_gw_m_per_s":q_gw,"q_swap_m_per_s":q_swap,
                        "residual_m_per_s":residual,"trace":trace,
                        "operational_swap_correctors":outer}
            swap.discard(); assert swap.state()==origin
            current_rhs=hcof*head-q_swap*AREA_M2*DAY_TO_S
        return {"status":"MAX_OUTER","iterations":len(trace),"trace":trace}
    finally:
        if raw is not None:
            try: raw.finalize()
            except Exception: pass
        if tmp is not None: tmp.cleanup()

def main()->None:
    sy=float(os.environ["E6_SY"])
    libmf6=Path(os.environ["LIBMF6"]).resolve()
    swaplib=Path(os.environ["PUB_GC_E6_SWAP_LIB"]).resolve()
    swap=E6ActiveDrainageSwap(swaplib)
    hcof,rhs,href=swap.initialize()
    pred=swap.predictor()
    assert swap.drainage_coverage()
    origin=swap.state()
    assert origin==(0,0.0,0,0.0)
    publisher=Fgc34CtypesPublisher(swaplib)

    loose=loose_constant(libmf6,publisher,swap,href,sy,hcof,rhs,origin)
    strong_out=strong(libmf6,publisher,swap,href,sy,hcof,rhs,origin)
    rec={"schema":"pub-gc-e6-active-drainage-v1","specific_yield":sy,
         "window_day":WINDOW_DAY,"predictor_hcof_m2_per_day":hcof,
         "predictor_rhs_m3_per_day":rhs,"predictor_reference_head_m":href,
         "predictor":pred,"loose":loose,"strong":strong_out}
    if loose.get("status")=="OK" and strong_out.get("status")=="CONVERGED":
        rec["delta_head_strong_minus_loose_m"]=strong_out["head_m"]-loose["head_m"]
        rec["delta_exchange_strong_minus_loose_m_per_s"]=strong_out["q_swap_m_per_s"]-loose["q_swap_m_per_s"]
        rec["delta_integrated_exchange_m"]=(strong_out["q_swap_m_per_s"]-loose["q_swap_m_per_s"])*WINDOW_DAY*DAY_TO_S
        rec["loose_residual_over_tol"]=abs(loose["residual_m_per_s"])/FLUX_TOL
    assert swap.state()==origin
    print("PUB_GC_E6_JSON="+json.dumps(rec,sort_keys=True,separators=(",",":")))

if __name__=="__main__":
    main()
