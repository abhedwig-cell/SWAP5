from __future__ import annotations

import json
import os
import sys
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/"tests"/"fgc"/"support"))
from fgc44_real_swap_ctypes import Fgc44RealSwap  # noqa: E402

if len(sys.argv)!=2:
    raise SystemExit("usage: test_rm15_dynamic_top_point.py <window-seconds>")

seconds=float(sys.argv[1])
days=seconds/86400.0
swap=Fgc44RealSwap(Path(os.environ["RM15_SWAP_LIB"]))
status,hcof,rhs,href=swap.try_initialize_dynamic_irrigation(days,1.0e-6,36.0,1.0)
diag=swap.predictor_run_diagnostics()
payload={
    "window_seconds":seconds,
    "window_days":days,
    "status":status,
    "hcof":hcof,
    "rhs":rhs,
    "reference_head":href,
    "diagnostics":diag,
}
if status==0:
    payload["e1"]=swap.e1_diagnostics()
print("RM15_POINT_JSON="+json.dumps(payload,separators=(",",":"),sort_keys=True))
