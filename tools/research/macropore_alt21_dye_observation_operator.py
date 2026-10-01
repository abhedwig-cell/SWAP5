#!/usr/bin/env python3
"""F-MACRO-ALT21: minimal dye observation operator.

Research-only, no fitted observation coefficient.

Maps reduced RFM water-routing outputs to rank-only dye signatures:
- deep_receipt_fraction
- normalized_mean_deposition_depth
- pathway_activation_fraction

The comparator only evaluates published directional/rank constraints from
Hartmann et al. (2022). It does not convert water flux to dye percentage.
"""

from __future__ import annotations
import json
import math

SIGMA_B = 0.65
MB = 0.25
Z_AH = 25.0
Z_IC = 85.0
R_AH = 0.2
A = 0.31
B = 0.55

# Representative ALT12 hydraulic screen state only.
K = 0.396
S = 13.34


def cdf(x):
    return 0.5 * (1.0 + math.erf(x / math.sqrt(2.0)))


def partition(R, b50):
    mu = math.log(b50)
    lr = math.log(R)
    z1 = (lr - mu - SIGMA_B * SIGMA_B) / SIGMA_B
    z2 = (lr - mu) / SIGMA_B
    matrix = math.exp(mu + 0.5 * SIGMA_B * SIGMA_B) * cdf(z1)
    matrix += R * (1.0 - cdf(z2))
    matrix = max(0.0, min(R, matrix))
    return matrix, R - matrix


def survival(z):
    if z <= Z_AH:
        ic = 1.0
    elif z >= Z_IC:
        ic = 0.0
    else:
        x = (z - Z_AH) / (Z_IC - Z_AH)
        ic = (1.0 - R_AH) * ((1.0 - x ** A) ** B)
    return MB + (1.0 - MB) * ic


def activation_fraction(intensity, duration_h, dt=0.001):
    n = max(1, round(duration_h / dt))
    dt = duration_h / n
    pref = 0.0
    for i in range(n):
        tau = (i + 0.5) * dt
        b50 = K + S / (2.0 * math.sqrt(tau))
        _, p = partition(intensity, b50)
        pref += p * dt
    total = intensity * duration_h
    return pref / total if total else 0.0


def observation_signature(intensity):
    # Hartmann design: same 40 mm total, so duration = amount/intensity.
    duration_h = 40.0 / intensity
    af = activation_fraction(intensity, duration_h)

    depths = [i * 5.0 for i in range(21)]
    sv = [survival(z) for z in depths]
    term = []
    for i in range(len(depths) - 1):
        loss = max(0.0, sv[i] - sv[i + 1])
        term.append((0.5 * (depths[i] + depths[i + 1]), loss))

    total_term = sum(w for _, w in term)
    mean_dep = (
        sum(z * w for z, w in term) / total_term
        if total_term > 0 else 0.0
    )

    # With fixed geometry, activation changes amount, not the normalized
    # geometry distribution. This is deliberate and is the hypothesis tested.
    deep_receipt = af * MB
    return {
        "intensity_mm_h": intensity,
        "duration_h": duration_h,
        "pathway_activation_fraction": af,
        "deep_receipt_fraction_of_total_input": deep_receipt,
        "normalized_mean_deposition_depth_cm": mean_dep,
    }


def direction(vals):
    if vals[0] < vals[1] < vals[2]:
        return "increasing"
    if vals[0] > vals[1] > vals[2]:
        return "decreasing"
    return "non_monotonic"


def main():
    rows = [observation_signature(i) for i in (20.0, 40.0, 60.0)]

    rfm = {
        "activation_direction": direction(
            [r["pathway_activation_fraction"] for r in rows]
        ),
        "deep_receipt_direction": direction(
            [r["deep_receipt_fraction_of_total_input"] for r in rows]
        ),
        "mean_deposition_depth_direction": direction(
            [r["normalized_mean_deposition_depth_cm"] for r in rows]
        ),
    }

    # Published direction constraints. Only 13.5 ka had a significant
    # intensity relationship in representative maximum infiltration depth.
    published = {
        "4900": {
            "categorical_pf_frequency": "increasing",
            "representative_infiltration_depth": "no_significant_intensity_relation",
        },
        "13500": {
            "categorical_pf_frequency": "decreasing",
            "representative_infiltration_depth": "increasing_significant",
        },
        "110": {
            "categorical_pf_frequency": "non_monotonic",
            "surface_runoff_limitation": True,
        },
        "160": {
            "categorical_pf_frequency": "non_monotonic",
            "surface_runoff_limitation": True,
        },
    }

    out = {
        "schema": "swap5.f_macro_alt21.rank_only_dye_operator.v1",
        "status": "RESEARCH_ONLY",
        "no_fitted_observation_parameter": True,
        "rfm_signatures": rows,
        "rfm_directions": rfm,
        "published_constraints": published,
        "key_test": {
            "fixed_geometry_prediction": (
                "normalized deposition-depth distribution is invariant with intensity; "
                "only activated amount/deep receipt increases"
            ),
            "empirical_pressure": (
                "13.5 ka representative infiltration depth increases significantly with intensity"
            ),
            "interpretation": (
                "If confirmed with raw profiles, fixed connectivity geometry alone cannot "
                "produce intensity-dependent penetration depth; either activation must select "
                "deeper connectivity non-uniformly or connectivity state must be source-dependent."
            ),
        },
    }
    print(json.dumps(out, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
