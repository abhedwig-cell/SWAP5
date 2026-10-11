#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/ppa-wu05-migmac01-source-origin-diagnostic-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "PPA_WU05_PERCH20_TX_FAIL $*" >&2; exit 1; }

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace)
mapfile -t MODULE_SRC < <(python3 - <<'PY'
from pathlib import Path
import re

stub = Path('tests/fsi/ppa_wu05a18_andelst_headcalc_stubs.f90')
test = Path('tests/fpm/test_ppa_wu05_migmac01_corrected_source_diagnostic.f90')
forced = [Path('src/legacy/b1_10_port/headcalc.f90')]

module_re = re.compile(r'^\s*module\s+(?!procedure\b)([a-z][a-z0-9_]*)', re.I | re.M)
use_re = re.compile(r'^\s*use(?:\s*,[^:]*)?(?:\s*::)?\s*([a-z][a-z0-9_]*)', re.I | re.M)

def defs(path):
    return {m.lower() for m in module_re.findall(path.read_text(errors='ignore'))}

def uses(path):
    return {m.lower() for m in use_re.findall(path.read_text(errors='ignore'))}

provided = defs(stub)
owners = {}
for path in sorted(Path('src').rglob('*.f90')):
    for mod in defs(path):
        if mod in owners and owners[mod] != path:
            raise SystemExit(f'duplicate module owner {mod}: {owners[mod]} {path}')
        owners[mod] = path

ordered, visiting, done = [], set(), set()
def visit_module(mod):
    if mod in provided or mod not in owners:
        return
    visit_file(owners[mod])

def visit_file(path):
    path = Path(path)
    key = str(path)
    if key in done:
        return
    if key in visiting:
        raise SystemExit(f'Fortran module dependency cycle at {key}')
    visiting.add(key)
    for dep in sorted(uses(path)):
        visit_module(dep)
    visiting.remove(key)
    done.add(key)
    ordered.append(path)

for mod in sorted(uses(test)):
    visit_module(mod)
for path in forced:
    visit_file(path)

print(stub)
for path in ordered:
    print(path)
PY
)

for opt in 0 2; do
  OUT="$BUILD/o$opt"; mkdir -p "$OUT"; objects=()
  for source in "${MODULE_SRC[@]}"; do
    obj="$OUT/$(basename "${source%.*}").o"
    gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$source" -o "$obj" || fail "compile O$opt $source"
    objects+=("$obj")
  done
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c \
    tests/fpm/test_ppa_wu05_migmac01_corrected_source_diagnostic.f90 -o "$OUT/test.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/test.o" -o "$OUT/test"
  "$OUT/test" | tee "$OUT/out.txt"
  grep -Fq 'PPA_WU05_MIGMAC01_CORRECTED_SOURCE=SOURCE_TRANSACTION_QUALIFIED' "$OUT/out.txt"
  grep -Fq 'PPA_WU05_MIGMAC01_SOURCE_REJECT_REPLAY=PASS' "$OUT/out.txt"
  grep -Fq 'PPA_WU05_MIGMAC01_SOURCE_COMMIT=PASS' "$OUT/out.txt"
  grep -Fq 'PPA_WU05_MIGMAC01_SOURCE_RESTART=PASS' "$OUT/out.txt"

done
echo 'PPA_WU05_MIGMAC01_CORRECTED_SOURCE_TRANSACTION_O0_O2=PASS'
