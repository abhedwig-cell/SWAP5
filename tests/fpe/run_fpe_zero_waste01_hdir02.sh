#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-/tmp}/fpe-hdir02-${GITHUB_RUN_ID:-local}-$$"
OWNER_HEAD="fff0a8be74de3240d56a910f1b19eb4fb50146e9"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"; rm -f tests/fgc/test_fgc31_active_drainage_production_tangent.f90 tests/fgc/run_fgc31_active_drainage_production_tangent.sh' EXIT

python3 - <<'PY'
from pathlib import Path
s=Path('src/adapter/mod_reference_richards_accepted_step_directional_service.f90').read_text()
assert 'allocate(source_direction' not in s
assert 'allocate(sink_direction' not in s
assert 'source_direction = 0.0_real64' not in s
assert 'sink_direction = 0.0_real64' not in s
assert 'direction_request%incoming_source_direction(i)' in s
assert 'direction_request%incoming_sink_direction(i)' in s
assert 'select case (source_sink_direction_case)' in s
print('FPE_ZERO_WASTE01_HDIR02_NO_STAGING_VECTORS=PASS')
PY

test ! -e tests/fgc/test_fgc31_active_drainage_production_tangent.f90
test ! -e tests/fgc/run_fgc31_active_drainage_production_tangent.sh
git show "$OWNER_HEAD:tests/fgc/test_fgc31_active_drainage_production_tangent.f90" > tests/fgc/test_fgc31_active_drainage_production_tangent.f90
git show "$OWNER_HEAD:tests/fgc/run_fgc31_active_drainage_production_tangent.sh" > tests/fgc/run_fgc31_active_drainage_production_tangent.sh
bash tests/fgc/run_fgc31_active_drainage_production_tangent.sh > "$BUILD/out.txt" 2>&1 || {
  cat "$BUILD/out.txt" >&2
  exit 1
}
for marker in   FGC31_ACTIVE_DRAINAGE_MULTI_SUBSTEP   FGC31_ACTIVE_DRAINAGE_COVERAGE_PROVENANCE   FGC31_ACTIVE_DRAINAGE_TANGENT_PHYSICAL_IDENTITY   FGC31_ACTIVE_DRAINAGE_PRODUCTION_FD   FGC31_ACTIVE_DRAINAGE_NO_EXTRA_NONLINEAR_SOLVE   FGC31_ACTIVE_DRAINAGE_ENDPOINT_AUTHORITATIVE   FGC31_ACTIVE_DRAINAGE_PRODUCTION_O0_O2_EXACT_IDENTITY; do
  grep -q "^${marker}=PASS$" "$BUILD/out.txt" || {
    cat "$BUILD/out.txt" >&2
    echo "FPE_HDIR02_FAIL missing ${marker}" >&2
    exit 1
  }
done
cat "$BUILD/out.txt"
echo 'FPE_ZERO_WASTE01_HDIR02_DRAINAGE_SUCCESSOR=PASS'
