#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/ppa-wu05a7-real-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "PPA_WU05A7_REAL_FAIL $*" >&2; exit 1; }

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace)
mapfile -t MODULE_SRC < <(python3 <<'SOURCES'
from pathlib import Path
lines=Path('tests/fpm/run_ppa_wu05a26_backend_compile.sh').read_text().splitlines()
inside=False
for raw in lines:
    s=raw.strip()
    if s == 'MODULE_SRC=(':
        inside=True
        continue
    if inside and s == ')':
        break
    if inside and s:
        print(s)
SOURCES
)
# Current backend prerequisites are completed in dependency order; A7/A8
# assertions and compiler flags remain unchanged.
mapfile -t MODULE_SRC < <(python3 tests/support/augment_bartholomeus_backend_sources.py "${MODULE_SRC[@]}")

for opt in 0 2; do
  OUT="$BUILD/o$opt"; mkdir -p "$OUT"; objects=()
  for source in "${MODULE_SRC[@]}"; do
    obj="$OUT/$(basename "${source%.*}").o"
    gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$source" -o "$obj" || fail "compile O$opt $source"
    objects+=("$obj")
  done
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c     tests/fpm/test_ppa_wu05a7_real_richards_runtime.f90 -o "$OUT/test.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/test.o" -o "$OUT/test"
  "$OUT/test" | tee "$OUT/out.txt"
  grep -Fq 'PPA_WU05A7_REAL_RICHARDS_RUNTIME=PASS' "$OUT/out.txt"

  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c     tests/fpm/test_ppa_wu05a8_fmr_macropore_trial.f90 -o "$OUT/test_fmr_macro.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/test_fmr_macro.o" -o "$OUT/test_fmr_macro"
  "$OUT/test_fmr_macro" | tee "$OUT/fmr_macro.txt"
  grep -Fq 'PPA_WU05A8_FMR_MACRO_TRIAL=PASS' "$OUT/fmr_macro.txt"
done
cmp "$BUILD/o0/out.txt" "$BUILD/o2/out.txt"
cmp "$BUILD/o0/fmr_macro.txt" "$BUILD/o2/fmr_macro.txt"
echo "PPA_WU05A8_REAL_RICHARDS_GATE=PASS"
