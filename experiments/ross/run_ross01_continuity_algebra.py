from __future__ import annotations

import json
import math
import struct
import sys
from pathlib import Path

MASS_TOL = 1.0e-12
LINEAR_TOL = 1.0e-12
CELL_COUNTS = (1, 2, 3, 8, 32, 128)
SIGMAS = (0.0, 0.5, 1.0)


def float_bytes(values):
    return b"".join(struct.pack("!d", float(v)) for v in values)


def thomas(lower, diag, upper, rhs):
    """Solve a tridiagonal system without iteration; inputs are not mutated."""
    n = len(diag)
    if not (len(lower) == max(0, n - 1) == len(upper) and len(rhs) == n):
        raise ValueError("invalid tridiagonal dimensions")
    if n == 0:
        return []
    c = list(upper)
    d = list(rhs)
    b = list(diag)
    a = list(lower)
    for i in range(1, n):
        if b[i - 1] == 0.0:
            raise ZeroDivisionError(("zero_pivot", i - 1))
        w = a[i - 1] / b[i - 1]
        b[i] -= w * c[i - 1]
        d[i] -= w * d[i - 1]
    if b[-1] == 0.0:
        raise ZeroDivisionError(("zero_pivot", n - 1))
    x = [0.0] * n
    x[-1] = d[-1] / b[-1]
    for i in range(n - 2, -1, -1):
        if b[i] == 0.0:
            raise ZeroDivisionError(("zero_pivot", i))
        x[i] = (d[i] - c[i] * x[i + 1]) / b[i]
    return x


def internal_flux(theta_upper, theta_lower, k, gravity):
    """Analytic linear face law used only to isolate continuity algebra."""
    return k * (theta_upper - theta_lower) + gravity


def build_case(n):
    theta = tuple(0.18 + 0.0017 * ((7 * i + 3) % 23) for i in range(n))
    dz = tuple(4.0 + 0.5 * ((5 * i + 1) % 7) for i in range(n))
    # Internal face coefficient j lies between cells j-1 and j.  Vary it strongly
    # enough that the matrix is genuinely heterogeneous.
    k = tuple(0.015 * (1.0 + ((11 * j + 2) % 9)) for j in range(1, n))
    gravity = tuple(0.0025 * (((3 * j) % 5) - 2) for j in range(1, n))
    source = tuple(0.0007 * (1 + (i % 3)) for i in range(n))
    sink = tuple(0.0004 * (1 + ((2 * i + 1) % 4)) for i in range(n))
    return theta, dz, k, gravity, source, sink


def assemble(theta, dz, k, gravity, source, sink, dt, sigma, q_top, q_bottom):
    n = len(theta)
    q0 = [0.0] * (n + 1)
    q0[0] = q_top
    q0[-1] = q_bottom
    for j in range(1, n):
        q0[j] = internal_flux(theta[j - 1], theta[j], k[j - 1], gravity[j - 1])

    lower = [0.0] * max(0, n - 1)
    diag = [1.0] * n
    upper = [0.0] * max(0, n - 1)
    rhs = [0.0] * n

    for i in range(n):
        fac = dt * sigma / dz[i]
        rhs[i] = dt * (q0[i] - q0[i + 1] + source[i] - sink[i]) / dz[i]
        if i > 0:
            # Incoming internal face i: dq/dtheta_{i-1}=+k, dq/dtheta_i=-k.
            ki = k[i - 1]
            lower[i - 1] -= fac * ki
            diag[i] += fac * ki
        if i < n - 1:
            # Outgoing internal face i+1: subtracting q adds +fac*k on the
            # diagonal and -fac*k on the upper off-diagonal.
            ko = k[i]
            diag[i] += fac * ko
            upper[i] -= fac * ko
    return lower, diag, upper, rhs, q0


def matrix_residual(lower, diag, upper, x, rhs):
    n = len(diag)
    residuals = []
    for i in range(n):
        lhs = diag[i] * x[i]
        if i > 0:
            lhs += lower[i - 1] * x[i - 1]
        if i < n - 1:
            lhs += upper[i] * x[i + 1]
        residuals.append(lhs - rhs[i])
    return max((abs(r) for r in residuals), default=0.0)


def realized_fluxes(theta, delta, k, gravity, sigma, q_top, q_bottom):
    n = len(theta)
    q = [0.0] * (n + 1)
    q[0] = q_top
    q[-1] = q_bottom
    for j in range(1, n):
        q_start = internal_flux(theta[j - 1], theta[j], k[j - 1], gravity[j - 1])
        # First-order Taylor flux at the selected fraction sigma of the step.
        q[j] = q_start + sigma * k[j - 1] * (delta[j - 1] - delta[j])
    return q


def run_trial(theta, dz, k, gravity, source, sink, dt, sigma, q_top, q_bottom):
    snapshot = float_bytes(theta)
    lower, diag, upper, rhs, q0 = assemble(
        theta, dz, k, gravity, source, sink, dt, sigma, q_top, q_bottom
    )
    delta = thomas(lower, diag, upper, rhs)
    q = realized_fluxes(theta, delta, k, gravity, sigma, q_top, q_bottom)
    candidate = tuple(theta[i] + delta[i] for i in range(len(theta)))

    storage_change = math.fsum(delta[i] * dz[i] for i in range(len(theta)))
    external_change = dt * (
        q[0] - q[-1] + math.fsum(source) - math.fsum(sink)
    )
    mass_residual = storage_change - external_change
    linear_residual = matrix_residual(lower, diag, upper, delta, rhs)
    return {
        "candidate": candidate,
        "delta": delta,
        "q_start": q0,
        "q_realized": q,
        "mass_residual": mass_residual,
        "linear_residual": linear_residual,
        "base_state_bitwise_unchanged": float_bytes(theta) == snapshot,
        "global_nonlinear_iterations": 0,
        "linear_solve_rows": len(theta),
        "internal_face_evaluations": max(0, len(theta) - 1),
    }


def main():
    if len(sys.argv) != 2:
        raise SystemExit("usage: run_ross01_continuity_algebra.py EVIDENCE_JSON")
    out = Path(sys.argv[1])
    rows = []
    max_mass = 0.0
    max_linear = 0.0
    unchanged = True

    for n in CELL_COUNTS:
        theta, dz, k, gravity, source, sink = build_case(n)
        # Use nonzero and asymmetric external fluxes to ensure the external ledger
        # is actually exercised.
        q_top = 0.031
        q_bottom = -0.007
        for sigma in SIGMAS:
            # Vary dt with n but keep it independent of solver convergence; there
            # is exactly one direct linear solve in every case.
            dt = 0.37 + 0.013 * n
            result = run_trial(
                theta, dz, k, gravity, source, sink, dt, sigma, q_top, q_bottom
            )
            max_mass = max(max_mass, abs(result["mass_residual"]))
            max_linear = max(max_linear, abs(result["linear_residual"]))
            unchanged = unchanged and result["base_state_bitwise_unchanged"]
            rows.append({
                "n_cells": n,
                "sigma": sigma,
                "dt": dt,
                "mass_residual": result["mass_residual"],
                "linear_residual": result["linear_residual"],
                "base_state_bitwise_unchanged": result["base_state_bitwise_unchanged"],
                "global_nonlinear_iterations": result["global_nonlinear_iterations"],
                "linear_solve_rows": result["linear_solve_rows"],
                "internal_face_evaluations": result["internal_face_evaluations"],
            })

    passed = (
        max_mass <= MASS_TOL
        and max_linear <= LINEAR_TOL
        and unchanged
        and all(r["global_nonlinear_iterations"] == 0 for r in rows)
    )
    evidence = {
        "schema_version": 1,
        "workstream": "F-ROSS",
        "work_unit": "F-ROSS01",
        "gate": "A_CONTINUITY_ALGEBRA",
        "hydraulic_fixture": "ANALYTIC_LINEAR_FACE_LAW_NOT_SWAP_PHYSICS",
        "cases": len(rows),
        "thresholds": {
            "mass_residual_abs_max": MASS_TOL,
            "tridiagonal_residual_abs_max": LINEAR_TOL,
        },
        "observed": {
            "maximum_abs_mass_residual": max_mass,
            "maximum_abs_tridiagonal_residual": max_linear,
            "base_state_bitwise_unchanged_all": unchanged,
            "global_nonlinear_iterations": 0,
            "cost_model": "ONE_TRIDIAGONAL_O_N_SOLVE_PLUS_O_N_FACE_EVALUATION_PER_INTERNAL_STEP",
        },
        "rows": rows,
        "decision": (
            "CONTINUITY_ALGEBRA_QUALIFIED_READY_FOR_REAL_FACE_TABLE_GATE"
            if passed
            else "CONTINUITY_ALGEBRA_FAILED_DO_NOT_ATTACH_REAL_HYDRAULICS"
        ),
        "scope_limit": "This gate does not qualify physical face fluxes, saturated-unsaturated switching, timestep accuracy, SWAP hydraulics, groundwater or coupling.",
        "pass": passed,
    }
    out.write_text(json.dumps(evidence, indent=2, sort_keys=True) + "\n")
    print(json.dumps(evidence, indent=2, sort_keys=True))
    raise SystemExit(0 if passed else 1)


if __name__ == "__main__":
    main()
