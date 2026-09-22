from __future__ import annotations

from dataclasses import dataclass


BOTTOM_NODE_CM = -250.0
BOTTOM_FACE_CM = -300.0


@dataclass(frozen=True)
class Low01C2Policy:
    requested_h_phreatic_cm: float
    policy: str
    hbot_cm: float | None


def classify_policy(h_phreatic_cm: float) -> Low01C2Policy:
    h = float(h_phreatic_cm)
    if h >= BOTTOM_NODE_CM:
        return Low01C2Policy(h, "INSIDE_PROFILE_ADMITTED", None)
    if h <= BOTTOM_FACE_CM:
        return Low01C2Policy(h, "BELOW_PROFILE_ADMITTED", h - BOTTOM_FACE_CM)
    return Low01C2Policy(h, "UNADMITTED_GEOMETRY_GAP", None)


CASES = (
    ("ABOVE_LAST_NODE", -249.99995, "INSIDE_PROFILE_ADMITTED", None),
    ("LAST_NODE_EXACT", -250.0, "INSIDE_PROFILE_ADMITTED", None),
    ("JUST_BELOW_LAST_NODE", -250.00005, "UNADMITTED_GEOMETRY_GAP", None),
    ("MID_LOWER_HALF_CELL", -275.0, "UNADMITTED_GEOMETRY_GAP", None),
    ("JUST_ABOVE_BOTTOM_FACE", -299.9999, "UNADMITTED_GEOMETRY_GAP", None),
    ("BOTTOM_FACE_EXACT", -300.0, "BELOW_PROFILE_ADMITTED", 0.0),
    ("BELOW_BOTTOM_FACE", -300.0001, "BELOW_PROFILE_ADMITTED", -0.0001),
)


def require(value: bool, message: str) -> None:
    if not value:
        raise AssertionError(message)


def main() -> None:
    forward: dict[str, Low01C2Policy] = {}

    for label, h, expected_policy, expected_hbot in CASES:
        state = classify_policy(h)
        forward[label] = state

        print(
            f"GC_LOW01C2_{label}=H:{state.requested_h_phreatic_cm:.17g},"
            f"POLICY:{state.policy},"
            f"HBOT:{'NA' if state.hbot_cm is None else format(state.hbot_cm,'.17g')}"
        )

        require(state.policy == expected_policy, f"{label} policy")
        if expected_hbot is None:
            require(state.hbot_cm is None, f"{label} must not materialize hbot")
        else:
            require(
                state.hbot_cm is not None
                and abs(state.hbot_cm - expected_hbot) <= 1.0e-12,
                f"{label} hbot",
            )

    for label, h, *_ in reversed(CASES):
        require(classify_policy(h) == forward[label], f"{label} reverse replay")

    gap_labels = (
        "JUST_BELOW_LAST_NODE",
        "MID_LOWER_HALF_CELL",
        "JUST_ABOVE_BOTTOM_FACE",
    )
    for label in gap_labels:
        state = forward[label]
        require(
            state.policy == "UNADMITTED_GEOMETRY_GAP",
            f"{label} gap exclusion",
        )
        require(state.hbot_cm is None, f"{label} gap must not expose hbot")

    require(
        forward["LAST_NODE_EXACT"].policy == "INSIDE_PROFILE_ADMITTED",
        "last node belongs to bounded inside-profile research envelope",
    )
    require(
        forward["BOTTOM_FACE_EXACT"].policy == "BELOW_PROFILE_ADMITTED",
        "bottom face belongs to bounded below-profile research envelope",
    )
    require(
        abs(float(forward["BOTTOM_FACE_EXACT"].hbot_cm)) <= 1.0e-15,
        "bottom-face hbot datum",
    )

    print("GC_LOW01C2_POLICY_CASES=PASS")
    print("GC_LOW01C2_GAP_EXCLUSION=PASS")
    print("GC_LOW01C2_BOTTOM_FACE_HBOT=PASS")
    print("GC_LOW01C2_REVERSE_REPLAY=PASS")
    print("GC_LOW01C2_GATE=PASS")


if __name__ == "__main__":
    main()
