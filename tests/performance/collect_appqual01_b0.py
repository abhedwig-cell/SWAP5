from __future__ import annotations
import json
import re
import sys
from pathlib import Path

if len(sys.argv) != 4:
    raise SystemExit("usage: collect_appqual01_b0.py <transcript> <source_commit> <output_json>")

transcript = Path(sys.argv[1]).read_text(encoding="utf-8")
source_commit = sys.argv[2]
output = Path(sys.argv[3])

def number(key: str) -> float:
    m = re.search(rf"^{re.escape(key)}=([^\n]+)$", transcript, flags=re.MULTILINE)
    if not m:
        raise SystemExit(f"missing metric {key}")
    return float(m.group(1).strip())

def integer(key: str) -> int:
    return int(round(number(key)))

required_markers = [
    "FGC47_REAL_MIXED_TOPOLOGY_END_TO_END=PASS",
    "FGC47_CONJUNCTIVE_MIXED_TOPOLOGY_CONVERGENCE=PASS",
    "FGC47_PER_CELL_LEDGER_CLOSURE=PASS",
]
for marker in required_markers:
    if marker not in transcript:
        raise SystemExit(f"missing B0 semantic marker: {marker}")

record = {
    "schema": "swap5-appqual01-v1",
    "run_id": "B0-FGC47-MIXED-LIVE",
    "source_commit": source_commit,
    "candidate_family": "REFERENCE",
    "candidate_config": "cleaned-reference-richards",
    "workload_id": "B0-FGC47-MIXED-LIVE",
    "swap_columns": 3,
    "modflow_interface_cells": 2,
    "modflow_version": "6.8.0",
    "performance": {
        "coupling_seconds": number("FGC47_COUPLING_SECONDS"),
        "coupling_outer_iterations": integer("FGC47_COUPLING_OUTER_ITERATIONS"),
        "modflow_solve_calls": integer("FGC47_MODFLOW_SOLVE_CALLS"),
    },
    "hydrology": {
        "groundwater_head_m": [
            number("FGC47_FINAL_HEAD1_M"),
            number("FGC47_FINAL_HEAD2_M"),
        ],
        "interface_exchange_m_per_s": [
            number("FGC47_FINAL_QCELL1_M_PER_S"),
            number("FGC47_FINAL_QCELL2_M_PER_S"),
        ],
        "coupling_residual_m_per_s": [
            number("FGC47_FINAL_R1"),
            number("FGC47_FINAL_R2"),
        ],
    },
    "semantic_gates": {
        "end_to_end": True,
        "coupled_convergence": True,
        "per_cell_ledger_closure": True,
    },
    "scaling_authority": False,
}

if record["performance"]["coupling_seconds"] <= 0.0:
    raise SystemExit("nonpositive B0 coupling runtime")
if record["performance"]["coupling_outer_iterations"] <= 0:
    raise SystemExit("invalid B0 coupling iteration count")
if record["performance"]["modflow_solve_calls"] < record["performance"]["coupling_outer_iterations"]:
    raise SystemExit("MODFLOW solve count below coupling outer iteration count")

output.write_text(json.dumps(record, indent=2, sort_keys=True) + "\n", encoding="utf-8")
print("APPQUAL01_B0_METRIC_RECORD=PASS")
