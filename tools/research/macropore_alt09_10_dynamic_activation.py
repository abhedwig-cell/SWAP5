#!/usr/bin/env python3
"""F-MACRO-ALT09/10: dynamic matrix-infiltrability activation.

Research-only.
Uses a time-dependent characteristic matrix infiltrability:
    b50(tau) = K_matrix + S_matrix / (2*sqrt(tau))
and one fixed lognormal heterogeneity parameter sigma_B.

The harness tests:
- no arbitrary characteristic time parameter;
- multiple matrix hydraulic states;
- multiple source intensities and pulse durations;
- direct coupling of dynamic activation to the existing RFM-1A geometry router.

Standard library only.
"""

from __future__ import annotations

import json
import math
from dataclasses import asdict, dataclass


SIGMA_B = 0.65
MB_FRACTION = 0.25

ENDPOINTS_CM = [85.0, 54.2, 35.6, 26.9, 25.0]
Z_AH_CM = 25.0
Z_IC_CM = 85.0
R_AH = 0.2
FIT_A = 0.31
FIT_B = 0.55


@dataclass
class ActivationSummary:
    rain_rate: float
    duration_h: float
    source_mm: float
    matrix_mm: float
    preferential_mm: float
    preferential_fraction: float


@dataclass
class RouteSummary:
    atmospheric_input: float
    matrix_direct: float
    preferential_input: float
    terminating_deposition: float
    bottom_fast_flux: float
    exchange: float
    residual_fast_storage: float
    mass_residual: float


def normal_cdf(x: float) -> float:
    return 0.5 * (1.0 + math.erf(x / math.sqrt(2.0)))


def partition(rain_rate: float, b50: float, sigma_ln: float) -> tuple[float, float]:
    if rain_rate <= 0.0:
        return 0.0, 0.0
    if b50 <= 0.0:
        raise ValueError("b50 must be > 0")

    mu = math.log(b50)
    lr = math.log(rain_rate)
    z_trunc = (lr - mu - sigma_ln * sigma_ln) / sigma_ln
    z_tail = (lr - mu) / sigma_ln

    truncated_mean = (
        math.exp(mu + 0.5 * sigma_ln * sigma_ln)
        * normal_cdf(z_trunc)
    )
    matrix = truncated_mean + rain_rate * (1.0 - normal_cdf(z_tail))
    matrix = min(rain_rate, max(0.0, matrix))
    return matrix, rain_rate - matrix


def b50_philip(k_matrix: float, sorptivity: float, event_age_h: float) -> float:
    age = max(event_age_h, 1.0e-8)
    return k_matrix + sorptivity / (2.0 * math.sqrt(age))


def activation_event(
    rain_rate: float,
    duration_h: float,
    k_matrix: float,
    sorptivity: float,
    sigma_b: float = SIGMA_B,
    dt_h: float = 0.001,
) -> ActivationSummary:
    source = matrix = pref = 0.0
    steps = max(1, round(duration_h / dt_h))
    dt_h = duration_h / steps

    for n in range(steps):
        age = (n + 0.5) * dt_h
        b50 = b50_philip(k_matrix, sorptivity, age)
        m, p = partition(rain_rate, b50, sigma_b)
        source += rain_rate * dt_h
        matrix += m * dt_h
        pref += p * dt_h

    return ActivationSummary(
        rain_rate=rain_rate,
        duration_h=duration_h,
        source_mm=source,
        matrix_mm=matrix,
        preferential_mm=pref,
        preferential_fraction=pref / source if source > 0.0 else 0.0,
    )


def ic_survival(depth_cm: float) -> float:
    if depth_cm <= Z_AH_CM:
        return 1.0
    if depth_cm >= Z_IC_CM:
        return 0.0
    x = (depth_cm - Z_AH_CM) / (Z_IC_CM - Z_AH_CM)
    return (1.0 - R_AH) * ((1.0 - x**FIT_A) ** FIT_B)


def route_integrated(
    *,
    rain_rate: float,
    duration_h: float,
    k_matrix: float,
    sorptivity: float,
    sigma_b: float = SIGMA_B,
) -> RouteSummary:
    """Feed dynamic activation directly into RFM-1A-like fast routing.

    Units are internally consistent research units; the balance is exact by construction.
    """
    dt_h = 0.001
    steps_event = max(1, round(duration_h / dt_h))
    total_h = max(duration_h + 8.0, 10.0)
    total_steps = round(total_h / dt_h)

    dz_cm = 5.0
    depths = [i * dz_cm for i in range(21)]
    survival = [
        MB_FRACTION + (1.0 - MB_FRACTION) * ic_survival(z)
        for z in depths
    ]
    for i in range(1, len(survival)):
        survival[i] = min(survival[i], survival[i - 1])

    storage = [0.0] * len(depths)
    event_s = [0.0] * len(depths)
    event_age = [0.0] * len(depths)
    event_active = [False] * len(depths)

    theta = [0.22] * len(depths)
    theta_s = 0.45
    exchange_scale = 0.0015
    release_rate_h = 3.0
    release_fraction = 1.0 - math.exp(-release_rate_h * dt_h)

    atmospheric = matrix_direct = pref_input = 0.0
    deposition = bottom = exchange = 0.0

    for n in range(total_steps):
        t = n * dt_h

        if n < steps_event:
            age = (n + 0.5) * dt_h
            b50 = b50_philip(k_matrix, sorptivity, age)
            mrate, prate = partition(rain_rate, b50, sigma_b)
            atmospheric += rain_rate * dt_h
            matrix_direct += mrate * dt_h
            incoming = prate * dt_h
            pref_input += incoming
            storage[0] += incoming

        released = [w * release_fraction for w in storage]
        for i, q in enumerate(released):
            storage[i] -= q

        carry = [0.0] * len(storage)
        for i in range(len(storage) - 1):
            if survival[i] <= 1.0e-14:
                deposition += released[i]
                continue
            survive = max(0.0, min(1.0, survival[i + 1] / survival[i]))
            carry[i + 1] += released[i] * survive
            deposition += released[i] * (1.0 - survive)

        bottom += released[-1]
        for i, q in enumerate(carry):
            storage[i] += q

        # Same compact event-history concept as prior RFM-1A screen.
        for i in range(len(storage)):
            if storage[i] > 1.0e-10 and not event_active[i]:
                event_active[i] = True
                event_age[i] = 0.0
                event_s[i] = exchange_scale * math.sqrt(
                    max(theta_s - theta[i], 0.0)
                )

            if event_active[i]:
                q = event_s[i] * (
                    math.sqrt(event_age[i] + dt_h)
                    - math.sqrt(event_age[i])
                )
                q = min(q, storage[i])
                storage[i] -= q
                exchange += q
                event_age[i] += dt_h

                if storage[i] <= 1.0e-10:
                    event_active[i] = False
                    event_s[i] = 0.0
                    event_age[i] = 0.0

    residual = sum(storage)
    # Whole atmospheric balance includes matrix direct intake and fast-path receipts.
    mass_residual = atmospheric - (
        matrix_direct + deposition + bottom + exchange + residual
    )

    return RouteSummary(
        atmospheric_input=atmospheric,
        matrix_direct=matrix_direct,
        preferential_input=pref_input,
        terminating_deposition=deposition,
        bottom_fast_flux=bottom,
        exchange=exchange,
        residual_fast_storage=residual,
        mass_residual=mass_residual,
    )


def main() -> None:
    # Illustrative hydraulic states. K and S are not calibrated SWAP soil values;
    # they are deliberately selected to span conductivity/sorptivity trade-offs.
    states = {
        "fine_dry": {"K": 2.0, "S": 10.0},
        "fine_wet": {"K": 5.0, "S": 4.0},
        "coarse_dry": {"K": 15.0, "S": 7.0},
        "coarse_wet": {"K": 25.0, "S": 3.0},
    }
    intensities = [5.0, 15.0, 30.0, 60.0]
    durations_h = [0.1, 0.5, 2.0]

    activation = {}
    for name, pars in states.items():
        rows = []
        for duration in durations_h:
            for intensity in intensities:
                rows.append(
                    asdict(
                        activation_event(
                            intensity,
                            duration,
                            pars["K"],
                            pars["S"],
                        )
                    )
                )
        activation[name] = rows

    integrated = {}
    for name, pars in states.items():
        integrated[name] = asdict(
            route_integrated(
                rain_rate=30.0,
                duration_h=0.5,
                k_matrix=pars["K"],
                sorptivity=pars["S"],
            )
        )

    output = {
        "schema": "swap5.f_macro_alt09_10.dynamic_activation.v1",
        "status": "RESEARCH_ONLY",
        "sigma_B": SIGMA_B,
        "b50_law": "K_matrix + S_matrix/(2*sqrt(event_age))",
        "states": states,
        "activation_matrix": activation,
        "integrated_rfm1b_case": integrated,
        "key_properties": {
            "no_characteristic_time_parameter": True,
            "one_sigma_B_for_all_cases": True,
            "source_duration_enters_through_event_age": True,
            "matrix_state_enters_through_K_and_S": True,
        },
        "qualification_boundary": (
            "K and S are illustrative state inputs. Full closure requires binding "
            "them to accepted SWAP hydraulic/sorptivity functions and testing against "
            "the exact reference route."
        ),
    }
    print(json.dumps(output, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
