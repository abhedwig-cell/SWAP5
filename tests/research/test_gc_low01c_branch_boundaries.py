from __future__ import annotations

import math
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tests" / "research"))

from test_gc_low01_state_machine import classify, source_gate


CASES = (
    ("Z2_ABOVE_EPS", -74.99989, "INSIDE_PROFILE", 1, -74.99989, None, None),
    ("Z2_ABOVE_WITHIN_SNAP", -74.99995, "INSIDE_PROFILE", 1, -74.99995, None, None),
    ("Z2_BELOW_WITHIN_SNAP", -75.00005, "INSIDE_PROFILE", 1, -75.0, None, 50.0),
    ("Z2_BELOW_EPS", -75.00011, "INSIDE_PROFILE", 2, -75.00011, None, 0.00011),
    ("Z4_ABOVE_EPS", -249.99989, "INSIDE_PROFILE", 3, -249.99989, None, 99.99989),
    ("Z4_BELOW_WITHIN_SNAP", -250.00005, "BELOW_BOTTOM_NODE", 4, -250.00005, 49.99995, None),
    ("Z4_BELOW_EPS", -250.00011, "BELOW_BOTTOM_NODE", 4, -250.00011, 49.99989, None),
    ("BOTTOM_FACE_ABOVE", -299.9999, "BELOW_BOTTOM_NODE", 4, -299.9999, 0.0001, None),
    ("BOTTOM_FACE_EXACT", -300.0, "BELOW_BOTTOM_NODE", 4, -300.0, 0.0, None),
    ("BOTTOM_FACE_BELOW", -300.0001, "BELOW_BOTTOM_NODE", 4, -300.0001, -0.0001, None),
)


def require(value: bool, message: str) -> None:
    if not value:
        raise AssertionError(message)


def close(actual: float | None, expected: float | None, tol: float, message: str) -> None:
    if expected is None:
        require(actual is None, message)
        return
    require(actual is not None and math.isclose(actual, expected, rel_tol=0.0, abs_tol=tol), message)


def main() -> None:
    source_gate()
    print("GC_LOW01C_SOURCE_AUTHORITY=PASS")

    forward = {}
    for name, gwl, branch, active, effective, hbot, distance in CASES:
        state = classify(gwl)
        forward[name] = state
        print(
            f"GC_LOW01C_{name}=branch:{state.branch},requested:{state.requested_gwl_cm:.17g},"
            f"effective:{state.effective_gwl_cm:.17g},active:{state.active_nodes},"
            f"fllow:{1 if state.fllowgwl else 0},"
            f"hbot:{'NA' if state.hbot_cm is None else format(state.hbot_cm,'.17g')},"
            f"distance:{'NA' if state.lower_distance_cm is None else format(state.lower_distance_cm,'.17g')}"
        )
        require(state.branch == branch, f"{name} branch")
        require(state.active_nodes == active, f"{name} active nodes")
        close(state.effective_gwl_cm, effective, 1.0e-12, f"{name} effective GWL")
        close(state.hbot_cm, hbot, 1.0e-10, f"{name} hbot")
        close(state.lower_distance_cm, distance, 1.0e-8, f"{name} lower distance")

    for name, gwl, *_ in reversed(CASES):
        require(classify(gwl) == forward[name], f"{name} reverse replay")

    # Explicitly record the two non-obvious source semantics.
    require(
        forward["Z2_ABOVE_WITHIN_SNAP"].effective_gwl_cm != -75.0,
        "snap must not be made symmetric above the node",
    )
    require(
        forward["Z2_BELOW_WITHIN_SNAP"].effective_gwl_cm == -75.0,
        "below-node source snap missing",
    )
    require(
        forward["Z4_BELOW_WITHIN_SNAP"].branch == "BELOW_BOTTOM_NODE",
        "bottom-node branch switch missing",
    )
    require(
        forward["BOTTOM_FACE_ABOVE"].branch == "BELOW_BOTTOM_NODE"
        and forward["BOTTOM_FACE_BELOW"].branch == "BELOW_BOTTOM_NODE",
        "physical bottom face must not be invented as legacy branch switch",
    )

    print("GC_LOW01C_NODE_SNAP_ASYMMETRY=PASS")
    print("GC_LOW01C_BOTTOM_NODE_SWITCH=PASS")
    print("GC_LOW01C_PHYSICAL_BOTTOM_FACE_DISTINCTION=PASS")
    print("GC_LOW01C_REVERSE_REPLAY=PASS")
    print("GC_LOW01C_CLASSIFIER_GATE=PASS")


if __name__ == "__main__":
    main()
