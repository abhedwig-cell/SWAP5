from __future__ import annotations

import json
import math
import sys
from pathlib import Path

import numpy as np

CATALOG = Path("integration/f-ross/F-ROSS01_GATE_C1_MATERIAL_CATALOG.json")
H_ENTRY = -4.0
H105 = 1.05 * H_ENTRY
H_MIN = -10000.0
HEAD_ABS_TOL = 1.0e-9
HEAD_SCALED_TOL = 1.0e-11
STATE_TOL = 1.0e-12
LEGACY_SAT_THETA_TOL = 1.0e-6


def mpar(row: dict) -> float:
    return 1.0 - 1.0 / float(row["n"])


def f_vg(h: float, row: dict) -> float:
    if h >= 0.0:
        return 1.0
    alpha = float(row["alpha_per_cm"])
    n = float(row["n"])
    m = mpar(row)
    return (1.0 + abs(alpha * h) ** n) ** (-m)


def constants(row: dict) -> dict:
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
    ab = a * b
    s105 = (t105 - tr) / dtheta
    s_min = f_vg(H_MIN, row) / s_entry
    return {
        "tr": tr,
        "ts": ts,
        "dtheta": dtheta,
        "alpha": alpha,
        "n": n,
        "m": m,
        "s_entry": s_entry,
        "t105": t105,
        "a": a,
        "ab": ab,
        "s105": s105,
        "s_min": s_min,
    }


def theta_from_h(h: float, row: dict, c: dict) -> float:
    if h >= 0.0:
        return c["ts"]
    if h >= H105:
        return c["ts"] + c["ab"] * h / (1.0 + c["a"] * h)
    return c["tr"] + c["dtheta"] * f_vg(h, row) / c["s_entry"]


def s_from_h(h: float, row: dict, c: dict) -> float:
    return (theta_from_h(h, row, c) - c["tr"]) / c["dtheta"]


def h_from_s_exact(s: float, row: dict, c: dict) -> tuple[float, str]:
    if not math.isfinite(s):
        return math.nan, "invalid"
    if s >= 1.0:
        return 0.0, "endpoint"
    if s < c["s_min"]:
        return math.nan, "outside_low"
    if s >= c["s105"]:
        theta = c["tr"] + c["dtheta"] * s
        y = theta - c["ts"]
        denom = c["ab"] - c["a"] * y
        return y / denom, "wet_rational"
    f = s * c["s_entry"]
    if not (0.0 < f < 1.0):
        return math.nan, "invalid_dry"
    help_term = f ** (-1.0 / c["m"]) - 1.0
    h = -(help_term ** (1.0 / c["n"])) / c["alpha"]
    return h, "dry_vg"


def legacy_prhead_algebraic(theta: float, row: dict, c: dict) -> float | None:
    # Source prhead switches to a geometry-dependent saturated branch when theta is
    # within 1e-6 of theta_s. Return None there because there is no constitutive
    # theta->h inverse to compare against.
    if c["ts"] - theta < LEGACY_SAT_THETA_TOL:
        return None
    if theta - c["tr"] < 1.0e-6:
        return -1.0e12
    help = c["dtheta"] / (theta - c["tr"]) / c["s_entry"]
    help = help ** (1.0 / c["m"])
    help = (help - 1.0) ** (1.0 / c["n"])
    return -abs(help / c["alpha"])


def head_test_grid() -> np.ndarray:
    dry = -np.geomspace(10000.0, 4.2, 1400)
    wet = np.linspace(H105, 0.0, 2001)
    special = np.array([
        H_MIN, -1000.0, -100.0, -40.0, -10.0,
        H105 - 1e-10, H105, H105 + 1e-10,
        H_ENTRY, -2.0, -1.0, -0.1, -0.01, -1e-6, -1e-9, 0.0
    ])
    return np.unique(np.concatenate((dry, wet, special)))


def state_test_grid(c: dict) -> np.ndarray:
    # Resolve both the long dry tail and the narrow wet rational state interval.
    dry = np.linspace(c["s_min"], c["s105"], 1601)
    wet = np.linspace(c["s105"], 1.0, 2001)
    special = np.array([c["s_min"], c["s105"], np.nextafter(c["s105"], 0.0), np.nextafter(c["s105"], 1.0), 1.0])
    return np.unique(np.concatenate((dry, wet, special)))


def percentile(values: list[float], p: float) -> float:
    if not values:
        return math.nan
    return float(np.percentile(np.asarray(values, dtype=float), p))


def run_material(row: dict) -> dict:
    c = constants(row)
    head_errors_abs: list[float] = []
    head_errors_scaled: list[float] = []
    branch_mismatch = 0
    nan_inf = 0

    for h in head_test_grid():
        h = float(h)
        s = s_from_h(h, row, c)
        h2, branch = h_from_s_exact(s, row, c)
        if not math.isfinite(s) or not math.isfinite(h2):
            nan_inf += 1
            continue
        err = abs(h2 - h)
        head_errors_abs.append(err)
        head_errors_scaled.append(err / max(1.0, abs(h)))
        expected = "endpoint" if h >= 0.0 else ("wet_rational" if h >= H105 else "dry_vg")
        if branch != expected:
            # Exact join belongs to wet branch by the forward source comparison head>=h105.
            branch_mismatch += 1

    state_errors: list[float] = []
    inverse_heads: list[float] = []
    inverse_nonmonotone_count = 0
    for s in state_test_grid(c):
        s = float(s)
        h, _ = h_from_s_exact(s, row, c)
        if not math.isfinite(h):
            nan_inf += 1
            continue
        s2 = s_from_h(h, row, c)
        state_errors.append(abs(s2 - s))
        inverse_heads.append(h)
    for a, b in zip(inverse_heads[:-1], inverse_heads[1:]):
        if b < a - 1.0e-11 * max(1.0, abs(a), abs(b)):
            inverse_nonmonotone_count += 1

    legacy_wet_errors: list[float] = []
    legacy_exceed_001 = 0
    legacy_exceed_01 = 0
    legacy_comparable_count = 0
    legacy_geometry_branch_count = 0
    for h in np.linspace(H105, -1.0e-9, 4001):
        h = float(h)
        theta = theta_from_h(h, row, c)
        hp = legacy_prhead_algebraic(theta, row, c)
        if hp is None:
            legacy_geometry_branch_count += 1
            continue
        legacy_comparable_count += 1
        err = abs(hp - h)
        legacy_wet_errors.append(err)
        if err > 0.01:
            legacy_exceed_001 += 1
        if err > 0.1:
            legacy_exceed_01 += 1

    representative = {}
    for h in (-4.0, -2.0, -1.0, -0.1):
        theta = theta_from_h(h, row, c)
        hp = legacy_prhead_algebraic(theta, row, c)
        representative[str(h)] = {
            "theta": theta,
            "exact_head_cm": h,
            "legacy_prhead_cm": hp,
            "legacy_abs_error_cm": None if hp is None else abs(hp - h),
            "legacy_branch": "geometry_dependent_saturated" if hp is None else "normalized_dry_VG_inverse"
        }

    max_head_abs = max(head_errors_abs) if head_errors_abs else math.inf
    max_head_scaled = max(head_errors_scaled) if head_errors_scaled else math.inf
    max_state_err = max(state_errors) if state_errors else math.inf

    checks = {
        "max_head_roundtrip_abs": max_head_abs <= HEAD_ABS_TOL,
        "max_head_roundtrip_scaled": max_head_scaled <= HEAD_SCALED_TOL,
        "max_state_roundtrip": max_state_err <= STATE_TOL,
        "branch_selection": branch_mismatch == 0,
        "inverse_monotone": inverse_nonmonotone_count == 0,
        "nan_or_inf": nan_inf == 0,
        "runtime_iterations_zero": True,
    }

    return {
        "material": row["sfu"],
        "pass": all(checks.values()),
        "checks": checks,
        "state_geometry": {
            "s_min_at_h_minus10000": c["s_min"],
            "s105": c["s105"],
            "wet_rational_state_width": 1.0 - c["s105"],
        },
        "roundtrip": {
            "max_head_abs_error_cm": max_head_abs,
            "max_head_scaled_error": max_head_scaled,
            "max_state_normalized_error": max_state_err,
            "branch_mismatch_count": branch_mismatch,
            "inverse_nonmonotone_count": inverse_nonmonotone_count,
            "nan_or_inf_count": nan_inf,
            "runtime_iterations": 0,
        },
        "legacy_prhead_diagnostic": {
            "comparable_wet_probe_count": legacy_comparable_count,
            "geometry_dependent_saturated_probe_count": legacy_geometry_branch_count,
            "max_abs_error_cm": max(legacy_wet_errors) if legacy_wet_errors else math.nan,
            "p99_abs_error_cm": percentile(legacy_wet_errors, 99.0),
            "count_error_gt_0_01_cm": legacy_exceed_001,
            "count_error_gt_0_1_cm": legacy_exceed_01,
            "representative": representative,
        },
    }


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit("usage: run_ross01_gate_c2b_henpr_state_inverse.py OUTPUT.json")
    out = Path(sys.argv[1])
    catalog = json.loads(CATALOG.read_text())
    materials = [run_material(row) for row in catalog["rows"]]
    failed = [m["material"] for m in materials if not m["pass"]]

    aggregate = {
        "max_head_abs_error_cm": max(m["roundtrip"]["max_head_abs_error_cm"] for m in materials),
        "max_head_scaled_error": max(m["roundtrip"]["max_head_scaled_error"] for m in materials),
        "max_state_normalized_error": max(m["roundtrip"]["max_state_normalized_error"] for m in materials),
        "branch_mismatch_count": sum(m["roundtrip"]["branch_mismatch_count"] for m in materials),
        "inverse_nonmonotone_count": sum(m["roundtrip"]["inverse_nonmonotone_count"] for m in materials),
        "nan_or_inf_count": sum(m["roundtrip"]["nan_or_inf_count"] for m in materials),
        "max_legacy_prhead_wet_error_cm": max(m["legacy_prhead_diagnostic"]["max_abs_error_cm"] for m in materials),
        "max_legacy_prhead_p99_wet_error_cm": max(m["legacy_prhead_diagnostic"]["p99_abs_error_cm"] for m in materials),
        "legacy_error_gt_0_01_total": sum(m["legacy_prhead_diagnostic"]["count_error_gt_0_01_cm"] for m in materials),
        "legacy_error_gt_0_1_total": sum(m["legacy_prhead_diagnostic"]["count_error_gt_0_1_cm"] for m in materials),
        "wet_rational_state_width_range": [
            min(m["state_geometry"]["wet_rational_state_width"] for m in materials),
            max(m["state_geometry"]["wet_rational_state_width"] for m in materials),
        ],
    }

    evidence = {
        "schema_version": 1,
        "workstream": "F-ROSS",
        "work_unit": "F-ROSS01",
        "gate": "C2B_HENPR_ANALYTICAL_STATE_TO_HEAD_INVERSE",
        "contract": "F-ROSS01_GATE_C2B_HENPR_STATE_INVERSE_CONTRACT.json",
        "material_count": len(materials),
        "pass_count": len(materials) - len(failed),
        "fail_count": len(failed),
        "failed_materials": failed,
        "aggregate": aggregate,
        "materials": materials,
        "pass": not failed,
        "decision": "C2B_HENPR_ANALYTICAL_STATE_INVERSE_PASS_READY_FOR_STEADY_FACE_REPRESENTATION" if not failed else "C2B_HENPR_ANALYTICAL_STATE_INVERSE_FAIL_CLOSED",
        "legacy_finding": "Legacy SWAP 4.3.1 prhead is not the inverse of watcon on the H_ENPR rational wet branch; the diagnostic magnitude is reported but legacy prhead is not used as the qualification oracle.",
        "scope_guard": "No positive saturated pressure inversion, hysteresis, elasticity, Ross table, transient timestep, groundwater or production qualification."
    }
    out.write_text(json.dumps(evidence, indent=2, sort_keys=True) + "\n")
    print(json.dumps({
        "pass": evidence["pass"],
        "pass_count": evidence["pass_count"],
        "fail_count": evidence["fail_count"],
        "failed_materials": failed,
        "aggregate": aggregate,
        "decision": evidence["decision"],
    }, sort_keys=True), flush=True)
    raise SystemExit(0 if evidence["pass"] else 1)


if __name__ == "__main__":
    main()
