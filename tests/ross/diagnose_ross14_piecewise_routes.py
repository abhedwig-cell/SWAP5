from __future__ import annotations

import argparse
import hashlib
import json
import sys
from collections import Counter, defaultdict
from pathlib import Path

SE_LEVELS = (0.65, 0.85, 0.98)
STEP_COUNTS = (2, 4, 8, 16)
TARGET_TOP_INTERNAL_OVER_K = -0.025
TARGET_BOTTOM_UP_OVER_K = 0.011


def parse_args():
    p = argparse.ArgumentParser()
    p.add_argument("--research-root", required=True, type=Path)
    p.add_argument("--fingerprint-authority", required=True, type=Path)
    p.add_argument("--material", required=True)
    p.add_argument("--output", required=True, type=Path)
    return p.parse_args()


def import_research(root: Path):
    exp = root / "experiments" / "ross"
    sys.path.insert(0, str(exp))
    import run_ross01_gate_f_timestep_convergence as gate_f
    return gate_f


def head_from_se(se, row):
    n = float(row["n"])
    m = 1.0 - 1.0 / n
    return -((se ** (-1.0 / m) - 1.0) ** (1.0 / n)) / float(row["alpha_per_cm"])


def target_external(gate_f, heads):
    ext = gate_f.fixed_external(heads, "zero")
    ext["q_top"] = TARGET_TOP_INTERNAL_OVER_K * float(ext["k_top"])
    ext["q_bottom"] = -TARGET_BOTTOM_UP_OVER_K * float(ext["k_bottom"])
    return ext


def exact_node(gate_f, h):
    return gate_f.j1a.table_cell(h)[1] == 0.0


def main():
    a = parse_args()
    gate_f = import_research(a.research_root.resolve())
    authority = json.loads(a.fingerprint_authority.read_text())
    catalog = json.loads(
        (a.research_root / "integration" / "f-ross" / "F-ROSS01_GATE_C1_MATERIAL_CATALOG.json").read_text()
    )
    by_name = {row["sfu"]: row for row in catalog["rows"]}
    if a.material not in by_name:
        raise SystemExit(f"unknown material {a.material}")
    row = by_name[a.material]
    gate_f.j1a.c1r.base.c1.configure_core(row)
    table, _, failures = gate_f.j1a.c1r.base.generate_table(gate_f.j1a.N)
    fingerprint = hashlib.sha256(table.tobytes(order="C")).hexdigest()
    expected = authority["fingerprints"][a.material]
    if failures or fingerprint != expected:
        raise SystemExit(f"F_ROSS14D_FAIL fingerprint {a.material}")

    route_rows = []
    trial_rows = []
    for se in SE_LEVELS:
        h0 = head_from_se(se, row)
        heads0 = tuple(h0 for _ in range(16))
        theta0 = tuple(gate_f.gate_d.theta_from_head(h) for h in heads0)
        ext = target_external(gate_f, heads0)

        for step_count in STEP_COUNTS:
            dt = gate_f.HORIZON_DAY / step_count
            committed = theta0
            for step_index in range(step_count):
                start_heads = gate_f.heads_from_theta(committed)
                result = gate_f.candidate_step(committed, table, ext, dt)
                end_heads = tuple(result["heads"])
                changed = []
                for i, (h_start, h_end) in enumerate(zip(start_heads, end_heads)):
                    c0 = gate_f.j1a.table_cell(h_start)[0]
                    c1 = gate_f.j1a.table_cell(h_end)[0]
                    if c0 != c1:
                        changed.append({
                            "component": i,
                            "start_cell": int(c0),
                            "end_cell": int(c1),
                            "displacement": int(c1 - c0),
                            "exact_node_endpoint": exact_node(gate_f, h_end),
                        })

                admissible = True
                if changed:
                    admissible = (
                        len(changed) == 1
                        and abs(changed[0]["displacement"]) == 1
                        and not changed[0]["exact_node_endpoint"]
                        and result["domain_ok"]
                        and result["envelope_ok"]
                        and result["nonfinite_count"] == 0
                        and result["abs_global_mass_residual_cm"] <= gate_f.MASS_TOL_CM
                        and result["max_abs_cell_mass_residual_cm"] <= gate_f.MASS_TOL_CM
                    )
                    route_rows.append({
                        "se": se,
                        "step_count": step_count,
                        "dt_day": dt,
                        "step_index": step_index,
                        "component_count": len(changed),
                        "max_abs_cell_displacement": max(abs(x["displacement"]) for x in changed),
                        "exact_node_endpoint_count": sum(x["exact_node_endpoint"] for x in changed),
                        "admissible": admissible,
                        "changes": changed,
                    })

                trial_rows.append({
                    "se": se,
                    "step_count": step_count,
                    "step_index": step_index,
                    "transition": bool(changed),
                    "transition_admissible": admissible,
                    "domain_ok": bool(result["domain_ok"]),
                    "head_envelope_ok": bool(result["envelope_ok"]),
                    "nonfinite_count": int(result["nonfinite_count"]),
                    "abs_global_mass_residual_cm": float(result["abs_global_mass_residual_cm"]),
                    "max_abs_cell_mass_residual_cm": float(result["max_abs_cell_mass_residual_cm"]),
                })
                committed = tuple(result["theta"])

    inadmissible = [r for r in route_rows if not r["admissible"]]
    by_se = Counter(f"{r['se']:.2f}" for r in inadmissible)
    by_step = Counter(str(r["step_count"]) for r in inadmissible)
    by_pair = Counter(f"Se={r['se']:.2f}|steps={r['step_count']}" for r in inadmissible)
    production_relevant = [r for r in inadmissible if r["step_count"] in (8, 16)]

    result = {
        "schema_version": 1,
        "workstream": "F-ROSS",
        "work_unit": "F-ROSS14D1",
        "kind": "PIECEWISE_ROUTE_FAILURE_DIAGNOSTIC",
        "parent_work_unit": "F-ROSS14",
        "parent_status": "BLOCKED_DECISIVE_PIECEWISE_ROUTE_FAILURE",
        "material": a.material,
        "research_head": "04807fdcf45453a59b7f6c99fe97f1286c172833",
        "table_fingerprint": fingerprint,
        "table_fingerprint_matches_authority": True,
        "effective_saturation": list(SE_LEVELS),
        "step_counts": list(STEP_COUNTS),
        "target_top_internal_over_K": TARGET_TOP_INTERNAL_OVER_K,
        "target_bottom_up_over_K": TARGET_BOTTOM_UP_OVER_K,
        "transition_route_count": len(route_rows),
        "inadmissible_route_count": len(inadmissible),
        "inadmissible_by_Se": dict(sorted(by_se.items())),
        "inadmissible_by_step_count": dict(sorted(by_step.items(), key=lambda kv: int(kv[0]))),
        "inadmissible_by_Se_and_step_count": dict(sorted(by_pair.items())),
        "production_relevant_inadmissible_count": len(production_relevant),
        "production_relevant_step_counts": [8, 16],
        "production_relevant_failure": bool(production_relevant),
        "max_transitioning_components": max((r["component_count"] for r in route_rows), default=0),
        "max_abs_cell_displacement": max((r["max_abs_cell_displacement"] for r in route_rows), default=0),
        "exact_node_endpoint_count": sum(r["exact_node_endpoint_count"] for r in route_rows),
        "max_abs_global_mass_residual_cm": max(t["abs_global_mass_residual_cm"] for t in trial_rows),
        "max_abs_cell_mass_residual_cm": max(t["max_abs_cell_mass_residual_cm"] for t in trial_rows),
        "domain_failure_count": sum(not t["domain_ok"] for t in trial_rows),
        "head_envelope_failure_count": sum(not t["head_envelope_ok"] for t in trial_rows),
        "nonfinite_count": sum(t["nonfinite_count"] for t in trial_rows),
        "inadmissible_routes": inadmissible,
        "verdict": (
            "PRODUCTION_RELEVANT_PIECEWISE_FAILURE_PRESENT"
            if production_relevant else
            "FAILURES_ONLY_OUTSIDE_PRODUCTION_RELEVANT_8_16_STEP_TRAJECTORIES"
        ),
        "production_admission_effect": "NONE; diagnostic only, F-ROSS14 remains blocked",
    }
    a.output.parent.mkdir(parents=True, exist_ok=True)
    a.output.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
    print(json.dumps({
        "material": a.material,
        "transition_routes": len(route_rows),
        "inadmissible_routes": len(inadmissible),
        "production_relevant_inadmissible": len(production_relevant),
        "by_se": result["inadmissible_by_Se"],
        "by_step": result["inadmissible_by_step_count"],
        "max_components": result["max_transitioning_components"],
        "max_displacement": result["max_abs_cell_displacement"],
        "verdict": result["verdict"],
    }, sort_keys=True))


if __name__ == "__main__":
    main()
