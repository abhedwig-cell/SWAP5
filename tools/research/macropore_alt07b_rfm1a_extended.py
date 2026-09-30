#!/usr/bin/env python3
"""F-MACRO-ALT07B: extended standalone RFM-1A harness.

Research-only comparison of stepped versus continuous terminating-path geometry
with:
- separate MB fraction;
- two-event forcing;
- compact Philip-style event history;
- explicit mass accounting.

Standard library only. No production SWAP mutation.
"""

from __future__ import annotations

import json
import math
from dataclasses import asdict, dataclass


ENDPOINTS_CM = [85.0, 54.2, 35.6, 26.9, 25.0]
Z_AH_CM = 25.0
Z_IC_CM = 85.0
R_AH = 0.2
FIT_A = 0.31
FIT_B = 0.55


@dataclass
class Summary:
    source: float
    deposition: float
    bottom: float
    exchange: float
    residual_storage: float
    mass_residual: float
    mean_termination_depth_cm: float


def stepped_survival(depth_cm: float) -> float:
    return sum(d >= depth_cm for d in ENDPOINTS_CM) / len(ENDPOINTS_CM)


def continuous_survival(depth_cm: float) -> float:
    if depth_cm <= Z_AH_CM:
        return 1.0
    if depth_cm >= Z_IC_CM:
        return 0.0
    x = (depth_cm - Z_AH_CM) / (Z_IC_CM - Z_AH_CM)
    return (1.0 - R_AH) * ((1.0 - x**FIT_A) ** FIT_B)


def route(connectivity, *, mb_fraction: float, second_event_start: float) -> Summary:
    dt = 0.0025
    days = 1.5
    dz = 5.0
    rain_rate = 30.0
    surface_fast_fraction = 0.04
    release_rate = 60.0
    theta_s = 0.45
    theta0 = 0.22
    sorptivity_scale = 0.004
    pulses = [(0.0, 0.08), (second_event_start, second_event_start + 0.08)]

    depths = [i * dz for i in range(21)]
    n = len(depths)

    # MB survives through the whole column. IC survival follows connectivity.
    survival = [
        mb_fraction + (1.0 - mb_fraction) * connectivity(z)
        for z in depths
    ]
    for i in range(1, n):
        survival[i] = min(survival[i], survival[i - 1])

    storage = [0.0] * n
    theta = [theta0] * n
    event_sorptivity = [0.0] * n
    event_age = [0.0] * n
    event_active = [False] * n
    deposition = [0.0] * (n - 1)

    source = 0.0
    bottom = 0.0
    exchange = 0.0
    release_fraction = 1.0 - math.exp(-release_rate * dt)

    for step in range(round(days / dt)):
        t = step * dt
        rain = rain_rate if any(t0 <= t < t1 for t0, t1 in pulses) else 0.0
        incoming = rain * surface_fast_fraction * dt
        source += incoming
        storage[0] += incoming

        previous = storage[:]
        released = [w * release_fraction for w in previous]
        for i, q in enumerate(released):
            storage[i] -= q

        carry = [0.0] * n
        for i in range(n - 1):
            if survival[i] <= 1.0e-15:
                deposition[i] += released[i]
                continue

            fraction_surviving = max(
                0.0,
                min(1.0, survival[i + 1] / survival[i]),
            )
            carry[i + 1] += released[i] * fraction_surviving
            deposition[i] += released[i] * (1.0 - fraction_surviving)

        bottom += released[-1]
        for i, q in enumerate(carry):
            storage[i] += q

        # Compact two-value Philip-event history: S_event and event age.
        for i in range(n):
            if storage[i] > 1.0e-9 and not event_active[i]:
                event_active[i] = True
                event_age[i] = 0.0
                event_sorptivity[i] = (
                    sorptivity_scale * math.sqrt(max(theta_s - theta[i], 0.0))
                )

            if event_active[i]:
                q = event_sorptivity[i] * (
                    math.sqrt(event_age[i] + dt)
                    - math.sqrt(event_age[i])
                )
                matrix_capacity = max((theta_s - theta[i]) * dz * 0.1, 0.0)
                q = min(q, storage[i], matrix_capacity)

                storage[i] -= q
                theta[i] += q / (dz * 0.1)
                exchange += q
                event_age[i] += dt

                if storage[i] <= 1.0e-9:
                    event_active[i] = False
                    event_sorptivity[i] = 0.0
                    event_age[i] = 0.0

    deposited = sum(deposition)
    residual_storage = sum(storage)
    mass_residual = source - (
        deposited + bottom + exchange + residual_storage
    )

    mids = [(depths[i] + depths[i + 1]) / 2.0 for i in range(n - 1)]
    mean_depth = (
        sum(q * z for q, z in zip(deposition, mids)) / deposited
        if deposited > 0.0 else 0.0
    )

    return Summary(
        source=source,
        deposition=deposited,
        bottom=bottom,
        exchange=exchange,
        residual_storage=residual_storage,
        mass_residual=mass_residual,
        mean_termination_depth_cm=mean_depth,
    )


def compare(second_event_start: float) -> dict:
    stepped = route(
        stepped_survival,
        mb_fraction=0.25,
        second_event_start=second_event_start,
    )
    continuous = route(
        continuous_survival,
        mb_fraction=0.25,
        second_event_start=second_event_start,
    )
    return {
        "second_event_start_day": second_event_start,
        "stepped": asdict(stepped),
        "continuous": asdict(continuous),
        "differences_cont_minus_step": {
            "deposition": continuous.deposition - stepped.deposition,
            "bottom": continuous.bottom - stepped.bottom,
            "exchange": continuous.exchange - stepped.exchange,
            "mean_termination_depth_cm": (
                continuous.mean_termination_depth_cm
                - stepped.mean_termination_depth_cm
            ),
        },
    }


def main() -> None:
    output = {
        "schema": "swap5.f_macro_alt07b.rfm1a_extended.v1",
        "status": "RESEARCH_ONLY",
        "mb_fraction": 0.25,
        "geometry": {
            "stepped_endpoints_cm": ENDPOINTS_CM,
            "continuous_fit": {
                "z_ah_cm": Z_AH_CM,
                "z_ic_cm": Z_IC_CM,
                "r_ah": R_AH,
                "shape_a": FIT_A,
                "shape_b": FIT_B,
            },
        },
        "cases": [
            compare(0.10),
            compare(0.12),
            compare(0.20),
            compare(0.50),
        ],
        "decision_note": (
            "Only terminating-path geometry differs. MB fraction, forcing, "
            "transfer, exchange law and compact Philip history are identical."
        ),
    }
    print(json.dumps(output, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
