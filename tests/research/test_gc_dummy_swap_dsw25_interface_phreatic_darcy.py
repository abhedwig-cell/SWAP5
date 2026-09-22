from __future__ import annotations

import math


AREA_M2 = 1.0
Z_BOTTOM_M = 0.0
H_PHREATIC_M = 8.0
L_M = H_PHREATIC_M - Z_BOTTOM_M
K_M_PER_DAY = 1.0
TOL = 1.0e-14


def require(value: bool, message: str) -> None:
    if not value:
        raise AssertionError(message)


def interface_head(q_bot_m_per_day: float, k_m_per_day: float) -> float:
    return H_PHREATIC_M + q_bot_m_per_day * L_M / k_m_per_day


def darcy_flux(h_interface_m: float, k_m_per_day: float) -> float:
    return k_m_per_day * (h_interface_m - H_PHREATIC_M) / L_M


def main() -> None:
    require(L_M > 0.0, "invalid saturated path length")
    conductance = K_M_PER_DAY * AREA_M2 / L_M
    require(
        math.isclose(conductance, 0.125, rel_tol=0.0, abs_tol=TOL),
        "conductance oracle",
    )
    print(f"GC_DSW25_CONDUCTANCE_M2_PER_DAY={conductance:.17g}")

    cases = (
        ("HYDROSTATIC", 0.0, 8.0, 0.0),
        ("UPWARD", 0.01, 8.08, 0.08),
        ("DOWNWARD", -0.01, 7.92, -0.08),
    )
    for name, q_bot, expected_head, expected_gap in cases:
        h_interface = interface_head(q_bot, K_M_PER_DAY)
        gap = h_interface - H_PHREATIC_M
        reconstructed_q = darcy_flux(h_interface, K_M_PER_DAY)

        print(f"GC_DSW25_{name}_QBOT_M_PER_DAY={q_bot:.17g}")
        print(f"GC_DSW25_{name}_H_INTERFACE_M={h_interface:.17g}")
        print(f"GC_DSW25_{name}_H_PHREATIC_M={H_PHREATIC_M:.17g}")
        print(f"GC_DSW25_{name}_HEAD_DIFFERENCE_M={gap:.17g}")
        print(f"GC_DSW25_{name}_RECONSTRUCTED_QBOT_M_PER_DAY={reconstructed_q:.17g}")

        require(
            math.isclose(h_interface, expected_head, rel_tol=0.0, abs_tol=TOL),
            f"{name} interface-head oracle",
        )
        require(
            math.isclose(gap, expected_gap, rel_tol=0.0, abs_tol=TOL),
            f"{name} head-gap oracle",
        )
        require(
            math.isclose(reconstructed_q, q_bot, rel_tol=0.0, abs_tol=TOL),
            f"{name} Darcy reconstruction",
        )

    require(
        interface_head(0.0, K_M_PER_DAY) == H_PHREATIC_M,
        "hydrostatic identity",
    )

    conductivities = (1.0, 10.0, 100.0, 1.0e6)
    gaps = [
        abs(interface_head(0.01, conductivity) - H_PHREATIC_M)
        for conductivity in conductivities
    ]
    for conductivity, gap in zip(conductivities, gaps, strict=True):
        print(
            f"GC_DSW25_K_{conductivity:g}_HEAD_GAP_M={gap:.17g}"
        )

    require(
        all(
            current < previous
            for previous, current in zip(gaps[:-1], gaps[1:], strict=True)
        ),
        f"head gap not monotone with K: {gaps}",
    )
    require(gaps[-1] < 1.0e-6, "high-K limit did not collapse heads")

    print("GC_DSW25_DARCY_IDENTITY=PASS")
    print("GC_DSW25_HYDROSTATIC_HEAD_EQUALITY=PASS")
    print("GC_DSW25_VERTICAL_FLOW_HEAD_SEPARATION=PASS")
    print("GC_DSW25_ZERO_RESISTANCE_LIMIT=PASS")
    print("GC_DSW25_ANALYTIC_GATE=PASS")


if __name__ == "__main__":
    main()
