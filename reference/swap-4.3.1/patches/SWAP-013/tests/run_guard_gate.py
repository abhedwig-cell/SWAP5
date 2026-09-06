#!/usr/bin/env python3
"""Compile the SWAP-013 guard harness and bind it to the exact stored patch."""
from __future__ import annotations

import argparse
import hashlib
import math
from pathlib import Path
import shutil
import subprocess
import tempfile

REPO_ROOT = Path(__file__).resolve().parents[5]
PATCH = REPO_ROOT / "reference/swap-4.3.1/patches/SWAP-013/fix.patch"
HARNESS = Path(__file__).with_name("guard_harness.f90")
EXPECTED_PATCH_SHA256 = "066c1c1aba8f32cb3a9aab3d17f1900b0ba8a28f43173d80461c91fb1a8f25f3"
REQUIRED_PATCH_TOKENS = (
    "call rdfdor ('ha',-1.0d5,0.0d0,ha,maho,numlay);  ha(1:numlay) = -ha(1:numlay)",
    "do lay = 1, numlay",
    "if (iHWCKmodel(lay) >= 8 .AND. iHWCKmodel(lay) <= 11) then",
    "if (ha(lay) <= 0.0d0 .OR. ha(lay) >= h0(lay)) then",
    "PDI requires 0 < abs(HA) < abs(H0) for every PDI soil layer",
    "call rdfdor ('apar',-5.0d0,0.0d0,apar,maho,numlay)",
)


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--compiler", default="gfortran")
    args = parser.parse_args()

    if sha256(PATCH) != EXPECTED_PATCH_SHA256:
        raise SystemExit("SWAP-013 gate: stored patch SHA mismatch")
    patch_text = PATCH.read_text(encoding="utf-8")
    positions = [patch_text.find(token) for token in REQUIRED_PATCH_TOKENS]
    if any(pos < 0 for pos in positions):
        raise SystemExit(f"SWAP-013 gate: required patch token missing: {positions}")
    if positions != sorted(positions):
        raise SystemExit("SWAP-013 gate: guard is not located after HA sign conversion and before APAR read")

    # Independent mathematical singularities motivating the guard.
    try:
        math.log10(0.0)
    except ValueError:
        pass
    else:
        raise SystemExit("SWAP-013 gate: expected log10(0) domain failure")
    h0 = 1.0e5
    ha = 1.0e5
    if math.log10(ha) - math.log10(h0) != 0.0:
        raise SystemExit("SWAP-013 gate: expected zero PDI logarithmic denominator at HA=H0")

    compiler = shutil.which(args.compiler)
    if not compiler:
        raise SystemExit(f"SWAP-013 gate: compiler not found: {args.compiler}")

    with tempfile.TemporaryDirectory() as tmp:
        exe = Path(tmp) / "swap013_guard"
        command = [
            compiler,
            "-std=f2018",
            "-O0",
            "-Wall",
            "-Wextra",
            "-Werror",
            "-fcheck=all",
            "-ffpe-trap=invalid,zero,overflow",
            str(HARNESS),
            "-o",
            str(exe),
        ]
        built = subprocess.run(command, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        if built.returncode != 0:
            raise SystemExit("SWAP-013 gate: harness compile failed\n" + built.stdout)
        run = subprocess.run([str(exe)], text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        if run.returncode != 0 or "SWAP-013_GUARD_HARNESS PASS 9/9" not in run.stdout:
            raise SystemExit("SWAP-013 gate: harness failed\n" + run.stdout)
        print(run.stdout.strip())

    print("SWAP-013_SOURCE_BOUND_GUARD_GATE PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
