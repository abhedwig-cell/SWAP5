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
from modflow6_prepared_solve_session import Modflow6PreparedSolveSession, PreparedSolveStatus
from fgc45_real_multiswap_ctypes import Fgc45RealMultiSwap

DAY_TO_S=86400.0
AREA_M2=1.0
WINDOW_DAY=1.0e-4
FLUX_TOL=1.0e-15
FRACTIONS=(0.375,0.625)

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

def build_model(workdir:Path, reference_head:float)->None:
    sim=flopy.mf6.MFSimulation(sim_name="FGC45_REAL_N1",version="mf6",sim_ws=str(workdir))
    flopy.mf6.ModflowTdis(sim,time_units="DAYS",nper=1,perioddata=[(WINDOW_DAY,1,1.0)])
    flopy.mf6.ModflowIms(sim,complexity="MODERATE",outer_dvclose=1e-11,inner_dvclose=1e-12,outer_maximum=100,inner_maximum=100)
    gwf=flopy.mf6.ModflowGwf(sim,modelname="GWF_1",save_flows=True,newtonoptions="NEWTON")
    flopy.mf6.ModflowGwfdis(gwf,nlay=1,nrow=1,ncol=3,delr=1.0,delc=1.0,top=0.0,botm=-2.0)
    flopy.mf6.ModflowGwfic(gwf,strt=reference_head)
    flopy.mf6.ModflowGwfnpf(gwf,icelltype=1,k=1.0,save_flows=True)
    flopy.mf6.ModflowGwfsto(gwf,iconvert=1,ss=0.02,sy=0.15,transient={0:True})
    flopy.mf6.ModflowGwfchd(gwf,stress_period_data={0:[((0,0,0),reference_head+0.002),((0,0,2),reference_head-0.002)]},pname="CHD_ENDS")
    flopy.mf6.ModflowGwfapi(gwf,maxbound=1,pname="API_SWAP",filename="api_swap.api")
    sim.write_simulation(silent=True)

def main()->None:
    libmf6=Path(os.environ["LIBMF6"]).resolve()
    swaplib=Path(os.environ["FGC45_SWAP_LIB"]).resolve()
    require(libmf6.is_file(),"missing live MODFLOW library")
    require(swaplib.is_file(),"missing real MultiSWAP bridge library")

    swap=Fgc45RealMultiSwap(swaplib)
    hcof,rhs,href=swap.initialize()
    q1,q2,u1,u2,h1,h2=swap.predictor_meta()
    require(all(math.isfinite(x) for x in (hcof,rhs,href,q1,q2,u1,u2,h1,h2)),"nonfinite MultiSWAP predictor")
    require(abs(hcof)>0.0,"aggregate predictor tangent is zero")
    require(max(abs(q1-q2),abs(u1-u2),abs(h1-h2))>1e-18,"two real tile predictors are not heterogeneous")
    dt_s=WINDOW_DAY*DAY_TO_S
    direct_qref=FRACTIONS[0]*(q1+(u1/dt_s)*(href-h1))+FRACTIONS[1]*(q2+(u2/dt_s)*(href-h2))
    term_qref=(hcof*href-rhs)/(AREA_M2*DAY_TO_S)
    require(abs(direct_qref-term_qref)<=2e-18*max(1.0,abs(direct_qref),abs(term_qref)),"F-GC40 real-tile affine closure failed")

    rev1,rev2,t1,t2,count1,count2,ledger_total=swap.state()
    require((rev1,rev2,count1,count2)==(0,0,0,0),"tile/ledger origins not clean")
    require(t1==0.0 and t2==0.0 and ledger_total==0.0,"tile origin time or ledger not zero")

    with tempfile.TemporaryDirectory(prefix="fgc45-n1-") as tmp:
        workdir=Path(tmp); build_model(workdir,href)
        raw=XmiWrapper(lib_path=libmf6,working_directory=workdir)
        kernel=CountingKernel(raw)
        publisher=Fgc34CtypesPublisher(swaplib)
        initialized=False
        try:
            raw.initialize(); initialized=True
            require("6.8.0" in raw.get_version(),"wrong MODFLOW version")
            raw.prepare_time_step(0.0)
            session=Modflow6PreparedSolveSession(kernel,"GWF_1","API_SWAP",publisher,solution_id=1)
            require(session.acquire_after_prepare_time_step()==PreparedSolveStatus.OK,session.last_error)
            require(session.open_prepared_solve()==PreparedSolveStatus.OK,session.last_error)
            accepted_xold=session.accepted_xold.copy()
            binding=[Binding(7001,1,2)]
            current_hcof=hcof; current_rhs=rhs
            final_head=None; final_q_swap=None; final_q_gw=None; converged=False

            for outer in range(1,min(40,session.max_solve_iterations)+1):
                term=Term(7001,current_hcof,current_rhs)
                status,it=session.publish_and_solve_iteration(binding,[term])
                require(status==PreparedSolveStatus.OK,session.last_error)
                require(it is not None,f"missing MODFLOW iterate {outer}")
                require(np.array_equal(it.accepted_head_old_m,accepted_xold),"MODFLOW XOLD drifted")
                head=float(it.head_m[1])
                q_gw=(current_hcof*head-current_rhs)/(AREA_M2*DAY_TO_S)
                q_swap=swap.trial(head)
                residual=q_swap-q_gw
                require(all(math.isfinite(x) for x in (head,q_gw,q_swap,residual)),"nonfinite N:1 coupled iterate")
                print(f"FGC45_ITER={outer} H={head:.17g} QSWAP_AGG={q_swap:.17g} QGW={q_gw:.17g} RES={residual:.17g} MF={int(it.modflow_converged)}")
                if it.modflow_converged and abs(residual)<=FLUX_TOL:
                    converged=True; final_head=head; final_q_swap=q_swap; final_q_gw=q_gw
                    break
                swap.discard()
                current_rhs=current_hcof*head-q_swap*AREA_M2*DAY_TO_S

            require(converged,"real MultiSWAP N:1 + MODFLOW coupling did not converge")
            require(session.finalize_prepared_solve()==PreparedSolveStatus.OK,session.last_error)
            require(kernel.prepare_solve_calls==1 and kernel.finalize_solve_calls==1,"prepared solve lifecycle mismatch")
            require(swap.swap_preflight(),"all real SWAP tile publication preflights did not pass")
            swap.prepare_ledgers()
            require(swap.ledger_preflight(),"all tile ledgers not ready")
            require(session.timestep_ready_for_finalize(),"live MODFLOW timestep not ready")
            require(kernel.finalize_time_step_calls==0,"preflight crossed MODFLOW publication point")

            require(session.finalize_time_step_once()==PreparedSolveStatus.OK,session.last_error)
            require(kernel.finalize_time_step_calls==1,"MODFLOW timestep not finalized exactly once")
            swap.commit_swap()
            swap.commit_ledgers()
            rev1,rev2,t1,t2,count1,count2,ledger_total=swap.state()
            require((rev1,rev2)==(1,1),"both real SWAP tiles not committed exactly once")
            require(abs(t1-WINDOW_DAY)<=1e-14 and abs(t2-WINDOW_DAY)<=1e-14,"tile committed times mismatch")
            require((count1,count2)==(1,1),"both tile ledgers not committed exactly once")
            require(math.isfinite(ledger_total),"aggregated ledger exchange nonfinite")
            require(abs(ledger_total-final_q_swap*dt_s)<=1e-16*max(1.0,abs(ledger_total),abs(final_q_swap*dt_s)),"area-weighted ledger transfer differs from accepted aggregate SWAP exchange")
            require(not session.timestep_ready_for_finalize(),"MODFLOW timestep remained publishable")
            require(session.finalize_time_step_once()==PreparedSolveStatus.TIMESTEP_ALREADY_FINALIZED,"second MODFLOW finalization not blocked")
            raw.finalize(); initialized=False

            print(f"FGC45_TILE1_PRED_Q={q1:.17g}")
            print(f"FGC45_TILE2_PRED_Q={q2:.17g}")
            print(f"FGC45_TILE1_PRED_U={u1:.17g}")
            print(f"FGC45_TILE2_PRED_U={u2:.17g}")
            print(f"FGC45_FINAL_HEAD_M={final_head:.17g}")
            print(f"FGC45_FINAL_Q_SWAP_AGG_M_PER_S={final_q_swap:.17g}")
            print(f"FGC45_FINAL_Q_GW_M_PER_S={final_q_gw:.17g}")
            print(f"FGC45_FINAL_FLUX_RESIDUAL={final_q_swap-final_q_gw:.17g}")
            print(f"FGC45_LEDGER_TOTAL_M={ledger_total:.17g}")
            print("FGC45_REAL_TILE_HETEROGENEITY=PASS")
            print("FGC45_FGC40_REAL_AFFINE_CLOSURE=PASS")
            print("FGC45_REAL_MULTISWAP_SAME_ORIGIN_CORRECTORS=PASS")
            print("FGC45_LIVE_MODFLOW680_PREPARED_SOLVE=PASS")
            print("FGC45_N1_CONJUNCTIVE_COUPLING_CONVERGENCE=PASS")
            print("FGC45_ALL_TILE_PREFLIGHTS_BEFORE_PUBLICATION=PASS")
            print("FGC45_MODFLOW_THEN_ALL_SWAP_THEN_ALL_LEDGER_PUBLICATION=PASS")
            print("FGC45_AREA_WEIGHTED_LEDGER_CLOSURE=PASS")
            print("FGC45_REAL_MULTISWAP_N1_END_TO_END=PASS")
        finally:
            if initialized:
                try: raw.finalize()
                except Exception: pass

if __name__=="__main__":
    main()
