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

def configure_swap(material:str,h0:float,imbalance:float)->tuple[Fgc44RealSwap,float]:
    swap=Fgc44RealSwap(Path(os.environ["FGC44_SWAP_LIB"]))
    cfg=swap.lib.fgc44_approx04_configure_case_c
    cfg.restype=ctypes.c_int; cfg.argtypes=[ctypes.c_double]*7
    tr,ts,alpha,nvg,ksat,lamb=MATERIALS[material]
    if cfg(h0,tr,ts,alpha,nvg,ksat,lamb): raise RuntimeError("configure case failed")

    predfn=swap.lib.fgc44_approx04_predictor_q_c
    predfn.restype=ctypes.c_int; predfn.argtypes=[ctypes.POINTER(ctypes.c_double)]
    predictor_q=ctypes.c_double()
    if predfn(ctypes.byref(predictor_q)): raise RuntimeError("predictor q failed")
    swap.initialize_configured(DT,predictor_q.value)

    dyn=swap.lib.fgc44_temporal03_dynamic_origin_c
    dyn.restype=ctypes.c_int
    dyn.argtypes=[ctypes.c_double,*([ctypes.POINTER(ctypes.c_double)]*3)]
    rate=ctypes.c_double(); origin_mass=ctypes.c_double(); origin_head=ctypes.c_double()
    if dyn(imbalance,ctypes.byref(rate),ctypes.byref(origin_mass),ctypes.byref(origin_head)):
        raise RuntimeError("dynamic origin failed")

    cachefn=swap.lib.fgc44_temporal06_tangent_cache_c
    cachefn.restype=ctypes.c_int; cachefn.argtypes=[ctypes.c_int]
    if cachefn(0): raise RuntimeError("tangent cache configure failed")
    return swap,origin_head.value

def diag_reader(swap:Fgc44RealSwap):
    fn=swap.lib.fgc44_live01_diagnostics_c
    fn.restype=ctypes.c_int
    fn.argtypes=[*([ctypes.POINTER(ctypes.c_int)]*12),ctypes.POINTER(ctypes.c_double)]
    names=["transaction_calls","accepted_substeps","attempts","retries","solver_rejections",
           "temporal_rejections","nonlinear_iterations","internal_retries","headcalc_calls",
           "jacobian_builds","linear_solves","backtracking_attempts"]
    def read():
        vals=[ctypes.c_int() for _ in range(12)]; mt=ctypes.c_double()
        if fn(*[ctypes.byref(v) for v in vals],ctypes.byref(mt)):
            raise RuntimeError("LIVE01 diagnostics failed")
        return {k:v.value for k,v in zip(names,vals)},mt.value
    return read

def live_heads(material:str,h0:float,imbalance:float)->None:
    libmf6=Path(os.environ["LIBMF6"]).resolve()
    swaplib=Path(os.environ["FGC44_SWAP_LIB"]).resolve()
    swap,origin_head=configure_swap(material,h0,imbalance)
    origin_state=swap.state()
    require(origin_state[0]==0 and origin_state[2]==0,"origin authority")

    q0=swap.trial(origin_head)
    qdiag,_,t0,av=swap.last_trial_response()
    require(av and math.isfinite(t0),"anchor tangent")
    require(abs(qdiag-q0)<=64*np.finfo(float).eps*max(1.0,abs(q0)),"anchor q")
    swap.discard()

    current_hcof=t0*AREA_M2*DAY_TO_S
    current_rhs=current_hcof*origin_head-q0*AREA_M2*DAY_TO_S
    heads=[]

    with tempfile.TemporaryDirectory(prefix=f"live01-p1-live-{material}-") as tmp:
        workdir=Path(tmp); build_model(workdir,origin_head)
        raw=XmiWrapper(lib_path=libmf6,working_directory=workdir)
        kernel=CountingKernel(raw); publisher=Fgc34CtypesPublisher(swaplib)
        initialized=False
        try:
            raw.initialize(); initialized=True; raw.prepare_time_step(0.0)
            session=Modflow6PreparedSolveSession(kernel,"GWF_1","API_SWAP",publisher,solution_id=1)
            require(session.acquire_after_prepare_time_step()==PreparedSolveStatus.OK,session.last_error)
            require(session.open_prepared_solve()==PreparedSolveStatus.OK,session.last_error)
            accepted_xold=session.accepted_xold.copy()
            binding=[Binding(7001,1,2)]
            for outer in range(1,min(40,session.max_solve_iterations)+1):
                status,it=session.publish_and_solve_iteration(binding,[Term(7001,current_hcof,current_rhs)])
                require(status==PreparedSolveStatus.OK,session.last_error)
                require(it is not None,"missing iterate")
                require(np.array_equal(it.accepted_head_old_m,accepted_xold),"XOLD drift")
                head=float(it.head_m[1]); heads.append(head)
                qgw=(current_hcof*head-current_rhs)/(AREA_M2*DAY_TO_S)
                q=swap.trial(head)
                _,_,t,av=swap.last_trial_response()
                require(av and math.isfinite(t),"live tangent unavailable")
                residual=q-qgw
                if it.modflow_converged and abs(residual)<=FLUX_TOL:
                    swap.discard()
                    break
                swap.discard()
                current_hcof=t*AREA_M2*DAY_TO_S
                current_rhs=current_hcof*head-q*AREA_M2*DAY_TO_S
            require(len(heads)>0,"no live heads")
            session.invalidate_without_finalize()
            raw.finalize(); initialized=False
        finally:
            if initialized:
                try: raw.finalize()
                except Exception: pass
    print("LIVE01_P1_LIVE|"+json.dumps({"material":material,"h0":h0,"imbalance":imbalance,"heads":heads},separators=(",",":")))

def replay(material:str,h0:float,imbalance:float,direction:bool,heads:list[float])->None:
    swap,_=configure_swap(material,h0,imbalance)
    toggle=swap.lib.fgc44_live01_direction_c
    toggle.restype=ctypes.c_int; toggle.argtypes=[ctypes.c_int]
    if toggle(1 if direction else 0): raise RuntimeError("direction toggle failed")
    read_diag=diag_reader(swap)
    totals={k:0 for k in ["transaction_calls","accepted_substeps","attempts","retries","solver_rejections",
           "temporal_rejections","nonlinear_iterations","internal_retries","headcalc_calls",
           "jacobian_builds","linear_solves","backtracking_attempts"]}
    qs=[]; trial_ns=[]; max_ti=0.0
    for head in heads:
        t0=time.perf_counter_ns()
        q=swap.trial(head)
        trial_ns.append(time.perf_counter_ns()-t0)
        d,mt=read_diag(); max_ti=max(max_ti,mt)
        for k,v in d.items(): totals[k]+=v
        qs.append(q)
        swap.discard()
    print("LIVE01_P1_REPLAY|"+json.dumps({
        "material":material,"h0":h0,"imbalance":imbalance,
        "mode":"full" if direction else "qonly","heads":heads,"q":qs,
        "trial_ns":trial_ns,"total_trial_ns":sum(trial_ns),"max_temporal_indicator":max_ti,
        **totals
    },separators=(",",":")))

def main()->None:
    if len(sys.argv)<5:
        raise SystemExit("usage: live|full|qonly MATERIAL H0 IMBALANCE [HEADS_JSON]")
    mode=sys.argv[1]; material=sys.argv[2]; h0=float(sys.argv[3]); imbalance=float(sys.argv[4])
    if mode=="live":
        live_heads(material,h0,imbalance)
    elif mode in ("full","qonly"):
        if len(sys.argv)!=6: raise SystemExit("replay requires HEADS_JSON")
        replay(material,h0,imbalance,mode=="full",json.loads(sys.argv[5]))
    else:
        raise SystemExit("invalid mode")

if __name__=="__main__":
    main()
