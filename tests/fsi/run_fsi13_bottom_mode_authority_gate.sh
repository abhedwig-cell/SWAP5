#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fsi13-bottom-authority-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

BASE_CORE="$ROOT/tests/fsi/run_fsi12_explicit_controls_gate.sh"

make_variant() {
  local mode="$1" out="$2"
  awk '/^# Legacy direct-call compatibility:/{exit} {print}' "$BASE_CORE" > "$out"
  python3 - "$out" "$mode" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1])
mode=int(sys.argv[2])
s=p.read_text()
if mode == -2:
    marker="def physical_profile(s):\n"
    insert=marker+"    s=s.replace('request%boundary%bottom_mode = 7','request%boundary%bottom_mode = -2',1)\n"
    if marker not in s: raise SystemExit('F-SI13 mode -2 physical_profile marker missing')
    s=s.replace(marker,insert,1)
elif mode != 7:
    raise SystemExit('F-SI13 authority gate supports only 7 and -2')
needle="  dt = 99.0_real64\n  maxit = 0"
repl="  swbotb = 5\n  dt = 99.0_real64\n  maxit = 0"
if needle not in s: raise SystemExit('F-SI13 swbotb poison insertion marker missing')
s=s.replace(needle,repl,1)
needle="  if (transfer(dt,0_int64) /= transfer(99.0_real64,0_int64)) failures = failures + 1"
repl="  if (swbotb /= 5) failures = failures + 1\n"+needle
if needle not in s: raise SystemExit('F-SI13 swbotb persistence marker missing')
s=s.replace(needle,repl,1)
p.write_text(s)
PY
  chmod +x "$out"
}

for mode in 7 -2; do
  script="$BUILD/mode-${mode}.sh"
  make_variant "$mode" "$script"
  bash "$script"
  echo "F-SI13_BOTTOM_MODE_${mode}_REQUEST_AUTHORITY PASS"
done

echo 'F-SI13_BOTTOM_MODE_GLOBAL_POISON PASS'
echo 'F-SI13_BOTTOM_MODE_AUTHORITY_GATE PASS'
