#!/usr/bin/env python3
"""Run the current serialized-runtime A-B-A worker-scratch reuse replay on O0/O2."""
from __future__ import annotations

import os
from pathlib import Path
import sys
import tempfile

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).resolve().parent))
from run_m7_standalone_profile_examples import compile_run  # noqa: E402


SPEC: dict[str, object] = {
    "runner": "tests/fapp/run_ppa_wu02_prescribed_qbot_application_admission.sh",
    "test": "tests/fmr/test_m7_serialized_worker_scratch_reuse.f90",
    "markers": [
        "M7_WORKER_SCRATCH_A_B_A_STATE_IDENTITY=PASS",
        "M7_WORKER_SCRATCH_A_B_A_MASS_IDENTITY=PASS",
        "M7_WORKER_SCRATCH_ALL_COLUMNS_COMMITTED_HARD_MASS=PASS",
        "M7_SERIALIZED_WORKER_SCRATCH_REUSE_CROSS_COLUMN=PASS",
    ],
}


def main() -> int:
    compiler = os.environ.get("FC", "gfortran")
    temp_root = os.environ.get("SWAP5_M7_TEMP_ROOT")
    with tempfile.TemporaryDirectory(prefix="swap5-m7-worker-scratch-", dir=temp_root) as raw_temp:
        temp = Path(raw_temp)
        outputs = [compile_run("worker_scratch_reuse", SPEC, opt, temp, compiler) for opt in ("0", "2")]
        if outputs[0] != outputs[1]:
            raise RuntimeError("worker-scratch A-B-A O0/O2 runtime transcript mismatch")
        print(outputs[0], end="")
    print("M7_WORKER_SCRATCH_A_B_A_O0_O2_TRANSCRIPT_IDENTITY=PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
