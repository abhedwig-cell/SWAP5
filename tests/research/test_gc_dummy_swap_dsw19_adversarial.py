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
INPUT = 0.010
DT = 1.0
HEAD_TOL = 1.0e-10

CASES = (
    {
        "name": "CORRECT_CONTROL",
        "sy": 0.20,
        "hcof": 0.0,
        "rhs": -INPUT,
        "expected_head": 8.05,
        "expected_mass_error": 0.0,
        "scientifically_correct": True,
    },
    {
        "name": "DUPLICATE_STORAGE",
        "sy": 0.20,
        "hcof": -0.20,
        "rhs": -0.20 * H0 - INPUT,
        "expected_head": 8.025,
        "expected_mass_error": -0.005,
        "scientifically_correct": False,
    },
    {
        "name": "WRONG_STORAGE_SIGN",
        "sy": 0.15,
        "hcof": +0.05,
        "rhs": +0.05 * H0 - INPUT,
        "expected_head": 8.10,
        "expected_mass_error": +0.010,
        "scientifically_correct": False,
    },
    {
        "name": "REVERSED_FORCING_SIGN",
        "sy": 0.20,
        "hcof": 0.0,
        "rhs": +INPUT,
        "expected_head": 7.95,
        "expected_mass_error": -0.020,
        "scientifically_correct": False,
    },
)


def main() -> None:
    libmf6 = Path(os.environ["LIBMF6"]).resolve()
    require(libmf6.is_file(), "missing libmf6")

    converged_count = 0
    rejected_count = 0

    for case in CASES:
        name = str(case["name"])
        result = run_case(
            libmf6,
            f"dsw19_{name.lower()}",
            hcof_m2_per_day=float(case["hcof"]),
            rhs_m3_per_day=float(case["rhs"]),
            sy=float(case["sy"]),
            newton=False,
            initial_head_m=H0,
            dt_day=DT,
            ims_rclose=1.0e-13,
        )
        require(bool(result["converged"]), f"{name} did not converge: {result}")
        converged_count += 1

        head = float(result["head_m"])
        require(
            math.isclose(
                head,
                float(case["expected_head"]),
                rel_tol=0.0,
                abs_tol=HEAD_TOL,
            ),
            f"{name} wrong numerical signature: {head}",
        )

        # Scientific ledger is always evaluated against the intended physical
        # control volume, not against the deliberately corrupted equations.
        physical_mass_error = S_PHYS * (head - H0) - INPUT
        require(
            math.isclose(
                physical_mass_error,
                float(case["expected_mass_error"]),
                rel_tol=0.0,
                abs_tol=1.0e-12,
            ),
            f"{name} unexpected intended-physics mass signature",
        )

        head_error = head - 8.05
        scientifically_correct = bool(case["scientifically_correct"])
        accepted_by_physics = (
            abs(head_error) <= HEAD_TOL and abs(physical_mass_error) <= 1.0e-12
        )
        if scientifically_correct:
            require(accepted_by_physics, "correct control rejected by physical oracle")
        else:
            require(not accepted_by_physics, f"{name} adversarial case escaped rejection")
            rejected_count += 1

        print(f"GC_DSW19_{name}_MODFLOW_CONVERGED=1")
        print(f"GC_DSW19_{name}_HEAD_M={head:.17g}")
        print(f"GC_DSW19_{name}_PHYSICAL_HEAD_ERROR_M={head_error:.17g}")
        print(f"GC_DSW19_{name}_PHYSICAL_MASS_ERROR_M={physical_mass_error:.17g}")
        print(f"GC_DSW19_{name}_PHYSICS_ACCEPTED={1 if accepted_by_physics else 0}")

    require(converged_count == 4, "not all adversarial systems converged")
    require(rejected_count == 3, "not all deliberately wrong systems were rejected")

    print("GC_DSW19_ALL_NUMERICAL_SYSTEMS_CONVERGED=PASS")
    print("GC_DSW19_CORRECT_CONTROL_ACCEPTED=PASS")
    print("GC_DSW19_ADVERSARIAL_CASES_REJECTED=PASS")
    print("GC_DSW19_CONVERGENCE_NOT_SCIENTIFIC_ACCEPTANCE=PASS")
    print("GC_DSW19_LIVE_GATE=PASS")


if __name__ == "__main__":
    main()
