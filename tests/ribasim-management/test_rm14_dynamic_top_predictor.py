from __future__ import annotations

import os
import sys
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/"tests"/"fgc"/"support"))
from fgc44_real_swap_ctypes import Fgc44RealSwap  # noqa: E402

WINDOW_DAY=1.0e-4
PREDICTOR_QBOT=1.0e-6
IRRIGATION_RATE=36.0
PONDING_MAX=1.0

swap=Fgc44RealSwap(Path(os.environ["RM14_SWAP_LIB"]))
status,hcof,rhs,href=swap.try_initialize_dynamic_irrigation(
    WINDOW_DAY,PREDICTOR_QBOT,IRRIGATION_RATE,PONDING_MAX
)
diag=swap.predictor_run_diagnostics()

print(f"RM14_PREDICTOR_INIT_STATUS={status}")
print(f"RM14_PREDICTOR_HCOF={hcof:.17g}")
print(f"RM14_PREDICTOR_RHS={rhs:.17g}")
print(f"RM14_PREDICTOR_REFERENCE_HEAD={href:.17g}")
print("RM14_PREDICTOR_DIAGNOSTICS="+repr(diag))

if status != 0:
    raise AssertionError(f"RM14 dynamic-top predictor rejected: status={status}, diagnostics={diag}")
if not diag["completed"]:
    raise AssertionError(f"RM14 predictor not completed: {diag}")
if diag["accepted_substeps"] < 1:
    raise AssertionError(f"RM14 predictor accepted no substeps: {diag}")
if diag["mass_rejections"] != 0:
    raise AssertionError(f"RM14 predictor hit mass gate: {diag}")

e1=swap.e1_diagnostics()
print("RM14_E1="+repr(e1))
if not e1["mass_complete"]:
    raise AssertionError(f"RM14 E1 mass accounting incomplete: {e1}")

print("RM14_DYNAMIC_TOP_PREDICTOR=PASS")
