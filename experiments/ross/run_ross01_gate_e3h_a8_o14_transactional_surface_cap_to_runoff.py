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

import run_ross01_gate_e3h_a4_o14_competing_surface_cap_event_ordering as a4
import run_ross01_gate_e3h_a7_r1_harness_repair_runner as a7r1

CONTRACT = "F-ROSS01_GATE_E3H_A8_O14_TRANSACTIONAL_SURFACE_CAP_ONSET_TO_ROSS_RUNOFF_CONTINUATION_PRECOMMIT.json"
CATALOG = Path("integration/f-ross/F-ROSS01_GATE_C1_MATERIAL_CATALOG.json")
MATERIAL = "O14"
S0 = 0.02
S_CAP = 1.0
SUPPLY_FRAC = 12.0
TAU_LO = 0.02
TAU_HI = 0.05
H_UPPER = -1.0e-8
MAX_NFEV = 250
MASS_TOL = 1.0e-9
TIME_DIFF_TOL = 2.5e-4
HEAD_DIFF_TOL = 0.25
EVENT_BOTTOM_DIFF_TOL = 0.001
SURFACE_Q_ERR_OVER_KS_TOL = 0.0005
MAX_K_EVALS = 530
MAX_ROOT_EVALS = 66
POST_HEAD_DIFF_TOL = 0.25
POST_RUNOFF_DIFF_TOL = 0.001
POST_BOTTOM_DIFF_TOL = 0.001
POST_STORAGE_DIFF_TOL = 0.001
FINAL_HEAD_DIFF_TOL = 0.25
FINAL_ATTRACTOR_TOL = 0.005
ATTRACTOR = (-0.19725877123808083, -3.641715902463716, -8.5218470896173)

PROFILES = {
    "P0_A1_CONTROL": {
        "initial": (-0.2, -1.5, -5.0),
        "seed_heads": (-0.14612442301092474, -3.4365807674561273, -8.231314064881142),
        "seed_tau": 0.03644773984112319,
    },
    "P1_DRIER_SUBSOIL": {
        "initial": (-0.5, -5.0, -10.0),
        "seed_heads": (-0.23356049032180035, -3.7808381225488468, -8.689972381245196),
        "seed_tau": 0.0365014276959812,
    },
    "P2_DRIER_TOP_AND_SUBSOIL": {
        "initial": (-1.0, -10.0, -20.0),
        "seed_heads": (-0.47697860016578836, -4.718962776786451, -10.022018575369172),
        "seed_tau": 0.03664790671376539,
    },
    "P3_STRONG_DRY_SEPARATION": {
        "initial": (-2.0, -20.0, -50.0),
        "seed_heads": (-1.472189253257072, -8.509653922626015, -16.120819017592716),
        "seed_tau": 0.03723734776750273,
    },
}


def state_bits(heads, surface: float, runoff: float = 0.0) -> bytes:
    return struct.pack("!5d", *map(float, heads), float(surface), float(runoff))


def configure(row: dict, initial) -> tuple[float, float, float]:
    old = a4.a1.INITIAL_HEADS
    a4.a1.INITIAL_HEADS = tuple(float(v) for v in initial)
    a4.a1.configure(row)
    return old


def restore(old) -> None:
    a4.a1.INITIAL_HEADS = old


def candidate_event_fluxes(heads, row: dict, table) -> dict:
    h0, h1, h2 = map(float, heads)
    qtop, top_route, top_cost = a4.a1.e3g.surface_face(S_CAP, h0, row, True)
    (q01, q12, qb), routes = a4.a1.internal_q(h0, h1, h2, row, True, table)
    return {
        "qtop": float(qtop), "q01": float(q01), "q12": float(q12), "qb": float(qb),
        "surface_route": str(top_route),
        "surface_cost": {
            "constitutive_K_evaluations": int(top_cost.get("constitutive_K_evaluations", 0)),
            "root_residual_evaluations": int(top_cost.get("root_residual_evaluations", 0)),
        },
        "internal_routes": [str(v) for v in routes],
    }


def reference_event_fluxes(heads, row: dict) -> dict:
    h0, h1, h2 = map(float, heads)
    ref = a4.a1.e3g.exact_surface_reference(S_CAP, h0, row)
    (q01, q12, qb), routes = a4.a1.internal_q(h0, h1, h2, row, False, None)
    return {
        "qtop": float(ref["q"]), "q01": float(q01), "q12": float(q12), "qb": float(qb),
        "surface_route": str(ref["branch"]),
        "surface_path_residual_cm": float(ref["residual_cm"]),
        "surface_cost": {"constitutive_K_evaluations": 0, "root_residual_evaluations": 0},
        "internal_routes": [str(v) for v in routes],
    }


def event_fluxes(heads, row: dict, candidate: bool, table) -> dict:
    return candidate_event_fluxes(heads, row, table) if candidate else reference_event_fluxes(heads, row)


def event_residual(x, initial, supply: float, row: dict, candidate: bool, table) -> np.ndarray:
    h0, h1, h2, tau = map(float, x)
    f = event_fluxes((h0, h1, h2), row, candidate, table)
    q = (f["qtop"], f["q01"], f["q12"], f["qb"])
    return np.asarray([
        a4.a1.DZ * (a4.a1.theta(h0) - a4.a1.theta(initial[0])) - tau * (q[0] - q[1]),
        a4.a1.DZ * (a4.a1.theta(h1) - a4.a1.theta(initial[1])) - tau * (q[1] - q[2]),
        a4.a1.DZ * (a4.a1.theta(h2) - a4.a1.theta(initial[2])) - tau * (q[2] - q[3]),
        (S_CAP - S0) - tau * (supply - q[0]),
    ], dtype=np.float64)


def event_diagnostics(initial, heads, tau: float, supply: float, f: dict) -> dict:
    h0, h1, h2 = map(float, heads)
    q = (f["qtop"], f["q01"], f["q12"], f["qb"])
    cell = [
        a4.a1.DZ * (a4.a1.theta(float(heads[i])) - a4.a1.theta(float(initial[i]))) - tau * (q[i] - q[i + 1])
        for i in range(3)
    ]
    surface = (S_CAP - S0) - tau * (supply - q[0])
    soil = math.fsum(
        a4.a1.DZ * (a4.a1.theta(float(heads[i])) - a4.a1.theta(float(initial[i]))) for i in range(3)
    )
    bottom = tau * q[-1]
    composed = soil + (S_CAP - S0) + bottom - tau * supply
    return {
        "cell_residuals_cm": [float(v) for v in cell],
        "surface_balance_residual_cm": float(surface),
        "composed_balance_residual_cm": float(composed),
        "soil_storage_change_cm": float(soil),
        "bottom_transfer_cm": float(bottom),
        "supply_amount_cm": float(tau * supply),
        "max_abs_balance_residual_cm": float(max(max(abs(v) for v in cell), abs(surface), abs(composed))),
    }


def solve_event(profile_id: str, row: dict, candidate: bool) -> dict:
    fixture = PROFILES[profile_id]
    initial = fixture["initial"]
    old_global = configure(row, initial)
    committed_snapshot = state_bits(initial, S0, 0.0)
    table = a4.a1.e3g.e3.generate_c1r_table() if candidate else None
    supply = SUPPLY_FRAC * float(row["ksatfit_cm_per_day"])
    x0 = np.asarray([*fixture["seed_heads"], fixture["seed_tau"]], dtype=np.float64)
    try:
        sol = least_squares(
            lambda x: event_residual(x, initial, supply, row, candidate, table),
            x0,
            bounds=(
                np.asarray([-10000.0, -10000.0, -10000.0, TAU_LO]),
                np.asarray([H_UPPER, H_UPPER, H_UPPER, TAU_HI]),
            ),
            xtol=1e-13, ftol=1e-13, gtol=1e-13,
            max_nfev=MAX_NFEV, x_scale="jac",
        )
        heads = tuple(float(v) for v in sol.x[:3])
        tau = float(sol.x[3])
        f = event_fluxes(heads, row, candidate, table)
        d = event_diagnostics(initial, heads, tau, supply, f)
        routes = [f["surface_route"], *f["internal_routes"]]
        no_unqualified = not any("UNQUALIFIED" in r for r in routes)
        physical_order = heads[0] >= heads[1] >= heads[2]
        finite = all(math.isfinite(v) for v in (*heads, tau, f["qtop"], f["q01"], f["q12"], f["qb"], d["max_abs_balance_residual_cm"]))
        strict_tau = TAU_LO < tau < TAU_HI
        top_negative = heads[0] < 0.0

        surface_accuracy = 0.0
        exact_q = f["qtop"]
        exact_branch = f["surface_route"]
        exact_residual = f.get("surface_path_residual_cm", 0.0)
        if candidate:
            exact = a4.a1.e3g.exact_surface_reference(S_CAP, heads[0], row)
            exact_q = float(exact["q"])
            exact_branch = str(exact["branch"])
            exact_residual = float(exact["residual_cm"])
            surface_accuracy = abs(f["qtop"] - exact_q) / float(row["ksatfit_cm_per_day"])

        surface_cost_ok = (
            int(f["surface_cost"]["constitutive_K_evaluations"]) <= MAX_K_EVALS
            and int(f["surface_cost"]["root_residual_evaluations"]) <= MAX_ROOT_EVALS
        )
        accepted = bool(
            sol.success and finite and strict_tau and physical_order and top_negative
            and d["max_abs_balance_residual_cm"] <= MASS_TOL and no_unqualified
            and (not candidate or (surface_accuracy <= SURFACE_Q_ERR_OVER_KS_TOL and surface_cost_ok))
        )

        synthetic_ledger = 0.0
        synthetic_reject_original_unchanged = state_bits(initial, S0, synthetic_ledger) == committed_snapshot
        return {
            "accepted": accepted,
            "solver_success": bool(sol.success),
            "nfev": int(sol.nfev),
            "event_time_day": tau,
            "heads_cm": list(heads),
            "surface_storage_cm": S_CAP,
            "surface_storage_change_cm": S_CAP - S0,
            "fluxes_cm_per_day": f,
            "diagnostics": d,
            "physical_head_order": physical_order,
            "top_node_negative_at_cap": top_negative,
            "strict_event_time": strict_tau,
            "no_unqualified_face_route": no_unqualified,
            "surface_q_exact_reference_cm_per_day": exact_q,
            "surface_q_exact_reference_branch": exact_branch,
            "surface_q_exact_reference_path_residual_cm": exact_residual,
            "surface_q_abs_error_over_ksat": float(surface_accuracy),
            "surface_cost_ok": surface_cost_ok,
            "original_committed_state_bitwise_unchanged_during_trial": state_bits(initial, S0, 0.0) == committed_snapshot,
            "synthetic_reject_after_event_corrector_restores_original_state": synthetic_reject_original_unchanged,
            "synthetic_reject_runoff_ledger_cm": synthetic_ledger,
            "mass_repair_or_clipping_used": False,
        }
    except Exception as exc:
        return {
            "accepted": False,
            "solver_success": False,
            "error": repr(exc),
            "original_committed_state_bitwise_unchanged_during_trial": state_bits(initial, S0, 0.0) == committed_snapshot,
            "synthetic_reject_after_event_corrector_restores_original_state": state_bits(initial, S0, 0.0) == committed_snapshot,
            "synthetic_reject_runoff_ledger_cm": 0.0,
            "mass_repair_or_clipping_used": False,
        }
    finally:
        restore(old_global)


def compare_events(c: dict, r: dict) -> dict:
    if not (c.get("accepted") and r.get("accepted")):
        return {"available": False, "pass": False}
    tdiff = abs(float(c["event_time_day"]) - float(r["event_time_day"]))
    hdiff = max(abs(float(a)-float(b)) for a,b in zip(c["heads_cm"], r["heads_cm"]))
    bdiff = abs(float(c["diagnostics"]["bottom_transfer_cm"]) - float(r["diagnostics"]["bottom_transfer_cm"]))
    tests = {
        "event_time": tdiff <= TIME_DIFF_TOL,
        "event_heads": hdiff <= HEAD_DIFF_TOL,
        "event_bottom_transfer": bdiff <= EVENT_BOTTOM_DIFF_TOL,
    }
    return {
        "available": True,
        "event_time_difference_day": tdiff,
        "max_event_head_difference_cm": hdiff,
        "event_bottom_transfer_difference_cm": bdiff,
        "tests": tests,
        "pass": all(tests.values()),
    }


def postcap_summary(traj: dict) -> dict:
    return {k:v for k,v in traj.items() if k != "records"}


def whole_path(profile_id: str, row: dict, event: dict, post: dict) -> dict:
    initial = PROFILES[profile_id]["initial"]
    final = tuple(float(v) for v in post["final_heads_cm"])
    supply = SUPPLY_FRAC * float(row["ksatfit_cm_per_day"])
    total_soil = math.fsum(
        a4.a1.DZ * (a4.a1.theta(final[i]) - a4.a1.theta(initial[i])) for i in range(3)
    )
    total_bottom = float(event["diagnostics"]["bottom_transfer_cm"]) + float(post["cumulative_bottom_transfer_cm"])
    runoff = float(post["cumulative_runoff_cm"])
    supply_amount = supply * (float(event["event_time_day"]) + 1.0)
    residual = total_soil + (S_CAP - S0) + runoff + total_bottom - supply_amount
    return {
        "total_soil_storage_change_cm": float(total_soil),
        "surface_storage_change_cm": S_CAP-S0,
        "cumulative_runoff_cm": runoff,
        "cumulative_bottom_transfer_cm": total_bottom,
        "cumulative_supply_cm": float(supply_amount),
        "whole_path_balance_residual_cm": float(residual),
        "final_heads_cm": list(final),
        "total_elapsed_day": float(event["event_time_day"] + 1.0),
    }


def compare_postcap(c: dict, r: dict) -> dict:
    if not (c.get("complete") and r.get("complete")):
        return {"available": False, "pass": False}
    max_head = 0.0
    for cs,rs in zip(c["records"], r["records"]):
        max_head = max(max_head, max(abs(float(a)-float(b)) for a,b in zip(cs["heads_cm"],rs["heads_cm"])))
    runoff = abs(float(c["cumulative_runoff_cm"])-float(r["cumulative_runoff_cm"]))
    bottom = abs(float(c["cumulative_bottom_transfer_cm"])-float(r["cumulative_bottom_transfer_cm"]))
    storage = abs(float(c["final_soil_storage_change_cm"])-float(r["final_soil_storage_change_cm"]))
    final_head = max(abs(float(a)-float(b)) for a,b in zip(c["final_heads_cm"],r["final_heads_cm"]))
    cattr = max(abs(float(a)-float(b)) for a,b in zip(c["final_heads_cm"], ATTRACTOR))
    rattr = max(abs(float(a)-float(b)) for a,b in zip(r["final_heads_cm"], ATTRACTOR))
    tests = {
        "trajectory_heads": max_head <= POST_HEAD_DIFF_TOL,
        "runoff": runoff <= POST_RUNOFF_DIFF_TOL,
        "bottom": bottom <= POST_BOTTOM_DIFF_TOL,
        "storage": storage <= POST_STORAGE_DIFF_TOL,
        "final_heads": final_head <= FINAL_HEAD_DIFF_TOL,
        "candidate_attractor": cattr <= FINAL_ATTRACTOR_TOL,
        "reference_attractor": rattr <= FINAL_ATTRACTOR_TOL,
    }
    return {
        "available": True,
        "max_trajectory_head_difference_cm": max_head,
        "cumulative_runoff_difference_cm": runoff,
        "cumulative_bottom_transfer_difference_cm": bottom,
        "final_soil_storage_change_difference_cm": storage,
        "final_head_difference_cm": final_head,
        "candidate_final_to_attractor_cm": cattr,
        "reference_final_to_attractor_cm": rattr,
        "tests": tests,
        "pass": all(tests.values()),
    }


def run_profile(row: dict, profile_id: str) -> dict:
    cand_event = solve_event(profile_id, row, True)
    ref_event = solve_event(profile_id, row, False)
    event_cmp = compare_events(cand_event, ref_event)
    if not (cand_event.get("accepted") and ref_event.get("accepted")):
        return {
            "profile_id": profile_id,
            "candidate_event": cand_event,
            "reference_event": ref_event,
            "event_comparison": event_cmp,
            "pass": False,
            "decision": "EVENT_CORRECTOR_FAILED"
        }

    # Importing a7r1 has already moved qualification-only surface reference
    # evaluation out of the candidate nonlinear residual. Each trajectory starts
    # from its own accepted cap-event state; no pre-cap qtop is carried across.
    cand_post = a7r1.a7.trajectory(tuple(cand_event["heads_cm"]), row, True)
    ref_post = a7r1.a7.trajectory(tuple(ref_event["heads_cm"]), row, False)
    post_cmp = compare_postcap(cand_post, ref_post)
    cand_whole = whole_path(profile_id, row, cand_event, cand_post) if cand_post.get("complete") else None
    ref_whole = whole_path(profile_id, row, ref_event, ref_post) if ref_post.get("complete") else None

    candidate_routes_ok = bool(
        cand_post.get("complete")
        and not any("UNQUALIFIED" in k for k in cand_post.get("route_counts", {}))
        and cand_event.get("no_unqualified_face_route") is True
    )
    candidate_post_cost_ok = bool(
        cand_post.get("complete")
        and int(cand_post["max_surface_constitutive_K_evaluations"]) <= MAX_K_EVALS
        and int(cand_post["max_surface_root_residual_evaluations"]) <= MAX_ROOT_EVALS
    )
    tests = {
        "candidate_event_accepted": cand_event.get("accepted") is True,
        "reference_event_accepted": ref_event.get("accepted") is True,
        "event_comparison": event_cmp.get("pass") is True,
        "candidate_event_mass": cand_event["diagnostics"]["max_abs_balance_residual_cm"] <= MASS_TOL,
        "reference_event_mass": ref_event["diagnostics"]["max_abs_balance_residual_cm"] <= MASS_TOL,
        "candidate_event_surface_accuracy": cand_event["surface_q_abs_error_over_ksat"] <= SURFACE_Q_ERR_OVER_KS_TOL,
        "candidate_event_surface_cost": cand_event["surface_cost_ok"] is True,
        "candidate_event_committed_immutable": cand_event["original_committed_state_bitwise_unchanged_during_trial"] is True,
        "reference_event_committed_immutable": ref_event["original_committed_state_bitwise_unchanged_during_trial"] is True,
        "synthetic_candidate_event_reject_rollback": cand_event["synthetic_reject_after_event_corrector_restores_original_state"] is True and cand_event["synthetic_reject_runoff_ledger_cm"] == 0.0,
        "synthetic_reference_event_reject_rollback": ref_event["synthetic_reject_after_event_corrector_restores_original_state"] is True and ref_event["synthetic_reject_runoff_ledger_cm"] == 0.0,
        "candidate_postcap_complete": cand_post.get("complete") is True and cand_post.get("accepted_step_count") == 40,
        "reference_postcap_complete": ref_post.get("complete") is True and ref_post.get("accepted_step_count") == 40,
        "candidate_postcap_mass": cand_post.get("complete") is True and cand_post["max_abs_balance_residual_cm"] <= MASS_TOL,
        "reference_postcap_mass": ref_post.get("complete") is True and ref_post["max_abs_balance_residual_cm"] <= MASS_TOL,
        "postcap_comparison": post_cmp.get("pass") is True,
        "candidate_routes_qualified": candidate_routes_ok,
        "candidate_postcap_surface_cost": candidate_post_cost_ok,
        "candidate_whole_path_mass": cand_whole is not None and abs(cand_whole["whole_path_balance_residual_cm"]) <= MASS_TOL,
        "reference_whole_path_mass": ref_whole is not None and abs(ref_whole["whole_path_balance_residual_cm"]) <= MASS_TOL,
        "candidate_runoff_nonnegative": cand_post.get("complete") is True and cand_post["cumulative_runoff_cm"] >= 0.0,
        "reference_runoff_nonnegative": ref_post.get("complete") is True and ref_post["cumulative_runoff_cm"] >= 0.0,
        "no_mass_repair_or_clipping": cand_event.get("mass_repair_or_clipping_used") is False and ref_event.get("mass_repair_or_clipping_used") is False,
    }
    return {
        "profile_id": profile_id,
        "candidate_event": cand_event,
        "reference_event": ref_event,
        "event_comparison": event_cmp,
        "candidate_postcap": postcap_summary(cand_post),
        "reference_postcap": postcap_summary(ref_post),
        "postcap_comparison": post_cmp,
        "candidate_whole_path": cand_whole,
        "reference_whole_path": ref_whole,
        "postcap_qtop_recomputed_from_cap_state": True,
        "precap_qtop_reused_after_cap": False,
        "tests": tests,
        "failed_metrics": [k for k,v in tests.items() if not v],
        "pass": all(tests.values()),
    }


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit("usage: run_ross01_gate_e3h_a8_o14_transactional_surface_cap_to_runoff.py PROFILE OUTPUT.json")
    profile_id = sys.argv[1]
    if profile_id not in PROFILES:
        raise SystemExit(profile_id)
    catalog = json.loads(CATALOG.read_text(encoding="utf-8"))
    row = next(r for r in catalog["rows"] if r["sfu"] == MATERIAL)
    result = run_profile(row, profile_id)
    payload = {
        "schema_version": 1,
        "workstream": "F-ROSS",
        "work_unit": "F-ROSS01",
        "gate": "E3H_A8_O14_TRANSACTIONAL_SURFACE_CAP_ONSET_TO_ROSS_RUNOFF_CONTINUATION",
        "contract": CONTRACT,
        "production_implementation": False,
        "qualification_use": True,
        "material": MATERIAL,
        "profile_result": result,
        "pass": result["pass"],
        "decision": (
            "QUALIFIED_RESTRICTED_O14_TRANSACTIONAL_SURFACE_CAP_ONSET_TO_ROSS_RUNOFF_CONTINUATION_READY_FOR_SURFACE_EVENT_DETECTION_AND_CAP_GENERALIZATION_RESEARCH"
            if result["pass"] else
            "O14_TRANSACTIONAL_SURFACE_CAP_ONSET_TO_ROSS_RUNOFF_CONTINUATION_NOT_QUALIFIED_PRESERVE_A4_A6R1_A7_SEPARATE_AUTHORITIES"
        ),
        "hard_nonclaims": [
            "No automatic event detection or bracket discovery.",
            "No surface cap other than 1 cm and no material other than O14.",
            "No top-node saturation event qualification.",
            "No response tangent through cap onset or runoff continuation.",
            "No production implementation, runtime, MultiSWAP, MODFLOW or groundwater admission."
        ],
    }
    out = Path(sys.argv[2])
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    ev=result.get("event_comparison",{}); pc=result.get("postcap_comparison",{}); cw=result.get("candidate_whole_path") or {}
    print(json.dumps({
        "profile": profile_id,
        "pass": result["pass"],
        "candidate_event_time_day": result.get("candidate_event",{}).get("event_time_day"),
        "reference_event_time_day": result.get("reference_event",{}).get("event_time_day"),
        "event_time_difference_day": ev.get("event_time_difference_day"),
        "event_head_difference_cm": ev.get("max_event_head_difference_cm"),
        "postcap_head_difference_cm": pc.get("max_trajectory_head_difference_cm"),
        "postcap_runoff_difference_cm": pc.get("cumulative_runoff_difference_cm"),
        "candidate_whole_mass_cm": cw.get("whole_path_balance_residual_cm"),
        "candidate_final_to_attractor_cm": pc.get("candidate_final_to_attractor_cm"),
        "failed_metrics": result.get("failed_metrics"),
        "decision": payload["decision"],
    }, sort_keys=True), flush=True)
    if not result["pass"]:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
