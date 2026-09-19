#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import math
import pathlib

import numpy as np

H0 = 40.0
H_ROOT = 10.0
RATE = 0.03
DURATION_DAY = 100.0
DT_DAY = 0.001
IDENTITY_GATE = 1.0e-10

MATERIALS = {
    "SANDY_LOAM": dict(alpha=0.075, n=1.89, theta_r=0.065, theta_s=0.41, Ks=106.1, lam=0.5),
    "LOAM": dict(alpha=0.036, n=1.56, theta_r=0.078, theta_s=0.43, Ks=24.96, lam=0.5),
    "CLAY_LOAM": dict(alpha=0.019, n=1.31, theta_r=0.095, theta_s=0.41, Ks=6.24, lam=0.5),
}


def water_table(t: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    exp = np.exp(-RATE * t)
    return H0 * (1.0 - exp), RATE * H0 * exp


def theta_from_psi(psi: np.ndarray, p: dict[str, float]) -> np.ndarray:
    m = 1.0 - 1.0 / p["n"]
    se = np.power(1.0 + np.power(p["alpha"] * np.maximum(psi, 0.0), p["n"]), -m)
    return p["theta_r"] + (p["theta_s"] - p["theta_r"]) * se


def layer_average_hydrostatic(length: np.ndarray, p: dict[str, float], order: int = 32) -> np.ndarray:
    # Average theta over a moving unsaturated interval whose water-table end has
    # psi=0 and whose fixed-end suction is psi=length.  Gauss-Legendre is
    # deterministic and vectorized in chunks to keep memory bounded.
    nodes, weights = np.polynomial.legendre.leggauss(order)
    out = np.empty_like(length)
    chunk = 8192
    for start in range(0, len(length), chunk):
        L = length[start:start + chunk]
        x = 0.5 * L[:, None] * (nodes[None, :] + 1.0)
        vals = theta_from_psi(x, p)
        integral = 0.5 * L * (vals @ weights)
        out[start:start + chunk] = integral / L
    return out


def regime_metrics(t: np.ndarray, H: np.ndarray, Hdot: np.ndarray, p: dict[str, float], regime: str) -> dict[str, float | int]:
    if regime == "ONE_LAYER_MOVING":
        mask = H <= H_ROOT
        L = H[mask]
    elif regime == "LOWER_LAYER_MOVING":
        mask = H > H_ROOT
        L = H[mask] - H_ROOT
    else:
        raise ValueError(regime)

    tt = t[mask]
    HHdot = Hdot[mask]
    if len(L) == 0 or np.any(L <= 0.0):
        raise RuntimeError(f"nonpositive active thickness in {regime}")

    theta_bar = layer_average_hydrostatic(L, p)
    theta_fixed_edge = theta_from_psi(L, p)

    # For U(L)=integral_0^L theta(psi)dpsi, dU/dt = theta(L)*dH/dt.
    dUdt = theta_fixed_edge * HHdot
    qnet = dUdt - p["theta_s"] * HHdot

    # d(theta_bar)/dt follows exactly from U=L*theta_bar.
    dtheta_dt = HHdot * (theta_fixed_edge - theta_bar) / L

    r_product = dUdt - p["theta_s"] * HHdot - qnet
    r_product_expanded = (
        L * dtheta_dt
        + (theta_bar - p["theta_s"]) * HHdot
        - qnet
    )
    r_literal = L * dtheta_dt - p["theta_s"] * HHdot - qnet
    expected_literal = -theta_bar * HHdot

    relation_error = r_literal - expected_literal
    abs_integral = float(np.trapezoid(np.abs(r_literal), tt)) if len(tt) > 1 else 0.0
    signed_integral = float(np.trapezoid(r_literal, tt)) if len(tt) > 1 else 0.0

    return {
        "sample_count": int(len(L)),
        "time_start_day": float(tt[0]),
        "time_end_day": float(tt[-1]),
        "thickness_min_cm": float(np.min(L)),
        "thickness_max_cm": float(np.max(L)),
        "theta_bar_min": float(np.min(theta_bar)),
        "theta_bar_max": float(np.max(theta_bar)),
        "max_abs_product_storage_residual_cm_per_day": float(np.max(np.abs(r_product))),
        "max_abs_product_expanded_residual_cm_per_day": float(np.max(np.abs(r_product_expanded))),
        "max_abs_printed_literal_residual_cm_per_day": float(np.max(np.abs(r_literal))),
        "max_abs_literal_identity_relation_error_cm_per_day": float(np.max(np.abs(relation_error))),
        "time_integrated_abs_literal_residual_cm": abs_integral,
        "time_integrated_signed_literal_residual_cm": signed_integral,
        "max_abs_dHdt_cm_per_day": float(np.max(np.abs(HHdot))),
    }


def transition_continuity(p: dict[str, float]) -> dict[str, float]:
    # At H=h, one moving unsaturated layer has storage integral_0^h theta(psi)dpsi.
    # Immediately after the switch that exact storage becomes the fixed first layer,
    # while the new lower moving layer has zero thickness/storage.
    L = np.asarray([H_ROOT], dtype=float)
    theta_bar = layer_average_hydrostatic(L, p)[0]
    one_layer_storage = H_ROOT * theta_bar

    nodes, weights = np.polynomial.legendre.leggauss(64)
    x = 0.5 * H_ROOT * (nodes + 1.0)
    fixed_first_storage = 0.5 * H_ROOT * float(theta_from_psi(x, p) @ weights)
    lower_storage = 0.0

    return {
        "one_layer_storage_at_switch_cm": float(one_layer_storage),
        "fixed_first_layer_storage_at_switch_cm": float(fixed_first_storage),
        "new_lower_layer_storage_at_switch_cm": lower_storage,
        "storage_jump_cm": float(fixed_first_storage + lower_storage - one_layer_storage),
        "theta_bar_limit_lower_layer": float(p["theta_s"]),
    }


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--prereg", required=True, type=pathlib.Path)
    ap.add_argument("--output", required=True, type=pathlib.Path)
    args = ap.parse_args()

    pre = json.loads(args.prereg.read_text())
    assert pre["phase"] == "PREREGISTERED_BEFORE_MOVING_CONTROL_VOLUME_AUDIT"
    assert pre["pre_execution_residual_sign_clarification"]["before_first_BC2_A0_execution"] is True

    t_transition = -math.log(1.0 - H_ROOT / H0) / RATE
    transition_residual = H0 * (1.0 - math.exp(-RATE * t_transition)) - H_ROOT

    # Do not evaluate a moving average at t=0 because the unsaturated thickness is zero.
    t = np.arange(DT_DAY, DURATION_DAY + 0.5 * DT_DAY, DT_DAY, dtype=float)
    H, Hdot = water_table(t)

    material_rows = {}
    max_product = 0.0
    max_literal = 0.0
    max_relation = 0.0
    max_switch_jump = 0.0

    for name, p in MATERIALS.items():
        one = regime_metrics(t, H, Hdot, p, "ONE_LAYER_MOVING")
        lower = regime_metrics(t, H, Hdot, p, "LOWER_LAYER_MOVING")
        switch = transition_continuity(p)
        material_rows[name] = {
            "one_layer_moving_regime": one,
            "lower_layer_moving_regime": lower,
            "switch_H_equals_h": switch,
        }
        for row in (one, lower):
            max_product = max(
                max_product,
                row["max_abs_product_storage_residual_cm_per_day"],
                row["max_abs_product_expanded_residual_cm_per_day"],
            )
            max_literal = max(max_literal, row["max_abs_printed_literal_residual_cm_per_day"])
            max_relation = max(max_relation, row["max_abs_literal_identity_relation_error_cm_per_day"])
        max_switch_jump = max(max_switch_jump, abs(switch["storage_jump_cm"]))

    if abs(transition_residual) > pre["adjudication"]["transition_time_gate_day"]:
        decision = "BC2_A0_NUMERICALLY_BLOCKED"
    elif max_product <= IDENTITY_GATE and max_literal > IDENTITY_GATE and max_relation <= IDENTITY_GATE:
        decision = "PRINTED_AVERAGE_LITERAL_NOT_CONTROL_VOLUME_EQUIVALENT"
    elif max_product <= IDENTITY_GATE and max_literal <= IDENTITY_GATE:
        decision = "PRODUCT_AND_PRINTED_FORMS_CONTROL_VOLUME_EQUIVALENT"
    else:
        decision = "SOURCE_EQUATION_SEMANTICS_UNRESOLVED"

    result = {
        "schema": "swap5.lare.bc2.a0.result.v1",
        "workstream": "F-ROM-LARE",
        "work_unit": "LARE-BC2-A0",
        "decision": decision,
        "published_scenario": {
            "H0_cm": H0,
            "h_cm": H_ROOT,
            "rate_per_day": RATE,
            "duration_day": DURATION_DAY,
            "dt_day": DT_DAY,
            "transition_time_day": t_transition,
            "transition_H_minus_h_cm": transition_residual,
            "first_positive_thickness_H_cm": float(H[0]),
            "H_at_100d_cm": float(H[-1]),
        },
        "audit": {
            "max_abs_product_form_residual_cm_per_day": max_product,
            "max_abs_printed_literal_residual_cm_per_day": max_literal,
            "max_abs_literal_identity_relation_error_cm_per_day": max_relation,
            "max_abs_switch_storage_jump_cm": max_switch_jump,
            "numerical_identity_gate_cm_per_day": IDENTITY_GATE,
        },
        "materials": material_rows,
        "interpretation": [
            "The product-storage form is tested as a moving-control-volume identity, not as a fitted model.",
            "The printed-average literal form is evaluated on exactly the same physically admissible hydrostatic state path.",
            "A nonzero literal residual establishes algebraic non-equivalence to the control-volume identity; it does not establish which equation the authors' implementation actually executed.",
            "The next source-reproduction gate must use author output/code if available or an independently frozen response benchmark before selecting BC2 dynamics."
        ],
        "author_dataset_used": False,
        "swap_reference_used": False,
        "moving_water_table_dynamics_authorized": False,
        "application_acceptance_adjudicated": False,
        "production_rom_authorized": False,
    }
    args.output.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
    print(json.dumps({
        "decision": decision,
        "transition_time_day": t_transition,
        "audit": result["audit"],
        "integrated_literal_defect_cm": {
            material: {
                "one_layer": row["one_layer_moving_regime"]["time_integrated_abs_literal_residual_cm"],
                "lower_layer": row["lower_layer_moving_regime"]["time_integrated_abs_literal_residual_cm"],
            }
            for material, row in material_rows.items()
        },
    }, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())