from __future__ import annotations
import json
from pathlib import Path

root = Path(__file__).resolve().parents[2]
schema = json.loads((root / "tests/performance/appqual01_result_schema.json").read_text())
workloads = json.loads((root / "tests/performance/appqual01_workloads.json").read_text())

assert schema["schema"] == "swap5-appqual01-v1"
assert len(set(schema["candidate_families"])) == len(schema["candidate_families"])
assert workloads["schema"] == "swap5-appqual01-workload-v1"

ids = [w["id"] for w in workloads["workloads"]]
assert len(ids) == len(set(ids))
by_id = {w["id"]: w for w in workloads["workloads"]}
assert by_id["B0-FGC47-MIXED-LIVE"]["scaling_authority"] is False
assert by_id["B1-S100"]["swap_columns"] == 100
assert by_id["B1-S1000"]["swap_columns"] == 1000
assert by_id["B1-S10000"]["swap_columns"] == 10000
assert by_id["B1-S10000"]["modflow_interface_cells"] == 100
assert by_id["B1-S10000"]["tiles_per_cell"] == 100

print("APPQUAL01_SCHEMA_MANIFEST=PASS")
