#!/usr/bin/env python3
"""Strict SWAP-004 focused gate bound to the exact candidate patch."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import tempfile

REPO_ROOT = Path(__file__).resolve().parents[5]
PATCH = REPO_ROOT / "reference/swap-4.3.1/patches/SWAP-004/fix.patch"
CANDIDATE_HARNESS = Path(__file__).with_name("mapping_harness.f90")
B0_REPRODUCER = Path(__file__).with_name("b0_sparse_bounds.f90")
EVIDENCE = Path(__file__).with_name("evidence.json")
EXPECTED_PATCH_SHA256 = "0a1b52cb018ebfc6aa11da2e04d52e858addfa5810c69b0fe078fd5f8bed8818"
EXPECTED_B0_SHA256 = "731a873e0aa5ac25626a6d392c1668e66e57ee3fdc1d94b3eab127b8e343a486"
EXPECTED_ORDERED_SHA256 = "eaf1976238f7c659c1acb02f54685a7aafdf03d50d0978bbcc788b6ada441ca3"
EXPECTED_CANDIDATE_SHA256 = "41a42be1f55e533843b7ecc115f9de2fbd7bc4c08515cb58a9bf6efb0479bede"
REQUIRED_ADDED_LINES = (
    "+         if (allocated(iTT1)) deallocate(iTT1); allocate(iTT1(tmax)); iTT1 = 0",
    "+         if (allocated(iTT2)) deallocate(iTT2); allocate(iTT2(tmax)); iTT2 = 0",
    "+         do j = 1, tmax",
    "+         do i = 1, Ntill",
    "+            j = Type_Tillage(i)",
    "+            else if (iTT1(j) == 0 .OR. iTT2(j) == 0) then",
    "+               call swap_error ('read_tillage', 'Every TYPE_TILLAGE must have corresponding ITYPE_TILLAGE entries')",
)
FORBIDDEN = (
    "i_n_model=2 requires PCLAY > 0",
    "iTill = Ntill + 1",
)


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--compiler", default="gfortran")
    args = parser.parse_args()

    if sha256(PATCH) != EXPECTED_PATCH_SHA256:
        raise SystemExit("SWAP-004 gate: stored patch SHA mismatch")
    patch_text = PATCH.read_text(encoding="utf-8")
    positions = [patch_text.find(line) for line in REQUIRED_ADDED_LINES]
    if any(pos < 0 for pos in positions) or positions != sorted(positions):
        raise SystemExit(f"SWAP-004 gate: required added line missing/out of order: {positions}")
    for token in FORBIDDEN:
        if token in patch_text:
            raise SystemExit(f"SWAP-004 gate: unrelated tillage correction leaked into patch: {token}")

    evidence = json.loads(EVIDENCE.read_text(encoding="utf-8"))
    binding = evidence["source_binding"]
    required = {
        "canonical_b0_tillage_sha256": EXPECTED_B0_SHA256,
        "ordered_b1_10_tillage_sha256": EXPECTED_ORDERED_SHA256,
        "stored_patch_sha256": EXPECTED_PATCH_SHA256,
        "candidate_tillage_sha256": EXPECTED_CANDIDATE_SHA256,
    }
    if any(binding.get(key) != value for key, value in required.items()):
        raise SystemExit("SWAP-004 gate: evidence source binding mismatch")
    if evidence.get("candidate_cases", {}).get("total") != "4/4 PASS":
        raise SystemExit("SWAP-004 gate: candidate evidence is not 4/4 PASS")

    compiler = shutil.which(args.compiler)
    if not compiler:
        raise SystemExit(f"SWAP-004 gate: compiler not found: {args.compiler}")

    flags = ["-std=f2018", "-O0", "-Wall", "-Wextra", "-Werror", "-fcheck=all"]
    with tempfile.TemporaryDirectory() as tmp:
        tmpdir = Path(tmp)
        candidate_exe = tmpdir / "swap004_candidate"
        built = subprocess.run([compiler, *flags, str(CANDIDATE_HARNESS), "-o", str(candidate_exe)], text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        if built.returncode != 0:
            raise SystemExit("SWAP-004 gate: candidate harness compile failed\n" + built.stdout)
        run = subprocess.run([str(candidate_exe)], text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        if run.returncode != 0 or "SWAP-004_CANDIDATE_HARNESS PASS 4/4" not in run.stdout:
            raise SystemExit("SWAP-004 gate: candidate harness failed\n" + run.stdout)
        print(run.stdout.strip())

        b0_exe = tmpdir / "swap004_b0_sparse"
        built = subprocess.run([compiler, *flags, str(B0_REPRODUCER), "-o", str(b0_exe)], text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        if built.returncode != 0:
            raise SystemExit("SWAP-004 gate: B0 reproducer compile failed\n" + built.stdout)
        legacy = subprocess.run([str(b0_exe)], text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        if legacy.returncode == 0:
            raise SystemExit("SWAP-004 gate: B0 sparse reproducer unexpectedly completed")
        if "above upper bound of 1" not in legacy.stdout:
            raise SystemExit("SWAP-004 gate: B0 failed for an unexpected reason\n" + legacy.stdout)
        print("SWAP-004_B0_SPARSE_BOUNDS_REPRODUCER PASS_EXPECTED_FAILURE")

    print("SWAP-004_FOCUSED_MAPPING_GATE PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
