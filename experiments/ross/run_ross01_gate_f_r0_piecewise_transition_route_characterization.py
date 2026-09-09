from __future__ import annotations

import hashlib
import json
import math
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import run_ross01_gate_f_timestep_convergence as gate_f

CONTRACT = "F-ROSS01_GATE_F_R0_PIECEWISE_TRANSITION_ROUTE_CHARACTERIZATION_CONTRACT.json"
MATERIAL = "O14"
N_CELLS = 4
PROFILE = "wet_gradient"
PATTERNS = ("zero", "mixed_local_source_and_sink")
STEP_COUNTS = gate_f.STEP_COUNTS
MASS_TOL_CM = 1.0e-12


def run() -> dict:
    catalog = json.loads(gate_f.j1a.CATALOG.read_text())
    by_name = {row["sfu"]: row for row in catalog["rows"]}
    gate_f.j1a.c1r.base.c1.configure_core(by_name[MATERIAL])
    table, preprocessing_seconds, generation_failures = gate_f.j1a.c1r.base.generate_table(gate_f.j1a.N)
    if generation_failures:
        raise RuntimeError(("table generation failures", generation_failures[:4]))
    table_before = hashlib.sha256(table.tobytes(order="C")).hexdigest()

    profile_row = next(row for row in gate_f.PROFILE_FAMILIES if row[0] == PROFILE)
    _, h_first, h_last = profile_row
    initial_heads = gate_f.gate_d.build_profile(N_CELLS, h_first, h_last)
    theta0 = tuple(gate_f.gate_d.theta_from_head(h) for h in initial_heads)

    paths = []
    all_crossings = []
    for pattern in PATTERNS:
        ext = gate_f.fixed_external(initial_heads, pattern)
        for step_count in STEP_COUNTS:
            dt = gate_f.HORIZON_DAY / step_count
            committed = theta0
            path_crossings = []
            max_step_mass = 0.0
            max_cell_mass = 0.0
            for step_index in range(step_count):
                start_heads = gate_f.heads_from_theta(committed)
                result = gate_f.candidate_step(committed, table, ext, dt)
                end_heads = tuple(result["heads"])
                max_step_mass = max(max_step_mass, result["abs_global_mass_residual_cm"])
                max_cell_mass = max(max_cell_mass, result["max_abs_cell_mass_residual_cm"])
                for i, (h0, h1) in enumerate(zip(start_heads, end_heads)):
                    c0 = gate_f.j1a.table_cell(h0)[0]
                    c1 = gate_f.j1a.table_cell(h1)[0]
                    displacement = c1 - c0
                    if displacement == 0:
                        continue
                    crossed_nodes = []
                    if displacement > 0:
                        node_indices = range(c0 + 1, c1 + 1)
                    else:
                        node_indices = range(c0, c1, -1)
                    for node in node_indices:
                        u_node = node / gate_f.j1a.DXDU
                        crossed_nodes.append({
                            "node_index": int(node),
                            "u_log10_minus_h": u_node,
                            "head_cm": float(gate_f.j1a.head_from_u(u_node)),
                        })
                    crossing = {
                        "pattern": pattern,
                        "step_count": step_count,
                        "dt_day": dt,
                        "step_index_zero_based": step_index,
                        "t_start_day": step_index * dt,
                        "t_end_day": (step_index + 1) * dt,
                        "component_index_zero_based": i,
                        "start_head_cm": h0,
                        "end_head_cm": h1,
                        "start_cell": int(c0),
                        "end_cell": int(c1),
                        "signed_cell_displacement": int(displacement),
                        "crossed_nodes": crossed_nodes,
                        "trial_abs_global_mass_residual_cm": result["abs_global_mass_residual_cm"],
                        "trial_max_abs_cell_mass_residual_cm": result["max_abs_cell_mass_residual_cm"],
                        "trial_domain_ok": result["domain_ok"],
                        "trial_envelope_ok": result["envelope_ok"],
                        "trial_nonfinite_count": result["nonfinite_count"],
                    }
                    path_crossings.append(crossing)
                    all_crossings.append(crossing)
                committed = result["theta"]
            paths.append({
                "pattern": pattern,
                "step_count": step_count,
                "dt_day": dt,
                "transitioning_trial_count": len({c["step_index_zero_based"] for c in path_crossings}),
                "transitioning_component_count": len(path_crossings),
                "max_abs_cell_displacement": max((abs(c["signed_cell_displacement"]) for c in path_crossings), default=0),
                "max_step_mass_residual_cm": max_step_mass,
                "max_cell_mass_residual_cm": max_cell_mass,
                "crossings": path_crossings,
            })

    table_after = hashlib.sha256(table.tobytes(order="C")).hexdigest()
    max_displacement = max((abs(c["signed_cell_displacement"]) for c in all_crossings), default=0)
    max_nodes_crossed = max((len(c["crossed_nodes"]) for c in all_crossings), default=0)
    max_global_mass = max((c["trial_abs_global_mass_residual_cm"] for c in all_crossings), default=0.0)
    max_cell_mass = max((c["trial_max_abs_cell_mass_residual_cm"] for c in all_crossings), default=0.0)
    invalid = sum(
        (not c["trial_domain_ok"]) or (not c["trial_envelope_ok"]) or c["trial_nonfinite_count"] != 0
        for c in all_crossings
    )
    compatible = (
        len(all_crossings) == 8
        and max_displacement == 1
        and max_nodes_crossed == 1
        and max_global_mass <= MASS_TOL_CM
        and max_cell_mass <= MASS_TOL_CM
        and invalid == 0
        and table_before == table_after
    )
    return {
        "schema_version": 1,
        "workstream": "F-ROSS",
        "work_unit": "F-ROSS01",
        "gate": "F_R0_PIECEWISE_TRANSITION_ROUTE_CHARACTERIZATION",
        "contract": CONTRACT,
        "production_implementation": False,
        "material": MATERIAL,
        "profile": PROFILE,
        "n_cells": N_CELLS,
        "patterns": list(PATTERNS),
        "step_counts": list(STEP_COUNTS),
        "preprocessing_seconds_descriptive": preprocessing_seconds,
        "table_sha256": table_before,
        "table_bitwise_unchanged": table_before == table_after,
        "total_transitioning_components": len(all_crossings),
        "max_abs_cell_displacement": max_displacement,
        "max_nodes_crossed_by_one_component_in_one_trial": max_nodes_crossed,
        "max_crossing_trial_abs_global_mass_residual_cm": max_global_mass,
        "max_crossing_trial_abs_cell_mass_residual_cm": max_cell_mass,
        "invalid_crossing_trial_count": invalid,
        "candidate_algebra_changed": False,
        "sigma_or_dt_retuned": False,
        "derivative_averaged_across_node": False,
        "paths": paths,
        "pass": compatible,
        "decision": (
            "PIECEWISE_ADJACENT_CELL_ROUTE_CHARACTERIZED_READY_FOR_F_R1_POLICY_PRECOMMIT"
            if compatible else
            "PIECEWISE_ROUTE_NOT_ADMISSIBLE_USE_EVENT_SPLIT_OR_FALLBACK_RESEARCH"
        ),
    }


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit("usage: run_ross01_gate_f_r0_piecewise_transition_route_characterization.py OUTPUT.json")
    out = Path(sys.argv[1])
    result = run()
    out.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
    print(json.dumps({k: v for k, v in result.items() if k != "paths"}, sort_keys=True), flush=True)
    raise SystemExit(0 if result["pass"] else 1)


if __name__ == "__main__":
    main()
