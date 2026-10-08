#!/usr/bin/env python3
"""Strict local SW431 root oxygen/supply component gate (no GitHub Actions)."""
from pathlib import Path
import os
import shlex
import subprocess
import tempfile

root = Path(__file__).resolve().parents[2]
sources = [
    root / "src/crop/mod_crop_root_anaerobic_extension_gate.f90",
    root / "src/crop/mod_crop_root_extension_supply_limit.f90",
    root / "tests/fmig431/test_swap431_root_anox_supply_combined.f90",
]
outputs = {}
with tempfile.TemporaryDirectory(prefix="swap431-root-anox-supply-") as tmp:
    for optimization in ("O0", "O2"):
        build = Path(tmp) / optimization
        build.mkdir()
        executable = build / "test"
        command = shlex.split(os.environ.get("FC", "gfortran")) + [
            "-" + optimization, "-std=f2008", "-ffree-line-length-none",
            "-Wall", "-Wextra", "-Werror", "-fcheck=all",
            "-ffpe-trap=invalid,zero,overflow", "-J" + str(build),
            "-I" + str(build),
        ] + [str(path) for path in sources] + ["-o", str(executable)]
        subprocess.run(command, check=True, cwd=build)
        result = subprocess.run([str(executable)], cwd=build, check=True, capture_output=True, text=True)
        outputs[optimization] = result.stdout
        print(optimization + ": " + result.stdout.strip())
if outputs["O0"] != outputs["O2"]:
    raise SystemExit("O0/O2 output drift")
if "ROOT_ANOX_SUPPLY_COMBINED=PASS" not in outputs["O0"]:
    raise SystemExit("missing expected result")
print("SW431_ROOT_ANOX_SUPPLY_O0_O2=PASS")
