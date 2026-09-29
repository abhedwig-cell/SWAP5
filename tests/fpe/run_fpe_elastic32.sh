#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

ARTIFACT_DIR="${1:-${RUNNER_TEMP:-${TMPDIR:-/tmp}}/elastic32-pdok}"
OUT="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/elastic32-spatial-source-audit.json"

LOG="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/elastic32-spatial-source-audit.log"
python3 tools/fpe_elastic32_spatial_source_audit.py \
  --artifact-dir "$ARTIFACT_DIR" \
  --output "$OUT" > "$LOG" 2>&1
cat "$LOG"

for marker in \
  'F_PE_ELASTIC32_A2_GPKG_CORE=PASS' \
  'F_PE_ELASTIC32_A3_FEATURE_AUTHORITY=PASS' \
  'F_PE_ELASTIC32_A4_MAPAREA_DOMAIN_IDENTITY=PASS' \
  'F_PE_ELASTIC32_A5_COUNTS=PASS' \
  'F_PE_ELASTIC32_A6_GEOMETRY_SRS=PASS' \
  'F_PE_ELASTIC32_A7_SRS_DEFINITION=PASS' \
  'F_PE_ELASTIC32_A8_ANOMALY_COUNTS=PASS' \
  'F_PE_ELASTIC32_A9_SPATIAL_METADATA=PASS' \
  'F_PE_ELASTIC32=PASS'; do
  grep -Fq "$marker" "$LOG" || {
    echo "F_PE_ELASTIC32_FAIL missing marker $marker" >&2
    exit 1
  }
done

python3 - "$OUT" <<'PY'
import json,sys
p=sys.argv[1]
d=json.load(open(p,encoding="utf-8"))
assert d["source_artifact_sha256"]=="f96bea1e9efdd0326ae1ca0d72684cd7928c90fd23f0930b51c782dfc0ff5fe6"
assert d["maparea_domain_identity"] is True
print("F_PE_ELASTIC32_A1_SOURCE_AUTHORITY=PASS")
PY

python3 - <<'PY'
import subprocess
base=subprocess.check_output(["git","merge-base","HEAD","origin/integration/f-ci-canonical"],text=True).strip()
names=subprocess.check_output(["git","diff","--name-only",base+"..HEAD"],text=True).splitlines()
prod=[p for p in names if p.startswith("src/")]
if prod:
    raise SystemExit("F_PE_ELASTIC32_SOURCE_SCOPE_FAIL="+repr(prod))
print("F_PE_ELASTIC32_A10_SOURCE_SCOPE=PASS")
PY

cat "$OUT"
echo "F_PE_ELASTIC32_RUN=PASS"
