#!/usr/bin/env python3
"""Run the SWAP-009 function-level PDI hydraulic qualification gate.

This test requires a byte-exact B0 WC_K_models_04_11.f90 file and gfortran.
It uses the dossier's existing apply_and_verify.py to materialize the exact
candidate target, compiles original and corrected modules under strict runtime
checks, and verifies the Kelvin vapor-term ratio through the real PDI K route.

This is not a full SWAP production-path or water-balance test.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import math
from pathlib import Path
import shutil
import subprocess
import tempfile

HERE = Path(__file__).resolve().parent
DOSSIER = HERE.parent
APPLIER = DOSSIER / "apply_and_verify.py"
STUBS = HERE / "stubs.f90"
HARNESS = HERE / "pdi_harness.f90"

B0_SHA256 = "1f956cae894e83e208630e234c9b2017c945b2c522daf8277e89541f598ae4fd"
CORRECTED_SHA256 = "f728e832645ab8273e41d0d285910240565148671989de24882740e7244f15b7"
PATCH_SHA256 = "43e63c098868632da51a3dd1c2980e9af72d6ce2a3dabafadff76f2151256f66"
REL_RATIO_TOL = 1.0e-9


def sha256_file(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def run(cmd: list[str], cwd: Path, *, capture: bool = False) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        cmd,
        cwd=cwd,
        check=True,
        text=True,
        stdout=subprocess.PIPE if capture else None,
        stderr=subprocess.PIPE if capture else None,
    )


def compile_and_run(source: Path, work: Path) -> list[dict[str, float]]:
    flags = [
        "-std=f2018",
        "-ffree-line-length-none",
        "-O0",
        "-fcheck=all",
        "-ffpe-trap=invalid,zero,overflow",
        "-Wall",
        "-Wextra",
    ]
    run(["gfortran", *flags, "-c", str(STUBS)], work)
    run(["gfortran", *flags, "-c", str(source)], work)
    run(
        [
            "gfortran",
            *flags,
            str(HARNESS),
            "stubs.o",
            "WC_K_models_04_11.o",
            "-o",
            "pdi_test",
        ],
        work,
    )
    completed = run([str(work / "pdi_test")], work, capture=True)
    reader = csv.DictReader(completed.stdout.splitlines())
    return [{k: float(v) for k, v in row.items()} for row in reader]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("b0_target", type=Path, help="byte-exact B0 WC_K_models_04_11.f90")
    parser.add_argument("--output", type=Path, default=None, help="write JSON evidence")
    args = parser.parse_args()

    if shutil.which("gfortran") is None:
        raise SystemExit("SWAP-009 hydraulic gate requires gfortran")

    b0 = args.b0_target.resolve()
    if sha256_file(b0) != B0_SHA256:
        raise SystemExit(f"B0 target SHA mismatch: {sha256_file(b0)}")

    patch_path = DOSSIER / "fix.patch"
    if sha256_file(patch_path) != PATCH_SHA256:
        raise SystemExit(f"stored fix.patch SHA mismatch: {sha256_file(patch_path)}")

    with tempfile.TemporaryDirectory(prefix="swap009-hydraulic-") as tmp:
        work_root = Path(tmp)
        original_dir = work_root / "original"
        corrected_dir = work_root / "corrected"
        original_dir.mkdir()
        corrected_dir.mkdir()
        original = original_dir / "WC_K_models_04_11.f90"
        corrected = corrected_dir / "WC_K_models_04_11.f90"
        original.write_bytes(b0.read_bytes())

        run(["python3", str(APPLIER), str(b0), str(corrected)], work_root)
        if sha256_file(corrected) != CORRECTED_SHA256:
            raise SystemExit("candidate target identity mismatch after materialization")

        old_rows = compile_and_run(original, original_dir)
        new_rows = compile_and_run(corrected, corrected_dir)

    if len(old_rows) != 3 or len(new_rows) != 3:
        raise SystemExit("unexpected harness row count")

    mg_rt = (0.018015 * 9.81 / 8.314) / (20.0 + 273.15)
    comparisons = []
    for old, new in zip(old_rows, new_rows):
        if old["h_cm"] != new["h_cm"]:
            raise SystemExit("head grid mismatch")
        h = old["h_cm"]
        ratio = old["kvap"] / new["kvap"]
        theory = math.exp(2.0 * abs(h) / 100.0 * mg_rt)
        relerr = abs(ratio - theory) / theory
        wc_delta = old["wc"] - new["wc"]
        no_vap_delta = old["k_no_vap"] - new["k_no_vap"]
        passed = relerr <= REL_RATIO_TOL and wc_delta == 0.0 and no_vap_delta == 0.0
        comparisons.append(
            {
                "h_cm": h,
                "old_kvap": old["kvap"],
                "corrected_kvap": new["kvap"],
                "old_over_corrected_kvap": ratio,
                "independent_kelvin_ratio": theory,
                "relative_ratio_error": relerr,
                "water_content_delta": wc_delta,
                "k_no_vap_delta": no_vap_delta,
                "old_total_k": old["k_total"],
                "corrected_total_k": new["k_total"],
                "old_over_corrected_total_k": old["k_total"] / new["k_total"],
                "pass": passed,
            }
        )

    compiler = run(["gfortran", "--version"], Path.cwd(), capture=True).stdout.splitlines()[0]
    result = {
        "gate": "SWAP-009-exact-candidate-PDI-hydraulic-function-level",
        "status": "PASS" if all(item["pass"] for item in comparisons) else "FAIL",
        "scope": "function-level actual WC_K_models_04_11 PDI vapor path; not full SWAP",
        "compiler": compiler,
        "compile_flags": "-std=f2018 -ffree-line-length-none -O0 -fcheck=all -ffpe-trap=invalid,zero,overflow -Wall -Wextra",
        "b0_target_sha256": B0_SHA256,
        "stored_patch_sha256": PATCH_SHA256,
        "corrected_target_sha256": CORRECTED_SHA256,
        "model": 8,
        "temperature_c": 20.0,
        "ratio_tolerance": REL_RATIO_TOL,
        "comparisons": comparisons,
        "remaining_gates": [
            "B1.5p1 VQ integration/identity acceptance",
            "representative full SWAP PDI production-path regression",
            "hard water-balance evidence for full production-path regression",
        ],
    }

    text = json.dumps(result, indent=2, sort_keys=True)
    print(text)
    if args.output:
        args.output.write_text(text + "\n", encoding="utf-8")
    return 0 if result["status"] == "PASS" else 2


if __name__ == "__main__":
    raise SystemExit(main())
