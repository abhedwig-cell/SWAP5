#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fwof26-fwof24-$$"
mkdir -p "$BUILD/o0" "$BUILD/o2"
trap 'rm -rf "$BUILD"' EXIT

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -Werror -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
TX="$ROOT/src/transaction/mod_transaction_reference.f90"
CONTRACTS="$ROOT/src/runtime/mod_canonical_contracts.f90"
RUNTIME="$ROOT/src/runtime/mod_canonical_interval_runtime.f90"
KERNEL="$ROOT/src/kernel/mod_kernel_transactions.f90"
ROOT_CONTRACT="$ROOT/src/crop/mod_crop_root_uptake_input_contract.f90"
ROOT_ASSEMBLY="$ROOT/src/crop/mod_crop_root_uptake_input_assembly.f90"
NONADAPT="$ROOT/src/crop/mod_nonadaptive_crop_root_view_producer.f90"
GEOMETRY="$ROOT/src/crop/mod_crop_root_geometry_snapshot_producer.f90"
BIOMASS="$ROOT/src/crop/mod_wofost_actual_biomass_state.f90"
OWNER="$ROOT/src/crop/mod_wofost_crop_owner_state.f90"
TEST="$ROOT/tests/fwof/test_fwof24_crop_owner_composite_state.f90"

for OPT in o0 o2; do
  FLAG=-O0
  [[ "$OPT" == "o2" ]] && FLAG=-O2
  gfortran "${COMMON[@]}" "$FLAG" -J "$BUILD/$OPT" \
    "$TX" "$CONTRACTS" "$RUNTIME" "$KERNEL" \
    "$ROOT_CONTRACT" "$ROOT_ASSEMBLY" "$NONADAPT" "$GEOMETRY" \
    "$BIOMASS" "$OWNER" "$TEST" -o "$BUILD/$OPT/test"
  "$BUILD/$OPT/test" > "$BUILD/$OPT/output.txt" 2>&1 || { cat "$BUILD/$OPT/output.txt" >&2; exit 1; }
  grep -Fq 'FWOF24_CROP_OWNER_COMPOSITE_STATE_TEST PASS' "$BUILD/$OPT/output.txt"
  echo "FWOF26_FWO24_BACKWARD_COMPAT_${OPT^^}=PASS"
done

cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
echo 'FWOF26_FWO24_BACKWARD_COMPAT_O0_O2_IDENTITY=PASS'
echo 'FWOF26_FWO24_VIEW_ONLY_OWNER_BEHAVIOR_RETAINED=PASS'
