from __future__ import annotations

import ctypes
import json
import os
from pathlib import Path

LIB=Path(os.environ["RM16_SWAP_LIB"]).resolve()
lib=ctypes.CDLL(str(LIB))
fn=lib.fgc44_rm16_provider_raw_solve_c
fn.restype=ctypes.c_int
fn.argtypes=[
    ctypes.c_double,ctypes.c_double,
    ctypes.POINTER(ctypes.c_int),ctypes.POINTER(ctypes.c_int),
    ctypes.POINTER(ctypes.c_double),ctypes.POINTER(ctypes.c_double),
    ctypes.POINTER(ctypes.c_double),ctypes.POINTER(ctypes.c_double),
    ctypes.POINTER(ctypes.c_double),ctypes.POINTER(ctypes.c_double),
    ctypes.POINTER(ctypes.c_int),ctypes.POINTER(ctypes.c_int),
    ctypes.POINTER(ctypes.c_int),ctypes.POINTER(ctypes.c_int),
    ctypes.POINTER(ctypes.c_double),ctypes.POINTER(ctypes.c_double),
]

windows=[8.64,1.08,0.0084375]
rows=[]
for seconds in windows:
    ints=[ctypes.c_int() for _ in range(6)]
    reals=[ctypes.c_double() for _ in range(8)]
    status=fn(
        seconds/86400.0,36.0,
        ctypes.byref(ints[0]),ctypes.byref(ints[1]),
        ctypes.byref(reals[0]),ctypes.byref(reals[1]),
        ctypes.byref(reals[2]),ctypes.byref(reals[3]),
        ctypes.byref(reals[4]),ctypes.byref(reals[5]),
        ctypes.byref(ints[2]),ctypes.byref(ints[3]),
        ctypes.byref(ints[4]),ctypes.byref(ints[5]),
        ctypes.byref(reals[6]),ctypes.byref(reals[7]),
    )
    row={
        "window_seconds":seconds,
        "bridge_status":int(status),
        "provider_status":ints[0].value,
        "provider_regime":ints[1].value,
        "provider_top_flux_cm_per_day":reals[0].value,
        "provider_surface_head_cm":reals[1].value,
        "provider_candidate_ponding_cm":reals[2].value,
        "provider_runoff_cm":reals[3].value,
        "provider_face_k_cm_per_day":reals[4].value,
        "provider_net_surface_cm_per_day":reals[5].value,
        "raw_status":ints[2].value,
        "raw_nonlinear_iterations":ints[3].value,
        "raw_backtracking_attempts":ints[4].value,
        "raw_internal_retries":ints[5].value,
        "raw_top_flux_cm_per_day":reals[6].value,
        "raw_candidate_ponding_cm":reals[7].value,
    }
    rows.append(row)
    print("RM16_POINT_JSON="+json.dumps(row,separators=(",",":"),sort_keys=True))

if any(r["bridge_status"] != 0 for r in rows):
    raise AssertionError(f"RM16 bridge failure: {rows}")
if any(r["provider_status"] != 1 for r in rows):
    raise AssertionError(f"RM16 provider unavailable: {rows}")
if any(r["provider_regime"] not in (1,2) for r in rows):
    raise AssertionError(f"RM16 provider regime invalid: {rows}")
for r in rows:
    if abs(r["provider_net_surface_cm_per_day"]-36.0) > 1e-12:
        raise AssertionError(f"RM16 provider net surface drift: {r}")
    if r["provider_runoff_cm"] < -1e-15:
        raise AssertionError(f"RM16 provider negative runoff: {r}")

raw_success=[r for r in rows if r["raw_status"]==1]
if raw_success:
    decision="RAW_RICHARDS_SUCCESS_EXISTS"
else:
    decision="PROVIDER_VALID_RAW_RICHARDS_FAILS"

print(f"RM16_DECISION={decision}")
print(f"RM16_RAW_SUCCESS_COUNT={len(raw_success)}")
print("RM16_PROVIDER_RAW_RICHARDS_ISOLATION=PASS")
