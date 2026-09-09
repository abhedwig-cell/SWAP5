from __future__ import annotations

import hashlib
import json
import math
import struct
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import run_ross01_gate_d_conservative_physical_unsaturated_column as gate_d
import run_ross01_gate_j1a_real_table_face_derivative as j1a
import run_ross01_tangent_algebra as j0

CONTRACT = "F-ROSS01_GATE_F1_TIMESTEP_SELF_CONVERGENCE_CHARACTERIZATION_CONTRACT.json"
MATERIALS = gate_d.MATERIALS
CELL_COUNTS = (16, 64)
PROFILE_FAMILIES = gate_d.PROFILE_FAMILIES
FORCING_PATTERNS = gate_d.SOURCE_PATTERNS
SIGMA = 0.5
HORIZON_DAY = 0.01
CANDIDATE_DT = (1.0e-4, 2.5e-4, 5.0e-4, 1.0e-3)
REFERENCE_DT = 1.25e-5
FINE_REFERENCE_DT = 6.25e-6
MASS_TOL_CM = 1.0e-12


def float_bytes(values) -> bytes:
    return b"".join(struct.pack("!d", float(v)) for v in values)


def nsteps_for(dt: float) -> int:
    n = int(round(HORIZON_DAY / dt))
    if n <= 0 or abs(n * dt - HORIZON_DAY) > 1.0e-14:
        raise ValueError(("dt does not divide frozen horizon", dt, n))
    return n


def index_ratio(coarse_dt: float, fine_dt: float) -> int:
    ratio = int(round(coarse_dt / fine_dt))
    if ratio <= 0 or abs(ratio * fine_dt - coarse_dt) > 1.0e-14:
        raise ValueError(("unaligned dt ratio", coarse_dt, fine_dt, ratio))
    return ratio


def frozen_forcing(heads: tuple[float, ...], pattern: str):
    q_top, q_bottom, q_scale, k_top, k_bottom = gate_d.boundary_fluxes(heads)
    source, sink = gate_d.source_sink(pattern, len(heads), q_scale)
    return {
        "q_top": float(q_top),
        "q_bottom": float(q_bottom),
        "source": tuple(float(x) for x in source),
        "sink": tuple(float(x) for x in sink),
        "q_scale": float(q_scale),
        "k_top": float(k_top),
        "k_bottom": float(k_bottom),
    }


def advance_once(heads: tuple[float, ...], table, forcing: dict, dt: float):
    n = len(heads)
    theta, _, faces = gate_d.build_faces(heads, table)
    lower, diag, upper, rhs = gate_d.assemble(
        theta,
        faces,
        forcing["q_top"],
        forcing["q_bottom"],
        forcing["source"],
        forcing["sink"],
        dt,
        SIGMA,
    )
    fac = j0.factor_tridiagonal(lower, diag, upper)
    delta = j0.solve_factored(fac, rhs)
    linear_residual = j0.base.matrix_residual(lower, diag, upper, delta, rhs)
    q = gate_d.realized_fluxes(delta, faces, forcing["q_top"], forcing["q_bottom"], SIGMA)

    candidate_theta = tuple(theta[i] + delta[i] for i in range(n))
    candidate_heads = tuple(gate_d.head_from_theta(value) for value in candidate_theta)
    domain_ok = all(
        float(gate_d.core().THETA_R) < value < float(gate_d.core().THETA_S)
        for value in candidate_theta
    )
    envelope_ok = all(j1a.c1r.base.H_MIN < h < j1a.c1r.base.H_MAX for h in candidate_heads)

    cell_residuals = []
    storage_rows = []
    for i in range(n):
        storage = gate_d.DZ_CM * delta[i]
        ledger = dt * (
            q[i] - q[i + 1] + forcing["source"][i] - forcing["sink"][i]
        )
        storage_rows.append(storage)
        cell_residuals.append(storage - ledger)
    global_storage = math.fsum(storage_rows)
    global_external = dt * (
        forcing["q_top"] - forcing["q_bottom"]
        + math.fsum(forcing["source"]) - math.fsum(forcing["sink"])
    )
    mass_residual = global_storage - global_external

    crossings = sum(
        int(j1a.table_cell(heads[i])[0] != j1a.table_cell(candidate_heads[i])[0])
        for i in range(n)
    )
    span = float(gate_d.core().THETA_S - gate_d.core().THETA_R)
    nonfinite = sum(
        not math.isfinite(v)
        for seq in (delta, q, candidate_theta, candidate_heads)
        for v in seq
    )
    return candidate_heads, {
        "abs_mass_residual_cm": abs(mass_residual),
        "max_abs_cell_balance_residual_cm": max(abs(x) for x in cell_residuals),
        "linear_residual_theta": linear_residual,
        "domain_ok": domain_ok,
        "envelope_ok": envelope_ok,
        "nonfinite_count": nonfinite,
        "max_abs_delta_theta": max(abs(x) for x in delta),
        "max_abs_delta_theta_fraction": max(abs(x) for x in delta) / span,
        "table_cell_crossings": crossings,
        "matrix_factorizations": 1,
        "normal_backsolves": 1,
        "global_nonlinear_iterations": 0,
    }


def run_trajectory(initial_heads: tuple[float, ...], table, forcing: dict, dt: float):
    nsteps = nsteps_for(dt)
    initial_snapshot = float_bytes(initial_heads)
    states = [tuple(initial_heads)]
    heads = tuple(initial_heads)
    max_mass = 0.0
    max_cell_mass = 0.0
    max_linear = 0.0
    max_delta = 0.0
    max_delta_fraction = 0.0
    crossings = 0
    nonfinite = 0
    domain_failures = 0
    envelope_failures = 0
    factorizations = 0
    backsolves = 0
    nonlinear_iterations = 0

    for _ in range(nsteps):
        heads, diag = advance_once(heads, table, forcing, dt)
        states.append(heads)
        max_mass = max(max_mass, diag["abs_mass_residual_cm"])
        max_cell_mass = max(max_cell_mass, diag["max_abs_cell_balance_residual_cm"])
        max_linear = max(max_linear, diag["linear_residual_theta"])
        max_delta = max(max_delta, diag["max_abs_delta_theta"])
        max_delta_fraction = max(max_delta_fraction, diag["max_abs_delta_theta_fraction"])
        crossings += diag["table_cell_crossings"]
        nonfinite += diag["nonfinite_count"]
        domain_failures += int(not diag["domain_ok"])
        envelope_failures += int(not diag["envelope_ok"])
        factorizations += diag["matrix_factorizations"]
        backsolves += diag["normal_backsolves"]
        nonlinear_iterations += diag["global_nonlinear_iterations"]

    return states, {
        "dt_day": dt,
        "steps": nsteps,
        "max_abs_per_step_mass_residual_cm": max_mass,
        "max_abs_per_step_cell_balance_residual_cm": max_cell_mass,
        "max_linear_residual_theta": max_linear,
        "max_abs_delta_theta": max_delta,
        "max_abs_delta_theta_fraction": max_delta_fraction,
        "table_cell_crossing_count": crossings,
        "nonfinite_count": nonfinite,
        "domain_failure_count": domain_failures,
        "envelope_failure_count": envelope_failures,
        "matrix_factorizations": factorizations,
        "normal_backsolves": backsolves,
        "global_nonlinear_iterations": nonlinear_iterations,
        "initial_state_bitwise_unchanged": float_bytes(initial_heads) == initial_snapshot,
    }


def theta_profile(heads: tuple[float, ...]):
    return tuple(gate_d.theta_from_head(h) for h in heads)


def compare_aligned(coarse_states, fine_states, coarse_dt: float, fine_dt: float):
    ratio = index_ratio(coarse_dt, fine_dt)
    max_theta = 0.0
    max_rms_theta = 0.0
    max_head_rel = 0.0
    max_bottom_abs = 0.0
    max_bottom_rel = 0.0
    max_cell_mismatch = 0
    total_cell_mismatch = 0

    for k, coarse in enumerate(coarse_states):
        fine = fine_states[k * ratio]
        tc = theta_profile(coarse)
        tf = theta_profile(fine)
        theta_errors = [abs(a - b) for a, b in zip(tc, tf)]
        max_theta = max(max_theta, max(theta_errors))
        rms = math.sqrt(math.fsum(e * e for e in theta_errors) / len(theta_errors))
        max_rms_theta = max(max_rms_theta, rms)
        head_rel = max(
            abs(a - b) / max(1.0, abs(b))
            for a, b in zip(coarse, fine)
        )
        max_head_rel = max(max_head_rel, head_rel)
        bottom_abs = abs(coarse[-1] - fine[-1])
        max_bottom_abs = max(max_bottom_abs, bottom_abs)
        max_bottom_rel = max(max_bottom_rel, bottom_abs / max(1.0, abs(fine[-1])))
        mismatches = sum(
            int(j1a.table_cell(a)[0] != j1a.table_cell(b)[0])
            for a, b in zip(coarse, fine)
        )
        max_cell_mismatch = max(max_cell_mismatch, mismatches)
        total_cell_mismatch += mismatches

    coarse_final = coarse_states[-1]
    fine_final = fine_states[-1]
    tc_final = theta_profile(coarse_final)
    tf_final = theta_profile(fine_final)
    final_theta = max(abs(a - b) for a, b in zip(tc_final, tf_final))
    final_head_rel = max(
        abs(a - b) / max(1.0, abs(b))
        for a, b in zip(coarse_final, fine_final)
    )
    return {
        "max_abs_theta_error": max_theta,
        "max_rms_theta_error": max_rms_theta,
        "max_relative_head_error": max_head_rel,
        "max_abs_bottom_head_error_cm": max_bottom_abs,
        "max_relative_bottom_head_error": max_bottom_rel,
        "max_aligned_profile_table_cell_mismatch_count": max_cell_mismatch,
        "total_aligned_profile_table_cell_mismatch_count": total_cell_mismatch,
        "final_max_abs_theta_error": final_theta,
        "final_max_relative_head_error": final_head_rel,
    }


def run_material(row: dict):
    j1a.c1r.base.c1.configure_core(row)
    material = row["sfu"]
    table, preprocessing_seconds, generation_failures = j1a.c1r.base.generate_table(j1a.N)
    if generation_failures:
        return {"material": material, "characterization_complete": False, "failed_execution_gates": ["table_generation_failures"]}
    table_before = hashlib.sha256(table.tobytes(order="C")).hexdigest()

    candidate_rows = []
    reference_rows = []
    errors = []
    trajectory_diagnostics = []
    initial_states_unchanged = True

    for n in CELL_COUNTS:
        for profile_name, h_first, h_last in PROFILE_FAMILIES:
            try:
                initial = gate_d.build_profile(n, h_first, h_last)
            except Exception as exc:
                errors.append({"n_cells": n, "profile": profile_name, "stage": "initial_profile", "error": repr(exc)})
                continue
            initial_snapshot = float_bytes(initial)
            for pattern in FORCING_PATTERNS:
                forcing = frozen_forcing(initial, pattern)
                scenario = {
                    "n_cells": n,
                    "profile": profile_name,
                    "forcing_pattern": pattern,
                }
                try:
                    fine_states, fine_diag = run_trajectory(initial, table, forcing, FINE_REFERENCE_DT)
                    ref_states, ref_diag = run_trajectory(initial, table, forcing, REFERENCE_DT)
                    ref_cmp = compare_aligned(ref_states, fine_states, REFERENCE_DT, FINE_REFERENCE_DT)
                    reference_rows.append({**scenario, **ref_cmp})
                    trajectory_diagnostics.extend([
                        {**scenario, "role": "fine_reference", **fine_diag},
                        {**scenario, "role": "reference", **ref_diag},
                    ])
                    for dt in CANDIDATE_DT:
                        candidate_states, candidate_diag = run_trajectory(initial, table, forcing, dt)
                        cmp = compare_aligned(candidate_states, fine_states, dt, FINE_REFERENCE_DT)
                        candidate_rows.append({**scenario, "dt_day": dt, **cmp, **{
                            "max_abs_delta_theta": candidate_diag["max_abs_delta_theta"],
                            "max_abs_delta_theta_fraction": candidate_diag["max_abs_delta_theta_fraction"],
                            "accepted_step_table_cell_crossing_count": candidate_diag["table_cell_crossing_count"],
                        }})
                        trajectory_diagnostics.append({**scenario, "role": "candidate", **candidate_diag})
                except Exception as exc:
                    errors.append({**scenario, "stage": "trajectory", "error": repr(exc)})
            initial_states_unchanged = initial_states_unchanged and float_bytes(initial) == initial_snapshot

    table_after = hashlib.sha256(table.tobytes(order="C")).hexdigest()
    expected_scenarios = len(CELL_COUNTS) * len(PROFILE_FAMILIES) * len(FORCING_PATTERNS)
    expected_candidate_rows = expected_scenarios * len(CANDIDATE_DT)

    if not candidate_rows or not reference_rows or not trajectory_diagnostics:
        return {
            "material": material,
            "characterization_complete": False,
            "failed_execution_gates": ["no_complete_characterization_rows"],
            "errors": errors,
        }

    max_mass = max(d["max_abs_per_step_mass_residual_cm"] for d in trajectory_diagnostics)
    max_cell_mass = max(d["max_abs_per_step_cell_balance_residual_cm"] for d in trajectory_diagnostics)
    domain_failures = sum(d["domain_failure_count"] for d in trajectory_diagnostics)
    envelope_failures = sum(d["envelope_failure_count"] for d in trajectory_diagnostics)
    nonfinite = sum(d["nonfinite_count"] for d in trajectory_diagnostics)
    nonlinear = sum(d["global_nonlinear_iterations"] for d in trajectory_diagnostics)
    cost_ok = all(
        d["matrix_factorizations"] == d["steps"]
        and d["normal_backsolves"] == d["steps"]
        for d in trajectory_diagnostics
    )

    by_dt = []
    for dt in CANDIDATE_DT:
        rows = [r for r in candidate_rows if r["dt_day"] == dt]
        by_dt.append({
            "dt_day": dt,
            "scenario_count": len(rows),
            "max_abs_theta_error": max(r["max_abs_theta_error"] for r in rows),
            "max_rms_theta_error": max(r["max_rms_theta_error"] for r in rows),
            "max_relative_head_error": max(r["max_relative_head_error"] for r in rows),
            "max_abs_bottom_head_error_cm": max(r["max_abs_bottom_head_error_cm"] for r in rows),
            "max_relative_bottom_head_error": max(r["max_relative_bottom_head_error"] for r in rows),
            "max_abs_delta_theta": max(r["max_abs_delta_theta"] for r in rows),
            "max_abs_delta_theta_fraction": max(r["max_abs_delta_theta_fraction"] for r in rows),
            "accepted_step_table_cell_crossing_count": sum(r["accepted_step_table_cell_crossing_count"] for r in rows),
            "max_aligned_profile_table_cell_mismatch_count": max(r["max_aligned_profile_table_cell_mismatch_count"] for r in rows),
        })

    reference_summary = {
        "scenario_count": len(reference_rows),
        "max_abs_theta_error_reference_vs_fine": max(r["max_abs_theta_error"] for r in reference_rows),
        "max_rms_theta_error_reference_vs_fine": max(r["max_rms_theta_error"] for r in reference_rows),
        "max_relative_head_error_reference_vs_fine": max(r["max_relative_head_error"] for r in reference_rows),
        "max_abs_bottom_head_error_cm_reference_vs_fine": max(r["max_abs_bottom_head_error_cm"] for r in reference_rows),
        "max_relative_bottom_head_error_reference_vs_fine": max(r["max_relative_bottom_head_error"] for r in reference_rows),
    }

    tests = {
        "all_precommitted_trajectories_complete": len(errors) == 0 and len(reference_rows) == expected_scenarios and len(candidate_rows) == expected_candidate_rows,
        "domain_valid": domain_failures == 0,
        "head_envelope_valid": envelope_failures == 0,
        "nonfinite_count": nonfinite == 0,
        "mass_residual": max_mass <= MASS_TOL_CM,
        "initial_state_not_mutated": initial_states_unchanged,
        "table_not_mutated": table_before == table_after,
        "global_nonlinear_iterations": nonlinear == 0,
        "one_factorization_and_backsolve_per_accepted_step": cost_ok,
    }

    return {
        "material": material,
        "preprocessing_seconds_descriptive": preprocessing_seconds,
        "scenario_count": expected_scenarios,
        "candidate_trajectory_count": len(candidate_rows),
        "reference_pair_count": len(reference_rows),
        "error_count": len(errors),
        "table_sha256": table_before,
        "table_bitwise_unchanged": table_before == table_after,
        "initial_state_bitwise_unchanged": initial_states_unchanged,
        "max_abs_per_step_mass_residual_cm": max_mass,
        "max_abs_per_step_cell_balance_residual_cm": max_cell_mass,
        "domain_failure_count": domain_failures,
        "head_envelope_failure_count": envelope_failures,
        "nonfinite_count": nonfinite,
        "global_nonlinear_iterations": nonlinear,
        "cost_contract_pass": cost_ok,
        "reference_convergence": reference_summary,
        "candidate_by_dt": by_dt,
        "candidate_rows": candidate_rows,
        "reference_rows": reference_rows,
        "errors": errors,
        "failed_execution_gates": [name for name, ok in tests.items() if not ok],
        "characterization_complete": all(tests.values()),
        "production_timestep_policy_qualified": False,
    }


def main():
    if len(sys.argv) != 3:
        raise SystemExit("usage: run_ross01_gate_f1_timestep_self_convergence.py MATERIAL OUTPUT.json")
    material = sys.argv[1]
    out = Path(sys.argv[2])
    catalog = json.loads(j1a.CATALOG.read_text())
    by_name = {r["sfu"]: r for r in catalog["rows"]}
    if material not in MATERIALS or material not in by_name:
        raise SystemExit(f"material must be one of {MATERIALS}")
    result = run_material(by_name[material])
    result.update({
        "schema_version": 1,
        "workstream": "F-ROSS",
        "work_unit": "F-ROSS01",
        "gate": "F1_TIMESTEP_SELF_CONVERGENCE_CHARACTERIZATION",
        "contract": CONTRACT,
        "sigma": SIGMA,
        "horizon_day": HORIZON_DAY,
        "candidate_dt_days": list(CANDIDATE_DT),
        "reference_dt_day": REFERENCE_DT,
        "fine_reference_dt_day": FINE_REFERENCE_DT,
        "reference_is_Ross_self_convergence_not_FullRichards": True,
        "production_implementation": False,
    })
    out.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
    concise = {k: v for k, v in result.items() if k not in ("candidate_rows", "reference_rows", "errors")}
    print(json.dumps(concise, sort_keys=True), flush=True)
    raise SystemExit(0 if result.get("characterization_complete", False) else 1)


if __name__ == "__main__":
    main()
