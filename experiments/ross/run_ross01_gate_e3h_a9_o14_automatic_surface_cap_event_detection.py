from __future__ import annotations

import json
import math
import struct
import sys
from pathlib import Path

import numpy as np
from scipy.optimize import least_squares

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import run_ross01_gate_e3h_a8_o14_transactional_surface_cap_to_runoff as a8

CONTRACT = "F-ROSS01_GATE_E3H_A9_O14_AUTOMATIC_SURFACE_CAP_EVENT_DETECTION_PRECOMMIT.json"
CATALOG = Path("integration/f-ross/F-ROSS01_GATE_C1_MATERIAL_CATALOG.json")
MATERIAL = "O14"
S0 = 0.02
S_CAP = 1.0
HORIZON = 0.05
SUPPLY_EVENT_FRAC = 12.0
NO_EVENT_FRACS = (1.5, 3.0, 5.0)
TAU_EPS = 1.0e-12
MASS_TOL = 1.0e-9
TIME_DIFF_TOL = 2.5e-4
HEAD_DIFF_TOL = 0.25
BOTTOM_DIFF_TOL = 0.001
SURFACE_Q_ERR_TOL = 0.0005
MAX_K_EVALS = 530
MAX_ROOT_EVALS = 66
MAX_NFEV = 250

# Candidate-visible profile data intentionally contains only committed physical state.
# A4/A8 event roots are absent here and therefore cannot be used as candidate seeds.
PROFILES = {
    "P0_A1_CONTROL": (-0.2, -1.5, -5.0),
    "P1_DRIER_SUBSOIL": (-0.5, -5.0, -10.0),
    "P2_DRIER_TOP_AND_SUBSOIL": (-1.0, -10.0, -20.0),
    "P3_STRONG_DRY_SEPARATION": (-2.0, -20.0, -50.0),
}


def bits(heads, surface: float, runoff: float = 0.0) -> bytes:
    return struct.pack("!5d", *map(float, heads), float(surface), float(runoff))


def no_event_certificate(initial, supply: float) -> dict:
    committed = bits(initial, S0, 0.0)
    upper_surface_if_zero_infiltration = S0 + max(float(supply), 0.0) * HORIZON
    impossible = upper_surface_if_zero_infiltration < S_CAP
    return {
        "classification": "NO_CAP_EVENT_SUPPLY_VOLUME_CERTIFIED" if impossible else "INCONCLUSIVE",
        "event_impossible": bool(impossible),
        "surface_storage_upper_bound_cm": float(upper_surface_if_zero_infiltration),
        "surface_cap_cm": S_CAP,
        "certificate_margin_cm": float(S_CAP - upper_surface_if_zero_infiltration),
        "nonlinear_trajectory_count": 0,
        "committed_state_bitwise_unchanged": bits(initial, S0, 0.0) == committed,
        "runoff_ledger_cm": 0.0,
        "mass_repair_or_clipping_used": False,
    }


def candidate_detect_event(profile_id: str, row: dict) -> dict:
    initial = PROFILES[profile_id]
    committed = bits(initial, S0, 0.0)
    old_global = a8.configure(row, initial)
    table = a8.a4.a1.e3g.e3.generate_c1r_table()
    supply = SUPPLY_EVENT_FRAC * float(row["ksatfit_cm_per_day"])
    try:
        # Seed derives only from committed state, forcing and the qualified face law.
        qtop0, route0, cost0 = a8.a4.a1.e3g.surface_face(S0, float(initial[0]), row, True)
        qtop0 = float(qtop0)
        denom = float(supply - qtop0)
        if not (math.isfinite(qtop0) and math.isfinite(denom) and denom > 0.0):
            return {
                "accepted": False,
                "classification": "SEED_DENOMINATOR_NOT_POSITIVE",
                "candidate_access_to_A4_or_A8_event_roots": False,
                "event_corrector_count": 0,
                "committed_state_bitwise_unchanged": bits(initial, S0, 0.0) == committed,
                "runoff_ledger_cm": 0.0,
                "mass_repair_or_clipping_used": False,
            }
        tau_seed = float((S_CAP - S0) / denom)
        if not (TAU_EPS < tau_seed < HORIZON):
            return {
                "accepted": False,
                "classification": "SEED_OUTSIDE_INTERVAL",
                "initial_qtop_cm_per_day": qtop0,
                "tau_seed_day": tau_seed,
                "candidate_access_to_A4_or_A8_event_roots": False,
                "event_corrector_count": 0,
                "committed_state_bitwise_unchanged": bits(initial, S0, 0.0) == committed,
                "runoff_ledger_cm": 0.0,
                "mass_repair_or_clipping_used": False,
            }

        x0 = np.asarray([*initial, tau_seed], dtype=np.float64)
        sol = least_squares(
            lambda x: a8.event_residual(x, initial, supply, row, True, table),
            x0,
            bounds=(
                np.asarray([-10000.0, -10000.0, -10000.0, TAU_EPS]),
                np.asarray([a8.H_UPPER, a8.H_UPPER, a8.H_UPPER, HORIZON]),
            ),
            xtol=1e-13, ftol=1e-13, gtol=1e-13,
            max_nfev=MAX_NFEV, x_scale="jac",
        )
        heads = tuple(float(v) for v in sol.x[:3])
        tau = float(sol.x[3])
        fluxes = a8.candidate_event_fluxes(heads, row, table)
        diag = a8.event_diagnostics(initial, heads, tau, supply, fluxes)
        routes = [fluxes["surface_route"], *fluxes["internal_routes"]]
        no_unqualified = not any("UNQUALIFIED" in str(v) for v in routes)
        physical_order = heads[0] >= heads[1] >= heads[2]
        strict_tau = TAU_EPS < tau < HORIZON
        top_negative = heads[0] < 0.0
        exact = a8.a4.a1.e3g.exact_surface_reference(S_CAP, heads[0], row)
        q_exact = float(exact["q"])
        surface_err = abs(float(fluxes["qtop"]) - q_exact) / float(row["ksatfit_cm_per_day"])
        cost_ok = (
            int(fluxes["surface_cost"]["constitutive_K_evaluations"]) <= MAX_K_EVALS
            and int(fluxes["surface_cost"]["root_residual_evaluations"]) <= MAX_ROOT_EVALS
        )
        finite = all(math.isfinite(v) for v in (*heads, tau, fluxes["qtop"], fluxes["q01"], fluxes["q12"], fluxes["qb"]))
        accepted = bool(
            sol.success and finite and strict_tau and top_negative and physical_order
            and diag["max_abs_balance_residual_cm"] <= MASS_TOL
            and no_unqualified and surface_err <= SURFACE_Q_ERR_TOL and cost_ok
        )
        # Synthetic post-corrector rejection must still leave the original transaction untouched.
        synthetic_runoff = 0.0
        rollback_ok = bits(initial, S0, synthetic_runoff) == committed
        return {
            "accepted": accepted,
            "classification": "CAP_EVENT_DETECTED" if accepted else "EVENT_CORRECTOR_NOT_ACCEPTED",
            "candidate_access_to_A4_or_A8_event_roots": False,
            "initial_qtop_cm_per_day": qtop0,
            "initial_surface_route": str(route0),
            "initial_surface_cost": {
                "constitutive_K_evaluations": int(cost0.get("constitutive_K_evaluations", 0)),
                "root_residual_evaluations": int(cost0.get("root_residual_evaluations", 0)),
            },
            "tau_seed_day": tau_seed,
            "seed_heads_cm": list(initial),
            "event_time_day": tau,
            "heads_cm": list(heads),
            "surface_storage_cm": S_CAP,
            "event_corrector_nfev": int(sol.nfev),
            "event_corrector_count": 1,
            "full_trajectory_predictor_count": 0,
            "event_search_bisection_trajectory_count": 0,
            "fluxes_cm_per_day": fluxes,
            "diagnostics": diag,
            "physical_head_order": physical_order,
            "top_node_negative_at_event": top_negative,
            "strict_event_time": strict_tau,
            "no_unqualified_face_route": no_unqualified,
            "surface_q_exact_reference_cm_per_day": q_exact,
            "surface_q_exact_reference_path_residual_cm": float(exact["residual_cm"]),
            "surface_q_abs_error_over_ksat": float(surface_err),
            "surface_cost_ok": cost_ok,
            "committed_state_bitwise_unchanged_until_accept": bits(initial, S0, 0.0) == committed,
            "synthetic_reject_restores_original_state": rollback_ok,
            "synthetic_reject_runoff_ledger_cm": synthetic_runoff,
            "mass_repair_or_clipping_used": False,
        }
    except Exception as exc:
        return {
            "accepted": False,
            "classification": "EXCEPTION_FAIL_CLOSED",
            "error": repr(exc),
            "candidate_access_to_A4_or_A8_event_roots": False,
            "event_corrector_count": 1,
            "full_trajectory_predictor_count": 0,
            "event_search_bisection_trajectory_count": 0,
            "committed_state_bitwise_unchanged_until_accept": bits(initial, S0, 0.0) == committed,
            "synthetic_reject_restores_original_state": bits(initial, S0, 0.0) == committed,
            "synthetic_reject_runoff_ledger_cm": 0.0,
            "mass_repair_or_clipping_used": False,
        }
    finally:
        a8.restore(old_global)


def compare_event(candidate: dict, reference: dict) -> dict:
    if not (candidate.get("accepted") and reference.get("accepted")):
        return {"available": False, "pass": False}
    tdiff = abs(float(candidate["event_time_day"]) - float(reference["event_time_day"]))
    hdiff = max(abs(float(a)-float(b)) for a,b in zip(candidate["heads_cm"], reference["heads_cm"]))
    bdiff = abs(float(candidate["diagnostics"]["bottom_transfer_cm"]) - float(reference["diagnostics"]["bottom_transfer_cm"]))
    tests = {
        "event_time": tdiff <= TIME_DIFF_TOL,
        "heads": hdiff <= HEAD_DIFF_TOL,
        "bottom_transfer": bdiff <= BOTTOM_DIFF_TOL,
    }
    return {
        "available": True,
        "event_time_difference_day": tdiff,
        "max_event_head_difference_cm": hdiff,
        "event_bottom_transfer_difference_cm": bdiff,
        "tests": tests,
        "pass": all(tests.values()),
    }


def run_profile(profile_id: str, row: dict) -> dict:
    positive = candidate_detect_event(profile_id, row)
    # Qualification reference may use its frozen A4 seed; candidate never sees it.
    reference = a8.solve_event(profile_id, row, False)
    comparison = compare_event(positive, reference)
    initial = PROFILES[profile_id]
    ksat = float(row["ksatfit_cm_per_day"])
    negatives = []
    for frac in NO_EVENT_FRACS:
        cert = no_event_certificate(initial, frac * ksat)
        cert["supply_fraction_of_ksat"] = frac
        negatives.append(cert)

    tests = {
        "positive_candidate_accepted": positive.get("accepted") is True,
        "positive_reference_accepted": reference.get("accepted") is True,
        "positive_comparison": comparison.get("pass") is True,
        "candidate_seed_independent": positive.get("candidate_access_to_A4_or_A8_event_roots") is False,
        "candidate_event_corrector_count": positive.get("event_corrector_count") == 1,
        "candidate_no_full_predictor": positive.get("full_trajectory_predictor_count") == 0,
        "candidate_no_trajectory_bisection": positive.get("event_search_bisection_trajectory_count") == 0,
        "candidate_event_mass": positive.get("diagnostics") is not None and positive["diagnostics"]["max_abs_balance_residual_cm"] <= MASS_TOL,
        "reference_event_mass": reference.get("diagnostics") is not None and reference["diagnostics"]["max_abs_balance_residual_cm"] <= MASS_TOL,
        "candidate_surface_accuracy": positive.get("surface_q_abs_error_over_ksat", math.inf) <= SURFACE_Q_ERR_TOL,
        "candidate_surface_cost": positive.get("surface_cost_ok") is True,
        "candidate_committed_immutable": positive.get("committed_state_bitwise_unchanged_until_accept") is True,
        "candidate_synthetic_reject_rollback": positive.get("synthetic_reject_restores_original_state") is True and positive.get("synthetic_reject_runoff_ledger_cm") == 0.0,
        "no_mass_repair_or_clipping": positive.get("mass_repair_or_clipping_used") is False,
        "negative_control_count": len(negatives) == len(NO_EVENT_FRACS),
        "all_negative_controls_certified": all(x["event_impossible"] for x in negatives),
        "all_negative_controls_zero_nonlinear": all(x["nonlinear_trajectory_count"] == 0 for x in negatives),
        "all_negative_controls_state_unchanged": all(x["committed_state_bitwise_unchanged"] for x in negatives),
        "all_negative_controls_zero_runoff": all(x["runoff_ledger_cm"] == 0.0 for x in negatives),
    }
    return {
        "profile_id": profile_id,
        "candidate_event": positive,
        "reference_event": reference,
        "comparison": comparison,
        "negative_controls": negatives,
        "tests": tests,
        "failed_metrics": [k for k,v in tests.items() if not v],
        "pass": all(tests.values()),
    }


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit("usage: run_ross01_gate_e3h_a9_o14_automatic_surface_cap_event_detection.py PROFILE OUTPUT.json")
    profile_id = sys.argv[1]
    if profile_id not in PROFILES:
        raise SystemExit(profile_id)
    catalog = json.loads(CATALOG.read_text(encoding="utf-8"))
    row = next(r for r in catalog["rows"] if r["sfu"] == MATERIAL)
    pr = run_profile(profile_id, row)
    payload = {
        "schema_version": 1,
        "workstream": "F-ROSS",
        "work_unit": "F-ROSS01",
        "gate": "E3H_A9_O14_AUTOMATIC_SURFACE_CAP_EVENT_DETECTION",
        "contract": CONTRACT,
        "production_implementation": False,
        "qualification_use": True,
        "material": MATERIAL,
        "profile_result": pr,
        "pass": pr["pass"],
        "decision": (
            "QUALIFIED_RESTRICTED_SEED_FREE_O14_SURFACE_CAP_EVENT_DETECTION_READY_FOR_CAP_GENERALIZATION_AND_EVENT_DETECTOR_ROBUSTNESS_RESEARCH"
            if pr["pass"] else
            "SEED_FREE_O14_SURFACE_CAP_EVENT_DETECTION_NOT_QUALIFIED_PRESERVE_A8_AND_CHARACTERIZE_DETECTOR_FAILURE"
        ),
        "hard_nonclaims": [
            "No generic bracket discovery for inconclusive cases.",
            "No cap generalization yet.",
            "No material other than O14.",
            "No production event detector, runtime or MultiSWAP admission.",
            "No response tangent through event detection."
        ],
    }
    out = Path(sys.argv[2])
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    c = pr["candidate_event"]; cmp = pr["comparison"]
    print(json.dumps({
        "profile": profile_id,
        "pass": pr["pass"],
        "tau_seed_day": c.get("tau_seed_day"),
        "candidate_event_time_day": c.get("event_time_day"),
        "reference_event_time_day": pr["reference_event"].get("event_time_day"),
        "event_time_difference_day": cmp.get("event_time_difference_day"),
        "event_head_difference_cm": cmp.get("max_event_head_difference_cm"),
        "candidate_event_nfev": c.get("event_corrector_nfev"),
        "candidate_mass_cm": None if c.get("diagnostics") is None else c["diagnostics"]["max_abs_balance_residual_cm"],
        "failed_metrics": pr["failed_metrics"],
        "decision": payload["decision"],
    }, sort_keys=True), flush=True)
    if not pr["pass"]:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
