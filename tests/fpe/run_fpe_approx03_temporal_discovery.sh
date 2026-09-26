#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-approx03-temporal-discovery-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT

RAW="$BUILD/raw.txt"
bash tests/fpe/run_fpe_approx02_a2_transaction.sh 2>&1 | tee "$RAW"

python3 - "$RAW" <<'PY'
import sys
rows=[]
for line in open(sys.argv[1]):
    if not line.startswith("APPROX02_A2_TRANSACTION|"):
        continue
    d={}
    for part in line.strip().split("|")[1:]:
        if "=" in part:
            k,v=part.split("=",1); d[k]=v
    rows.append(d)
if len(rows)!=12:
    raise SystemExit(f"expected 12 transaction rows, got {len(rows)}")

selected=[]
for r in rows:
    exact_sub=int(r["EXACT_ACCEPTED_SUBSTEPS"])
    exact_retry=int(r["EXACT_RETRIES"])
    exact_nl=int(r["EXACT_NONLINEAR"])
    exact_mass=int(r["EXACT_MASS_REJECTIONS"])
    print(
      f"APPROX03_TEMPORAL_DISCOVERY|MATERIAL={r['MATERIAL']}|REGIME={r['REGIME']}"
      f"|ACCEPTED_SUBSTEPS={exact_sub}|RETRIES={exact_retry}|NONLINEAR={exact_nl}"
      f"|MASS_REJECTIONS={exact_mass}|MAX_MASS_RESIDUAL={r['EXACT_MAX_MASS_RESIDUAL']}"
    )
    if exact_sub>8 or exact_retry>0:
        selected.append((exact_sub,exact_retry,exact_nl,r))
if not selected:
    raise SystemExit("no exact temporal-refinement workload found in external-full-half matrix")
selected.sort(key=lambda x:(x[0],x[1],x[2]),reverse=True)
sub,retry,nl,r=selected[0]
print(
  f"APPROX03_TEMPORAL_SELECTED|MATERIAL={r['MATERIAL']}|REGIME={r['REGIME']}"
  f"|ACCEPTED_SUBSTEPS={sub}|RETRIES={retry}|NONLINEAR={nl}"
)
print("FPE_APPROX03_TEMPORAL_DISCOVERY=PASS")
PY
