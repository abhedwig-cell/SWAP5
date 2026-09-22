from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "src" / "legacy" / "b1_10_port" / "headcalc.f90"


def require(value: bool, message: str) -> None:
    if not value:
        raise AssertionError(message)


def normalized(text: str) -> str:
    return re.sub(r"\s+", " ", text.replace("\n", " ")).strip().lower()


def main() -> None:
    source = SOURCE.read_text(encoding="utf-8")
    flat = normalized(source)

    hbot_relation = normalized(
        "state%hbot = state%gwlinp - grid_z(numnod) + 0.5d0*grid_dz(numnod)"
    )
    require(hbot_relation in flat, "legacy below-profile hbot relation missing")

    residual_branch = normalized(
        "else if (swbotb == 5 .OR. (swbotb == 1 .AND. state%fllowgwl)) then"
    )
    residual_count = flat.count(residual_branch)
    require(
        residual_count >= 2,
        f"expected mode-5/mode-1-below-profile residual/flux branch at least twice, got {residual_count}",
    )

    jacobian_pattern = re.compile(
        r"else if \(swbotb == 5 \.or\. \(swbotb == 1 \.and\. state%fllowgwl\) \.or\. swbotb == 9\) then",
        re.IGNORECASE,
    )
    require(jacobian_pattern.search(flat) is not None, "shared lower-head Jacobian branch missing")

    fllow_assignment = normalized("state%fllowgwl = .TRUE.")
    require(fllow_assignment in flat, "below-profile fllowgwl activation missing")

    print(f"GC_LOW01A_SOURCE_RESIDUAL_BRANCH_COUNT={residual_count}")
    print("GC_LOW01A_SOURCE_HBOT_RELATION=PASS")
    print("GC_LOW01A_SOURCE_FLLOWGWL_ACTIVATION=PASS")
    print("GC_LOW01A_SOURCE_RESIDUAL_BRANCH_IDENTITY=PASS")
    print("GC_LOW01A_SOURCE_JACOBIAN_BRANCH_IDENTITY=PASS")
    print("GC_LOW01A_SOURCE_GATE=PASS")


if __name__ == "__main__":
    main()
