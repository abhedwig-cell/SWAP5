#!/usr/bin/env python3
"""Run the isolated B1.11 MICRO stress-factor source slice at O0 and O2."""
import pathlib
import subprocess
import tempfile

root = pathlib.Path(__file__).resolve().parents[2]
sources = ("src/process/mod_root_micro_stress_factors.f90",
           "tests/physics/test_ppa_micro07_stress_factors.f90")
outputs = []
with tempfile.TemporaryDirectory(prefix="ppa-micro07-stress-") as tmp:
    for opt in ("O0", "O2"):
        build = pathlib.Path(tmp) / opt
        build.mkdir()
        objects = []
        for source in sources:
            obj = build / (pathlib.Path(source).stem + ".o")
            subprocess.run(["gfortran", "-std=f2008", "-ffree-line-length-none", "-fcheck=all",
                            "-ffpe-trap=invalid,zero,overflow", f"-{opt}", f"-J{build}",
                            f"-I{build}", "-c", source, "-o", str(obj)], cwd=root, check=True)
            objects.append(str(obj))
        exe = build / "test"
        subprocess.run(["gfortran", *objects, "-o", str(exe)], check=True)
        result = subprocess.run([str(exe)], text=True, capture_output=True, check=True)
        outputs.append(result.stdout)
        print(f"MICRO07_{opt}\n{result.stdout}", end="", flush=True)
assert outputs[0] == outputs[1], "O0/O2 semantic drift"
assert outputs[0].count("=PASS") == 5
print("MICRO07_SOURCE_FACTOR_LOCAL_O0_O2=PASS")
