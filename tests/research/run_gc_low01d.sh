#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-low01d-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"
fail(){ echo "GC_LOW01D_RUNNER_FAIL $*" >&2; exit 1; }

test -f integration/research/GC_LOW01A2_RESULT.json || fail 'LOW01-A2 authority missing'

# Preserve the live below-profile substrate in the same execution.
bash tests/research/run_gc_low01a2.sh | tee "$BUILD/a2.txt"
grep -Fq 'GC_LOW01A2_QUALIFICATION=PASS' "$BUILD/a2.txt" || fail 'LOW01-A2 preservation'

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -Werror -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
SRC=(
  tests/fsi/fsi04_real_headcalc_stubs.f90
  src/solver/mod_soil_water_accepted_step_direction_contract.f90
  src/transaction/mod_accepted_trajectory_directional_sensitivity.f90
  src/runtime/mod_a23bu_worker_execution_context.f90
  src/solver/mod_soil_water_solver_contract.f90
  src/solver/mod_reference_richards_workspace.f90
  src/solver/mod_reference_richards_state_binding.f90
  src/solver/mod_reference_linear_solver.f90
  src/solver/mod_b110_default_mvg_provider.f90
  src/solver/mod_b110_source_sink_provider.f90
  src/solver/mod_fixed_flux_top_boundary_provider.f90
  src/solver/mod_reference_richards_temporal_indicator.f90
  src/legacy/b1_10_port/headcalc.f90
  src/adapter/mod_reference_richards_legacy_binding.f90
  tests/research/test_gc_low01d_replay_isolation.f90
)

for opt in 0 2; do
  OUT="$BUILD/o$opt"; mkdir -p "$OUT"; objects=()
  for source in "${SRC[@]}"; do
    obj="$OUT/$(basename "${source%.*}").o"
    gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$source" -o "$obj" || fail "compile O$opt $source"
    objects+=("$obj")
  done
  gfortran -O"$opt" "${objects[@]}" -o "$OUT/low01d" || fail "link O$opt"
  "$OUT/low01d" > "$OUT/output.txt" 2>&1 || { cat "$OUT/output.txt" >&2; fail "runtime O$opt"; }
  grep -Fq 'GC_LOW01D_GATE=PASS' "$OUT/output.txt" || fail "missing D gate O$opt"
  cat "$OUT/output.txt"
  echo "GC_LOW01D_O${opt}=PASS"
done

cmp -s "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" || {
  diff -u "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" >&2 || true
  fail 'LOW01-D O0/O2 drift'
}
echo 'GC_LOW01D_O0_O2_IDENTITY=PASS'

git diff --check -- \
  integration/research/GC_LOW01D_PREREGISTRATION.json \
  integration/research/GC_LOW01A2_RESULT.json \
  tests/research/test_gc_low01d_replay_isolation.f90 \
  tests/research/run_gc_low01d.sh
echo 'GC_LOW01D_QUALIFICATION=PASS'
