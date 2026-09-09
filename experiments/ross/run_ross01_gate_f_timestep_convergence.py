from __future__ import annotations

import hashlib
import json
import math
import statistics
import struct
import sys
from pathlib import Path

import numpy as np
from scipy.integrate import solve_ivp

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import run_ross01_gate_d_conservative_physical_unsaturated_column as gate_d
import run_ross01_gate_j1a_real_table_face_derivative as j1a
import run_ross01_gate_j1a_r1_head_coordinate_oracle_repair as r1
import run_ross01_tangent_algebra as j0

CONTRACT = "F-ROSS01_GATE_F_TIMESTEP_CONVERGENCE_CONTRACT.json"
MATERIALS = ("B01", "B12", "O01", "O05", "O14", "O18")
CELL_COUNTS = (4, 16, 64)
PROFILE_FAMILIES = gate_d.PROFILE_FAMILIES
SOURCE_PATTERNS = ("zero", "mixed_local_source_and_sink")
SIGMA = 0.5
HORIZON_DAY = 0.0016
STEP_COUNTS = (2, 4, 8, 16)
REFERENCE_RTOL = 1.0e-11
REFERENCE_ATOL = 1.0e-13
REFERENCE_MAX_STEP_COARSE = 0.000025
REFERENCE_MAX_STEP_FINE = 0.0000125
REF_SELF_TOL = 1.0e-9
FINE_SPAN_ERROR_TOL = 1.0e-5
FINE_CHANGE_ERROR_TOL = 0.005
ORDER_FLOOR = 1.0e-10
MIN_ORDER = 1.0
MEDIAN_ORDER = 1.5
MASS_TOL_CM = 1.0e-12
MONOTONIC_SLACK = 1.0e-14


def float_bytes(values) -> bytes:
    return b"".join(struct.pack("!d", float(v)) for v in values)


def theta_span() -> float:
    c = gate_d.core()
    return float(c.THETA_S - c.THETA_R)


def heads_from_theta(theta) -> tuple[float, ...]:
    return tuple(gate_d.head_from_theta(float(v)) for v in theta)


def fixed_external(initial_heads: tuple[float, ...], pattern: str):
    q_top, q_bottom, q_scale, k_top, k_bottom = gate_d.boundary_fluxes(initial_heads)
    source, sink = gate_d.source_sink(pattern, len(initial_heads), q_scale)
    return {
        "q_top": float(q_top),
        "q_bottom": float(q_bottom),
        "q_scale": float(q_scale),
        "k_top": float(k_top),
        "k_bottom": float(k_bottom),
        "source": tuple(float(v) for v in source),
        "sink": tuple(float(v) for v in sink),
    }


def internal_fluxes(heads: tuple[float, ...], table) -> list[float]:
    return [
        float(r1.direct_head_flux(heads[j], heads[j + 1], table))
        for j in range(len(heads) - 1)
    ]


def reference_rhs(_t, theta_array, table, ext):
    theta = tuple(float(v) for v in theta_array)
    heads = heads_from_theta(theta)
    n = len(theta)
    q_internal = internal_fluxes(heads, table)
    q = [ext["q_top"], *q_internal, ext["q_bottom"]]
    return np.asarray([
        (q[i] - q[i + 1] + ext["source"][i] - ext["sink"][i]) / gate_d.DZ_CM
        for i in range(n)
    ], dtype=float)


def run_reference(theta0, table, ext, max_step):
    sol = solve_ivp(
        lambda t, y: reference_rhs(t, y, table, ext),
        (0.0, HORIZON_DAY),
        np.asarray(theta0, dtype=float),
        method="DOP853",
        rtol=REFERENCE_RTOL,
        atol=REFERENCE_ATOL,
        max_step=max_step,
        dense_output=False,
    )
    if not sol.success:
        raise RuntimeError(("reference solve failed", sol.message))
    final_theta = tuple(float(v) for v in sol.y[:, -1])
    final_heads = heads_from_theta(final_theta)
    if not all(j1a.c1r.base.H_MIN < h < j1a.c1r.base.H_MAX for h in final_heads):
        raise ValueError(("reference final head outside C1R envelope", min(final_heads), max(final_heads)))
    if not all(float(gate_d.core().THETA_R) < v < float(gate_d.core().THETA_S) for v in final_theta):
        raise ValueError("reference final theta outside unsaturated MvG domain")
    nonfinite = sum(not math.isfinite(v) for v in (*final_theta, *final_heads))
    initial_storage = gate_d.DZ_CM * math.fsum(theta0)
    final_storage = gate_d.DZ_CM * math.fsum(final_theta)
    external = HORIZON_DAY * (
        ext["q_top"] - ext["q_bottom"] + math.fsum(ext["source"]) - math.fsum(ext["sink"])
    )
    return {
        "theta": final_theta,
        "heads": final_heads,
        "nfev": int(sol.nfev),
        "njev": int(getattr(sol, "njev", 0) or 0),
        "nlu": int(getattr(sol, "nlu", 0) or 0),
        "nonfinite_count": nonfinite,
        "abs_mass_residual_cm_diagnostic": abs((final_storage - initial_storage) - external),
    }


def candidate_step(theta_start, table, ext, dt):
    theta_start = tuple(float(v) for v in theta_start)
    theta_snapshot = float_bytes(theta_start)
    heads = heads_from_theta(theta_start)
    heads_snapshot = float_bytes(heads)

    _, _, faces = gate_d.build_faces(heads, table)
    lower, diag, upper, rhs = gate_d.assemble(
        theta_start,
        faces,
        ext["q_top"],
        ext["q_bottom"],
        ext["source"],
        ext["sink"],
        dt,
        SIGMA,
    )
    factorization = j0.factor_tridiagonal(lower, diag, upper)
    delta = j0.solve_factored(factorization, rhs)
    linear_residual = j0.base.matrix_residual(lower, diag, upper, delta, rhs)
    q = gate_d.realized_fluxes(
        delta, faces, ext["q_top"], ext["q_bottom"], SIGMA
    )
    theta_candidate = tuple(theta_start[i] + delta[i] for i in range(len(theta_start)))
    heads_candidate = heads_from_theta(theta_candidate)

    cell_residuals = []
    for i in range(len(theta_start)):
        storage = gate_d.DZ_CM * delta[i]
        ledger = dt * (
            q[i] - q[i + 1] + ext["source"][i] - ext["sink"][i]
        )
        cell_residuals.append(storage - ledger)
    global_storage = gate_d.DZ_CM * math.fsum(delta)
    global_external = dt * (
        ext["q_top"] - ext["q_bottom"] + math.fsum(ext["source"]) - math.fsum(ext["sink"])
    )
    mass_residual = global_storage - global_external

    domain_ok = all(
        float(gate_d.core().THETA_R) < value < float(gate_d.core().THETA_S)
        for value in theta_candidate
    )
    envelope_ok = all(
        j1a.c1r.base.H_MIN < h < j1a.c1r.base.H_MAX
        for h in heads_candidate
    )
    cell_transitions = sum(
        int(j1a.table_cell(heads[i])[0] != j1a.table_cell(heads_candidate[i])[0])
        for i in range(len(heads))
    )
    nonfinite = sum(
        not math.isfinite(v)
        for seq in (delta, q, theta_candidate, heads_candidate)
        for v in seq
    )
    input_unchanged = (
        float_bytes(theta_start) == theta_snapshot
        and float_bytes(heads) == heads_snapshot
    )
    return {
        "theta": theta_candidate,
        "heads": heads_candidate,
        "abs_global_mass_residual_cm": abs(mass_residual),
        "max_abs_cell_mass_residual_cm": max(abs(v) for v in cell_residuals),
        "linear_residual_theta": linear_residual,
        "domain_ok": domain_ok,
        "envelope_ok": envelope_ok,
        "cell_transition_count": cell_transitions,
        "nonfinite_count": nonfinite,
        "input_state_unchanged": input_unchanged,
        "matrix_factorizations": 1,
        "normal_backsolves": 1,
        "global_nonlinear_iterations": 0,
        "retry_count": 0,
        "branch_or_fallback_count": 0,
    }


def run_candidate(theta0, table, ext, step_count):
    dt = HORIZON_DAY / step_count
    committed = tuple(float(v) for v in theta0)
    initial_snapshot = float_bytes(committed)
    max_step_mass = 0.0
    max_cell_mass = 0.0
    max_linear = 0.0
    domain_failures = 0
    envelope_failures = 0
    cell_transitions = 0
    nonfinite = 0
    input_mutations = 0
    factorizations = 0
    backsolves = 0

    for _ in range(step_count):
        result = candidate_step(committed, table, ext, dt)
        max_step_mass = max(max_step_mass, result["abs_global_mass_residual_cm"])
        max_cell_mass = max(max_cell_mass, result["max_abs_cell_mass_residual_cm"])
        max_linear = max(max_linear, result["linear_residual_theta"])
        domain_failures += int(not result["domain_ok"])
        envelope_failures += int(not result["envelope_ok"])
        cell_transitions += result["cell_transition_count"]
        nonfinite += result["nonfinite_count"]
        input_mutations += int(not result["input_state_unchanged"])
        factorizations += result["matrix_factorizations"]
        backsolves += result["normal_backsolves"]
        if not result["domain_ok"] or not result["envelope_ok"] or result["nonfinite_count"]:
            raise ValueError(("candidate invalid state", step_count, result))
        committed = result["theta"]

    initial_storage = gate_d.DZ_CM * math.fsum(theta0)
    final_storage = gate_d.DZ_CM * math.fsum(committed)
    external = HORIZON_DAY * (
        ext["q_top"] - ext["q_bottom"] + math.fsum(ext["source"]) - math.fsum(ext["sink"])
    )
    horizon_mass_residual = (final_storage - initial_storage) - external
    return {
        "step_count": step_count,
        "dt_day": dt,
        "theta": committed,
        "heads": heads_from_theta(committed),
        "max_abs_step_mass_residual_cm": max_step_mass,
        "max_abs_cell_mass_residual_cm": max_cell_mass,
        "abs_horizon_mass_residual_cm": abs(horizon_mass_residual),
        "max_linear_residual_theta": max_linear,
        "domain_failure_count": domain_failures,
        "envelope_failure_count": envelope_failures,
        "cell_transition_count": cell_transitions,
        "nonfinite_count": nonfinite,
        "input_mutation_count": input_mutations,
        "matrix_factorizations": factorizations,
        "normal_backsolves": backsolves,
        "global_nonlinear_iterations": 0,
        "retry_count": 0,
        "branch_or_fallback_count": 0,
        "initial_state_bitwise_unchanged_outside_sequence": float_bytes(theta0) == initial_snapshot,
    }


def theta_span_error(candidate, reference):
    span = theta_span()
    return max(abs(a - b) for a, b in zip(candidate, reference)) / span


def state_change_relative_error(candidate, reference, theta0):
    span = theta_span()
    change = max(abs(r - s) for r, s in zip(reference, theta0))
    denom = max(change, 1.0e-8 * span)
    return max(abs(a - b) for a, b in zip(candidate, reference)) / denom


def run_case(material, n, profile_name, h_first, h_last, pattern, table):
    initial_heads = gate_d.build_profile(n, h_first, h_last)
    theta0 = tuple(gate_d.theta_from_head(h) for h in initial_heads)
    theta0_snapshot = float_bytes(theta0)
    heads0_snapshot = float_bytes(initial_heads)
    ext = fixed_external(initial_heads, pattern)

    ref_coarse = run_reference(theta0, table, ext, REFERENCE_MAX_STEP_COARSE)
    ref_fine = run_reference(theta0, table, ext, REFERENCE_MAX_STEP_FINE)
    ref_self = theta_span_error(ref_coarse["theta"], ref_fine["theta"])

    paths = []
    for step_count in STEP_COUNTS:
        candidate = run_candidate(theta0, table, ext, step_count)
        candidate["theta_span_normalized_error"] = theta_span_error(
            candidate["theta"], ref_fine["theta"]
        )
        candidate["state_change_relative_error"] = state_change_relative_error(
            candidate["theta"], ref_fine["theta"], theta0
        )
        paths.append(candidate)

    errors = [p["theta_span_normalized_error"] for p in paths]
    monotonic = all(
        errors[i + 1] <= errors[i] + MONOTONIC_SLACK
        for i in range(len(errors) - 1)
    )
    e8 = next(p["theta_span_normalized_error"] for p in paths if p["step_count"] == 8)
    e16 = next(p["theta_span_normalized_error"] for p in paths if p["step_count"] == 16)
    observed_order = None
    if e8 >= ORDER_FLOOR and e16 > 0.0:
        observed_order = math.log(e8 / e16, 2.0)

    initial_unchanged = (
        float_bytes(theta0) == theta0_snapshot
        and float_bytes(initial_heads) == heads0_snapshot
    )
    finest = next(p for p in paths if p["step_count"] == 16)
    return {
        "material": material,
        "n_cells": n,
        "profile": profile_name,
        "source_sink_pattern": pattern,
        "horizon_day": HORIZON_DAY,
        "sigma": SIGMA,
        "reference_coarse_nfev": ref_coarse["nfev"],
        "reference_fine_nfev": ref_fine["nfev"],
        "reference_self_theta_span_normalized": ref_self,
        "reference_coarse_mass_residual_cm_diagnostic": ref_coarse["abs_mass_residual_cm_diagnostic"],
        "reference_fine_mass_residual_cm_diagnostic": ref_fine["abs_mass_residual_cm_diagnostic"],
        "reference_nonfinite_count": ref_coarse["nonfinite_count"] + ref_fine["nonfinite_count"],
        "candidate_paths": paths,
        "refinement_error_nonincreasing": monotonic,
        "observed_order_8_to_16": observed_order,
        "finest_theta_span_normalized_error": finest["theta_span_normalized_error"],
        "finest_state_change_relative_error": finest["state_change_relative_error"],
        "initial_state_bitwise_unchanged_outside_sequences": initial_unchanged,
        "total_candidate_cell_transition_count": sum(p["cell_transition_count"] for p in paths),
        "total_candidate_nonfinite_count": sum(p["nonfinite_count"] for p in paths),
        "total_candidate_domain_failure_count": sum(p["domain_failure_count"] for p in paths),
        "total_candidate_envelope_failure_count": sum(p["envelope_failure_count"] for p in paths),
        "total_candidate_input_mutation_count": sum(p["input_mutation_count"] for p in paths),
        "max_abs_step_mass_residual_cm": max(p["max_abs_step_mass_residual_cm"] for p in paths),
        "max_abs_horizon_mass_residual_cm": max(p["abs_horizon_mass_residual_cm"] for p in paths),
        "max_abs_cell_mass_residual_cm": max(p["max_abs_cell_mass_residual_cm"] for p in paths),
        "max_linear_residual_theta": max(p["max_linear_residual_theta"] for p in paths),
    }


def run_material(row):
    j1a.c1r.base.c1.configure_core(row)
    material = row["sfu"]
    table, preprocessing_seconds, generation_failures = j1a.c1r.base.generate_table(j1a.N)
    if generation_failures:
        return {
            "material": material,
            "pass": False,
            "failed_metrics": ["table_generation_failures"],
            "table_generation_failures": len(generation_failures),
        }
    table_before = hashlib.sha256(table.tobytes(order="C")).hexdigest()
    cases = []
    errors = []

    for n in CELL_COUNTS:
        for profile_name, h_first, h_last in PROFILE_FAMILIES:
            for pattern in SOURCE_PATTERNS:
                try:
                    cases.append(
                        run_case(
                            material, n, profile_name, h_first, h_last, pattern, table
                        )
                    )
                except Exception as exc:
                    errors.append({
                        "n_cells": n,
                        "profile": profile_name,
                        "source_sink_pattern": pattern,
                        "error": repr(exc),
                    })

    table_after = hashlib.sha256(table.tobytes(order="C")).hexdigest()
    expected_cases = len(CELL_COUNTS) * len(PROFILE_FAMILIES) * len(SOURCE_PATTERNS)
    if not cases:
        return {
            "material": material,
            "pass": False,
            "failed_metrics": ["no_valid_cases"],
            "errors": errors,
        }

    informative_orders = [
        c["observed_order_8_to_16"]
        for c in cases
        if c["observed_order_8_to_16"] is not None
        and math.isfinite(c["observed_order_8_to_16"])
    ]
    min_order = min(informative_orders) if informative_orders else None
    median_order = statistics.median(informative_orders) if informative_orders else None

    observed = {
        "material": material,
        "case_count": len(cases),
        "expected_case_count": expected_cases,
        "case_error_count": len(errors),
        "preprocessing_seconds_descriptive": preprocessing_seconds,
        "table_sha256": table_before,
        "table_bitwise_unchanged": table_before == table_after,
        "max_reference_coarse_vs_fine_theta_span_normalized": max(c["reference_self_theta_span_normalized"] for c in cases),
        "max_finest_candidate_theta_span_normalized_error": max(c["finest_theta_span_normalized_error"] for c in cases),
        "max_finest_candidate_state_change_relative_error": max(c["finest_state_change_relative_error"] for c in cases),
        "refinement_monotonicity_violation_count": sum(not c["refinement_error_nonincreasing"] for c in cases),
        "informative_order_case_count": len(informative_orders),
        "minimum_observed_order_in_informative_cases": min_order,
        "median_observed_order_in_informative_cases": median_order,
        "max_abs_step_mass_residual_cm": max(c["max_abs_step_mass_residual_cm"] for c in cases),
        "max_abs_horizon_mass_residual_cm": max(c["max_abs_horizon_mass_residual_cm"] for c in cases),
        "max_abs_cell_mass_residual_cm": max(c["max_abs_cell_mass_residual_cm"] for c in cases),
        "max_linear_residual_theta": max(c["max_linear_residual_theta"] for c in cases),
        "candidate_table_cell_transition_count": sum(c["total_candidate_cell_transition_count"] for c in cases),
        "candidate_nonfinite_count": sum(c["total_candidate_nonfinite_count"] for c in cases),
        "candidate_domain_failure_count": sum(c["total_candidate_domain_failure_count"] for c in cases),
        "candidate_envelope_failure_count": sum(c["total_candidate_envelope_failure_count"] for c in cases),
        "candidate_input_mutation_count": sum(c["total_candidate_input_mutation_count"] for c in cases),
        "reference_nonfinite_count": sum(c["reference_nonfinite_count"] for c in cases),
        "initial_state_bitwise_unchanged_all": all(c["initial_state_bitwise_unchanged_outside_sequences"] for c in cases),
        "candidate_cost_shapes": sorted({
            (p["step_count"], p["matrix_factorizations"], p["normal_backsolves"])
            for c in cases for p in c["candidate_paths"]
        }),
        "worst_finest_theta_case": max(cases, key=lambda c: c["finest_theta_span_normalized_error"]),
        "worst_finest_change_relative_case": max(cases, key=lambda c: c["finest_state_change_relative_error"]),
        "worst_reference_self_case": max(cases, key=lambda c: c["reference_self_theta_span_normalized"]),
        "cases": cases,
        "errors": errors,
    }

    order_ok = (
        not informative_orders
        or (
            min_order is not None
            and median_order is not None
            and min_order >= MIN_ORDER
            and median_order >= MEDIAN_ORDER
        )
    )
    tests = {
        "all_precommitted_cases_valid": observed["case_count"] == expected_cases and observed["case_error_count"] == 0,
        "reference_self_check": observed["max_reference_coarse_vs_fine_theta_span_normalized"] <= REF_SELF_TOL,
        "finest_theta_span_error": observed["max_finest_candidate_theta_span_normalized_error"] <= FINE_SPAN_ERROR_TOL,
        "finest_state_change_relative_error": observed["max_finest_candidate_state_change_relative_error"] <= FINE_CHANGE_ERROR_TOL,
        "refinement_error_nonincreasing": observed["refinement_monotonicity_violation_count"] == 0,
        "observed_order": order_ok,
        "maximum_abs_step_mass_residual_cm": observed["max_abs_step_mass_residual_cm"] <= MASS_TOL_CM,
        "maximum_abs_horizon_mass_residual_cm": observed["max_abs_horizon_mass_residual_cm"] <= MASS_TOL_CM,
        "candidate_state_within_unsaturated_MvG_domain": observed["candidate_domain_failure_count"] == 0,
        "candidate_head_within_C1R_envelope": observed["candidate_envelope_failure_count"] == 0,
        "candidate_table_cell_transition_count": observed["candidate_table_cell_transition_count"] == 0,
        "nonfinite_count": observed["candidate_nonfinite_count"] == 0 and observed["reference_nonfinite_count"] == 0,
        "shared_table_bitwise_unchanged": observed["table_bitwise_unchanged"],
        "initial_state_bitwise_unchanged": observed["initial_state_bitwise_unchanged_all"] and observed["candidate_input_mutation_count"] == 0,
    }
    observed["failed_metrics"] = [name for name, ok in tests.items() if not ok]
    observed["pass"] = all(tests.values())
    return observed


def main():
    if len(sys.argv) != 3:
        raise SystemExit("usage: run_ross01_gate_f_timestep_convergence.py MATERIAL OUTPUT.json")
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
        "gate": "F_TIMESTEP_CONVERGENCE_SMOOTH_C1R",
        "contract": CONTRACT,
        "sigma": SIGMA,
        "horizon_day": HORIZON_DAY,
        "candidate_step_counts": list(STEP_COUNTS),
        "candidate_dt_days": [HORIZON_DAY / n for n in STEP_COUNTS],
        "reference_solver": "DOP853",
        "reference_rtol": REFERENCE_RTOL,
        "reference_atol_theta": REFERENCE_ATOL,
        "reference_max_steps": [REFERENCE_MAX_STEP_COARSE, REFERENCE_MAX_STEP_FINE],
        "production_implementation": False,
        "mass_is_hard_gate_not_state_correction": True,
        "adaptive_timestep_controller_is_not_qualified_here": True,
    })
    out.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
    print(json.dumps({
        k: v for k, v in result.items()
        if k not in ("cases", "errors", "worst_finest_theta_case", "worst_finest_change_relative_case", "worst_reference_self_case")
    }, sort_keys=True), flush=True)
    raise SystemExit(0 if result["pass"] else 1)


if __name__ == "__main__":
    main()
