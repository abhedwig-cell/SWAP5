#!/usr/bin/env python3
"""F-AHL01 research preflight.

Builds a frozen adaptive lookup over the expensive smooth unsaturated B1.10/MvG
core for four already-bound RossFast catalog materials. This is not production
code and deliberately keeps saturation and the Hcrit..0 near-saturation branch
outside the lookup.

The preflight compares adaptive support-point counts and constitutive errors to
a fixed 401-point log-head baseline. It does not make an end-to-end performance
claim.
"""
from __future__ import annotations

import json
import math
from dataclasses import dataclass, asdict

HCRIT = -1.0e-2
HMIN = -1.0e6
STEP_DURATION_DAY = 1.0 / 24.0
THETA_TOL = 1.0e-5
LOGC_TOL = 1.0e-2
LOGK_TOL = 1.0e-2
FIXED_N = 401

# theta_r, theta_s, alpha [1/cm], n, Ksatfit [cm/d], lambda
MATERIALS = {
    "B01": (0.02, 0.427494, 0.021659, 1.734737, 31.225016, 0.98087),
    "B12": (0.01, 0.529749, 0.016562, 1.090671, 2.245895, -4.493581),
    "O05": (0.01, 0.336701, 0.030304, 2.887502, 17.418504, 0.0736),
    "O14": (0.01, 0.393878, 0.003288, 1.616573, 2.495984, 0.514012),
}


@dataclass(frozen=True)
class ErrorTriple:
    theta_span: float
    log_capacity: float
    log_conductivity: float


def derived(p):
    tr, ts, alpha, n, ksat, lam = p
    m = 1.0 - 1.0 / n
    span = ts - tr
    theta_hcrit = tr + span / (1.0 + abs(alpha * HCRIT) ** n) ** m
    c27 = (ts - theta_hcrit) / (-HCRIT)
    return tr, ts, alpha, n, ksat, lam, m, span, theta_hcrit, c27


def evaluate_core(head, p):
    """B1.10 Branch-A smooth core, restricted to head <= HCRIT."""
    if head > HCRIT:
        raise ValueError("core evaluator called outside preregistered domain")
    tr, ts, alpha, n, ksat, lam, m, span, _, _ = derived(p)

    ah = abs(alpha * head)
    theta = tr + span / (1.0 + ah ** n) ** m

    term1 = ah ** (n - 1.0)
    capacity = n * m * alpha * (span / (1.0 + term1 * ah) ** (m + 1.0)) * term1
    if head > -1.0 and capacity < STEP_DURATION_DAY * 1.0e-7:
        capacity = STEP_DURATION_DAY * 1.0e-7

    relsat = (theta - tr) / span
    if relsat > 1.0 - 1.0e-6:
        conductivity = ksat
    else:
        term = (1.0 - relsat ** (1.0 / m)) ** m
        conductivity = ksat * relsat ** lam * (1.0 - term) ** 2
        conductivity = min(conductivity, ksat)

    return theta, max(capacity, 1.0e-300), max(conductivity, 1.0e-300)


def transformed_values(head, p):
    theta, capacity, conductivity = evaluate_core(head, p)
    return theta, math.log(capacity), math.log(conductivity)


def x_from_head(head):
    return math.log10(-head)


def head_from_x(x):
    return -(10.0 ** x)


def conductivity_switch_head(p):
    tr, ts, alpha, n, _, _, m, _, _, _ = derived(p)
    del tr, ts
    s = 1.0 - 1.0e-6
    return -((s ** (-1.0 / m) - 1.0) ** (1.0 / n)) / alpha


def interval_error(h0, h1, p):
    x0, x1 = x_from_head(h0), x_from_head(h1)
    y0, y1 = transformed_values(h0, p), transformed_values(h1, p)
    span = derived(p)[7]
    maxima = [0.0, 0.0, 0.0]
    for fraction in (0.25, 0.5, 0.75):
        x = x0 + fraction * (x1 - x0)
        head = head_from_x(x)
        truth = transformed_values(head, p)
        interp = tuple(y0[j] + fraction * (y1[j] - y0[j]) for j in range(3))
        errors = (
            abs(interp[0] - truth[0]) / span,
            abs(interp[1] - truth[1]),
            abs(interp[2] - truth[2]),
        )
        maxima = [max(maxima[j], errors[j]) for j in range(3)]
    score = max(
        maxima[0] / THETA_TOL,
        maxima[1] / LOGC_TOL,
        maxima[2] / LOGK_TOL,
    )
    return score, ErrorTriple(*maxima)


def refine(h0, h1, p, depth=0):
    score, _ = interval_error(h0, h1, p)
    if score <= 1.0:
        return [h0, h1]
    if depth >= 40:
        raise RuntimeError("adaptive refinement depth exceeded")
    midpoint = head_from_x(0.5 * (x_from_head(h0) + x_from_head(h1)))
    left = refine(h0, midpoint, p, depth + 1)
    right = refine(midpoint, h1, p, depth + 1)
    return left[:-1] + right


def adaptive_knots(p):
    boundaries = [HMIN, HCRIT]
    kswitch = conductivity_switch_head(p)
    if HMIN < kswitch < HCRIT:
        boundaries.append(kswitch)
    boundaries = sorted(set(boundaries))

    knots = []
    for h0, h1 in zip(boundaries[:-1], boundaries[1:]):
        segment = refine(h0, h1, p)
        knots.extend(segment[:-1])
    knots.append(boundaries[-1])
    return knots


def fixed_knots(n=FIXED_N):
    x0, x1 = x_from_head(HMIN), x_from_head(HCRIT)
    heads = [head_from_x(x0 + i * (x1 - x0) / (n - 1)) for i in range(n)]
    return sorted(heads)


def validate(knots, p):
    maxima = ErrorTriple(0.0, 0.0, 0.0)
    for h0, h1 in zip(knots[:-1], knots[1:]):
        _, e = interval_error(h0, h1, p)
        maxima = ErrorTriple(
            max(maxima.theta_span, e.theta_span),
            max(maxima.log_capacity, e.log_capacity),
            max(maxima.log_conductivity, e.log_conductivity),
        )
    return maxima


def passes(e):
    return (
        e.theta_span <= THETA_TOL
        and e.log_capacity <= LOGC_TOL
        and e.log_conductivity <= LOGK_TOL
    )


def main():
    result = {
        "work_unit": "F-AHL01",
        "scope": "research preflight only",
        "domain_cm": [HMIN, HCRIT],
        "tolerances": {
            "theta_span_normalized_abs": THETA_TOL,
            "abs_log_capacity": LOGC_TOL,
            "abs_log_conductivity": LOGK_TOL,
        },
        "fixed_baseline_points": FIXED_N,
        "materials": {},
    }

    for material_id, p in MATERIALS.items():
        adaptive = adaptive_knots(p)
        fixed = fixed_knots()
        adaptive_error = validate(adaptive, p)
        fixed_error = validate(fixed, p)
        result["materials"][material_id] = {
            "adaptive_points": len(adaptive),
            "adaptive_error": asdict(adaptive_error),
            "adaptive_pass": passes(adaptive_error),
            "fixed_points": len(fixed),
            "fixed_error": asdict(fixed_error),
            "fixed_pass": passes(fixed_error),
            "conductivity_switch_head_cm": conductivity_switch_head(p),
        }

    print(json.dumps(result, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
