from __future__ import annotations

import math


AREA_M2 = 1.0
H0_M = 8.0
STORAGE = 0.20
PRECIP_M = 0.010
DT_DAY = 1.0
QBOT_M_PER_DAY = 0.0
EXPECTED_DH_M = 0.050
EXPECTED_H1_M = 8.050


def require_close(actual: float, expected: float, name: str, atol: float = 1.0e-13) -> None:
    if not math.isclose(actual, expected, rel_tol=0.0, abs_tol=atol):
        raise AssertionError(f"{name}: {actual:.17g} != {expected:.17g}")


def dummy_swap_predictor(qbot_m_per_day: float) -> tuple[float, float, float, float]:
    """Transparent zero-resistance SWAP substitute.

    qbot is positive into the dummy column. Rain is transferred immediately.
    Returns final head, dH/dqbot [day], coupling u, and q_u [m/day].
    """
    recharge_m_per_day = PRECIP_M / DT_DAY
    h_end_m = H0_M + (recharge_m_per_day + qbot_m_per_day) * DT_DAY / STORAGE
    dh_dqbot_day = DT_DAY / STORAGE
    u = DT_DAY / dh_dqbot_day
    q_u_m_per_day = u * (h_end_m - H0_M) / DT_DAY - qbot_m_per_day
    return h_end_m, dh_dqbot_day, u, q_u_m_per_day


def affine_q_u_m_per_day(
    head_m: float, reference_head_m: float, q_ref_m_per_day: float, u: float
) -> float:
    return q_ref_m_per_day + (u / DT_DAY) * (head_m - reference_head_m)


def main() -> None:
    physical_dh = PRECIP_M / STORAGE
    physical_h1 = H0_M + physical_dh
    require_close(physical_dh, EXPECTED_DH_M, "physical head rise")
    require_close(physical_h1, EXPECTED_H1_M, "physical final head")

    h_ref, dh_dqbot, u, q_u = dummy_swap_predictor(QBOT_M_PER_DAY)
    require_close(h_ref, EXPECTED_H1_M, "dummy predictor head")
    require_close(dh_dqbot, 5.0, "dH/dqbot")
    require_close(u, STORAGE, "coupling storage coefficient u")
    require_close(q_u, PRECIP_M / DT_DAY, "q_u")

    # Current F-GC40/F-GC33 affine response.
    q_at_h0 = affine_q_u_m_per_day(H0_M, h_ref, q_u, u)
    q_at_href = affine_q_u_m_per_day(h_ref, h_ref, q_u, u)
    require_close(q_at_h0, 0.0, "affine q at initial head")
    require_close(q_at_href, PRECIP_M / DT_DAY, "affine q at predictor head")

    coupling_slope_per_day = u / DT_DAY
    modflow_storage_slope_per_day = STORAGE / DT_DAY
    require_close(
        coupling_slope_per_day,
        modflow_storage_slope_per_day,
        "shared-volume storage/coupling slope identity",
    )

    # Algebraic classification only: if the same physical storage is represented
    # both by MODFLOW Sy and by this coupling slope, their head-dependent terms
    # have identical magnitude. The live DSW-01B probe determines the actual
    # assembled sign and numerical consequence in MODFLOW6.
    h_probe = 8.037
    q_affine = affine_q_u_m_per_day(h_probe, h_ref, q_u, u)
    storage_flux = STORAGE * (h_probe - H0_M) / DT_DAY
    require_close(q_affine, storage_flux, "affine/storage identity at probe head")

    # Constant-recharge control remains the independent physical oracle.
    flux_only_h1 = H0_M + (PRECIP_M / DT_DAY) * DT_DAY / STORAGE
    require_close(flux_only_h1, EXPECTED_H1_M, "flux-only storage control")

    print("GC_DSW01_PHYSICAL_SINGLE_STORAGE=PASS")
    print("GC_DSW01_DUMMY_U_EQUALS_STORAGE=PASS")
    print("GC_DSW01_DUMMY_QU_EQUALS_RECHARGE=PASS")
    print("GC_DSW01_AFFINE_ZERO_AT_INITIAL_HEAD=PASS")
    print("GC_DSW01_SHARED_STORAGE_SLOPE_IDENTITY=PASS")
    print("GC_DSW01_ANALYTIC_GATE=PASS")


if __name__ == "__main__":
    main()
