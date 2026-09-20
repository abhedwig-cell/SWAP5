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
WINDOW_DAY=1.0e-1
WINDOW_COUNT=4
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
    next_window=swap.lib.hydro_memory_dyn02_begin_next_window_c
    next_window.restype=ctypes.c_int
    next_window.argtypes=[
        ctypes.c_double,
        ctypes.POINTER(ctypes.c_double),ctypes.POINTER(ctypes.c_double),ctypes.POINTER(ctypes.c_double),
    ]
    dyn=swap.lib.hydro_memory_dyn02_window_diagnostics_c
    dyn.restype=ctypes.c_int
    dyn.argtypes=[
        ctypes.POINTER(ctypes.c_int),ctypes.POINTER(ctypes.c_int),
        ctypes.POINTER(ctypes.c_double),ctypes.POINTER(ctypes.c_double),
        ctypes.POINTER(ctypes.c_double),ctypes.POINTER(ctypes.c_double),
    ]
    return accuracy,policy,next_window,dyn

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

def dyn02_diagnostics(fn):
    window_index=ctypes.c_int()
    forcing_revision=ctypes.c_int()
    ptra=ctypes.c_double()
    actual=ctypes.c_double()
    top_flux=ctypes.c_double()
    root_sum=ctypes.c_double()
    status=fn(
        ctypes.byref(window_index),ctypes.byref(forcing_revision),
        ctypes.byref(ptra),ctypes.byref(actual),ctypes.byref(top_flux),ctypes.byref(root_sum)
    )
    require(status==0,f"DYN02 forcing diagnostics failed {status}")
    return window_index.value,forcing_revision.value,ptra.value,actual.value,top_flux.value,root_sum.value

def policy_accepts(policy,residual_m:float)->bool:
    accepted=ctypes.c_int()
    status=policy(float(residual_m),ctypes.byref(accepted))
    require(status==0,f"governed head policy failed {status}")
    return bool(accepted.value)

def build_model(workdir:Path, reference_head:float)->None:
    sim=flopy.mf6.MFSimulation(sim_name="HYDRO_MEMORY_DYN02",version="mf6",sim_ws=str(workdir))
    flopy.mf6.ModflowTdis(sim,time_units="DAYS",nper=1,perioddata=[(WINDOW_COUNT*WINDOW_DAY,WINDOW_COUNT,1.0)])
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
    accuracy_fn,policy_fn,next_window_fn,dyn_fn=bind_hydro_memory_api(swap)
    hcof,rhs,href=swap.initialize_configured(WINDOW_DAY,1.0e-6)
    require(all(math.isfinite(v) for v in (hcof,rhs,href)),"nonfinite predictor response")
    require(abs(hcof)>0.0,"root-active predictor tangent is zero")

    h_app_cm,temporal_budget_cm,interface_tol_m,root_total,root_coverage,endpoint_authoritative=accuracy_diagnostics(accuracy_fn)
    require(abs(h_app_cm-0.4)<=1e-15,"H_app drift")
    require(abs(temporal_budget_cm-TEMPORAL_BUDGET_CM)<=1e-15,"temporal budget drift")
    require(abs(interface_tol_m-INTERFACE_TOLERANCE_M)<=1e-15,"interface tolerance drift")
    dyn_initial=dyn02_diagnostics(dyn_fn)
    require(dyn_initial[0]==1 and dyn_initial[1]==0,"initial DYN02 forcing lineage drift")
    # ACC02's root_total slot belongs to the earlier fixed-root qualification ABI.
    # DYN02 root uptake is authoritative only through the per-window recomposition diagnostics.
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

    with tempfile.TemporaryDirectory(prefix="hydro-memory-dyn02-") as tmp:
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
            binding=[Binding(7001,1,2)]
            current_hcof=hcof
            current_rhs=rhs
            window_metrics=[]
            cumulative_expected_ledger=0.0

            for window_index in range(1,WINDOW_COUNT+1):
                dyn_before=dyn02_diagnostics(dyn_fn)
                expected_ptra=0.4 if window_index<=2 else 0.3
                expected_top=0.0 if window_index<=2 else -0.5
                require(dyn_before[0]==window_index,
                        f"forcing window index drift {window_index}: {dyn_before[0]}")
                require(dyn_before[1]==window_index-1,
                        f"forcing committed revision drift {window_index}: {dyn_before[1]}")
                require(abs(dyn_before[2]-expected_ptra)<=1e-14,
                        f"potential transpiration drift window {window_index}: {dyn_before[2]}")
                require(abs(dyn_before[4]-expected_top)<=1e-14,
                        f"top flux drift window {window_index}: {dyn_before[4]}")
                require(math.isfinite(dyn_before[3]) and 0.0<=dyn_before[3]<=dyn_before[2]+1e-14,
                        f"actual uptake outside potential window {window_index}: {dyn_before[3]}")
                require(abs(dyn_before[5]-dyn_before[3])<=1e-14*max(1.0,abs(dyn_before[3])),
                        f"root sink sum mismatch window {window_index}")

                pred=swap.predictor_run_diagnostics()
                require(bool(pred["available"]) and bool(pred["completed"]) and bool(pred["direction_available"]),
                        f"predictor diagnostic availability incomplete window {window_index}")
                require(int(pred["temporal_unavailable_rejections"])==0,
                        f"predictor temporal certificate unavailable window {window_index}")
                require(float(pred["max_temporal_indicator"])<=1.0+64*np.finfo(float).eps,
                        f"accepted predictor temporal indicator exceeded governed budget window {window_index}")

                e1=swap.e1_diagnostics()
                require(bool(e1["mass_complete"]),f"predictor mass incomplete window {window_index}")
                require(abs(float(e1["mass_residual_native"]))<=MASS_TOL_CM,
                        f"predictor hard mass exceeded window {window_index}")

                revision,time_day,ledger_count,ledger_exchange=swap.state()
                expected_origin_revision=window_index-1
                expected_origin_time=(window_index-1)*WINDOW_DAY
                require(revision==expected_origin_revision,
                        f"origin revision drift window {window_index}: {revision}")
                require(abs(time_day-expected_origin_time)<=128*np.finfo(float).eps*max(1.0,abs(expected_origin_time)),
                        f"origin time drift window {window_index}: {time_day}")
                require(ledger_count==expected_origin_revision,
                        f"origin ledger count drift window {window_index}: {ledger_count}")
                origin_state=(revision,time_day,ledger_count,ledger_exchange)

                raw.prepare_time_step(0.0)
                session=Modflow6PreparedSolveSession(kernel,"GWF_1","API_SWAP",publisher,solution_id=1)
                require(session.acquire_after_prepare_time_step()==PreparedSolveStatus.OK,session.last_error)
                require(session.open_prepared_solve()==PreparedSolveStatus.OK,session.last_error)
                accepted_xold=session.accepted_xold.copy()

                converged=False
                final_h_swap=final_h_groundwater=final_q_swap=final_q_package=None
                final_head_residual=final_flux_residual=None
                coupling_iterations=0

                for outer in range(1,MAX_COUPLING_ITERATIONS+1):
                    status,it=session.publish_and_solve_iteration(binding,[Term(7001,current_hcof,current_rhs)])
                    require(status==PreparedSolveStatus.OK,session.last_error)
                    require(it is not None,f"missing MODFLOW input iterate w{window_index} i{outer}")
                    require(np.array_equal(it.accepted_head_old_m,accepted_xold),
                            f"MODFLOW XOLD drifted w{window_index} i{outer}")
                    h_swap=float(it.head_m[1])

                    q_swap=swap.trial(h_swap)
                    require(math.isfinite(q_swap),f"nonfinite SWAP flux w{window_index} i{outer}")
                    require(dyn02_diagnostics(dyn_fn)==dyn_before,
                            f"same-origin corrector changed frozen forcing/root sink w{window_index} i{outer}")
                    updated_rhs=current_hcof*h_swap-q_swap*AREA_M2*DAY_TO_S

                    status,it2=session.publish_and_solve_iteration(binding,[Term(7001,current_hcof,updated_rhs)])
                    require(status==PreparedSolveStatus.OK,session.last_error)
                    require(it2 is not None,f"missing MODFLOW return iterate w{window_index} i{outer}")
                    require(np.array_equal(it2.accepted_head_old_m,accepted_xold),
                            f"MODFLOW XOLD drifted on return w{window_index} i{outer}")
                    h_groundwater=float(it2.head_m[1])
                    q_package=(current_hcof*h_groundwater-updated_rhs)/(AREA_M2*DAY_TO_S)
                    head_residual=h_swap-h_groundwater
                    flux_residual=q_swap-q_package
                    head_ok=policy_accepts(policy_fn,head_residual)
                    require(all(math.isfinite(v) for v in
                                (h_swap,h_groundwater,q_swap,q_package,head_residual,flux_residual)),
                            f"nonfinite coupled iterate w{window_index} i{outer}")
                    print(
                        f"HYDRO_MEMORY_DYN02_ITER window={window_index} iter={outer} "
                        f"HSWAP={h_swap:.17g} HGW={h_groundwater:.17g} "
                        f"HRES={head_residual:.17g} QSWAP={q_swap:.17g} "
                        f"QPKG={q_package:.17g} QRES={flux_residual:.17g} HOK={int(head_ok)}"
                    )

                    if head_ok and abs(flux_residual)<=FLUX_ITER_TOL:
                        converged=True
                        coupling_iterations=outer
                        final_h_swap=h_swap
                        final_h_groundwater=h_groundwater
                        final_q_swap=q_swap
                        final_q_package=q_package
                        final_head_residual=head_residual
                        final_flux_residual=flux_residual
                        current_rhs=updated_rhs
                        break

                    require(swap.state()==origin_state,
                            f"intermediate corrector mutated authority w{window_index} i{outer}")
                    swap.discard()
                    require(swap.state()==origin_state,
                            f"discard mutated authority w{window_index} i{outer}")
                    require(dyn02_diagnostics(dyn_fn)==dyn_before,
                            f"discard changed frozen forcing/root sink w{window_index} i{outer}")
                    current_rhs=updated_rhs

                require(converged,f"live coupling did not converge within six iterations window {window_index}")
                require(abs(float(final_head_residual))<=INTERFACE_TOLERANCE_M,
                        f"final head residual exceeds policy window {window_index}")
                require(policy_accepts(policy_fn,float(final_head_residual)),
                        f"policy rejected final head residual window {window_index}")

                require(session.finalize_prepared_solve()==PreparedSolveStatus.OK,session.last_error)
                require(swap.swap_preflight(),f"SWAP publication preflight failed window {window_index}")
                swap.prepare_ledger()
                require(swap.ledger_preflight(),f"ledger preflight failed window {window_index}")
                require(session.timestep_ready_for_finalize(),f"MODFLOW timestep not ready window {window_index}")
                require(swap.state()==origin_state,f"preflight mutated authority window {window_index}")

                finalize_count_before=kernel.finalize_time_step_calls
                require(session.finalize_time_step_once()==PreparedSolveStatus.OK,session.last_error)
                require(kernel.finalize_time_step_calls==finalize_count_before+1,
                        f"MODFLOW timestep not finalized once window {window_index}")
                require(swap.state()==origin_state,
                        f"MODFLOW publication changed SWAP/ledger authority window {window_index}")

                swap.commit_swap()
                after_swap=swap.state()
                require(after_swap[0]==window_index,
                        f"SWAP revision not monotone window {window_index}")
                expected_time=window_index*WINDOW_DAY
                require(abs(after_swap[1]-expected_time)<=128*np.finfo(float).eps*max(1.0,abs(expected_time)),
                        f"SWAP committed time mismatch window {window_index}")
                require(after_swap[2]==window_index-1,
                        f"SWAP commit prematurely changed ledger window {window_index}")

                final_trial_q,final_bottom_exchange_cm=swap.last_trial_diagnostics()
                require(abs(final_trial_q-float(final_q_swap))<=64*np.finfo(float).eps*max(1.0,abs(float(final_q_swap))),
                        f"final trial diagnostic mismatch window {window_index}")
                cumulative_expected_ledger += final_bottom_exchange_cm*0.01

                swap.commit_ledger()
                revision,time_day,ledger_count,ledger_exchange=swap.state()
                require(revision==window_index,f"post-ledger revision mismatch window {window_index}")
                require(abs(time_day-expected_time)<=128*np.finfo(float).eps*max(1.0,abs(expected_time)),
                        f"post-ledger time mismatch window {window_index}")
                require(ledger_count==window_index,f"ledger count mismatch window {window_index}")
                require(abs(ledger_exchange-cumulative_expected_ledger)
                        <=128*np.finfo(float).eps*max(1.0,abs(ledger_exchange),abs(cumulative_expected_ledger)),
                        f"cumulative ledger mismatch window {window_index}")
                require(session.finalize_time_step_once()==PreparedSolveStatus.TIMESTEP_ALREADY_FINALIZED,
                        f"second MODFLOW finalization not blocked window {window_index}")

                mf_time=float(raw.get_current_time())
                require(abs(mf_time-expected_time)<=1e-12*max(1.0,abs(expected_time)),
                        f"MODFLOW current-time mismatch window {window_index}: {mf_time}")

                window_metrics.append({
                    "window":window_index,
                    "iterations":coupling_iterations,
                    "accepted_substeps":int(pred["accepted_substeps"]),
                    "retries":int(pred["retries"]),
                    "max_temporal_indicator":float(pred["max_temporal_indicator"]),
                    "h_swap":float(final_h_swap),
                    "h_groundwater":float(final_h_groundwater),
                    "head_residual":float(final_head_residual),
                    "flux_residual":float(final_flux_residual),
                    "ledger":float(ledger_exchange),
                    "mf_time":mf_time,
                    "ptra":float(dyn_before[2]),
                    "actual_uptake":float(dyn_before[3]),
                    "top_flux":float(dyn_before[4]),
                    "root_sum":float(dyn_before[5]),
                })
                print(
                    f"HYDRO_MEMORY_DYN02_WINDOW={window_index} "
                    f"REV={revision} TIME={time_day:.17g} LEDGER_COUNT={ledger_count} "
                    f"LEDGER={ledger_exchange:.17g} ITER={coupling_iterations} "
                    f"TIND={float(pred['max_temporal_indicator']):.17g} "
                    f"HRES={float(final_head_residual):.17g} QRES={float(final_flux_residual):.17g} "
                    f"PTRA={dyn_before[2]:.17g} AUP={dyn_before[3]:.17g} TOP={dyn_before[4]:.17g}"
                )

                if window_index<WINDOW_COUNT:
                    nhcof=ctypes.c_double()
                    nrhs=ctypes.c_double()
                    nref=ctypes.c_double()
                    status=next_window_fn(
                        float(final_h_groundwater),
                        ctypes.byref(nhcof),ctypes.byref(nrhs),ctypes.byref(nref)
                    )
                    require(status==0,f"next-window predictor failed after window {window_index}: {status}")
                    require(all(math.isfinite(v) for v in (nhcof.value,nrhs.value,nref.value)),
                            f"next-window predictor nonfinite after window {window_index}")
                    require(abs(nhcof.value)>0.0,f"next-window tangent zero after window {window_index}")
                    current_hcof=nhcof.value
                    current_rhs=nrhs.value
                    h_app_cm2,temporal_budget_cm2,interface_tol_m2,root_total2,root_coverage2,endpoint_authoritative2=accuracy_diagnostics(accuracy_fn)
                    require(abs(h_app_cm2-0.4)<=1e-15 and
                            abs(temporal_budget_cm2-TEMPORAL_BUDGET_CM)<=1e-15 and
                            abs(interface_tol_m2-INTERFACE_TOLERANCE_M)<=1e-15,
                            f"governed accuracy drift after window {window_index}")
                    dyn_next=dyn02_diagnostics(dyn_fn)
                    require(dyn_next[0]==window_index+1 and dyn_next[1]==window_index,
                            f"next-window recomposition lineage drift after window {window_index}: {dyn_next[:2]}")
                    require(root_coverage2 and endpoint_authoritative2,
                            f"root/tangent authority drift after window {window_index}")

            raw.finalize()
            initialized=False

            require([m["window"] for m in window_metrics]==[1,2,3,4],"window sequence drift")
            require(max(m["max_temporal_indicator"] for m in window_metrics)<=1.0+64*np.finfo(float).eps,
                    "multi-window temporal maximum exceeded governed budget")
            require(max(abs(m["head_residual"]) for m in window_metrics)<=INTERFACE_TOLERANCE_M,
                    "multi-window head maximum exceeded policy")
            require(max(abs(m["flux_residual"]) for m in window_metrics)<=FLUX_ITER_TOL,
                    "multi-window flux maximum exceeded frozen criterion")
            require(max(m["iterations"] for m in window_metrics)<=MAX_COUPLING_ITERATIONS,
                    "multi-window iteration ceiling exceeded")

            print(f"HYDRO_MEMORY_DYN02_H_APP_CM={h_app_cm:.17g}")
            print(f"HYDRO_MEMORY_DYN02_TEMPORAL_BUDGET_CM={temporal_budget_cm:.17g}")
            print(f"HYDRO_MEMORY_DYN02_INTERFACE_TOLERANCE_M={interface_tol_m:.17g}")
            print(f"HYDRO_MEMORY_DYN02_INITIAL_ACTUAL_UPTAKE_CM_PER_DAY={dyn_initial[3]:.17g}")
            print(f"HYDRO_MEMORY_DYN02_MAX_TEMPORAL_INDICATOR={max(m['max_temporal_indicator'] for m in window_metrics):.17g}")
            print(f"HYDRO_MEMORY_DYN02_MAX_HEAD_RESIDUAL_M={max(abs(m['head_residual']) for m in window_metrics):.17g}")
            print(f"HYDRO_MEMORY_DYN02_MAX_FLUX_RESIDUAL={max(abs(m['flux_residual']) for m in window_metrics):.17g}")
            print(f"HYDRO_MEMORY_DYN02_FINAL_REVISION={window_metrics[-1]['window']}")
            print(f"HYDRO_MEMORY_DYN02_FINAL_TIME_DAY={window_metrics[-1]['mf_time']:.17g}")
            print(f"HYDRO_MEMORY_DYN02_FINAL_LEDGER_EXCHANGE_M={window_metrics[-1]['ledger']:.17g}")
            print("HYDRO_MEMORY_DYN02_PTRA_SEQUENCE="+",".join(f"{m['ptra']:.17g}" for m in window_metrics))
            print("HYDRO_MEMORY_DYN02_ACTUAL_UPTAKE_SEQUENCE="+",".join(f"{m['actual_uptake']:.17g}" for m in window_metrics))
            print("HYDRO_MEMORY_DYN02_TOP_FLUX_SEQUENCE="+",".join(f"{m['top_flux']:.17g}" for m in window_metrics))
            print("HYDRO_MEMORY_DYN02_PERSISTENT_SWAPP_STATE=PASS")
            print("HYDRO_MEMORY_DYN02_DYNAMIC_PREDICTOR_ORIGIN=PASS")
            print("HYDRO_MEMORY_DYN02_REVISION_TIME_LEDGER_SEQUENCE=PASS")
            print("HYDRO_MEMORY_DYN02_GOVERNED_ACCURACY=PASS")
            print("HYDRO_MEMORY_DYN02_LIVE_MODFLOW680=PASS")
            require([m["ptra"] for m in window_metrics]==[0.4,0.4,0.3,0.3],
                    "DYN02 ptra sequence drift")
            require(all(abs(a-b)<=1e-14 for a,b in zip([m["top_flux"] for m in window_metrics],[0.0,0.0,-0.5,-0.5])),
                    "DYN02 top-flux sequence drift")
            print("HYDRO_MEMORY_DYN02_EXACT_ONCE_PUBLICATION=PASS")
            print("HYDRO_MEMORY_DYN02_WINDOW_FORCING_IMMUTABLE=PASS")
            print("HYDRO_MEMORY_DYN02_ACCEPTED_STATE_RECOMPOSITION=PASS")
            print("HYDRO_MEMORY_DYN02_DROUGHT_RECOVERY_FORCING_SEQUENCE=PASS")
            print("HYDRO_MEMORY_DYN02_GATE=PASS")
        finally:
            if initialized:
                try:
                    raw.finalize()
                except Exception:
                    pass

if __name__=="__main__":
    main()
