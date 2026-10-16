#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

ARTIFACT_DIR="${1:-${RUNNER_TEMP:-${TMPDIR:-/tmp}}/elastic34-pdok}"
OUT="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/elastic34-rd-point-maparea.json"
LOG="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/elastic34-rd-point-maparea.log"

if ! python3 tests/fpe/run_fpe_elastic34.py   --repo-root "$ROOT"   --artifact-dir "$ARTIFACT_DIR"   --output "$OUT" > "$LOG" 2>&1; then
  cat "$LOG" >&2
  exit 1
fi
cat "$LOG"

for marker in   'F_PE_ELASTIC34_A1_SOURCE_AUTHORITY=PASS'   'F_PE_ELASTIC34_A2_SYNTHETIC_POLICY=PASS'   'F_PE_ELASTIC34_A3_ALL_GEOMETRIES_DECODE=PASS'   'F_PE_ELASTIC34_A4_IDENTITY=PASS'   'F_PE_ELASTIC34_A5_REAL_SOURCE_PROBES=PASS'   'F_PE_ELASTIC34_A6_BOUNDARY_FAIL_CLOSED=PASS'   'F_PE_ELASTIC34_A7_OUTSIDE_NOT_FOUND=PASS'   'F_PE_ELASTIC34_A8_AMBIGUITY_FAIL_CLOSED=PASS'   'F_PE_ELASTIC34_A9_REPEAT_DETERMINISM=PASS'   'F_PE_ELASTIC34=PASS'; do
  grep -Fq "$marker" "$LOG" || {
    echo "F_PE_ELASTIC34_FAIL missing marker $marker" >&2
    exit 1
  }
done

python3 - <<'PY'
import subprocess
base=subprocess.check_output(["git","merge-base","HEAD","origin/integration/f-ci-canonical"],text=True).strip()
names=subprocess.check_output(["git","diff","--name-only",base+"..HEAD"],text=True).splitlines()
prod=[p for p in names if p.startswith("src/")]
if prod:
    raise SystemExit("F_PE_ELASTIC34_SOURCE_SCOPE_FAIL="+repr(prod))
print("F_PE_ELASTIC34_A10_SOURCE_SCOPE=PASS")
PY

cat "$OUT"
echo "F_PE_ELASTIC34_RUN=PASS"
