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

def main()->None:
    if len(sys.argv)!=7:
        raise SystemExit("usage: MODE MATERIAL H0 IMBALANCE FLOOR_CM HEADS_JSON")
    mode,material,h0s,imbs,floors,heads_json=sys.argv[1:]
    if mode not in ("prod","wide") or material not in MATERIALS:
        raise SystemExit("invalid mode/material")
    h0=float(h0s); imbalance=float(imbs); floor_cm=float(floors)
    heads=json.loads(heads_json)
    if not heads: raise SystemExit("empty heads")

    swap=Fgc44RealSwap(Path(os.environ["FGC44_SWAP_LIB"]))
    cfg=swap.lib.fgc44_approx04_configure_case_c
    cfg.restype=ctypes.c_int; cfg.argtypes=[ctypes.c_double]*7
    tr,ts,alpha,nvg,ksat,lamb=MATERIALS[material]
    if cfg(h0,tr,ts,alpha,nvg,ksat,lamb): raise RuntimeError("configure failed")

    # The research bridge intentionally freezes policy configuration at
    # initialization. Set the requested floor before initialize_configured(),
    # matching the production bootstrap/configuration ownership boundary.
    pfn=swap.lib.fgc44_live01_policy_floor_c
    pfn.restype=ctypes.c_int; pfn.argtypes=[ctypes.c_double]
    if pfn(floor_cm): raise RuntimeError("policy floor configure failed")

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

    direction=swap.lib.fgc44_live01_direction_c
    direction.restype=ctypes.c_int; direction.argtypes=[ctypes.c_int]
    if direction(0): raise RuntimeError("direction disable failed")

    dfn=swap.lib.fgc44_live01_diagnostics_c
    dfn.restype=ctypes.c_int
    dfn.argtypes=[*([ctypes.POINTER(ctypes.c_int)]*12),ctypes.POINTER(ctypes.c_double)]
    names=["transaction_calls","accepted_substeps","attempts","retries","solver_rejections",
           "temporal_rejections","nonlinear_iterations","internal_retries","headcalc_calls",
           "jacobian_builds","linear_solves","backtracking_attempts"]

    totals={k:0 for k in names}; qs=[]; trial_ns=[]; max_ti=0.0
    for head in heads:
        t0=time.perf_counter_ns()
        q=swap.trial(float(head))
        trial_ns.append(time.perf_counter_ns()-t0)
        vals=[ctypes.c_int() for _ in range(12)]; mt=ctypes.c_double()
        if dfn(*[ctypes.byref(v) for v in vals],ctypes.byref(mt)):
            raise RuntimeError("diagnostics query failed")
        for k,v in zip(names,vals): totals[k]+=v.value
        max_ti=max(max_ti,mt.value)
        qs.append(q)
        swap.discard()

    print("LIVE01_P2_REPLAY|"+json.dumps({
        "material":material,"h0":h0,"imbalance":imbalance,"mode":mode,
        "floor_cm":floor_cm,"history_scale":rate.value,"heads":heads,"q":qs,
        "trial_ns":trial_ns,"total_trial_ns":sum(trial_ns),
        "max_temporal_indicator":max_ti,**totals
    },separators=(",",":")))

if __name__=="__main__":
    main()
