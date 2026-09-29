#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
ARTIFACT_DIR="${1:-${RUNNER_TEMP:-${TMPDIR:-/tmp}}/elastic36-pdok}"
LOG="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/elastic36.log"

if ! python3 tests/fpe/run_fpe_elastic36.py   --repo-root "$ROOT"   --artifact-dir "$ARTIFACT_DIR" > "$LOG" 2>&1; then
  cat "$LOG" >&2
  exit 1
fi
cat "$LOG"

for marker in   'F_PE_ELASTIC36_A1_PARENT_AUTHORITY=PASS'   'F_PE_ELASTIC36_A2_REAL_MAPAREA_SELECTION=PASS'   'F_PE_ELASTIC36_A3_SQL_PROFILE_IDENTITY=PASS'   'F_PE_ELASTIC36_A4_ELASTIC24_IDENTITY=PASS'   'F_PE_ELASTIC36_A5_ELASTIC33_BYTE_IDENTITY=PASS'   'F_PE_ELASTIC36_A6_BROAD_SAMPLE=PASS'   'F_PE_ELASTIC36_A7_SPATIAL_FAIL_CLOSED=PASS'   'F_PE_ELASTIC36_A8_RELATION_FAIL_CLOSED=PASS'   'F_PE_ELASTIC36_A9_REPEAT_IDENTITY=PASS'   'F_PE_ELASTIC36=PASS'; do
  grep -Fq "$marker" "$LOG" || {
    echo "F_PE_ELASTIC36_FAIL missing marker $marker" >&2
    exit 1
  }
done

python3 - <<'PY'
import subprocess
base=subprocess.check_output(["git","merge-base","HEAD","origin/integration/f-ci-canonical"],text=True).strip()
names=subprocess.check_output(["git","diff","--name-only",base+"..HEAD"],text=True).splitlines()
prod=[p for p in names if p.startswith("src/")]
if prod:
    raise SystemExit("F_PE_ELASTIC36_SOURCE_SCOPE_FAIL="+repr(prod))
print("F_PE_ELASTIC36_A10_SOURCE_SCOPE=PASS")
PY

echo "F_PE_ELASTIC36_RUN=PASS"
