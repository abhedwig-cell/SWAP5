#!/usr/bin/env python3
"""F-MACRO-ALT23: dynamic activation-weighted connectivity router.

Research-only. Standard library only.

Combines:
- RFM-1B dynamic source activation;
- fixed structural IC connectivity;
- ALT22 quantile recruitment;
- separate MB deep pathway;
- dynamic endpoint reservoirs;
- conservative tracer identical to water partition.

No event-specific geometry parameters.
"""

from __future__ import annotations

import json
import math


SIGMA_B = 0.65
K_SURFACE = 0.396
S_SURFACE = 13.34

MB_FRACTION = 0.25
Z_AH = 25.0
Z_IC = 85.0
R_AH = 0.2
SHAPE_A = 0.31
SHAPE_B = 0.55


def cdf(x: float) -> float:
    return 0.5 * (1.0 + math.erf(x / math.sqrt(2.0)))


def preferential_rate(rain_rate: float, b50: float) -> float:
    mu = math.log(b50)
    lr = math.log(rain_rate)
    z1 = (lr - mu - SIGMA_B * SIGMA_B) / SIGMA_B
    z2 = (lr - mu) / SIGMA_B
    matrix = (
        math.exp(mu + 0.5 * SIGMA_B * SIGMA_B) * cdf(z1)
        + rain_rate * (1.0 - cdf(z2))
    )
    matrix = max(0.0, min(rain_rate, matrix))
    return rain_rate - matrix


def c_struct(depth_cm: float) -> float:
    if depth_cm <= Z_AH:
        return 1.0
    if depth_cm >= Z_IC:
        return 0.0
    x = (depth_cm - Z_AH) / (Z_IC - Z_AH)
    return (1.0 - R_AH) * ((1.0 - x ** SHAPE_A) ** SHAPE_B)


def active_survival_abs(depth_cm: float, activation: float) -> float:
    return max(0.0, activation - (1.0 - c_struct(depth_cm)))


def endpoint_weights(activation: float, dz_cm: int = 5) -> list[tuple[int, float]]:
    depths = list(range(dz_cm, int(Z_IC) + 1, dz_cm))
    previous = activation
    raw: list[tuple[int, float]] = []

    for depth in depths:
        survival = active_survival_abs(depth, activation)
        loss = max(0.0, previous - survival)
        raw.append((depth, loss))
        previous = survival

    total = sum(weight for _, weight in raw)
    if total <= 0.0:
        return [(int(Z_AH), 1.0)]

    return [
        (depth, weight / total)
        for depth, weight in raw
        if weight > 0.0
    ]


def simulate_case(
    intensity_mm_h: float,
    total_mm: float = 40.0,
    second_event: bool = False,
    dt_h: float = 0.002,
    total_time_h: float = 10.0,
    velocity_cm_h: float = 100.0,
) -> dict:

    endpoints = list(range(5, int(Z_IC) + 1, 5))
    water_store = {z: 0.0 for z in endpoints}
    tracer_store = {z: 0.0 for z in endpoints}

    mb_water = 0.0
    mb_tracer = 0.0

    source = tracer_source = 0.0
    deposition = tracer_deposition = 0.0
    bottom = tracer_bottom = 0.0

    duration = total_mm / intensity_mm_h
    events = [(0.0, duration, intensity_mm_h)]

    if second_event:
        half_amount = total_mm / 2.0
        half_duration = half_amount / intensity_mm_h
        events = [
            (0.0, half_duration, intensity_mm_h),
            (1.0, half_duration, intensity_mm_h),
        ]

    release_rate_by_depth = {
        depth: velocity_cm_h / depth
        for depth in endpoints
    }
    mb_release_rate = velocity_cm_h / 100.0

    max_active_depth = 0.0
    activation_weighted_depth_num = 0.0
    activation_weighted_depth_den = 0.0

    for step in range(round(total_time_h / dt_h)):
        t = step * dt_h

        for start, event_duration, rain_rate in events:
            if start <= t < start + event_duration:
                event_age = t - start + 0.5 * dt_h
                b50 = (
                    K_SURFACE
                    + S_SURFACE / (2.0 * math.sqrt(event_age))
                )
                pref_rate = preferential_rate(rain_rate, b50)
                incoming = pref_rate * dt_h
                activation = pref_rate / rain_rate

                source += incoming
                tracer_source += incoming

                mb_incoming = incoming * MB_FRACTION
                mb_water += mb_incoming
                mb_tracer += mb_incoming

                ic_incoming = incoming * (1.0 - MB_FRACTION)
                weights = endpoint_weights(activation)

                for depth, weight in weights:
                    q = ic_incoming * weight
                    water_store[depth] += q
                    tracer_store[depth] += q

                    if q > 0.0:
                        max_active_depth = max(max_active_depth, depth)
                        activation_weighted_depth_num += q * depth
                        activation_weighted_depth_den += q

        release_fraction = 1.0 - math.exp(-mb_release_rate * dt_h)
        q_water = mb_water * release_fraction
        q_tracer = mb_tracer * release_fraction
        mb_water -= q_water
        mb_tracer -= q_tracer
        bottom += q_water
        tracer_bottom += q_tracer

        for depth in endpoints:
            rate = release_rate_by_depth[depth]
            release_fraction = 1.0 - math.exp(-rate * dt_h)

            q_water = water_store[depth] * release_fraction
            q_tracer = tracer_store[depth] * release_fraction

            water_store[depth] -= q_water
            tracer_store[depth] -= q_tracer

            deposition += q_water
            tracer_deposition += q_tracer

    residual_storage = mb_water + sum(water_store.values())
    tracer_residual_storage = mb_tracer + sum(tracer_store.values())

    water_balance_residual = (
        source - deposition - bottom - residual_storage
    )
    tracer_balance_residual = (
        tracer_source
        - tracer_deposition
        - tracer_bottom
        - tracer_residual_storage
    )

    return {
        "intensity_mm_h": intensity_mm_h,
        "total_applied_mm": total_mm,
        "second_event": second_event,
        "preferential_source": source,
        "deposition": deposition,
        "bottom": bottom,
        "residual_storage": residual_storage,
        "water_balance_residual": water_balance_residual,
        "tracer_source": tracer_source,
        "tracer_deposition": tracer_deposition,
        "tracer_bottom": tracer_bottom,
        "tracer_residual_storage": tracer_residual_storage,
        "tracer_balance_residual": tracer_balance_residual,
        "max_active_ic_depth_cm": max_active_depth,
        "mean_input_weighted_ic_endpoint_cm": (
            activation_weighted_depth_num / activation_weighted_depth_den
            if activation_weighted_depth_den > 0.0
            else None
        ),
    }


def main() -> None:
    cases = [
        simulate_case(20.0),
        simulate_case(40.0),
        simulate_case(60.0),
        simulate_case(40.0, second_event=True),
    ]

    print(json.dumps({
        "schema": "swap5.f_macro_alt23.dynamic_weighted_connectivity.v1",
        "status": "RESEARCH_ONLY",
        "structural_parameters_shared_across_cases": True,
        "event_specific_geometry_parameters": 0,
        "cases": cases,
        "decision": (
            "Activation-weighted connectivity is dynamically composable and "
            "conservative in the standalone RFM router."
        ),
    }, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
