from __future__ import annotations
import os,sys,math
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];sys.path.insert(0,str(ROOT/"tests"/"fgc"/"support"))
from fgc44_real_swap_ctypes import Fgc44RealSwap
s=Fgc44RealSwap(os.environ["FGC44_REAL_SWAP_LIB"])
s.initialize()
a=s.committed_profile_observables(); b=s.committed_profile_observables()
assert a==b
assert a["profile_water_cm"]>0
assert a["root_water_cm"]>0
assert a["root_water_cm"]<=a["profile_water_cm"]
assert math.isfinite(a["distribution_moment_cm"])
# This is deliberately diagnostic only: groundwater_level is not H_c.
print("RZM06A_PROFILE_WATER_CM",repr(a["profile_water_cm"]))
print("RZM06A_ROOT_WATER_CM",repr(a["root_water_cm"]))
print("RZM06A_DISTRIBUTION_MOMENT_CM",repr(a["distribution_moment_cm"]))
print("RZM06A_INTERNAL_GROUNDWATER_LEVEL_CM",repr(a["groundwater_level_cm"]))
print("GC_RZM06A_OBSERVABLE_EXTRACTION=PASS")
