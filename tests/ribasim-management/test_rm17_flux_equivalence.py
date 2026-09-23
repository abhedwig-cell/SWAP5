from __future__ import annotations
import ctypes, json, os
from pathlib import Path

lib=ctypes.CDLL(str(Path(os.environ["RM17_SWAP_LIB"]).resolve()))
fn=lib.fgc44_rm17_flux_equivalence_c
fn.restype=ctypes.c_int
fn.argtypes=[
    ctypes.c_double,ctypes.c_double,
    ctypes.POINTER(ctypes.c_int),ctypes.POINTER(ctypes.c_int),
    ctypes.POINTER(ctypes.c_double),ctypes.POINTER(ctypes.c_double),ctypes.POINTER(ctypes.c_double),
    ctypes.POINTER(ctypes.c_double),ctypes.POINTER(ctypes.c_double),
    ctypes.POINTER(ctypes.c_int),ctypes.POINTER(ctypes.c_int),
    ctypes.POINTER(ctypes.c_double),ctypes.POINTER(ctypes.c_double),ctypes.POINTER(ctypes.c_double),
]
ints=[ctypes.c_int() for _ in range(4)]
reals=[ctypes.c_double() for _ in range(8)]
status=fn(
    1.0e-4,36.0,
    ctypes.byref(ints[0]),ctypes.byref(ints[1]),
    ctypes.byref(reals[0]),ctypes.byref(reals[1]),ctypes.byref(reals[2]),
    ctypes.byref(reals[3]),ctypes.byref(reals[4]),
    ctypes.byref(ints[2]),ctypes.byref(ints[3]),
    ctypes.byref(reals[5]),ctypes.byref(reals[6]),ctypes.byref(reals[7]),
)
row={
    "bridge_status":status,
    "dynamic_status":ints[0].value,
    "fixed_status":ints[1].value,
    "max_head_diff_cm":reals[0].value,
    "max_water_diff":reals[1].value,
    "ponding_diff_cm":reals[2].value,
    "top_flux_diff_cm_per_day":reals[3].value,
    "bottom_flux_diff_cm_per_day":reals[4].value,
    "endpoint_provider_status":ints[2].value,
    "endpoint_provider_regime":ints[3].value,
    "endpoint_provider_top_flux_cm_per_day":reals[5].value,
    "endpoint_provider_runoff_cm":reals[6].value,
    "endpoint_provider_ponding_cm":reals[7].value,
}
print("RM17_RESULT="+json.dumps(row,separators=(",",":"),sort_keys=True))
if status != 0:
    raise AssertionError(row)
if ints[0].value != 1 or ints[1].value != 1:
    raise AssertionError(f"both raw solves must converge: {row}")
if reals[3].value > 1e-12 or reals[4].value > 1e-12:
    raise AssertionError(f"flux equivalence failed: {row}")
if reals[0].value > 1e-12 or reals[1].value > 1e-14 or reals[2].value > 1e-12:
    raise AssertionError(f"state equivalence failed: {row}")
if ints[2].value != 1 or ints[3].value != 1:
    raise AssertionError(f"endpoint provider not flux regime: {row}")
if abs(reals[5].value+36.0) > 1e-12 or abs(reals[6].value) > 1e-12 or abs(reals[7].value) > 1e-12:
    raise AssertionError(f"endpoint dynamic provider drift: {row}")
print("RM17_DYNAMIC_FIXED_FLUX_EQUIVALENCE=PASS")
