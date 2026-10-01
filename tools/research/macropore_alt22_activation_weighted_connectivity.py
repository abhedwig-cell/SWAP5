#!/usr/bin/env python3
"""F-MACRO-ALT22: activation-weighted connectivity feasibility screen.

Research-only. No event-specific geometry fit.

Structural connectivity C_struct(z) is fixed per profile class.
Event activation fraction a recruits a shallow-to-deep quantile of the
pre-existing terminating-path population:

    C_active_abs(z | a) = max(0, a - F_end(z))
    F_end(z) = 1 - C_struct(z)

This introduces no new event parameter. It only maps an already-computed
activation fraction onto a fixed structural endpoint distribution.

The screen asks whether different fixed structural shapes can yield:
- more activation with little/no penetration-depth change;
- more activation with substantial penetration-depth change.
"""

from __future__ import annotations
import json
import math

SIGMA_B = 0.65
K_SURFACE = 0.396
S_SURFACE = 13.34
Z_AH = 25.0
Z_IC = 85.0
R_AH = 0.2


def cdf(x):
    return 0.5 * (1.0 + math.erf(x / math.sqrt(2.0)))


def preferential_rate(rain_rate, b50):
    mu = math.log(b50)
    lr = math.log(rain_rate)
    z1 = (lr - mu - SIGMA_B * SIGMA_B) / SIGMA_B
    z2 = (lr - mu) / SIGMA_B
    matrix = math.exp(mu + 0.5 * SIGMA_B * SIGMA_B) * cdf(z1)
    matrix += rain_rate * (1.0 - cdf(z2))
    matrix = max(0.0, min(rain_rate, matrix))
    return rain_rate - matrix


def activation_fraction(intensity, total_mm=40.0, dt_h=0.001):
    duration_h = total_mm / intensity
    n = max(1, round(duration_h / dt_h))
    dt_h = duration_h / n
    pref = 0.0
    for i in range(n):
        tau = (i + 0.5) * dt_h
        b50 = K_SURFACE + S_SURFACE / (2.0 * math.sqrt(tau))
        pref += preferential_rate(intensity, b50) * dt_h
    return pref / total_mm


def c_struct(z, shape_a, shape_b):
    if z <= Z_AH:
        return 1.0
    if z >= Z_IC:
        return 0.0
    x = (z - Z_AH) / (Z_IC - Z_AH)
    return (1.0 - R_AH) * ((1.0 - x ** shape_a) ** shape_b)


def active_survival_abs(z, activation, shape_a, shape_b):
    """Absolute active terminating-path survival fraction.

    Endpoint CDF F_end = 1 - C_struct.
    Shallow-to-deep quantile recruitment activates the lowest endpoint-depth
    quantiles first. A path reaches z only if its endpoint quantile exceeds F_end(z).
    """
    f_end = 1.0 - c_struct(z, shape_a, shape_b)
    return max(0.0, activation - f_end)


def active_depth_metrics(activation, shape_a, shape_b):
    dz = 0.1
    depths = [Z_AH + i * dz for i in range(round((Z_IC - Z_AH) / dz) + 1)]
    surv = [active_survival_abs(z, activation, shape_a, shape_b) for z in depths]

    active_depths = [z for z, s in zip(depths, surv) if s > 1.0e-8]
    max_depth = max(active_depths) if active_depths else Z_AH

    # Approximate termination mass as decline in absolute active survival.
    terms = []
    for i in range(len(depths) - 1):
        loss = max(0.0, surv[i] - surv[i + 1])
        zmid = 0.5 * (depths[i] + depths[i + 1])
        terms.append((zmid, loss))
    total_term = sum(w for _, w in terms)
    mean_depth = (
        sum(z * w for z, w in terms) / total_term
        if total_term > 0 else Z_AH
    )

    return {
        "max_active_termination_depth_cm": max_depth,
        "mean_active_termination_depth_cm": mean_depth,
    }


def evaluate_profile(name, shape_a, shape_b, activations):
    rows = []
    for intensity, activation in activations:
        rows.append({
            "intensity_mm_h": intensity,
            "activation_fraction": activation,
            **active_depth_metrics(activation, shape_a, shape_b),
        })
    return {
        "name": name,
        "shape_a": shape_a,
        "shape_b": shape_b,
        "rows": rows,
        "max_depth_change_20_to_60_cm": (
            rows[-1]["max_active_termination_depth_cm"]
            - rows[0]["max_active_termination_depth_cm"]
        ),
        "mean_depth_change_20_to_60_cm": (
            rows[-1]["mean_active_termination_depth_cm"]
            - rows[0]["mean_active_termination_depth_cm"]
        ),
    }


def main():
    activations = [(i, activation_fraction(i)) for i in (20.0, 40.0, 60.0)]

    # These are synthetic structural-shape examples, not fits to Griessfirn.
    profiles = [
        evaluate_profile(
            "broad_depth_sensitive_example",
            0.31, 0.55, activations
        ),
        evaluate_profile(
            "depth_insensitive_example",
            0.10, 5.00, activations
        ),
        evaluate_profile(
            "moderate_depth_sensitive_example",
            3.00, 3.00, activations
        ),
    ]

    print(json.dumps({
        "schema": "swap5.f_macro_alt22.activation_weighted_connectivity.v1",
        "status": "RESEARCH_ONLY",
        "activation_fractions": [
            {"intensity_mm_h": i, "activation_fraction": a}
            for i, a in activations
        ],
        "selector": {
            "type": "shallow_to_deep_quantile_recruitment",
            "event_specific_parameters": 0,
            "formula": "C_active_abs(z|a)=max(0,a-(1-C_struct(z)))"
        },
        "profiles": profiles,
        "interpretation": [
            "The same event activation fractions can yield strong, moderate, or negligible penetration-depth response solely because fixed structural C(z) shapes differ.",
            "Therefore 4.9 ka versus 13.5 ka qualitative behavior is feasible without event-specific geometry refit.",
            "This is only a structural feasibility result; no Griessfirn profile has been fitted."
        ]
    }, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
