#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-fvq124-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/o0" "$BUILD/o2"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "F_VQ124_FAIL $*" >&2; exit 1; }

SUBJECT=5b70bed7a3758b052e3d22ba0b771ed123c96954
SRC=src/process/mod_tcs1_dcs2_sprinkling_irrigation_process.f90
BIND=src/runtime/mod_fmr_hupsel_irrigation_application_binding.f90
TEST=tests/fvq/test_fvq124_fapp07_tcs1_dcs2_independent.f90
COMP_TEST=tests/fvq/test_fvq124_fapp07_composition_independent.f90
FIX=tests/f-app07/fixtures/hupsel_irrigation_active_intervals_b111.csv.gz

[[ "$(git rev-parse HEAD:$SRC)" == 6ff53ac9c97b7b4c42fa8043193aa03bb116bd13 ]] || fail "candidate process drift"
[[ "$(git rev-parse HEAD:$BIND)" == ca5fd1cd5353ba18deae89b7e1178b1b9bb43435 ]] || fail "candidate binding drift"
[[ -z "$(git diff --name-only "$SUBJECT"..HEAD -- src)" ]] || fail "qualification mutated production source"
test "$(sha256sum "$FIX" | awk '{print $1}')" = aa2b900691f124701b3f98d3c660f3b27291b3da4a94754db64c86b36252eaec || fail "fixture archive drift"
python3 - "$FIX" "$BUILD/irrigation.csv" <<'PY'
import gzip,hashlib,sys
raw=gzip.open(sys.argv[1],"rb").read()
assert hashlib.sha256(raw).hexdigest()=="98c7031e28f134e3f1f2ddee788788f4b8855d4f38f178777bbc5e24721dd63b"
open(sys.argv[2],"wb").write(raw)
PY

COMMON=(-std=f2008 -pedantic-errors -ffree-line-length-none -Wall -Wextra -Werror -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
for opt in 0 2; do
  OUT="$BUILD/o$opt"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$SRC" -o "$OUT/process.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$TEST" -o "$OUT/test.o"
  gfortran -O"$opt" "$OUT/process.o" "$OUT/test.o" -o "$OUT/test"
  "$OUT/test" > "$OUT/process-output.txt" 2>&1 || { cat "$OUT/process-output.txt" >&2; fail "process runtime O$opt"; }
  for m in F_VQ124_B110_EQUATION_ORACLE=PASS F_VQ124_TCSFIX_CADENCE=PASS F_VQ124_SPLIT_ROLLBACK_REPLAY=PASS F_VQ124_A_B_A=PASS F_VQ124_FAIL_CLOSED=PASS; do
    grep -Fq "$m" "$OUT/process-output.txt" || fail "missing process O$opt marker $m"
  done

  COMP=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
  sources=(
    src/solver/mod_soil_water_solver_contract.f90
    src/solver/mod_process_hydraulic_view.f90
    src/process/mod_irrigation_process.f90
    "$SRC"
    src/process/mod_rutter_interception_process.f90
    src/process/mod_restricted_surface_evaporation.f90
    src/solver/mod_b110_default_mvg_provider.f90
    src/solver/mod_b110_dynamic_top_boundary_provider.f90
    "$BIND"
  )
  objects=()
  for source in "${sources[@]}"; do
    obj="$OUT/$(basename "${source%.*}").o"
    extra=()
    [[ "$source" == "$SRC" || "$source" == "$BIND" ]] && extra=(-Werror -pedantic-errors)
    [[ "$source" == "src/solver/mod_soil_water_solver_contract.f90" ]] && extra=(-Wno-error=unused-dummy-argument)
    [[ "$source" == "src/solver/mod_b110_dynamic_top_boundary_provider.f90" ]] && extra=(-Wno-error=compare-reals)
    gfortran "${COMP[@]}" "${extra[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$source" -o "$obj" || fail "composition compile O$opt $source"
    objects+=("$obj")
  done
  gfortran "${COMP[@]}" -Wno-error=compare-reals -O"$opt" -J "$OUT" -I "$OUT" -c "$COMP_TEST" -o "$OUT/comp-test.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/comp-test.o" -o "$OUT/comp-test"
  "$OUT/comp-test" "$BUILD/irrigation.csv" > "$OUT/composition-output.txt" 2>&1 || { cat "$OUT/composition-output.txt" >&2; fail "composition runtime O$opt"; }
  grep -Fq 'F_VQ124_COMPOSITION_RECORDS=110' "$OUT/composition-output.txt" || fail "composition count O$opt"
  grep -Fq 'F_VQ124_COMPOSITION_SWINTER0=18' "$OUT/composition-output.txt" || fail "SWINTER0 count O$opt"
  grep -Fq 'F_VQ124_COMPOSITION_SWINTER3=92' "$OUT/composition-output.txt" || fail "SWINTER3 count O$opt"
  grep -Fq 'F_VQ124_EXACT_110_BINDING_COMPOSITION=PASS' "$OUT/composition-output.txt" || fail "composition marker O$opt"
done

cmp -s "$BUILD/o0/process-output.txt" "$BUILD/o2/process-output.txt" || { diff -u "$BUILD/o0/process-output.txt" "$BUILD/o2/process-output.txt" >&2 || true; fail "process O0/O2 drift"; }
cmp -s "$BUILD/o0/composition-output.txt" "$BUILD/o2/composition-output.txt" || { diff -u "$BUILD/o0/composition-output.txt" "$BUILD/o2/composition-output.txt" >&2 || true; fail "composition O0/O2 drift"; }
cat "$BUILD/o0/process-output.txt"
cat "$BUILD/o0/composition-output.txt"
echo "F_VQ124_PROCESS_SHA256=$(sha256sum "$BUILD/o0/process-output.txt" | awk '{print $1}')"
echo "F_VQ124_COMPOSITION_SHA256=$(sha256sum "$BUILD/o0/composition-output.txt" | awk '{print $1}')"
echo 'F_VQ124_FAPP07_INDEPENDENT=PASS'
