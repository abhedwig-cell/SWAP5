#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import math
import pathlib


def general_case(t: float) -> dict[str, float]:
    a = 20.0
    h0 = 90.0
    v = 7.5
    H = h0 + v * t
    Hdot = v
    c0, c1, c2, c3, c4 = 0.19, 6.0e-4, 0.012, -2.0e-5, 1.5e-6

    # theta(z,t)=c0+c1*z+c2*t+c3*z*t+c4*z^2
    def F(z: float) -> float:
        return (
            c0 * z
            + 0.5 * c1 * z * z
            + c2 * t * z
            + 0.5 * c3 * t * z * z
            + (c4 / 3.0) * z**3
        )

    def Ft(z: float) -> float:
        return c2 * z + 0.5 * c3 * z * z

    theta_H = c0 + c1 * H + c2 * t + c3 * H * t + c4 * H * H
    W = F(H) - F(a)
    int_theta_t = Ft(H) - Ft(a)
    dWdt = int_theta_t + theta_H * Hdot
    L = H - a
    theta_bar = W / L

    # From d(W=L*theta_bar)/dt.
    dtheta_bar_dt = (dWdt - theta_bar * Hdot) / L
    conservative_expanded = L * dtheta_bar_dt + (theta_bar - theta_H) * Hdot
    published_style = L * dtheta_bar_dt - theta_H * Hdot

    return {
        "H": H,
        "Hdot": Hdot,
        "W": W,
        "theta_bar": theta_bar,
        "theta_H": theta_H,
        "qdiff_equivalent": int_theta_t,
        "conservative_product_residual": dWdt - theta_H * Hdot - int_theta_t,
        "conservative_expanded_residual": conservative_expanded - int_theta_t,
        "published_style_residual": published_style - int_theta_t,
        "published_expected_residual": -theta_bar * Hdot,
    }


def water_table_case(t: float) -> dict[str, float]:
    # theta(H(t),t)=theta_s by construction.
    a = 30.0
    H0 = 120.0
    v = -8.0
    H = H0 + v * t
    Hdot = v
    theta_s = 0.43
    alpha = 1.0e-3
    beta = 3.0e-6
    L = H - a

    # theta = theta_s - alpha*(H-z) - beta*(H-z)^2
    W = theta_s * L - 0.5 * alpha * L**2 - (beta / 3.0) * L**3
    theta_bar = W / L

    # At fixed z: theta_t = -alpha*Hdot - 2*beta*(H-z)*Hdot.
    int_theta_t = -alpha * Hdot * L - beta * Hdot * L**2
    dWdt = (
        theta_s * Hdot
        - alpha * L * Hdot
        - beta * L**2 * Hdot
    )
    dtheta_bar_dt = (dWdt - theta_bar * Hdot) / L

    conservative_expanded = L * dtheta_bar_dt + (theta_bar - theta_s) * Hdot
    published = L * dtheta_bar_dt - theta_s * Hdot

    return {
        "H": H,
        "Hdot": Hdot,
        "theta_s": theta_s,
        "W": W,
        "theta_bar": theta_bar,
        "qdiff_equivalent": int_theta_t,
        "conservative_product_residual": dWdt - theta_s * Hdot - int_theta_t,
        "conservative_expanded_residual": conservative_expanded - int_theta_t,
        "published_style_residual": published - int_theta_t,
        "published_expected_residual": -theta_bar * Hdot,
    }


def saturated_case(t: float) -> dict[str, float]:
    a = 10.0
    H0 = 80.0
    v = 5.0
    H = H0 + v * t
    Hdot = v
    theta_s = 0.41
    L = H - a
    W = theta_s * L
    theta_bar = theta_s
    dWdt = theta_s * Hdot
    int_theta_t = 0.0
    dtheta_bar_dt = 0.0
    return {
        "H": H,
        "Hdot": Hdot,
        "W": W,
        "theta_bar": theta_bar,
        "conservative_product_residual": dWdt - theta_s * Hdot - int_theta_t,
        "conservative_expanded_residual": (
            L * dtheta_bar_dt + (theta_bar - theta_s) * Hdot - int_theta_t
        ),
        "published_style_residual": (
            L * dtheta_bar_dt - theta_s * Hdot - int_theta_t
        ),
        "published_expected_residual": -theta_bar * Hdot,
    }


def stationary_case(t: float) -> dict[str, float]:
    # Any moving-boundary discrepancy must vanish in dH/dt=0 limit.
    a = 15.0
    H = 105.0
    Hdot = 0.0
    theta_s = 0.42
    alpha = 8.0e-4
    L = H - a
    theta_bar = theta_s - 0.5 * alpha * L
    dtheta_bar_dt = 0.003
    qdiff = L * dtheta_bar_dt
    return {
        "H": H,
        "Hdot": Hdot,
        "theta_bar": theta_bar,
        "conservative_expanded_residual": (
            L * dtheta_bar_dt + (theta_bar - theta_s) * Hdot - qdiff
        ),
        "published_style_residual": (
            L * dtheta_bar_dt - theta_s * Hdot - qdiff
        ),
    }


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--prereg", required=True, type=pathlib.Path)
    ap.add_argument("--output", required=True, type=pathlib.Path)
    args = ap.parse_args()

    prereg = json.loads(args.prereg.read_text())
    assert prereg["phase"] == "PREREGISTERED_BEFORE_MOVING_WATER_TABLE_REFERENCE_GEOMETRY_EXECUTION"
    assert prereg["source_algebra"]["discrepancy_class"] == (
        "SOURCE_ALGEBRA_DISCREPANCY_MOVING_AVERAGE_VS_CONSERVATIVE_STORAGE"
    )

    cases = {
        "GENERAL_POLYNOMIAL": general_case(0.37),
        "WATER_TABLE_THETA_S": water_table_case(0.41),
        "CONSTANT_SATURATED": saturated_case(0.23),
        "STATIONARY_GEOMETRY": stationary_case(0.61),
    }

    tol = 5.0e-14
    for name in ("GENERAL_POLYNOMIAL", "WATER_TABLE_THETA_S", "CONSTANT_SATURATED"):
        row = cases[name]
        if abs(row["conservative_product_residual"]) > tol:
            raise SystemExit(f"{name}: conservative product identity failed")
        if abs(row["conservative_expanded_residual"]) > tol:
            raise SystemExit(f"{name}: conservative expanded identity failed")
        if not math.isclose(
            row["published_style_residual"],
            row["published_expected_residual"],
            rel_tol=1.0e-13,
            abs_tol=tol,
        ):
            raise SystemExit(f"{name}: published-form discrepancy identity drift")

    stationary = cases["STATIONARY_GEOMETRY"]
    if abs(stationary["conservative_expanded_residual"]) > tol:
        raise SystemExit("stationary conservative limit failed")
    if abs(stationary["published_style_residual"]) > tol:
        raise SystemExit("stationary published limit failed")

    if abs(cases["WATER_TABLE_THETA_S"]["published_style_residual"]) <= 1.0e-6:
        raise SystemExit("water-table diagnostic did not expose published-form discrepancy")
    if abs(cases["CONSTANT_SATURATED"]["published_style_residual"]) <= 1.0e-6:
        raise SystemExit("constant-saturated diagnostic did not expose published-form discrepancy")

    result = {
        "schema": "swap5.lare.bc2.a1.algebra-result.v1",
        "workstream": "F-ROM-LARE",
        "work_unit": "LARE-BC2-A1",
        "decision": "BC2_SOURCE_ALGEBRA_DISCREPANCY_CONFIRMED",
        "floating_point_tolerance": tol,
        "cases": cases,
        "interpretation": [
            "The conservative moving-volume form and its correctly expanded average-state form are algebraically identical to floating-point tolerance.",
            "The displayed published average-state form differs from the conservative product-rule balance by -theta_bar*dH/dt whenever geometry moves.",
            "Both forms coincide in the stationary-geometry limit dH/dt=0.",
            "This result is a calculus/source-authority diagnostic only and contains no SWAP response fitting."
        ],
        "author_intent_inferred": False,
        "bc2_reduced_dynamics_authorized": False,
        "production_rom_authorized": False,
    }
    args.output.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
    print(json.dumps({
        "decision": result["decision"],
        "water_table_published_residual": cases["WATER_TABLE_THETA_S"]["published_style_residual"],
        "constant_saturated_published_residual": cases["CONSTANT_SATURATED"]["published_style_residual"],
    }, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
