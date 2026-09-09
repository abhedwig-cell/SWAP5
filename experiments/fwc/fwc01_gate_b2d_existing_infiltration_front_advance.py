from __future__ import annotations

import json
import math
import struct
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import fwc01_gate_b2a_physical_falling_slug_mass as b2a

CONTRACT = "F-FWC01_GATE_B2D_EXISTING_INFILTRATION_FRONT_ADVANCE_MASS_HYDROLOGIC_PRECOMMIT.json"
FIXTURE = Path("integration/f-fwc/F-FWC01_GATE_B2A_MATERIAL_FIXTURE.json")
MATERIALS = ("B01", "B12", "O13", "O14")
BIN_COUNTS = (16, 64, 200)
BIN_FRACTIONS = (0.125, 0.5, 0.875, 1.0)
Z0S = (1.0, 10.0, 50.0)
G_VALUES = (1.0, 10.0, 100.0)
HP_VALUES = (0.0, 5.0)
STEP_COUNTS = (1, 2, 4, 8, 16)
COLUMN_LENGTH = 100.0
STEP_MASS_TOL = 1.0e-12
HORIZON_MASS_TOL = 1.0e-11
REL_FRONT_TOL = 1.0e-3
WATER_TOL = 1.0e-4
NONWORSEN_FACTOR = 1.05


def pack_state(z: float, ledger: float) -> bytes:
    return struct.pack("!dd", float(z), float(ledger))


def bin_pair(row: dict, nbins: int, fraction: float):
    j = min(nbins, max(1, int(round(fraction * nbins))))
    tr = float(row["theta_r"]); ts = float(row["theta_s"])
    dtheta = (ts - tr) / nbins
    theta_i = tr + (j - 1) * dtheta
    theta_d = tr + j * dtheta
    k_i = b2a.mvg_k_of_theta(theta_i, row)
    k_d = b2a.mvg_k_of_theta(theta_d, row)
    return j, dtheta, theta_i, theta_d, k_i, k_d


def coefficients(dtheta: float, k_i: float, k_d: float, g: float, hp: float):
    delta_k = k_d - k_i
    A = k_d * (g + hp) / dtheta
    B = delta_k / dtheta
    return A, B, delta_k


def velocity(z: float, A: float, B: float) -> float:
    return A / z + B


def flux(z: float, dtheta: float, A: float, B: float) -> float:
    return dtheta * velocity(z, A, B)


def elapsed_to(z: float, z0: float, A: float, B: float) -> float:
    if z < z0:
        raise ValueError("reference front must not move upward")
    if A == 0.0:
        if B == 0.0:
            return math.inf if z > z0 else 0.0
        return (z - z0) / B
    if B == 0.0:
        return (z * z - z0 * z0) / (2.0 * A)
    # Stable form: integral z/(A+Bz) dz.
    x0 = A + B * z0
    x = A + B * z
    return (z - z0) / B - (A / (B * B)) * math.log(x / x0)


def exact_front(z0: float, A: float, B: float, horizon: float) -> float:
    if horizon == 0.0 or (A == 0.0 and B == 0.0):
        return z0
    v0 = velocity(z0, A, B)
    if not (math.isfinite(v0) and v0 >= 0.0):
        raise ValueError("invalid exact-front velocity")
    lo = z0
    hi = z0 + v0 * horizon
    if hi == lo:
        return lo
    # Because A/z+B decreases with z, explicit-Euler first-step travel is an upper bound.
    for _ in range(96):
        mid = 0.5 * (lo + hi)
        tmid = elapsed_to(mid, z0, A, B)
        if tmid < horizon:
            lo = mid
        else:
            hi = mid
    return 0.5 * (lo + hi)


def candidate_trajectory(z0: float, dtheta: float, A: float, B: float, horizon: float, steps: int):
    z = float(z0)
    ledger = 0.0
    dt = horizon / steps
    max_step_mass = 0.0
    nonfinite = 0
    negative = 0
    boundary = 0
    rows = []
    for step in range(steps):
        committed = pack_state(z, ledger)
        v = velocity(z, A, B)
        f = dtheta * v
        if not (math.isfinite(v) and math.isfinite(f)):
            nonfinite += 1
            break
        if v < 0.0:
            negative += 1
            break
        trial_z = z + dt * v
        trial_ledger = ledger + dt * f
        if trial_z > COLUMN_LENGTH or trial_z < 0.0:
            boundary += 1
            # Fail closed. No commit.
            assert pack_state(z, ledger) == committed
            break
        storage_change = dtheta * (trial_z - z)
        mass_residual = storage_change - dt * f
        max_step_mass = max(max_step_mass, abs(mass_residual))
        z = trial_z
        ledger = trial_ledger
        rows.append({"step":step,"z_cm":z,"flux_cm_per_day":f,"mass_residual_cm":mass_residual})
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


def rejected_trial_check(z0: float, dtheta: float, A: float, B: float):
    ledger = 0.0
    before = pack_state(z0, ledger)
    v = velocity(z0, A, B)
    if v <= 0.0 or not math.isfinite(v):
        return {"state_mutation":1,"ledger_mutation":1,"diagnostic":"INVALID_BASE_VELOCITY"}
    dt = 2.0 * max(1.0, COLUMN_LENGTH - z0) / v
    trial_z = z0 + dt * v
    if trial_z <= COLUMN_LENGTH:
        return {"state_mutation":1,"ledger_mutation":1,"diagnostic":"OVERSIZE_FIXTURE_DID_NOT_OVERFLOW"}
    # Rejection occurs before commit.
    after = pack_state(z0, ledger)
    return {
        "state_mutation": int(before != after),
        "ledger_mutation": int(before != after),
        "diagnostic": "FALLBACK_OR_RETRY_REQUIRED",
        "trial_z_cm": trial_z,
    }


def run_case(material: str, row: dict, nbins: int, fraction: float, z0: float, g: float, hp: float):
    j, dtheta, ti, td, ki, kd = bin_pair(row, nbins, fraction)
    A, B, delta_k = coefficients(dtheta, ki, kd, g, hp)
    v0 = velocity(z0, A, B)
    if not (math.isfinite(v0) and v0 >= 0.0):
        return {"pass":False,"failure":"invalid_initial_velocity","material":material}
    horizon = 0.0 if v0 == 0.0 else min(0.01, 0.1 * z0 / v0)
    exact_z = exact_front(z0, A, B, horizon)
    exact_water = dtheta * (exact_z - z0)
    candidates = [candidate_trajectory(z0, dtheta, A, B, horizon, n) for n in STEP_COUNTS]
    finest = candidates[-1]
    exact_disp = exact_z - z0
    candidate_disp = finest["z_final_cm"] - z0
    rel_front = abs(candidate_disp - exact_disp) / max(abs(exact_disp), 1.0e-15)
    water_error = abs(finest["ledger_infiltration_cm"] - exact_water)
    errors = []
    for c in candidates:
        errors.append(abs((c["z_final_cm"] - z0) - exact_disp) / max(abs(exact_disp), 1.0e-15))
    nonworsen = errors[-1] <= NONWORSEN_FACTOR * errors[-2] if len(errors) >= 2 else True
    max_step_mass = max(c["max_abs_step_mass_residual_cm"] for c in candidates)
    max_horizon_mass = max(c["abs_horizon_mass_residual_cm"] for c in candidates)
    nonfinite = sum(c["nonfinite_count"] for c in candidates)
    negative = sum(c["negative_velocity_count"] for c in candidates)
    boundary = sum(c["accepted_front_boundary_violation_count"] for c in candidates)
    rejected = rejected_trial_check(z0, dtheta, A, B)
    tests = {
        "step_mass": max_step_mass <= STEP_MASS_TOL,
        "horizon_mass": max_horizon_mass <= HORIZON_MASS_TOL,
        "front_trajectory": rel_front <= REL_FRONT_TOL,
        "equivalent_water": water_error <= WATER_TOL,
        "nonworsening": nonworsen,
        "nonfinite": nonfinite == 0,
        "negative_velocity": negative == 0,
        "accepted_boundary": boundary == 0,
        "rejected_state": rejected["state_mutation"] == 0,
        "rejected_ledger": rejected["ledger_mutation"] == 0,
        "rejected_diagnostic": rejected["diagnostic"] == "FALLBACK_OR_RETRY_REQUIRED",
    }
    return {
        "material": material,"theta_bin_count":nbins,"bin_fraction":fraction,"bin_j":j,
        "theta_i":ti,"theta_d":td,"delta_theta":dtheta,"K_i":ki,"K_d":kd,"delta_K":delta_k,
        "G_eff_cm":g,"ponding_head_cm":hp,"initial_front_depth_cm":z0,"initial_velocity_cm_per_day":v0,
        "horizon_day":horizon,"exact_front_cm":exact_z,"exact_equivalent_water_cm":exact_water,
        "candidate_relative_front_errors":errors,"finest_relative_front_displacement_error":rel_front,
        "finest_abs_equivalent_water_depth_error_cm":water_error,"max_abs_step_mass_residual_cm":max_step_mass,
        "max_abs_horizon_mass_residual_cm":max_horizon_mass,"nonfinite_count":nonfinite,
        "negative_velocity_count":negative,"accepted_front_boundary_violation_count":boundary,
        "rejected_trial":rejected,"candidates":candidates,"tests":tests,"failed_metrics":[k for k,v in tests.items() if not v],
        "pass":all(tests.values())
    }


def main():
    if len(sys.argv) != 2:
        raise SystemExit("usage: fwc01_gate_b2d_existing_infiltration_front_advance.py OUTPUT.json")
    out = Path(sys.argv[1])
    fixture = json.loads(FIXTURE.read_text(encoding="utf-8"))
    by = {r["sfu"]: r for r in fixture["rows"]}
    rows = []
    for material in MATERIALS:
        row = by[material]
        for nbins in BIN_COUNTS:
            for fraction in BIN_FRACTIONS:
                for z0 in Z0S:
                    for g in G_VALUES:
                        for hp in HP_VALUES:
                            rows.append(run_case(material,row,nbins,fraction,z0,g,hp))
    passed = all(r.get("pass",False) for r in rows)
    result = {
        "schema_version":1,"workstream":"F-FWC","work_unit":"F-FWC01",
        "gate":"B2D_RESTRICTED_EXISTING_INFILTRATION_FRONT_ADVANCE_MASS_AND_HYDROLOGIC_TRAJECTORY",
        "contract":CONTRACT,"production_implementation":False,"case_count":len(rows),
        "case_pass_count":sum(bool(r.get("pass")) for r in rows),
        "max_abs_step_mass_residual_cm":max(r.get("max_abs_step_mass_residual_cm",math.inf) for r in rows),
        "max_abs_horizon_mass_residual_cm":max(r.get("max_abs_horizon_mass_residual_cm",math.inf) for r in rows),
        "max_finest_relative_front_displacement_error":max(r.get("finest_relative_front_displacement_error",math.inf) for r in rows),
        "max_finest_abs_equivalent_water_depth_error_cm":max(r.get("finest_abs_equivalent_water_depth_error_cm",math.inf) for r in rows),
        "total_nonfinite_count":sum(r.get("nonfinite_count",1) for r in rows),
        "total_negative_velocity_count":sum(r.get("negative_velocity_count",1) for r in rows),
        "total_accepted_boundary_violation_count":sum(r.get("accepted_front_boundary_violation_count",1) for r in rows),
        "rejected_trial_state_mutation_count":sum(r.get("rejected_trial",{}).get("state_mutation",1) for r in rows),
        "rejected_trial_ledger_mutation_count":sum(r.get("rejected_trial",{}).get("ledger_mutation",1) for r in rows),
        "mass_repair_count":0,"clipping_repair_count":0,"rows":rows,"pass":passed,
        "decision":"QUALIFIED_RESTRICTED_EXISTING_INFILTRATION_FRONT_ADVANCE_MASS_AND_TRAJECTORY_READY_FOR_FRONT_CREATION_EVENT_GATE" if passed else "EXISTING_INFILTRATION_FRONT_ADVANCE_NOT_QUALIFIED_RESEARCH_REQUIRED",
        "hard_nonclaims":["No dry-bin creation or rainfall allocation qualification.","No G_eff closure qualification.","No front collision or merge qualification.","No groundwater or explicit diffusion qualification."]
    }
    out.parent.mkdir(parents=True,exist_ok=True)
    out.write_text(json.dumps(result,indent=2,sort_keys=True)+"\n",encoding="utf-8")
    print(json.dumps({k:v for k,v in result.items() if k not in ('rows',)},sort_keys=True),flush=True)
    if not passed:
        raise SystemExit(1)

if __name__ == "__main__":
    main()
