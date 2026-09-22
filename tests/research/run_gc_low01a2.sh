#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-low01a2-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

fail(){ echo "GC_LOW01A2_RUNNER_FAIL $*" >&2; exit 1; }

bash tests/research/run_gc_low01a.sh | tee "$BUILD/low01a-prerequisite.txt"
grep -Fq 'GC_LOW01A_QUALIFICATION=PASS' "$BUILD/low01a-prerequisite.txt" || fail 'LOW01-A prerequisite'

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
OWNED=("${COMMON[@]}" -Werror)
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

  gfortran "${OWNED[@]}" -O"$opt" -J "$OUT" -I "$OUT"     -c tests/research/test_gc_low01a2_live_below_profile.f90 -o "$OUT/low01a2.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/low01a2.o" -o "$OUT/low01a2"

  "$OUT/low01a2" > "$OUT/low01a2.txt" 2>&1 || {
    cat "$OUT/low01a2.txt" >&2
    fail "LOW01-A2 executable O$opt"
  }

  for marker in     'GC_LOW01A2_LIVE_MODE5_REDUCTION=PASS'     'GC_LOW01A2_INDEPENDENT_MASS_LEDGER=PASS'     'GC_LOW01A2_IMMUTABLE_ORIGIN_REPLAY=PASS'     'GC_LOW01A2_NONVACUOUS_PERTURBATION=PASS'     'GC_LOW01A2_LIVE_GATE=PASS'; do
    grep -Fq "$marker" "$OUT/low01a2.txt" || {
      cat "$OUT/low01a2.txt" >&2
      fail "missing $marker O$opt"
    }
  done
  cat "$OUT/low01a2.txt"
  echo "GC_LOW01A2_O${opt}=PASS"
done

cmp -s "$BUILD/o0/low01a2.txt" "$BUILD/o2/low01a2.txt" || {
  diff -u "$BUILD/o0/low01a2.txt" "$BUILD/o2/low01a2.txt" >&2 || true
  fail 'LOW01-A2 O0/O2 semantic drift'
}
echo 'GC_LOW01A2_O0_O2_IDENTITY=PASS'

git diff --check --   integration/research/GC_LOW01A2_PREREGISTRATION.json   integration/research/GC_LOW01B_STATUS.json   tests/research/test_gc_low01a2_live_below_profile.f90   tests/research/run_gc_low01a2.sh

echo 'GC_LOW01A2_QUALIFICATION=PASS'
