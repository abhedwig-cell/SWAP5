from __future__ import annotations
import json
import re
import sys
from pathlib import Path

if len(sys.argv) != 4:
    raise SystemExit("usage: collect_appqual01_b1_reference.py <transcript> <source_commit> <output_json>")

text = Path(sys.argv[1]).read_text(encoding="utf-8")
source_commit = sys.argv[2]
out = Path(sys.argv[3])

pat = re.compile(
    r"^APPQUAL01_B1_REFERENCE,n=(?P<n>\d+),init_seconds=\s*(?P<init>[^,]+),"
    r"run_seconds=\s*(?P<run>[^,]+),ns_per_column=\s*(?P<ns>[^,]+),"
    r"max_mass_residual=\s*(?P<mass>[^\n]+)$",
    re.MULTILINE,
)
records = []
for m in pat.finditer(text):
    n = int(m.group("n"))
    records.append({
        "schema": "swap5-appqual01-v1",
        "run_id": f"B1-S{n}-REFERENCE",
        "source_commit": source_commit,
        "candidate_family": "REFERENCE",
        "candidate_config": "cleaned-reference-richards",
        "workload_id": f"B1-S{n}",
        "swap_columns": n,
        "performance": {
            "initialization_seconds": float(m.group("init")),
            "swap_run_seconds": float(m.group("run")),
            "ns_per_column": float(m.group("ns")),
        },
        "hydrology": {
            "max_mass_residual": float(m.group("mass")),
        },
        "scaling_authority": True,
    })

expected = [100, 1000, 10000]
if [r["swap_columns"] for r in records] != expected:
    raise SystemExit(f"unexpected B1 records: {[r['swap_columns'] for r in records]}")
if text.count("APPQUAL01_B1_REFERENCE=PASS") != 3:
    raise SystemExit("missing B1 PASS markers")
if any(r["performance"]["swap_run_seconds"] <= 0.0 for r in records):
    raise SystemExit("nonpositive B1 runtime")

out.write_text(json.dumps({"schema":"swap5-appqual01-b1-reference-v1","records":records}, indent=2, sort_keys=True)+"\n", encoding="utf-8")
print("APPQUAL01_B1_REFERENCE_RECORDS=PASS")
