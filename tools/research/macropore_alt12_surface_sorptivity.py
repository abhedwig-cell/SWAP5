#!/usr/bin/env python3
"""F-MACRO-ALT12: source-bound default-MvG surface sorptivity research helper.

Research-only mirror of the documented B1.10 default-MvG theta(h) and K(h)
branches. Computes surface sorptivity from the Parlange integral transformed
from theta-space to h-space:

    S^2 = integral_{h_i}^{0} (theta_s + theta(h) - 2 theta_i) K(h) dh

This intentionally does NOT apply legacy macropore-wall SORPFACPARL.
"""

from __future__ import annotations

import json
import math
from dataclasses import dataclass, asdict


HCRIT = -1.0e-2
HCON_VSMALL = 1.0e-10


@dataclass
class Cof:
    c1: float   # residual theta-like executable row
    c2: float   # saturated theta
    c3: float   # K ceiling / Ksat
    c4: float   # alpha
    c5: float   # conductivity exponent
    c6: float   # n-like
    c7: float   # m-like
    c9: float   # entry/transition head


def derived(c: Cof) -> dict[str, float]:
    c25 = c.c2 - c.c1
    c26 = c.c1 + c25 / (1.0 + abs(c.c4 * HCRIT) ** c.c6) ** c.c7
    c27 = (c.c2 - c26) / (-HCRIT)
    c28 = (1.0 + abs(c.c4 * c.c9) ** c.c6) ** (-c.c7)
    c29 = c.c6 * c.c7 * c.c4
    c30 = c.c6 - 1.0
    c31 = c.c7 + 1.0
    c32 = 1.0 / c.c7

    c41 = c42 = 0.0
    if c.c9 < 0.0:
        h105 = 1.05 * c.c9
        t105 = c.c1 + (c.c2 - c.c1) * (
            (1.0 + abs(c.c4 * c.c9) ** c.c6) ** c.c7
        ) / (
            (1.0 + abs(c.c4 * h105) ** c.c6) ** c.c7
        )
        c105 = (
            (c.c2 - c.c1)
            * c.c4
            * c.c7
            * c.c6
            * abs(c.c4 * h105) ** (c.c6 - 1.0)
            * (1.0 + abs(c.c4 * c.c9) ** c.c6) ** c.c7
            / (1.0 + abs(c.c4 * h105) ** c.c6) ** (c.c7 + 1.0)
        )
        a = (t105 - c.c2 - c105 * h105) / (c105 * h105 * h105)
        b = (t105 * t105 - 2.0 * t105 * c.c2 + c.c2 * c.c2) / (
            t105 - c.c2 - c105 * h105
        )
        c41 = a
        c42 = a * b

    return {
        "c25": c25, "c26": c26, "c27": c27, "c28": c28,
        "c29": c29, "c30": c30, "c31": c31, "c32": c32,
        "c41": c41, "c42": c42,
    }


def theta(c: Cof, h: float, d: dict[str, float]) -> float:
    if h >= 0.0:
        return c.c2

    if c.c9 > HCRIT:
        if h > HCRIT:
            return min(d["c26"] + d["c27"] * (h - HCRIT), c.c2)
        u = abs(c.c4 * h)
        return c.c1 + d["c25"] / (1.0 + u ** c.c6) ** c.c7

    h105 = 1.05 * c.c9
    if h >= h105:
        return c.c2 + d["c42"] * h / (1.0 + d["c41"] * h)

    u = abs(c.c4 * h)
    return c.c1 + d["c25"] / (
        (1.0 + u ** c.c6) ** c.c7 * d["c28"]
    )


def conductivity(c: Cof, h: float, th: float, d: dict[str, float]) -> float:
    if h < -1.0e14:
        return HCON_VSMALL

    if c.c9 > HCRIT:
        se = (th - c.c1) / d["c25"]
        se = min(1.0, max(0.0, se))
        if se > 1.0 - 1.0e-6:
            return c.c3
        a = (1.0 - se ** (1.0 / c.c7)) ** c.c7
        k = c.c3 * se ** c.c5 * (1.0 - a) ** 2
        return min(k, c.c3)

    if h >= c.c9:
        return c.c3

    se = (
        (1.0 + abs(c.c4 * h) ** c.c6) ** (-c.c7)
        / d["c28"]
    )
    a = (1.0 - (se * d["c28"]) ** (1.0 / c.c7)) ** c.c7
    b = (1.0 - d["c28"] ** (1.0 / c.c7)) ** c.c7
    k = c.c3 * se ** c.c5 * ((1.0 - a) / (1.0 - b)) ** 2
    return min(k, c.c3)


def surface_sorptivity(c: Cof, h_initial: float, panels: int = 20000) -> float:
    """Midpoint quadrature in pressure-head space."""
    if h_initial >= 0.0:
        return 0.0
    d = derived(c)
    theta_i = theta(c, h_initial, d)
    dh = (0.0 - h_initial) / panels
    integral = 0.0
    for i in range(panels):
        h = h_initial + (i + 0.5) * dh
        th = theta(c, h, d)
        k = conductivity(c, h, th, d)
        weight = c.c2 + th - 2.0 * theta_i
        integral += max(0.0, weight) * k * dh
    return math.sqrt(max(0.0, integral))


def convergence(c: Cof, h: float) -> dict:
    vals = {
        n: surface_sorptivity(c, h, n)
        for n in (1000, 2000, 5000, 10000, 20000)
    }
    ref = vals[20000]
    rel = {n: abs(v - ref) / max(abs(ref), 1.0e-30) for n, v in vals.items()}
    return {"values": vals, "relative_to_20000": rel}


def main() -> None:
    # Representative default-MvG research profile, not a SWAP calibration.
    c = Cof(
        c1=0.08,
        c2=0.45,
        c3=50.0,
        c4=0.02,
        c5=0.5,
        c6=1.6,
        c7=1.0 - 1.0 / 1.6,
        c9=0.0,
    )

    heads = [-10.0, -50.0, -100.0, -300.0, -1000.0]
    d = derived(c)
    rows = []
    for h in heads:
        th = theta(c, h, d)
        k = conductivity(c, h, th, d)
        s = surface_sorptivity(c, h)
        rows.append({
            "head_cm": h,
            "theta": th,
            "conductivity": k,
            "surface_sorptivity": s,
        })

    output = {
        "schema": "swap5.f_macro_alt12.surface_sorptivity.v1",
        "status": "RESEARCH_ONLY",
        "formula": "S^2=int_h_i^0 (theta_s+theta(h)-2*theta_i)*K(h) dh",
        "wall_correction_applied": False,
        "profile": asdict(c),
        "rows": rows,
        "quadrature_convergence_h_minus_100": convergence(c, -100.0),
        "checks": {
            "nonnegative": all(r["surface_sorptivity"] >= 0.0 for r in rows),
            "drying_increases_sorptivity_in_screen": all(
                rows[i + 1]["surface_sorptivity"] >= rows[i]["surface_sorptivity"]
                for i in range(len(rows) - 1)
            ),
            "drying_decreases_point_conductivity_in_screen": all(
                rows[i + 1]["conductivity"] <= rows[i]["conductivity"]
                for i in range(len(rows) - 1)
            ),
        },
    }
    print(json.dumps(output, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
