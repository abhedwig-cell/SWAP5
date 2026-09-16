#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SOURCE="$ROOT/tests/fci/run_fci30_parallel_v1_canonical_admission.sh"
TMP="$ROOT/tests/fci/.fci30-admission-v2-$$.sh"

cleanup_wrapper() {
  rm -f "$TMP"
}
trap cleanup_wrapper EXIT

cp "$SOURCE" "$TMP"
python3 - "$TMP" <<'PY'
from pathlib import Path
import sys

p = Path(sys.argv[1])
s = p.read_text(encoding='utf-8')
old = '''trap 'rm -rf "$BUILD"; rm -f "$ROOT/tests/fmr/.fci30-fmr18-replay-$$.sh" "$ROOT/tests/fci/.fci30-fci28-replay-$$.sh"' EXIT\n'''
new = '''cleanup_fci30() {
  rm -rf "$BUILD"
  rm -f "$ROOT/tests/fmr/.fci30-fmr18-replay-$$.sh" "$ROOT/tests/fci/.fci30-fci28-replay-$$.sh"
}
trap cleanup_fci30 EXIT
'''
if s.count(old) != 1:
    raise SystemExit(f'FCI30 V2 cleanup anchor count={s.count(old)}')
s = s.replace(old, new, 1)
p.write_text(s, encoding='utf-8')
PY

echo 'FCI30_CLEANUP_TRAP_HARDENED=PASS'
bash "$TMP"
