from __future__ import annotations

import json
import math
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import fwc01_gate_b2d_existing_infiltration_front_advance as b2d

CONTRACT = "F-FWC01_GATE_B2D_R1_CONSERVATIVE_HEUN_POLICY_PRECOMMIT.json"
CONVERGENCE_FLOOR = 1.0e-4
CONVERGENCE_RATIO_MAX = 0.5


def heun_trajectory(z0: float, dtheta: float, A: float, B: float, horizon: float, steps: int):
    z = float(z0)
    ledger = 0.0
    dt = horizon / steps
    max_step_mass = 0.0
    nonfinite = 0
    negative = 0
    boundary = 0
    rows = []
    for step in range(steps):
        committed = b2d.pack_state(z, ledger)
        v0 = b2d.velocity(z, A, B)
        if not math.isfinite(v0):
            nonfinite += 1
            break
        if v0 < 0.0:
            negative += 1
            break
        z_predict = z + dt * v0
        if not math.isfinite(z_predict):
            nonfinite += 1
            break
        if z_predict > b2d.COLUMN_LENGTH or z_predict < 0.0:
            boundary += 1
            assert b2d.pack_state(z, ledger) == committed
            break
        v1 = b2d.velocity(z_predict, A, B)
        if not math.isfinite(v1):
            nonfinite += 1
            break
        if v1 < 0.0:
            negative += 1
            break
        vbar = 0.5 * (v0 + v1)
        trial_z = z + dt * vbar
        trial_flux = dtheta * vbar
        trial_ledger = ledger + dt * trial_flux
        if not math.isfinite(trial_z) or not math.isfinite(trial_flux):
            nonfinite += 1
            break
        if trial_z > b2d.COLUMN_LENGTH or trial_z < 0.0:
            boundary += 1
            assert b2d.pack_state(z, ledger) == committed
            break
        storage_change = dtheta * (trial_z - z)
        mass_residual = storage_change - dt * trial_flux
        max_step_mass = max(max_step_mass, abs(mass_residual))
        z = trial_z
        ledger = trial_ledger
        rows.append({
            "step": step,
            "z_cm": z,
            "predictor_z_cm": z_predict,
            "stage1_velocity_cm_per_day": v0,
            "stage2_velocity_cm_per_day": v1,
            "mean_flux_cm_per_day": trial_flux,
            "mass_residual_cm": mass_residual,
        })
    horizon_mass = dtheta * (z - z0) - ledger
    return {
        "steps": steps,
        "completed_steps": len(rows),
        "z_final_cm": z,
        "ledger_infiltration_cm": ledger,
        "max_abs_step_mass_residual_cm": max_step_mass,
        "abs_horizon_mass_residual_cm": abs(horizon_mass),
        "nonfinite_count": nonfinite,
        "negative_velocity_count": negative,
        "accepted_front_boundary_violation_count": boundary,
        "rows": rows,
    }


def run_case(material: str, row: dict, nbins: int, fraction: float, z0: float, g: float, hp: float):
    j, dtheta, ti, td, ki, kd = b2d.bin_pair(row, nbins, fraction)
    A, B, delta_k = b2d.coefficients(dtheta, ki, kd, g, hp)
    v0 = b2d.velocity(z0, A, B)
    if not (math.isfinite(v0) and v0 >= 0.0):
        return {"pass": False, "failure": "invalid_initial_velocity", "material": material}
    horizon = 0.0 if v0 == 0.0 else min(0.01, 0.1 * z0 / v0)
    exact_z = b2d.exact_front(z0, A, B, horizon)
    exact_water = dtheta * (exact_z - z0)
    candidates = [heun_trajectory(z0, dtheta, A, B, horizon, n) for n in b2d.STEP_COUNTS]
    finest = candidates[-1]
    exact_disp = exact_z - z0
    candidate_disp = finest["z_final_cm"] - z0
    rel_front = abs(candidate_disp - exact_disp) / max(abs(exact_disp), 1.0e-15)
    water_error = abs(finest["ledger_infiltration_cm"] - exact_water)
    errors = [
        abs((c["z_final_cm"] - z0) - exact_disp) / max(abs(exact_disp), 1.0e-15)
        for c in candidates
    ]
    e8, e16 = errors[-2], errors[-1]
    meaningful_convergence = e8 >= CONVERGENCE_FLOOR
    convergence_ratio = e16 / e8 if e8 > 0.0 else 0.0
    convergence_pass = (not meaningful_convergence) or convergence_ratio <= CONVERGENCE_RATIO_MAX
    max_step_mass = max(c["max_abs_step_mass_residual_cm"] for c in candidates)
    max_horizon_mass = max(c["abs_horizon_mass_residual_cm"] for c in candidates)
    nonfinite = sum(c["nonfinite_count"] for c in candidates)
    negative = sum(c["negative_velocity_count"] for c in candidates)
    boundary = sum(c["accepted_front_boundary_violation_count"] for c in candidates)
    rejected = b2d.rejected_trial_check(z0, dtheta, A, B)
    tests = {
        "step_mass": max_step_mass <= b2d.STEP_MASS_TOL,
        "horizon_mass": max_horizon_mass <= b2d.HORIZON_MASS_TOL,
        "front_trajectory": rel_front <= b2d.REL_FRONT_TOL,
        "equivalent_water": water_error <= b2d.WATER_TOL,
        "meaningful_convergence": convergence_pass,
        "nonfinite": nonfinite == 0,
        "negative_velocity": negative == 0,
        "accepted_boundary": boundary == 0,
        "rejected_state": rejected["state_mutation"] == 0,
        "rejected_ledger": rejected["ledger_mutation"] == 0,
        "rejected_diagnostic": rejected["diagnostic"] == "FALLBACK_OR_RETRY_REQUIRED",
    }
    return {
        "material": material,
        "theta_bin_count": nbins,
        "bin_fraction": fraction,
        "bin_j": j,
        "theta_i": ti,
        "theta_d": td,
        "delta_theta": dtheta,
        "K_i": ki,
        "K_d": kd,
        "delta_K": delta_k,
        "G_eff_cm": g,
        "ponding_head_cm": hp,
        "initial_front_depth_cm": z0,
        "initial_velocity_cm_per_day": v0,
        "horizon_day": horizon,
        "exact_front_cm": exact_z,
        "exact_equivalent_water_cm": exact_water,
        "candidate_relative_front_errors": errors,
        "finest_relative_front_displacement_error": rel_front,
        "finest_abs_equivalent_water_depth_error_cm": water_error,
        "e8_relative_front_error": e8,
        "e16_relative_front_error": e16,
        "e16_over_e8": convergence_ratio,
        "meaningful_convergence_case": meaningful_convergence,
        "max_abs_step_mass_residual_cm": max_step_mass,
        "max_abs_horizon_mass_residual_cm": max_horizon_mass,
        "nonfinite_count": nonfinite,
        "negative_velocity_count": negative,
        "accepted_front_boundary_violation_count": boundary,
        "rejected_trial": rejected,
        "candidates": candidates,
        "tests": tests,
        "failed_metrics": [k for k, v in tests.items() if not v],
        "pass": all(tests.values()),
    }


def main():
    if len(sys.argv) != 2:
        raise SystemExit("usage: fwc01_gate_b2d_r1_conservative_heun_policy.py OUTPUT.json")
    out = Path(sys.argv[1])
    fixture = json.loads(b2d.FIXTURE.read_text(encoding="utf-8"))
    by = {r["sfu"]: r for r in fixture["rows"]}
    rows = []
    for material in b2d.MATERIALS:
        row = by[material]
        for nbins in b2d.BIN_COUNTS:
            for fraction in b2d.BIN_FRACTIONS:
                for z0 in b2d.Z0S:
                    for g in b2d.G_VALUES:
                        for hp in b2d.HP_VALUES:
                            rows.append(run_case(material, row, nbins, fraction, z0, g, hp))
    passed = all(r.get("pass", False) for r in rows)
    meaningful = [r for r in rows if r.get("meaningful_convergence_case")]
    result = {
        "schema_version": 1,
        "workstream": "F-FWC",
        "work_unit": "F-FWC01",
        "gate": "B2D_R1_CONSERVATIVE_HEUN_RK2_NUMERICAL_POLICY_QUALIFICATION",
        "contract": CONTRACT,
        "candidate_numerical_policy": "EXPLICIT_HEUN_RK2",
        "physics_changed_from_B2D": False,
        "production_implementation": False,
        "case_count": len(rows),
        "case_pass_count": sum(bool(r.get("pass")) for r in rows),
        "meaningful_convergence_case_count": len(meaningful),
        "max_meaningful_e16_over_e8": max((r["e16_over_e8"] for r in meaningful), default=0.0),
        "max_abs_step_mass_residual_cm": max(r.get("max_abs_step_mass_residual_cm", math.inf) for r in rows),
        "max_abs_horizon_mass_residual_cm": max(r.get("max_abs_horizon_mass_residual_cm", math.inf) for r in rows),
        "max_finest_relative_front_displacement_error": max(r.get("finest_relative_front_displacement_error", math.inf) for r in rows),
        "max_finest_abs_equivalent_water_depth_error_cm": max(r.get("finest_abs_equivalent_water_depth_error_cm", math.inf) for r in rows),
        "total_nonfinite_count": sum(r.get("nonfinite_count", 1) for r in rows),
        "total_negative_velocity_count": sum(r.get("negative_velocity_count", 1) for r in rows),
        "total_accepted_boundary_violation_count": sum(r.get("accepted_front_boundary_violation_count", 1) for r in rows),
        "rejected_trial_state_mutation_count": sum(r.get("rejected_trial", {}).get("state_mutation", 1) for r in rows),
        "rejected_trial_ledger_mutation_count": sum(r.get("rejected_trial", {}).get("ledger_mutation", 1) for r in rows),
        "persistent_extra_state_bytes": 0,
        "predictor_owner": "worker_scratch",
        "mass_repair_count": 0,
        "clipping_repair_count": 0,
        "rows": rows,
        "pass": passed,
        "decision": (
            "QUALIFIED_RESTRICTED_EXISTING_INFILTRATION_FRONT_HEUN_MASS_AND_TRAJECTORY_READY_FOR_FRONT_CREATION_EVENT_GATE"
            if passed else
            "HEUN_EXISTING_INFILTRATION_FRONT_POLICY_NOT_QUALIFIED_RESEARCH_REQUIRED"
        ),
        "preserved_negative_evidence": "B2D explicit Euler remains FAIL",
        "hard_nonclaims": [
            "No dry-bin creation or rainfall allocation qualification.",
            "No G_eff closure qualification.",
            "No front collision or merge qualification.",
            "No groundwater or explicit diffusion qualification.",
            "No production runtime or MultiSWAP qualification."
        ],
    }
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps({k: v for k, v in result.items() if k != "rows"}, sort_keys=True), flush=True)
    if not passed:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
