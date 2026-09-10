"""Independent frozen SWAP 4.3.1 DIVDRA oracle for F-VQ47.

Restricted scientific domain: one drainage level, positive qdrain > 1e-10,
no special top discharge layer, no separate infiltration distribution.
Equations are reconstructed from frozen SWAP/divdra.f90, not from SWAP5 tests.
"""
from __future__ import annotations
from dataclasses import dataclass
import math

SMALL = 1.0e-10
LEV2COMP_OFFSET = 1.0e-10

@dataclass(frozen=True)
class OracleResult:
    wt_node: int
    bottom_node: int
    wlev: float
    dz_top_sat: float
    discharge_bottom_thickness: float
    fac_aniso: float
    discharge_bottom: float
    kd_drain: float
    nodes: tuple[float, ...]
    raw_partition_sum: float


def lev2comp(depth: float, dz: list[float], bottoms: list[float]) -> tuple[int, float, float]:
    """Frozen Lev2Comp semantics from divdra.f90 lines 400-409."""
    icp = 0
    n = len(dz)
    while depth > bottoms[icp] + LEV2COMP_OFFSET:
        icp += 1
        if icp >= n:
            raise ValueError("legacy Lev2Comp would call swap_error: icplev > numnod")
    dz_below = bottoms[icp] - depth
    dz_above = dz[icp] - dz_below
    return icp + 1, dz_above, dz_below


def distribute_positive_single_level(
    dz: list[float],
    ksat: list[float],
    aniso: list[float],
    drain_spacing: float,
    groundwater_level: float,
    scalar_transfer: float,
) -> OracleResult:
    """Reconstruct legacy paragraphs 1,2,4,5,7,10 for the restricted domain."""
    n = len(dz)
    if not (n and len(ksat) == n and len(aniso) == n):
        raise ValueError("shape")
    if not scalar_transfer > SMALL:
        raise ValueError("outside legacy-admitted active positive domain")
    if any(x <= 0.0 or not math.isfinite(x) for x in dz + ksat + aniso):
        raise ValueError("parameters")
    if drain_spacing <= 0.0 or not math.isfinite(drain_spacing):
        raise ValueError("spacing")
    if not math.isfinite(groundwater_level):
        raise ValueError("gw")

    bottoms: list[float] = []
    acc = 0.0
    for d in dz:
        acc += d
        bottoms.append(acc)

    wlev = -min(groundwater_level, 0.0)
    wt, _dz_unsat, dz_top_sat = lev2comp(wlev, dz, bottoms)
    wi = wt - 1

    khor = [ksat[i] * aniso[i] for i in range(n)]
    kver = list(ksat)

    kd_hor = dz_top_sat * khor[wi]
    kd_ver = dz_top_sat / kver[wi]
    saturated_depth = dz_top_sat
    for i in range(wi + 1, n):
        kd_hor += dz[i] * khor[i]
        kd_ver += dz[i] / kver[i]
        saturated_depth += dz[i]

    khor_avg = kd_hor / saturated_depth
    kver_avg = saturated_depth / kd_ver
    fac_aniso = math.sqrt(kver_avg / khor_avg)

    dmax = 0.25 * drain_spacing * fac_aniso + wlev
    dmax = min(dmax, saturated_depth + wlev)

    discharge_bottom = bottoms[-1]
    bottom = n
    bottom_thickness = dz[-1]
    kd_drain = kd_hor

    if discharge_bottom > dmax:
        discharge_bottom = dmax
        i = wi
        depth_accum = dz_top_sat
        kd_drain = dz_top_sat * khor[wi]
        discharge_depth = discharge_bottom - wlev
        while discharge_depth > depth_accum:
            i += 1
            if i >= n:
                raise AssertionError("oracle traversed below profile")
            depth_accum += dz[i]
            kd_drain += dz[i] * khor[i]
        kd_drain -= (depth_accum - discharge_depth) * khor[i]
        bottom_thickness = dz[i] - (depth_accum - discharge_depth)
        bottom = i + 1

    q = [0.0] * n
    bi = bottom - 1
    if wt == bottom:
        q[wi] = scalar_transfer
    else:
        q[wi] = scalar_transfer * dz_top_sat * khor[wi] / kd_drain
        for i in range(wi + 1, bi):
            q[i] = scalar_transfer * dz[i] * khor[i] / kd_drain
        q[bi] = scalar_transfer * bottom_thickness * khor[bi] / kd_drain

    raw_sum = sum(q[:bottom])
    return OracleResult(
        wt_node=wt,
        bottom_node=bottom,
        wlev=wlev,
        dz_top_sat=dz_top_sat,
        discharge_bottom_thickness=bottom_thickness,
        fac_aniso=fac_aniso,
        discharge_bottom=discharge_bottom,
        kd_drain=kd_drain,
        nodes=tuple(q),
        raw_partition_sum=raw_sum,
    )
