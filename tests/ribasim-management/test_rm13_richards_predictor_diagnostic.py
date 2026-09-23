from __future__ import annotations
import os,sys
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/"tests"/"fgc"/"support"))
from fgc44_real_swap_ctypes import Fgc44RealSwap

swap=Fgc44RealSwap(Path(os.environ["RM13_SWAP_LIB"]))
status,hcof,rhs,href=swap.try_initialize_forced(1.0e-4,1.0e-6,-36.0)
diag=swap.predictor_run_diagnostics()
print(f"RM13_PREDICTOR_INIT_STATUS={status}")
print(f"RM13_PREDICTOR_HCOF={hcof:.17g}")
print(f"RM13_PREDICTOR_RHS={rhs:.17g}")
print(f"RM13_PREDICTOR_REFERENCE_HEAD={href:.17g}")
print("RM13_PREDICTOR_DIAGNOSTICS="+repr(diag))
if status==0:
    print("RM13_PREDICTOR_SMOKE_COMPLETED=PASS")
else:
    print("RM13_PREDICTOR_SMOKE_COMPLETED=FAIL_EXPECTED_DIAGNOSTIC")
