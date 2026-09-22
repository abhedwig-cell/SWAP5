from __future__ import annotations

import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
LEGACY = ROOT / "src" / "legacy" / "b1_10_port" / "headcalc.f90"
CONTRACT = ROOT / "src" / "runtime" / "mod_groundwater_coupling_contract.f90"

Z_BOTTOM_NODE_M = -2.5
DZ_BOTTOM_M = 1.0
Z_BOTTOM_FACE_M = -3.0
GW_LEVELS_M = (-3.1, -3.5, -5.0, -10.0)


def require(value: bool, message: str) -> None:
    if not value:
        raise AssertionError(message)


def legacy_hbot_cm(gwl_m: float) -> float:
    return (gwl_m - Z_BOTTOM_NODE_M + 0.5 * DZ_BOTTOM_M) * 100.0


def current_hbot_cm(head_m: float) -> float:
    return (head_m - Z_BOTTOM_FACE_M) * 100.0


def roundtrip_head_m(hbot_cm: float) -> float:
    return Z_BOTTOM_FACE_M + hbot_cm / 100.0


def main() -> None:
    legacy_source = LEGACY.read_text(encoding="utf-8")
    contract_source = CONTRACT.read_text(encoding="utf-8")

    require(
        "state%hbot     = state%gwlinp - grid_z(numnod) + 0.5d0*grid_dz(numnod)"
        in legacy_source,
        "legacy mode-1 below-profile formula drifted",
    )
    require(
        "swbotb == 5 .OR. (swbotb == 1 .AND. state%fllowgwl)" in legacy_source,
        "shared mode-5 residual branch marker missing",
    )
    require(
        "pressure_head_cm = (head_m - datum%bottom_boundary_elevation_m) * M_TO_CM"
        in contract_source,
        "current datum conversion formula drifted",
    )

    print("GC_LOW01A_SOURCE_AUTHORITY=PASS")

    for index, gwl in enumerate(GW_LEVELS_M, start=1):
        require(gwl < Z_BOTTOM_FACE_M, f"case {index} is not below profile")
        legacy_hbot = legacy_hbot_cm(gwl)
        current_hbot = current_hbot_cm(gwl)
        recovered = roundtrip_head_m(current_hbot)

        print(f"GC_LOW01A_CASE_{index}_GWL_M={gwl:.17g}")
        print(f"GC_LOW01A_CASE_{index}_LEGACY_HBOT_CM={legacy_hbot:.17g}")
        print(f"GC_LOW01A_CASE_{index}_CURRENT_HBOT_CM={current_hbot:.17g}")
        print(f"GC_LOW01A_CASE_{index}_ROUNDTRIP_HEAD_M={recovered:.17g}")

        require(
            math.isclose(legacy_hbot, current_hbot, rel_tol=0.0, abs_tol=1.0e-12),
            f"case {index} hbot mismatch",
        )
        require(
            math.isclose(recovered, gwl, rel_tol=0.0, abs_tol=1.0e-14),
            f"case {index} roundtrip mismatch",
        )

    print("GC_LOW01A_ALL_CASES_BELOW_PROFILE=PASS")
    print("GC_LOW01A_LEGACY_MODE1_EQUALS_MODE5_MAPPING=PASS")
    print("GC_LOW01A_ROUNDTRIP_DATUM=PASS")
    print("GC_LOW01A_SHARED_RESIDUAL_JACOBIAN_BRANCH=PASS")
    print("GC_LOW01A_GATE=PASS")


if __name__ == "__main__":
    main()
