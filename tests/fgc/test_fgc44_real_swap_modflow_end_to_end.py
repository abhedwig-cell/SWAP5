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
from fgc44_real_swap_ctypes import Fgc44RealSwap

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

def build_model(workdir:Path, reference_head:float)->None:
    sim=flopy.mf6.MFSimulation(sim_name="FGC44_REAL_E2E",version="mf6",sim_ws=str(workdir))
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
    swaplib=Path(os.environ["FGC44_SWAP_LIB"]).resolve()
    require(libmf6.is_file(),"missing live MODFLOW library")
    require(swaplib.is_file(),"missing real SWAP bridge library")

    swap=Fgc44RealSwap(swaplib)
    hcof,rhs,href=swap.initialize()
    require(math.isfinite(hcof) and math.isfinite(rhs) and math.isfinite(href),"nonfinite real SWAP predictor")
    require(abs(hcof)>0.0,"real SWAP predictor tangent is zero")

    e1=swap.e1_diagnostics()
    require(bool(e1["mass_complete"]),"predictor mass accounting incomplete")
    mass_identity=float(e1["storage_change_native"])-(float(e1["total_in_native"])-float(e1["total_out_native"]))
    require(abs(mass_identity-float(e1["mass_residual_native"]))<=64*np.finfo(float).eps*max(1.0,abs(mass_identity)),
            "predictor mass identity mismatch")
    require(abs(float(e1["storage_end_native"])-float(e1["storage_start_native"])-float(e1["storage_change_native"]))
            <=64*np.finfo(float).eps*max(1.0,abs(float(e1["storage_change_native"]))),
            "predictor storage-change identity mismatch")
    qu_reconstructed=(float(e1["u"])*(float(e1["h_end_m"])-float(e1["h_start_m"]))*100.0/WINDOW_DAY
                      -float(e1["q_bot_predictor_cm_per_day"]))
    require(abs(qu_reconstructed-float(e1["q_u_cm_per_day"]))
            <=128*np.finfo(float).eps*max(1.0,abs(float(e1["q_u_cm_per_day"]))),
            "F-GC30 q_u reconstruction mismatch")

    revision,time_day,ledger_count,ledger_exchange=swap.state()
    origin_state=(revision,time_day,ledger_count,ledger_exchange)
    require(origin_state==(0,0.0,0,0.0),"SWAP/ledger not at accepted origin")

    # E2 real-participant isolation probe: a rejected corrector is a calculation,
    # not accepted hydrological history and not authoritative interface mass.
    probe_q=swap.trial(href)
    probe_diag=swap.last_trial_diagnostics()
    # PB01 follow-up: prospectively sample the immutable-origin real-SWAP corrector
    # around the predictor reference head. These are rejected diagnostic trials only.
    scan=[]
    for dh in (-2e-4,-1e-4,-5e-5,5e-5,1e-4,2e-4):
        qscan=swap.trial(href+dh); scan.append((dh,qscan)); swap.discard()
    for dh,qscan in scan: print(f"FGC44_LOCAL_SCAN_DH_M={dh:.17g} QSWAP={qscan:.17g}")
    require(math.isfinite(probe_q) and all(math.isfinite(v) for v in probe_diag),"nonfinite rejected-trial probe")
    require(swap.state()==origin_state,"rejected trial mutated committed state or ledger before discard")
    swap.discard()
    require(swap.state()==origin_state,"discarded trial mutated committed state or ledger")

    # A prepared publication that is abandoned before the publication point must
    # likewise leave committed state and mass unchanged.
    _=swap.trial(href)
    require(swap.swap_preflight(),"prepublication abort probe SWAP preflight failed")
    swap.prepare_ledger()
    require(swap.ledger_preflight(),"prepublication abort probe ledger preflight failed")
    require(swap.state()==origin_state,"prepared publication changed authoritative state")
    swap.abort_prepublication()
    require(swap.state()==origin_state,"prepublication abort changed authoritative state or mass")

    with tempfile.TemporaryDirectory(prefix="fgc44-e2e-") as tmp:
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
                require(all(math.isfinite(x) for x in (head,q_gw,q_swap,residual)),"nonfinite coupled iterate")
                print(f"FGC44_ITER={outer} H={head:.17g} QSWAP={q_swap:.17g} QGW={q_gw:.17g} RES={residual:.17g} MF={int(it.modflow_converged)}")
                if it.modflow_converged and abs(residual)<=FLUX_TOL:
                    converged=True; final_head=head; final_q_swap=q_swap; final_q_gw=q_gw
                    break
                require(swap.state()==origin_state,"rejected coupled corrector changed authoritative state before discard")
                swap.discard()
                require(swap.state()==origin_state,"discarded coupled corrector changed authoritative state or mass")
                current_rhs=current_hcof*head-q_swap*AREA_M2*DAY_TO_S

            require(converged,"real SWAP + MODFLOW coupling did not converge")
            require(session.finalize_prepared_solve()==PreparedSolveStatus.OK,session.last_error)
            require(kernel.prepare_solve_calls==1 and kernel.finalize_solve_calls==1,"prepared solve lifecycle mismatch")
            require(swap.swap_preflight(),"real SWAP publication preflight failed")
            swap.prepare_ledger()
            require(swap.ledger_preflight(),"real ledger publication preflight failed")
            require(session.timestep_ready_for_finalize(),"live MODFLOW timestep publication preflight failed")
            require(kernel.finalize_time_step_calls==0,"preflight crossed MODFLOW publication point")
            require(swap.state()==origin_state,"publication preflight changed authoritative SWAP/ledger state")

            require(session.finalize_time_step_once()==PreparedSolveStatus.OK,session.last_error)
            require(kernel.finalize_time_step_calls==1,"MODFLOW timestep not finalized exactly once")
            require(swap.state()==origin_state,"MODFLOW publication prematurely changed SWAP/ledger authority")

            swap.commit_swap()
            after_swap_commit=swap.state()
            require(after_swap_commit[0]==1 and abs(after_swap_commit[1]-WINDOW_DAY)<=1e-14,
                    "SWAP publication did not advance revision/time exactly once")
            require(after_swap_commit[2]==0 and after_swap_commit[3]==0.0,
                    "SWAP publication prematurely committed interface ledger")

            final_trial_q,final_bottom_exchange_cm=swap.last_trial_diagnostics()
            require(abs(final_trial_q-final_q_swap)<=64*np.finfo(float).eps*max(1.0,abs(final_q_swap)),
                    "final-trial q diagnostic mismatch")

            swap.commit_ledger()
            revision,time_day,ledger_count,ledger_exchange=swap.state()
            require(revision==1,"real SWAP revision not committed exactly once")
            require(abs(time_day-WINDOW_DAY)<=1e-14,"real SWAP committed time mismatch")
            require(ledger_count==1,"real ledger not committed exactly once")
            require(math.isfinite(ledger_exchange),"real ledger exchange nonfinite")
            require(abs(ledger_exchange-final_bottom_exchange_cm*0.01)
                    <=64*np.finfo(float).eps*max(1.0,abs(ledger_exchange)),
                    "ledger exchange does not equal final accepted SWAP bottom amount")
            public_rate_amount=final_q_swap*WINDOW_DAY*DAY_TO_S
            require(abs(public_rate_amount-ledger_exchange)
                    <=256*np.finfo(float).eps*max(1.0,abs(public_rate_amount),abs(ledger_exchange)),
                    "public q_swap rate and accepted outward ledger amount are inconsistent")
            require(not session.timestep_ready_for_finalize(),"MODFLOW timestep remained publishable")
            require(session.finalize_time_step_once()==PreparedSolveStatus.TIMESTEP_ALREADY_FINALIZED,"second MODFLOW timestep finalization not blocked")
            raw.finalize(); initialized=False

            print(f"FGC44_FINAL_HEAD_M={final_head:.17g}")
            print(f"FGC44_FINAL_Q_SWAP_M_PER_S={final_q_swap:.17g}")
            print(f"FGC44_FINAL_Q_GW_M_PER_S={final_q_gw:.17g}")
            print(f"FGC44_FINAL_FLUX_RESIDUAL={final_q_swap-final_q_gw:.17g}")
            print(f"FGC44_LEDGER_EXCHANGE_M={ledger_exchange:.17g}")
            print(f"PUB_GC_E1_QBOT_PREDICTOR_CM_PER_DAY={float(e1['q_bot_predictor_cm_per_day']):.17g}")
            print(f"PUB_GC_E1_QU_CM_PER_DAY={float(e1['q_u_cm_per_day']):.17g}")
            print(f"PUB_GC_E1_U={float(e1['u']):.17g}")
            print(f"PUB_GC_E1_STORAGE_START_NATIVE={float(e1['storage_start_native']):.17g}")
            print(f"PUB_GC_E1_STORAGE_END_NATIVE={float(e1['storage_end_native']):.17g}")
            print(f"PUB_GC_E1_STORAGE_CHANGE_NATIVE={float(e1['storage_change_native']):.17g}")
            print(f"PUB_GC_E1_TOTAL_IN_NATIVE={float(e1['total_in_native']):.17g}")
            print(f"PUB_GC_E1_TOTAL_OUT_NATIVE={float(e1['total_out_native']):.17g}")
            print(f"PUB_GC_E1_MASS_RESIDUAL_NATIVE={float(e1['mass_residual_native']):.17g}")
            print(f"PUB_GC_E1_FINAL_BOTTOM_EXCHANGE_CM={final_bottom_exchange_cm:.17g}")
            print(f"PUB_GC_E1_PUBLIC_RATE_AMOUNT_M={public_rate_amount:.17g}")
            print("PUB_GC_E1_INTERFACE_IDENTITY=PASS")
            print("PUB_GC_E2_REJECTED_TRIAL_ZERO_AUTHORITY=PASS")
            print("PUB_GC_E2_PREPUBLICATION_ABORT_ZERO_AUTHORITY=PASS")
            print("PUB_GC_E2_EXACTLY_ONCE_PUBLICATION=PASS")
            print("PUB_GC_E2_PUBLICATION_ORDER=PASS")
            print("FGC44_REAL_SWAP_PREDICTOR_ANALYTIC=PASS")
            print("FGC44_REAL_SWAP_CORRECTORS_FROM_ACCEPTED_ORIGIN=PASS")
            print("FGC44_LIVE_MODFLOW680_PREPARED_SOLVE=PASS")
            print("FGC44_CONJUNCTIVE_COUPLING_CONVERGENCE=PASS")
            print("FGC44_ALL_PREFLIGHTS_BEFORE_PUBLICATION=PASS")
            print("FGC44_MODFLOW_THEN_SWAP_THEN_LEDGER_PUBLICATION=PASS")
            print("FGC44_REAL_SWAP_MODFLOW_END_TO_END=PASS")
        finally:
            if initialized:
                try: raw.finalize()
                except Exception: pass

if __name__=="__main__":
    main()
