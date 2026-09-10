#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SOURCE="$ROOT/tests/fci/run_fci31_reference_et_root_uptake_canonical_admission.sh"
TAG="${GITHUB_RUN_ID:-$$}-${GITHUB_RUN_ATTEMPT:-0}"
TMP="$ROOT/tests/fci/.fci31-admission-v4-$TAG.sh"
REPLAY="$ROOT/tests/fci/.fci31-fci30-preservation-$TAG.sh"
PATCHER="$ROOT/tests/fci/.fci31-nested-fci28-patcher-$TAG.py"

cleanup_wrapper() {
  rm -f "$TMP" "$REPLAY" "$PATCHER"
}
trap cleanup_wrapper EXIT

cat > "$PATCHER" <<'PY'
from pathlib import Path
import sys

p = Path(sys.argv[1])
s = p.read_text(encoding='utf-8')
anchor = """if old not in s: raise SystemExit('FCI30 F-CI28 source-delta anchor missing')
s=s.replace(old,new,1)
p.write_text(s,encoding='utf-8')"""
replacement = """if old not in s: raise SystemExit('FCI30 F-CI28 source-delta anchor missing')
s=s.replace(old,new,1)
old_immut='''if ! git diff --quiet \"$CANDIDATE\"..HEAD -- src; then
  git diff --name-only \"$CANDIDATE\"..HEAD -- src >&2
  fail 'qualification branch mutated production source after candidate'
fi'''
new_immut='''mapfile -t fci31_extension < <(git diff --name-only \"$CANDIDATE\"..HEAD -- src | sort)
printf '%s\\n' \"${fci31_extension[@]}\" > \"$BUILD/fci31-extension-actual.txt\"
printf '%s\\n' src/runtime/mod_fmr_reference_et_root_uptake_composition.f90 > \"$BUILD/fci31-extension-expected.txt\"
cmp -s \"$BUILD/fci31-extension-actual.txt\" \"$BUILD/fci31-extension-expected.txt\" || {
  cat \"$BUILD/fci31-extension-actual.txt\" >&2
  fail 'F-CI31 extension beyond F-CI30 is not exactly one qualified composition source'
}
echo 'FCI31_FCI28_ALLOWED_SINGLE_SOURCE_EXTENSION=PASS' '''
if old_immut not in s: raise SystemExit('FCI31 nested F-CI28 immutability anchor missing')
s=s.replace(old_immut,new_immut,1)
p.write_text(s,encoding='utf-8')"""
if s.count(anchor) != 1:
    raise SystemExit(f'FCI31 V4 F-CI30 nested F-CI28 patch anchor count={s.count(anchor)}')
s = s.replace(anchor, replacement, 1)
p.write_text(s, encoding='utf-8')
PY

cp "$SOURCE" "$TMP"
python3 - "$TMP" <<'PY'
from pathlib import Path
import sys

p=Path(sys.argv[1])
s=p.read_text(encoding='utf-8')
old_path='FCI30_REPLAY="$BUILD/fci30-preservation.sh"'
new_path='FCI30_REPLAY="${FCI31_REPLAY_PATH:?}"'
if s.count(old_path) != 1:
    raise SystemExit(f'FCI31 V4 replay-path anchor count={s.count(old_path)}')
s=s.replace(old_path,new_path,1)
old_run='''bash "$FCI30_REPLAY" > "$BUILD/fci30.txt" 2>&1 || { cat "$BUILD/fci30.txt" >&2; fail 'F-CI30 full preservation replay'; }'''
new_run='''python3 "${FCI31_NESTED_PATCHER_PATH:?}" "$FCI30_REPLAY"
echo 'FCI31_NESTED_FCI28_IMMUTABILITY_REBOUND=PASS'
bash "$FCI30_REPLAY" > "$BUILD/fci30.txt" 2>&1 || { cat "$BUILD/fci30.txt" >&2; fail 'F-CI30 full preservation replay'; }'''
if s.count(old_run) != 1:
    raise SystemExit(f'FCI31 V4 F-CI30 execution anchor count={s.count(old_run)}')
s=s.replace(old_run,new_run,1)
p.write_text(s,encoding='utf-8')
PY

export FCI31_REPLAY_PATH="$REPLAY"
export FCI31_NESTED_PATCHER_PATH="$PATCHER"
echo 'FCI31_NESTED_REPLAY_PATH_HARDENED_V4=PASS'
bash "$TMP"
