#!/usr/bin/env python3
"""F-MACRO-ALT07A: standalone RFM-1A geometry-reduction harness.

Research-only. Compares:
- a stepped SWAP-like terminating-path endpoint distribution;
- a continuous bounded connectivity survival function.

The forcing and transfer law are identical, so only geometry representation changes.
Standard library only. No GitHub Actions required.
"""

from __future__ import annotations

import json
import math
from dataclasses import asdict, dataclass


ENDPOINTS_CM = [85.0, 54.2, 35.6, 26.9, 25.0]
Z_AH_CM = 25.0
Z_IC_CM = 85.0
R_AH = 0.2


@dataclass
class ConnectivityFit:
    shape_a: float
    shape_b: float
    rms_survival_error: float
    max_survival_error: float


@dataclass
class RouteSummary:
    source: float
    deposited: float
    bottom: float
    residual_storage: float
    mean_termination_depth_cm: float
    mass_residual: float


def stepped_survival(depth_cm: float) -> float:
    return sum(d >= depth_cm for d in ENDPOINTS_CM) / len(ENDPOINTS_CM)


def bounded_connectivity(depth_cm: float, shape_a: float, shape_b: float) -> float:
    """Ah atom plus bounded Kumaraswamy survival on [Z_AH, Z_IC].

    R_AH ends exactly at the Ah depth.
    The remaining fraction terminates continuously before/equal to Z_IC.
    """
    if depth_cm <= Z_AH_CM:
        return 1.0
    if depth_cm >= Z_IC_CM:
        return 0.0

    x = (depth_cm - Z_AH_CM) / (Z_IC_CM - Z_AH_CM)
    return (1.0 - R_AH) * ((1.0 - x**shape_a) ** shape_b)


def fit_connectivity() -> ConnectivityFit:
    depths = [
        Z_AH_CM + (Z_IC_CM - Z_AH_CM) * i / 240.0
        for i in range(1, 240)
    ]

    best = None
    for ia in range(5, 201, 2):
        a = ia / 100.0
        for ib in range(5, 301, 2):
            b = ib / 100.0
            errors = [
                bounded_connectivity(z, a, b) - stepped_survival(z)
                for z in depths
            ]
            mse = sum(e * e for e in errors) / len(errors)
            candidate = (mse, a, b, max(abs(e) for e in errors))
            if best is None or candidate[0] < best[0]:
                best = candidate

    assert best is not None
    mse, a, b, max_error = best
    return ConnectivityFit(
        shape_a=a,
        shape_b=b,
        rms_survival_error=math.sqrt(mse),
        max_survival_error=max_error,
    )


def route_event(connectivity, *, dt=0.0025, days=1.0, pulse_days=0.1,
                rain_rate=30.0, surface_fast_fraction=0.04, release_rate=80.0):
    """Linear-reservoir fast routing with connectivity-controlled termination.

    This is deliberately not a new SWAP transfer law.
    It is a common transport operator used for both geometry representations.
    """
    dz = 5.0
    depths = [i * dz for i in range(21)]
    conn = [connectivity(z) for z in depths]

    # Enforce survival monotonicity defensively.
    for i in range(1, len(conn)):
        conn[i] = min(conn[i], conn[i - 1])

    storage = [0.0] * len(depths)
    deposition = [0.0] * (len(depths) - 1)
    bottom = 0.0
    source = 0.0
    release_fraction = 1.0 - math.exp(-release_rate * dt)

    n_steps = round(days / dt)
    for n in range(n_steps):
        t = n * dt
        top_rate = rain_rate * surface_fast_fraction if t < pulse_days else 0.0
        incoming = top_rate * dt
        source += incoming
        storage[0] += incoming

        previous = storage[:]
        released = [w * release_fraction for w in previous]
        for i, q in enumerate(released):
            storage[i] -= q

        carry = [0.0] * len(storage)
        for i in range(len(depths) - 1):
            if conn[i] <= 1.0e-14:
                deposition[i] += released[i]
                continue

            survive = max(0.0, min(1.0, conn[i + 1] / conn[i]))
            carry[i + 1] += released[i] * survive
            deposition[i] += released[i] * (1.0 - survive)

        bottom += released[-1]
        for i, q in enumerate(carry):
            storage[i] += q

    mids = [(depths[i] + depths[i + 1]) / 2.0 for i in range(len(deposition))]
    deposited = sum(deposition)
    mean_depth = (
        sum(q * z for q, z in zip(deposition, mids)) / deposited
        if deposited > 0.0 else 0.0
    )
    residual_storage = sum(storage)
    residual = source - (deposited + bottom + residual_storage)

    return RouteSummary(
        source=source,
        deposited=deposited,
        bottom=bottom,
        residual_storage=residual_storage,
        mean_termination_depth_cm=mean_depth,
        mass_residual=residual,
    )


def main() -> None:
    fit = fit_connectivity()

    stepped = route_event(stepped_survival)
    continuous = route_event(
        lambda z: bounded_connectivity(z, fit.shape_a, fit.shape_b)
    )

    output = {
        "schema": "swap5.f_macro_alt07a.geometry_reduction.v1",
        "status": "RESEARCH_ONLY",
        "endpoint_depths_cm": ENDPOINTS_CM,
        "fit": asdict(fit),
        "stepped_route": asdict(stepped),
        "continuous_route": asdict(continuous),
        "mean_termination_depth_difference_cm": (
            continuous.mean_termination_depth_cm
            - stepped.mean_termination_depth_cm
        ),
        "decision_note": (
            "This screen isolates geometry representation only. "
            "It does not establish full SWAP equivalence."
        ),
    }
    print(json.dumps(output, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
