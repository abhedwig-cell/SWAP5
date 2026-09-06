#!/usr/bin/env python3
"""Compile the SWAP-002 tillage-start harness and bind it to the exact stored patch."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import tempfile

REPO_ROOT = Path(__file__).resolve().parents[5]
PATCH = REPO_ROOT / "reference/swap-4.3.1/patches/SWAP-002/fix.patch"
HARNESS = Path(__file__).with_name("tillage_start_harness.f90")
EVIDENCE = Path(__file__).with_name("actual_source_start_evidence.json")
EXPECTED_PATCH_SHA256 = "80e12cd4e9f47c192bd6c7d5ee7d460c473b3a2b29a5a553e8c35cf0b90b5c13"
EXPECTED_B0_SHA256 = "731a873e0aa5ac25626a6d392c1668e66e57ee3fdc1d94b3eab127b8e343a486"
EXPECTED_CORRECTED_SHA256 = "eaf1976238f7c659c1acb02f54685a7aafdf03d50d0978bbcc788b6ada441ca3"
REQUIRED_NEW_TOKENS = (
    "iTill = Ntill + 1",
    "do i = 1, Ntill",
    "if (t1900 <= Date_tillage(i)) then",
    "iTill = i",
    "if (iTill > 1) call Change_Tillage_Info(iTill-1)",
)
FORBIDDEN_ADMITTED_TOKENS = (
    "i_n_model=2 requires PCLAY > 0",
    "allocate(iTT1(tmax))",
    "TYPE_TILLAGE is outside the range defined by ITYPE_TILLAGE",
)
LEGACY_IMPOSSIBLE = "t1900 >= Date_tillage(i-1) .AND. t1900 < Date_tillage(i-1)"


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--compiler", default="gfortran")
    args = parser.parse_args()

    if sha256(PATCH) != EXPECTED_PATCH_SHA256:
        raise SystemExit("SWAP-002 gate: stored patch SHA mismatch")
    patch_text = PATCH.read_text(encoding="utf-8")
    positions = [patch_text.find(token) for token in REQUIRED_NEW_TOKENS]
    if any(pos < 0 for pos in positions) or positions != sorted(positions):
        raise SystemExit(f"SWAP-002 gate: required set_iTill token missing/out of order: {positions}")
    if "-      if (" + LEGACY_IMPOSSIBLE + " iTill = i-1" not in patch_text:
        # The exact removed line is easier and less ambiguous to check directly below.
        removed = "-      if (t1900 >= Date_tillage(i-1) .AND. t1900 < Date_tillage(i-1)) iTill = i-1"
        if removed not in patch_text:
            raise SystemExit("SWAP-002 gate: legacy impossible interval line is not the removed preimage")
    for token in FORBIDDEN_ADMITTED_TOKENS:
        if token in patch_text:
            raise SystemExit(f"SWAP-002 gate: unrelated tillage fix leaked into patch: {token}")

    evidence = json.loads(EVIDENCE.read_text(encoding="utf-8"))
    binding = evidence["source_binding"]
    if binding["canonical_b0_tillage_sha256"] != EXPECTED_B0_SHA256:
        raise SystemExit("SWAP-002 gate: evidence B0 pin mismatch")
    if binding["stored_patch_sha256"] != EXPECTED_PATCH_SHA256:
        raise SystemExit("SWAP-002 gate: evidence patch pin mismatch")
    if binding["corrected_tillage_sha256"] != EXPECTED_CORRECTED_SHA256:
        raise SystemExit("SWAP-002 gate: evidence corrected-target pin mismatch")
    if evidence["b0"]["passed"] != 3 or evidence["b0"]["total"] != 6:
        raise SystemExit("SWAP-002 gate: B0 defect evidence changed")
    if evidence["candidate"]["passed"] != 6 or evidence["candidate"]["total"] != 6:
        raise SystemExit("SWAP-002 gate: candidate evidence is not 6/6")

    compiler = shutil.which(args.compiler)
    if not compiler:
        raise SystemExit(f"SWAP-002 gate: compiler not found: {args.compiler}")

    with tempfile.TemporaryDirectory() as tmp:
        exe = Path(tmp) / "swap002_tillage_start"
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
            raise SystemExit("SWAP-002 gate: harness compile failed\n" + built.stdout)
        run = subprocess.run([str(exe)], text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        if run.returncode != 0 or "SWAP-002_TILLAGE_START_HARNESS PASS 6/6" not in run.stdout:
            raise SystemExit("SWAP-002 gate: harness failed\n" + run.stdout)
        print(run.stdout.strip())

    print("SWAP-002_SOURCE_BOUND_TILLAGE_START_GATE PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
