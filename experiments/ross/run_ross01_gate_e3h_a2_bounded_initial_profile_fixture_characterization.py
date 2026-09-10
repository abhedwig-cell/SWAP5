from __future__ import annotations

import json
import math
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import run_ross01_gate_e3h_a_top_node_saturation_event_fixture_characterization as a1

CONTRACT = "F-ROSS01_GATE_E3H_A2_BOUNDED_INITIAL_PROFILE_FIXTURE_CHARACTERIZATION_PRECOMMIT.json"
CATALOG = Path("integration/f-ross/F-ROSS01_GATE_C1_MATERIAL_CATALOG.json")
MATERIALS = ("B01", "B12", "O13", "O14")
PROFILES = (
    ("P0_A1_CONTROL", (-0.2, -1.5, -5.0)),
    ("P1_DRIER_SUBSOIL", (-0.5, -5.0, -10.0)),
    ("P2_DRIER_TOP_AND_SUBSOIL", (-1.0, -10.0, -20.0)),
    ("P3_STRONG_DRY_SEPARATION", (-2.0, -20.0, -50.0)),
)


def run_material(row: dict) -> dict:
    a1.configure(row)
    table = a1.e3g.e3.generate_c1r_table()
    ks = float(row["ksatfit_cm_per_day"])
    original = a1.INITIAL_HEADS
    rows = []
    selected = None
    try:
        for profile_id, heads in PROFILES:
            a1.INITIAL_HEADS = tuple(float(x) for x in heads)
            for frac in a1.SUPPLY_FRACTIONS:
                supply = float(frac) * ks
                cand = a1.solve_event(row, supply, True, table)
                ref = a1.solve_event(row, supply, False, None)
                cmp = a1.compare(cand, ref)
                passed = bool(
                    cand.get("valid") and ref.get("valid") and cmp.get("pass")
                    and cand.get("committed_state_bitwise_unchanged") is True
                    and ref.get("committed_state_bitwise_unchanged") is True
                    and cand.get("mass_repair_or_clipping_used") is False
                    and ref.get("mass_repair_or_clipping_used") is False
                )
                item = {
                    "profile_id": profile_id,
                    "initial_heads_cm": list(heads),
                    "supply_fraction_ksat": frac,
                    "q_supply_cm_per_day": supply,
                    "candidate": cand,
                    "reference": ref,
                    "comparison": cmp,
                    "pass": passed,
                }
                rows.append(item)
                if selected is None and passed:
                    selected = item
    finally:
        a1.INITIAL_HEADS = original

    selected_summary = None
    if selected is not None:
        selected_summary = {
            "profile_id": selected["profile_id"],
            "initial_heads_cm": selected["initial_heads_cm"],
            "supply_fraction_ksat": selected["supply_fraction_ksat"],
            "q_supply_cm_per_day": selected["q_supply_cm_per_day"],
            "candidate_event_time_day": selected["candidate"]["event_time_day"],
            "reference_event_time_day": selected["reference"]["event_time_day"],
            "candidate_event_heads_cm": selected["candidate"]["heads_cm"],
            "reference_event_heads_cm": selected["reference"]["heads_cm"],
            "candidate_surface_storage_cm": selected["candidate"]["surface_storage_cm"],
            "reference_surface_storage_cm": selected["reference"]["surface_storage_cm"],
            "candidate_max_abs_balance_residual_cm": selected["candidate"]["max_abs_balance_residual_cm"],
            "reference_max_abs_balance_residual_cm": selected["reference"]["max_abs_balance_residual_cm"],
            "event_time_difference_day": selected["comparison"]["event_time_difference_day"],
            "max_head_difference_cm": selected["comparison"]["max_head_difference_cm"],
            "surface_storage_difference_cm": selected["comparison"]["surface_storage_difference_cm"],
        }

    b01_control = True
    if row["sfu"] == "B01":
        passing_p0 = [r for r in rows if r["profile_id"] == "P0_A1_CONTROL" and r["pass"]]
        b01_control = bool(passing_p0 and passing_p0[0]["supply_fraction_ksat"] == 5.0)

    tests = {
        "frozen_grid_complete": len(rows) == len(PROFILES) * len(a1.SUPPLY_FRACTIONS),
        "selected_fixture_exists": selected is not None,
        "selected_is_first_passing_pair": selected is not None and all(not r["pass"] for r in rows[:rows.index(selected)]),
        "selected_candidate_reference_valid": selected is not None and selected["candidate"]["valid"] and selected["reference"]["valid"],
        "selected_mass": selected is not None and max(selected["candidate"]["max_abs_balance_residual_cm"], selected["reference"]["max_abs_balance_residual_cm"]) <= a1.MASS_TOL,
        "selected_event_scope": selected is not None and selected["candidate"]["heads_cm"][1] <= -1.0 and selected["reference"]["heads_cm"][1] <= -1.0,
        "selected_transaction": selected is not None and selected["candidate"]["committed_state_bitwise_unchanged"] and selected["reference"]["committed_state_bitwise_unchanged"],
        "B01_P0_control_preserved": b01_control,
    }
    return {
        "material": row["sfu"],
        "profile_count": len(PROFILES),
        "supply_count_per_profile": len(a1.SUPPLY_FRACTIONS),
        "case_count": len(rows),
        "rows": rows,
        "selected_fixture": selected_summary,
        "tests": tests,
        "failed_metrics": [k for k,v in tests.items() if not v],
        "pass": all(tests.values()),
    }


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit("usage: run_ross01_gate_e3h_a2_bounded_initial_profile_fixture_characterization.py MATERIAL OUTPUT.json")
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
        "gate": "E3H_A2_BOUNDED_INITIAL_PROFILE_FIXTURE_CHARACTERIZATION",
        "contract": CONTRACT,
        "material": material,
        "production_implementation": False,
        "qualification_use": False,
        "material_result": mr,
        "pass": mr["pass"],
        "decision": "CHARACTERIZED_BOUNDED_TRUE_TOP_NODE_H0_EVENT_FIXTURE_READY_FOR_E3H_QUALIFICATION" if mr["pass"] else "BOUNDED_INITIAL_PROFILE_GRID_DID_NOT_ESTABLISH_TOP_NODE_H0_FIXTURE_RESEARCH_REQUIRED",
    }
    out = Path(sys.argv[2])
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    sf = mr["selected_fixture"]
    print(json.dumps({
        "material": material,
        "pass": mr["pass"],
        "case_count": mr["case_count"],
        "selected_profile": None if sf is None else sf["profile_id"],
        "selected_supply_fraction_ksat": None if sf is None else sf["supply_fraction_ksat"],
        "candidate_event_time_day": None if sf is None else sf["candidate_event_time_day"],
        "reference_event_time_day": None if sf is None else sf["reference_event_time_day"],
        "max_balance_cm": None if sf is None else max(sf["candidate_max_abs_balance_residual_cm"], sf["reference_max_abs_balance_residual_cm"]),
        "failed_metrics": mr["failed_metrics"],
        "decision": payload["decision"],
    }, sort_keys=True), flush=True)
    if not mr["pass"]:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
