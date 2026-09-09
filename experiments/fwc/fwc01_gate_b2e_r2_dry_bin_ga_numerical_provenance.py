from __future__ import annotations

import itertools
import json
import math
import sys
from pathlib import Path

from scipy.optimize import brentq

CONTRACT = "F-FWC01_GATE_B2E_R2_DRY_BIN_GA_NUMERICAL_PROVENANCE_PRECOMMIT.json"
K_VALUES = (0.01, 0.1, 1.0, 10.0, 100.0)
DT_VALUES = (1.0e-5, 1.0e-4, 1.0e-3, 1.0e-2)
PSI_VALUES = (1.0, 10.0, 100.0, 1000.0)
DTHETA_VALUES = (0.001, 0.01, 0.05, 0.2)
Z_SEEDS = (0.0, 0.001, 0.1, 1.0, 10.0)
STOP_DZ_CM = 5.0e-4
MAX_DEPTH_ERROR_CM = 5.0e-4
MAX_ITER = 200000


def validate_inputs(K: float, dt: float, psi: float, dtheta: float):
    vals = (K, dt, psi, dtheta)
    if not all(math.isfinite(v) for v in vals):
        raise ValueError("nonfinite_input")
    if K <= 0.0 or dt <= 0.0 or psi <= 0.0 or dtheta <= 0.0:
        raise ValueError("nonpositive_input")


def next_F(F: float, K: float, dt: float, psi: float, dtheta: float) -> float:
    validate_inputs(K, dt, psi, dtheta)
    if not math.isfinite(F) or F < 0.0:
        raise ValueError("invalid_F")
    A = psi * dtheta
    return K * dt + A * math.log1p(F / A)


def fixed_point(K: float, dt: float, psi: float, dtheta: float, z_seed: float):
    validate_inputs(K, dt, psi, dtheta)
    if not math.isfinite(z_seed) or z_seed < 0.0:
        raise ValueError("invalid_seed")
    F = z_seed * dtheta
    last_dz = math.inf
    for iteration in range(1, MAX_ITER + 1):
        newF = next_F(F, K, dt, psi, dtheta)
        z_old = F / dtheta
        z_new = newF / dtheta
        last_dz = abs(z_new - z_old)
        F = newF
        if last_dz < STOP_DZ_CM:
            return {
                "converged": True,
                "iterations": iteration,
                "F_cm": F,
                "Z_cm": z_new,
                "last_delta_Z_cm": last_dz,
            }
    return {
        "converged": False,
        "iterations": MAX_ITER,
        "F_cm": F,
        "Z_cm": F / dtheta,
        "last_delta_Z_cm": last_dz,
    }


def root_solution(K: float, dt: float, psi: float, dtheta: float):
    validate_inputs(K, dt, psi, dtheta)
    A = psi * dtheta
    def g(F: float) -> float:
        return F - A * math.log1p(F / A) - K * dt
    lo = 0.0
    hi = max(K * dt, A, 1.0e-15)
    while g(hi) <= 0.0:
        hi *= 2.0
        if not math.isfinite(hi) or hi > 1.0e12:
            raise RuntimeError("root_bracket_failure")
    F = brentq(g, lo, hi, xtol=1.0e-14, rtol=1.0e-14, maxiter=1000)
    return {"F_cm": F, "Z_cm": F / dtheta, "residual_cm": g(F)}


def invalid_controls():
    bad = [
        (0.0, 1e-3, 10.0, 0.1),
        (-1.0, 1e-3, 10.0, 0.1),
        (1.0, 0.0, 10.0, 0.1),
        (1.0, -1e-3, 10.0, 0.1),
        (1.0, 1e-3, 0.0, 0.1),
        (1.0, 1e-3, -10.0, 0.1),
        (1.0, 1e-3, 10.0, 0.0),
        (1.0, 1e-3, 10.0, -0.1),
    ]
    passed = 0
    rows = []
    for args in bad:
        rejected = False
        try:
            fixed_point(*args, 0.0)
        except ValueError:
            rejected = True
        passed += int(rejected)
        rows.append({"inputs": args, "rejected": rejected})
    return rows, passed


def main():
    if len(sys.argv) != 2:
        raise SystemExit("usage: fwc01_gate_b2e_r2_dry_bin_ga_numerical_provenance.py OUTPUT.json")
    out = Path(sys.argv[1])
    rows = []
    max_error = 0.0
    max_iterations = 0
    convergence_failures = 0
    error_failures = 0
    seed_spread_max = 0.0

    roots_by_group = {}
    for K, dt, psi, dtheta in itertools.product(K_VALUES, DT_VALUES, PSI_VALUES, DTHETA_VALUES):
        root = root_solution(K, dt, psi, dtheta)
        seed_results = []
        for seed in Z_SEEDS:
            fp = fixed_point(K, dt, psi, dtheta, seed)
            err = abs(fp["Z_cm"] - root["Z_cm"])
            max_error = max(max_error, err)
            max_iterations = max(max_iterations, fp["iterations"])
            convergence_failures += int(not fp["converged"])
            error_failures += int(fp["converged"] and err > MAX_DEPTH_ERROR_CM)
            seed_results.append({
                "seed_Z_cm": seed,
                "converged": fp["converged"],
                "iterations": fp["iterations"],
                "Z_cm": fp["Z_cm"],
                "last_delta_Z_cm": fp["last_delta_Z_cm"],
                "depth_error_vs_root_cm": err,
            })
        zs = [r["Z_cm"] for r in seed_results if r["converged"]]
        spread = (max(zs) - min(zs)) if zs else math.inf
        seed_spread_max = max(seed_spread_max, spread)
        row_pass = all(r["converged"] and r["depth_error_vs_root_cm"] <= MAX_DEPTH_ERROR_CM for r in seed_results)
        rows.append({
            "K_cm_per_day": K,
            "dt_day": dt,
            "psi_cm": psi,
            "delta_theta": dtheta,
            "root_Z_cm": root["Z_cm"],
            "root_residual_cm": root["residual_cm"],
            "seed_spread_cm": spread,
            "seed_results": seed_results,
            "pass": row_pass,
        })
        roots_by_group.setdefault((K, psi, dtheta), []).append((dt, root["Z_cm"]))

    dt_groups = []
    dt_sensitivity_failures = 0
    for (K, psi, dtheta), vals in sorted(roots_by_group.items()):
        vals = sorted(vals)
        strictly_increasing = all(vals[i+1][1] > vals[i][1] for i in range(len(vals)-1))
        dt_sensitivity_failures += int(not strictly_increasing)
        dt_groups.append({
            "K_cm_per_day": K,
            "psi_cm": psi,
            "delta_theta": dtheta,
            "dt_and_root_Z": vals,
            "strictly_increasing_with_dt": strictly_increasing,
            "span_cm": vals[-1][1] - vals[0][1],
        })

    invalid_rows, invalid_passed = invalid_controls()
    case_pass_count = sum(r["pass"] for r in rows)
    passed = (
        case_pass_count == len(rows)
        and convergence_failures == 0
        and error_failures == 0
        and dt_sensitivity_failures == 0
        and invalid_passed == len(invalid_rows)
    )
    result = {
        "schema_version": 1,
        "workstream": "F-FWC",
        "work_unit": "F-FWC01",
        "gate": "B2E_R2_DRY_BIN_GREEN_AMPT_NUMERICAL_PROVENANCE",
        "contract": CONTRACT,
        "production_implementation": False,
        "published_iteration_depth_delta_cm": STOP_DZ_CM,
        "independent_root_depth_error_limit_cm": MAX_DEPTH_ERROR_CM,
        "case_count": len(rows),
        "case_pass_count": case_pass_count,
        "seed_variant_count_per_case": len(Z_SEEDS),
        "convergence_failure_count": convergence_failures,
        "root_error_failure_count": error_failures,
        "max_depth_error_vs_root_cm": max_error,
        "max_seed_solution_spread_cm": seed_spread_max,
        "max_iteration_count": max_iterations,
        "dt_sensitivity_group_count": len(dt_groups),
        "dt_sensitivity_failure_count": dt_sensitivity_failures,
        "invalid_control_count": len(invalid_rows),
        "invalid_control_pass_count": invalid_passed,
        "new_persistent_state_bytes": 0,
        "cache_key_requires_dt": dt_sensitivity_failures == 0,
        "rows": rows,
        "dt_sensitivity_groups": dt_groups,
        "invalid_controls": invalid_rows,
        "pass": passed,
        "decision": (
            "QUALIFIED_PUBLISHED_DRY_BIN_GA_FIXED_POINT_NUMERICAL_REPRESENTATION_AND_DT_PROVENANCE_READY_FOR_PHYSICAL_PARAMETER_MAPPING"
            if passed else
            "PUBLISHED_DRY_BIN_GA_SUCCESSIVE_APPROXIMATION_NOT_NUMERICALLY_QUALIFIED_ON_FROZEN_GRID_CHARACTERIZE_BEFORE_PHYSICAL_MAPPING"
        ),
        "hard_nonclaims": [
            "No M2WC70 code-equivalence claim.",
            "No qualification of which physical K, psi or delta-theta is selected for each 2015 FWC dry bin.",
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
        "root_error_failure_count": error_failures,
        "max_depth_error_vs_root_cm": max_error,
        "max_iteration_count": max_iterations,
        "dt_sensitivity_failure_count": dt_sensitivity_failures,
    }, sort_keys=True), flush=True)
    if not passed:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
