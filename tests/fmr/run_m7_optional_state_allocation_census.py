#!/usr/bin/env python3
"""Compile and replay the bounded M7 optional physical-state allocation test."""
from __future__ import annotations

import os
from pathlib import Path
import re
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parents[2]
SOURCE_RUNNER = ROOT / "tests/fapp/run_ppa_wu01_production_application_bootstrap.sh"
TEST_SOURCE = ROOT / "tests/fmr/test_m7_optional_state_allocation_census.f90"
FLAGS = [
    "-std=f2008",
    "-ffree-line-length-none",
    "-Wall",
    "-Wextra",
    "-fopenmp",
    "-fcheck=all",
    "-fbacktrace",
    "-ffpe-trap=invalid,zero,overflow",
]
EXPECTED_MARKERS = [
    "M7_OPTIONAL_STATE_INACTIVE_BASE_PAYLOADS_ABSENT=PASS",
    "M7_OPTIONAL_STATE_ACTIVE_PAYLOAD_CLONE_IDENTITY=PASS",
    "M7_OPTIONAL_STATE_ALLOCATION_CENSUS_TEST PASS",
]


def module_sources() -> list[Path]:
    text = SOURCE_RUNNER.read_text(encoding="utf-8")
    match = re.search(r"MODULE_SRC=\(\s*(.*?)\s*\)", text, re.S)
    if not match:
        raise RuntimeError(f"could not locate module list in {SOURCE_RUNNER}")
    paths = re.findall(r"(?m)^\s*([^\s]+\.f90)\s*$", match.group(1))
    if len(paths) < 80:
        raise RuntimeError(f"unexpectedly short Reference module list: {len(paths)}")
    return [ROOT / path for path in paths] + [TEST_SOURCE]


def main() -> int:
    compiler = os.environ.get("FC", "gfortran")
    transcripts: list[str] = []
    sources = module_sources()
    with tempfile.TemporaryDirectory(prefix="swap5-m7-optional-state-") as temp:
        for opt in ("0", "2"):
            out = Path(temp) / f"o{opt}"
            out.mkdir()
            executable = out / "test_m7_optional_state_allocation_census.exe"
            compile_cmd = [
                compiler,
                *FLAGS,
                f"-O{opt}",
                "-J",
                str(out),
                "-I",
                str(out),
                *(str(path) for path in sources),
                "-o",
                str(executable),
            ]
            built = subprocess.run(compile_cmd, cwd=ROOT, text=True, capture_output=True)
            if built.returncode:
                print(built.stdout, end="")
                print(built.stderr, end="")
                return built.returncode
            run = subprocess.run([str(executable)], cwd=ROOT, text=True, capture_output=True)
            transcript = run.stdout + run.stderr
            print(transcript, end="")
            if run.returncode:
                return run.returncode
            for marker in EXPECTED_MARKERS:
                if marker not in transcript:
                    raise RuntimeError(f"O{opt} transcript missing marker {marker}")
            transcripts.append(transcript)
        if transcripts[0] != transcripts[1]:
            raise RuntimeError("M7 optional-state O0/O2 transcript mismatch")
    print("M7_OPTIONAL_STATE_O0_O2_TRANSCRIPT_IDENTITY=PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
