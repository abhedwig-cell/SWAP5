from __future__ import annotations
import ctypes
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
ROOT_TOTAL_CM_PER_DAY=2.0e-2
TEMPORAL_BUDGET_CM=1.0e-1
INTERFACE_TOLERANCE_M=1.0e-3
FLUX_ITER_TOL=1.0e-15
MAX_COUPLING_ITERATIONS=6
MASS_TOL_CM=1.0e-12

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
        self.prepare_solve_calls+=1
        self.kernel.prepare_solve(solution_id)
    def solve(self,solution_id:int)->bool:
        self.solve_calls+=1
        return bool(self.kernel.solve(solution_id))
    def finalize_solve(self,solution_id:int)->None:
        self.finalize_solve_calls+=1
        self.kernel.finalize_solve(solution_id)
    def finalize_time_step(self)->None:
        self.finalize_time_step_calls+=1
        self.kernel.finalize_time_step()

def require(x:bool,msg:str)->None:
    if not x:
        raise AssertionError(msg)

def bind_hydro_memory_api(swap:Fgc44RealSwap):
    accuracy=swap.lib.hydro_memory_acc02_accuracy_c
    accuracy.restype=ctypes.c_int
    accuracy.argtypes=[
        ctypes.POINTER(ctypes.c_double),ctypes.POINTER(ctypes.c_double),
        ctypes.POINTER(ctypes.c_double),ctypes.POINTER(ctypes.c_double),
        ctypes.POINTER(ctypes.c_int),ctypes.POINTER(ctypes.c_int),
    ]
    policy=swap.lib.hydro_memory_acc02_head_policy_c
    policy.restype=ctypes.c_int
    policy.argtypes=[ctypes.c_double,ctypes.POINTER(ctypes.c_int)]
    return accuracy,policy

def accuracy_diagnostics(accuracy):
    h_app=ctypes.c_double()
    temporal=ctypes.c_double()
    interface=ctypes.c_double()
    root_total=ctypes.c_double()
    root_coverage=ctypes.c_int()
    endpoint_authoritative=ctypes.c_int()
    status=accuracy(
        ctypes.byref(h_app),ctypes.byref(temporal),ctypes.byref(interface),
        ctypes.byref(root_total),ctypes.byref(root_coverage),ctypes.byref(endpoint_authoritative)
    )
    require(status==0,f"accuracy diagnostic failed {status}")
    return h_app.value,temporal.value,interface.value,root_total.value,bool(root_coverage.value),bool(endpoint_authoritative.value)

def policy_accepts(policy,residual_m:float)->bool:
    accepted=ctypes.c_int()
    status=policy(float(residual_m),ctypes.byref(accepted))
    require(status==0,f"governed head policy failed {status}")
    return bool(accepted.value)

def build_model(workdir:Path, reference_head:float)->None:
    sim=flopy.mf6.MFSimulation(sim_name="HYDRO_MEMORY_ACC02_F1",version="mf6",sim_ws=str(workdir))
    flopy.mf6.ModflowTdis(sim,time_units="DAYS",nper=1,perioddata=[(WINDOW_DAY,1,1.0)])
    flopy.mf6.ModflowIms(sim,complexity="MODERATE",outer_dvclose=1e-10,inner_dvclose=1e-10,
                        outer_maximum=100,inner_maximum=100)
    gwf=flopy.mf6.ModflowGwf(sim,modelname="GWF_1",save_flows=True,newtonoptions="NEWTON")
    flopy.mf6.ModflowGwfdis(gwf,nlay=1,nrow=1,ncol=3,delr=1.0,delc=1.0,top=0.0,botm=-2.0)
    flopy.mf6.ModflowGwfic(gwf,strt=reference_head)
    flopy.mf6.ModflowGwfnpf(gwf,icelltype=1,k=1.0,save_flows=True)
    flopy.mf6.ModflowGwfsto(gwf,iconvert=1,ss=0.02,sy=0.15,transient={0:True})
    flopy.mf6.ModflowGwfchd(
        gwf,
        stress_period_data={0:[((0,0,0),reference_head+0.002),((0,0,2),reference_head-0.002)]},
        pname="CHD_ENDS",
    )
    flopy.mf6.ModflowGwfapi(gwf,maxbound=1,pname="API_SWAP",filename="api_swap.api")
    sim.write_simulation(silent=True)

def main()->None:
    libmf6=Path(os.environ["LIBMF6"]).resolve()
    swaplib=Path(os.environ["FGC44_SWAP_LIB"]).resolve()
    require(libmf6.is_file(),"missing live MODFLOW library")
    require(swaplib.is_file(),"missing governed root-active SWAP bridge")

    swap=Fgc44RealSwap(swaplib)
    accuracy_fn,policy_fn=bind_hydro_memory_api(swap)
    hcof,rhs,href=swap.initialize()
    require(all(math.isfinite(v) for v in (hcof,rhs,href)),"nonfinite predictor response")
    require(abs(hcof)>0.0,"root-active predictor tangent is zero")

    h_app_cm,temporal_budget_cm,interface_tol_m,root_total,root_coverage,endpoint_authoritative=accuracy_diagnostics(accuracy_fn)
    require(abs(h_app_cm-0.4)<=1e-15,"H_app drift")
    require(abs(temporal_budget_cm-TEMPORAL_BUDGET_CM)<=1e-15,"temporal budget drift")
    require(abs(interface_tol_m-INTERFACE_TOLERANCE_M)<=1e-15,"interface tolerance drift")
    require(abs(root_total-ROOT_TOTAL_CM_PER_DAY)<=1e-15,"root sink drift")
    require(root_coverage,"prescribed-root trajectory coverage missing")
    require(endpoint_authoritative,"root-active predictor endpoint not authoritative")
    require(policy_accepts(policy_fn,INTERFACE_TOLERANCE_M),"policy rejected boundary tolerance")
    require(not policy_accepts(policy_fn,np.nextafter(INTERFACE_TOLERANCE_M,math.inf)),
            "policy accepted residual above governed tolerance")

    pred=swap.predictor_run_diagnostics()
    require(bool(pred["available"]) and bool(pred["completed"]) and bool(pred["direction_available"]),
            "predictor diagnostic availability incomplete")
    require(int(pred["temporal_unavailable_rejections"])==0,"predictor temporal certificate unavailable")
    require(float(pred["max_temporal_indicator"])<=1.0+64*np.finfo(float).eps,
            "accepted predictor temporal indicator exceeded governed budget")

    e1=swap.e1_diagnostics()
    require(bool(e1["mass_complete"]),"predictor mass accounting incomplete")
    require(abs(float(e1["mass_residual_native"]))<=MASS_TOL_CM,"predictor hard mass residual exceeded")
    mass_identity=float(e1["storage_change_native"])-(float(e1["total_in_native"])-float(e1["total_out_native"]))
    require(abs(mass_identity-float(e1["mass_residual_native"]))<=64*np.finfo(float).eps*max(1.0,abs(mass_identity)),
            "predictor mass identity mismatch")

    revision,time_day,ledger_count,ledger_exchange=swap.state()
    origin_state=(revision,time_day,ledger_count,ledger_exchange)
    require(origin_state==(0,0.0,0,0.0),"SWAP/ledger not at accepted origin")

    with tempfile.TemporaryDirectory(prefix="hydro-memory-acc02-f1-") as tmp:
        workdir=Path(tmp)
        build_model(workdir,href)
        raw=XmiWrapper(lib_path=libmf6,working_directory=workdir)
        kernel=CountingKernel(raw)
        publisher=Fgc34CtypesPublisher(swaplib)
        initialized=False
        try:
            raw.initialize()
            initialized=True
            require("6.8.0" in raw.get_version(),"wrong MODFLOW version")
            raw.prepare_time_step(0.0)
            session=Modflow6PreparedSolveSession(kernel,"GWF_1","API_SWAP",publisher,solution_id=1)
            require(session.acquire_after_prepare_time_step()==PreparedSolveStatus.OK,session.last_error)
            require(session.open_prepared_solve()==PreparedSolveStatus.OK,session.last_error)
            accepted_xold=session.accepted_xold.copy()
            binding=[Binding(7001,1,2)]
            current_hcof=hcof
            current_rhs=rhs
            final_h_swap=None
            final_h_groundwater=None
            final_q_swap=None
            final_q_package=None
            final_head_residual=None
            final_flux_residual=None
            converged=False

            for outer in range(1,MAX_COUPLING_ITERATIONS+1):
                status,it=session.publish_and_solve_iteration(binding,[Term(7001,current_hcof,current_rhs)])
                require(status==PreparedSolveStatus.OK,session.last_error)
                require(it is not None,f"missing MODFLOW input-head iterate {outer}")
                require(np.array_equal(it.accepted_head_old_m,accepted_xold),"MODFLOW XOLD drifted")
                h_swap=float(it.head_m[1])

                q_swap=swap.trial(h_swap)
                require(math.isfinite(q_swap),"nonfinite root-active SWAP flux")
                updated_rhs=current_hcof*h_swap-q_swap*AREA_M2*DAY_TO_S

                status,it2=session.publish_and_solve_iteration(binding,[Term(7001,current_hcof,updated_rhs)])
                require(status==PreparedSolveStatus.OK,session.last_error)
                require(it2 is not None,f"missing MODFLOW return-head iterate {outer}")
                require(np.array_equal(it2.accepted_head_old_m,accepted_xold),"MODFLOW XOLD drifted on return solve")
                h_groundwater=float(it2.head_m[1])
                q_package=(current_hcof*h_groundwater-updated_rhs)/(AREA_M2*DAY_TO_S)

                head_residual=h_swap-h_groundwater
                flux_residual=q_swap-q_package
                head_ok=policy_accepts(policy_fn,head_residual)
                require(all(math.isfinite(v) for v in (h_swap,h_groundwater,q_swap,q_package,head_residual,flux_residual)),
                        "nonfinite coupled iterate")
                print(
                    f"HYDRO_MEMORY_ACC02_F1_ITER={outer} "
                    f"HSWAP={h_swap:.17g} HGW={h_groundwater:.17g} "
                    f"HRES={head_residual:.17g} QSWAP={q_swap:.17g} "
                    f"QPKG={q_package:.17g} QRES={flux_residual:.17g} HOK={int(head_ok)}"
                )

                if bool(it.modflow_converged) and bool(it2.modflow_converged) and head_ok and abs(flux_residual)<=FLUX_ITER_TOL:
                    converged=True
                    final_h_swap=h_swap
                    final_h_groundwater=h_groundwater
                    final_q_swap=q_swap
                    final_q_package=q_package
                    final_head_residual=head_residual
                    final_flux_residual=flux_residual
                    current_rhs=updated_rhs
                    break

                require(swap.state()==origin_state,"rejected coupled corrector changed authoritative state")
                swap.discard()
                require(swap.state()==origin_state,"discarded coupled corrector changed authoritative state")
                current_rhs=updated_rhs

            require(converged,"root-active live coupling did not satisfy governed convergence within six iterations")
            require(abs(float(final_head_residual))<=INTERFACE_TOLERANCE_M,
                    "final canonical head residual exceeds governed tolerance")
            require(policy_accepts(policy_fn,float(final_head_residual)),
                    "canonical policy rejected final head residual")

            require(session.finalize_prepared_solve()==PreparedSolveStatus.OK,session.last_error)
            require(kernel.prepare_solve_calls==1 and kernel.finalize_solve_calls==1,
                    "prepared solve lifecycle mismatch")
            require(swap.swap_preflight(),"root-active SWAP publication preflight failed")
            swap.prepare_ledger()
            require(swap.ledger_preflight(),"root-active ledger publication preflight failed")
            require(session.timestep_ready_for_finalize(),"live MODFLOW timestep publication preflight failed")
            require(kernel.finalize_time_step_calls==0,"preflight crossed MODFLOW publication point")
            require(swap.state()==origin_state,"publication preflight changed authoritative SWAP/ledger state")

            require(session.finalize_time_step_once()==PreparedSolveStatus.OK,session.last_error)
            require(kernel.finalize_time_step_calls==1,"MODFLOW timestep not finalized exactly once")
            require(swap.state()==origin_state,"MODFLOW publication prematurely changed SWAP/ledger authority")

            swap.commit_swap()
            after_swap=swap.state()
            require(after_swap[0]==1 and abs(after_swap[1]-WINDOW_DAY)<=1e-14,
                    "SWAP did not commit exactly one governed window")
            require(after_swap[2]==0 and after_swap[3]==0.0,
                    "SWAP commit prematurely committed ledger")

            final_trial_q,final_bottom_exchange_cm=swap.last_trial_diagnostics()
            require(abs(final_trial_q-float(final_q_swap))<=64*np.finfo(float).eps*max(1.0,abs(float(final_q_swap))),
                    "final root-active trial flux diagnostic mismatch")

            swap.commit_ledger()
            revision,time_day,ledger_count,ledger_exchange=swap.state()
            require(revision==1 and abs(time_day-WINDOW_DAY)<=1e-14,
                    "accepted SWAP revision/time mismatch")
            require(ledger_count==1,"interface ledger not committed exactly once")
            require(abs(ledger_exchange-final_bottom_exchange_cm*0.01)
                    <=64*np.finfo(float).eps*max(1.0,abs(ledger_exchange)),
                    "ledger exchange mismatch")
            require(not session.timestep_ready_for_finalize(),"MODFLOW timestep remained publishable")
            require(session.finalize_time_step_once()==PreparedSolveStatus.TIMESTEP_ALREADY_FINALIZED,
                    "second MODFLOW finalization was not blocked")

            raw.finalize()
            initialized=False

            print(f"HYDRO_MEMORY_ACC02_F1_H_APP_CM={h_app_cm:.17g}")
            print(f"HYDRO_MEMORY_ACC02_F1_TEMPORAL_BUDGET_CM={temporal_budget_cm:.17g}")
            print(f"HYDRO_MEMORY_ACC02_F1_INTERFACE_TOLERANCE_M={interface_tol_m:.17g}")
            print(f"HYDRO_MEMORY_ACC02_F1_ROOT_TOTAL_CM_PER_DAY={root_total:.17g}")
            print(f"HYDRO_MEMORY_ACC02_F1_ACCEPTED_SUBSTEPS={int(pred['accepted_substeps'])}")
            print(f"HYDRO_MEMORY_ACC02_F1_PREDICTOR_RETRIES={int(pred['retries'])}")
            print(f"HYDRO_MEMORY_ACC02_F1_MAX_TEMPORAL_INDICATOR={float(pred['max_temporal_indicator']):.17g}")
            print(f"HYDRO_MEMORY_ACC02_F1_FINAL_H_SWAP_M={float(final_h_swap):.17g}")
            print(f"HYDRO_MEMORY_ACC02_F1_FINAL_H_GROUNDWATER_M={float(final_h_groundwater):.17g}")
            print(f"HYDRO_MEMORY_ACC02_F1_HEAD_RESIDUAL_M={float(final_head_residual):.17g}")
            print(f"HYDRO_MEMORY_ACC02_F1_LIVE_PACKAGE_FLUX_RESIDUAL={float(final_flux_residual):.17g}")
            print(f"HYDRO_MEMORY_ACC02_F1_LEDGER_EXCHANGE_M={ledger_exchange:.17g}")
            print("HYDRO_MEMORY_ACC02_F1_GOVERNED_ACCURACY_BINDING=PASS")
            print("HYDRO_MEMORY_ACC02_F1_PRESCRIBED_ROOT_TANGENT=PASS")
            print("HYDRO_MEMORY_ACC02_F1_TEMPORAL_BUDGET=PASS")
            print("HYDRO_MEMORY_ACC02_F1_LIVE_MODFLOW680=PASS")
            print("HYDRO_MEMORY_ACC02_F1_INTERFACE_HEAD_POLICY=PASS")
            print("HYDRO_MEMORY_ACC02_F1_HARD_MASS=PASS")
            print("HYDRO_MEMORY_ACC02_F1_PUBLICATION_ORDER=PASS")
            print("HYDRO_MEMORY_ACC02_F1_GATE=PASS")
        finally:
            if initialized:
                try:
                    raw.finalize()
                except Exception:
                    pass

if __name__=="__main__":
    main()
