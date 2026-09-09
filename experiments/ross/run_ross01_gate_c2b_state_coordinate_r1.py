from __future__ import annotations

import json
import math
import sys
from pathlib import Path

import run_ross01_gate_c2b_state_coordinate_conditioning as base

N = 241
CELL_WIDTH_U = 4.0 / (N - 1)
ROUNDTRIP_CELL_FRACTION_MAX = 1.0e-8
ROUNDTRIP_ABS_MAX = CELL_WIDTH_U * ROUNDTRIP_CELL_FRACTION_MAX
JOIN_U = math.log10(4.2)

_original_state_to_u = base.state_to_u


def state_to_u_r1(s: float, c: dict):
    if s == c["s105"]:
        return JOIN_U, "wet"
    return _original_state_to_u(s, c)


base.state_to_u = state_to_u_r1
base.ROUNDTRIP_TOL = ROUNDTRIP_ABS_MAX


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit("usage: run_ross01_gate_c2b_state_coordinate_r1.py OUTPUT.json")
    out = Path(sys.argv[1])
    catalog = json.loads(base.CATALOG_PATH.read_text())
    results = []
    for index, row in enumerate(catalog["rows"], 1):
        result = base.run_material(row)
        c = base.constants(row)
        join_u, join_branch = state_to_u_r1(c["s105"], c)
        join_error = abs(join_u - JOIN_U)
        join_failure = int(join_error != 0.0 or join_branch != "wet")
        if join_failure:
            if "exact_join_mapping_failures" not in result["failed_metrics"]:
                result["failed_metrics"].append("exact_join_mapping_failures")
            result["pass"] = False
        result["exact_join_mapping_failures"] = join_failure
        result["exact_join_u"] = JOIN_U
        result["join_u_abs_error"] = join_error
        result["roundtrip_fraction_of_table_cell"] = result["max_abs_u_roundtrip_error_from_log_head_origin"] / CELL_WIDTH_U
        results.append(result)
        print(json.dumps({
            "progress": f"{index}/{len(catalog['rows'])}",
            "material": row["sfu"],
            "pass": result["pass"],
            "max_mp_error": result["max_abs_u_error_vs_80_digit_reference"],
            "roundtrip_fraction_of_cell": result["roundtrip_fraction_of_table_cell"],
            "max_source_difference": result["max_normalized_forward_difference_vs_direct_source_arithmetic"],
            "failed_metrics": result["failed_metrics"],
        }), flush=True)

    failed = [r for r in results if not r["pass"]]
    aggregate = {
        "max_abs_u_error_vs_80_digit_reference": max(r["max_abs_u_error_vs_80_digit_reference"] for r in results),
        "max_abs_u_roundtrip_error_from_log_head_origin": max(r["max_abs_u_roundtrip_error_from_log_head_origin"] for r in results),
        "max_abs_u_roundtrip_fraction_of_table_cell": max(r["roundtrip_fraction_of_table_cell"] for r in results),
        "max_normalized_forward_difference_vs_direct_source_arithmetic": max(r["max_normalized_forward_difference_vs_direct_source_arithmetic"] for r in results),
        "nan_or_inf_failures": sum(r["nan_or_inf_count"] for r in results),
        "coordinate_domain_failures": sum(r["coordinate_outside_closed_interval_count"] for r in results),
        "monotonicity_failures": sum(r["monotonicity_violation_count"] for r in results),
        "endpoint_mapping_failures": sum(r["exact_endpoint_mapping_failures"] for r in results),
        "exact_join_mapping_failures": sum(r["exact_join_mapping_failures"] for r in results),
        "out_of_domain_rejection_failures": sum(r["out_of_domain_rejection_failures"] for r in results),
        "branch_selection_failures": sum(r["branch_selection_failures"] for r in results),
    }
    evidence = {
        "schema_version": 1,
        "workstream": "F-ROSS",
        "work_unit": "F-ROSS01",
        "gate": "C2B_DIRECT_STATE_TO_LOG_HEAD_TABLE_COORDINATE_R1",
        "contract": "F-ROSS01_GATE_C2B_STATE_COORDINATE_R1_CONTRACT.json",
        "candidate_N": N,
        "table_cell_width_u": CELL_WIDTH_U,
        "material_count": len(results),
        "pass_count": len(results) - len(failed),
        "fail_count": len(failed),
        "failed_materials": [r["material"] for r in failed],
        "aggregate": aggregate,
        "thresholds": {
            "max_abs_u_error_vs_80_digit_reference": base.REF_TOL,
            "max_abs_u_roundtrip_fraction_of_table_cell": ROUNDTRIP_CELL_FRACTION_MAX,
            "max_normalized_forward_difference_vs_direct_source_arithmetic": base.SOURCE_EQ_TOL,
        },
        "materials": results,
        "pass": not failed,
        "decision": "C2B_STATE_COORDINATE_R1_PASS_READY_FOR_FACE_TABLE_CHARACTERIZATION" if not failed else "C2B_STATE_COORDINATE_R1_FAIL_CLOSED",
        "scope_guard": "Coordinate mapping only for C2B h=[-10000,-1] cm with N241 resolution; no face-flux or transient qualification."
    }
    out.write_text(json.dumps(evidence, indent=2, sort_keys=True) + "\n")
    print(json.dumps({k: v for k, v in evidence.items() if k != "materials"}, indent=2, sort_keys=True))
    raise SystemExit(0 if evidence["pass"] else 1)


if __name__ == "__main__":
    main()
