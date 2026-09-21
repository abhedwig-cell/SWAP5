#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-low01b-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

fail(){ echo "GC_LOW01B_RUNNER_FAIL $*" >&2; exit 1; }

# Dependency gates are executable prerequisites, not documentary assumptions.
bash tests/research/run_gc_low01_constitutive_bridge.sh | tee "$BUILD/constitutive.txt"
grep -Fq 'GC_LOW01_CONSTITUTIVE_BRIDGE_QUALIFICATION=PASS' "$BUILD/constitutive.txt" || fail 'constitutive prerequisite'

bash tests/research/run_gc_low01a2.sh | tee "$BUILD/low01a2.txt"
grep -Fq 'GC_LOW01A2_QUALIFICATION=PASS' "$BUILD/low01a2.txt" || fail 'LOW01-A2 prerequisite'

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -Werror -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
SRC=(
  tests/research/support/gc_low01_headcalc_nonconstitutive_stubs.f90
  src/solver/mod_soil_water_accepted_step_direction_contract.f90
  src/transaction/mod_accepted_trajectory_directional_sensitivity.f90
  src/runtime/mod_a23bu_worker_execution_context.f90
  src/solver/mod_soil_water_solver_contract.f90
  src/solver/mod_reference_richards_workspace.f90
  src/solver/mod_reference_richards_state_binding.f90
  src/solver/mod_reference_linear_solver.f90
  src/solver/mod_b110_default_mvg_provider.f90
  tests/research/support/mod_gc_low01_constitutive_bridge.f90
  src/solver/mod_b110_source_sink_provider.f90
  src/solver/mod_fixed_flux_top_boundary_provider.f90
  src/solver/mod_reference_richards_temporal_indicator.f90
  src/legacy/b1_10_port/headcalc.f90
  tests/research/test_gc_low01b_inside_profile.f90
)

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  mkdir -p "$OUT"
  objects=()
  for source in "${SRC[@]}"; do
    obj="$OUT/$(basename "${source%.*}").o"
    gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$source" -o "$obj" || fail "compile O$opt $source"
    objects+=("$obj")
  done
  gfortran -O"$opt" "${objects[@]}" -o "$OUT/low01b" || fail "link O$opt"
  "$OUT/low01b" > "$OUT/output.txt" 2>&1 || {
    cat "$OUT/output.txt" >&2
    fail "LOW01-B runtime O$opt"
  }
  for marker in \
    'GC_LOW01B_SINGLE_CONSTITUTIVE_OWNER=PASS' \
    'GC_LOW01B_IMMUTABLE_ORIGIN=PASS' \
    'GC_LOW01B_COMPLETE_TRIAL_CARRIER=PASS' \
    'GC_LOW01B_IMMUTABLE_ORIGIN=PASS' \
    'GC_LOW01B_INSIDE_PROFILE_CASES=PASS' \
    'GC_LOW01B_SATURATED_CONTINUATION=PASS' \
    'GC_LOW01B_QBOT_DIAGNOSED=PASS' \
    'GC_LOW01B_MASS_CLOSURE=PASS' \
    'GC_LOW01B_BITWISE_REPLAY=PASS' \
    'GC_LOW01B_LIVE_GATE=PASS'; do
    grep -Fq "$marker" "$OUT/output.txt" || {
      cat "$OUT/output.txt" >&2
      fail "missing O$opt marker $marker"
    }
  done
  cat "$OUT/output.txt"
  echo "GC_LOW01B_O${opt}=PASS"
done

cmp -s "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" || {
  diff -u "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" >&2 || true
  fail 'LOW01-B O0/O2 semantic drift'
}
echo 'GC_LOW01B_O0_O2_IDENTITY=PASS'

git diff --check -- \
  integration/research/GC_LOW01B_PREREGISTRATION.json \
  integration/research/GC_LOW01B_PREREGISTRATION_AMENDMENT.json \
  integration/research/GC_LOW01B_PREREGISTRATION_AMENDMENT_V2.json \
  integration/research/GC_LOW01B_CONSTITUTIVE_OWNERSHIP_AUDIT.json \
  tests/research/support/gc_low01_headcalc_nonconstitutive_stubs.f90 \
  tests/research/support/mod_gc_low01_constitutive_bridge.f90 \
  tests/research/test_gc_low01b_inside_profile.f90 \
  tests/research/run_gc_low01b.sh

echo 'GC_LOW01B_QUALIFICATION=PASS'
