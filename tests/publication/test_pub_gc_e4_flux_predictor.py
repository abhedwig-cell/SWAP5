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
    q0=float(os.environ["E4_BASELINE_QBOT_CM_PER_DAY"])
    q=float(os.environ["E4_QBOT_CM_PER_DAY"])
    baseline_id=os.environ["E4_BASELINE_ID"]
    fraction=float(os.environ["E4_FRACTION"])
    side=os.environ["E4_SIDE"]
    lib=Path(os.environ["FGC44_SWAP_LIB"]).resolve()

    swap=Fgc44RealSwap(lib)
    point=swap.e4_flux_point(window,q0,q)
    rec={
        "schema":"pub-gc-e4-flux-point-v2",
        "baseline_id":baseline_id,
        "window_day":window,
        "top_flux_fixed_cm_per_day":q0,
        "qbot_cm_per_day":q,
        "fraction":fraction,
        "side":side,
        "status_code":int(point["status"]),
        "ready":bool(point["ready"]),
    }
    if bool(point["ready"]):
        vals=[
            float(point["h_end_m"]),
            float(point["dh_end_cm_per_qbot_cm_per_day"]),
            float(point["u_A_point"]),
            float(point["mass_residual_native"]),
        ]
        if not all(math.isfinite(v) for v in vals):
            raise AssertionError("nonfinite successful E4 pure-bottom flux point")
        if not bool(point["mass_complete"]):
            raise AssertionError("successful E4 pure-bottom flux point has incomplete mass")
        rec.update({
            "h_end_m":float(point["h_end_m"]),
            "dh_end_cm_per_qbot_cm_per_day":float(point["dh_end_cm_per_qbot_cm_per_day"]),
            "u_A_point":float(point["u_A_point"]),
            "mass_complete":bool(point["mass_complete"]),
            "mass_residual_native":float(point["mass_residual_native"]),
        })
    print("E4_FLUX_JSON="+json.dumps(rec,sort_keys=True,separators=(",",":")))

if __name__=="__main__":
    main()
