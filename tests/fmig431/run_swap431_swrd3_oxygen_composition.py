#!/usr/bin/env python3
"""Exact-tree O0/O2 SWRD3 actual/potential oxygen composition gate."""
from pathlib import Path
import os
import re
import shlex
import subprocess
import tempfile

root = Path(__file__).resolve().parents[2]
test = root / "tests/fmig431/test_swap431_swrd3_oxygen_composition.f90"
modules = {}
for path in sorted((root / "src").rglob("*.f90")):
    for name in re.findall(r"^\s*module\s+(?!procedure\b)(\w+)", path.read_text(), re.I | re.M):
        key = name.lower()
        if key in modules and modules[key] != path:
            raise RuntimeError(f"duplicate Fortran module {key}: {modules[key]} and {path}")
        modules[key] = path

intrinsic = {"iso_fortran_env", "iso_c_binding", "ieee_arithmetic", "omp_lib"}
ordered, visited, active = [], set(), set()
def visit(path):
    if path in visited:
        return
    if path in active:
        raise RuntimeError(f"circular module dependency: {path}")
    active.add(path)
    for name in re.findall(r"^\s*use\s*(?:,\s*non_intrinsic\s*)?(?:::)?\s*(\w+)", path.read_text(), re.I | re.M):
        key = name.lower()
        if key in modules:
            visit(modules[key])
        elif key not in intrinsic:
            raise RuntimeError(f"unresolved module {name} in {path}")
    active.remove(path)
    visited.add(path)
    ordered.append(path)

visit(test)
results = []
with tempfile.TemporaryDirectory(prefix="swap431-swrd3-oxygen-") as temp:
    for opt in ("O0", "O2"):
        folder = Path(temp) / opt
        folder.mkdir()
        flags = [f"-{opt}", "-std=f2008", "-ffree-line-length-none", "-Wall", "-Wextra",
                 "-Werror", "-Wno-error=compare-reals", "-fcheck=all",
                 "-ffpe-trap=invalid,zero,overflow", "-J" + str(folder), "-I" + str(folder)]
        compiler = shlex.split(os.getenv("FC", "gfortran"))
        objects = []
        for index, source in enumerate(ordered):
            output = folder / f"{index}_{source.stem}.o"
            subprocess.run(compiler + flags + ["-c", str(source), "-o", str(output)], check=True)
            objects.append(str(output))
        binary = folder / "test"
        subprocess.run(compiler + flags + objects + ["-o", str(binary)], check=True)
        output = subprocess.run([str(binary)], capture_output=True, text=True, check=True)
        print(opt + ": " + output.stdout.strip())
        results.append(output.stdout)
if results[0] != results[1] or "SW431_SWRD3_OXYGEN_COMPOSITION=PASS" not in results[0]:
    raise SystemExit("SWRD3 oxygen composition O0/O2 mismatch")
print("SW431_SWRD3_OXYGEN_COMPOSITION_O0_O2=PASS")
