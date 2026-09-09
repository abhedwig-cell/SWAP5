from __future__ import annotations

import json
import math
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import run_ross01_gate_e3_saturation_transition_hydrologic_relevance as e3
import run_ross01_gate_e3c_tight_qualification_solver_policy as e3c

CONTRACT = "F-ROSS01_GATE_E3D_R3_SUBKSAT_EVENT_FEASIBILITY_DIAGNOSTIC_PRECOMMIT.json"
CATALOG = Path("integration/f-ross/F-ROSS01_GATE_C1_MATERIAL_CATALOG.json")
MATERIALS = ("B01", "B12", "O13", "O14")
INITIAL_HEADS = (-0.2, -1.5, -5.0)
BOTTOM_HEAD = -15.0
Q_FRACTIONS = (0.25, 0.5, 0.75, 1.0)
DTS = (0.001, 0.002, 0.004, 0.008, 0.016, 0.032)
MASS_TOL = 1.0e-9
HEAD_GUARD = 0.8


def probe(row: dict, q_fraction: float, dt: float) -> dict:
    e3.configure(row)
    q_top = q_fraction * float(e3.core().KSAT)
    r = e3c.tight_solve_step(
        INITIAL_HEADS,
        dt,
        q_top,
        BOTTOM_HEAD,
        None,
        candidate=False,
    )
    max_cell = max(abs(float(x)) for x in r["cell_residuals"])
    abs_global = abs(float(r["global_mass_residual"]))
    heads = [float(x) for x in r["heads"]]
    crossed = bool(r["accepted"] and INITIAL_HEADS[0] < 0.0 <= heads[0])
    finite = bool(r["finite"] and all(math.isfinite(x) for x in heads))
    feasible = bool(
        r["accepted"]
        and finite
        and crossed
        and max_cell <= MASS_TOL
        and abs_global <= MASS_TOL
        and max(heads) < HEAD_GUARD
    )
    return {
        "accepted": bool(r["accepted"]),
        "finite": finite,
        "heads_cm": heads,
        "top_cell_h0_crossing": crossed,
        "max_abs_cell_mass_residual_cm": max_cell,
        "abs_global_mass_residual_cm": abs_global,
        "solver_success": bool(r["solver_success"]),
        "nfev": int(r["nfev"]),
        "feasible": feasible,
    }


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit("usage: run_ross01_gate_e3d_r3_subksat_event_feasibility.py OUTPUT.json")
    out = Path(sys.argv[1])
    catalog = json.loads(CATALOG.read_text(encoding="utf-8"))
    by = {r["sfu"]: r for r in catalog["rows"]}

    rows = []
    for q_fraction in Q_FRACTIONS:
        for dt in DTS:
            materials = []
            for material in MATERIALS:
                x = probe(by[material], q_fraction, dt)
                x["material"] = material
                materials.append(x)
            shared = all(x["feasible"] for x in materials)
            row = {
                "q_top_fraction_ksat": q_fraction,
                "trial_dt_day": dt,
                "shared_feasible_h0_root": shared,
                "materials": materials,
            }
            rows.append(row)
            print(json.dumps({
                "q_top_fraction_ksat": q_fraction,
                "trial_dt_day": dt,
                "shared_feasible_h0_root": shared,
                "accepted_count": sum(x["accepted"] for x in materials),
                "crossing_count": sum(x["top_cell_h0_crossing"] for x in materials),
            }, sort_keys=True), flush=True)

    passing = [r for r in rows if r["shared_feasible_h0_root"]]
    selected = min(
        passing,
        key=lambda r: (float(r["q_top_fraction_ksat"]), float(r["trial_dt_day"])),
        default=None,
    )

    result = {
        "schema_version": 1,
        "workstream": "F-ROSS",
        "work_unit": "F-ROSS01",
        "diagnostic": "E3D_R3_SUBKSAT_REFERENCE_EVENT_FEASIBILITY",
        "contract": CONTRACT,
        "qualification_use": False,
        "production_implementation": False,
        "reference_only": True,
        "c1r_table_generation": False,
        "materials": list(MATERIALS),
        "initial_heads_cm": list(INITIAL_HEADS),
        "bottom_head_cm": BOTTOM_HEAD,
        "q_top_fraction_ksat": list(Q_FRACTIONS),
        "trial_dt_day": list(DTS),
        "hard_mass_tolerance_cm": MASS_TOL,
        "head_guard_cm": HEAD_GUARD,
        "rows": rows,
        "shared_feasible_tuple_found": selected is not None,
        "selected_tuple": None if selected is None else {
            "q_top_fraction_ksat": selected["q_top_fraction_ksat"],
            "trial_dt_day": selected["trial_dt_day"],
        },
        "decision": (
            "SHARED_SUBKSAT_REFERENCE_H0_ROOT_FOUND_READY_FOR_NEW_FROZEN_TRAJECTORY_FIXTURE_DESIGN"
            if selected is not None
            else "NO_SHARED_SUBKSAT_REFERENCE_H0_ROOT_IN_FROZEN_GRID_RETHINK_TOP_BOUNDARY_EVENT_FORMULATION"
        ),
        "hard_nonclaims": [
            "No saturation-transition qualification.",
            "No candidate RossFast comparison.",
            "No production top-boundary policy.",
            "No searched tuple is admitted to qualification without a new frozen precommit."
        ],
    }
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps({
        "decision": result["decision"],
        "shared_feasible_tuple_found": result["shared_feasible_tuple_found"],
        "selected_tuple": result["selected_tuple"],
    }, sort_keys=True), flush=True)


if __name__ == "__main__":
    main()
