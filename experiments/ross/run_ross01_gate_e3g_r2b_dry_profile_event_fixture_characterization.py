from __future__ import annotations

import json
import math
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import run_ross01_gate_e3g_physical_top_boundary_switch_composition as e3g
import run_ross01_gate_e3g_r2a_constant_supply_event_fixture_characterization as r2a

CONTRACT = "F-ROSS01_GATE_E3G_R2B_DRY_INITIAL_PROFILE_EVENT_FIXTURE_CHARACTERIZATION_PRECOMMIT.json"
CATALOG = Path("integration/f-ross/F-ROSS01_GATE_C1_MATERIAL_CATALOG.json")
MATERIALS = ("B01", "O14")
PROFILES = (
    {"id": "UNIFORM_DRY_10", "heads": (-10.0, -10.0, -10.0), "priority": 0},
    {"id": "UNIFORM_DRY_100", "heads": (-100.0, -100.0, -100.0), "priority": 1},
)
LAMBDAS = (0.25, 0.5, 0.75)
TIMES = (0.0, 1.0e-4, 5.0e-4, 1.0e-3, 5.0e-3, 1.0e-2, 5.0e-2, 1.0e-1)
EPS = sys.float_info.epsilon


def robust_brackets(samples: list[dict], ksat: float) -> list[dict]:
    out = []
    for a, b in zip(samples[:-1], samples[1:]):
        if not (a.get("local_trial_valid") and b.get("local_trial_valid")):
            continue
        ga = float(a["g_supply_minus_capacity_cm_per_day"])
        gb = float(b["g_supply_minus_capacity_cm_per_day"])
        ta = float(a["comparison_tolerance_cm_per_day"])
        tb = float(b["comparison_tolerance_cm_per_day"])
        ha = float(a["heads_cm"][0])
        hb = float(b["heads_cm"][0])
        if ga < -ta and gb >= -tb and hb > ha:
            margin = min(abs(ga), abs(gb)) / ksat
            out.append({
                "t_left_day": float(a["dt_day"]),
                "t_right_day": float(b["dt_day"]),
                "g_left_cm_per_day": ga,
                "g_right_cm_per_day": gb,
                "h_top_left_cm": ha,
                "h_top_right_cm": hb,
                "normalized_sign_margin": margin,
                "wetting_direction": True,
            })
    return out


def characterize(row: dict) -> dict:
    ksat = float(row["ksatfit_cm_per_day"])
    rows = []
    candidates = []
    for profile in PROFILES:
        old = e3g.State(2.375, tuple(float(v) for v in profile["heads"]), 0.0)
        qcap0 = r2a.exact_qcap(old.heads[0], row)
        cap_tol = 64.0 * EPS * max(1.0, abs(ksat), abs(qcap0))
        cap_above_ksat = bool(qcap0 > ksat + cap_tol)
        profile_row = {
            "profile_id": profile["id"],
            "initial_heads_cm": list(profile["heads"]),
            "qcap0_cm_per_day": qcap0,
            "qcap0_over_ksat": qcap0 / ksat,
            "qcap0_strictly_above_ksat": cap_above_ksat,
            "forcing_rows": [],
        }
        if not cap_above_ksat:
            rows.append(profile_row)
            continue

        for lam in LAMBDAS:
            supply = ksat + lam * (qcap0 - ksat)
            forcing_tol = 64.0 * EPS * max(1.0, abs(supply), abs(qcap0))
            initial_physics_ok = bool(supply > ksat + forcing_tol and supply < qcap0 - forcing_tol)
            samples = [r2a.dry_reference_at(old, supply, dt, row) for dt in TIMES]
            brackets = robust_brackets(samples, ksat)
            fr = {
                "lambda": lam,
                "q_supply_cm_per_day": supply,
                "q_supply_over_ksat": supply / ksat,
                "initial_supply_between_ksat_and_qcap0": initial_physics_ok,
                "samples": samples,
                "valid_wetting_event_brackets": brackets,
                "has_valid_wetting_event_bracket": bool(brackets),
                "all_samples_committed_state_unchanged": all(s.get("committed_state_bitwise_unchanged") for s in samples),
                "mass_repair_or_clipping_used": any(s.get("mass_repair_or_clipping_used") for s in samples),
            }
            profile_row["forcing_rows"].append(fr)
            for b in brackets:
                candidates.append({
                    "profile_id": profile["id"],
                    "profile_priority": profile["priority"],
                    "initial_heads_cm": list(profile["heads"]),
                    "lambda": lam,
                    "q_supply_cm_per_day": supply,
                    "q_supply_over_ksat": supply / ksat,
                    **b,
                })
        rows.append(profile_row)

    def ranking(x: dict):
        return (
            -float(x["normalized_sign_margin"]),
            int(x["profile_priority"]),
            abs(float(x["lambda"]) - 0.5),
            float(x["t_right_day"]),
        )

    selected = sorted(candidates, key=ranking)[0] if candidates else None
    tests = {
        "profile_count": len(rows) == len(PROFILES),
        "at_least_one_valid_wetting_bracket": selected is not None,
        "all_trials_preserve_committed_state": all(
            fr["all_samples_committed_state_unchanged"]
            for p in rows for fr in p["forcing_rows"]
        ),
        "no_mass_repair_or_clipping": not any(
            fr["mass_repair_or_clipping_used"]
            for p in rows for fr in p["forcing_rows"]
        ),
    }
    if selected is not None:
        tests.update({
            "selected_initial_supply_super_ksat": selected["q_supply_cm_per_day"] > ksat,
            "selected_wetting_direction": selected["h_top_right_cm"] > selected["h_top_left_cm"],
            "selected_strict_event_bracket": selected["g_left_cm_per_day"] < 0.0 and selected["g_right_cm_per_day"] >= 0.0,
        })

    return {
        "material": row["sfu"],
        "profiles": rows,
        "valid_candidate_count": len(candidates),
        "selected_fixture_candidate": selected,
        "tests": tests,
        "failed_metrics": [k for k, v in tests.items() if not v],
        "pass": all(tests.values()),
    }


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit("usage: run_ross01_gate_e3g_r2b_dry_profile_event_fixture_characterization.py MATERIAL OUTPUT.json")
    material = sys.argv[1]
    if material not in MATERIALS:
        raise SystemExit(material)
    catalog = json.loads(CATALOG.read_text(encoding="utf-8"))
    row = next(r for r in catalog["rows"] if r["sfu"] == material)
    result = characterize(row)
    payload = {
        "schema_version": 1,
        "workstream": "F-ROSS",
        "work_unit": "F-ROSS01",
        "gate": "E3G_R2B_DRY_INITIAL_PROFILE_EVENT_FIXTURE_CHARACTERIZATION",
        "contract": CONTRACT,
        "material": material,
        "production_implementation": False,
        "qualification_use": False,
        "material_result": result,
        "pass": result["pass"],
        "decision": (
            "CHARACTERIZED_DRY_PROFILE_FINITE_TIME_PONDING_FIXTURES_READY_FOR_R2_QUALIFICATION_PRECOMMIT"
            if result["pass"] else
            "DRY_PROFILE_FINITE_TIME_PONDING_FIXTURE_NOT_ESTABLISHED_FURTHER_EVENT_RESEARCH_REQUIRED"
        ),
        "hard_nonclaims": [
            "No finite-time event localization is qualified.",
            "No candidate event locator is tested.",
            "No production initialization or event-search cadence is implied.",
            "No B12/O13 finite-time event is sought.",
            "No top-node positive head, depletion switch, runoff, tangent, runtime, MultiSWAP or MODFLOW admission."
        ],
    }
    out = Path(sys.argv[2])
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps({
        "material": material,
        "pass": payload["pass"],
        "valid_candidate_count": result["valid_candidate_count"],
        "selected_fixture_candidate": result["selected_fixture_candidate"],
        "decision": payload["decision"],
    }, sort_keys=True), flush=True)
    if not payload["pass"]:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
