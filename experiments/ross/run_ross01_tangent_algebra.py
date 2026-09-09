from __future__ import annotations

import json
import math
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import run_ross01_continuity_algebra as base

MASS_TOL = 1.0e-12
LINEAR_TOL = 1.0e-12
TANGENT_TOL = 1.0e-8
TANGENT_SCALE_FLOOR = 1.0e-8
CELL_COUNTS = (1, 2, 3, 8, 32, 128)
SIGMAS = (0.0, 0.5, 1.0)
BOUNDARY_STATES = (0.10, 0.18, 0.26)
BOTTOM_FACE_COEFFICIENTS = (0.03, 0.11, 0.27)
FD_STEPS = (1.0e-7, 1.0e-6)
Q_TOP = 0.031
BOTTOM_GRAVITY = -0.004


def factor_tridiagonal(lower, diag, upper):
    """One Thomas LU factorization reusable for multiple right-hand sides."""
    n = len(diag)
    if not (len(lower) == max(0, n - 1) == len(upper)):
        raise ValueError("invalid tridiagonal dimensions")
    if n == 0:
        return (), (), ()
    d = list(diag)
    u = list(upper)
    multipliers = [0.0] * max(0, n - 1)
    for i in range(1, n):
        if d[i - 1] == 0.0:
            raise ZeroDivisionError(("zero_pivot", i - 1))
        w = lower[i - 1] / d[i - 1]
        multipliers[i - 1] = w
        d[i] -= w * u[i - 1]
    if d[-1] == 0.0:
        raise ZeroDivisionError(("zero_pivot", n - 1))
    return tuple(multipliers), tuple(d), tuple(u)


def solve_factored(factorization, rhs):
    multipliers, diag_u, upper = factorization
    n = len(diag_u)
    if len(rhs) != n:
        raise ValueError("rhs dimension mismatch")
    if n == 0:
        return []
    y = list(rhs)
    for i in range(1, n):
        y[i] -= multipliers[i - 1] * y[i - 1]
    x = [0.0] * n
    x[-1] = y[-1] / diag_u[-1]
    for i in range(n - 2, -1, -1):
        x[i] = (y[i] - upper[i] * x[i + 1]) / diag_u[i]
    return x


def bottom_flux(theta_last, boundary_state, k_bottom):
    return k_bottom * (theta_last - boundary_state) + BOTTOM_GRAVITY


def assemble_with_boundary(theta, dz, k, gravity, source, sink, dt, sigma,
                           boundary_state, k_bottom):
    n = len(theta)
    q0 = [0.0] * (n + 1)
    q0[0] = Q_TOP
    for j in range(1, n):
        q0[j] = base.internal_flux(theta[j - 1], theta[j], k[j - 1], gravity[j - 1])
    q0[-1] = bottom_flux(theta[-1], boundary_state, k_bottom)

    lower = [0.0] * max(0, n - 1)
    diag = [1.0] * n
    upper = [0.0] * max(0, n - 1)
    rhs = [0.0] * n

    for i in range(n):
        fac = dt * sigma / dz[i]
        rhs[i] = dt * (q0[i] - q0[i + 1] + source[i] - sink[i]) / dz[i]
        if i > 0:
            ki = k[i - 1]
            lower[i - 1] -= fac * ki
            diag[i] += fac * ki
        if i < n - 1:
            ko = k[i]
            diag[i] += fac * ko
            upper[i] -= fac * ko
        else:
            # Bottom outgoing face: dq_bottom/dtheta_last = +k_bottom.
            diag[i] += fac * k_bottom
    return lower, diag, upper, rhs, q0


def realized_fluxes(theta, delta, k, gravity, sigma, q0, k_bottom):
    q = list(q0)
    for j in range(1, len(theta)):
        q[j] = q0[j] + sigma * k[j - 1] * (delta[j - 1] - delta[j])
    q[-1] = q0[-1] + sigma * k_bottom * delta[-1]
    return q


def run_analytic_trial(theta, dz, k, gravity, source, sink, dt, sigma,
                       boundary_state, k_bottom):
    snapshot = base.float_bytes(theta)
    lower, diag, upper, rhs, q0 = assemble_with_boundary(
        theta, dz, k, gravity, source, sink, dt, sigma, boundary_state, k_bottom
    )
    factorization = factor_tridiagonal(lower, diag, upper)
    delta = solve_factored(factorization, rhs)
    q = realized_fluxes(theta, delta, k, gravity, sigma, q0, k_bottom)

    # Differentiate the same frozen-regime equations A*delta=b with respect
    # to the external boundary state.  A is unchanged for this linear fixture.
    sensitivity_rhs = [0.0] * len(theta)
    sensitivity_rhs[-1] = dt * k_bottom / dz[-1]
    sensitivity = solve_factored(factorization, sensitivity_rhs)
    tangent = -k_bottom + sigma * k_bottom * sensitivity[-1]

    candidate = tuple(theta[i] + delta[i] for i in range(len(theta)))
    storage_change = math.fsum(delta[i] * dz[i] for i in range(len(theta)))
    external_change = dt * (
        q[0] - q[-1] + math.fsum(source) - math.fsum(sink)
    )
    mass_residual = storage_change - external_change
    normal_linear_residual = base.matrix_residual(lower, diag, upper, delta, rhs)
    sensitivity_linear_residual = base.matrix_residual(
        lower, diag, upper, sensitivity, sensitivity_rhs
    )
    return {
        "candidate": candidate,
        "q_bottom": q[-1],
        "tangent": tangent,
        "mass_residual": mass_residual,
        "normal_linear_residual": normal_linear_residual,
        "sensitivity_linear_residual": sensitivity_linear_residual,
        "base_state_bitwise_unchanged": base.float_bytes(theta) == snapshot,
        "matrix_factorizations": 1,
        "normal_backsolves": 1,
        "additional_tangent_backsolves": 1,
        "global_nonlinear_iterations": 0,
    }


def tangent_metric(analytic, reference):
    return abs(analytic - reference) / max(
        abs(analytic), abs(reference), TANGENT_SCALE_FLOOR
    )


def main():
    if len(sys.argv) != 2:
        raise SystemExit("usage: run_ross01_tangent_algebra.py EVIDENCE_JSON")
    out = Path(sys.argv[1])
    rows = []
    max_mass = 0.0
    max_fd_mass = 0.0
    max_normal_linear = 0.0
    max_sensitivity_linear = 0.0
    max_tangent_metric = 0.0
    unchanged = True
    analytic_trials = 0
    fd_reference_trials = 0

    for n in CELL_COUNTS:
        theta, dz, k, gravity, source, sink = base.build_case(n)
        dt = 0.37 + 0.013 * n
        for sigma in SIGMAS:
            for boundary_state in BOUNDARY_STATES:
                for k_bottom in BOTTOM_FACE_COEFFICIENTS:
                    analytic_trials += 1
                    trial = run_analytic_trial(
                        theta, dz, k, gravity, source, sink, dt, sigma,
                        boundary_state, k_bottom
                    )
                    max_mass = max(max_mass, abs(trial["mass_residual"]))
                    max_normal_linear = max(
                        max_normal_linear, abs(trial["normal_linear_residual"])
                    )
                    max_sensitivity_linear = max(
                        max_sensitivity_linear, abs(trial["sensitivity_linear_residual"])
                    )
                    unchanged = unchanged and trial["base_state_bitwise_unchanged"]

                    for fd_step in FD_STEPS:
                        plus = run_analytic_trial(
                            theta, dz, k, gravity, source, sink, dt, sigma,
                            boundary_state + fd_step, k_bottom
                        )
                        minus = run_analytic_trial(
                            theta, dz, k, gravity, source, sink, dt, sigma,
                            boundary_state - fd_step, k_bottom
                        )
                        fd_reference_trials += 2
                        max_fd_mass = max(
                            max_fd_mass,
                            abs(plus["mass_residual"]),
                            abs(minus["mass_residual"]),
                        )
                        unchanged = (
                            unchanged
                            and plus["base_state_bitwise_unchanged"]
                            and minus["base_state_bitwise_unchanged"]
                        )
                        tangent_fd = (
                            plus["q_bottom"] - minus["q_bottom"]
                        ) / (2.0 * fd_step)
                        metric = tangent_metric(trial["tangent"], tangent_fd)
                        max_tangent_metric = max(max_tangent_metric, metric)
                        rows.append({
                            "n_cells": n,
                            "sigma": sigma,
                            "dt": dt,
                            "boundary_state": boundary_state,
                            "k_bottom": k_bottom,
                            "fd_step": fd_step,
                            "q_bottom": trial["q_bottom"],
                            "tangent_analytic": trial["tangent"],
                            "tangent_symmetric_fd": tangent_fd,
                            "tangent_metric": metric,
                            "mass_residual": trial["mass_residual"],
                            "normal_linear_residual": trial["normal_linear_residual"],
                            "sensitivity_linear_residual": trial["sensitivity_linear_residual"],
                            "base_state_bitwise_unchanged": trial["base_state_bitwise_unchanged"],
                        })

    passed = (
        max_mass <= MASS_TOL
        and max_fd_mass <= MASS_TOL
        and max_normal_linear <= LINEAR_TOL
        and max_sensitivity_linear <= LINEAR_TOL
        and max_tangent_metric <= TANGENT_TOL
        and unchanged
    )
    evidence = {
        "schema_version": 1,
        "workstream": "F-ROSS",
        "work_unit": "F-ROSS01",
        "gate": "J0_RESPONSE_TANGENT_ALGEBRA",
        "fixture": "ANALYTIC_LINEAR_INTERNAL_AND_BOTTOM_FACE_LAWS_NOT_SWAP_PHYSICS",
        "analytic_trials": analytic_trials,
        "finite_difference_reference_trials": fd_reference_trials,
        "comparisons": len(rows),
        "thresholds": {
            "mass_residual_abs_max": MASS_TOL,
            "linear_residual_abs_max": LINEAR_TOL,
            "tangent_relative_or_scaled_absolute_max": TANGENT_TOL,
            "tangent_scale_floor": TANGENT_SCALE_FLOOR,
        },
        "observed": {
            "maximum_abs_normal_trial_mass_residual": max_mass,
            "maximum_abs_fd_reference_mass_residual": max_fd_mass,
            "maximum_abs_normal_linear_residual": max_normal_linear,
            "maximum_abs_sensitivity_linear_residual": max_sensitivity_linear,
            "maximum_tangent_comparison_metric": max_tangent_metric,
            "base_state_bitwise_unchanged_all": unchanged,
            "analytic_path_matrix_factorizations_per_trial": 1,
            "analytic_path_normal_backsolves_per_trial": 1,
            "analytic_path_additional_tangent_backsolves_per_trial": 1,
            "analytic_path_global_nonlinear_iterations": 0,
            "finite_difference_trials_are_reference_only": True,
        },
        "rows": rows,
        "pass": passed,
        "decision": (
            "RESPONSE_TANGENT_ALGEBRA_QUALIFIED_READY_FOR_REAL_HYDRAULIC_DERIVATIVE_GATE"
            if passed
            else "RESPONSE_TANGENT_ALGEBRA_FAILED_DO_NOT_ATTACH_REAL_HYDRAULICS"
        ),
        "scope_limit": "This gate proves only the discrete same-factorization sensitivity construction for the analytic linear fixture. It does not qualify SWAP hydraulic tables, pressure-head semantics, saturation switching, prescribed-flux inversion, groundwater or MODFLOW coupling.",
    }
    out.write_text(json.dumps(evidence, indent=2, sort_keys=True) + "\n")
    print(json.dumps({k: v for k, v in evidence.items() if k != "rows"}, indent=2, sort_keys=True))
    raise SystemExit(0 if passed else 1)


if __name__ == "__main__":
    main()
