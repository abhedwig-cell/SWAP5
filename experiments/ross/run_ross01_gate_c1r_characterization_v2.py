from __future__ import annotations

import math
import sys

import numpy as np

import run_ross01_gate_c1r_characterization as base

EPS64 = np.finfo(float).eps


def boundary_tol(value: float, boundary: float) -> float:
    return 128.0 * EPS64 * max(1.0, abs(value), abs(boundary))


def endpoint_roundoff_clamp(h: float) -> float:
    if h > base.H_MAX and h - base.H_MAX <= boundary_tol(h, base.H_MAX):
        return base.H_MAX
    if h < base.H_MIN and base.H_MIN - h <= boundary_tol(h, base.H_MIN):
        return base.H_MIN
    return h


def lookup(sa: float, sb: float, table: np.ndarray, n: int):
    s_tol_a = 128.0 * EPS64 * max(1.0, abs(sa), abs(base.c1.core.S_MIN), abs(base.c1.core.S_MAX))
    s_tol_b = 128.0 * EPS64 * max(1.0, abs(sb), abs(base.c1.core.S_MIN), abs(base.c1.core.S_MAX))
    if not (
        base.c1.core.S_MIN - s_tol_a <= sa <= base.c1.core.S_MAX + s_tol_a
        and base.c1.core.S_MIN - s_tol_b <= sb <= base.c1.core.S_MAX + s_tol_b
    ):
        raise ValueError("state outside material S envelope")
    sa = min(base.c1.core.S_MAX, max(base.c1.core.S_MIN, sa))
    sb = min(base.c1.core.S_MAX, max(base.c1.core.S_MIN, sb))
    h_above = endpoint_roundoff_clamp(base.c1.core.h_of_s(sa))
    h_below = endpoint_roundoff_clamp(base.c1.core.h_of_s(sb))
    if not (base.H_MIN <= h_above <= base.H_MAX and base.H_MIN <= h_below <= base.H_MAX):
        raise ValueError("head outside frozen envelope after roundoff check")
    if abs(h_above - h_below) <= 2.0e-13 * max(1.0, abs(h_above), abs(h_below)):
        return base.c1.core.k_of_h(0.5 * (h_above + h_below)), h_above, h_below

    ua = math.log10(-h_above)
    ub = math.log10(-h_below)
    xa = (n - 1) * ua / 4.0
    xb = (n - 1) * ub / 4.0
    coord_tol = 128.0 * EPS64 * max(1.0, float(n - 1))
    if not (-coord_tol <= xa <= n - 1 + coord_tol and -coord_tol <= xb <= n - 1 + coord_tol):
        raise ValueError("lookup would extrapolate")
    xa = min(n - 1.0, max(0.0, xa))
    xb = min(n - 1.0, max(0.0, xb))
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


base.endpoint_roundoff_clamp = endpoint_roundoff_clamp
base.lookup = lookup

if __name__ == "__main__":
    base.main()
