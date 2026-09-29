#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

ARTIFACT_DIR="${1:-${RUNNER_TEMP:-${TMPDIR:-/tmp}}/elastic24-pdok}"

python3 tests/fpe/run_fpe_elastic24.py \
  --repo-root "$ROOT" \
  --artifact-dir "$ARTIFACT_DIR"

python3 - <<'PY'
import subprocess
base=subprocess.check_output(["git","merge-base","HEAD","origin/integration/f-ci-canonical"],text=True).strip()
names=subprocess.check_output(["git","diff","--name-only",base+"..HEAD"],text=True).splitlines()
prod=[p for p in names if p.startswith("src/")]
if prod:
    raise SystemExit("F_PE_ELASTIC24_SOURCE_SCOPE_FAIL="+repr(prod))
print("F_PE_ELASTIC24_A10_SOURCE_SCOPE=PASS")
PY

echo "F_PE_ELASTIC24_RUN=PASS"
