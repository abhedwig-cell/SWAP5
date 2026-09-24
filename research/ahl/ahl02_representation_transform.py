#!/usr/bin/env python3
"""F-AHL02 transformed-retention research preflight.

Compares the F-AHL01 direct-theta representation with a linear representation
of logit(Se). Capacity and conductivity remain represented in log space.
"""
from __future__ import annotations

import json
import math
import ahl01_adaptive_lookup as base


def logit_se_values(head, p):
    theta, capacity, conductivity = base.evaluate_core(head, p)
    tr, ts, *_ = p
    se = (theta - tr) / (ts - tr)
    eps = 1.0e-15
    se = min(max(se, eps), 1.0 - eps)
    return math.log(se / (1.0 - se)), math.log(capacity), math.log(conductivity)


def interval_error(h0, h1, p):
    x0, x1 = base.x_from_head(h0), base.x_from_head(h1)
    y0, y1 = logit_se_values(h0, p), logit_se_values(h1, p)
    tr, ts, *_ = p
    span = ts - tr
    maxima = [0.0, 0.0, 0.0]

    for fraction in (0.125, 0.25, 0.5, 0.75, 0.875):
        x = x0 + fraction * (x1 - x0)
        head = base.head_from_x(x)
        theta_true, capacity_true, conductivity_true = base.evaluate_core(head, p)
        yi = tuple(y0[j] + fraction * (y1[j] - y0[j]) for j in range(3))

        if yi[0] >= 0.0:
            exp_neg = math.exp(-min(yi[0], 700.0))
            se = 1.0 / (1.0 + exp_neg)
        else:
            exp_pos = math.exp(max(yi[0], -700.0))
            se = exp_pos / (1.0 + exp_pos)
        theta = tr + span * se

        errors = (
            abs(theta - theta_true) / span,
            abs(yi[1] - math.log(capacity_true)),
            abs(yi[2] - math.log(conductivity_true)),
        )
        maxima = [max(maxima[j], errors[j]) for j in range(3)]

    score = max(
        maxima[0] / base.THETA_TOL,
        maxima[1] / base.LOGC_TOL,
        maxima[2] / base.LOGK_TOL,
    )
    return score, maxima


def refine(h0, h1, p, depth=0):
    score, _ = interval_error(h0, h1, p)
    if score <= 1.0:
        return [h0, h1]
    if depth >= 40:
        raise RuntimeError("adaptive refinement depth exceeded")
    midpoint = base.head_from_x(0.5 * (base.x_from_head(h0) + base.x_from_head(h1)))
    left = refine(h0, midpoint, p, depth + 1)
    right = refine(midpoint, h1, p, depth + 1)
    return left[:-1] + right


def adaptive_knots(p):
    boundaries = [base.HMIN, base.HCRIT]
    kswitch = base.conductivity_switch_head(p)
    if base.HMIN < kswitch < base.HCRIT:
        boundaries.append(kswitch)
    boundaries = sorted(set(boundaries))

    knots = []
    for h0, h1 in zip(boundaries[:-1], boundaries[1:]):
        segment = refine(h0, h1, p)
        knots.extend(segment[:-1])
    knots.append(boundaries[-1])
    return knots


def validate(knots, p):
    maxima = [0.0, 0.0, 0.0]
    for h0, h1 in zip(knots[:-1], knots[1:]):
        _, e = interval_error(h0, h1, p)
        maxima = [max(maxima[j], e[j]) for j in range(3)]
    return maxima


def main():
    result = {
        "work_unit": "F-AHL02",
        "scope": "research preflight only",
        "representation": "linear logit(Se), log(C), log(K) over log10(-h)",
        "materials": {},
    }
    for material_id, p in base.MATERIALS.items():
        knots = adaptive_knots(p)
        e = validate(knots, p)
        result["materials"][material_id] = {
            "points": len(knots),
            "theta_span_error": e[0],
            "log_capacity_error": e[1],
            "log_conductivity_error": e[2],
            "pass": (
                e[0] <= base.THETA_TOL
                and e[1] <= base.LOGC_TOL
                and e[2] <= base.LOGK_TOL
            ),
        }
    print(json.dumps(result, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
