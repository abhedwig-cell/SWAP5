#!/usr/bin/env python3
"""F-MACRO-ALT13: paired direct-activation comparator.

Research-only.
Compares, for identical top state and atmospheric forcing:
- legacy SWAP direct atmospheric macropore input: q_pref = A_mp * P
- RFM-1B unponded activation: dynamic matrix-infiltrability partition

Ponding inflow is deliberately excluded from this comparator because ALT11
keeps that route common to both models.

Standard library only.
"""

from __future__ import annotations

import json
import math


AMP = 0.04
SIGMA_B = 0.65
HCRIT = -1.0e-2


def cdf(x: float) -> float:
    return 0.5 * (1.0 + math.erf(x / math.sqrt(2.0)))


def partition(rain_rate: float, b50: float, sigma_ln: float = SIGMA_B) -> tuple[float, float]:
    if rain_rate <= 0.0:
        return 0.0, 0.0
    mu = math.log(b50)
    lr = math.log(rain_rate)
    z_trunc = (lr - mu - sigma_ln * sigma_ln) / sigma_ln
    z_tail = (lr - mu) / sigma_ln
    truncated_mean = math.exp(mu + 0.5 * sigma_ln * sigma_ln) * cdf(z_trunc)
    matrix = truncated_mean + rain_rate * (1.0 - cdf(z_tail))
    matrix = min(rain_rate, max(0.0, matrix))
    return matrix, rain_rate - matrix


class Mvg:
    def __init__(self):
        self.c1 = 0.08
        self.c2 = 0.45
        self.c3 = 50.0
        self.c4 = 0.02
        self.c5 = 0.5
        self.c6 = 1.6
        self.c7 = 1.0 - 1.0 / 1.6
        self.c9 = 0.0
        self.c25 = self.c2 - self.c1
        self.c26 = self.c1 + self.c25 / (
            1.0 + abs(self.c4 * HCRIT) ** self.c6
        ) ** self.c7
        self.c27 = (self.c2 - self.c26) / (-HCRIT)

    def theta(self, h: float) -> float:
        if h >= 0.0:
            return self.c2
        if h > HCRIT:
            return min(self.c26 + self.c27 * (h - HCRIT), self.c2)
        u = abs(self.c4 * h)
        return self.c1 + self.c25 / (1.0 + u ** self.c6) ** self.c7

    def k(self, h: float) -> float:
        th = self.theta(h)
        se = max(0.0, min(1.0, (th - self.c1) / self.c25))
        if se > 1.0 - 1.0e-6:
            return self.c3
        a = (1.0 - se ** (1.0 / self.c7)) ** self.c7
        return min(self.c3 * se ** self.c5 * (1.0 - a) ** 2, self.c3)

    def surface_sorptivity(self, h_initial: float, panels: int = 10000) -> float:
        if h_initial >= 0.0:
            return 0.0
        theta_i = self.theta(h_initial)
        dh = -h_initial / panels
        integral = 0.0
        for i in range(panels):
            h = h_initial + (i + 0.5) * dh
            th = self.theta(h)
            kk = self.k(h)
            weight = self.c2 + th - 2.0 * theta_i
            integral += max(0.0, weight) * kk * dh
        return math.sqrt(max(0.0, integral))


def rfm_event(h: float, rain_rate: float, duration_h: float, dt_h: float = 0.001) -> dict:
    mvg = Mvg()
    k_surface = mvg.k(h)
    s_surface = mvg.surface_sorptivity(h)

    steps = max(1, round(duration_h / dt_h))
    dt_h = duration_h / steps
    matrix = pref = 0.0
    onset = None

    for n in range(steps):
        tau = (n + 0.5) * dt_h
        b50 = k_surface + s_surface / (2.0 * math.sqrt(tau))
        m, p = partition(rain_rate, b50)
        matrix += m * dt_h
        pref += p * dt_h
        if onset is None and p / rain_rate >= 1.0e-4:
            onset = tau

    total = rain_rate * duration_h
    return {
        "h_cm": h,
        "rain_rate": rain_rate,
        "duration_h": duration_h,
        "k_surface": k_surface,
        "s_surface": s_surface,
        "total_source": total,
        "legacy_direct_pref": AMP * total,
        "legacy_direct_fraction": AMP,
        "rfm_matrix": matrix,
        "rfm_pref": pref,
        "rfm_pref_fraction": pref / total,
        "rfm_minus_legacy_pref": pref - AMP * total,
        "rfm_onset_h": onset,
    }


def crossover_rate(h: float, duration_h: float) -> float:
    """Find R where integrated RFM preferential fraction equals AMP."""
    lo, hi = 0.1, 100.0
    for _ in range(70):
        mid = 0.5 * (lo + hi)
        frac = rfm_event(h, mid, duration_h)["rfm_pref_fraction"]
        if frac < AMP:
            lo = mid
        else:
            hi = mid
    return 0.5 * (lo + hi)


def main() -> None:
    heads = [-10.0, -50.0, -100.0, -300.0, -1000.0]
    rain_rates = [4.0, 8.0, 15.0, 30.0, 60.0]
    durations_h = [0.1, 0.5, 2.0]

    cases = []
    for duration in durations_h:
        for h in heads:
            for rain in rain_rates:
                cases.append(rfm_event(h, rain, duration))

    crossover = {
        str(duration): {
            str(h): crossover_rate(h, duration)
            for h in heads
        }
        for duration in durations_h
    }

    output = {
        "schema": "swap5.f_macro_alt13.direct_activation_comparator.v1",
        "status": "RESEARCH_ONLY",
        "legacy_surface_fraction": AMP,
        "sigma_B": SIGMA_B,
        "ponding_route": "held_common_and_excluded",
        "cases": cases,
        "crossover_rain_rate_where_rfm_equals_legacy_fraction": crossover,
        "interpretation": (
            "Legacy direct activation is source-proportional at fixed A_mp. "
            "RFM-1B is state-, intensity- and duration-dependent. "
            "This is a changed physical hypothesis, not a refactor."
        ),
    }
    print(json.dumps(output, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
