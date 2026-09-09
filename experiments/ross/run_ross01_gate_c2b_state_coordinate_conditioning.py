from __future__ import annotations

import json
import math
import sys
from pathlib import Path

import mpmath as mp
import numpy as np

CATALOG_PATH = Path("integration/f-ross/F-ROSS01_GATE_C1_MATERIAL_CATALOG.json")
H_MIN = -10000.0
H_MAX = -1.0
H_ENTRY = -4.0
H105 = -4.2
U_MIN = 0.0
U_MAX = 4.0
REF_TOL = 2.0e-12
ROUNDTRIP_TOL = 2.0e-12
SOURCE_EQ_TOL = 2.0e-12
NEXTAFTER_COUNT = 2048
UNIFORM_STATE_COUNT = 8193
HEAD_ORIGIN_COUNT = 8193
JOIN_COUNT = 4096
MP_REF_COUNT = 2048
MP_DPS = 80


def constants(row: dict) -> dict:
    tr = float(row["theta_r"])
    ts = float(row["theta_s"])
    dtheta = ts - tr
    alpha = float(row["alpha_per_cm"])
    n = float(row["n"])
    m = 1.0 - 1.0 / n

    def f(h: float) -> float:
        if h >= 0.0:
            return 1.0
        return (1.0 + abs(alpha * h) ** n) ** (-m)

    s_entry = f(H_ENTRY)
    s105 = f(H105) / s_entry
    theta105 = tr + dtheta * s105
    c105 = (
        dtheta
        * alpha
        * m
        * n
        * abs(alpha * H105) ** (n - 1.0)
        * ((1.0 + abs(alpha * H_ENTRY) ** n) ** m)
        / ((1.0 + abs(alpha * H105) ** n) ** (m + 1.0))
    )
    a = (theta105 - ts - c105 * H105) / (c105 * H105**2)
    ab_stable = c105 * (1.0 + a * H105) ** 2
    b_source = (theta105**2 - 2.0 * theta105 * ts + ts**2) / (theta105 - ts - c105 * H105)
    ab_source = a * b_source

    def s_of_h_stable(h: float) -> float:
        if h >= 0.0:
            return 1.0
        if h >= H105:
            return 1.0 + (ab_stable / dtheta) * h / (1.0 + a * h)
        return f(h) / s_entry

    def s_of_h_source(h: float) -> float:
        if h >= 0.0:
            return 1.0
        if h >= H105:
            return 1.0 + (ab_source / dtheta) * h / (1.0 + a * h)
        return f(h) / s_entry

    return {
        "tr": tr,
        "ts": ts,
        "dtheta": dtheta,
        "alpha": alpha,
        "n": n,
        "m": m,
        "s_entry": s_entry,
        "s105": s105,
        "a": a,
        "ab": ab_stable,
        "ab_source": ab_source,
        "s_of_h": s_of_h_stable,
        "s_of_h_source": s_of_h_source,
        "s_min": s_of_h_stable(H_MIN),
        "s_max": s_of_h_stable(H_MAX),
    }


def state_to_u(s: float, c: dict) -> tuple[float, str]:
    if s < c["s_min"] or s > c["s_max"]:
        raise ValueError("state outside exact C2B table domain")
    if s == c["s_max"]:
        return U_MIN, "wet"
    if s == c["s_min"]:
        return U_MAX, "dry"
    if s < c["s105"]:
        f = s * c["s_entry"]
        z = -math.log(f) / c["m"]
        u = (math.log(math.expm1(z)) / c["n"] - math.log(c["alpha"])) / math.log(10.0)
        return u, "dry"
    w = 1.0 - s
    denom = c["ab"] + c["a"] * c["dtheta"] * w
    u = (math.log(c["dtheta"]) + math.log1p(-s) - math.log(denom)) / math.log(10.0)
    return u, "wet"


def state_to_u_mp(s: float, c: dict) -> float:
    mp.mp.dps = MP_DPS
    sm = mp.mpf(float(s))
    ln10 = mp.log(10)
    if s < c["s105"]:
        se = mp.mpf(float(c["s_entry"]))
        m = mp.mpf(float(c["m"]))
        n = mp.mpf(float(c["n"]))
        alpha = mp.mpf(float(c["alpha"]))
        f = sm * se
        z = -mp.log(f) / m
        return float((mp.log(mp.expm1(z)) / n - mp.log(alpha)) / ln10)
    dtheta = mp.mpf(float(c["dtheta"]))
    ab = mp.mpf(float(c["ab"]))
    a = mp.mpf(float(c["a"]))
    w = 1 - sm
    denom = ab + a * dtheta * w
    return float((mp.log(dtheta) + mp.log(1 - sm) - mp.log(denom)) / ln10)


def inward_nextafter_values(start: float, target: float, count: int):
    values = []
    value = float(start)
    for _ in range(count):
        value = float(np.nextafter(value, target))
        if target > start:
            if value >= target:
                break
        else:
            if value <= target:
                break
        values.append(value)
    return values


def run_material(row: dict) -> dict:
    c = constants(row)
    endpoint_failures = 0
    if state_to_u(c["s_min"], c)[0] != U_MAX:
        endpoint_failures += 1
    if state_to_u(c["s_max"], c)[0] != U_MIN:
        endpoint_failures += 1

    rejection_failures = 0
    for outside in (float(np.nextafter(c["s_min"], -math.inf)), float(np.nextafter(c["s_max"], math.inf))):
        try:
            state_to_u(outside, c)
        except ValueError:
            pass
        else:
            rejection_failures += 1

    states = {float(c["s_min"]), float(c["s_max"]), float(c["s105"])}
    states.update(inward_nextafter_values(c["s_min"], c["s_max"], NEXTAFTER_COUNT))
    states.update(inward_nextafter_values(c["s_max"], c["s_min"], NEXTAFTER_COUNT))
    for j in range(1, UNIFORM_STATE_COUNT - 1):
        f = j / float(UNIFORM_STATE_COUNT - 1)
        s = float((1.0 - f) * c["s_min"] + f * c["s_max"])
        if c["s_min"] < s < c["s_max"]:
            states.add(s)

    # Join-focused representable states on both sides of the exact canonical join.
    value = float(c["s105"])
    for _ in range(JOIN_COUNT):
        value = float(np.nextafter(value, c["s_min"]))
        if value <= c["s_min"]:
            break
        states.add(value)
    value = float(c["s105"])
    for _ in range(JOIN_COUNT):
        value = float(np.nextafter(value, c["s_max"]))
        if value >= c["s_max"]:
            break
        states.add(value)

    ordered = sorted(states)
    coords = []
    nan_inf = 0
    outside_count = 0
    branch_failures = 0
    for s in ordered:
        u, branch = state_to_u(s, c)
        coords.append(u)
        if not math.isfinite(u):
            nan_inf += 1
        if not (U_MIN <= u <= U_MAX):
            outside_count += 1
        expected = "dry" if s < c["s105"] else "wet"
        if branch != expected:
            # Exact dry endpoint is explicitly special-cased but remains a dry state.
            if not (s == c["s_min"] and branch == "dry"):
                branch_failures += 1

    monotonicity_failures = 0
    for left, right in zip(coords, coords[1:]):
        if right > left:
            monotonicity_failures += 1

    max_roundtrip = 0.0
    worst_roundtrip = None
    for j in range(HEAD_ORIGIN_COUNT):
        u0 = U_MAX * j / float(HEAD_ORIGIN_COUNT - 1)
        h = -(10.0 ** u0)
        s = c["s_of_h"](h)
        u, _ = state_to_u(s, c)
        error = abs(u - u0)
        if error > max_roundtrip:
            max_roundtrip = error
            worst_roundtrip = {"u_origin": u0, "h_cm": h, "s_binary64": s, "u_reconstructed": u, "abs_error": error}

    max_mp_error = 0.0
    worst_mp = None
    for j in range(MP_REF_COUNT):
        f = (j + 0.5) / float(MP_REF_COUNT)
        s = float((1.0 - f) * c["s_min"] + f * c["s_max"])
        u, _ = state_to_u(s, c)
        uref = state_to_u_mp(s, c)
        error = abs(u - uref)
        if error > max_mp_error:
            max_mp_error = error
            worst_mp = {"state_fraction": f, "s_binary64": s, "u_binary64": u, "u_reference_80_digit": uref, "abs_error": error}

    max_source_diff = 0.0
    worst_source = None
    source_heads = np.unique(np.concatenate((-np.geomspace(10000.0, 4.2, 1200), np.linspace(H105, H_MAX, 1201))))
    for h in source_heads:
        stable = c["s_of_h"](float(h))
        source = c["s_of_h_source"](float(h))
        error = abs(stable - source)
        if error > max_source_diff:
            max_source_diff = error
            worst_source = {"h_cm": float(h), "S_stabilized": stable, "S_direct_source_arithmetic": source, "abs_difference": error}

    tests = {
        "nan_or_inf_count": nan_inf == 0,
        "coordinate_outside_closed_interval_count": outside_count == 0,
        "monotonicity_violation_count": monotonicity_failures == 0,
        "exact_endpoint_mapping_failures": endpoint_failures == 0,
        "out_of_domain_rejection_failures": rejection_failures == 0,
        "branch_selection_failures": branch_failures == 0,
        "max_abs_u_error_vs_80_digit_reference": max_mp_error <= REF_TOL,
        "max_abs_u_roundtrip_error_from_log_head_origin": max_roundtrip <= ROUNDTRIP_TOL,
        "max_normalized_forward_difference_vs_direct_source_arithmetic": max_source_diff <= SOURCE_EQ_TOL,
    }

    return {
        "material": row["sfu"],
        "s_min": c["s_min"],
        "s_max": c["s_max"],
        "s105": c["s105"],
        "unique_state_probe_count": len(ordered),
        "nan_or_inf_count": nan_inf,
        "coordinate_outside_closed_interval_count": outside_count,
        "monotonicity_violation_count": monotonicity_failures,
        "exact_endpoint_mapping_failures": endpoint_failures,
        "out_of_domain_rejection_failures": rejection_failures,
        "branch_selection_failures": branch_failures,
        "max_abs_u_error_vs_80_digit_reference": max_mp_error,
        "max_abs_u_roundtrip_error_from_log_head_origin": max_roundtrip,
        "max_normalized_forward_difference_vs_direct_source_arithmetic": max_source_diff,
        "worst_high_precision_probe": worst_mp,
        "worst_roundtrip_probe": worst_roundtrip,
        "worst_source_equivalence_probe": worst_source,
        "failed_metrics": [key for key, passed in tests.items() if not passed],
        "pass": all(tests.values()),
    }


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit("usage: run_ross01_gate_c2b_state_coordinate_conditioning.py OUTPUT.json")
    out = Path(sys.argv[1])
    catalog = json.loads(CATALOG_PATH.read_text())
    results = []
    for index, row in enumerate(catalog["rows"], 1):
        result = run_material(row)
        results.append(result)
        print(json.dumps({
            "progress": f"{index}/{len(catalog['rows'])}",
            "material": row["sfu"],
            "pass": result["pass"],
            "max_mp_error": result["max_abs_u_error_vs_80_digit_reference"],
            "max_roundtrip_error": result["max_abs_u_roundtrip_error_from_log_head_origin"],
            "max_source_difference": result["max_normalized_forward_difference_vs_direct_source_arithmetic"],
            "failed_metrics": result["failed_metrics"],
        }), flush=True)

    failed = [r for r in results if not r["pass"]]
    evidence = {
        "schema_version": 1,
        "workstream": "F-ROSS",
        "work_unit": "F-ROSS01",
        "gate": "C2B_DIRECT_STATE_TO_LOG_HEAD_TABLE_COORDINATE",
        "contract": "F-ROSS01_GATE_C2B_STATE_COORDINATE_CONDITIONING_CONTRACT.json",
        "material_count": len(results),
        "pass_count": len(results) - len(failed),
        "fail_count": len(failed),
        "failed_materials": [r["material"] for r in failed],
        "aggregate": {
            "max_abs_u_error_vs_80_digit_reference": max(r["max_abs_u_error_vs_80_digit_reference"] for r in results),
            "max_abs_u_roundtrip_error_from_log_head_origin": max(r["max_abs_u_roundtrip_error_from_log_head_origin"] for r in results),
            "max_normalized_forward_difference_vs_direct_source_arithmetic": max(r["max_normalized_forward_difference_vs_direct_source_arithmetic"] for r in results),
            "nan_or_inf_failures": sum(r["nan_or_inf_count"] for r in results),
            "coordinate_domain_failures": sum(r["coordinate_outside_closed_interval_count"] for r in results),
            "monotonicity_failures": sum(r["monotonicity_violation_count"] for r in results),
            "endpoint_mapping_failures": sum(r["exact_endpoint_mapping_failures"] for r in results),
            "out_of_domain_rejection_failures": sum(r["out_of_domain_rejection_failures"] for r in results),
            "branch_selection_failures": sum(r["branch_selection_failures"] for r in results),
        },
        "thresholds": {"mp_reference": REF_TOL, "head_origin_roundtrip": ROUNDTRIP_TOL, "source_equivalence": SOURCE_EQ_TOL},
        "materials": results,
        "pass": not failed,
        "decision": "C2B_DIRECT_STATE_TO_TABLE_COORDINATE_PASS" if not failed else "C2B_DIRECT_STATE_TO_TABLE_COORDINATE_FAIL_CLOSED",
        "scope_guard": "Numerical state-to-coordinate mapping only for C2B h=[-10000,-1] cm; no face interpolation, timestep or production qualification."
    }
    out.write_text(json.dumps(evidence, indent=2, sort_keys=True) + "\n")
    print(json.dumps({k: v for k, v in evidence.items() if k != "materials"}, indent=2, sort_keys=True))
    raise SystemExit(0 if evidence["pass"] else 1)


if __name__ == "__main__":
    main()
