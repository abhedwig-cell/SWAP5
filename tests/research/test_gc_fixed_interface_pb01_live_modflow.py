from __future__ import annotations
import math, os, sys, tempfile
from dataclasses import dataclass
from pathlib import Path
import flopy
import numpy as np
from xmipy import XmiWrapper

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/"src"/"adapter"))
from modflow6_prepared_solve_session import Modflow6PreparedSolveSession, PreparedSolveStatus

DAY=86400.0; DT=1.0; AREA=1.0; H0=8.0; SS=.10; SM=.10; C=.20; WS=.010
BETA=C*DT/(SS+C*DT); U=BETA*SS; ROOT_HEAD=8.04
@dataclass(frozen=True)
class Binding: groundwater_cell_id:int; package_slot:int; modflow_node_id:int
@dataclass(frozen=True)
class Term: groundwater_cell_id:int; hcof_m2_per_day:float; rhs_m3_per_day:float
class Publisher:
    def __call__(self,bindings,terms,maxbound,nodelist,hcof,rhs,nbound):
        nodelist[0]=1; hcof[0]=terms[0].hcof_m2_per_day; rhs[0]=terms[0].rhs_m3_per_day; nbound[0]=1; return 0

def qphys(h): return BETA*WS-(U)*(h-H0)

def build(ws:Path,start:float):
    sim=flopy.mf6.MFSimulation(sim_name="PB01",version="mf6",sim_ws=str(ws))
    flopy.mf6.ModflowTdis(sim,time_units="DAYS",nper=1,perioddata=[(1.0,1,1.0)])
    flopy.mf6.ModflowIms(sim,complexity="SIMPLE",outer_dvclose=1e-12,inner_dvclose=1e-13,outer_maximum=100,inner_maximum=100)
    gwf=flopy.mf6.ModflowGwf(sim,modelname="GWF_1",save_flows=True)
    flopy.mf6.ModflowGwfdis(gwf,nlay=1,nrow=1,ncol=1,delr=1.,delc=1.,top=20.,botm=0.)
    flopy.mf6.ModflowGwfic(gwf,strt=start)
    flopy.mf6.ModflowGwfnpf(gwf,icelltype=0,k=1.)
    # Confined storage gives exactly SM m water per m head for unit area.
    flopy.mf6.ModflowGwfsto(gwf,iconvert=0,ss=SM/20.0,sy=0.0,transient={0:True})
    flopy.mf6.ModflowGwfapi(gwf,maxbound=1,pname="API_SWAP",filename="api_swap.api")
    sim.write_simulation(silent=True)

def run(lib:Path,slope:float,reanchor:bool,start_anchor:float,max_outer=12):
    with tempfile.TemporaryDirectory(prefix="pb01-live-") as t:
        p=Path(t); build(p,H0); raw=XmiWrapper(lib_path=lib,working_directory=p); raw.initialize()
        try:
            raw.prepare_time_step(0.0)
            ses=Modflow6PreparedSolveSession(raw,"GWF_1","API_SWAP",Publisher(),1)
            assert ses.acquire_after_prepare_time_step()==PreparedSolveStatus.OK
            assert ses.open_prepared_solve()==PreparedSolveStatus.OK
            anchor=start_anchor; q_anchor=qphys(anchor)
            hcof=AREA*slope
            rhs=hcof*anchor-AREA*q_anchor
            trace=[]
            for k in range(max_outer):
                st,it=ses.publish_and_solve_iteration([Binding(1,1,1)],[Term(1,hcof,rhs)])
                assert st==PreparedSolveStatus.OK and it is not None
                h=float(it.head_m[0]); r=qphys(h)-SM*(h-H0)
                trace.append((h,r))
                if reanchor:
                    rhs=hcof*h-AREA*qphys(h)
            return trace
        finally: raw.finalize()

def main():
    lib=Path(os.environ["LIBMF6"]).resolve()
    # Controls use same MODFLOW API route.
    neg=run(lib,-U,False,H0)
    assert abs(neg[-1][0]-ROOT_HEAD)<1e-9
    frozen=run(lib,+U,False,H0)
    assert abs(frozen[-1][0]-ROOT_HEAD)>1e-4
    pos=run(lib,+U,True,8.20)
    errs=[abs(h-ROOT_HEAD) for h,_ in pos]
    print("PB01_LIVE_NEGATIVE_HEAD",neg[-1][0])
    print("PB01_LIVE_FROZEN_POSITIVE_HEAD",frozen[-1][0])
    print("PB01_LIVE_REANCHORED_POSITIVE_ERRORS"," ".join(f"{x:.12g}" for x in errs))
    print("PB01_LIVE_PHYSICAL_NEGATIVE_TANGENT=PASS")
    print("PB01_LIVE_FROZEN_POSITIVE_PHYSICAL_CONDENSATION=FAIL_AS_PREDICTED")
    # Do not demand a specific MODFLOW nonlinear amplification a priori.
    if errs[-1] < errs[0]: print("PB01_LIVE_REANCHORED_POSITIVE=CONVERGENT")
    else: print("PB01_LIVE_REANCHORED_POSITIVE=NONCONVERGENT_OR_UNSTABLE")

if __name__=="__main__": main()
