from __future__ import annotations

import json
import sys
from pathlib import Path

if len(sys.argv)!=2:
    raise SystemExit("usage: aggregate_rm15_dynamic_top_census.py <output-file>")

path=Path(sys.argv[1])
rows=[]
for line in path.read_text().splitlines():
    if line.startswith("RM15_POINT_JSON="):
        rows.append(json.loads(line.split("=",1)[1]))

expected=[8.64,4.32,2.16,1.08,0.54,0.27,0.135,0.0675,0.03375,0.016875,0.0084375]
if [r["window_seconds"] for r in rows] != expected:
    raise AssertionError(f"RM15 census windows drift: {[r['window_seconds'] for r in rows]}")

success=[r for r in rows if r["status"]==0 and r["diagnostics"]["accepted_substeps"]>=1]
mass_block=[r for r in rows if r["diagnostics"]["mass_rejections"]>0]

for r in rows:
    d=r["diagnostics"]
    print(
        "RM15_POINT "
        f"seconds={r['window_seconds']:.9g} status={r['status']} "
        f"accepted={d['accepted_substeps']} attempts={d['attempts']} "
        f"solver_rej={d['solver_rejections']} temporal_rej={d['temporal_rejections']} "
        f"temporal_unavailable={d['temporal_unavailable_rejections']} "
        f"mass_rej={d['mass_rejections']} max_temporal={d['max_temporal_indicator']:.17g}"
    )

if mass_block:
    decision="MASS_ACCOUNTING_BLOCKER_PRESENT"
elif success:
    decision="BOUNDED_WINDOW_SUCCESS_EXISTS"
else:
    decision="STRUCTURAL_FAILURE_ACROSS_CENSUS"

print(f"RM15_DECISION={decision}")
print(f"RM15_SUCCESS_COUNT={len(success)}")
if success:
    print(f"RM15_LARGEST_SUCCESS_WINDOW_SECONDS={max(r['window_seconds'] for r in success):.17g}")
    print(f"RM15_SMALLEST_SUCCESS_WINDOW_SECONDS={min(r['window_seconds'] for r in success):.17g}")
print("RM15_DYNAMIC_TOP_DURATION_CENSUS=PASS")
