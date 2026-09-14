from __future__ import annotations

import json
import math
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import run_ross01_gate_j1e_d1_local_terminal_coupling_preconditioner as base

HEAD_TRUST_RADIUS_CM = 0.05
PRECONDITIONER_FD_RATIO_MIN = 0.90
PRECONDITIONER_FD_RATIO_MAX = 1.10


def correction_case(theta0, table, ext, predictor, qbot0, q_scale, step_count, target_offset):
    """Consume the local-terminal tangent only as bounded proposal scaling.

    The trust region is expressed in the interface residual coordinate, not in
    hydraulic conductivity.  This avoids silently turning a physical material
    property into a numerical-policy cap.  B_pre remains a preconditioner, not
    a whole-window derivative.  Acceptance is determined only by the actual
    full-window corrector result and hard mass gates.
    """
    del q_scale
    target_head = predictor["h_bottom_cm"] + target_offset
    residual_predictor = predictor["h_bottom_cm"] - target_head
    tangent = predictor["local_terminal_dh_bottom_dqbot_day"]

    result = {
        "target_head_offset_cm": target_offset,
        "target_head_cm": target_head,
        "predictor_residual_cm": residual_predictor,
        "predictor_within_accept_tolerance": abs(residual_predictor) <= base.HEAD_ACCEPT_TOL_CM,
        "local_terminal_tangent_available": predictor["local_terminal_tangent_available"],
        "local_terminal_tangent_scope": predictor["local_terminal_tangent_scope"],
        "local_terminal_tangent_is_whole_window_derivative": False,
        "preconditioner_is_whole_window_derivative": False,
        "corrector_started_from_same_checkpoint": True,
        "head_trust_radius_cm": HEAD_TRUST_RADIUS_CM,
    }

    if not predictor["local_terminal_tangent_available"] or tangent is None:
        result.update({
            "route": "FALLBACK_LOCAL_TERMINAL_TANGENT_UNAVAILABLE",
            "corrector_attempted": False,
            "corrector_run": False,
            "coupled_candidate_published": False,
            "fallback_required": True,
            "fallback_reason": predictor["local_terminal_tangent_reason"],
        })
        return result

    preconditioner = step_count * tangent
    if not (math.isfinite(preconditioner) and preconditioner > 0.0):
        result.update({
            "route": "FALLBACK_INVALID_PRECONDITIONER",
            "corrector_attempted": False,
            "corrector_run": False,
            "coupled_candidate_published": False,
            "fallback_required": True,
            "fallback_reason": "NONFINITE_OR_NONPOSITIVE_PRECONDITIONER",
        })
        return result

    requested_head_update = -residual_predictor
    bounded_head_update = base.clip(
        requested_head_update, -HEAD_TRUST_RADIUS_CM, HEAD_TRUST_RADIUS_CM
    )
    dq = bounded_head_update / preconditioner
    qbot1 = qbot0 + dq

    result.update({
        "preconditioner_day": preconditioner,
        "preconditioner_formula": "n_accepted_substeps_times_local_terminal_tangent",
        "preconditioner_is_derivative_claim": False,
        "requested_head_update_cm": requested_head_update,
        "bounded_head_update_cm": bounded_head_update,
        "proposal_head_trust_clipped": bounded_head_update != requested_head_update,
        "applied_delta_qbot_cm_per_day": dq,
        "qbot_corrector_cm_per_day": qbot1,
        "corrector_attempted": True,
    })

    try:
        corrector = base.run_window(theta0, table, ext, qbot1, step_count, False)
    except Exception as exc:
        result.update({
            "route": "CORRECTOR_TRIAL_INVALID_FALLBACK_REQUIRED",
            "corrector_run": False,
            "coupled_candidate_published": False,
            "fallback_required": True,
            "fallback_reason": "INVALID_CORRECTOR_TRIAL",
            "corrector_exception": repr(exc),
        })
        return result

    residual_corrector = corrector["h_bottom_cm"] - target_head
    improved = (
        abs(residual_corrector) + base.RESIDUAL_IMPROVEMENT_EPS
        < abs(residual_predictor)
    )
    converged = abs(residual_corrector) <= base.HEAD_ACCEPT_TOL_CM
    mass_ok = base.window_mass_ok(corrector)
    finite = math.isfinite(residual_corrector)
    publish = improved and converged and mass_ok and finite

    result.update({
        "route": (
            "CORRECTOR_ACCEPTED_BY_ACTUAL_RESIDUAL_AND_MASS"
            if publish else "CORRECTOR_REJECTED_FALLBACK_REQUIRED"
        ),
        "corrector_run": True,
        "corrector_residual_cm": residual_corrector,
        "actual_residual_improved": improved,
        "actual_residual_within_accept_tolerance": converged,
        "corrector_mass_ok": mass_ok,
        "corrector_checkpoint_unchanged": corrector["checkpoint_bitwise_unchanged"],
        "corrector_max_abs_step_mass_residual_cm": corrector["max_abs_step_mass_residual_cm"],
        "corrector_abs_horizon_mass_residual_cm": corrector["abs_horizon_mass_residual_cm"],
        "corrector_route_changed_from_predictor": (
            corrector["route_signature"] != predictor["route_signature"]
        ),
        "coupled_candidate_published": publish,
        "fallback_required": not publish,
        "fallback_reason": None if publish else "ACTUAL_CORRECTOR_ACCEPTANCE_GATE_NOT_MET",
    })
    return result


# Preserve the first executable D1 attempt as provenance.  Override only the
# correction proposal policy; the RossFast window integrator, terminal tangent,
# mass accounting, finite-difference qualification oracle and material matrix
# remain exactly the same.
base.correction_case = correction_case


def add_preconditioner_qualification(result: dict) -> None:
    ratios = []
    for case in result.get("cases", []):
        fd = case["qualification_fd"]
        local = case.get("local_terminal_dh_bottom_dqbot_day")
        if (
            fd.get("route_signature_same")
            and fd.get("finite")
            and local is not None
            and math.isfinite(local)
            and fd.get("whole_window_fd_day_diagnostic") not in (None, 0.0)
        ):
            b_pre = case["step_count"] * local
            fd_value = fd["whole_window_fd_day_diagnostic"]
            ratio = b_pre / fd_value
            fd["preconditioner_to_whole_window_fd_ratio_diagnostic"] = ratio
            fd["preconditioner_matches_fd_is_derivative_claim"] = False
            ratios.append(ratio)

    scaling_ok = bool(ratios) and all(
        PRECONDITIONER_FD_RATIO_MIN <= value <= PRECONDITIONER_FD_RATIO_MAX
        for value in ratios
    )
    result["preconditioner_to_whole_window_fd_ratio_min_diagnostic"] = (
        min(ratios) if ratios else None
    )
    result["preconditioner_to_whole_window_fd_ratio_max_diagnostic"] = (
        max(ratios) if ratios else None
    )
    result["preconditioner_fd_ratio_qualification_band"] = [
        PRECONDITIONER_FD_RATIO_MIN,
        PRECONDITIONER_FD_RATIO_MAX,
    ]
    result["preconditioner_scaling_fd_consistency_is_derivative_claim"] = False
    result["tests"]["qualification_preconditioner_scaling_consistency"] = scaling_ok
    result["failed_metrics"] = [
        name for name, ok in result["tests"].items() if not ok
    ]
    result["pass"] = all(result["tests"].values())


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit(
            "usage: run_ross01_gate_j1e_d1_head_space_trust_preconditioner.py MATERIAL OUTPUT.json"
        )
    material = sys.argv[1]
    out = Path(sys.argv[2])
    catalog = json.loads(base.j1a.CATALOG.read_text())
    by_name = {row["sfu"]: row for row in catalog["rows"]}
    if material not in base.MATERIALS or material not in by_name:
        raise SystemExit(f"material must be one of {base.MATERIALS}")

    result = base.run_material(by_name[material])
    add_preconditioner_qualification(result)
    result.update({
        "schema_version": 2,
        "workstream": "F-ROSS",
        "work_unit": "F-ROSS01",
        "gate": "J1E_D1_LOCAL_TERMINAL_COUPLING_PRECONDITIONER",
        "resolution_route": "B",
        "contract": base.CONTRACT,
        "supersedes_first_execution_policy": "K_SCALED_FLUX_TRUST_RADIUS",
        "first_execution_policy_retained_as_provenance": True,
        "production_implementation": False,
        "production_admission": False,
        "f_si31_frozen_v1_modified": False,
        "full_richards_modified": False,
        "qbot_sign": "positive_upward_into_SWAP_column",
        "coupling_window_day": base.gate_f.HORIZON_DAY,
        "accepted_internal_substep_counts": list(base.STEP_COUNTS),
        "target_head_offsets_cm": list(base.TARGET_HEAD_OFFSETS_CM),
        "head_accept_tolerance_cm": base.HEAD_ACCEPT_TOL_CM,
        "head_trust_radius_cm": HEAD_TRUST_RADIUS_CM,
        "finite_difference_factor": base.FD_FACTOR,
        "algorithm_contract": {
            "local_terminal_tangent_scope": "LOCAL_TERMINAL_SUBSTEP_ONLY",
            "local_terminal_tangent_is_whole_window_derivative": False,
            "preconditioner_formula": "n_accepted_substeps_times_local_terminal_tangent",
            "preconditioner_is_derivative_claim": False,
            "proposal_bound_coordinate": "interface_head_residual_cm",
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
        key: value for key, value in result.items()
        if key not in ("cases", "errors")
    }, sort_keys=True), flush=True)
    raise SystemExit(0 if result["pass"] else 1)


if __name__ == "__main__":
    main()
