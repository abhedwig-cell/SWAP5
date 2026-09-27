from __future__ import annotations

import ctypes
import json
import math
import os
import sys
import time
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/"tests"/"fgc"/"support"))

from fgc44_real_swap_ctypes import Fgc44RealSwap

MATERIALS={
    "B01":(0.02,0.427494,0.021659,1.734737,31.225016,0.98087),
    "B12":(0.01,0.529749,0.016562,1.090671,2.245895,-4.493581),
    "O05":(0.01,0.336701,0.030304,2.887502,17.418504,0.0736),
    "O14":(0.01,0.393878,0.003288,1.616573,2.495984,0.514012),
}
DT=1.0e-4

def frozen_case(material:str,h0:float,imbalance:float)->dict:
    data=json.loads((ROOT/"tests"/"fpe"/"fpe_base01_p1_live_heads.json").read_text())
    for case in data["cases"]:
        if case["material"]==material and float(case["h0"])==h0 and abs(float(case["imbalance"])-imbalance)<1e-15:
            return case
    raise RuntimeError("frozen LIVE01 head sequence unavailable")

def temporal_diag(swap:Fgc44RealSwap)->dict[str,int|float]:
    fn=swap.lib.fgc44_temporal04_diagnostics_c
    fn.restype=ctypes.c_int
    ints=[ctypes.c_int() for _ in range(8)]
    mt=ctypes.c_double()
    fn.argtypes=[*([ctypes.POINTER(ctypes.c_int)]*8),ctypes.POINTER(ctypes.c_double)]
    if fn(*[ctypes.byref(v) for v in ints],ctypes.byref(mt)):
        raise RuntimeError("temporal diagnostics failed")
    keys=("transaction_calls","accepted_substeps","attempts","retries","solver_rejections",
          "temporal_rejections","nonlinear_iterations","backtracking_attempts")
    out={k:v.value for k,v in zip(keys,ints)}
    out["max_temporal_indicator"]=mt.value
    return out

def main()->None:
    if len(sys.argv)!=4:
        raise SystemExit("usage: MATERIAL H0 IMBALANCE")
    material=sys.argv[1]; h0=float(sys.argv[2]); imbalance=float(sys.argv[3])
    if material not in MATERIALS:
        raise SystemExit("invalid material")
    case=frozen_case(material,h0,imbalance)
    heads=[float(x) for x in case["heads"]]

    swap=Fgc44RealSwap(Path(os.environ["FGC44_SWAP_LIB"]))
    cfg=swap.lib.fgc44_approx04_configure_case_c
    cfg.restype=ctypes.c_int; cfg.argtypes=[ctypes.c_double]*7
    tr,ts,alpha,nvg,ksat,lamb=MATERIALS[material]
    if cfg(h0,tr,ts,alpha,nvg,ksat,lamb):
        raise RuntimeError("configure case failed")

    predfn=swap.lib.fgc44_approx04_predictor_q_c
    predfn.restype=ctypes.c_int; predfn.argtypes=[ctypes.POINTER(ctypes.c_double)]
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

    budget=max(1.0e-5,0.65*DT*rate.value)
    bfn=swap.lib.fgc44_temporal04_budget_c
    bfn.restype=ctypes.c_int; bfn.argtypes=[ctypes.c_double]
    if bfn(budget):
        raise RuntimeError("temporal budget configure failed")

    cachefn=swap.lib.fgc44_temporal06_tangent_cache_c
    cachefn.restype=ctypes.c_int; cachefn.argtypes=[ctypes.c_int]
    if cachefn(0):
        raise RuntimeError("tangent cache configure failed")

    reset=swap.lib.fgc44_base01_timing_reset_c
    reset.restype=ctypes.c_int; reset.argtypes=[]
    if reset(): raise RuntimeError("participant timing reset failed")
    hreset=swap.lib.base01_timing_reset_c
    hreset.restype=ctypes.c_int; hreset.argtypes=[]
    if hreset(): raise RuntimeError("headcalc timing reset failed")

    origin_state=swap.state()
    totals={k:0 for k in ("transaction_calls","accepted_substeps","attempts","retries",
                           "solver_rejections","temporal_rejections","nonlinear_iterations",
                           "backtracking_attempts")}
    qs=[]; max_ti=0.0
    t0=time.perf_counter_ns()
    for head in heads:
        q=swap.trial(head)
        d=temporal_diag(swap)
        for k in totals: totals[k]+=int(d[k])
        max_ti=max(max_ti,float(d["max_temporal_indicator"]))
        if not math.isfinite(q): raise RuntimeError("nonfinite q")
        qs.append(q)
        swap.discard()
        if swap.state()!=origin_state:
            raise RuntimeError("discarded q-only trial changed origin authority")
    swap_trial_ns=time.perf_counter_ns()-t0

    timing=swap.lib.fgc44_base01_timing_c
    timing.restype=ctypes.c_int
    timing.argtypes=[ctypes.POINTER(ctypes.c_double),ctypes.POINTER(ctypes.c_double),ctypes.POINTER(ctypes.c_int)]
    forcing_s=ctypes.c_double(); backend_s=ctypes.c_double(); participant_calls=ctypes.c_int()
    if timing(ctypes.byref(forcing_s),ctypes.byref(backend_s),ctypes.byref(participant_calls)):
        raise RuntimeError("participant timing query failed")
    forcing_ns=forcing_s.value*1e9; backend_ns=backend_s.value*1e9
    post_ns=swap_trial_ns-forcing_ns-backend_ns

    get=swap.lib.base01_timing_get_c
    get.restype=ctypes.c_int
    secs=(ctypes.c_double*6)(); calls=(ctypes.c_int*6)()
    get.argtypes=[ctypes.POINTER(ctypes.c_double),ctypes.POINTER(ctypes.c_int)]
    if get(secs,calls): raise RuntimeError("headcalc timing query failed")
    names=("headcalc","constitutive","vector","jacobian","linear","backtrack")
    timed={f"p1_{name}_ns":secs[i]*1e9 for i,name in enumerate(names)}
    timed.update({f"p1_{name}_calls":calls[i] for i,name in enumerate(names)})

    print("BASE01_P1_RAW|"+json.dumps({
        "material":material,"regime":case["regime"],"h0":h0,"imbalance":imbalance,
        "heads":heads,"q":qs,"budget_cm":budget,"history_scale":rate.value,
        "swap_trial_ns":swap_trial_ns,"participant_forcing_ns":forcing_ns,
        "participant_backend_ns":backend_ns,"participant_post_ns":post_ns,
        "participant_calls":participant_calls.value,
        **totals,"max_temporal_indicator":max_ti,**timed
    },separators=(",",":")))

if __name__=="__main__":
    main()
