#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fwof42-layouts-$$"
mkdir -p "$BUILD/o0" "$BUILD/o2"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

# Freeze the current owner-state surface and the F-WOF41 production API blobs.
check_blob() {
  local path="$1" expected="$2" label="$3"
  local actual
  actual="$(git hash-object "$path")"
  if [[ "$actual" != "$expected" ]]; then
    echo "F-WOF42 source drift $label: expected $expected got $actual" >&2
    exit 1
  fi
}
check_blob src/crop/mod_wofost_crop_owner_state.f90 31bb390a0b70bec0a3f525f1d704a2c53890f9b4 crop_owner
check_blob src/crop/mod_wofost_actual_biomass_state.f90 feab0672b38e1c9668ac418cbe9d800f032cf4d8 biomass
check_blob src/runtime/mod_fmr_wofost_accepted_window_lineage.f90 61ffdf21a00c23924184c9117d91d84a88544d1a lineage_persistence
check_blob src/runtime/mod_fmr_wofost_crop_transaction.f90 dad15717e5794b7489c9fecf6dbc17e12435c61e crop_persistence

# Preserve the complete production owner API qualification first.
bash tests/fwof/run_fwof41_production_owner_persistence_gate.sh

# Only the qualification codec needs the ordered-validation temporary copy.
python3 tools/fwof40_order_external_adapter_validation.py \
  tests/fwof/mod_fwof40_external_crop_restart_adapter.f90 \
  "$BUILD/mod_fwof40_external_crop_restart_adapter.f90" > "$BUILD/adapter_ordering.txt"
grep -Fq 'FWOF40_EXTERNAL_ADAPTER_ORDERED_VALIDATION_MATERIALIZED=PASS' "$BUILD/adapter_ordering.txt"

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -Werror -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
SOURCES=(
  src/transaction/mod_transaction_reference.f90
  src/runtime/mod_canonical_contracts.f90
  src/runtime/mod_canonical_interval_runtime.f90
  src/kernel/mod_kernel_transactions.f90
  src/kernel/mod_kernel_committed_persistence.f90
  src/crop/mod_wofost_actual_biomass_state.f90
  src/crop/mod_wofost_crop_owner_state.f90
  src/crop/mod_wofost_one_day_structural_evolution.f90
  src/crop/mod_wofost_one_day_rate_state_view.f90
  src/crop/mod_wofost_rate_table.f90
  src/crop/mod_wofost_rate_parameters.f90
  src/crop/mod_wofost_prepare_assimilation.f90
  src/crop/mod_wofost_finalize_rates.f90
  src/crop/mod_wofost_two_phase_crop_window.f90
  src/runtime/mod_fmr_wofost_accepted_window_lineage.f90
  src/runtime/mod_fmr_wofost_crop_transaction.f90
  src/runtime/mod_fmr_wofost_crop_event_lifecycle.f90
)

for OPT in 0 2; do
  OUT="$BUILD/o$OPT"
  pushd "$OUT" >/dev/null
  for src in "${SOURCES[@]}"; do
    gfortran "${COMMON[@]}" -O"$OPT" -J . -I . -c "$ROOT/$src"
  done
  gfortran "${COMMON[@]}" -O"$OPT" -J . -I . -c "$BUILD/mod_fwof40_external_crop_restart_adapter.f90"
  OBJECTS=(./*.o)
  gfortran "${COMMON[@]}" -O"$OPT" -J . -I . \
    "$ROOT/tests/fwof/test_fwof42_crop_persistence_layouts.f90" "${OBJECTS[@]}" -o test_layouts

  ./test_layouts direct > direct.log 2>&1
  ./test_layouts invalid > invalid.log 2>&1
  ./test_layouts zero_behavior > zero_behavior.log 2>&1
  grep -Fq 'FWOF42_DIRECT_PRODUCTION_PERSISTENCE_ALL_LAYOUTS=PASS' direct.log
  grep -Fq 'FWOF42_INVALID_LAYOUTS_FAIL_CLOSED=PASS' invalid.log
  grep -Fq 'FWOF42_ZERO_LENGTH_COHORT_CANONICALIZATION_BEHAVIOR_EQUIVALENT=PASS' zero_behavior.log

  : > process.log
  for layout in 1 2 3 4 5 6 7; do
    ./test_layouts produce "$layout" "layout_${layout}.artifact" >> process.log 2>&1
    ./test_layouts consume "$layout" "layout_${layout}.artifact" "layout_${layout}_roundtrip.artifact" >> process.log 2>&1
    cmp "layout_${layout}.artifact" "layout_${layout}_roundtrip.artifact"
    grep -Fq "FWOF42_PRODUCER_LAYOUT_${layout}=PASS" process.log
    grep -Fq "FWOF42_CONSUMER_LAYOUT_${layout}=PASS" process.log
  done

  # Layout-specific minimality and presence checks in the qualification codec.
  grep -Fq 'biomass_present 0' layout_1.artifact
  grep -Fq 'leaf_count 0' layout_1.artifact
  grep -Fq 'evolution_present 0' layout_1.artifact
  grep -Fq 'b110_compatibility_present 0' layout_1.artifact
  ! grep -Fq 'root_biomass_bits' layout_1.artifact
  ! grep -Fq 'temperature_sum_bits' layout_1.artifact
  ! grep -Fq 'lai_exponential_rate_carryover_bits' layout_1.artifact

  grep -Fq 'biomass_present 1' layout_2.artifact
  grep -Fq 'leaf_count 0' layout_2.artifact
  grep -Fq 'evolution_present 0' layout_2.artifact
  grep -Fq 'b110_compatibility_present 0' layout_2.artifact
  ! grep -Fq 'leaf_biomass_bits_1' layout_2.artifact

  grep -Fq 'leaf_count 2' layout_3.artifact
  grep -Fq 'evolution_present 0' layout_3.artifact
  grep -Fq 'b110_compatibility_present 0' layout_3.artifact

  grep -Fq 'leaf_count 2' layout_4.artifact
  grep -Fq 'evolution_present 1' layout_4.artifact
  grep -Fq 'b110_compatibility_present 0' layout_4.artifact

  grep -Fq 'leaf_count 0' layout_5.artifact
  grep -Fq 'evolution_present 0' layout_5.artifact
  grep -Fq 'b110_compatibility_present 1' layout_5.artifact

  grep -Fq 'leaf_count 2' layout_6.artifact
  grep -Fq 'evolution_present 1' layout_6.artifact
  grep -Fq 'b110_compatibility_present 1' layout_6.artifact

  grep -Fq 'leaf_count 0' layout_7.artifact
  grep -Fq 'evolution_present 1' layout_7.artifact
  grep -Fq 'b110_compatibility_present 0' layout_7.artifact
  ! grep -Fq 'leaf_biomass_bits_1' layout_7.artifact

  if grep -Eqi 'accepted_window|event_delivered|delivery_committed|solver|scratch|forcing|parameter' layout_6.artifact; then
    echo 'F-WOF42 non-state payload leaked into maximal optional layout artifact' >&2
    cat layout_6.artifact >&2
    exit 1
  fi

  echo "FWOF42_OPTIONAL_LAYOUT_MATRIX_O${OPT}=PASS"
  popd >/dev/null
done

for layout in 1 2 3 4 5 6 7; do
  cmp "$BUILD/o0/layout_${layout}.artifact" "$BUILD/o2/layout_${layout}.artifact"
  cmp "$BUILD/o0/layout_${layout}_roundtrip.artifact" "$BUILD/o2/layout_${layout}_roundtrip.artifact"
done
cmp "$BUILD/o0/direct.log" "$BUILD/o2/direct.log"
cmp "$BUILD/o0/invalid.log" "$BUILD/o2/invalid.log"
cmp "$BUILD/o0/zero_behavior.log" "$BUILD/o2/zero_behavior.log"
cmp "$BUILD/o0/process.log" "$BUILD/o2/process.log"

cat "$BUILD/o0/direct.log"
cat "$BUILD/o0/invalid.log"
cat "$BUILD/o0/zero_behavior.log"
cat "$BUILD/o0/process.log"
echo 'FWOF42_SIX_CURRENT_VALID_OWNER_LAYOUTS_PLUS_ZERO_EDGE=PASS'
echo 'FWOF42_SIX_INVALID_OWNER_LAYOUTS_FAIL_CLOSED=PASS'
echo 'FWOF42_INACTIVE_OPTIONAL_STATE_MINIMALITY=PASS'
echo 'FWOF42_ABSENT_EVOLUTION_AND_B110_PAYLOAD_BODIES=PASS'
echo 'FWOF42_ZERO_LENGTH_COHORT_EXTERNAL_CANONICALIZATION=QUALIFIED_SEMANTIC_EQUIVALENCE'
echo 'FWOF42_EXTERNAL_REPRESENTATION_O0_O2_IDENTITY=PASS'
echo 'FWOF42_CROP_PERSISTENCE_LAYOUT_COMPLETENESS_GATE PASS'
