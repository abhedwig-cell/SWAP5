from __future__ import annotations

import itertools
import json
import math
import sys
from pathlib import Path

import mpmath as mp

CONTRACT = "F-FWC01_GATE_B2E_R3_BOUNDED_GA_SCALAR_ROOT_PRECOMMIT.json"
K_VALUES = (0.01, 0.1, 1.0, 10.0, 100.0)
DT_VALUES = (1.0e-5, 1.0e-4, 1.0e-3, 1.0e-2)
PSI_VALUES = (1.0, 10.0, 100.0, 1000.0)
DTHETA_VALUES = (0.001, 0.01, 0.05, 0.2)
MAX_BRACKET_EXPANSIONS = 64
BISECTION_ITERATIONS = 80
ORACLE_ITERATIONS = 240
DEPTH_ERROR_TOL_CM = 1.0e-9
MAX_RESIDUAL_EVALS = 145


def validate(K: float, dt: float, psi: float, dtheta: float):
    values = (K, dt, psi, dtheta)
    if not all(math.isfinite(x) for x in values):
        raise ValueError("nonfinite_input")
    if any(x <= 0.0 for x in values):
        raise ValueError("nonpositive_input")


def g_float(F: float, K: float, dt: float, psi: float, dtheta: float) -> float:
    A = psi * dtheta
    return F - A * math.log1p(F / A) - K * dt


def candidate_root(K: float, dt: float, psi: float, dtheta: float):
    validate(K, dt, psi, dtheta)
    A = psi * dtheta
    lo = 0.0
    hi = max(K * dt, A)
    evals = 0
    expansions = 0
    ghi = g_float(hi, K, dt, psi, dtheta); evals += 1
    while ghi <= 0.0:
        expansions += 1
        if expansions > MAX_BRACKET_EXPANSIONS:
            raise RuntimeError("bracket_expansion_bound_exceeded")
        hi *= 2.0
        if not math.isfinite(hi):
            raise RuntimeError("nonfinite_bracket")
        ghi = g_float(hi, K, dt, psi, dtheta); evals += 1
    for _ in range(BISECTION_ITERATIONS):
        mid = 0.5 * (lo + hi)
        gm = g_float(mid, K, dt, psi, dtheta); evals += 1
        if gm <= 0.0:
            lo = mid
        else:
            hi = mid
    F = 0.5 * (lo + hi)
    residual = g_float(F, K, dt, psi, dtheta); evals += 1
    return {
        "F_cm": F,
        "Z_cm": F / dtheta,
        "residual_cm": residual,
        "bracket_expansions": expansions,
        "residual_evaluations": evals,
        "final_bracket_width_F_cm": hi - lo,
    }


def oracle_root(K: float, dt: float, psi: float, dtheta: float):
    validate(K, dt, psi, dtheta)
    mp.mp.dps = 80
    Km = mp.mpf(str(K)); dtm = mp.mpf(str(dt)); psim = mp.mpf(str(psi)); dm = mp.mpf(str(dtheta))
    A = psim * dm
    def g(F):
        return F - A * mp.log(1 + F / A) - Km * dtm
    lo = mp.mpf('0')
    hi = max(Km * dtm, A)
    expansions = 0
    while g(hi) <= 0:
        expansions += 1
        if expansions > MAX_BRACKET_EXPANSIONS:
            raise RuntimeError("oracle_bracket_expansion_bound_exceeded")
        hi *= 2
    for _ in range(ORACLE_ITERATIONS):
        mid = (lo + hi) / 2
        if g(mid) <= 0:
            lo = mid
        else:
            hi = mid
    F = (lo + hi) / 2
    return {
        "F_cm": F,
        "Z_cm": F / dm,
        "residual_cm": g(F),
        "bracket_expansions": expansions,
    }


def invalid_controls():
    cases = [
        (0.0, 1e-3, 10.0, 0.1),
        (-1.0, 1e-3, 10.0, 0.1),
        (1.0, 0.0, 10.0, 0.1),
        (1.0, -1e-3, 10.0, 0.1),
        (1.0, 1e-3, 0.0, 0.1),
        (1.0, 1e-3, -10.0, 0.1),
        (1.0, 1e-3, 10.0, 0.0),
        (1.0, 1e-3, 10.0, -0.1),
    ]
    rows = []
    for c in cases:
        rejected = False
        try:
            candidate_root(*c)
        except ValueError:
            rejected = True
        rows.append({"inputs": c, "rejected": rejected})
    return rows


def main():
    if len(sys.argv) != 2:
        raise SystemExit("usage: fwc01_gate_b2e_r3_bounded_ga_scalar_root.py OUTPUT.json")
    out = Path(sys.argv[1])
    rows = []
    roots_by_group = {}
    max_depth_error = 0.0
    max_evals = 0
    max_expansions = 0
    max_abs_residual = 0.0
    for K, dt, psi, dtheta in itertools.product(K_VALUES, DT_VALUES, PSI_VALUES, DTHETA_VALUES):
        cand = candidate_root(K, dt, psi, dtheta)
        oracle = oracle_root(K, dt, psi, dtheta)
        oracle_z = float(oracle["Z_cm"])
        depth_error = abs(cand["Z_cm"] - oracle_z)
        max_depth_error = max(max_depth_error, depth_error)
        max_evals = max(max_evals, cand["residual_evaluations"])
        max_expansions = max(max_expansions, cand["bracket_expansions"])
        max_abs_residual = max(max_abs_residual, abs(cand["residual_cm"]))
        case_pass = depth_error <= DEPTH_ERROR_TOL_CM and cand["residual_evaluations"] <= MAX_RESIDUAL_EVALS
        rows.append({
            "K_cm_per_day": K,
            "dt_day": dt,
            "psi_cm": psi,
            "delta_theta": dtheta,
            "candidate_Z_cm": cand["Z_cm"],
            "oracle_Z_cm": oracle_z,
            "depth_error_cm": depth_error,
            "candidate_residual_cm": cand["residual_cm"],
            "candidate_bracket_expansions": cand["bracket_expansions"],
            "candidate_residual_evaluations": cand["residual_evaluations"],
            "final_bracket_width_F_cm": cand["final_bracket_width_F_cm"],
            "pass": case_pass,
        })
        roots_by_group.setdefault((K, psi, dtheta), []).append((dt, cand["Z_cm"]))

    dt_groups = []
    dt_failures = 0
    for (K, psi, dtheta), vals in sorted(roots_by_group.items()):
        vals = sorted(vals)
        monotone = all(vals[i + 1][1] > vals[i][1] for i in range(len(vals) - 1))
        dt_failures += int(not monotone)
        dt_groups.append({
            "K_cm_per_day": K,
            "psi_cm": psi,
            "delta_theta": dtheta,
            "dt_and_Z": vals,
            "strictly_increasing_with_dt": monotone,
            "span_cm": vals[-1][1] - vals[0][1],
        })

    invalid = invalid_controls()
    invalid_pass_count = sum(r["rejected"] for r in invalid)
    case_pass_count = sum(r["pass"] for r in rows)
    passed = (
        case_pass_count == len(rows)
        and max_depth_error <= DEPTH_ERROR_TOL_CM
        and max_evals <= MAX_RESIDUAL_EVALS
        and dt_failures == 0
        and invalid_pass_count == len(invalid)
    )
    result = {
        "schema_version": 1,
        "workstream": "F-FWC",
        "work_unit": "F-FWC01",
        "gate": "B2E_R3_BOUNDED_MONOTONE_GREEN_AMPT_SCALAR_ROOT_POLICY",
        "contract": CONTRACT,
        "production_implementation": False,
        "physics_changed_from_R2": False,
        "upstream_R2_failure_preserved": True,
        "candidate_policy": "DOUBLE_BRACKET_PLUS_FIXED_80_BISECTION",
        "oracle": "MPMATH_80_DIGIT_240_BISECTION",
        "case_count": len(rows),
        "case_pass_count": case_pass_count,
        "max_depth_error_vs_high_precision_cm": max_depth_error,
        "max_abs_candidate_equation_residual_cm": max_abs_residual,
        "max_candidate_bracket_expansions": max_expansions,
        "max_candidate_residual_evaluations": max_evals,
        "candidate_residual_evaluation_bound": MAX_RESIDUAL_EVALS,
        "dt_sensitivity_group_count": len(dt_groups),
        "dt_sensitivity_failure_count": dt_failures,
        "invalid_control_count": len(invalid),
        "invalid_control_pass_count": invalid_pass_count,
        "seed_required": False,
        "new_persistent_state_bytes": 0,
        "cache_key_requires_dt": dt_failures == 0,
        "rows": rows,
        "dt_sensitivity_groups": dt_groups,
        "invalid_controls": invalid,
        "pass": passed,
        "decision": (
            "QUALIFIED_BOUNDED_SEED_FREE_GREEN_AMPT_DRY_BIN_SCALAR_ROOT_POLICY_READY_FOR_PHYSICAL_PARAMETER_MAPPING"
            if passed else
            "BOUNDED_GREEN_AMPT_DRY_BIN_SCALAR_ROOT_POLICY_NOT_QUALIFIED_RESEARCH_REQUIRED"
        ),
        "hard_nonclaims": [
            "No M2WC70 code-equivalence claim.",
            "No physical mapping of K, psi or delta-theta to a specific 2015 FWC dry bin.",
            "No rainfall allocation, partial funding, capillary relaxation, runtime or MultiSWAP qualification."
        ],
    }
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps({
        "pass": passed,
        "decision": result["decision"],
        "case_count": len(rows),
        "case_pass_count": case_pass_count,
        "max_depth_error_vs_high_precision_cm": max_depth_error,
        "max_candidate_residual_evaluations": max_evals,
        "max_candidate_bracket_expansions": max_expansions,
        "dt_sensitivity_failure_count": dt_failures,
    }, sort_keys=True), flush=True)
    if not passed:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
