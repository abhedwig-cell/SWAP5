#!/usr/bin/env python3
"""Measure common workspace payload and option calls for BASE and Black profiles."""
from __future__ import annotations

import os
from pathlib import Path
import sys
import tempfile

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).resolve().parent))
from run_m7_standalone_profile_examples import compile_run  # noqa: E402


PROFILES: dict[str, dict[str, object]] = {
    "base_inactive": {
        "runner": "tests/fapp/run_ppa_wu02_prescribed_qbot_application_admission.sh",
        "test": "tests/fmr/test_m7_serialized_worker_scratch_reuse.f90",
        "markers": [
            "M7_RESOURCE_BASE_OPTION_CALLS=0",
            "M7_SERIALIZED_WORKER_SCRATCH_REUSE_CROSS_COLUMN=PASS",
        ],
    },
    "black_active": {
        "runner": "tests/fapp/run_ppa_wu04a_black_evaporation.sh",
        "test": "tests/fapp/test_ppa_wu04a_black_runtime.f90",
        "markers": [
            "M7_RESOURCE_BLACK",
            "M7_RESOURCE_BLACK_OPTION_INPUT_BYTES",
            "PPA-WU04-A BLACK RUNTIME TEST PASS",
        ],
    },
    "boesten_active": {
        "runner": "tests/fapp/run_ppa_wu04b_boesten_evaporation.sh",
        "test": "tests/fapp/test_ppa_wu04b_boesten_runtime.f90",
        "markers": [
            "M7_RESOURCE_BOESTEN",
            "M7_RESOURCE_BOESTEN_OPTION_INPUT_BYTES",
            "PPA-WU04-B BOESTEN RUNTIME TEST PASS",
        ],
    },
}


def main() -> int:
    compiler = os.environ.get("FC", "gfortran")
    temp_root = os.environ.get("SWAP5_M7_TEMP_ROOT")
    with tempfile.TemporaryDirectory(prefix="swap5-m7-resource-census-", dir=temp_root) as raw_temp:
        temp = Path(raw_temp)
        for name, spec in PROFILES.items():
            outputs = [compile_run(name, spec, opt, temp, compiler) for opt in ("0", "2")]
            if outputs[0] != outputs[1]:
                raise RuntimeError(f"{name} O0/O2 resource transcript mismatch")
            print(f"M7_RESOURCE_PROFILE_{name.upper()}_O0_O2=PASS")
            print(outputs[0], end="")
    print("M7_OPTIONAL_RESOURCE_MEASUREMENT=PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
