#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-low01d-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

fail(){ echo "GC_LOW01D_RUNNER_FAIL $*" >&2; exit 1; }

bash tests/research/run_gc_low01a2.sh | tee "$BUILD/low01a2-prerequisite.txt"
grep -Fq 'GC_LOW01A2_QUALIFICATION=PASS' "$BUILD/low01a2-prerequisite.txt" || fail 'LOW01-A2 prerequisite'

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -Werror -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
MODULE_SRC=(
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
  tests/research/support/mod_gc_low01_trial_transaction.f90
)

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  mkdir -p "$OUT"
  objects=()
  for source in "${MODULE_SRC[@]}"; do
    obj="$OUT/$(basename "${source%.*}").o"
    gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$source" -o "$obj"
    objects+=("$obj")
  done

  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" \
    -c tests/research/test_gc_low01d_below_profile_transaction.f90 -o "$OUT/low01d.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/low01d.o" -o "$OUT/low01d"

  "$OUT/low01d" > "$OUT/low01d.txt" 2>&1 || {
    cat "$OUT/low01d.txt" >&2
    fail "LOW01-D executable O$opt"
  }

  for marker in \
    'GC_LOW01D_REJECTED_TRIAL_ISOLATION=PASS' \
    'GC_LOW01D_A_B_A_REPLAY=PASS' \
    'GC_LOW01D_SINGLE_PUBLICATION=PASS' \
    'GC_LOW01D_TYPED_CANDIDATE_CONTRACT=PASS' \
    'GC_LOW01D_LIVE_GATE=PASS'; do
    grep -Fq "$marker" "$OUT/low01d.txt" || {
      cat "$OUT/low01d.txt" >&2
      fail "missing $marker O$opt"
    }
  done
  cat "$OUT/low01d.txt"
  echo "GC_LOW01D_O${opt}=PASS"
done

cmp -s "$BUILD/o0/low01d.txt" "$BUILD/o2/low01d.txt" || {
  diff -u "$BUILD/o0/low01d.txt" "$BUILD/o2/low01d.txt" >&2 || true
  fail 'LOW01-D O0/O2 semantic drift'
}
echo 'GC_LOW01D_O0_O2_IDENTITY=PASS'

git diff --check -- \
  integration/research/GC_LOW01D_PREREGISTRATION.json \
  integration/research/GC_LOW01_RESULT_CONTRACT_V1.json \
  tests/research/support/mod_gc_low01_trial_transaction.f90 \
  tests/research/test_gc_low01d_below_profile_transaction.f90 \
  tests/research/run_gc_low01d.sh

echo 'GC_LOW01D_QUALIFICATION=PASS'
