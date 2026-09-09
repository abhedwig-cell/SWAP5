from __future__ import annotations

import json
import math
import struct
import sys
from pathlib import Path

SQRT_PI = math.sqrt(math.pi)
FINAL_TIME = 100.0
STEP_COUNTS = (32, 64, 128, 256, 512, 1024)
CONST_ABS_TOL = 1.0e-15
FINEST_UNIFORM_REL_TOL = 0.02
FINEST_NONUNIFORM_REL_TOL = 0.03


def float_bytes(value):
    return struct.pack("!d", float(value))


def literal_eq5(times, theta):
    if len(times) != len(theta):
        raise ValueError("times_theta_length_mismatch")
    if len(times) < 2:
        raise ValueError("at_least_one_interval_required")
    for j in range(len(times) - 1):
        if not times[j + 1] > times[j]:
            raise ValueError(("times_not_strictly_increasing", j, times[j], times[j + 1]))
    tn = times[-1]
    terms = []
    for j in range(len(times) - 1):
        midpoint = 0.5 * (times[j] + times[j + 1])
        lag = tn - midpoint
        if not lag > 0.0:
            raise ValueError(("nonpositive_midpoint_lag", j, lag))
        terms.append((theta[j + 1] - theta[j]) / math.sqrt(lag))
    return -math.fsum(terms) / SQRT_PI


def normalized_times(factors):
    scale = FINAL_TIME / math.fsum(factors)
    times = [0.0]
    acc = 0.0
    for factor in factors:
        acc += scale * factor
        times.append(acc)
    times[-1] = FINAL_TIME
    return times


def make_times(n, family):
    if family == "uniform":
        return normalized_times([1.0] * n)
    if family == "alternating":
        return normalized_times([0.5 if i % 2 == 0 else 1.5 for i in range(n)])
    if family == "geometric":
        r = 4.0 ** (1.0 / (n - 1))
        if r > 1.08:
            raise AssertionError(("geometric_ratio_exceeds_precommit", n, r))
        return normalized_times([r ** i for i in range(n)])
    raise ValueError(family)


def theta_value(name, t):
    theta0 = 0.2
    if name == "constant":
        return theta0
    if name == "linear_wetting":
        return theta0 + 0.003 * t
    if name == "linear_drying":
        return theta0 - 0.003 * t
    if name == "quadratic_wetting":
        return theta0 + 0.0002 * t * t
    raise ValueError(name)


def exact_h(name, t):
    if name == "constant":
        return 0.0
    if name == "linear_wetting":
        return -(2.0 * 0.003 / SQRT_PI) * math.sqrt(t)
    if name == "linear_drying":
        return +(2.0 * 0.003 / SQRT_PI) * math.sqrt(t)
    if name == "quadratic_wetting":
        return -(8.0 * 0.0002 / (3.0 * SQRT_PI)) * t ** 1.5
    raise ValueError(name)


def rel_error(value, reference):
    if reference == 0.0:
        return abs(value - reference)
    return abs(value - reference) / abs(reference)


def reversal_theta(t):
    quarters = (25.0, 50.0, 75.0, 100.0)
    slopes = (0.003, -0.004, 0.002, -0.001)
    value = 0.2
    left = 0.0
    for right, slope in zip(quarters, slopes):
        used_right = min(t, right)
        if used_right > left:
            value += slope * (used_right - left)
        if t <= right:
            break
        left = right
    return value


def reversal_characterization(n):
    times = make_times(n, "uniform")
    theta = [reversal_theta(t) for t in times]
    rows = []
    deterministic = True
    finite = True
    for i in range(1, len(times)):
        h1 = literal_eq5(times[: i + 1], theta[: i + 1])
        h2 = literal_eq5(times[: i + 1], theta[: i + 1])
        deterministic = deterministic and float_bytes(h1) == float_bytes(h2)
        finite = finite and math.isfinite(h1)
        rows.append({
            "sample": i,
            "time": times[i],
            "theta": theta[i],
            "H": h1,
            "eq6_c": 0.5 if h1 <= 0.0 else 2.0,
        })
    return {"n_steps": n, "finite_all": finite,
            "bitwise_deterministic_all": deterministic, "rows": rows}


def main():
    if len(sys.argv) != 2:
        raise SystemExit("usage: run_vzaa01_h0_literal_eq5_reference.py EVIDENCE_JSON")
    out = Path(sys.argv[1])
    out.parent.mkdir(parents=True, exist_ok=True)
    evidence = {
        "schema_version": 1,
        "workstream": "F-VZAA",
        "work_unit": "F-VZAA01",
        "gate": "H0_LITERAL_EQ5_REFERENCE",
        "production_implementation": False,
        "operator": "published midpoint full-history Eq5 sum",
        "status": "IN_PROGRESS",
        "stage": "ANALYTIC_HISTORY_REFINEMENT",
    }
    out.write_text(json.dumps(evidence, indent=2, sort_keys=True) + "\n")

    histories = ("constant", "linear_wetting", "linear_drying", "quadratic_wetting")
    families = ("uniform", "alternating", "geometric")
    rows = []
    deterministic = True
    sign_ok = True
    constant_max = 0.0
    errors = {family: {name: [] for name in histories if name != "constant"}
              for family in families}

    for family in families:
        for n in STEP_COUNTS:
            times = make_times(n, family)
            for name in histories:
                theta = [theta_value(name, t) for t in times]
                h1 = literal_eq5(times, theta)
                h2 = literal_eq5(times, theta)
                deterministic = deterministic and float_bytes(h1) == float_bytes(h2)
                exact = exact_h(name, FINAL_TIME)
                err = rel_error(h1, exact)
                if name == "constant":
                    constant_max = max(constant_max, abs(h1))
                else:
                    errors[family][name].append(err)
                if name in ("linear_wetting", "quadratic_wetting"):
                    sign_ok = sign_ok and h1 < 0.0
                elif name == "linear_drying":
                    sign_ok = sign_ok and h1 > 0.0
                rows.append({
                    "grid_family": family,
                    "n_steps": n,
                    "history": name,
                    "H_literal": h1,
                    "H_exact_continuous": exact,
                    "relative_or_absolute_error": err,
                })

    uniform_monotone = {}
    for name, vals in errors["uniform"].items():
        uniform_monotone[name] = all(vals[i + 1] < vals[i] for i in range(len(vals) - 1))

    finest_uniform = max(errors["uniform"][name][-1] for name in errors["uniform"])
    finest_nonuniform = max(
        errors[family][name][-1]
        for family in ("alternating", "geometric")
        for name in errors[family]
    )

    evidence["stage"] = "REVERSAL_CHARACTERIZATION"
    out.write_text(json.dumps(evidence, indent=2, sort_keys=True) + "\n")
    reversal = [reversal_characterization(n) for n in STEP_COUNTS]
    reversal_finite = all(r["finite_all"] for r in reversal)
    reversal_deterministic = all(r["bitwise_deterministic_all"] for r in reversal)

    checks = {
        "constant_abs_H_max_le_1e_15": constant_max <= CONST_ABS_TOL,
        "uniform_refinement_error_strictly_decreases_all_nonconstant": all(uniform_monotone.values()),
        "finest_uniform_relative_error_max_le_0p02": finest_uniform <= FINEST_UNIFORM_REL_TOL,
        "finest_nonuniform_relative_error_max_le_0p03": finest_nonuniform <= FINEST_NONUNIFORM_REL_TOL,
        "wetting_and_drying_signs_match_exact": sign_ok,
        "repeated_calls_bitwise_deterministic": deterministic and reversal_deterministic,
        "reversal_values_finite": reversal_finite,
    }
    passed = all(checks.values())
    evidence.update({
        "grid_definition": {
            "uniform": "dt_i=T/N",
            "alternating": "0.5/1.5 factors normalized to T",
            "geometric": "r_N=4^(1/(N-1)); dt_i proportional to r_N^i; normalized to T",
        },
        "step_counts": list(STEP_COUNTS),
        "final_time": FINAL_TIME,
        "analytic_rows": rows,
        "uniform_refinement_error_strictly_decreases": uniform_monotone,
        "observed": {
            "constant_abs_H_max": constant_max,
            "finest_uniform_relative_error_max": finest_uniform,
            "finest_nonuniform_relative_error_max": finest_nonuniform,
        },
        "reversal_characterization": reversal,
        "checks": checks,
        "pass": passed,
        "status": "COMPLETED",
        "stage": "COMPLETE",
        "decision": ("H0_LITERAL_EQ5_REFERENCE_QUALIFIED_FOR_BOUNDED_HISTORY_COMPARATOR_USE"
                     if passed else
                     "H0_LITERAL_EQ5_REFERENCE_FAILED_DO_NOT_BUILD_BOUNDED_HISTORY_CANDIDATE"),
        "scope_limit": "H0 qualifies only the direct full-history midpoint Eq. 5 reference evaluator and its time-grid behavior. It does not qualify VZAA flux physics, mass conservation repair, groundwater coupling or any bounded-memory approximation.",
    })
    out.write_text(json.dumps(evidence, indent=2, sort_keys=True) + "\n")
    print(json.dumps({
        "observed": evidence["observed"],
        "uniform_refinement_error_strictly_decreases": uniform_monotone,
        "checks": checks,
        "decision": evidence["decision"],
    }, indent=2, sort_keys=True))
    raise SystemExit(0 if passed else 1)


if __name__ == "__main__":
    main()
