#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

fail() { echo "FPM08D7_TEMPORAL_PRESERVATION_GATE_FAIL $*" >&2; exit 89; }
CANONICAL='0aeb0a2ed4096e1f9493d3dabc70962ea5270182'
CANONICAL_BACKEND_BLOB='9af5a494526810324dc00706b444e448e770cba9'
PRE_PATCH='00ac0cf029cb50a4182f6e25ab9b355028e7ff4c'
PATCH='e6c7b2cb0d0e1c75707fe39ecaeaec657ad66436'
BACKEND='src/runtime/mod_fmr_serialized_reference_backend.f90'
PATCHED_BACKEND_BLOB='251a12a0133b48dd8e6bfd1a1e1ff3ce515db274'

[[ "$(git rev-parse "$CANONICAL:$BACKEND")" == "$CANONICAL_BACKEND_BLOB" ]] || fail 'canonical backend authority drift'
[[ "$(git rev-parse "HEAD:$BACKEND")" == "$PATCHED_BACKEND_BLOB" ]] || fail 'candidate backend blob drift'
[[ "$(git diff --name-only "$PRE_PATCH".."$PATCH" -- src)" == "$BACKEND" ]] || fail 'preservation production patch is not single-file'
[[ "$(git diff --numstat "$PRE_PATCH".."$PATCH" -- "$BACKEND")" == $'7\t7\t'"$BACKEND" ]] || fail 'preservation production patch is not exact +7/-7'
echo 'FPM08D7_TEMPORAL_PRESERVATION_EXACT_PATCH_SCOPE=PASS'

CANON_FILE="$(mktemp)"
trap 'rm -f "$CANON_FILE"' EXIT
git show "$CANONICAL:$BACKEND" > "$CANON_FILE"
python3 - "$CANON_FILE" "$BACKEND" <<'PY'
from pathlib import Path
import sys
canonical = Path(sys.argv[1]).read_text()
candidate = Path(sys.argv[2]).read_text()

required_numeric = [
    'all(full%pressure_head == half%pressure_head)',
    'all(full%water_content == half%water_content)',
    'full%ponding_depth == half%ponding_depth',
    'full%groundwater_level == half%groundwater_level',
    'full%snow%process%snow_water_storage == half%snow%process%snow_water_storage',
    'full%snow%process%liquid_water_storage == half%snow%process%liquid_water_storage',
    'full%snow%event_t0 == half%snow%event_t0',
]
if not all(x in canonical for x in required_numeric):
    raise SystemExit('FPM08D7_TEMPORAL_PRESERVATION_GATE_FAIL canonical numeric-equality authority missing')

a = candidate.index('  logical function base_physical_states_identical')
b = candidate.index('  end function base_physical_states_identical', a)
helper = candidate[a:b]
if not all(x in helper for x in required_numeric):
    raise SystemExit('FPM08D7_TEMPORAL_PRESERVATION_GATE_FAIL candidate base helper does not preserve canonical equality')
if 'same_real_bits(' in helper:
    raise SystemExit('FPM08D7_TEMPORAL_PRESERVATION_GATE_FAIL bit identity remains in ordinary base helper')
if 'pure elemental logical function same_real_bits(a, b)' not in candidate:
    raise SystemExit('FPM08D7_TEMPORAL_PRESERVATION_GATE_FAIL unrelated bit-identity helper disappeared')
if 'value = abs(full%surface_water%storage - half%surface_water%storage)' not in candidate:
    raise SystemExit('FPM08D7_TEMPORAL_PRESERVATION_GATE_FAIL D7 SWST temporal metric drift')
print('FPM08D7_CANONICAL_BASE_TEMPORAL_IDENTITY_PRESERVED=PASS')
print('FPM08D7_SWST_TEMPORAL_METRIC_UNCHANGED=PASS')
PY

git diff --check "$PRE_PATCH".."$PATCH"
echo 'FPM08D7_TEMPORAL_PRESERVATION_OWNER_GATE=PASS'
