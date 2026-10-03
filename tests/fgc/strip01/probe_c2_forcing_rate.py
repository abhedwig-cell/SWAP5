"""Fresh-origin diagnostic of the C2 imposed-flux temporal certificate."""
import argparse
import ctypes
import json
from pathlib import Path

p = argparse.ArgumentParser()
p.add_argument('--library', type=Path, required=True)
p.add_argument('--rate', type=float, required=True)
p.add_argument('--output', type=Path, required=True)
a = p.parse_args()
lib = ctypes.CDLL(str(a.library.resolve()))
init = lib.fgc49d_fixture_initialize_c
init.argtypes = [ctypes.POINTER(ctypes.c_int64), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double)]
h, h1, h2 = ctypes.c_int64(), ctypes.c_double(), ctypes.c_double()
assert init(ctypes.byref(h), ctypes.byref(h1), ctypes.byref(h2)) == 0
rain = lib.fgc49d_fixture_set_rain_c
rain.argtypes = [ctypes.c_double]
assert rain(a.rate) == 0
f = lib.strip01_diagnose_detail_c
f.argtypes = [ctypes.c_int, ctypes.c_double, ctypes.c_double,
              ctypes.POINTER(ctypes.c_int), ctypes.POINTER(ctypes.c_double)]
rows = []
for dt in (1e-3, 1e-4, 1e-5, 1e-6, 1e-7, 1e-8):
    codes, values = (ctypes.c_int * 12)(), (ctypes.c_double * 6)()
    assert f(1, -1.0, dt, codes, values) == 0
    rows.append(dict(dt_day=dt, codes=list(codes), observations=list(values)))
a.output.write_text(json.dumps(dict(top_flux_cm_per_day=a.rate, initial_time_day=0.0,
                                    attempts=rows), indent=2) + '\n')
