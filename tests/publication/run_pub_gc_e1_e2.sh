#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
OUT="${PUB_GC_EVIDENCE_DIR:-$ROOT/build/pub-gc-e1-e2}"
mkdir -p "$OUT"

python3 -m pytest -q tests/fgc/test_fgc41_whole_window_acceptance_retry.py | tee "$OUT/fgc41.txt"
bash tests/fgc/run_fgc44_real_swap_modflow_end_to_end.sh | tee "$OUT/fgc44.txt"

for marker in \
  'PUB_GC_E1_INTERFACE_IDENTITY=PASS' \
  'PUB_GC_E2_REJECTED_TRIAL_ZERO_AUTHORITY=PASS' \
  'PUB_GC_E2_PREPUBLICATION_ABORT_ZERO_AUTHORITY=PASS' \
  'PUB_GC_E2_EXACTLY_ONCE_PUBLICATION=PASS' \
  'PUB_GC_E2_PUBLICATION_ORDER=PASS'; do
  grep -Fq "$marker" "$OUT/fgc44.txt"
done

python3 - "$OUT" <<'PY'
from __future__ import annotations
import json
import os
import sys
from pathlib import Path

out=Path(sys.argv[1])
lines=(out/"fgc44.txt").read_text().splitlines()
values={}
passes=[]
for line in lines:
    if "=" not in line:
        continue
    key,value=line.strip().split("=",1)
    if key.startswith("PUB_GC_"):
        if value=="PASS":
            passes.append(key)
        else:
            try: values[key]=float(value)
            except ValueError: values[key]=value

record={
    "schema":"pub-gc-e1-e2-result-v1",
    "source_head":os.environ.get("GITHUB_SHA","local"),
    "modflow_version":"6.8.0",
    "window_day":1.0e-4,
    "deterministic_fgc41_failure_injection":"PASS",
    "passes":sorted(passes),
    "values":values,
}
(out/"PUB_GC_E1_E2_RESULT.json").write_text(json.dumps(record,indent=2,sort_keys=True)+"\n")
print(json.dumps(record,indent=2,sort_keys=True))
PY

echo "PUB_GC_E1_E2_EVIDENCE=PASS"
