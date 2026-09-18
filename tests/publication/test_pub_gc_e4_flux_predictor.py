from __future__ import annotations

import json
import math
import os
import sys
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/"tests"/"fgc"/"support"))

from fgc44_real_swap_ctypes import Fgc44RealSwap

def main()->None:
    window=float(os.environ["E4_WINDOW_DAY"])
    q=float(os.environ["E4_QBOT_CM_PER_DAY"])
    baseline_id=os.environ["E4_BASELINE_ID"]
    fraction=float(os.environ["E4_FRACTION"])
    side=os.environ["E4_SIDE"]
    lib=Path(os.environ["FGC44_SWAP_LIB"]).resolve()

    swap=Fgc44RealSwap(lib)
    status,hcof,rhs,href=swap.try_initialize_configured(window,q)
    rec={
        "schema":"pub-gc-e4-flux-point-v1",
        "baseline_id":baseline_id,
        "window_day":window,
        "qbot_cm_per_day":q,
        "fraction":fraction,
        "side":side,
        "status_code":status,
        "ready":status==0,
    }
    if status==0:
        d=swap.e1_diagnostics()
        vals=[hcof,rhs,href,float(d["u"]),float(d["h_end_m"]),float(d["h_start_m"])]
        if not all(math.isfinite(v) for v in vals):
            raise AssertionError("nonfinite successful E4 flux point")
        if swap.state()!=(0,0.0,0,0.0):
            raise AssertionError("E4 flux predictor changed authoritative state")
        rec.update({
            "hcof_m2_per_day":hcof,
            "rhs_m3_per_day":rhs,
            "reference_head_m":href,
            "u_A_point":float(d["u"]),
            "h_start_m":float(d["h_start_m"]),
            "h_end_m":float(d["h_end_m"]),
            "q_u_cm_per_day":float(d["q_u_cm_per_day"]),
            "mass_complete":bool(d["mass_complete"]),
            "mass_residual_native":float(d["mass_residual_native"]),
        })
    print("E4_FLUX_JSON="+json.dumps(rec,sort_keys=True,separators=(",",":")))

if __name__=="__main__":
    main()
