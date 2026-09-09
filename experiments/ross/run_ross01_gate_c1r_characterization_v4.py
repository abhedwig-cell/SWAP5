from __future__ import annotations

import math

import numpy as np

import run_ross01_gate_c1r_characterization as base

LOG10 = math.log(10.0)


def state_to_u(s: float) -> float:
    s_min = base.c1.core.S_MIN
    s_max = base.c1.core.S_MAX
    if s < s_min or s > s_max:
        raise ValueError("state outside exact material S domain")
    if s == s_max:
        return 0.0
    if s == s_min:
        return 4.0
    z = -math.log(s) / base.c1.core.MPAR
    u = (
        math.log(math.expm1(z)) / base.c1.core.NPAR
        - math.log(base.c1.core.ALPHA)
    ) / LOG10
    if not (0.0 <= u <= 4.0 and math.isfinite(u)):
        raise ValueError("qualified S-to-u mapping returned invalid coordinate")
    return u


def u_to_head(u: float) -> float:
    if u == 0.0:
        return base.H_MAX
    if u == 4.0:
        return base.H_MIN
    h = -(10.0 ** u)
    if not (base.H_MIN <= h <= base.H_MAX):
        raise ValueError("u-to-head reconstruction outside frozen head envelope")
    return h


def state_to_head(s: float) -> tuple[float, float]:
    u = state_to_u(s)
    return u, u_to_head(u)


def lookup(sa: float, sb: float, table: np.ndarray, n: int):
    ua, h_above = state_to_head(sa)
    ub, h_below = state_to_head(sb)

    if abs(h_above - h_below) <= 2.0e-13 * max(1.0, abs(h_above), abs(h_below)):
        return base.c1.core.k_of_h(0.5 * (h_above + h_below)), h_above, h_below

    xa = (n - 1) * ua / 4.0
    xb = (n - 1) * ub / 4.0
    if not (0.0 <= xa <= n - 1 and 0.0 <= xb <= n - 1):
        raise ValueError("qualified coordinate would extrapolate table")

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


def safe_reference(task):
    idx, sa, sb = task
    try:
        _, h_above = state_to_head(sa)
        _, h_below = state_to_head(sb)
        return idx, base.c1.core.steady_q(h_above, h_below), None
    except Exception as exc:
        return idx, None, repr(exc)


base.lookup = lookup
base._safe_ref = safe_reference

if __name__ == "__main__":
    base.main()
