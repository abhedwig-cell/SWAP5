from __future__ import annotations

import json
import math
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import run_lmfp09_gate_c_endpoint_pair as ep
import run_lmfp09_gate_c3_anchored_endpoint_axis as c3
import run_lmfp09_gate_c3b_offgrid_holdout as c3b
import run_lmfp09_homogeneous_face_matrix as core
from run_lmfp09_coordinate_envelope import FIXTURES

ALLOWED_BASE_N = (33, 49, 65, 97)
ALLOWED_CLASSES = (("reference_sand", 10.0), ("very_fast", 5.0))


def main():
    if len(sys.argv) != 5:
        raise SystemExit(
            "usage: run_lmfp09_gate_c4_global_density.py EVIDENCE_JSON MATERIAL HALF_FACE_LENGTH_CM BASE_N"
        )
    out = Path(sys.argv[1])
    material_name = sys.argv[2]
    length = float(sys.argv[3])
    base_n = int(sys.argv[4])
    if base_n not in ALLOWED_BASE_N:
        raise SystemExit(("unsupported_precommitted_base_n", base_n))
    if (material_name, length) not in ALLOWED_CLASSES:
        raise SystemExit(("unsupported_precommitted_class", material_name, length))

    fixtures = {f.name: f for f in FIXTURES}
    fixture = fixtures[material_name]

    # Freeze all C3 semantics except the globally selected base-axis cardinality.
    c3.BASE_N = base_n
    ep.bracket = c3.tolerant_bracket

    evidence = {
        "schema_version": 1,
        "work_unit": "F-LMFP09",
        "gate": "C4_GLOBAL_ENDPOINT_DENSITY_CHARACTERIZATION",
        "qualification": False,
        "material": material_name,
        "half_face_length_cm": length,
        "base_axis_nodes": base_n,
        "anchors_changed_from_C3": False,
        "thresholds_changed_from_C2_C3": False,
        "probe_set": "REVEALED_C3B_CHARACTERIZATION_SET_NOT_VALID_FOR_QUALIFICATION",
        "status": "IN_PROGRESS",
        "stage": "PROVIDER_PREPARATION",
    }
    out.write_text(json.dumps(evidence, indent=2, sort_keys=True) + "\n")

    view, oracle_solves, _ = c3.build_provider(fixture, length)
    provider = {
        "actual_axis_nodes_after_anchors": view.nx,
        "table_values": view.memory()["values"],
        "bytes_before_metadata": view.memory()["bytes_before_metadata"],
        "offline_oracle_solves": oracle_solves,
    }
    evidence["provider"] = provider
    evidence["stage"] = "HOLDOUT_REFERENCE_GENERATION"
    out.write_text(json.dumps(evidence, indent=2, sort_keys=True) + "\n")

    probes, attempts = c3b.holdout_rows(fixture.material, length)
    evidence["probe_count"] = len(probes)
    evidence["random_sampling_attempts"] = attempts
    evidence["stage"] = "EVALUATION"
    out.write_text(json.dumps(evidence, indent=2, sort_keys=True) + "\n")

    metrics = core.metrics_for_view(view, probes)
    worst = None
    for row in metrics["rows"]:
        score = math.inf if row.get("failed") else row.get("corrected_error", -1.0)
        if worst is None or score > worst[0]:
            worst = (score, row)

    summary = {k: v for k, v in metrics.items() if k != "rows"}
    evidence.update({
        "metrics": summary,
        "worst_probe": worst[1] if worst else None,
        "status": "COMPLETED",
        "stage": "COMPLETE",
        "decision": "C4_DENSITY_CHARACTERIZATION_RECORDED_NO_QUALIFICATION_CLAIM",
    })
    out.write_text(json.dumps(evidence, indent=2, sort_keys=True) + "\n")
    print(json.dumps({
        "material": material_name,
        "half_face_length_cm": length,
        "base_axis_nodes": base_n,
        "provider": provider,
        "metrics": summary,
        "worst_probe": evidence["worst_probe"],
        "decision": evidence["decision"],
    }, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
