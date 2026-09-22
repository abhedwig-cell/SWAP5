from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
LEGACY = ROOT / "src" / "legacy" / "b1_10_port" / "headcalc.f90"

Z_CM = (-25.0, -75.0, -150.0, -250.0)
DZ_CM = (50.0, 50.0, 100.0, 100.0)
TOP_TOL_CM = 1.0e-4
NIHIL_CM = 1.0e-12


@dataclass(frozen=True)
class Low01State:
    branch: str
    requested_gwl_cm: float
    effective_gwl_cm: float
    active_nodes: int
    fllowgwl: bool
    hbot_cm: float | None
    lower_distance_cm: float | None


def require(value: bool, message: str) -> None:
    if not value:
        raise AssertionError(message)


def classify(requested_gwl_cm: float) -> Low01State:
    gwl = float(requested_gwl_cm)

    if gwl >= Z_CM[0] - TOP_TOL_CM:
        return Low01State(
            "ABOVE_OR_AT_TOP",
            requested_gwl_cm,
            gwl,
            0,
            False,
            None,
            None,
        )

    nn = 0
    while nn < len(Z_CM) and Z_CM[nn] > gwl:
        nn += 1

    if nn >= len(Z_CM):
        hbot = gwl - Z_CM[-1] + 0.5 * DZ_CM[-1]
        return Low01State(
            "BELOW_BOTTOM_NODE",
            requested_gwl_cm,
            gwl,
            len(Z_CM),
            True,
            hbot,
            None,
        )

    # Source inside-profile branch. nn is the count of hydraulic nodes above
    # the prescribed groundwater level.
    effective = gwl
    active_nodes = nn
    if active_nodes > 0 and (Z_CM[active_nodes - 1] - effective) < TOP_TOL_CM:
        effective = Z_CM[active_nodes - 1]
        active_nodes -= 1

    require(active_nodes > 0, "inside-profile branch lost all active nodes")
    lower_distance = Z_CM[active_nodes - 1] - effective
    require(lower_distance > 0.0, "nonpositive inside-profile lower distance")

    return Low01State(
        "INSIDE_PROFILE",
        requested_gwl_cm,
        effective,
        active_nodes,
        False,
        None,
        lower_distance,
    )


def source_gate() -> None:
    source = LEGACY.read_text(encoding="utf-8")
    required = (
        "if (state%gwlinp >= grid_z(1)-1.0d-4) then",
        "do while (grid_z(NN+1) > state%gwlinp .AND. NN < numnod)",
        "if ((grid_z(NN)-state%gwlinp) < 1.0d-4 .AND. (NN > 0)) then",
        "state%gwlinp = grid_z(NN)",
        "NN     = NN-1",
        "state%fllowgwl = .TRUE.",
        "state%hbot     = state%gwlinp - grid_z(numnod) + 0.5d0*grid_dz(numnod)",
        "fsi_ws%head_gradient(NN+1) = state%h(NN)/(grid_z(nn)-state%gwlinp) + 1.0d0",
    )
    for marker in required:
        require(marker in source, f"legacy state-machine authority drift: {marker}")


def main() -> None:
    source_gate()
    print("GC_LOW01_STATE01_SOURCE_AUTHORITY=PASS")

    cases = (
        ("ABOVE_TOP", -10.0, "ABOVE_OR_AT_TOP", 0, None, None),
        ("TOP_TOLERANCE", -25.00005, "ABOVE_OR_AT_TOP", 0, None, None),
        ("INSIDE_UPPER", -100.0, "INSIDE_PROFILE", 2, None, 25.0),
        ("INSIDE_LOWER", -200.0, "INSIDE_PROFILE", 3, None, 50.0),
        ("NODE_SNAP_BELOW_Z3", -150.00005, "INSIDE_PROFILE", 2, None, 75.0),
        ("NODE_NO_SNAP_ABOVE_Z3", -149.99995, "INSIDE_PROFILE", 2, None, 74.99995),
        ("BELOW_BOTTOM_NODE_INSIDE_HALF_CELL", -275.0, "BELOW_BOTTOM_NODE", 4, 25.0, None),
        ("BELOW_PROFILE_FACE", -350.0, "BELOW_BOTTOM_NODE", 4, -50.0, None),
    )

    forward: dict[str, Low01State] = {}
    for name, gwl, branch, active_nodes, hbot, distance in cases:
        state = classify(gwl)
        forward[name] = state
        print(
            f"GC_LOW01_STATE01_{name}="
            f"branch:{state.branch},requested:{state.requested_gwl_cm:.17g},"
            f"effective:{state.effective_gwl_cm:.17g},active:{state.active_nodes},"
            f"fllow:{1 if state.fllowgwl else 0},"
            f"hbot:{'NA' if state.hbot_cm is None else format(state.hbot_cm,'.17g')},"
            f"distance:{'NA' if state.lower_distance_cm is None else format(state.lower_distance_cm,'.17g')}"
        )
        require(state.branch == branch, f"{name} branch")
        require(state.active_nodes == active_nodes, f"{name} active nodes")
        if hbot is not None:
            require(state.hbot_cm is not None and abs(state.hbot_cm - hbot) <= 1.0e-12, f"{name} hbot")
        if distance is not None:
            require(
                state.lower_distance_cm is not None
                and abs(state.lower_distance_cm - distance) <= 1.0e-10,
                f"{name} lower distance",
            )

    snapped = forward["NODE_SNAP_BELOW_Z3"]
    require(abs(snapped.effective_gwl_cm + 150.0) <= 1.0e-14, "node snap effective GWL")

    for name, gwl, *_ in reversed(cases):
        require(classify(gwl) == forward[name], f"{name} replay changed state")

    print("GC_LOW01_STATE01_BRANCHES=PASS")
    print("GC_LOW01_STATE01_ACTIVE_DOMAIN=PASS")
    print("GC_LOW01_STATE01_NODE_SNAP=PASS")
    print("GC_LOW01_STATE01_BELOW_NODE_HBOT=PASS")
    print("GC_LOW01_STATE01_REPLAY_DETERMINISM=PASS")
    print("GC_LOW01_STATE01_GATE=PASS")


if __name__ == "__main__":
    main()
