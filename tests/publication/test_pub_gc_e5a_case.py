from __future__ import annotations
import json, math, os, sys, tempfile
from dataclasses import dataclass
from pathlib import Path
import flopy, numpy as np
from xmipy import XmiWrapper

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/"src"/"adapter"))
sys.path.insert(0,str(ROOT/"tests"/"fgc"/"support"))
from modflow6_fgc34_ctypes_publisher import Fgc34CtypesPublisher
from modflow6_prepared_solve_session import Modflow6PreparedSolveSession, PreparedSolveStatus
from fgc44_real_swap_ctypes import Fgc44RealSwap

DAY=86400.0
AREA=1.0
TOL=1e-15
MAXIT=40

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

def build_model(ws:Path, href:float, dt:float, k:float)->None:
    sim=flopy.mf6.MFSimulation(sim_name="PUB_GC_E5",version="mf6",sim_ws=str(ws))
    flopy.mf6.ModflowTdis(sim,time_units="DAYS",nper=1,perioddata=[(dt,1,1.0)])
    flopy.mf6.ModflowIms(sim,complexity="MODERATE",outer_dvclose=1e-11,inner_dvclose=1e-12,outer_maximum=100,inner_maximum=100)
    gwf=flopy.mf6.ModflowGwf(sim,modelname="GWF_1",save_flows=True,newtonoptions="NEWTON")
    flopy.mf6.ModflowGwfdis(gwf,nlay=1,nrow=1,ncol=3,delr=1.0,delc=1.0,top=0.0,botm=-2.0)
    flopy.mf6.ModflowGwfic(gwf,strt=href)
    flopy.mf6.ModflowGwfnpf(gwf,icelltype=1,k=k,save_flows=True)
    flopy.mf6.ModflowGwfsto(gwf,iconvert=1,ss=0.02,sy=0.15,transient={0:True})
    flopy.mf6.ModflowGwfchd(gwf,stress_period_data={0:[((0,0,0),href),((0,0,2),href)]},pname="CHD_ENDS")
    flopy.mf6.ModflowGwfapi(gwf,maxbound=1,pname="API_SWAP",filename="api_swap.api")
    sim.write_simulation(silent=True)

def q_from_term(hcof:float,rhs:float,h:float)->float:
    return (hcof*h-rhs)/(AREA*DAY)

def make_session(libmf6:Path,publisher,href:float,dt:float,k:float):
    tmp=tempfile.TemporaryDirectory(prefix="pub-gc-e5-")
    build_model(Path(tmp.name),href,dt,k)
    raw=XmiWrapper(lib_path=libmf6,working_directory=Path(tmp.name))
    raw.initialize()
    raw.prepare_time_step(0.0)
    sess=Modflow6PreparedSolveSession(raw,"GWF_1","API_SWAP",publisher,solution_id=1)
    if sess.acquire_after_prepare_time_step()!=PreparedSolveStatus.OK: raise RuntimeError(sess.last_error)
    if sess.open_prepared_solve()!=PreparedSolveStatus.OK: raise RuntimeError(sess.last_error)
    return tmp,raw,sess

def run()->dict:
    method=os.environ["E5_METHOD"]
    dt=float(os.environ["E5_WINDOW_DAY"])
    qbot=float(os.environ["E5_QBOT_CM_PER_DAY"])
    k=float(os.environ["E5_K_M_PER_DAY"])
    jr=float(os.environ["E5_JR"])
    libmf6=Path(os.environ["LIBMF6"]).resolve()
    swaplib=Path(os.environ["FGC44_SWAP_LIB"]).resolve()

    swap=Fgc44RealSwap(swaplib)
    hcof_u,rhs_u,href=swap.initialize_configured(dt,qbot)
    origin=swap.state()
    if origin!=(0,0.0,0,0.0): raise AssertionError("nonzero accepted origin")
    qref=q_from_term(hcof_u,rhs_u,href)
    publisher=Fgc34CtypesPublisher(swaplib)
    tmp=raw=sess=None
    trace=[]
    try:
        tmp,raw,sess=make_session(libmf6,publisher,href,dt,k)
        binding=[Binding(7001,1,2)]

        qvar=qref
        prev_q=None; prev_r=None; prev_omega=1.0
        if method=="uA":
            hcof=hcof_u; rhs=rhs_u
        elif method=="oracle":
            hcof=jr*AREA/dt
            rhs=hcof*href-qref*AREA*DAY
        else:
            hcof=0.0; rhs=-qvar*AREA*DAY

        for outer in range(1,min(MAXIT,sess.max_solve_iterations)+1):
            status,it=sess.publish_and_solve_iteration(binding,[Term(7001,hcof,rhs)])
            if status!=PreparedSolveStatus.OK or it is None:
                return {"status":"MODFLOW_FAIL","method":method,"iterations":outer-1,"trace":trace,"message":sess.last_error}
            head=float(it.head_m[1])
            qgw=q_from_term(hcof,rhs,head)
            try:
                qswap=swap.trial(head)
            except Exception as exc:
                return {"status":"SWAP_TRIAL_FAIL","method":method,"iterations":outer,"trace":trace,"head_m":head,"message":str(exc)}
            r=qswap-qgw
            trace.append({"iteration":outer,"head_m":head,"q_gw_m_per_s":qgw,"q_swap_m_per_s":qswap,"residual_m_per_s":r,"modflow_converged":bool(it.modflow_converged)})
            if it.modflow_converged and abs(r)<=TOL:
                swap.discard()
                return {"status":"CONVERGED","method":method,"iterations":outer,"head_m":head,"q_gw_m_per_s":qgw,"q_swap_m_per_s":qswap,"residual_m_per_s":r,"swap_work":1+outer,"trace":trace}
            swap.discard()
            if swap.state()!=origin: raise AssertionError("trial/discard changed authority")

            if method in ("uA","oracle"):
                rhs=hcof*head-qswap*AREA*DAY
            elif method=="fp":
                qvar=qswap; rhs=-qvar*AREA*DAY
            elif method=="aitken":
                if prev_r is None:
                    omega=1.0
                else:
                    den=r-prev_r
                    omega=prev_omega if abs(den)<=1e-30 else -prev_omega*prev_r/den
                    omega=max(-10.0,min(10.0,omega))
                prev_q=qvar; prev_r=r; prev_omega=omega
                qvar=qvar+omega*r
                rhs=-qvar*AREA*DAY
            elif method=="secant":
                if prev_r is None or prev_q is None or abs(r-prev_r)<=1e-30:
                    qnext=qvar+r
                else:
                    qnext=qvar-r*(qvar-prev_q)/(r-prev_r)
                prev_q,prev_r=qvar,r
                qvar=qnext
                rhs=-qvar*AREA*DAY
            else:
                raise ValueError(method)

        return {"status":"ITERATION_LIMIT","method":method,"iterations":len(trace),"swap_work":1+len(trace),"trace":trace}
    finally:
        if raw is not None:
            try: raw.finalize()
            except Exception: pass
        if tmp is not None: tmp.cleanup()

if __name__=="__main__":
    rec={
      "schema":"pub-gc-e5a-case-v1",
      "baseline":os.environ["E5_BASELINE"],
      "window_day":float(os.environ["E5_WINDOW_DAY"]),
      "qbot_cm_per_day":float(os.environ["E5_QBOT_CM_PER_DAY"]),
      "k_m_per_day":float(os.environ["E5_K_M_PER_DAY"]),
      "J_R":float(os.environ["E5_JR"]),
      "method":os.environ["E5_METHOD"],
    }
    try:
        rec["outcome"]=run(); rec["harness_status"]="OK"
    except Exception as exc:
        rec["harness_status"]="ERROR"; rec["harness_error"]=f"{type(exc).__name__}:{exc}"
    print("E5_JSON="+json.dumps(rec,sort_keys=True,separators=(",",":")))
