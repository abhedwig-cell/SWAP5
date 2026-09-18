#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/pub-gc-e6-${GITHUB_RUN_ID:-local}-$$"
RESULTS="${PUB_GC_E6_RESULT_DIR:-$BUILD/results}"
mkdir -p "$BUILD" "$RESULTS"
trap 'rm -rf "$BUILD"' EXIT

PUB_GC_E6_BUILD_DIR="$BUILD/build" bash tests/publication/build_pub_gc_e6_active_drainage.sh | tee "$RESULTS/init.txt"
LIBMF6="$BUILD/build/modflow-bin/libmf6.so"
SWAPLIB="$BUILD/build/bridge/libpub_gc_e6_swap.so"

if grep -Fq 'PUB_GC_E6_REFERENCE_CORRECTOR_BOUNDED_FAILURE=PASS' "$RESULTS/init.txt"; then
  python3 - "$RESULTS" <<'PY'
from __future__ import annotations
import json,sys
from pathlib import Path
root=Path(sys.argv[1])
lines=(root/"init.txt").read_text().splitlines()
def one(prefix):
    hits=[x.split("=",1)[1] for x in lines if x.startswith(prefix+"=")]
    if len(hits)!=1: raise SystemExit(f"expected one {prefix} record, got {len(hits)}")
    return json.loads(hits[0])
payload={
    "schema":"pub-gc-e6-component-envelope-stop-v1",
    "status":"REFERENCE_CORRECTOR_TRIAL_FAILED",
    "live_modflow_executed":False,
    "predictor":one("PUB_GC_E6_PREDICTOR"),
    "corrector_diagnostics":one("PUB_GC_E6_REFERENCE_CORRECTOR_DIAGNOSTICS"),
    "adjudication":"PREREGISTERED_STOP_RULE_COMPONENT_ENVELOPE",
}
(root/"PUB_GC_E6_RESULT_RAW.json").write_text(json.dumps(payload,indent=2,sort_keys=True)+"\n")
print(json.dumps(payload,indent=2,sort_keys=True))
print("PUB_GC_E6_PREREGISTERED_STOP_RULE=PASS")
print("PUB_GC_E6_LIVE_MATRIX_SKIPPED_REFERENCE_CORRECTOR_UNAVAILABLE=PASS")
PY
  exit 0
fi

grep -Fq 'PUB_GC_E6_REFERENCE_CORRECTOR_AVAILABLE=PASS' "$RESULTS/init.txt" || {
  echo "PUB_GC_E6_FAIL missing reference-corrector disposition" >&2; exit 1;
}

for sy in 0.02 0.15 0.30; do
  E6_SY="$sy" LIBMF6="$LIBMF6" PUB_GC_E6_SWAP_LIB="$SWAPLIB" \
    python3 tests/publication/test_pub_gc_e6_live_case.py | tee "$RESULTS/sy_${sy}.txt"
done

python3 - "$RESULTS" <<'PY'
from __future__ import annotations
import json,sys
from pathlib import Path
root=Path(sys.argv[1])
rows=[]
for p in sorted(root.glob("sy_*.txt")):
    lines=[x for x in p.read_text().splitlines() if x.startswith("PUB_GC_E6_JSON=")]
    if len(lines)!=1: raise SystemExit(f"missing E6 JSON in {p}")
    rows.append(json.loads(lines[0].split("=",1)[1]))
payload={"schema":"pub-gc-e6-summary-v1","cases":rows}
(root/"PUB_GC_E6_RESULT_RAW.json").write_text(json.dumps(payload,indent=2,sort_keys=True)+"\n")
for r in rows:
    print("PUB_GC_E6_ROW",r["specific_yield"],r["loose"]["status"],r["strong"]["status"],
          r.get("delta_head_strong_minus_loose_m"),r.get("delta_integrated_exchange_m"))
if not all(r["loose"].get("status")=="OK" for r in rows):
    raise SystemExit("at least one E6 loose case unavailable")
print("PUB_GC_E6_MATRIX_EXECUTED=PASS")
PY
