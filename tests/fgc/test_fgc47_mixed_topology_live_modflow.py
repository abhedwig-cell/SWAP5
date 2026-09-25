from __future__ import annotations
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
from modflow6_prepared_solve_session import Modflow6PreparedSolveSession,PreparedSolveStatus
from fgc47_mixed_topology_ctypes import Fgc47MixedTopology

DAY_TO_S=86400.0
AREA_M2=1.0
WINDOW_DAY=1.0e-4
FLUX_TOL=1.0e-15
F1=0.35
F2=0.65

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
    sim=flopy.mf6.MFSimulation(sim_name="FGC47_MIXED",version="mf6",sim_ws=str(workdir))
    flopy.mf6.ModflowTdis(sim,time_units="DAYS",nper=1,perioddata=[(WINDOW_DAY,1,1.0)])
    flopy.mf6.ModflowIms(sim,complexity="MODERATE",outer_dvclose=1e-11,inner_dvclose=1e-12,outer_maximum=100,inner_maximum=100)
    gwf=flopy.mf6.ModflowGwf(sim,modelname="GWF_1",save_flows=True,newtonoptions="NEWTON")
    flopy.mf6.ModflowGwfdis(gwf,nlay=1,nrow=1,ncol=4,delr=1.0,delc=1.0,top=0.0,botm=-2.0)
    flopy.mf6.ModflowGwfic(gwf,strt=np.array([[[href1,href1,href2,href2]]],dtype=float))
    flopy.mf6.ModflowGwfnpf(gwf,icelltype=1,k=1.0,save_flows=True)
    flopy.mf6.ModflowGwfsto(gwf,iconvert=1,ss=0.02,sy=0.15,transient={0:True})
    flopy.mf6.ModflowGwfchd(gwf,stress_period_data={0:[((0,0,0),href1+0.002),((0,0,3),href2-0.002)]},pname="CHD_ENDS")
    flopy.mf6.ModflowGwfapi(gwf,maxbound=2,pname="API_SWAP",filename="api_swap.api")
    sim.write_simulation(silent=True)

def main()->None:
    libmf6=Path(os.environ["LIBMF6"]).resolve()
    bridge=Path(os.environ["FGC47_MIXED_LIB"]).resolve()
    require(libmf6.is_file(),"missing MODFLOW library")
    require(bridge.is_file(),"missing F-GC47 bridge")

    swap=Fgc47MixedTopology(bridge)
    hcof1,rhs1,href1,hcof2,rhs2,href2=swap.initialize()
    require(all(math.isfinite(v) for v in (hcof1,rhs1,href1,hcof2,rhs2,href2)),"nonfinite mixed-topology predictors")
    require(abs(hcof1)>0.0 and abs(hcof2)>0.0,"mixed cell slope is zero")
    state=swap.state()
    require(state[:3]==(0,0,0),"SWAP revisions not at accepted origins")
    require(sum(abs(v) for v in state[3:6])==0.0,"SWAP times not at accepted origins")
    require(state[6:9]==(0,0,0),"ledgers not empty at origin")

    with tempfile.TemporaryDirectory(prefix="fgc47-mixed-") as tmp:
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
            coupling_start=time.perf_counter()
            outer_iterations=0

            for outer in range(1,min(40,session.max_solve_iterations)+1):
                outer_iterations=outer
                status,it=session.publish_and_solve_iteration(bindings,current)
                require(status==PreparedSolveStatus.OK,session.last_error)
                require(it is not None,f"missing MODFLOW iterate {outer}")
                require(np.array_equal(it.accepted_head_old_m,accepted_xold),"MODFLOW XOLD drifted")
                require(list(session.nodelist[:2])==[2,3],"two-cell API mapping changed")
                h1=float(it.head_m[1]); h2=float(it.head_m[2])
                qgw1=(current[0].hcof_m2_per_day*h1-current[0].rhs_m3_per_day)/(AREA_M2*DAY_TO_S)
                qgw2=(current[1].hcof_m2_per_day*h2-current[1].rhs_m3_per_day)/(AREA_M2*DAY_TO_S)
                qc1,qc2,q1,q2,q3=swap.trial(h1,h2)
                require(abs(qc1-(F1*q1+F2*q2))<=8*np.finfo(float).eps*max(1.0,abs(qc1)),"cell1 N:1 corrector closure")
                require(abs(qc2-q3)<=8*np.finfo(float).eps*max(1.0,abs(qc2)),"cell2 1:1 corrector closure")
                r1=qc1-qgw1; r2=qc2-qgw2
                require(all(math.isfinite(x) for x in (h1,h2,qgw1,qgw2,qc1,qc2,q1,q2,q3,r1,r2)),"nonfinite mixed iterate")
                print(f"FGC47_ITER={outer} H1={h1:.17g} H2={h2:.17g} QC1={qc1:.17g} QC2={qc2:.17g} Q1={q1:.17g} Q2={q2:.17g} Q3={q3:.17g} QGW1={qgw1:.17g} QGW2={qgw2:.17g} R1={r1:.17g} R2={r2:.17g} MF={int(it.modflow_converged)}")
                if it.modflow_converged and max(abs(r1),abs(r2))<=FLUX_TOL:
                    converged=True; final=(h1,h2,qc1,qc2,q1,q2,q3,qgw1,qgw2,r1,r2)
                    break
                swap.discard()
                current=[
                    Term(7001,current[0].hcof_m2_per_day,current[0].hcof_m2_per_day*h1-qc1*AREA_M2*DAY_TO_S),
                    Term(7002,current[1].hcof_m2_per_day,current[1].hcof_m2_per_day*h2-qc2*AREA_M2*DAY_TO_S),
                ]

            require(converged,"mixed-topology coupling did not converge")
            coupling_seconds=time.perf_counter()-coupling_start
            require(session.finalize_prepared_solve()==PreparedSolveStatus.OK,session.last_error)
            require(kernel.prepare_solve_calls==1 and kernel.finalize_solve_calls==1,"prepared-solve lifecycle mismatch")
            require(swap.swap_preflight(),"all three SWAP preflights failed")
            swap.prepare_ledgers()
            require(swap.ledgers_preflight(),"all three ledger preflights failed")
            require(session.timestep_ready_for_finalize(),"shared MODFLOW timestep readiness failed")
            require(kernel.finalize_time_step_calls==0,"preflight crossed publication point")

            require(session.finalize_time_step_once()==PreparedSolveStatus.OK,session.last_error)
            require(kernel.finalize_time_step_calls==1,"MODFLOW timestep finalize count mismatch")
            swap.commit_swaps()
            swap.commit_ledgers()
            state=swap.state()
            require(state[:3]==(1,1,1),"three SWAP lineages not committed exactly once")
            require(all(abs(v-WINDOW_DAY)<=1e-14 for v in state[3:6]),"committed SWAP times mismatch")
            require(state[6:9]==(1,1,1),"three ledgers not committed exactly once")
            require(all(math.isfinite(v) for v in state[9:]),"ledger exchange nonfinite")
            assert final is not None
            h1,h2,qc1,qc2,q1,q2,q3,qgw1,qgw2,r1,r2=final
            dt_s=WINDOW_DAY*DAY_TO_S
            require(abs((state[9]+state[10])-qc1*dt_s)<=1e-16*max(1.0,abs(qc1*dt_s)),"cell1 N:1 ledger closure failed")
            require(abs(state[11]-qc2*dt_s)<=1e-16*max(1.0,abs(qc2*dt_s)),"cell2 1:1 ledger closure failed")
            require(not session.timestep_ready_for_finalize(),"finalized timestep remained ready")
            require(session.finalize_time_step_once()==PreparedSolveStatus.TIMESTEP_ALREADY_FINALIZED,"second timestep finalization not blocked")
            raw.finalize(); initialized=False

            print(f"FGC47_FINAL_HEAD1_M={h1:.17g}")
            print(f"FGC47_FINAL_HEAD2_M={h2:.17g}")
            print(f"FGC47_FINAL_QCELL1_M_PER_S={qc1:.17g}")
            print(f"FGC47_FINAL_QCELL2_M_PER_S={qc2:.17g}")
            print(f"FGC47_FINAL_R1={r1:.17g}")
            print(f"FGC47_FINAL_R2={r2:.17g}")
            print(f"FGC47_COUPLING_OUTER_ITERATIONS={outer_iterations}")
            print(f"FGC47_MODFLOW_SOLVE_CALLS={kernel.solve_calls}")
            print(f"FGC47_COUPLING_SECONDS={coupling_seconds:.17g}")
            print("FGC47_THREE_REAL_SWAP_LINEAGES=PASS")
            print("FGC47_CELL1_FGC40_N1_RESPONSE=PASS")
            print("FGC47_CELL2_ONE_TO_ONE_RESPONSE=PASS")
            print("FGC47_FGC34_TWO_CELL_MAPPING=PASS")
            print("FGC47_COMMON_HEAD_FOR_N1_TILES=PASS")
            print("FGC47_CELL_SPECIFIC_CORRECTOR_ROUTING=PASS")
            print("FGC47_CONJUNCTIVE_MIXED_TOPOLOGY_CONVERGENCE=PASS")
            print("FGC47_ALL_PARTICIPANTS_PREFLIGHT_BEFORE_PUBLICATION=PASS")
            print("FGC47_MODFLOW_THEN_THREE_SWAP_THEN_THREE_LEDGER_PUBLICATION=PASS")
            print("FGC47_PER_CELL_LEDGER_CLOSURE=PASS")
            print("FGC47_REAL_MIXED_TOPOLOGY_END_TO_END=PASS")
        finally:
            if initialized:
                try: raw.finalize()
                except Exception: pass

if __name__=="__main__":
    main()
