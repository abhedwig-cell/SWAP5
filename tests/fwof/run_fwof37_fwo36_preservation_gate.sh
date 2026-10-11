#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TMP="${TMPDIR:-/tmp}/swap5-fwof37-fwo36-preservation-$$"
mkdir -p "$TMP"
trap 'rm -rf "$TMP"' EXIT
cd "$ROOT"

BASE_SRC="$ROOT/tests/fwof/run_fwof36_gate_b_physical_binding_gate.sh"
V2_SRC="$ROOT/tests/fwof/run_fwof36_gate_b_physical_binding_gate_v2.sh"
PATCHED_BASE="$TMP/run_fwof36_gate_b_physical_binding_gate.sh"
PATCHED_V2="$TMP/run_fwof36_gate_b_physical_binding_gate_v2.sh"

python3 - "$BASE_SRC" "$PATCHED_BASE" <<'PY'
from pathlib import Path
import sys
s = Path(sys.argv[1]).read_text(encoding='utf-8')
old = '''cat > "$BUILD/expected-source-delta.txt" <<'EOF'
src/runtime/mod_fmr_wofost_accepted_window_lineage.f90
src/runtime/mod_fmr_wofost_physical_trial_binding.f90
EOF
git diff --name-only "$FMR18_CLOSEOUT"..HEAD -- src | sort > "$BUILD/actual-source-delta.txt"
diff -u "$BUILD/expected-source-delta.txt" "$BUILD/actual-source-delta.txt" || fail "unexpected Gate B production source delta"
echo 'FWOF36_GATE_B_EXACT_TWO_FILE_SOURCE_DELTA=PASS'
'''
new = '''cat > "$BUILD/expected-source-delta.txt" <<'EOF'
src/crop/mod_wofost_finalize_rates.f90
src/crop/mod_wofost_one_day_rate_state_view.f90
src/crop/mod_wofost_prepare_assimilation.f90
src/crop/mod_wofost_rate_parameters.f90
src/crop/mod_wofost_rate_table.f90
src/crop/mod_wofost_two_phase_crop_window.f90
src/runtime/mod_fmr_wofost_accepted_window_lineage.f90
src/runtime/mod_fmr_wofost_physical_trial_binding.f90
EOF
git diff --name-only "$FMR18_CLOSEOUT"..HEAD -- src | sort > "$BUILD/actual-source-delta.txt"
diff -u "$BUILD/expected-source-delta.txt" "$BUILD/actual-source-delta.txt" || fail "unexpected F-WOF37 preservation production source closure"
echo 'FWOF37_PRESERVATION_FWO36_EXACT_EIGHT_FILE_SOURCE_CLOSURE=PASS'
'''
if s.count(old) != 1:
    raise SystemExit(f'F-WOF37 F-WOF36 source-lock anchor count={s.count(old)}')
s = s.replace(old, new, 1)
Path(sys.argv[2]).write_text(s, encoding='utf-8')
print('FWOF37_PRESERVATION_FWO36_DISPOSABLE_SOURCE_LOCK_PATCH=PASS')
PY

python3 - "$V2_SRC" "$PATCHED_V2" <<'PY'
from pathlib import Path
import sys
s = Path(sys.argv[1]).read_text(encoding='utf-8')
old_root = 'ROOT="$(cd "$(dirname "$0")/../.." && pwd)"'
if old_root not in s:
    raise SystemExit('F-WOF37 V2 top-level root anchor missing')
# The literal occurs twice in V2: once as the real top-level assignment and
# once inside V2's own Python transformation logic. Replace only the first.
s = s.replace(old_root, 'ROOT="${FWOF37_ROOT:?}"', 1)
old_base = 'python3 - "$ROOT/tests/fwof/run_fwof36_gate_b_physical_binding_gate.sh" "$TMP/gate.sh" <<\'PY\''
new_base = 'python3 - "${FWOF37_FWO36_BASE:?}" "$TMP/gate.sh" <<\'PY\''
if s.count(old_base) != 1:
    raise SystemExit(f'F-WOF37 V2 base-script anchor count={s.count(old_base)}')
s = s.replace(old_base, new_base, 1)
Path(sys.argv[2]).write_text(s, encoding='utf-8')
print('FWOF37_PRESERVATION_FWO36_V2_WRAPPER_PATCH=PASS')
PY

chmod +x "$PATCHED_V2"
FWOF37_ROOT="$ROOT" FWOF37_FWO36_BASE="$PATCHED_BASE" bash "$PATCHED_V2" | tee "$TMP/out.txt"

for marker in \
  'FWOF37_PRESERVATION_FWO36_EXACT_EIGHT_FILE_SOURCE_CLOSURE=PASS' \
  'FWOF36_GATE_B_PHYSICAL_AND_MASS_IDENTITY=PASS' \
  'FWOF36_GATE_B_EXACT_QROT_PTRA_INTEGRALS=PASS' \
  'FWOF36_GATE_B_O0_O2_OUTPUT_IDENTITY=PASS' \
  'FWOF36_GATE_B_TRUE_SINGLE_COLUMN_MULTISWAP_IDENTITY=PASS' \
  'FWOF36_GATE_B_REJECT_THEN_ACCEPT_RETRY_EXACTLY_ONCE=PASS' \
  'FWOF36_GATE_B_DUPLICATE_ACCEPTED_INTERVAL_ZERO_EXTRA_CONTRIBUTION=PASS' \
  'FWOF36_GATE_B_FWO34_EXACT_TRANSCRIPT_PRESERVATION=PASS' \
  'FWOF36_GATE_B_PHYSICAL_BINDING_GATE PASS'; do
  grep -Fq "$marker" "$TMP/out.txt" || { cat "$TMP/out.txt" >&2; exit 1; }
done

echo 'FWOF37_FWO36_REAL_PHYSICS_AND_FWO34_LINEAGE_PRESERVATION=PASS'
echo 'FWOF37_FWO36_PRESERVATION_GATE PASS'
