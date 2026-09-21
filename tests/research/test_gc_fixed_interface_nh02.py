from __future__ import annotations

import math


S_S = 0.10
S_M = 0.10
C = 0.20
DT = 1.0
ZP0 = 8.0
HC0 = 8.0
WS = 0.010
WM = 0.0
PREDICTORS = (-0.002, 0.0, 0.003, 0.008)
TOL = 1.0e-12


def close(a: float, b: float, tol: float = TOL) -> None:
    assert math.isclose(a, b, rel_tol=0.0, abs_tol=tol), (a, b)


def predictor_terminal_head(qb_into_top_m_per_day: float) -> float:
    # Predictor bottom flux is positive into the top system.
    zp = ZP0 + (WS + qb_into_top_m_per_day * DT) / S_S
    return zp + qb_into_top_m_per_day / C


def production_response(qb: float) -> tuple[float, float, float]:
    # Exact derivative for this linear oracle. q_u follows production algebra.
    dhc_dqb_day = DT / S_S + 1.0 / C
    u = DT / dhc_dqb_day
    hc_end = predictor_terminal_head(qb)
    q_u = u * (hc_end - HC0) / DT - qb
    return u, q_u, hc_end


def solve_groundwater_from_affine(u: float, q_u: float, href: float) -> float:
    # Production-style groundwater-directed response:
    # q(H) = q_u + (u/dt)*(H-href).
    # For the predictor-specific reference point, q_u is invariant but the
    # reference head entering the affine extension must be the predictor
    # terminal head. The groundwater residual is storage rate minus response.
    slope = u / DT
    numerator = S_M * HC0 / DT + WM / DT + q_u - slope * href
    denominator = S_M / DT - slope
    # This direct representation becomes singular/incorrect in this sign form;
    # the physically equivalent fixed-interface residual uses the eliminated
    # outward transfer below. Keep this helper unused until backend signs are
    # reconciled explicitly.
    return numerator / denominator


def eliminated_transfer(hc: float) -> float:
    beta = C * DT / (S_S + C * DT)
    return beta * (WS + S_S * (ZP0 - hc))


def exact_groundwater_root() -> float:
    beta = C * DT / (S_S + C * DT)
    return (
        S_M * HC0 + WM + beta * WS + beta * S_S * ZP0
    ) / (S_M + beta * S_S)


def test_nh02_predictor_invariance() -> None:
    expected_u = 1.0 / 15.0
    expected_qu = (2.0 / 3.0) * WS / DT
    for qb in PREDICTORS:
        u, qu, _ = production_response(qb)
        close(u, expected_u)
        close(qu, expected_qu)


def test_nh02_exact_eliminated_root_and_corrector_slope() -> None:
    hc = exact_groundwater_root()
    close(hc, 8.04)
    ec = eliminated_transfer(hc)
    close(ec, 0.004)
    zp = ZP0 + (WS - ec) / S_S
    close(zp, 8.06)

    eps = 1.0e-6
    fd = (eliminated_transfer(hc + eps)-eliminated_transfer(hc-eps))/(2*eps)
    u, _, _ = production_response(0.0)
    close(fd, -u, 1.0e-10)
    close(u / DT, 0.06666666666666667)


def test_nh02_complete_mass() -> None:
    hc = exact_groundwater_root()
    ec = eliminated_transfer(hc)
    zp = ZP0 + (WS - ec) / S_S
    ds = S_S * (zp-ZP0)
    dm = S_M * (hc-HC0)
    close(ds, WS-ec)
    close(dm, WM+ec)
    close(ds+dm, WS+WM)


if __name__ == "__main__":
    test_nh02_predictor_invariance()
    test_nh02_exact_eliminated_root_and_corrector_slope()
    test_nh02_complete_mass()
    print("GC_FIXED_INTERFACE_NH02_ANALYTIC_RESPONSE=PASS")
