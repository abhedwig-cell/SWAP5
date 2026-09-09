from __future__ import annotations

import hashlib
import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import run_ross01_gate_j1b_same_factorization_column_response as j1b

CONTRACT = "F-ROSS01_GATE_J1B_O01_CELL_SWITCH_DIAGNOSTIC_CONTRACT.json"
MATERIAL = "O01"


def head_cell_detail(h: float) -> dict:
    i, f, u = j1b.j1a.table_cell(h)
    return {"h_cm": h, "cell_index": i, "cell_fraction": f, "u_log10_negative_head": u}


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit("usage: run_ross01_gate_j1b_o01_cell_switch_diagnostic.py OUTPUT.json")
    out = Path(sys.argv[1])
    catalog = json.loads(j1b.j1a.CATALOG.read_text())
    by_name = {r["sfu"]: r for r in catalog["rows"]}
    row = by_name[MATERIAL]
    j1b.j1a.c1r.base.c1.configure_core(row)
    ksat = float(j1b.j1a.c1r.base.c1.core.KSAT)
    table, preprocessing_seconds, generation_failures = j1b.j1a.c1r.base.generate_table(j1b.j1a.N)
    if generation_failures:
        result = {
            "schema_version": 1,
            "workstream": "F-ROSS",
            "work_unit": "F-ROSS01",
            "gate": "J1B_O01_CELL_SWITCH_DIAGNOSTIC",
            "contract": CONTRACT,
            "material": MATERIAL,
            "pass": False,
            "decision": "DIAGNOSTIC_TABLE_GENERATION_FAILURE",
            "table_generation_failures": len(generation_failures),
        }
        out.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
        raise SystemExit(1)

    table_before = hashlib.sha256(table.tobytes(order="C")).hexdigest()
    cases = []
    invalid = []
    total_switches = 0

    for geometry_name, n_faces, h_top in j1b.GEOMETRIES:
        k_top = float(j1b.j1a.c1r.base.c1.core.k_of_h(h_top))
        for q_fraction in j1b.Q_FRACTIONS:
            q_bottom = q_fraction * k_top
            try:
                heads = j1b.generate_profile(h_top, n_faces, q_bottom, table)
                # Parent J1B requires a unique strict-interior derivative on every
                # base face.  Re-run exactly that validation before FD diagnostics.
                j1b.assemble_system(heads, q_bottom, table)
            except Exception as exc:
                invalid.append({
                    "geometry": geometry_name,
                    "n_faces": n_faces,
                    "h_top_cm": h_top,
                    "q_fraction_of_K_top": q_fraction,
                    "error": repr(exc),
                })
                continue

            base_sig = j1b.cell_signature(heads)
            fd_rows = []
            for factor in j1b.FD_FACTORS:
                q_scale = max(abs(q_bottom), k_top, 1.0e-12 * ksat)
                dq = factor * q_scale
                plus = j1b.generate_profile(h_top, n_faces, q_bottom + dq, table)
                minus = j1b.generate_profile(h_top, n_faces, q_bottom - dq, table)
                plus_sig = j1b.cell_signature(plus)
                minus_sig = j1b.cell_signature(minus)
                switch_indices = [
                    idx for idx, (b, p, m) in enumerate(zip(base_sig, plus_sig, minus_sig))
                    if b != p or b != m
                ]
                total_switches += len(switch_indices)
                switch_details = []
                for idx in switch_indices:
                    switch_details.append({
                        "head_index": idx,
                        "base": head_cell_detail(heads[idx]),
                        "plus": head_cell_detail(plus[idx]),
                        "minus": head_cell_detail(minus[idx]),
                    })
                fd_rows.append({
                    "factor": factor,
                    "delta_q_cm_per_day": dq,
                    "base_signature": list(base_sig),
                    "plus_signature": list(plus_sig),
                    "minus_signature": list(minus_sig),
                    "switch_indices": switch_indices,
                    "switch_details": switch_details,
                })
            cases.append({
                "geometry": geometry_name,
                "n_faces": n_faces,
                "h_top_cm": h_top,
                "q_fraction_of_K_top": q_fraction,
                "q_bottom_cm_per_day": q_bottom,
                "fd_rows": fd_rows,
            })

    table_after = hashlib.sha256(table.tobytes(order="C")).hexdigest()
    localized = total_switches == 1
    result = {
        "schema_version": 1,
        "workstream": "F-ROSS",
        "work_unit": "F-ROSS01",
        "gate": "J1B_O01_CELL_SWITCH_DIAGNOSTIC",
        "contract": CONTRACT,
        "material": MATERIAL,
        "preprocessing_seconds_descriptive": preprocessing_seconds,
        "fd_factors_unchanged": list(j1b.FD_FACTORS),
        "valid_parent_case_count": len(cases),
        "invalid_parent_case_count": len(invalid),
        "total_switch_count": total_switches,
        "cases": cases,
        "invalid_parent_cases": invalid,
        "table_sha256": table_before,
        "table_bitwise_unchanged": table_before == table_after,
        "pass": localized and table_before == table_after,
        "decision": (
            "O01_SINGLE_FD_CELL_SWITCH_LOCALIZED_READY_FOR_J1B_R1_PRECOMMIT"
            if localized and table_before == table_after
            else "O01_CELL_SWITCH_NOT_UNIQUELY_LOCALIZED_KEEP_J1B_BLOCKED"
        ),
        "production_implementation": False,
    }
    out.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
    print(json.dumps({k: v for k, v in result.items() if k not in ("cases", "invalid_parent_cases")}, sort_keys=True), flush=True)
    raise SystemExit(0 if result["pass"] else 1)


if __name__ == "__main__":
    main()
