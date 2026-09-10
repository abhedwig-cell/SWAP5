from __future__ import annotations

import json
import math
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import run_ross01_gate_e3g_physical_top_boundary_switch_composition as e3g

CONTRACT = "F-ROSS01_GATE_E3G_R1_INITIAL_SURFACE_COMPLEMENTARITY_ADMISSION_PRECOMMIT.json"
CATALOG = Path("integration/f-ross/F-ROSS01_GATE_C1_MATERIAL_CATALOG.json")
MATERIALS = e3g.MATERIALS
SCENARIOS = e3g.SCENARIOS
EPS = sys.float_info.epsilon
QCAP_ERR_MAX = 5.0e-4


def admission_at_t0(old: e3g.State, supply: float, row: dict, candidate: bool) -> dict:
    """Classify the boundary mode from committed state only.

    This routine performs no soil nonlinear trajectory. It evaluates the
    qualified 5 cm h_surface=0 face at the committed top-node head.
    """
    snapshot = e3g.bits(old)
    qcap0, route, cost = e3g.surface_face(0.0, float(old.heads[0]), row, candidate)
    exact = e3g.exact_surface_reference(0.0, float(old.heads[0]), row)
    q_exact = float(exact["q"])
    ksat = float(row["ksatfit_cm_per_day"])
    tol = 64.0 * EPS * max(1.0, abs(supply), abs(qcap0))
    immediate_ponding = bool(supply > qcap0 + tol)
    return {
        "classification": "IMMEDIATE_PONDED_AT_T0" if immediate_ponding else "DRY_FLUX_ADMISSIBLE_AT_T0",
        "immediate_ponding_at_t0": immediate_ponding,
        "dry_flux_admissible_at_t0": not immediate_ponding,
        "q_supply_cm_per_day": float(supply),
        "q_cap0_cm_per_day": float(qcap0),
        "capacity_route": str(route),
        "capacity_cost": cost,
        "roundoff_tolerance_cm_per_day": float(tol),
        "exact_surface_reference_q_cm_per_day": q_exact,
        "exact_surface_reference_residual_cm": float(exact.get("residual_cm", 0.0)),
        "q_cap0_abs_error_over_ksat": abs(float(qcap0) - q_exact) / ksat,
        "soil_nonlinear_trajectory_count": 0,
        "committed_state_bitwise_unchanged": e3g.bits(old) == snapshot,
    }


def run_path_r1(row: dict, scenario: dict, candidate: bool) -> dict:
    e3g.internal_geometry(row)
    table = e3g.e3.generate_c1r_table() if candidate else None
    old = e3g.State(2.375, e3g.INITIAL_HEADS, float(scenario["S0"]))
    supply = float(scenario["supply_fraction"]) * float(row["ksatfit_cm_per_day"])
    snapshot = e3g.bits(old)

    if scenario["id"] == "PONDED_HEAD_CONTINUATION":
        out = e3g.ponded_solve(old, supply, table, row, candidate)
        out["initial_admission"] = {
            "classification": "PONDED_STATE_ALREADY_ACTIVE",
            "soil_nonlinear_trajectory_count": 0,
            "committed_state_bitwise_unchanged": e3g.bits(old) == snapshot,
        }
        out["dry_flux_predictor"] = None
        out["dry_predictor_executed"] = False
        out["dry_predictor_nonlinear_solve_count"] = 0
        out["mode"] = "PONDED_HEAD" if out.get("accepted") else "REJECTED"
        out["bottom_transfer_cm"] = (
            None if out.get("diagnostics") is None else out["diagnostics"]["bottom_transfer_cm"]
        )
        return out

    admission = admission_at_t0(old, supply, row, candidate)

    if scenario["id"] == "DRY_FLUX_ADMISSIBLE":
        if admission["immediate_ponding_at_t0"]:
            return {
                "accepted": False,
                "mode": "REJECTED",
                "initial_admission": admission,
                "dry_flux_predictor": None,
                "dry_predictor_executed": False,
                "dry_predictor_nonlinear_solve_count": 0,
                "heads_cm": None,
                "surface_storage_cm": 0.0,
                "bottom_transfer_cm": None,
                "diagnostics": None,
                "committed_input_bitwise_unchanged_during_trial": e3g.bits(old) == snapshot,
                "mass_repair_or_clipping_used": False,
                "error": "dry control unexpectedly classified immediate ponding",
            }
        p = e3g.dry_predictor(old, supply, table, row, candidate)
        accepted = bool(p.get("accepted_as_dry_flux"))
        return {
            "accepted": accepted,
            "mode": "DRY_FLUX" if accepted else "REJECTED",
            "initial_admission": admission,
            "dry_flux_predictor": p,
            "dry_predictor_executed": True,
            "dry_predictor_nonlinear_solve_count": 1,
            "heads_cm": p.get("heads_cm"),
            "surface_storage_cm": 0.0,
            "bottom_transfer_cm": None if not accepted else p["diagnostics"]["bottom_transfer_cm"],
            "diagnostics": p.get("diagnostics"),
            "committed_input_bitwise_unchanged_during_trial": p["committed_bitwise_unchanged"],
            "mass_repair_or_clipping_used": False,
        }

    if not admission["immediate_ponding_at_t0"]:
        return {
            "accepted": False,
            "mode": "REJECTED",
            "initial_admission": admission,
            "dry_flux_predictor": None,
            "dry_predictor_executed": False,
            "dry_predictor_nonlinear_solve_count": 0,
            "heads_cm": None,
            "surface_storage_cm": 0.0,
            "bottom_transfer_cm": None,
            "diagnostics": None,
            "committed_input_bitwise_unchanged_during_trial": e3g.bits(old) == snapshot,
            "mass_repair_or_clipping_used": False,
            "error": "switch control not classified immediate ponding",
        }

    # R1 remediation: no fictitious dry full-step solve. The ponded solve starts
    # from the exact same committed state and owns the only nonlinear trajectory.
    out = e3g.ponded_solve(old, supply, table, row, candidate)
    out["initial_admission"] = admission
    out["dry_flux_predictor"] = None
    out["dry_predictor_executed"] = False
    out["dry_predictor_nonlinear_solve_count"] = 0
    out["ponded_nonlinear_solve_count"] = 1
    out["ponded_solve_started_from_original_committed_state"] = e3g.bits(old) == snapshot
    out["mode"] = "PONDED_HEAD" if out.get("accepted") else "REJECTED"
    out["bottom_transfer_cm"] = (
        None if out.get("diagnostics") is None else out["diagnostics"]["bottom_transfer_cm"]
    )
    return out


def path_tests_r1(path: dict, scenario: dict) -> dict:
    d = path.get("diagnostics")
    tests = {
        "accepted": path.get("accepted") is True,
        "mode": path.get("mode") == scenario["mode"],
        "no_repair_or_clipping": path.get("mass_repair_or_clipping_used") is False,
        "committed_input_unchanged_during_trial": path.get("committed_input_bitwise_unchanged_during_trial") is True,
        "surface_scope": 0.0 <= float(path.get("surface_storage_cm", -1.0)) < e3g.S_MAX,
        "top_node_negative_scope": path.get("heads_cm") is not None and max(path["heads_cm"]) <= e3g.TOP_UPPER,
    }
    if d is None:
        tests.update({"cell_mass": False, "surface_mass": False, "composed_mass": False})
    else:
        tests.update({
            "cell_mass": max(abs(v) for v in d["cell_residuals_cm"]) <= e3g.MASS_TOL,
            "surface_mass": abs(d["surface_balance_residual_cm"]) <= e3g.MASS_TOL,
            "composed_mass": abs(d["composed_balance_residual_cm"]) <= e3g.MASS_TOL,
        })

    admission = path.get("initial_admission") or {}
    if scenario["id"] == "DRY_FLUX_ADMISSIBLE":
        tests.update({
            "initial_admission_dry": admission.get("dry_flux_admissible_at_t0") is True,
            "initial_qcap_crosscheck": admission.get("q_cap0_abs_error_over_ksat", math.inf) <= QCAP_ERR_MAX,
            "dry_predictor_executed": path.get("dry_predictor_executed") is True,
            "dry_predictor_nonlinear_solve_count": path.get("dry_predictor_nonlinear_solve_count") == 1,
            "surface_exact_zero": path.get("surface_storage_cm") == 0.0,
        })
    elif scenario["id"] == "DRY_FLUX_TO_PONDED_HEAD_SWITCH":
        tests.update({
            "initial_admission_immediate_ponding": admission.get("immediate_ponding_at_t0") is True,
            "initial_qcap_crosscheck": admission.get("q_cap0_abs_error_over_ksat", math.inf) <= QCAP_ERR_MAX,
            "admission_state_unchanged": admission.get("committed_state_bitwise_unchanged") is True,
            "dry_predictor_not_executed": path.get("dry_predictor_executed") is False,
            "dry_predictor_nonlinear_solve_count_zero": path.get("dry_predictor_nonlinear_solve_count") == 0,
            "ponded_nonlinear_solve_count_one": path.get("ponded_nonlinear_solve_count") == 1,
            "ponded_starts_from_original_committed_state": path.get("ponded_solve_started_from_original_committed_state") is True,
            "surface_strictly_positive": float(path.get("surface_storage_cm", 0.0)) > 0.0,
        })
    else:
        tests.update({
            "already_ponded_admission": admission.get("classification") == "PONDED_STATE_ALREADY_ACTIVE",
            "dry_predictor_not_executed": path.get("dry_predictor_executed") is False,
            "surface_strictly_positive": float(path.get("surface_storage_cm", 0.0)) > 0.0,
        })
    return tests


def run_material(row: dict) -> dict:
    rows = []
    for scenario in SCENARIOS:
        cand = run_path_r1(row, scenario, True)
        ref = run_path_r1(row, scenario, False)
        ct = path_tests_r1(cand, scenario)
        rt = path_tests_r1(ref, scenario)
        cmp = e3g.compare(cand, ref)
        rows.append({
            "scenario": scenario,
            "candidate": cand,
            "reference": ref,
            "candidate_tests": ct,
            "reference_tests": rt,
            "comparison": cmp,
            "pass": all(ct.values()) and all(rt.values()) and cmp["pass"],
        })

    max_h = max((r["comparison"].get("max_abs_head_difference_cm", math.inf) for r in rows), default=math.inf)
    max_s = max((r["comparison"].get("max_abs_surface_storage_difference_cm", math.inf) for r in rows), default=math.inf)
    max_b = max((r["comparison"].get("max_abs_bottom_transfer_difference_cm", math.inf) for r in rows), default=math.inf)
    max_mass = 0.0
    for r in rows:
        for side in (r["candidate"], r["reference"]):
            d = side.get("diagnostics")
            if d:
                max_mass = max(
                    max_mass,
                    max(abs(v) for v in d["cell_residuals_cm"]),
                    abs(d["surface_balance_residual_cm"]),
                    abs(d["composed_balance_residual_cm"]),
                )

    switch = next(r for r in rows if r["scenario"]["id"] == "DRY_FLUX_TO_PONDED_HEAD_SWITCH")
    tests = {
        "scenario_count": len(rows) == 3,
        "all_rows_pass": all(r["pass"] for r in rows),
        "switch_candidate_immediate_admission": switch["candidate"]["initial_admission"]["immediate_ponding_at_t0"] is True,
        "switch_reference_immediate_admission": switch["reference"]["initial_admission"]["immediate_ponding_at_t0"] is True,
        "switch_candidate_dry_solve_count_zero": switch["candidate"]["dry_predictor_nonlinear_solve_count"] == 0,
        "switch_reference_dry_solve_count_zero": switch["reference"]["dry_predictor_nonlinear_solve_count"] == 0,
        "switch_candidate_ponded_solve_count_one": switch["candidate"]["ponded_nonlinear_solve_count"] == 1,
        "switch_reference_ponded_solve_count_one": switch["reference"]["ponded_nonlinear_solve_count"] == 1,
        "max_head_difference": max_h <= e3g.HEAD_DIFF_TOL,
        "max_surface_difference": max_s <= e3g.SURFACE_DIFF_TOL,
        "max_bottom_transfer_difference": max_b <= e3g.BOTTOM_TRANSFER_DIFF_TOL,
        "max_mass_residual": max_mass <= e3g.MASS_TOL,
    }
    return {
        "material": row["sfu"],
        "rows": rows,
        "max_abs_head_difference_cm": max_h,
        "max_abs_surface_storage_difference_cm": max_s,
        "max_abs_bottom_transfer_difference_cm": max_b,
        "max_abs_mass_residual_cm": max_mass,
        "switch_candidate_qcap0_cm_per_day": switch["candidate"]["initial_admission"]["q_cap0_cm_per_day"],
        "switch_reference_qcap0_cm_per_day": switch["reference"]["initial_admission"]["q_cap0_cm_per_day"],
        "switch_q_supply_cm_per_day": switch["candidate"]["initial_admission"]["q_supply_cm_per_day"],
        "B12_negative_control_original_E3G_dry_trial_was_valid": row["sfu"] == "B12",
        "tests": tests,
        "failed_metrics": [k for k, v in tests.items() if not v],
        "pass": all(tests.values()),
    }


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit("usage: run_ross01_gate_e3g_r1_initial_surface_complementarity_admission.py MATERIAL OUTPUT.json")
    material = sys.argv[1]
    if material not in MATERIALS:
        raise SystemExit(material)
    catalog = json.loads(CATALOG.read_text(encoding="utf-8"))
    row = next(r for r in catalog["rows"] if r["sfu"] == material)
    mr = run_material(row)
    payload = {
        "schema_version": 1,
        "workstream": "F-ROSS",
        "work_unit": "F-ROSS01",
        "gate": "E3G_R1_INITIAL_SURFACE_COMPLEMENTARITY_ADMISSION",
        "contract": CONTRACT,
        "material": material,
        "production_implementation": False,
        "material_result": mr,
        "pass": mr["pass"],
        "decision": (
            "QUALIFIED_INITIAL_COMPLEMENTARITY_ADMISSION_AND_IMMEDIATE_PONDING_SWITCH_READY_FOR_FINITE_TIME_EVENT_LOCALIZATION_GATE"
            if mr["pass"] else
            "INITIAL_COMPLEMENTARITY_ADMISSION_NOT_QUALIFIED_PRESERVE_R1_FAILURE"
        ),
        "hard_nonclaims": [
            "No finite-time within-step ponding onset event localization.",
            "No pond-depletion head-to-flux switch.",
            "No top soil-node h=0 or positive-head state.",
            "No runoff with real soil state.",
            "No response tangent across top-boundary switching.",
            "No production, runtime, MultiSWAP, MODFLOW or groundwater admission."
        ],
    }
    out = Path(sys.argv[2])
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps({
        "material": material,
        "pass": mr["pass"],
        "switch_q_supply_cm_per_day": mr["switch_q_supply_cm_per_day"],
        "switch_candidate_qcap0_cm_per_day": mr["switch_candidate_qcap0_cm_per_day"],
        "switch_reference_qcap0_cm_per_day": mr["switch_reference_qcap0_cm_per_day"],
        "max_head_difference_cm": mr["max_abs_head_difference_cm"],
        "max_surface_difference_cm": mr["max_abs_surface_storage_difference_cm"],
        "max_bottom_transfer_difference_cm": mr["max_abs_bottom_transfer_difference_cm"],
        "max_mass_residual_cm": mr["max_abs_mass_residual_cm"],
        "failed_metrics": mr["failed_metrics"],
        "decision": payload["decision"],
    }, sort_keys=True), flush=True)
    if not mr["pass"]:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
