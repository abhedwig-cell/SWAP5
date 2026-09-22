from __future__ import annotations

import math
import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tests" / "research"))

from test_gc_dummy_swap_dsw01_live_modflow import run_case, require

H0 = 8.0
S_PHYS = 0.20
RAIN = 0.010
EXPECTED = 8.05
HEAD_TOL = 1.0e-10

CASES = (
    ("CORRECT_CONTROL", 0.20, 0.0, -RAIN, 8.05),
    ("DUPLICATE_STORAGE", 0.20, -0.20, -0.20 * H0 - RAIN, 8.025),
    ("WRONG_STORAGE_SIGN", 0.15, 0.05, 0.05 * H0 - RAIN, 8.10),
    ("REVERSED_FORCING_SIGN", 0.20, 0.0, RAIN, 7.95),
)


def main() -> None:
    libmf6 = Path(os.environ["LIBMF6"]).resolve()
    require(libmf6.is_file(), "missing libmf6")

    physical_mass_errors: dict[str, float] = {}
    heads: dict[str, float] = {}

    for name, sy, hcof, rhs, expected_signature in CASES:
        result = run_case(
            libmf6,
            f"dsw19_{name.lower()}",
            hcof_m2_per_day=hcof,
            rhs_m3_per_day=rhs,
            sy=sy,
            newton=False,
        )
        require(bool(result["converged"]), f"{name} did not converge: {result}")
        head = float(result["head_m"])
        physical_mass_error = S_PHYS * (head - H0) - RAIN
        heads[name] = head
        physical_mass_errors[name] = physical_mass_error

        print(f"GC_DSW19_{name}_HEAD_M={head:.17g}")
        print(f"GC_DSW19_{name}_EXPECTED_SIGNATURE_M={expected_signature:.17g}")
        print(f"GC_DSW19_{name}_PHYSICAL_HEAD_ERROR_M={head-EXPECTED:.17g}")
        print(f"GC_DSW19_{name}_PHYSICAL_MASS_ERROR_M={physical_mass_error:.17g}")
        print(f"GC_DSW19_{name}_MODFLOW_CONVERGED=1")

        require(math.isclose(head, expected_signature, rel_tol=0.0, abs_tol=HEAD_TOL), f"{name} signature")

    require(math.isclose(heads["CORRECT_CONTROL"], EXPECTED, rel_tol=0.0, abs_tol=HEAD_TOL), "control physical oracle")
    require(abs(physical_mass_errors["CORRECT_CONTROL"]) <= 1.0e-12, "control physical mass")
    for name in ("DUPLICATE_STORAGE", "WRONG_STORAGE_SIGN", "REVERSED_FORCING_SIGN"):
        require(abs(heads[name] - EXPECTED) > 1.0e-3, f"{name} not distinguishable from physical oracle")
    require(
        max(abs(physical_mass_errors[name]) for name in physical_mass_errors if name != "CORRECT_CONTROL") > 1.0e-3,
        "adversarial physical mass error too small",
    )

    print("GC_DSW19_ALL_SUBSYSTEM_SOLVES_CONVERGED=PASS")
    print("GC_DSW19_WRONG_SIGNATURES_PREDICTED=PASS")
    print("GC_DSW19_CONVERGENCE_NOT_CORRECTNESS=PASS")
    print("GC_DSW19_LIVE_GATE=PASS")


if __name__ == "__main__":
    main()
