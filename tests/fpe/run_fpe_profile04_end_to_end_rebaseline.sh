#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-profile04-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT

# PROFILE04 is deliberately an orchestration-only measurement harness.
# It reuses qualified production-shaped runners and emits one compact record.

echo "PROFILE04_CANONICAL_HEAD=$(git rev-parse HEAD)"

echo "PROFILE04_PHASE=SETUP_PLANVALID"
bash tests/fpe/run_fpe_planvalid01_application_timing.sh | tee "$BUILD/planvalid.txt"
grep 'PLANVALID01_APP_PAIRED_N=' "$BUILD/planvalid.txt" || true

echo "PROFILE04_PHASE=SETUP_AHL"
bash tests/fahl/run_fahl49_application_scale.sh | tee "$BUILD/ahl_scale.txt"
grep '^FAHL49_SCALE|' "$BUILD/ahl_scale.txt"

echo "PROFILE04_PHASE=REPEATED_REFERENCE"
TIMING_MODE=reference bash tests/fpe/run_fpe_zero_waste01_paired_runtime.sh | tee "$BUILD/reference.txt"
grep 'FPE_ZERO_WASTE01_REFERENCE_PAIRED_' "$BUILD/reference.txt"

echo "PROFILE04_PHASE=REPEATED_DIRECTIONAL"
TIMING_MODE=directional bash tests/fpe/run_fpe_zero_waste01_paired_runtime.sh | tee "$BUILD/directional.txt"
grep 'FPE_ZERO_WASTE01_DIRECTIONAL_PAIRED_' "$BUILD/directional.txt"

python3 - "$BUILD" <<'PY'
import pathlib,re,sys
b=pathlib.Path(sys.argv[1])
def grab(path,key):
    txt=(b/path).read_text()
    m=re.search(rf'^{re.escape(key)}=([^\n]+)$',txt,re.M)
    return m.group(1).strip() if m else "NA"
print("PROFILE04_SUMMARY|"
      f"REF_ZERO_WASTE_RATIO={grab('reference.txt','FPE_ZERO_WASTE01_REFERENCE_PAIRED_MEDIAN_RATIO')}|"
      f"DIR_ZERO_WASTE_RATIO={grab('directional.txt','FPE_ZERO_WASTE01_DIRECTIONAL_PAIRED_MEDIAN_RATIO')}")
print("FPE_PROFILE04_MEASUREMENT=PASS")
PY
