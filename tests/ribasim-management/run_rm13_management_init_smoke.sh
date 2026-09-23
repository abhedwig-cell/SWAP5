#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-rm13-init-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "RM13_INIT_FAIL $*" >&2; exit 1; }

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -Wno-error=compare-reals -Wno-error=function-elimination -fcheck=all -fbacktrace)
SOURCES=(
  src/solver/mod_soil_water_accepted_step_direction_contract.f90
  src/transaction/mod_accepted_trajectory_directional_sensitivity.f90
  src/transaction/mod_accepted_trajectory_directional_publication.f90
  src/transaction/mod_transaction_reference.f90
  src/runtime/mod_canonical_contracts.f90
  src/runtime/mod_canonical_interval_runtime.f90
  src/kernel/mod_kernel_transactions.f90
  src/process/mod_tcs1_dcs2_sprinkling_irrigation_process.f90
  src/process/mod_rutter_interception_process.f90
  src/runtime/mod_fmr_hupsel_management_transaction.f90
  src/runtime/mod_fmr_ribasim_management_binding.f90
  tests/ribasim-management/support/mod_rm13_management_c_bridge.f90
)
objects=()
for source in "${SOURCES[@]}"; do
  obj="$BUILD/$(basename "${source%.*}").o"
  gfortran "${COMMON[@]}" -O0 -J "$BUILD" -I "$BUILD" -c "$source" -o "$obj" || fail "compile $source"
  objects+=("$obj")
done
gfortran "${COMMON[@]}" -O0 -J "$BUILD" -I "$BUILD" -c   tests/ribasim-management/test_rm13_management_init_smoke.f90 -o "$BUILD/test.o" || fail "compile smoke"
gfortran -O0 "${objects[@]}" "$BUILD/test.o" -o "$BUILD/test" || fail "link smoke"
"$BUILD/test" | tee "$BUILD/output.txt"
grep -Fq 'RM13_MANAGEMENT_INIT_SMOKE=PASS' "$BUILD/output.txt" || fail "missing smoke marker"
