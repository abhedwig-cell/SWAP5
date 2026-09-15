#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

BASE="$ROOT/qualification/run_fpm02_current_canonical_snow_preservation.sh"
GENERATED="$ROOT/qualification/.run_fpm02_current_canonical_snow_preservation_v2_generated.sh"
trap 'rm -f "$GENERATED"' EXIT

python3 - "$BASE" "$GENERATED" <<'PY'
from pathlib import Path
import sys
src=Path(sys.argv[1]).read_text(encoding='utf-8')
anchor="echo 'SNOW_CC_IMMUTABLE_RUNTIME_FIXTURES_REHYDRATED=PASS'\n"
if src.count(anchor) != 1:
    raise SystemExit('typed-layout adaptation anchor count mismatch')
adapt=r'''# F-VQ17 predates the typed optional-state-layout registry. Adapt only the
# disposable verifier fixture to the current public Snow layout identity.
# No Snow assertion, parameter, forcing, state, timing, mass or transaction
# expectation is changed.
cp "$BUILD/test_snow_multiswap.f90" "$BUILD/test_snow_multiswap.pre-layout-adaptation.f90"
python3 - "$BUILD/test_snow_multiswap.f90" <<'PY_LAYOUT'
from pathlib import Path
import sys
p=Path(sys.argv[1])
s=p.read_text(encoding='utf-8')
old_use="       fmr_aggregate_diagnostics_t, FMR_BACKEND_SERIALIZED_REFERENCE\n"
new_use="       fmr_aggregate_diagnostics_t, FMR_BACKEND_SERIALIZED_REFERENCE, FMR_OPTIONAL_STATE_LAYOUT_SNOW\n"
old_layout="    tmpl%optional_state_layout_id = 71705_int64\n"
new_layout="    tmpl%optional_state_layout_id = FMR_OPTIONAL_STATE_LAYOUT_SNOW\n"
if s.count(old_use) != 1 or s.count(old_layout) != 1:
    raise SystemExit('unexpected F-VQ17 verifier shape for typed-layout adaptation')
s=s.replace(old_use,new_use,1).replace(old_layout,new_layout,1)
p.write_text(s,encoding='utf-8')
PY_LAYOUT
python3 - "$BUILD/test_snow_multiswap.pre-layout-adaptation.f90" "$BUILD/test_snow_multiswap.f90" <<'PY_LAYOUT_AUDIT'
from pathlib import Path
import sys
before=Path(sys.argv[1]).read_text(encoding='utf-8')
after=Path(sys.argv[2]).read_text(encoding='utf-8')
# Removing the two allowed metadata substitutions must reconstruct the exact
# immutable verifier byte-for-byte.
restored=after.replace(', FMR_OPTIONAL_STATE_LAYOUT_SNOW\n','\n',1).replace(
    '    tmpl%optional_state_layout_id = FMR_OPTIONAL_STATE_LAYOUT_SNOW\n',
    '    tmpl%optional_state_layout_id = 71705_int64\n',1)
assert restored == before
for token in [
 'FVQ17_PROFILE_ALL_INACTIVE_1_2_17_31=PASS',
 'FVQ17_PROFILE_ALL_ACTIVE_1_2_17_31=PASS',
 'FVQ17_PROFILE_MIXED_1_2_17_31=PASS',
 'FVQ17_DIRECT_FVQ16_SNOW_STATE_IDENTITY=PASS',
 'FVQ17_NONZERO_MELT_INTERNAL_TRANSFER=PASS',
 'FVQ17_REVERSE_ORDER_AGGREGATE_MASS_IDENTITY=PASS',
 'FVQ17_A_B_A_EXACT=PASS',
 'FVQ17_AUTHORITATIVE_MASS_COMPLETE=PASS',
 'FVQ17_SUBDAILY_RUNTIME_FAIL_CLOSED=PASS',
 'FVQ17_MULTIDAY_RUNTIME_FAIL_CLOSED=PASS',
 'FVQ17_MAX_SIMULTANEOUS_REAL_PHYSICAL_SOLVES=1'
]:
    assert token in after, token
print('SNOW_CC_FVQ17_TYPED_LAYOUT_FIXTURE_ADAPTATION_ONLY=PASS')
print('SNOW_CC_FVQ17_SCIENTIFIC_ASSERTIONS_UNCHANGED=PASS')
PY_LAYOUT_AUDIT
'''
src=src.replace(anchor,anchor+adapt,1)
Path(sys.argv[2]).write_text(src,encoding='utf-8')
PY

chmod +x "$GENERATED"
exec bash "$GENERATED"
