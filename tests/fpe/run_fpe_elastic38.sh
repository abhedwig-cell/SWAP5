#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

python3 tests/fpe/run_fpe_elastic38_crs_capability.py

python3 - <<'PY'
import subprocess
base=subprocess.check_output(["git","merge-base","HEAD","origin/integration/f-ci-canonical"],text=True).strip()
names=subprocess.check_output(["git","diff","--name-only",base+"..HEAD"],text=True).splitlines()
prod=[p for p in names if p.startswith("src/")]
if prod:
    raise SystemExit("F_PE_ELASTIC38_SOURCE_SCOPE_FAIL="+repr(prod))
print("F_PE_ELASTIC38_A10_SOURCE_SCOPE=PASS")
PY

echo "F_PE_ELASTIC38_RUN=PASS"
