from __future__ import annotations

import ctypes
import json
import math
import os
import sys
import tempfile
import time
from pathlib import Path

import numpy as np
from xmipy import XmiWrapper

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/"tests"/"fgc"))
sys.path.insert(0,str(ROOT/"tests"/"fgc"/"support"))
sys.path.insert(0,str(ROOT/"src"/"adapter"))

from test_fgc44_real_swap_modflow_end_to_end import (
    AREA_M2, DAY_TO_S, FLUX_TOL, Binding, Term, CountingKernel, build_model, require
)
from fgc44_real_swap_ctypes import Fgc44RealSwap
from modflow6_fgc34_ctypes_publisher import Fgc34CtypesPublisher
from modflow6_prepared_solve_session import Modflow6PreparedSolveSession, PreparedSolveStatus

MATERIALS={
    "B01":(0.02,0.427494,0.021659,1.734737,31.225016,0.98087),
    "B12":(0.01,0.529749,0.016562,1.090671,2.245895,-4.493581),
    "O05":(0.01,0.336701,0.030304,2.887502,17.418504,0.0736),
    "O14":(0.01,0.393878,0.003288,1.616573,2.495984,0.514012),
}
DT=1.0e-4

def _temporal_diag(swap:Fgc44RealSwap)->dict[str,int|float]:
    fn=swap.lib.fgc44_temporal04_diagnostics_c
    fn.restype=ctypes.c_int
    ints=[ctypes.c_int() for _ in range(8)]
    mt=ctypes.c_double()
    fn.argtypes=[*([ctypes.POINTER(ctypes.c_int)]*8),ctypes.POINTER(ctypes.c_double)]
    status=fn(*[ctypes.byref(v) for v in ints],ctypes.byref(mt))
    if status: raise RuntimeError("temporal diagnostics failed")
    keys=("transaction_calls","accepted_substeps","attempts","retries","solver_rejections",
          "temporal_rejections","nonlinear_iterations","backtracking_attempts")
    out={k:v.value for k,v in zip(keys,ints)}
    out["max_temporal_indicator"]=mt.value
    return out

def main()->None:
    if len(sys.argv)!=4:
        raise SystemExit("usage: MATERIAL H0 IMBALANCE")
    material=sys.argv[1]
    h0=float(sys.argv[2])
    imbalance=float(sys.argv[3])
    if material not in MATERIALS:
        raise SystemExit("invalid material")

    libmf6=Path(os.environ["LIBMF6"]).resolve()
    swaplib=Path(os.environ["FGC44_SWAP_LIB"]).resolve()
    swap=Fgc44RealSwap(swaplib)

    cfg=swap.lib.fgc44_approx04_configure_case_c
    cfg.restype=ctypes.c_int
    cfg.argtypes=[ctypes.c_double]*7
    tr,ts,alpha,nvg,ksat,lamb=MATERIALS[material]
    if cfg(h0,tr,ts,alpha,nvg,ksat,lamb):
        raise RuntimeError("configure case failed")

    predfn=swap.lib.fgc44_approx04_predictor_q_c
    predfn.restype=ctypes.c_int
    predfn.argtypes=[ctypes.POINTER(ctypes.c_double)]
    predictor_q=ctypes.c_double()
    if predfn(ctypes.byref(predictor_q)):
        raise RuntimeError("predictor q failed")
    swap.initialize_configured(DT,predictor_q.value)

    dyn=swap.lib.fgc44_temporal03_dynamic_origin_c
    dyn.restype=ctypes.c_int
    dyn.argtypes=[ctypes.c_double,*([ctypes.POINTER(ctypes.c_double)]*3)]
    rate=ctypes.c_double(); origin_mass=ctypes.c_double(); origin_head=ctypes.c_double()
    if dyn(imbalance,ctypes.byref(rate),ctypes.byref(origin_mass),ctypes.byref(origin_head)):
        raise RuntimeError("dynamic origin failed")

    budget=max(1.0e-5,0.50*DT*rate.value)
    bfn=swap.lib.fgc44_temporal04_budget_c
    bfn.restype=ctypes.c_int
    bfn.argtypes=[ctypes.c_double]
    if bfn(budget):
        raise RuntimeError("temporal budget configure failed")

    cachefn=swap.lib.fgc44_temporal06_tangent_cache_c
    cachefn.restype=ctypes.c_int
    cachefn.argtypes=[ctypes.c_int]
    if cachefn(0):
        raise RuntimeError("tangent cache configure failed")

    # Untimed exact anchor to establish a valid same-origin linear term.
    q0=swap.trial(origin_head.value)
    qdiag,_,t0,available=swap.last_trial_response()
    require(available and math.isfinite(t0),"initial exact tangent unavailable")
    require(abs(qdiag-q0)<=64*np.finfo(float).eps*max(1.0,abs(q0)),"anchor q mismatch")
    swap.discard()
    origin_state=swap.state()
    require(origin_state[0]==0 and origin_state[2]==0 and origin_state[3]==0.0,
            "anchor trial changed revision/ledger authority")
    require(abs(origin_state[1]-DT)<=1.0e-14,"dynamic origin committed-time mismatch")

    current_hcof=t0*AREA_M2*DAY_TO_S
    current_rhs=current_hcof*origin_head.value-q0*AREA_M2*DAY_TO_S

    modflow_ns=0
    swap_trial_ns=0
    response_ns=0
    discard_ns=0
    finalization_ns=0
    iterations=0
    exact_trials=0
    final_head=None
    final_q_swap=None
    final_q_gw=None
    final_residual=None
    diag_sums={k:0 for k in ("transaction_calls","accepted_substeps","attempts","retries",
                              "solver_rejections","temporal_rejections","nonlinear_iterations",
                              "backtracking_attempts")}
    diag_max_indicator=0.0

    with tempfile.TemporaryDirectory(prefix=f"profile07-{material}-") as tmp:
        workdir=Path(tmp)
        build_model(workdir,origin_head.value)
        raw=XmiWrapper(lib_path=libmf6,working_directory=workdir)
        kernel=CountingKernel(raw)
        publisher=Fgc34CtypesPublisher(swaplib)
        initialized=False
        try:
            raw.initialize(); initialized=True
            raw.prepare_time_step(0.0)
            session=Modflow6PreparedSolveSession(kernel,"GWF_1","API_SWAP",publisher,solution_id=1)
            require(session.acquire_after_prepare_time_step()==PreparedSolveStatus.OK,session.last_error)
            require(session.open_prepared_solve()==PreparedSolveStatus.OK,session.last_error)
            accepted_xold=session.accepted_xold.copy()
            binding=[Binding(7001,1,2)]

            loop_start=time.perf_counter_ns()
            for outer in range(1,min(40,session.max_solve_iterations)+1):
                iterations=outer
                t=time.perf_counter_ns()
                status,it=session.publish_and_solve_iteration(
                    binding,[Term(7001,current_hcof,current_rhs)]
                )
                modflow_ns += time.perf_counter_ns()-t
                require(status==PreparedSolveStatus.OK,session.last_error)
                require(it is not None,f"missing MODFLOW iterate {outer}")
                require(np.array_equal(it.accepted_head_old_m,accepted_xold),"accepted XOLD drift")
                head=float(it.head_m[1])
                q_gw=(current_hcof*head-current_rhs)/(AREA_M2*DAY_TO_S)

                t=time.perf_counter_ns()
                q_swap=swap.trial(head)
                swap_trial_ns += time.perf_counter_ns()-t
                exact_trials += 1

                t=time.perf_counter_ns()
                qdiag,_,tangent,available=swap.last_trial_response()
                response_ns += time.perf_counter_ns()-t
                require(available and math.isfinite(tangent),"exact tangent unavailable")
                require(abs(qdiag-q_swap)<=64*np.finfo(float).eps*max(1.0,abs(q_swap)),
                        "exact q diagnostic mismatch")

                d=_temporal_diag(swap)
                for k in diag_sums: diag_sums[k]+=int(d[k])
                diag_max_indicator=max(diag_max_indicator,float(d["max_temporal_indicator"]))

                residual=q_swap-q_gw
                require(all(math.isfinite(x) for x in (head,q_gw,q_swap,tangent,residual)),
                        "nonfinite exact coupled response")
                if it.modflow_converged and abs(residual)<=FLUX_TOL:
                    final_head=head; final_q_swap=q_swap; final_q_gw=q_gw; final_residual=residual
                    break

                t=time.perf_counter_ns()
                swap.discard()
                discard_ns += time.perf_counter_ns()-t
                require(swap.state()==origin_state,"discarded exact trial changed authority")
                current_hcof=tangent*AREA_M2*DAY_TO_S
                current_rhs=current_hcof*head-q_swap*AREA_M2*DAY_TO_S

            coupled_loop_ns=time.perf_counter_ns()-loop_start
            require(final_head is not None,"exact live coupling did not converge")

            t=time.perf_counter_ns()
            require(session.finalize_prepared_solve()==PreparedSolveStatus.OK,session.last_error)
            require(swap.swap_preflight(),"SWAP preflight failed")
            swap.prepare_ledger()
            require(swap.ledger_preflight(),"ledger preflight failed")
            require(session.timestep_ready_for_finalize(),"MODFLOW timestep not ready")
            require(swap.state()==origin_state,"prepublication authority drift")
            require(session.finalize_time_step_once()==PreparedSolveStatus.OK,session.last_error)
            swap.commit_swap()
            swap.commit_ledger()
            finalization_ns += time.perf_counter_ns()-t

            final_state=swap.state()
            require(final_state[0]==1 and final_state[2]==1,"commit/ledger count")
            raw.finalize(); initialized=False
        finally:
            if initialized:
                try: raw.finalize()
                except Exception: pass

    measured_components_ns=modflow_ns+swap_trial_ns+response_ns+discard_ns
    residual_loop_ns=coupled_loop_ns-measured_components_ns
    print("PROFILE07_RAW|"+json.dumps({
        "material":material,"h0":h0,"imbalance":imbalance,"budget_cm":budget,
        "iterations":iterations,"exact_trials":exact_trials,
        "coupled_loop_ns":coupled_loop_ns,"modflow_ns":modflow_ns,
        "swap_trial_ns":swap_trial_ns,"response_ns":response_ns,"discard_ns":discard_ns,
        "loop_residual_ns":residual_loop_ns,"finalization_ns":finalization_ns,
        "final_head":final_head,"final_q_swap":final_q_swap,"final_q_gw":final_q_gw,
        "final_residual":final_residual,"revision":final_state[0],"ledger_count":final_state[2],
        **diag_sums,"max_temporal_indicator":diag_max_indicator,
    },separators=(",",":")))

if __name__=="__main__":
    main()
