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

import run_ross01_gate_f_timestep_convergence as gate_f

j0 = gate_f.j0
gate_d = gate_f.gate_d
j1a = gate_f.j1a

CONTRACT = "F-ROSS01_GATE_J1E_D1_LOCAL_TERMINAL_COUPLING_PRECONDITIONER_CONTRACT.json"
MATERIALS = ("B01", "B12", "O01", "O05", "O14", "O18")
N_CELLS = 16
PROFILE_FAMILIES = gate_f.PROFILE_FAMILIES
SOURCE_PATTERNS = ("zero", "mixed_local_source_and_sink")
STEP_COUNTS = (2, 4, 8, 16)
TARGET_HEAD_OFFSETS_CM = (-0.02, 0.02)
FD_FACTOR = 1.0e-5
TRUST_FRACTION_OF_K = 0.05
HEAD_ACCEPT_TOL_CM = 0.01
RESIDUAL_IMPROVEMENT_EPS = 1.0e-12
MASS_TOL_CM = gate_f.MASS_TOL_CM
LINEAR_TOL = 1.0e-12


def float_bytes(values) -> bytes:
    return b"".join(struct.pack("!d", float(v)) for v in values)


def clip(value: float, lo: float, hi: float) -> float:
    return min(hi, max(lo, value))


def exact_internal_table_node(h: float) -> bool:
    _, frac, _ = j1a.table_cell(h)
    return frac == 0.0


def cell_signature(heads) -> tuple[int, ...]:
    return tuple(int(j1a.table_cell(float(h))[0]) for h in heads)


def terminal_step_with_local_qbot_tangent(theta_start, table, ext, dt):
    """One accepted candidate step plus direct local qbot response.

    qbot uses native SWAP sign: positive upward into the column.  gate_f uses
    q_bottom positive downward, hence q_bottom = -qbot.  The tangent holds the
    start state of this terminal substep fixed.  It is deliberately NOT a
    derivative of a preceding multi-substep coupling window.
    """
    theta_start = tuple(float(v) for v in theta_start)
    theta_snapshot = float_bytes(theta_start)
    heads = gate_f.heads_from_theta(theta_start)
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
        gate_f.SIGMA,
    )
    factorization = j0.factor_tridiagonal(lower, diag, upper)
    delta = j0.solve_factored(factorization, rhs)
    normal_linear_residual = j0.base.matrix_residual(lower, diag, upper, delta, rhs)
    q = gate_d.realized_fluxes(
        delta, faces, ext["q_top"], ext["q_bottom"], gate_f.SIGMA
    )

    theta_candidate = tuple(theta_start[i] + delta[i] for i in range(len(theta_start)))
    heads_candidate = gate_f.heads_from_theta(theta_candidate)

    cell_residuals = []
    for i in range(len(theta_start)):
        storage = gate_d.DZ_CM * delta[i]
        ledger = dt * (
            q[i] - q[i + 1] + ext["source"][i] - ext["sink"][i]
        )
        cell_residuals.append(storage - ledger)

    global_storage = gate_d.DZ_CM * math.fsum(delta)
    global_external = dt * (
        ext["q_top"]
        - ext["q_bottom"]
        + math.fsum(ext["source"])
        - math.fsum(ext["sink"])
    )
    mass_residual = global_storage - global_external

    domain_ok = all(
        float(gate_d.core().THETA_R) < value < float(gate_d.core().THETA_S)
        for value in theta_candidate
    )
    envelope_ok = all(
        j1a.c1r.base.H_MIN < h < j1a.c1r.base.H_MAX for h in heads_candidate
    )
    cell_transition_count = sum(
        int(j1a.table_cell(heads[i])[0] != j1a.table_cell(heads_candidate[i])[0])
        for i in range(len(heads))
    )
    exact_node_endpoint_count = sum(exact_internal_table_node(h) for h in heads_candidate)
    nonfinite_count = sum(
        not math.isfinite(v)
        for seq in (delta, q, theta_candidate, heads_candidate)
        for v in seq
    )
    input_unchanged = (
        float_bytes(theta_start) == theta_snapshot
        and float_bytes(heads) == heads_snapshot
    )

    tangent_available = (
        domain_ok
        and envelope_ok
        and nonfinite_count == 0
        and cell_transition_count == 0
        and exact_node_endpoint_count == 0
    )
    tangent = None
    tangent_linear_residual = None
    tangent_backsolves = 0
    tangent_reason = "AVAILABLE_SMOOTH_TERMINAL_SUBSTEP"

    if tangent_available:
        # rhs_last contains -dt/dz*q_bottom.  q_bottom = -qbot, so
        # d(rhs_last)/d(qbot) = +dt/dz.  The start state and factorization are
        # held fixed: this is a local-terminal direct response only.
        tangent_rhs = [0.0] * len(theta_start)
        tangent_rhs[-1] = dt / gate_d.DZ_CM
        response = j0.solve_factored(factorization, tangent_rhs)
        tangent_linear_residual = j0.base.matrix_residual(
            lower, diag, upper, response, tangent_rhs
        )
        tangent = gate_d.dh_dtheta(heads_candidate[-1]) * response[-1]
        tangent_backsolves = 1
        if not (math.isfinite(tangent) and tangent > 0.0):
            tangent_available = False
            tangent_reason = "NONFINITE_OR_NONPOSITIVE_LOCAL_TERMINAL_RESPONSE"
    else:
        reasons = []
        if cell_transition_count:
            reasons.append("TERMINAL_TABLE_CELL_TRANSITION")
        if exact_node_endpoint_count:
            reasons.append("EXACT_INTERNAL_TABLE_NODE_ENDPOINT")
        if not domain_ok:
            reasons.append("DOMAIN_FAILURE")
        if not envelope_ok:
            reasons.append("HEAD_ENVELOPE_FAILURE")
        if nonfinite_count:
            reasons.append("NONFINITE")
        tangent_reason = "+".join(reasons) if reasons else "UNAVAILABLE"

    return {
        "theta": theta_candidate,
        "heads": heads_candidate,
        "abs_global_mass_residual_cm": abs(mass_residual),
        "max_abs_cell_mass_residual_cm": max(abs(v) for v in cell_residuals),
        "normal_linear_residual_theta": normal_linear_residual,
        "domain_ok": domain_ok,
        "envelope_ok": envelope_ok,
        "cell_transition_count": cell_transition_count,
        "exact_node_endpoint_count": exact_node_endpoint_count,
        "nonfinite_count": nonfinite_count,
        "input_state_unchanged": input_unchanged,
        "matrix_factorizations": 1,
        "normal_backsolves": 1,
        "local_terminal_tangent_backsolves": tangent_backsolves,
        "local_terminal_tangent_available": tangent_available,
        "local_terminal_dh_bottom_dqbot_day": tangent if tangent_available else None,
        "local_terminal_tangent_linear_residual": tangent_linear_residual,
        "local_terminal_tangent_scope": "LOCAL_TERMINAL_SUBSTEP_ONLY",
        "local_terminal_tangent_method": "SAME_FACTORIZATION_DIRECT_QBOT_BACKSOLVE",
        "local_terminal_tangent_is_whole_window_derivative": False,
        "local_terminal_tangent_reason": tangent_reason,
    }


def run_window(theta0, table, ext_base, qbot_swap, step_count, request_terminal_tangent):
    if step_count < 2:
        raise ValueError("D1 qualification requires a multi-substep coupling window")

    ext = dict(ext_base)
    ext["source"] = tuple(ext_base["source"])
    ext["sink"] = tuple(ext_base["sink"])
    ext["q_bottom"] = -float(qbot_swap)

    dt = gate_f.HORIZON_DAY / step_count
    checkpoint = tuple(float(v) for v in theta0)
    checkpoint_snapshot = float_bytes(checkpoint)
    committed = checkpoint

    max_step_mass = 0.0
    max_cell_mass = 0.0
    max_normal_linear = 0.0
    nonfinite_count = 0
    domain_failure_count = 0
    envelope_failure_count = 0
    input_mutation_count = 0
    cell_transition_count = 0
    factorizations = 0
    normal_backsolves = 0
    tangent_backsolves = 0
    route_signature = []
    terminal = None

    for step_index in range(step_count):
        is_terminal = step_index == step_count - 1
        if is_terminal and request_terminal_tangent:
            result = terminal_step_with_local_qbot_tangent(committed, table, ext, dt)
            terminal = result
            max_normal_linear = max(max_normal_linear, result["normal_linear_residual_theta"])
            tangent_backsolves += result["local_terminal_tangent_backsolves"]
        else:
            result = gate_f.candidate_step(committed, table, ext, dt)
            max_normal_linear = max(max_normal_linear, result["linear_residual_theta"])

        max_step_mass = max(max_step_mass, result["abs_global_mass_residual_cm"])
        max_cell_mass = max(max_cell_mass, result["max_abs_cell_mass_residual_cm"])
        nonfinite_count += result["nonfinite_count"]
        domain_failure_count += int(not result["domain_ok"])
        envelope_failure_count += int(not result["envelope_ok"])
        input_mutation_count += int(not result["input_state_unchanged"])
        cell_transition_count += result["cell_transition_count"]
        factorizations += result["matrix_factorizations"]
        normal_backsolves += result["normal_backsolves"]

        if not result["domain_ok"] or not result["envelope_ok"] or result["nonfinite_count"]:
            raise ValueError(("invalid RossFast candidate state", step_count, step_index, result))

        committed = tuple(float(v) for v in result["theta"])
        route_signature.append(cell_signature(result["heads"]))

    initial_storage = gate_d.DZ_CM * math.fsum(checkpoint)
    final_storage = gate_d.DZ_CM * math.fsum(committed)
    external = gate_f.HORIZON_DAY * (
        ext["q_top"]
        - ext["q_bottom"]
        + math.fsum(ext["source"])
        - math.fsum(ext["sink"])
    )
    horizon_mass_residual = (final_storage - initial_storage) - external
    final_heads = gate_f.heads_from_theta(committed)

    return {
        "step_count": step_count,
        "dt_day": dt,
        "qbot_swap_cm_per_day": float(qbot_swap),
        "q_bottom_down_cm_per_day": ext["q_bottom"],
        "theta": committed,
        "heads": final_heads,
        "h_bottom_cm": final_heads[-1],
        "route_signature": tuple(route_signature),
        "max_abs_step_mass_residual_cm": max_step_mass,
        "max_abs_cell_mass_residual_cm": max_cell_mass,
        "abs_horizon_mass_residual_cm": abs(horizon_mass_residual),
        "max_normal_linear_residual_theta": max_normal_linear,
        "domain_failure_count": domain_failure_count,
        "envelope_failure_count": envelope_failure_count,
        "nonfinite_count": nonfinite_count,
        "input_mutation_count": input_mutation_count,
        "cell_transition_count": cell_transition_count,
        "matrix_factorizations": factorizations,
        "normal_backsolves": normal_backsolves,
        "local_terminal_tangent_backsolves": tangent_backsolves,
        "checkpoint_bitwise_unchanged": float_bytes(checkpoint) == checkpoint_snapshot,
        "local_terminal_tangent_available": (
            bool(terminal["local_terminal_tangent_available"]) if terminal is not None else False
        ),
        "local_terminal_dh_bottom_dqbot_day": (
            terminal["local_terminal_dh_bottom_dqbot_day"] if terminal is not None else None
        ),
        "local_terminal_tangent_linear_residual": (
            terminal["local_terminal_tangent_linear_residual"] if terminal is not None else None
        ),
        "local_terminal_tangent_scope": (
            terminal["local_terminal_tangent_scope"] if terminal is not None else "NOT_REQUESTED"
        ),
        "local_terminal_tangent_method": (
            terminal["local_terminal_tangent_method"] if terminal is not None else "NOT_REQUESTED"
        ),
        "local_terminal_tangent_reason": (
            terminal["local_terminal_tangent_reason"] if terminal is not None else "NOT_REQUESTED"
        ),
        "local_terminal_tangent_is_whole_window_derivative": False,
    }


def window_mass_ok(window: dict) -> bool:
    return (
        window["max_abs_step_mass_residual_cm"] <= MASS_TOL_CM
        and window["max_abs_cell_mass_residual_cm"] <= MASS_TOL_CM
        and window["abs_horizon_mass_residual_cm"] <= MASS_TOL_CM
    )


def qualification_fd_oracle(theta0, table, ext, qbot0, q_scale, step_count, base_window):
    dq = FD_FACTOR * max(q_scale, 1.0e-12)
    plus = run_window(theta0, table, ext, qbot0 + dq, step_count, False)
    minus = run_window(theta0, table, ext, qbot0 - dq, step_count, False)
    route_same = (
        plus["route_signature"] == base_window["route_signature"]
        and minus["route_signature"] == base_window["route_signature"]
    )
    fd = (plus["h_bottom_cm"] - minus["h_bottom_cm"]) / (2.0 * dq)
    local = base_window["local_terminal_dh_bottom_dqbot_day"]
    return {
        "delta_qbot_cm_per_day": dq,
        "whole_window_fd_day_diagnostic": fd,
        "route_signature_same": route_same,
        "finite": math.isfinite(fd),
        "local_terminal_day": local,
        "local_to_fd_ratio_diagnostic": (
            local / fd if local is not None and fd != 0.0 and math.isfinite(fd) else None
        ),
        "fd_is_algorithm_input": False,
        "qualification_full_window_runs": 2,
        "plus_mass_ok": window_mass_ok(plus),
        "minus_mass_ok": window_mass_ok(minus),
        "plus_checkpoint_unchanged": plus["checkpoint_bitwise_unchanged"],
        "minus_checkpoint_unchanged": minus["checkpoint_bitwise_unchanged"],
    }


def correction_case(theta0, table, ext, predictor, qbot0, q_scale, step_count, target_offset):
    target_head = predictor["h_bottom_cm"] + target_offset
    residual_predictor = predictor["h_bottom_cm"] - target_head
    tangent = predictor["local_terminal_dh_bottom_dqbot_day"]

    base = {
        "target_head_offset_cm": target_offset,
        "target_head_cm": target_head,
        "predictor_residual_cm": residual_predictor,
        "predictor_within_accept_tolerance": abs(residual_predictor) <= HEAD_ACCEPT_TOL_CM,
        "local_terminal_tangent_available": predictor["local_terminal_tangent_available"],
        "local_terminal_tangent_scope": predictor["local_terminal_tangent_scope"],
        "local_terminal_tangent_is_whole_window_derivative": False,
        "preconditioner_is_whole_window_derivative": False,
        "corrector_started_from_same_checkpoint": True,
    }

    if not predictor["local_terminal_tangent_available"] or tangent is None:
        base.update({
            "route": "FALLBACK_LOCAL_TERMINAL_TANGENT_UNAVAILABLE",
            "corrector_run": False,
            "coupled_candidate_published": False,
            "fallback_required": True,
            "fallback_reason": predictor["local_terminal_tangent_reason"],
        })
        return base

    preconditioner = step_count * tangent
    if not (math.isfinite(preconditioner) and preconditioner > 0.0):
        base.update({
            "route": "FALLBACK_INVALID_PRECONDITIONER",
            "corrector_run": False,
            "coupled_candidate_published": False,
            "fallback_required": True,
            "fallback_reason": "NONFINITE_OR_NONPOSITIVE_PRECONDITIONER",
        })
        return base

    raw_dq = -residual_predictor / preconditioner
    trust_radius = TRUST_FRACTION_OF_K * max(q_scale, 1.0e-12)
    dq = clip(raw_dq, -trust_radius, trust_radius)
    qbot1 = qbot0 + dq
    corrector = run_window(theta0, table, ext, qbot1, step_count, False)
    residual_corrector = corrector["h_bottom_cm"] - target_head
    improved = abs(residual_corrector) + RESIDUAL_IMPROVEMENT_EPS < abs(residual_predictor)
    converged = abs(residual_corrector) <= HEAD_ACCEPT_TOL_CM
    mass_ok = window_mass_ok(corrector)
    finite = math.isfinite(residual_corrector)
    publish = improved and converged and mass_ok and finite

    base.update({
        "route": (
            "CORRECTOR_ACCEPTED_BY_ACTUAL_RESIDUAL_AND_MASS"
            if publish else
            "CORRECTOR_REJECTED_FALLBACK_REQUIRED"
        ),
        "preconditioner_day": preconditioner,
        "preconditioner_formula": "n_accepted_substeps_times_local_terminal_tangent",
        "raw_delta_qbot_cm_per_day": raw_dq,
        "trust_radius_cm_per_day": trust_radius,
        "applied_delta_qbot_cm_per_day": dq,
        "proposal_trust_clipped": dq != raw_dq,
        "qbot_corrector_cm_per_day": qbot1,
        "corrector_run": True,
        "corrector_residual_cm": residual_corrector,
        "actual_residual_improved": improved,
        "actual_residual_within_accept_tolerance": converged,
        "corrector_mass_ok": mass_ok,
        "corrector_checkpoint_unchanged": corrector["checkpoint_bitwise_unchanged"],
        "corrector_max_abs_step_mass_residual_cm": corrector["max_abs_step_mass_residual_cm"],
        "corrector_abs_horizon_mass_residual_cm": corrector["abs_horizon_mass_residual_cm"],
        "coupled_candidate_published": publish,
        "fallback_required": not publish,
        "fallback_reason": None if publish else (
            "ACTUAL_CORRECTOR_ACCEPTANCE_GATE_NOT_MET"
        ),
    })
    return base


def run_base_case(material, profile_name, h_first, h_last, pattern, step_count, table):
    initial_heads = gate_d.build_profile(N_CELLS, h_first, h_last)
    theta0 = tuple(gate_d.theta_from_head(h) for h in initial_heads)
    theta0_snapshot = float_bytes(theta0)
    ext = gate_f.fixed_external(initial_heads, pattern)
    qbot0 = -ext["q_bottom"]
    q_scale = max(abs(qbot0), abs(ext["k_bottom"]), 1.0e-12)

    predictor = run_window(theta0, table, ext, qbot0, step_count, True)
    fd = qualification_fd_oracle(theta0, table, ext, qbot0, q_scale, step_count, predictor)
    corrections = [
        correction_case(
            theta0, table, ext, predictor, qbot0, q_scale, step_count, offset
        )
        for offset in TARGET_HEAD_OFFSETS_CM
    ]

    local_linear_ok = (
        predictor["local_terminal_tangent_linear_residual"] is None
        or predictor["local_terminal_tangent_linear_residual"] <= LINEAR_TOL
    )
    predictor_cost_ok = (
        predictor["matrix_factorizations"] == step_count
        and predictor["normal_backsolves"] == step_count
        and predictor["local_terminal_tangent_backsolves"]
        == (1 if predictor["local_terminal_tangent_available"] else 0)
    )

    return {
        "material": material,
        "profile": profile_name,
        "source_sink_pattern": pattern,
        "n_cells": N_CELLS,
        "step_count": step_count,
        "dt_day": gate_f.HORIZON_DAY / step_count,
        "qbot_predictor_cm_per_day": qbot0,
        "predictor_h_bottom_cm": predictor["h_bottom_cm"],
        "predictor_mass_ok": window_mass_ok(predictor),
        "predictor_checkpoint_unchanged": predictor["checkpoint_bitwise_unchanged"],
        "predictor_input_mutation_count": predictor["input_mutation_count"],
        "predictor_cell_transition_count": predictor["cell_transition_count"],
        "local_terminal_tangent_available": predictor["local_terminal_tangent_available"],
        "local_terminal_dh_bottom_dqbot_day": predictor["local_terminal_dh_bottom_dqbot_day"],
        "local_terminal_tangent_scope": predictor["local_terminal_tangent_scope"],
        "local_terminal_tangent_method": predictor["local_terminal_tangent_method"],
        "local_terminal_tangent_reason": predictor["local_terminal_tangent_reason"],
        "local_terminal_tangent_is_whole_window_derivative": False,
        "local_terminal_linear_ok": local_linear_ok,
        "predictor_cost_ok": predictor_cost_ok,
        "qualification_fd": fd,
        "corrections": corrections,
        "checkpoint_bitwise_unchanged_after_all_trials": float_bytes(theta0) == theta0_snapshot,
    }


def run_material(row: dict) -> dict:
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
    for profile_name, h_first, h_last in PROFILE_FAMILIES:
        for pattern in SOURCE_PATTERNS:
            for step_count in STEP_COUNTS:
                try:
                    cases.append(
                        run_base_case(
                            material,
                            profile_name,
                            h_first,
                            h_last,
                            pattern,
                            step_count,
                            table,
                        )
                    )
                except Exception as exc:
                    errors.append({
                        "profile": profile_name,
                        "source_sink_pattern": pattern,
                        "step_count": step_count,
                        "error": repr(exc),
                    })

    table_after = hashlib.sha256(table.tobytes(order="C")).hexdigest()
    corrections = [correction for case in cases for correction in case["corrections"]]
    corrector_runs = [c for c in corrections if c.get("corrector_run", False)]
    published = [c for c in corrections if c.get("coupled_candidate_published", False)]
    fallback = [c for c in corrections if c.get("fallback_required", False)]
    tangent_cases = [c for c in cases if c["local_terminal_tangent_available"]]
    unavailable_cases = [c for c in cases if not c["local_terminal_tangent_available"]]
    smooth_fd = [
        c["qualification_fd"] for c in cases
        if c["qualification_fd"]["route_signature_same"]
        and c["qualification_fd"]["finite"]
    ]
    ratio_values = [
        fd["local_to_fd_ratio_diagnostic"] for fd in smooth_fd
        if fd["local_to_fd_ratio_diagnostic"] is not None
        and math.isfinite(fd["local_to_fd_ratio_diagnostic"])
    ]

    worsening_published = sum(
        c.get("coupled_candidate_published", False)
        and not c.get("actual_residual_improved", False)
        for c in corrections
    )
    unconverged_published = sum(
        c.get("coupled_candidate_published", False)
        and not c.get("actual_residual_within_accept_tolerance", False)
        for c in corrections
    )
    mass_bad_published = sum(
        c.get("coupled_candidate_published", False)
        and not c.get("corrector_mass_ok", False)
        for c in corrections
    )

    tests = {
        "all_requested_base_cases_executed": (
            len(cases) == len(PROFILE_FAMILIES) * len(SOURCE_PATTERNS) * len(STEP_COUNTS)
            and len(errors) == 0
        ),
        "multi_substep_only": all(c["step_count"] >= 2 for c in cases),
        "table_bitwise_unchanged": table_before == table_after,
        "predictor_mass_hard_gate": all(c["predictor_mass_ok"] for c in cases),
        "predictor_checkpoint_unchanged": all(c["predictor_checkpoint_unchanged"] for c in cases),
        "all_trial_origins_checkpoint_unchanged": all(
            c["checkpoint_bitwise_unchanged_after_all_trials"] for c in cases
        ),
        "no_predictor_input_mutation": all(c["predictor_input_mutation_count"] == 0 for c in cases),
        "local_terminal_scope_explicit": all(
            (not c["local_terminal_tangent_available"])
            or c["local_terminal_tangent_scope"] == "LOCAL_TERMINAL_SUBSTEP_ONLY"
            for c in cases
        ),
        "no_whole_window_relabelling": all(
            not c["local_terminal_tangent_is_whole_window_derivative"] for c in cases
        ),
        "same_factorization_tangent_cost_shape": all(c["predictor_cost_ok"] for c in cases),
        "local_terminal_linear_residual": all(c["local_terminal_linear_ok"] for c in cases),
        "at_least_one_local_terminal_tangent_consumed": len(corrector_runs) > 0,
        "correctors_use_same_checkpoint": all(
            c.get("corrector_started_from_same_checkpoint", False) for c in corrector_runs
        ),
        "corrector_checkpoint_unchanged": all(
            c.get("corrector_checkpoint_unchanged", False) for c in corrector_runs
        ),
        "no_worsening_corrector_published": worsening_published == 0,
        "no_unconverged_corrector_published": unconverged_published == 0,
        "no_mass_bad_corrector_published": mass_bad_published == 0,
        "at_least_one_actual_corrector_acceptance": len(published) > 0,
        "unavailable_tangent_fails_closed": all(
            all(
                correction["fallback_required"]
                and not correction["coupled_candidate_published"]
                and not correction["corrector_run"]
                for correction in case["corrections"]
            )
            for case in unavailable_cases
        ),
        "qualification_fd_not_algorithm_input": all(
            not c["qualification_fd"]["fd_is_algorithm_input"] for c in cases
        ),
        "qualification_fd_mass_and_checkpoint": all(
            c["qualification_fd"]["plus_mass_ok"]
            and c["qualification_fd"]["minus_mass_ok"]
            and c["qualification_fd"]["plus_checkpoint_unchanged"]
            and c["qualification_fd"]["minus_checkpoint_unchanged"]
            for c in cases
        ),
        "smooth_whole_window_fd_diagnostic_present": len(smooth_fd) > 0,
    }

    return {
        "material": material,
        "preprocessing_seconds_descriptive": preprocessing_seconds,
        "case_count": len(cases),
        "case_error_count": len(errors),
        "correction_case_count": len(corrections),
        "corrector_run_count": len(corrector_runs),
        "published_coupled_candidate_count": len(published),
        "fallback_required_count": len(fallback),
        "local_terminal_tangent_available_case_count": len(tangent_cases),
        "local_terminal_tangent_unavailable_case_count": len(unavailable_cases),
        "smooth_whole_window_fd_diagnostic_count": len(smooth_fd),
        "local_to_whole_window_fd_ratio_min_diagnostic": min(ratio_values) if ratio_values else None,
        "local_to_whole_window_fd_ratio_max_diagnostic": max(ratio_values) if ratio_values else None,
        "worsening_corrector_published_count": worsening_published,
        "unconverged_corrector_published_count": unconverged_published,
        "mass_bad_corrector_published_count": mass_bad_published,
        "table_sha256": table_before,
        "table_bitwise_unchanged": table_before == table_after,
        "whole_window_fd_is_qualification_only": True,
        "whole_window_derivative_claimed_by_algorithm": False,
        "preconditioner_is_derivative_claim": False,
        "tests": tests,
        "failed_metrics": [name for name, ok in tests.items() if not ok],
        "pass": all(tests.values()),
        "cases": cases,
        "errors": errors,
    }


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit(
            "usage: run_ross01_gate_j1e_d1_local_terminal_coupling_preconditioner.py MATERIAL OUTPUT.json"
        )
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
        "gate": "J1E_D1_LOCAL_TERMINAL_COUPLING_PRECONDITIONER",
        "resolution_route": "B",
        "contract": CONTRACT,
        "production_implementation": False,
        "production_admission": False,
        "f_si31_frozen_v1_modified": False,
        "full_richards_modified": False,
        "qbot_sign": "positive_upward_into_SWAP_column",
        "coupling_window_day": gate_f.HORIZON_DAY,
        "accepted_internal_substep_counts": list(STEP_COUNTS),
        "target_head_offsets_cm": list(TARGET_HEAD_OFFSETS_CM),
        "head_accept_tolerance_cm": HEAD_ACCEPT_TOL_CM,
        "trust_fraction_of_K": TRUST_FRACTION_OF_K,
        "finite_difference_factor": FD_FACTOR,
        "algorithm_contract": {
            "local_terminal_tangent_scope": "LOCAL_TERMINAL_SUBSTEP_ONLY",
            "local_terminal_tangent_is_whole_window_derivative": False,
            "preconditioner_formula": "n_accepted_substeps_times_local_terminal_tangent",
            "preconditioner_is_derivative_claim": False,
            "corrector_physical_origin": "same_immutable_committed_checkpoint_as_predictor",
            "publication_authority": "actual_corrector_head_residual_plus_hard_mass_gates",
            "worsening_or_unconverged_corrector": "reject_and_request_fallback",
        },
        "decision": (
            "QUALIFIED_RESEARCH_ROUTE_B_LOCAL_TERMINAL_TANGENT_CONSUMER_FOR_D1"
            if result["pass"] else
            "D1_ROUTE_B_NOT_YET_QUALIFIED_REVIEW_FAILED_METRICS"
        ),
    })
    out.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
    print(json.dumps({
        k: v for k, v in result.items()
        if k not in ("cases", "errors")
    }, sort_keys=True), flush=True)
    raise SystemExit(0 if result["pass"] else 1)


if __name__ == "__main__":
    main()
