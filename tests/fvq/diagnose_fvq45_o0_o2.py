#!/usr/bin/env python3
import importlib.util
import math
import subprocess
import tempfile
from pathlib import Path

TARGET = Path("tests/fvq/test_fvq45_divdra_spatial_distribution.py")
spec = importlib.util.spec_from_file_location("fvq45", TARGET)
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)

source = subprocess.run(
    ["git", "show", f"{mod.CANDIDATE}:{mod.CANDIDATE_PATH}"],
    check=True, capture_output=True, text=True,
).stdout
stable = mod.make_stable_cases()
boundary = mod.make_boundary_cases()
zero = {
    "dz": [10.0, 20.0, 30.0], "zbot": [-10.0, -30.0, -60.0],
    "ksat": [1.0, 2.0, 3.0], "aniso": [1.0, 1.5, 0.8],
    "q": 0.0, "gwl": float("nan"), "spacing": 50.0,
}
small = []
for q in [math.nextafter(0.0, 1.0), 0.5e-10, 1.0e-10]:
    small.append({
        "dz": [10.0, 20.0, 30.0], "zbot": [-10.0, -30.0, -60.0],
        "ksat": [1.0, 2.0, 3.0], "aniso": [1.0, 1.5, 0.8],
        "q": q, "gwl": -12.0, "spacing": 50.0,
    })
cases = stable + boundary + [zero] + small

with tempfile.TemporaryDirectory(prefix="fvq45_diag_") as tmp:
    mod.write_sources(tmp, source)
    exe0 = mod.compile_driver(tmp, "-O0")
    exe2 = mod.compile_driver(tmp, "-O2")
    rows0, out0 = mod.run_cases(exe0, cases)
    rows2, out2 = mod.run_cases(exe2, cases)

lines0 = out0.splitlines()
lines2 = out2.splitlines()
print(f"FVQ45_DIAG_TEXT_IDENTICAL={out0 == out2}")
for i, (a, b) in enumerate(zip(lines0, lines2)):
    if a != b:
        print(f"FVQ45_DIAG_FIRST_DIFFERING_CASE={i}")
        print("FVQ45_DIAG_O0=" + a)
        print("FVQ45_DIAG_O2=" + b)
        break

structural_keys = ["status", "evaluated", "zero", "wt", "bottom", "scalar_authoritative", "worker_scratch"]
numeric_keys = ["wlev", "dz_top", "bottom_thickness", "fac", "discharge_bottom", "kd", "raw_sum", "closure", "sum_nodes", "identity_residual"]
structural_mismatch = 0
max_abs = {k: 0.0 for k in numeric_keys}
max_node_abs = 0.0
first_structural = None
for i, (a, b) in enumerate(zip(rows0, rows2)):
    for key in structural_keys:
        if a[key] != b[key]:
            structural_mismatch += 1
            if first_structural is None:
                first_structural = (i, key, a[key], b[key])
    for key in numeric_keys:
        diff = abs(a[key] - b[key])
        if math.isfinite(diff):
            max_abs[key] = max(max_abs[key], diff)
    for x, y in zip(a["nodes"], b["nodes"]):
        diff = abs(x - y)
        if math.isfinite(diff):
            max_node_abs = max(max_node_abs, diff)

print(f"FVQ45_DIAG_STRUCTURAL_MISMATCH_COUNT={structural_mismatch}")
print(f"FVQ45_DIAG_FIRST_STRUCTURAL_MISMATCH={first_structural}")
print(f"FVQ45_DIAG_MAX_NODE_ABS={max_node_abs:.17g}")
for key in numeric_keys:
    print(f"FVQ45_DIAG_MAX_{key.upper()}_ABS={max_abs[key]:.17g}")
