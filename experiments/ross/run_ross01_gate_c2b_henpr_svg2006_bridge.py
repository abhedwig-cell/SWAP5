from __future__ import annotations

import json
import math
import sys
from pathlib import Path

import numpy as np
from scipy.integrate import quad

CATALOG = Path("integration/f-ross/F-ROSS01_GATE_C1_MATERIAL_CATALOG.json")
H_ENTRY = -4.0
H105 = 1.05 * H_ENTRY
H_R0 = -40.0
H_MIN = -10000.0
THETA_C0_TOL = 1.0e-11
THETA_ENDPOINT_TOL = 1.0e-12
K_C0_TOL = 1.0e-11
K_ENDPOINT_TOL = 1.0e-12
K_UPPER_TOL = 1.0e-12
MONO_TOL = 1.0e-12


def mpar(row: dict) -> float:
    return 1.0 - 1.0 / float(row["n"])


def f_vg(h: float, row: dict) -> float:
    if h >= 0.0:
        return 1.0
    alpha = float(row["alpha_per_cm"])
    n = float(row["n"])
    m = mpar(row)
    return (1.0 + abs(alpha * h) ** n) ** (-m)


def theta_constants(row: dict) -> dict:
    tr = float(row["theta_r"])
    ts = float(row["theta_s"])
    alpha = float(row["alpha_per_cm"])
    n = float(row["n"])
    m = mpar(row)
    dtheta = ts - tr
    s_entry = f_vg(H_ENTRY, row)
    t105 = tr + dtheta * ((1.0 + abs(alpha * H_ENTRY) ** n) ** m) / ((1.0 + abs(alpha * H105) ** n) ** m)
    c105 = (
        dtheta
        * alpha
        * m
        * n
        * abs(alpha * H105) ** (n - 1.0)
        * ((1.0 + abs(alpha * H_ENTRY) ** n) ** m)
        / ((1.0 + abs(alpha * H105) ** n) ** (m + 1.0))
    )
    a = (t105 - ts - c105 * H105) / (c105 * H105**2)
    b = (t105**2 - 2.0 * t105 * ts + ts**2) / (t105 - ts - c105 * H105)
    return {"s_entry": s_entry, "a": a, "ab": a * b}


def theta_dry(h: float, row: dict, c: dict) -> float:
    tr = float(row["theta_r"])
    ts = float(row["theta_s"])
    return tr + (ts - tr) * f_vg(h, row) / c["s_entry"]


def theta_wet(h: float, row: dict, c: dict) -> float:
    ts = float(row["theta_s"])
    return ts + c["ab"] * h / (1.0 + c["a"] * h)


def theta_candidate(h: float, row: dict, c: dict) -> float:
    if h >= 0.0:
        return float(row["theta_s"])
    if h >= H105:
        return theta_wet(h, row, c)
    return theta_dry(h, row, c)


def base_mvg_k(h: float, row: dict) -> float:
    if h >= 0.0:
        return float(row["ksatfit_cm_per_day"])
    s = f_vg(h, row)
    m = mpar(row)
    lam = float(row["lambda"])
    kfit = float(row["ksatfit_cm_per_day"])
    term = (1.0 - s ** (1.0 / m)) ** m
    return kfit * s**lam * (1.0 - term) ** 2


def matrix_k(h: float, row: dict, c: dict) -> float:
    kfit = float(row["ksatfit_cm_per_day"])
    if h >= H_ENTRY:
        return kfit
    m = mpar(row)
    lam = float(row["lambda"])
    f = f_vg(h, row)
    s_entry = c["s_entry"]
    se = f / s_entry
    term1 = (1.0 - f ** (1.0 / m)) ** m
    term2 = (1.0 - s_entry ** (1.0 / m)) ** m
    return kfit * se**lam * ((1.0 - term1) / (1.0 - term2)) ** 2


def r_exact(h: float) -> float:
    if h <= H_R0:
        return 0.0
    if h < H_ENTRY:
        return (h + 40.0) / 144.0
    if h < 0.0:
        return 1.0 + (3.0 / 16.0) * h
    return 1.0


def r_paper_rounded(h: float) -> float:
    if h < H_R0:
        return 0.0
    if h < H_ENTRY:
        return 0.2778 + 0.00694 * h
    if h <= 0.0:
        return 1.0 + 0.1875 * h
    return 1.0


def k_candidate(h: float, row: dict, c: dict) -> float:
    kext = float(row["ksatexm_cm_per_day"])
    if h >= 0.0:
        return kext
    km = matrix_k(h, row, c)
    r = r_exact(h)
    return math.exp((1.0 - r) * math.log(km) + r * math.log(kext))


def k_bridge_at_r(h: float, r: float, row: dict, c: dict) -> float:
    km = matrix_k(h, row, c)
    kext = float(row["ksatexm_cm_per_day"])
    return math.exp((1.0 - r) * math.log(km) + r * math.log(kext))


def legacy_ksatexm_k(h: float, row: dict) -> float:
    kfit = float(row["ksatfit_cm_per_day"])
    kext = float(row["ksatexm_cm_per_day"])
    if h >= 0.0:
        return kext
    s = f_vg(h, row)
    s_thr = f_vg(-2.0, row)
    k_thr = base_mvg_k(-2.0, row)
    if s > s_thr:
        frac = (s - s_thr) / (1.0 - s_thr)
        return frac * kext + (1.0 - frac) * k_thr
    return base_mvg_k(h, row)


def relerr(a: float, b: float, scale: float) -> float:
    return abs(a - b) / max(scale, 1.0e-300)


def derivative(func, h: float, side: str | None = None) -> float:
    step = max(1.0e-7, 1.0e-6 * max(1.0, abs(h)))
    if side == "left":
        return (func(h) - func(h - step)) / step
    if side == "right":
        return (func(h + step) - func(h)) / step
    return (func(h + step) - func(h - step)) / (2.0 * step)


def log_derivative(func, h: float, side: str | None = None) -> float:
    return derivative(lambda x: math.log(func(x)), h, side)


def monotone_non_decreasing(values: list[float], scale: float) -> tuple[bool, float]:
    worst_drop = 0.0
    for a, b in zip(values[:-1], values[1:]):
        worst_drop = min(worst_drop, b - a)
    return worst_drop >= -MONO_TOL * max(scale, 1.0), worst_drop


def characterization_heads() -> np.ndarray:
    dry = -np.geomspace(10000.0, 40.0, 700)
    mid = np.linspace(-40.0, -4.0, 721)
    wet = np.linspace(-4.0, 0.0, 801)
    special = np.array([H_MIN, -40.0, H105, -4.0, -2.0, -1.0, -0.1, -0.01, -1.0e-6, 0.0])
    return np.unique(np.concatenate((dry, mid, wet, special)))


def mfp_integral(row: dict, c: dict, upper: float) -> float:
    if upper <= H_MIN:
        return 0.0
    cuts = [H_MIN]
    for x in (H_R0, H105, H_ENTRY, 0.0):
        if H_MIN < x < upper:
            cuts.append(x)
    cuts.append(upper)
    total = 0.0
    for lo, hi in zip(cuts[:-1], cuts[1:]):
        value, _ = quad(lambda h: k_candidate(h, row, c), lo, hi, epsabs=1.0e-9, epsrel=1.0e-10, limit=160)
        total += value
    return total


def max_wet_log_slope(func, lo: float = -40.0, hi: float = -1.0e-4) -> float:
    # Avoid evaluating exactly on deliberate C0-only derivative joins.
    segments = [(-39.99, -4.01), (-3.99, hi)]
    vals: list[float] = []
    for a, b in segments:
        for h in np.linspace(a, b, 300):
            try:
                v = abs(log_derivative(func, float(h)))
            except (ValueError, OverflowError, ZeroDivisionError):
                continue
            if math.isfinite(v):
                vals.append(v)
    return max(vals) if vals else math.inf


def max_k_over_c(row: dict, c: dict) -> float:
    vals = []
    for h in np.linspace(-39.99, -1.0e-3, 700):
        cap = derivative(lambda x: theta_candidate(x, row, c), float(h))
        k = k_candidate(float(h), row, c)
        if cap > 1.0e-14 and math.isfinite(cap) and math.isfinite(k):
            vals.append(k / cap)
    return max(vals) if vals else math.inf


def run_material(row: dict) -> dict:
    name = row["sfu"]
    kfit = float(row["ksatfit_cm_per_day"])
    kext = float(row["ksatexm_cm_per_day"])
    tr = float(row["theta_r"])
    ts = float(row["theta_s"])
    dtheta = ts - tr
    if not kext > kfit:
        raise ValueError(f"{name}: V1 requires KSATEXM>KSATFIT")
    c = theta_constants(row)

    theta_h105_dry = theta_dry(H105, row, c)
    theta_h105_wet = theta_wet(H105, row, c)
    theta_h0_wet = theta_wet(0.0, row, c)

    km40 = matrix_k(H_R0, row, c)
    k40_left = km40
    k40_right = k_bridge_at_r(H_R0, 0.0, row, c)
    km4_left = matrix_k(H_ENTRY, row, c)
    k4_left = k_bridge_at_r(H_ENTRY, 0.25, row, c)
    k4_right = k_bridge_at_r(H_ENTRY, 0.25, row, c)
    k0_left = k_bridge_at_r(0.0, 1.0, row, c)
    k0_right = kext

    heads = characterization_heads()
    theta_vals = [theta_candidate(float(h), row, c) for h in heads]
    k_vals = [k_candidate(float(h), row, c) for h in heads]

    finite_theta = all(math.isfinite(x) for x in theta_vals)
    finite_k = all(math.isfinite(x) and x > 0.0 for x in k_vals)
    theta_bounds = all((tr - 1.0e-12 * max(1.0, dtheta)) <= x <= (ts + 1.0e-12 * max(1.0, dtheta)) for x in theta_vals)
    theta_mono, theta_worst_drop = monotone_non_decreasing(theta_vals, dtheta)
    k_mono, k_worst_drop = monotone_non_decreasing(k_vals, kext)
    k_upper_ok = max(k_vals) <= kext * (1.0 + K_UPPER_TOL)

    theta_join_metric = relerr(theta_h105_dry, theta_h105_wet, max(dtheta, 1.0e-300))
    theta_h0_metric = relerr(theta_h0_wet, ts, max(dtheta, 1.0e-300))
    k40_metric = relerr(k40_left, k40_right, kext)
    k4_metric = relerr(k4_left, k4_right, kext)
    k0_metric = relerr(k0_left, k0_right, kext)

    mfp_points = [H_MIN, -40.0, H105, -4.0, -2.0, -1.0, 0.0]
    mfp_vals = [mfp_integral(row, c, h) for h in mfp_points]
    mfp_finite = all(math.isfinite(x) for x in mfp_vals)
    mfp_mono, mfp_worst_drop = monotone_non_decreasing(mfp_vals, max(mfp_vals[-1], 1.0))

    join_derivatives = {}
    for h, label in ((-40.0, "minus40"), (-4.0, "minus4"), (0.0, "zero")):
        f = lambda x: k_candidate(x, row, c)
        left = derivative(f, h, "left")
        right = derivative(f, h, "right")
        llog = log_derivative(f, h, "left")
        rlog = log_derivative(f, h, "right")
        join_derivatives[label] = {
            "h_cm": h,
            "dKdh_left": left,
            "dKdh_right": right,
            "dKdh_jump": right - left,
            "dlogKdh_left": llog,
            "dlogKdh_right": rlog,
            "dlogKdh_jump": rlog - llog,
        }

    candidate_slope = max_wet_log_slope(lambda h: k_candidate(h, row, c))
    legacy_slope = max_wet_log_slope(lambda h: legacy_ksatexm_k(h, row))
    henpr_matrix_slope = max_wet_log_slope(lambda h: matrix_k(h, row, c))

    r_grid = np.linspace(-40.0, 0.0, 2001)
    r_diff = max(abs(r_exact(float(h)) - r_paper_rounded(float(h))) for h in r_grid)

    total_mfp = mfp_vals[-1]
    wet_mfp = total_mfp - mfp_integral(row, c, -40.0)
    wet_fraction = wet_mfp / total_mfp if total_mfp > 0.0 else math.nan

    checks = {
        "theta_finite": finite_theta,
        "theta_within_bounds": theta_bounds,
        "theta_monotone": theta_mono,
        "theta_C0_h105": theta_join_metric <= THETA_C0_TOL,
        "theta_endpoint_h0": theta_h0_metric <= THETA_ENDPOINT_TOL,
        "K_positive_finite": finite_k,
        "K_not_above_KSATEXM": k_upper_ok,
        "K_monotone": k_mono,
        "K_C0_minus40": k40_metric <= K_C0_TOL,
        "K_C0_minus4": k4_metric <= K_C0_TOL,
        "K_endpoint_h0": k0_metric <= K_ENDPOINT_TOL,
        "MFP_finite": mfp_finite,
        "MFP_monotone": mfp_mono,
    }

    return {
        "material": name,
        "pass": all(checks.values()),
        "checks": checks,
        "parameters": {
            "H_ENPR_cm": H_ENTRY,
            "ksatfit_cm_per_day": kfit,
            "ksatexm_cm_per_day": kext,
            "ksatexm_over_ksatfit": kext / kfit,
            "s_entry": c["s_entry"],
        },
        "continuity_metrics": {
            "theta_h105_normalized": theta_join_metric,
            "theta_h0_normalized": theta_h0_metric,
            "K_minus40_normalized": k40_metric,
            "K_minus4_normalized": k4_metric,
            "K_h0_normalized": k0_metric,
        },
        "monotonicity_diagnostics": {
            "theta_worst_drop": theta_worst_drop,
            "K_worst_drop_cm_per_day": k_worst_drop,
            "MFP_worst_drop": mfp_worst_drop,
        },
        "MFP": {
            "heads_cm": mfp_points,
            "values": mfp_vals,
            "total_minus10000_to_0": total_mfp,
            "wet_minus40_to_0": wet_mfp,
            "wet_fraction": wet_fraction,
        },
        "stiffness_diagnostics": {
            "candidate_max_abs_dlogKdh_minus40_to_0": candidate_slope,
            "legacy_exact_KSATEXM_max_abs_dlogKdh_minus40_to_0": legacy_slope,
            "H_ENPR_matrix_only_max_abs_dlogKdh_minus40_to_0": henpr_matrix_slope,
            "candidate_over_legacy_slope_ratio": candidate_slope / legacy_slope if legacy_slope > 0.0 else math.nan,
            "max_K_over_C_minus40_to_0": max_k_over_c(row, c),
        },
        "join_derivatives": join_derivatives,
        "endpoint_exact_R_vs_paper_rounded": {
            "max_abs_R_difference_minus40_to_0": r_diff,
            "R_exact_minus40": r_exact(-40.0),
            "R_exact_minus4": r_exact(-4.0),
            "R_exact_zero": r_exact(0.0),
            "R_paper_rounded_minus40": r_paper_rounded(-40.0),
            "R_paper_rounded_minus4_from_second_segment": r_paper_rounded(-4.0),
        },
    }


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit("usage: run_ross01_gate_c2b_henpr_svg2006_bridge.py OUTPUT.json")
    out = Path(sys.argv[1])
    catalog = json.loads(CATALOG.read_text())
    rows = catalog["rows"]
    if len(rows) != 36:
        raise RuntimeError("frozen catalog must contain 36 materials")

    materials = [run_material(row) for row in rows]
    failed = [x["material"] for x in materials if not x["pass"]]
    max_join_theta = max(x["continuity_metrics"]["theta_h105_normalized"] for x in materials)
    max_join_k = max(max(x["continuity_metrics"]["K_minus40_normalized"], x["continuity_metrics"]["K_minus4_normalized"], x["continuity_metrics"]["K_h0_normalized"]) for x in materials)
    max_slope_ratio = max(x["stiffness_diagnostics"]["candidate_over_legacy_slope_ratio"] for x in materials if math.isfinite(x["stiffness_diagnostics"]["candidate_over_legacy_slope_ratio"]))
    min_slope_ratio = min(x["stiffness_diagnostics"]["candidate_over_legacy_slope_ratio"] for x in materials if math.isfinite(x["stiffness_diagnostics"]["candidate_over_legacy_slope_ratio"]))

    evidence = {
        "schema_version": 1,
        "workstream": "F-ROSS",
        "work_unit": "F-ROSS01",
        "gate": "C2B_SWAPP_HENPR_SVG2006_LOGK_BRIDGE_CONSTITUTIVE_CHARACTERIZATION",
        "contract": "F-ROSS01_GATE_C2B_HENPR_SVG2006_BRIDGE_CONTRACT.json",
        "candidate_id": "SWAP5_HENPR_SVG2006_LOGK_BRIDGE_V1",
        "material_count": len(materials),
        "pass_count": len(materials) - len(failed),
        "fail_count": len(failed),
        "failed_materials": failed,
        "aggregate": {
            "max_theta_h105_continuity_metric": max_join_theta,
            "max_K_join_or_endpoint_continuity_metric": max_join_k,
            "candidate_over_legacy_max_log_slope_ratio_range": [min_slope_ratio, max_slope_ratio],
            "nan_or_inf_count": sum(not x["checks"]["theta_finite"] or not x["checks"]["K_positive_finite"] or not x["checks"]["MFP_finite"] for x in materials),
        },
        "materials": materials,
        "pass": not failed,
        "decision": "C2B_V1_CONSTITUTIVE_CHARACTERIZATION_PASS_READY_FOR_SEPARATE_STEADY_FACE_REPRESENTATION_GATE" if not failed else "C2B_V1_CONSTITUTIVE_CHARACTERIZATION_FAIL_CLOSED",
        "science_guard": "A pass establishes mathematical constitutive admissibility only. Existing KSATFIT and LEXP have not been empirically refitted as MMVG K_o and L, so no empirical soil-hydraulic qualification or production claim follows.",
        "scope_guard": "No Ross table, transient FullRichards comparison, saturation crossing, explicit macropore, groundwater or MultiSWAP production qualification."
    }
    out.write_text(json.dumps(evidence, indent=2, sort_keys=True) + "\n")
    print(json.dumps({
        "pass": evidence["pass"],
        "pass_count": evidence["pass_count"],
        "fail_count": evidence["fail_count"],
        "failed_materials": failed,
        "aggregate": evidence["aggregate"],
        "decision": evidence["decision"],
    }, sort_keys=True), flush=True)
    raise SystemExit(0 if evidence["pass"] else 1)


if __name__ == "__main__":
    main()
