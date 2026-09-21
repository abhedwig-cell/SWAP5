from __future__ import annotations

import math


S_TOTAL = 0.20
DT_DAY = 1.0
H0_M = 8.0
RAIN_M_PER_DAY = 0.010
Q_LAT_M_PER_DAY = 0.004
EXPECTED_DH_M = (RAIN_M_PER_DAY + Q_LAT_M_PER_DAY) * DT_DAY / S_TOTAL
EXPECTED_H1_M = H0_M + EXPECTED_DH_M


def require_close(a: float, b: float, name: str, atol: float = 1.0e-13) -> None:
    if not math.isclose(a, b, rel_tol=0.0, abs_tol=atol):
        raise AssertionError(f"{name}: {a:.17g} != {b:.17g}")


def physically_consistent_partition(alpha: float) -> float:
    """Solve the same physical control volume with relabeled storage ownership.

    S_swap + S_mf = S_total.  Dummy SWAP contributes rainfall and accounts for
    its owned storage share. MODFLOW owns lateral inflow and its storage share.

    MODFLOW-side balance:
        S_mf*dh = q_api*dt + q_lat*dt
    with
        q_api = rain - S_swap*dh/dt

    which reduces identically to:
        S_total*dh = (rain + q_lat)*dt.
    """
    s_swap = alpha * S_TOTAL
    s_mf = (1.0 - alpha) * S_TOTAL

    # solve analytically after collecting head-dependent terms
    denominator = s_mf + s_swap
    dh = (RAIN_M_PER_DAY + Q_LAT_M_PER_DAY) * DT_DAY / denominator

    q_api = RAIN_M_PER_DAY - s_swap * dh / DT_DAY
    lhs = s_mf * dh
    rhs = (q_api + Q_LAT_M_PER_DAY) * DT_DAY
    require_close(lhs, rhs, f"MODFLOW partition balance alpha={alpha}")
    return H0_M + dh


def deliberately_double_counted() -> float:
    """Both models independently claim the full physical storage."""
    s_swap = S_TOTAL
    s_mf = S_TOTAL
    # Correctly signed shared-storage accounting but duplicated ownership:
    # (s_mf+s_swap) dh = total forcing.
    return H0_M + (RAIN_M_PER_DAY + Q_LAT_M_PER_DAY) * DT_DAY / (s_mf + s_swap)


def main() -> None:
    require_close(EXPECTED_DH_M, 0.07, "physical head rise")
    require_close(EXPECTED_H1_M, 8.07, "physical final head")

    for alpha in (0.0, 0.25, 0.5, 0.75, 1.0):
        h = physically_consistent_partition(alpha)
        require_close(h, EXPECTED_H1_M, f"partition invariance alpha={alpha}")

    doubled = deliberately_double_counted()
    require_close(doubled, 8.035, "double-storage signature")
    if math.isclose(doubled, EXPECTED_H1_M, rel_tol=0.0, abs_tol=1.0e-13):
        raise AssertionError("deliberate double storage was not distinguishable")

    print("GC_DSW02_PHYSICAL_CONTROL_VOLUME=PASS")
    print("GC_DSW02_STORAGE_PARTITION_INVARIANCE=PASS")
    print("GC_DSW02_DOUBLE_STORAGE_SIGNATURE=PASS")
    print("GC_DSW02_ANALYTIC_GATE=PASS")


if __name__ == "__main__":
    main()
