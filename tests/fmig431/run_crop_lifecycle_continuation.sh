#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="$(mktemp -d)"
trap 'rm -rf "$BUILD"' EXIT
for OPT in 0 2; do
  mkdir -p "$BUILD/o$OPT"
  gfortran -O"$OPT" -std=f2008 -ffree-line-length-none -Wall -Wextra -Werror -fcheck=all \
    -J"$BUILD/o$OPT" -I"$BUILD/o$OPT" \
    "$ROOT/src/transaction/mod_transaction_reference.f90" \
    "$ROOT/src/runtime/mod_canonical_contracts.f90" \
    "$ROOT/src/runtime/mod_canonical_interval_runtime.f90" \
    "$ROOT/src/kernel/mod_kernel_transactions.f90" \
    "$ROOT/src/crop/mod_wofost_actual_biomass_state.f90" \
    "$ROOT/src/crop/mod_wofost_crop_owner_state.f90" \
    "$ROOT/src/crop/mod_wofost_one_day_structural_evolution.f90" \
    "$ROOT/src/runtime/mod_fmr_wofost_accepted_window_lineage.f90" \
    "$ROOT/src/crop/mod_crop_preparation_sowing_preflight.f90" \
    "$ROOT/src/crop/mod_crop_germination_preflight.f90" \
    "$ROOT/src/crop/mod_crop_lifecycle_daily_composition.f90" \
    "$ROOT/src/crop/mod_crop_lifecycle_continuation.f90" \
    "$ROOT/tests/fmig431/test_crop_lifecycle_continuation.f90" \
    -o "$BUILD/o$OPT/test"
  "$BUILD/o$OPT/test" > "$BUILD/o$OPT/output"
  grep -Fx 'SW431_CROP_LIFECYCLE_CONTINUATION=PASS' "$BUILD/o$OPT/output"
done
cmp "$BUILD/o0/output" "$BUILD/o2/output"
echo 'SW431_CROP_LIFECYCLE_CONTINUATION_O0_O2=PASS'
