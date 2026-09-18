#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-fapp07-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/o0" "$BUILD/o2"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "F_APP07_FAIL $*" >&2; exit 1; }

SRC=src/process/mod_tcs1_dcs2_sprinkling_irrigation_process.f90
TEST=tests/f-app07/test_tcs1_dcs2_sprinkling_process.f90
[[ -f "$SRC" && -f "$TEST" ]] || fail "missing source/test"

grep -Fq 'pure subroutine evaluate_tcs1_dcs2_sprinkling_interval' "$SRC" || fail "missing pure process"
if grep -Eiq 'open[[:space:]]*\(|read[[:space:]]*\(|write[[:space:]]*\(' "$SRC"; then
  fail "process contains file or formatted I/O"
fi
if grep -Eiq 'mod_rutter|mod_fmr|headcalc|timecontrol' "$SRC"; then
  fail "process depends on runtime, interception or solver internals"
fi

COMMON=(-std=f2008 -pedantic-errors -ffree-line-length-none -Wall -Wextra -Werror -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
for opt in 0 2; do
  OUT="$BUILD/o$opt"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$SRC" -o "$OUT/process.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$TEST" -o "$OUT/test.o"
  gfortran -O"$opt" "$OUT/process.o" "$OUT/test.o" -o "$OUT/test"
  "$OUT/test" > "$OUT/output.txt" 2>&1 || { cat "$OUT/output.txt" >&2; fail "runtime O$opt"; }
  grep -Fq 'F_APP07_TCS1_DCS2_HUPSEL_PROCESS=PASS' "$OUT/output.txt" || fail "missing Hupsel marker O$opt"
  grep -Fq 'F_APP07_TCS1_DCS2_SPLIT_REPLAY=PASS' "$OUT/output.txt" || fail "missing split marker O$opt"
  grep -Fq 'F_APP07_TCSFIX_DAYFIX=PASS' "$OUT/output.txt" || fail "missing dayfix marker O$opt"
  echo "F_APP07_O${opt}=PASS"
done
cmp -s "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" || { diff -u "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" >&2 || true; fail "O0/O2 drift"; }
cat "$BUILD/o0/output.txt"
echo "F_APP07_OUTPUT_SHA256=$(sha256sum "$BUILD/o0/output.txt" | awk '{print $1}')"
echo 'F_APP07_TCS1_DCS2_PROCESS_QUALIFICATION=PASS'

# Exact application composition over every accepted Hupsel interval with active irrigation.
FIX=tests/f-app07/fixtures/hupsel_irrigation_active_intervals_b111.csv.gz
test "$(sha256sum "$FIX" | awk '{print $1}')" = aa2b900691f124701b3f98d3c660f3b27291b3da4a94754db64c86b36252eaec || fail "irrigation fixture drift"
python3 - "$FIX" "$BUILD/irrigation.csv" <<'PY'
import gzip,hashlib,sys
raw=gzip.open(sys.argv[1],"rb").read()
assert hashlib.sha256(raw).hexdigest()=="98c7031e28f134e3f1f2ddee788788f4b8855d4f38f178777bbc5e24721dd63b"
open(sys.argv[2],"wb").write(raw)
PY

BIND=src/runtime/mod_fmr_hupsel_irrigation_application_binding.f90
grep -Fq 'fmr_bind_tcs1_sprinkling_to_rutter' "$BIND" || fail "missing scheduled-to-Rutter binding"
grep -Fq 'fmr_bind_rutter_net_irrigation_to_dynamic_top' "$BIND" || fail "missing Rutter-to-dynamic-top binding"
grep -Fq 'fmr_bind_fixed_surface_irrigation_identity_to_dynamic_top' "$BIND" || fail "missing fixed SWINTER0 identity binding"

COMPOSITION_SRC=(
  src/solver/mod_soil_water_solver_contract.f90
  src/solver/mod_process_hydraulic_view.f90
  src/process/mod_irrigation_process.f90
  src/process/mod_tcs1_dcs2_sprinkling_irrigation_process.f90
  src/process/mod_rutter_interception_process.f90
  src/process/mod_restricted_surface_evaporation.f90
  src/solver/mod_b110_default_mvg_provider.f90
  src/solver/mod_b110_dynamic_top_boundary_provider.f90
  src/runtime/mod_fmr_hupsel_irrigation_application_binding.f90
)
COMP=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
for opt in 0 2; do
  OUT="$BUILD/composition-o$opt"; mkdir -p "$OUT"; objects=()
  for source in "${COMPOSITION_SRC[@]}"; do
    obj="$OUT/$(basename "${source%.*}").o"
    extra=()
    if [[ "$source" == "$BIND" || "$source" == "$SRC" ]]; then extra=(-Werror -pedantic-errors); fi
    gfortran "${COMP[@]}" "${extra[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$source" -o "$obj" || fail "composition compile O$opt $source"
    objects+=("$obj")
  done
  gfortran "${COMP[@]}" -Wno-error=compare-reals -O"$opt" -J "$OUT" -I "$OUT"     -c tests/f-app07/test_hupsel_irrigation_composition.f90 -o "$OUT/test.o" || fail "composition oracle compile O$opt"
  gfortran -O"$opt" "${objects[@]}" "$OUT/test.o" -o "$OUT/test" || fail "composition link O$opt"
  "$OUT/test" "$BUILD/irrigation.csv" > "$OUT/output.txt" 2>&1 || { cat "$OUT/output.txt" >&2; fail "composition runtime O$opt"; }
  grep -Fq 'F_APP07_EXACT_ACTIVE_INTERVALS=110' "$OUT/output.txt" || fail "active interval count O$opt"
  grep -Fq 'F_APP07_SWINTER0_INTERVALS=18' "$OUT/output.txt" || fail "SWINTER0 count O$opt"
  grep -Fq 'F_APP07_SWINTER3_INTERVALS=92' "$OUT/output.txt" || fail "SWINTER3 count O$opt"
  grep -Fq 'F_APP07_IRRIGATION_RUTTER_DYNAMIC_TOP_COMPOSITION=PASS' "$OUT/output.txt" || fail "composition marker O$opt"
done
cmp -s "$BUILD/composition-o0/output.txt" "$BUILD/composition-o2/output.txt" || { diff -u "$BUILD/composition-o0/output.txt" "$BUILD/composition-o2/output.txt" >&2 || true; fail "composition O0/O2 drift"; }
cat "$BUILD/composition-o0/output.txt"
echo "F_APP07_COMPOSITION_OUTPUT_SHA256=$(sha256sum "$BUILD/composition-o0/output.txt" | awk '{print $1}')"
echo 'F_APP07_EXACT_110_INTERVAL_COMPOSITION=PASS'
