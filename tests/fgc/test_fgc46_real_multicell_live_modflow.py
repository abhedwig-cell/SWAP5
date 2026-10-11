from __future__ import annotations
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
from modflow6_prepared_solve_session import Modflow6PreparedSolveSession,PreparedSolveStatus
from fgc46_real_multicell_ctypes import Fgc46RealMultiCell

DAY_TO_S=86400.0
AREA_M2=1.0
WINDOW_DAY=1.0e-4
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
        self.kernel=kernel; self.prepare_solve_calls=0; self.solve_calls=0
        self.finalize_solve_calls=0; self.finalize_time_step_calls=0
    def __getattr__(self,name): return getattr(self.kernel,name)
    def prepare_solve(self,solution_id:int)->None:
        self.prepare_solve_calls+=1; self.kernel.prepare_solve(solution_id)
    def solve(self,solution_id:int)->bool:
        self.solve_calls+=1; return bool(self.kernel.solve(solution_id))
    def finalize_solve(self,solution_id:int)->None:
        self.finalize_solve_calls+=1; self.kernel.finalize_solve(solution_id)
    def finalize_time_step(self)->None:
        self.finalize_time_step_calls+=1; self.kernel.finalize_time_step()

def require(x:bool,msg:str)->None:
    if not x: raise AssertionError(msg)

def build_model(workdir:Path,href1:float,href2:float)->None:
    sim=flopy.mf6.MFSimulation(sim_name="FGC46_REAL_MULTICELL",version="mf6",sim_ws=str(workdir))
    flopy.mf6.ModflowTdis(sim,time_units="DAYS",nper=1,perioddata=[(WINDOW_DAY,1,1.0)])
    flopy.mf6.ModflowIms(sim,complexity="MODERATE",outer_dvclose=1e-11,inner_dvclose=1e-12,outer_maximum=100,inner_maximum=100)
    gwf=flopy.mf6.ModflowGwf(sim,modelname="GWF_1",save_flows=True,newtonoptions="NEWTON")
    flopy.mf6.ModflowGwfdis(gwf,nlay=1,nrow=1,ncol=4,delr=1.0,delc=1.0,top=0.0,botm=-2.0)
    strt=np.array([[[href1,href1,href2,href2]]],dtype=float)
    flopy.mf6.ModflowGwfic(gwf,strt=strt)
    flopy.mf6.ModflowGwfnpf(gwf,icelltype=1,k=1.0,save_flows=True)
    flopy.mf6.ModflowGwfsto(gwf,iconvert=1,ss=0.02,sy=0.15,transient={0:True})
    flopy.mf6.ModflowGwfchd(gwf,stress_period_data={0:[((0,0,0),href1+0.002),((0,0,3),href2-0.002)]},pname="CHD_ENDS")
    flopy.mf6.ModflowGwfapi(gwf,maxbound=2,pname="API_SWAP",filename="api_swap.api")
    sim.write_simulation(silent=True)

def main()->None:
    libmf6=Path(os.environ["LIBMF6"]).resolve()
    bridge=Path(os.environ["FGC46_MULTICELL_LIB"]).resolve()
    require(libmf6.is_file(),"missing MODFLOW library")
    require(bridge.is_file(),"missing F-GC46 bridge")

    swap=Fgc46RealMultiCell(bridge)
    hcof1,rhs1,href1,hcof2,rhs2,href2=swap.initialize()
    require(all(math.isfinite(v) for v in (hcof1,rhs1,href1,hcof2,rhs2,href2)),"nonfinite two-cell predictors")
    require(abs(hcof1)>0.0 and abs(hcof2)>0.0,"cell predictor slope is zero")
    state=swap.state()
    require(state[:2]==(0,0),"SWAP revisions not at accepted origins")
    require(abs(state[2])+abs(state[3])==0.0,"SWAP times not at accepted origins")
    require(state[4:6]==(0,0),"interface ledgers not empty at origin")

    with tempfile.TemporaryDirectory(prefix="fgc46-multicell-") as tmp:
        workdir=Path(tmp); build_model(workdir,href1,href2)
        raw=XmiWrapper(lib_path=libmf6,working_directory=workdir)
        kernel=CountingKernel(raw)
        publisher=Fgc34CtypesPublisher(bridge)
        initialized=False
        try:
            raw.initialize(); initialized=True
            require("6.8.0" in raw.get_version(),"wrong MODFLOW version")
            raw.prepare_time_step(0.0)
            session=Modflow6PreparedSolveSession(kernel,"GWF_1","API_SWAP",publisher,solution_id=1)
            require(session.acquire_after_prepare_time_step()==PreparedSolveStatus.OK,session.last_error)
            require(session.open_prepared_solve()==PreparedSolveStatus.OK,session.last_error)
            accepted_xold=session.accepted_xold.copy()
            bindings=[Binding(7001,1,2),Binding(7002,2,3)]
            current=[Term(7001,hcof1,rhs1),Term(7002,hcof2,rhs2)]
            converged=False; final=None

            for outer in range(1,min(40,session.max_solve_iterations)+1):
                status,it=session.publish_and_solve_iteration(bindings,current)
                require(status==PreparedSolveStatus.OK,session.last_error)
                require(it is not None,f"missing MODFLOW iterate {outer}")
                require(np.array_equal(it.accepted_head_old_m,accepted_xold),"MODFLOW XOLD drifted")
                require(list(session.nodelist[:2])==[2,3],"F-GC34 API slot/node mapping changed")
                head1=float(it.head_m[1]); head2=float(it.head_m[2])
                qgw1=(current[0].hcof_m2_per_day*head1-current[0].rhs_m3_per_day)/(AREA_M2*DAY_TO_S)
                qgw2=(current[1].hcof_m2_per_day*head2-current[1].rhs_m3_per_day)/(AREA_M2*DAY_TO_S)
                q1,q2=swap.trial(head1,head2)
                r1=q1-qgw1; r2=q2-qgw2
                require(all(math.isfinite(x) for x in (head1,head2,qgw1,qgw2,q1,q2,r1,r2)),"nonfinite multi-cell iterate")
                print(f"FGC46_ITER={outer} H1={head1:.17g} H2={head2:.17g} Q1={q1:.17g} Q2={q2:.17g} QGW1={qgw1:.17g} QGW2={qgw2:.17g} R1={r1:.17g} R2={r2:.17g} MF={int(it.modflow_converged)}")
                if it.modflow_converged and max(abs(r1),abs(r2))<=FLUX_TOL:
                    converged=True; final=(head1,head2,q1,q2,qgw1,qgw2,r1,r2)
                    break
                swap.discard()
                current=[
                    Term(7001,current[0].hcof_m2_per_day,current[0].hcof_m2_per_day*head1-q1*AREA_M2*DAY_TO_S),
                    Term(7002,current[1].hcof_m2_per_day,current[1].hcof_m2_per_day*head2-q2*AREA_M2*DAY_TO_S),
                ]

            require(converged,"two-cell real SWAP + MODFLOW coupling did not converge")
            require(session.finalize_prepared_solve()==PreparedSolveStatus.OK,session.last_error)
            require(kernel.prepare_solve_calls==1 and kernel.finalize_solve_calls==1,"prepared-solve lifecycle mismatch")
            require(swap.swap_preflight(),"both SWAP publication preflights failed")
            swap.prepare_ledgers()
            require(swap.ledgers_preflight(),"both ledger preflights failed")
            require(session.timestep_ready_for_finalize(),"shared MODFLOW timestep readiness failed")
            require(kernel.finalize_time_step_calls==0,"preflight crossed publication point")

            require(session.finalize_time_step_once()==PreparedSolveStatus.OK,session.last_error)
            require(kernel.finalize_time_step_calls==1,"MODFLOW timestep finalized other than once")
            swap.commit_swaps()
            swap.commit_ledgers()
            state=swap.state()
            require(state[:2]==(1,1),"both SWAP interfaces not committed exactly once")
            require(abs(state[2]-WINDOW_DAY)<=1e-14 and abs(state[3]-WINDOW_DAY)<=1e-14,"committed SWAP times mismatch")
            require(state[4:6]==(1,1),"both interface ledgers not committed exactly once")
            require(all(math.isfinite(v) for v in state[6:]),"ledger exchange nonfinite")
            assert final is not None
            head1,head2,q1,q2,qgw1,qgw2,r1,r2=final
            dt_s=WINDOW_DAY*DAY_TO_S
            require(abs(state[6]-q1*dt_s)<=1e-16*max(1.0,abs(state[6]),abs(q1*dt_s)),"cell1 ledger/exchange mismatch")
            require(abs(state[7]-q2*dt_s)<=1e-16*max(1.0,abs(state[7]),abs(q2*dt_s)),"cell2 ledger/exchange mismatch")
            require(not session.timestep_ready_for_finalize(),"finalized timestep remained ready")
            require(session.finalize_time_step_once()==PreparedSolveStatus.TIMESTEP_ALREADY_FINALIZED,"second timestep finalization not blocked")
            raw.finalize(); initialized=False

            print(f"FGC46_FINAL_HEAD1_M={head1:.17g}")
            print(f"FGC46_FINAL_HEAD2_M={head2:.17g}")
            print(f"FGC46_FINAL_Q1_M_PER_S={q1:.17g}")
            print(f"FGC46_FINAL_Q2_M_PER_S={q2:.17g}")
            print(f"FGC46_FINAL_QGW1_M_PER_S={qgw1:.17g}")
            print(f"FGC46_FINAL_QGW2_M_PER_S={qgw2:.17g}")
            print(f"FGC46_FINAL_R1={r1:.17g}")
            print(f"FGC46_FINAL_R2={r2:.17g}")
            print(f"FGC46_LEDGER1_M={state[6]:.17g}")
            print(f"FGC46_LEDGER2_M={state[7]:.17g}")
            print("FGC46_TWO_DISTINCT_LIVE_MODFLOW_CELLS=PASS")
            print("FGC46_FGC34_TWO_SLOT_NODE_BINDING=PASS")
            print("FGC46_TWO_REAL_SWAP_SAME_ORIGIN_CORRECTORS=PASS")
            print("FGC46_ONE_PREPARED_SOLVE_TWO_INTERFACES=PASS")
            print("FGC46_CONJUNCTIVE_TWO_CELL_CONVERGENCE=PASS")
            print("FGC46_ALL_INTERFACE_PREFLIGHTS_BEFORE_PUBLICATION=PASS")
            print("FGC46_SINGLE_MODFLOW_THEN_ALL_SWAP_THEN_ALL_LEDGER_PUBLICATION=PASS")
            print("FGC46_PER_CELL_LEDGER_CLOSURE=PASS")
            print("FGC46_REAL_MULTICELL_END_TO_END=PASS")
        finally:
            if initialized:
                try: raw.finalize()
                except Exception: pass

if __name__=="__main__":
    main()
