from __future__ import annotations

import hashlib
import json
import math
import random
import sys
from pathlib import Path

CONTRACT = "F-FWC01_GATE_B2C_EQ18_INFILTRATION_ODE_PROVENANCE_LIMITS_PRECOMMIT.json"
CASE_COUNT = 256
EPS = 2.220446049250313e-16


def eq18(theta_i: float, theta_d: float, k_i: float, k_d: float, g_eff: float, h_p: float, z: float) -> float:
    dtheta = theta_d - theta_i
    if not (math.isfinite(dtheta) and dtheta > 0.0):
        raise ValueError("NONPOSITIVE_DTHETA")
    if not (math.isfinite(z) and z > 0.0):
        raise ValueError("NONPOSITIVE_Z")
    values = (k_i, k_d, g_eff, h_p)
    if not all(math.isfinite(v) for v in values):
        raise ValueError("NONFINITE_INPUT")
    return (k_d * (g_eff + h_p) / z + k_d - k_i) / dtheta


def green_ampt_rate(dtheta: float, k_d: float, h_c: float, h_p: float, f: float) -> float:
    return k_d * (1.0 + dtheta * (h_c + h_p) / f)


def sample_cases() -> list[dict]:
    seed = int(hashlib.sha256(b"F-FWC01-B2C-EQ18").hexdigest()[:16], 16)
    rng = random.Random(seed)
    rows = []
    for i in range(CASE_COUNT):
        dtheta = 10.0 ** rng.uniform(-4.0, math.log10(0.8))
        theta_i = rng.uniform(0.0, max(0.0, 0.9 - dtheta))
        theta_d = theta_i + dtheta
        k_i = rng.uniform(0.0, 100.0)
        k_inc = rng.uniform(0.0, 500.0)
        k_d = k_i + k_inc
        g_eff = rng.uniform(0.0, 500.0)
        h_p = rng.uniform(0.0, 20.0)
        z = 10.0 ** rng.uniform(-4.0, 6.0)
        v = eq18(theta_i, theta_d, k_i, k_d, g_eff, h_p, z)
        finite = math.isfinite(v)

        gravity_only = eq18(theta_i, theta_d, k_i, k_d, 0.0, 0.0, z)
        gravity_expected = (k_d - k_i) / dtheta
        gravity_res = gravity_only - gravity_expected

        cap_only = eq18(theta_i, theta_d, k_i, k_i, g_eff, h_p, z)
        cap_expected = k_i * (g_eff + h_p) / (z * dtheta)
        cap_res = cap_only - cap_expected

        z_large = 1.0e20
        large = eq18(theta_i, theta_d, k_i, k_d, g_eff, h_p, z_large)
        large_expected = (k_d - k_i) / dtheta
        large_err = abs(large - large_expected)
        large_tol = 128.0 * EPS * max(1.0, abs(large), abs(large_expected)) + abs(k_d * (g_eff + h_p) / (z_large * dtheta))

        # One-bin Green-Ampt identity: F = dtheta*z and K_i=0.
        f = max(1.0e-10, dtheta * z)
        dzdt = eq18(0.0, dtheta, 0.0, k_d, g_eff, h_p, f / dtheta)
        infiltration_from_eq18 = dtheta * dzdt
        ga = green_ampt_rate(dtheta, k_d, g_eff, h_p, f)
        ga_res = infiltration_from_eq18 - ga
        scale = max(1.0, abs(infiltration_from_eq18), abs(ga))
        ga_tol = 128.0 * EPS * scale

        tests = {
            "finite_velocity": finite,
            "gravity_finite_difference_identity": abs(gravity_res) <= 128.0 * EPS * max(1.0, abs(gravity_expected)),
            "pure_capillary_identity": abs(cap_res) <= 128.0 * EPS * max(1.0, abs(cap_expected)),
            "large_depth_limit": large_err <= large_tol,
            "green_ampt_one_bin_identity": abs(ga_res) <= ga_tol,
        }
        rows.append({
            "case": i,
            "tests": tests,
            "pass": all(tests.values()),
            "gravity_identity_residual": gravity_res,
            "pure_capillary_residual": cap_res,
            "large_depth_error": large_err,
            "green_ampt_identity_residual": ga_res,
        })
    return rows


def rejection_checks() -> list[dict]:
    checks = []
    for args, expected in [
        ((0.2, 0.2, 1.0, 2.0, 10.0, 0.0, 1.0), "NONPOSITIVE_DTHETA"),
        ((0.3, 0.2, 1.0, 2.0, 10.0, 0.0, 1.0), "NONPOSITIVE_DTHETA"),
        ((0.1, 0.2, 1.0, 2.0, 10.0, 0.0, 0.0), "NONPOSITIVE_Z"),
        ((0.1, 0.2, 1.0, 2.0, 10.0, 0.0, -1.0), "NONPOSITIVE_Z"),
    ]:
        got = None
        try:
            eq18(*args)
        except ValueError as exc:
            got = str(exc)
        checks.append({"expected": expected, "got": got, "pass": got == expected})
    return checks


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit("usage: fwc01_gate_b2c_eq18_provenance_limits.py OUTPUT.json")
    out = Path(sys.argv[1])
    cases = sample_cases()
    rejects = rejection_checks()
    passed = all(r["pass"] for r in cases) and all(r["pass"] for r in rejects)
    result = {
        "schema_version": 1,
        "workstream": "F-FWC",
        "work_unit": "F-FWC01",
        "gate": "B2C_EQ18_INFILTRATION_ODE_PROVENANCE_AND_LIMITS",
        "contract": CONTRACT,
        "production_implementation": False,
        "implementation_provenance": "PRIMARY_SOURCE_ALGEBRAIC_RECONCILIATION_2008_EQ6_PLUS_2015_EQ17_GRADIENT_AND_STATED_EQ18_DIFFERENCE",
        "reconciled_equation": "dz_j/dt = [K(theta_d)*(G_eff+h_p)/z_j + K(theta_d)-K(theta_i)]/[theta_d-theta_i]",
        "case_count": len(cases),
        "case_pass_count": sum(r["pass"] for r in cases),
        "rejection_checks": rejects,
        "all_rejection_checks_pass": all(r["pass"] for r in rejects),
        "max_abs_gravity_identity_residual": max(abs(r["gravity_identity_residual"]) for r in cases),
        "max_abs_pure_capillary_residual": max(abs(r["pure_capillary_residual"]) for r in cases),
        "max_abs_large_depth_error": max(abs(r["large_depth_error"]) for r in cases),
        "max_abs_green_ampt_identity_residual": max(abs(r["green_ampt_identity_residual"]) for r in cases),
        "pass": passed,
        "decision": "QUALIFIED_SOURCE_RECONCILED_EQ18_ALGEBRA_READY_FOR_RESTRICTED_EXISTING_FRONT_ADVANCE_MASS_GATE" if passed else "EQ18_SOURCE_RECONCILIATION_OR_LIMIT_IDENTITY_FAILED_STOP_INFILTRATION_IMPLEMENTATION",
        "hard_nonclaims": [
            "No dry-bin creation or rainfall allocation qualification.",
            "No G_eff closure qualification.",
            "No front merge or groundwater interaction qualification.",
            "No hydraulic accuracy qualification."
        ],
    }
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps({
        "pass": passed,
        "decision": result["decision"],
        "case_count": result["case_count"],
        "case_pass_count": result["case_pass_count"],
        "all_rejection_checks_pass": result["all_rejection_checks_pass"],
        "max_abs_green_ampt_identity_residual": result["max_abs_green_ampt_identity_residual"],
    }, sort_keys=True))
    if not passed:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
