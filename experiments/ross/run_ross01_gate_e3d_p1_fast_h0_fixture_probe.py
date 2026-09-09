from __future__ import annotations

import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import run_ross01_gate_e3_saturation_transition_hydrologic_relevance as e3
import run_ross01_gate_e3c_tight_qualification_solver_policy as e3c

CATALOG = Path("integration/f-ross/F-ROSS01_GATE_C1_MATERIAL_CATALOG.json")
MATERIALS = ("B01", "B12", "O13", "O14")
INITIAL_HEADS = (-0.2, -1.5, -5.0)
Q_FRACTIONS = (1.25, 1.5)
HORIZONS = (0.001, 0.002)
BOTTOM_HEAD = -15.0


def solve_one(material_row, q_fraction: float, horizon: float):
    e3.configure(material_row)
    table = e3.generate_c1r_table()
    q_top = q_fraction * float(e3.core().KSAT)
    ref = e3c.tight_solve_step(INITIAL_HEADS, horizon, q_top, BOTTOM_HEAD, table, candidate=False)
    cand = e3c.tight_solve_step(INITIAL_HEADS, horizon, q_top, BOTTOM_HEAD, table, candidate=True)
    ref_cross = bool(ref["accepted"] and INITIAL_HEADS[0] < 0.0 <= ref["heads"][0])
    cand_cross = bool(cand["accepted"] and INITIAL_HEADS[0] < 0.0 <= cand["heads"][0])
    return {
        "reference": {
            "accepted": ref["accepted"],
            "heads_cm": list(ref["heads"]),
            "top_crossed_h0": ref_cross,
            "max_abs_cell_mass_residual_cm": max(abs(x) for x in ref["cell_residuals"]),
            "abs_global_mass_residual_cm": abs(ref["global_mass_residual"]),
            "nfev": ref["nfev"],
        },
        "candidate": {
            "accepted": cand["accepted"],
            "heads_cm": list(cand["heads"]),
            "top_crossed_h0": cand_cross,
            "routes": list(cand["routes"]),
            "unqualified_route_count": sum(r == "UNQUALIFIED_FACE_FALLBACK" for r in cand["routes"]),
            "max_abs_cell_mass_residual_cm": max(abs(x) for x in cand["cell_residuals"]),
            "abs_global_mass_residual_cm": abs(cand["global_mass_residual"]),
            "nfev": cand["nfev"],
        },
    }


def main():
    if len(sys.argv) != 2:
        raise SystemExit("usage: run_ross01_gate_e3d_p1_fast_h0_fixture_probe.py OUTPUT.json")
    out = Path(sys.argv[1])
    catalog = json.loads(CATALOG.read_text(encoding="utf-8"))
    by = {r["sfu"]: r for r in catalog["rows"]}

    original_face = e3.candidate_face
    rows = []
    selected = None
    try:
        e3.candidate_face = e3c.expanded_candidate_face
        for q_fraction in Q_FRACTIONS:
            for horizon in HORIZONS:
                materials = []
                for material in MATERIALS:
                    x = solve_one(by[material], q_fraction, horizon)
                    x["material"] = material
                    materials.append(x)
                shared = all(
                    x["reference"]["accepted"]
                    and x["candidate"]["accepted"]
                    and x["reference"]["top_crossed_h0"]
                    and x["candidate"]["top_crossed_h0"]
                    and x["candidate"]["unqualified_route_count"] == 0
                    and max(x["reference"]["heads_cm"]) < 0.8
                    and max(x["candidate"]["heads_cm"]) < 0.8
                    for x in materials
                )
                row = {"q_top_fraction_ksat": q_fraction, "horizon_day": horizon, "shared_probe_pass": shared, "materials": materials}
                rows.append(row)
                print(json.dumps({"q": q_fraction, "horizon": horizon, "shared": shared}, sort_keys=True), flush=True)
        passing = [r for r in rows if r["shared_probe_pass"]]
        if passing:
            selected = min(passing, key=lambda r: (r["q_top_fraction_ksat"], r["horizon_day"]))
    finally:
        e3.candidate_face = original_face

    result = {
        "schema_version": 1,
        "workstream": "F-ROSS",
        "work_unit": "F-ROSS01",
        "diagnostic": "E3D_P1_FAST_H0_FIXTURE_PROBE",
        "qualification_use": false,
        "production_implementation": false,
        "initial_heads_cm": list(INITIAL_HEADS),
        "bottom_head_cm": BOTTOM_HEAD,
        "q_top_fraction_ksat": list(Q_FRACTIONS),
        "horizons_day": list(HORIZONS),
        "rows": rows,
        "selected_probe": None if selected is None else {
            "initial_heads_cm": list(INITIAL_HEADS),
            "q_top_fraction_ksat": selected["q_top_fraction_ksat"],
            "bottom_head_cm": BOTTOM_HEAD,
            "horizon_day": selected["horizon_day"],
            "direction": "wetting"
        },
        "shared_probe_found": selected is not None,
        "decision": "FAST_SHARED_H0_FIXTURE_PROBE_FOUND_READY_FOR_FROZEN_TRAJECTORY_PRECOMMIT" if selected is not None else "FAST_SHARED_H0_FIXTURE_PROBE_NOT_FOUND_DO_NOT_QUALIFY",
        "hard_nonclaims": [
            "A one-step crossing probe is not a timestep-convergence qualification.",
            "No transition-time accuracy claim follows.",
            "The wider E3D search remains independent evidence and is not overwritten."
        ]
    }
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps({"decision": result["decision"], "selected_probe": result["selected_probe"]}, sort_keys=True), flush=True)


if __name__ == "__main__":
    main()
