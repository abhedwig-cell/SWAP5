#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ORIG="$ROOT/tests/fsi/run_fsi21_dynamic_local_hydraulics.sh"
TMP="$ROOT/tests/fsi/.run_fsi21_dynamic_local_hydraulics_fixed_$$.sh"
trap 'rm -f "$TMP"' EXIT
python3 - "$ORIG" "$TMP" <<'PY'
from pathlib import Path
import sys
src=Path(sys.argv[1]).read_text()
old='''build_run(){
  local opt="$1" tag="$2" out="$BUILD/$tag"
  mkdir -p "$out"
'''
new='''build_run(){
  local opt="$1"
  local tag="$2"
  local out="$BUILD/$tag"
  mkdir -p "$out"
'''
assert src.count(old)==1, src.count(old)
fixed=src.replace(old,new,1)
# The wrapper is allowed to alter exactly this shell-local declaration and nothing else.
assert fixed.replace(new,old,1)==src
Path(sys.argv[2]).write_text(fixed)
PY
chmod +x "$TMP"
exec bash "$TMP"
