#!/usr/bin/env python3
"""F-MACRO-ALT08: RFM-1B activation-transferability harness.

Research-only.
Tests whether one fixed heterogeneity parameter sigma_B transfers across:
- rainfall intensity;
- matrix-infiltrability scale b50 representing different antecedent states.

No production SWAP mutation. Standard library only.
"""

from __future__ import annotations

import json
import math


def normal_cdf(x: float) -> float:
    return 0.5 * (1.0 + math.erf(x / math.sqrt(2.0)))


def lognormal_partition(
    rain_rate: float,
    b50: float,
    sigma_ln: float,
) -> dict:
    if rain_rate <= 0.0:
        return {
            "rain_rate": rain_rate,
            "matrix_rate": 0.0,
            "preferential_rate": 0.0,
            "preferential_fraction": 0.0,
        }
    if b50 <= 0.0 or sigma_ln <= 0.0:
        raise ValueError("b50 and sigma_ln must be > 0")

    mu = math.log(b50)
    lr = math.log(rain_rate)

    z_trunc = (lr - mu - sigma_ln * sigma_ln) / sigma_ln
    z_tail = (lr - mu) / sigma_ln

    truncated_mean = (
        math.exp(mu + 0.5 * sigma_ln * sigma_ln)
        * normal_cdf(z_trunc)
    )
    matrix_rate = (
        truncated_mean
        + rain_rate * (1.0 - normal_cdf(z_tail))
    )
    matrix_rate = min(rain_rate, max(0.0, matrix_rate))
    pref_rate = rain_rate - matrix_rate

    return {
        "rain_rate": rain_rate,
        "matrix_rate": matrix_rate,
        "preferential_rate": pref_rate,
        "preferential_fraction": pref_rate / rain_rate,
    }


def main() -> None:
    sigma_b = 0.65
    rainfall_rates = [2.0, 4.0, 8.0, 15.0, 30.0, 60.0]

    # Prescribed matrix-capacity scales for this transferability screen.
    # Their physical derivation from SWAP hydraulic state is deliberately
    # left for a later work unit.
    b50_values = [8.0, 12.0, 20.0]

    cases = []
    for b50 in b50_values:
        rows = [
            lognormal_partition(r, b50, sigma_b)
            for r in rainfall_rates
        ]
        cases.append({
            "b50": b50,
            "sigma_B": sigma_b,
            "rows": rows,
            "monotone_in_rain_intensity": all(
                rows[i + 1]["preferential_fraction"]
                >= rows[i]["preferential_fraction"]
                for i in range(len(rows) - 1)
            ),
        })

    cross_state = []
    for rain_rate in rainfall_rates:
        fracs = [
            lognormal_partition(rain_rate, b50, sigma_b)[
                "preferential_fraction"
            ]
            for b50 in b50_values
        ]
        cross_state.append({
            "rain_rate": rain_rate,
            "fractions_for_b50_8_12_20": fracs,
            "decreases_with_matrix_capacity": (
                fracs[0] >= fracs[1] >= fracs[2]
            ),
        })

    output = {
        "schema": "swap5.f_macro_alt08.rfm1b_activation_transfer.v1",
        "status": "RESEARCH_ONLY",
        "sigma_B": sigma_b,
        "b50_values": b50_values,
        "rainfall_rates": rainfall_rates,
        "cases": cases,
        "cross_state_checks": cross_state,
        "all_intensity_monotone": all(
            c["monotone_in_rain_intensity"] for c in cases
        ),
        "all_capacity_monotone": all(
            c["decreases_with_matrix_capacity"] for c in cross_state
        ),
        "interpretation": (
            "One fixed sigma_B produces source-responsive activation across "
            "rainfall intensities and prescribed matrix-capacity states. "
            "The mapping from current SWAP hydraulic state to b50 remains "
            "unqualified and is the next research target."
        ),
    }
    print(json.dumps(output, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
