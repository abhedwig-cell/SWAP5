#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
FSI18_CLOSEOUT='8c5438a73e8ae4c9fcbd9de9fdd82d9a600626b2'
BUILD="${TMPDIR:-/tmp}/swap5-fsi19-headcalc-$$"
mkdir -p "$BUILD"
trap 'git -C "$ROOT" worktree remove --force "$BUILD/fsi18" >/dev/null 2>&1 || true; rm -rf "$BUILD"' EXIT
cd "$ROOT"

[[ "$(git rev-parse HEAD:src/solver/mod_reference_linear_solver.f90)" == 'b292d284e5549049eac1c80df4cc30008154eb96' ]] || {
  echo 'FSI19_LINEAR_SOLVER_SOURCE_LOCK=FAIL' >&2; exit 1; }
[[ "$(git rev-parse HEAD:tests/fsi/fsi04_real_headcalc_stubs.f90)" == '23c00e4a188e88bc36ef95cbe4faaacdd6aad639' ]] || {
  echo 'FSI19_SUPPORT_FIXTURE_SOURCE_LOCK=FAIL' >&2; exit 1; }

echo 'FSI19_REFERENCE_CONTROL_BEGIN'
git worktree add --detach "$BUILD/fsi18" "$FSI18_CLOSEOUT" >/dev/null
(
  cd "$BUILD/fsi18"
  FSI18_TRIDAG_EVIDENCE_DIR="$BUILD/fsi18-evidence" \
    bash tests/fsi/run_fsi18_reference_tridag_control_gate.sh > "$BUILD/fsi18-control.log"
)
grep -Fq 'FSI18_REFERENCE_TRIDAG_CONTROL_GATE=PASS_DIAGNOSTIC_ONLY' "$BUILD/fsi18-control.log"
grep -Fq 'FSI18_REFERENCE_TRIDAG_ALL_NONZERO_CONVERGED=YES' "$BUILD/fsi18-control.log"
echo 'FSI19_REFERENCE_CONTROL=PASS_FSI18_CLOSEOUT'

python3 tests/fsi/fsi19_make_solverless_headcalc_stubs.py \
  tests/fsi/fsi04_real_headcalc_stubs.f90 "$BUILD/current-stubs.f90" > "$BUILD/stub-filter.log"
grep -Fq 'FSI19_SOLVERLESS_SUPPORT_FIXTURE=PASS' "$BUILD/stub-filter.log"

# Match the F-SI18 reference-control warning policy for production/support
# sources. Known legacy HeadCalc warnings are evidence, not F-SI19 failures.
# Keep -Werror on the F-SI19/F-SI18 test program itself.
COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
REST=(
  src/runtime/mod_a23bu_worker_execution_context.f90
  src/solver/mod_soil_water_solver_contract.f90
  src/solver/mod_reference_linear_solver.f90
  src/solver/mod_reference_richards_workspace.f90
  src/solver/mod_reference_richards_state_binding.f90
  tests/fsi/mod_fsi07_top_provider.f90
  src/solver/mod_b110_default_mvg_provider.f90
  src/solver/mod_b110_source_sink_provider.f90
  src/solver/mod_b110_root_sink_provider.f90
  src/legacy/b1_10_port/headcalc.f90
  src/adapter/mod_reference_richards_legacy_binding.f90
)

for opt in 0 2; do
  OUT="$BUILD/current-o$opt"
  mkdir -p "$OUT"
  objects=()
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" \
    -c "$BUILD/current-stubs.f90" -o "$OUT/current-stubs.o"
  objects+=("$OUT/current-stubs.o")
  for src in "${REST[@]}"; do
    obj="$OUT/$(basename "${src%.*}").o"
    gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$src" -o "$obj"
    objects+=("$obj")
  done
  gfortran "${COMMON[@]}" -Werror -O"$opt" -J "$OUT" -I "$OUT" \
    -c tests/fsi/test_fsi18_reference_convergence_cliff.F90 -o "$OUT/test.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/test.o" -o "$OUT/test"
  "$OUT/test" > "$OUT/run-a.txt" 2>&1
  "$OUT/test" > "$OUT/run-b.txt" 2>&1
  cmp "$OUT/run-a.txt" "$OUT/run-b.txt"
  grep -Fq 'FSI18_REFERENCE_CONVERGENCE_CLIFF_PROBE PASS' "$OUT/run-a.txt"
  for i in 1 2 3 4 5; do
    grep -Fq "FSI18_CASE_${i}_CONVERGED=T" "$OUT/run-a.txt"
  done
  cmp "$OUT/run-a.txt" "$BUILD/fsi18-evidence/reference-tridag-o${opt}.txt"
  echo "FSI19_HEADCALC_O${opt}=PASS_BITWISE_FSI18_REFERENCE_CONTROL"
done

cmp "$BUILD/current-o0/run-a.txt" "$BUILD/current-o2/run-a.txt"
echo 'FSI19_HEADCALC_O0_O2_IDENTITY=PASS'
cat "$BUILD/current-o0/run-a.txt"
echo 'FSI19_HEADCALC_PRODUCTION_GATE=PASS_BITWISE_REFERENCE_CONTROL'
