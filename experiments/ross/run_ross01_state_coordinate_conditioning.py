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
U_MIN = 0.0
U_MAX = 4.0
REF_TOL = 2.0e-12
ROUNDTRIP_TOL = 2.0e-12
NEXTAFTER_COUNT = 4096
UNIFORM_STATE_COUNT = 8193
HEAD_ORIGIN_COUNT = 8193
MP_REF_COUNT = 1024
MP_DPS = 80


def mpar(row) -> float:
    return 1.0 - 1.0 / float(row["n"])


def s_of_h(h: float, row) -> float:
    if h >= 0.0:
        return 1.0
    alpha = float(row["alpha_per_cm"])
    n = float(row["n"])
    m = mpar(row)
    return (1.0 + abs(alpha * h) ** n) ** (-m)


def material_bounds(row):
    return s_of_h(H_MIN, row), s_of_h(H_MAX, row)


def state_to_u(s: float, row, s_min: float, s_max: float) -> float:
    if s < s_min or s > s_max:
        raise ValueError("state outside exact material S domain")
    if s == s_max:
        return U_MIN
    if s == s_min:
        return U_MAX
    alpha = float(row["alpha_per_cm"])
    n = float(row["n"])
    m = mpar(row)
    z = -math.log(s) / m
    return (math.log(math.expm1(z)) / n - math.log(alpha)) / math.log(10.0)


def state_to_u_mp(s: float, row) -> float:
    mp.mp.dps = MP_DPS
    sm = mp.mpf(float(s))
    alpha = mp.mpf(float(row["alpha_per_cm"]))
    n = mp.mpf(float(row["n"]))
    m = 1 - 1 / n
    z = -mp.log(sm) / m
    u = (mp.log(mp.expm1(z)) / n - mp.log(alpha)) / mp.log(10)
    return float(u)


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


def run_material(row):
    name = row["sfu"]
    s_min, s_max = material_bounds(row)

    exact_endpoint_mapping_failures = 0
    if state_to_u(s_min, row, s_min, s_max) != U_MAX:
        exact_endpoint_mapping_failures += 1
    if state_to_u(s_max, row, s_min, s_max) != U_MIN:
        exact_endpoint_mapping_failures += 1

    out_of_domain_rejection_failures = 0
    for outside in (
        float(np.nextafter(s_min, -math.inf)),
        float(np.nextafter(s_max, math.inf)),
    ):
        try:
            state_to_u(outside, row, s_min, s_max)
        except ValueError:
            pass
        else:
            out_of_domain_rejection_failures += 1

    states = {float(s_min), float(s_max)}
    states.update(inward_nextafter_values(s_min, s_max, NEXTAFTER_COUNT))
    states.update(inward_nextafter_values(s_max, s_min, NEXTAFTER_COUNT))
    for j in range(1, UNIFORM_STATE_COUNT - 1):
        f = j / float(UNIFORM_STATE_COUNT - 1)
        s = float((1.0 - f) * s_min + f * s_max)
        if s_min < s < s_max:
            states.add(s)
    ordered_states = sorted(states)

    nan_or_inf_count = 0
    coordinate_outside_closed_interval_count = 0
    coords = []
    for s in ordered_states:
        u = state_to_u(s, row, s_min, s_max)
        coords.append(u)
        if not math.isfinite(u):
            nan_or_inf_count += 1
        if not (U_MIN <= u <= U_MAX):
            coordinate_outside_closed_interval_count += 1

    monotonicity_violation_count = 0
    for left, right in zip(coords, coords[1:]):
        if right > left:
            monotonicity_violation_count += 1

    max_abs_u_roundtrip_error = 0.0
    worst_roundtrip = None
    for j in range(HEAD_ORIGIN_COUNT):
        u_origin = U_MAX * j / float(HEAD_ORIGIN_COUNT - 1)
        h = -(10.0 ** u_origin)
        s = s_of_h(h, row)
        u = state_to_u(s, row, s_min, s_max)
        error = abs(u - u_origin)
        if error > max_abs_u_roundtrip_error:
            max_abs_u_roundtrip_error = error
            worst_roundtrip = {
                "u_origin": u_origin,
                "s_binary64": s,
                "u_reconstructed": u,
                "abs_error": error,
            }

    max_abs_u_error_vs_mp = 0.0
    worst_mp = None
    for j in range(MP_REF_COUNT):
        f = (j + 0.5) / float(MP_REF_COUNT)
        s = float((1.0 - f) * s_min + f * s_max)
        u = state_to_u(s, row, s_min, s_max)
        u_ref = state_to_u_mp(s, row)
        error = abs(u - u_ref)
        if error > max_abs_u_error_vs_mp:
            max_abs_u_error_vs_mp = error
            worst_mp = {
                "state_fraction": f,
                "s_binary64": s,
                "u_binary64": u,
                "u_reference_80_digit": u_ref,
                "abs_error": error,
            }

    observed = {
        "material": name,
        "s_min": s_min,
        "s_max": s_max,
        "unique_state_probe_count": len(ordered_states),
        "nan_or_inf_count": nan_or_inf_count,
        "coordinate_outside_closed_interval_count": coordinate_outside_closed_interval_count,
        "monotonicity_violation_count": monotonicity_violation_count,
        "exact_endpoint_mapping_failures": exact_endpoint_mapping_failures,
        "out_of_domain_rejection_failures": out_of_domain_rejection_failures,
        "max_abs_u_error_vs_80_digit_reference": max_abs_u_error_vs_mp,
        "max_abs_u_roundtrip_error_from_log_head_origin": max_abs_u_roundtrip_error,
        "worst_high_precision_probe": worst_mp,
        "worst_roundtrip_probe": worst_roundtrip,
    }
    tests = {
        "nan_or_inf_count": nan_or_inf_count == 0,
        "coordinate_outside_closed_interval_count": coordinate_outside_closed_interval_count == 0,
        "monotonicity_violation_count": monotonicity_violation_count == 0,
        "exact_endpoint_mapping_failures": exact_endpoint_mapping_failures == 0,
        "out_of_domain_rejection_failures": out_of_domain_rejection_failures == 0,
        "max_abs_u_error_vs_80_digit_reference": max_abs_u_error_vs_mp <= REF_TOL,
        "max_abs_u_roundtrip_error_from_log_head_origin": max_abs_u_roundtrip_error <= ROUNDTRIP_TOL,
    }
    observed["failed_metrics"] = [key for key, passed in tests.items() if not passed]
    observed["pass"] = all(tests.values())
    return observed


def main():
    if len(sys.argv) != 2:
        raise SystemExit("usage: run_ross01_state_coordinate_conditioning.py OUTPUT.json")
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
            "failed_metrics": result["failed_metrics"],
        }), flush=True)

    failed = [r for r in results if not r["pass"]]
    evidence = {
        "schema_version": 1,
        "workstream": "F-ROSS",
        "work_unit": "F-ROSS01",
        "gate": "STATE_TO_LOG_HEAD_COORDINATE_CONDITIONING",
        "candidate_formula": "u=(log(expm1(-log(S)/m))/n-log(alpha))/log(10)",
        "material_count": len(results),
        "passed_material_count": len(results) - len(failed),
        "failed_material_count": len(failed),
        "failed_materials": [r["material"] for r in failed],
        "thresholds": {
            "max_abs_u_error_vs_80_digit_reference": REF_TOL,
            "max_abs_u_roundtrip_error_from_log_head_origin": ROUNDTRIP_TOL,
        },
        "materials": results,
        "pass": len(failed) == 0,
        "decision": (
            "STATE_TO_LOG_HEAD_COORDINATE_CONDITIONING_QUALIFIED_FOR_C1R"
            if not failed else
            "STATE_TO_LOG_HEAD_COORDINATE_CONDITIONING_FAILED"
        ),
        "production_implementation": False,
        "scope_limit": "Numerical state-to-coordinate mapping only for the frozen 36-material unimodal MvG KSATFIT scope.",
    }
    out.write_text(json.dumps(evidence, indent=2, sort_keys=True) + "\n")
    print(json.dumps({k: v for k, v in evidence.items() if k != "materials"}, indent=2, sort_keys=True))
    raise SystemExit(0 if evidence["pass"] else 1)


if __name__ == "__main__":
    main()
