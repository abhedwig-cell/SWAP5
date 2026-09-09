from __future__ import annotations

import math

import numpy as np

import run_ross01_gate_c1r_characterization as base

EPS64 = np.finfo(float).eps


def state_boundary_tol(value: float, boundary: float) -> float:
    return 128.0 * EPS64 * max(1.0, abs(value), abs(boundary))


def normalize_state_to_domain(s: float) -> float:
    s_min = base.c1.core.S_MIN
    s_max = base.c1.core.S_MAX
    if s < s_min:
        if s_min - s <= state_boundary_tol(s, s_min):
            return s_min
        raise ValueError("state below material S envelope")
    if s > s_max:
        if s - s_max <= state_boundary_tol(s, s_max):
            return s_max
        raise ValueError("state above material S envelope")
    return s


def state_to_head(s: float) -> float:
    s = normalize_state_to_domain(s)
    if s == base.c1.core.S_MIN:
        return base.H_MIN
    if s == base.c1.core.S_MAX:
        return base.H_MAX
    h = base.c1.core.h_of_s(s)
    if not (base.H_MIN < h < base.H_MAX):
        raise ValueError("interior state inverse lies outside frozen head envelope")
    return h


def head_to_table_coordinate(h: float, n: int) -> float:
    if h == base.H_MAX:
        return 0.0
    if h == base.H_MIN:
        return float(n - 1)
    u = math.log10(-h)
    x = (n - 1) * u / 4.0
    if not (0.0 < x < n - 1):
        raise ValueError("interior head would extrapolate table coordinate")
    return x


def lookup(sa: float, sb: float, table: np.ndarray, n: int):
    h_above = state_to_head(sa)
    h_below = state_to_head(sb)

    if abs(h_above - h_below) <= 2.0e-13 * max(1.0, abs(h_above), abs(h_below)):
        return base.c1.core.k_of_h(0.5 * (h_above + h_below)), h_above, h_below

    xa = head_to_table_coordinate(h_above, n)
    xb = head_to_table_coordinate(h_below, n)
    ia = min(n - 2, max(0, int(math.floor(xa))))
    ib = min(n - 2, max(0, int(math.floor(xb))))
    fa = xa - ia
    fb = xb - ib

    q00 = float(table[ia, ib])
    q10 = float(table[ia + 1, ib])
    q01 = float(table[ia, ib + 1])
    q11 = float(table[ia + 1, ib + 1])
    log_mobility = (
        (1.0 - fa) * (1.0 - fb) * q00
        + fa * (1.0 - fb) * q10
        + (1.0 - fa) * fb * q01
        + fa * fb * q11
    )
    driving = base.LENGTH_CM + h_above - h_below
    return driving * math.exp(log_mobility), h_above, h_below


base.lookup = lookup

if __name__ == "__main__":
    base.main()
