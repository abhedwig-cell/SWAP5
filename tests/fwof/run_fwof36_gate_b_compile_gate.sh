#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fwof36-gate-b-compile-$$"
FMR18_CLOSEOUT="ebf051bbf7e57f77d115287a9ba02fc987a255bc"
FCI19_PRESERVATION_HEAD="5d5ece58b2b8e053a270992ded52377dd524f9c4"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

fail() {
  echo "FWOF36_GATE_B_COMPILE_FAIL $*" >&2
  exit 1
}

cat > "$BUILD/expected-source-delta.txt" <<'EOF'
src/runtime/mod_fmr_wofost_accepted_window_lineage.f90
src/runtime/mod_fmr_wofost_physical_trial_binding.f90
EOF
git diff --name-only "$FMR18_CLOSEOUT"..HEAD -- src | sort > "$BUILD/actual-source-delta.txt"
diff -u "$BUILD/expected-source-delta.txt" "$BUILD/actual-source-delta.txt" || fail "unexpected Gate B production source delta"
echo 'FWOF36_GATE_B_EXACT_TWO_FILE_SOURCE_DELTA=PASS'

python3 - <<'PY'
from pathlib import Path
lineage = Path('src/runtime/mod_fmr_wofost_accepted_window_lineage.f90').read_text(encoding='utf-8').lower()
binding = Path('src/runtime/mod_fmr_wofost_physical_trial_binding.f90').read_text(encoding='utf-8').lower()
assert 'prevalidate_wofost_trial_admission' in lineage
assert 'fmr_run_serialized_multiswap_with_wofost_integrals' in binding
assert 'fmr_run_serialized_physical_multiswap' in binding
assert 'receipt_column_ids=wofost_column_ids' in binding
assert 'commit_receipts=receipts' in binding
assert 'sum(forcing_registry(fidx)%root_extraction_sink)' in binding
assert 'candidate' not in binding, 'Gate B must not recompute root uptake from candidate post-state'
for forbidden in ['use variables', 'use mod_grid', 'use mod_snow', 'call headcalc(']:
    assert forbidden not in binding, f'legacy/domain boundary leak in Gate B wrapper: {forbidden}'
print('FWOF36_GATE_B_PRECOMMIT_HELPER_PRESENT=PASS')
print('FWOF36_GATE_B_EXACT_APPLIED_ROOT_SINK_SUM_PRESENT=PASS')
print('FWOF36_GATE_B_NO_CANDIDATE_ROOT_UPTAKE_RECOMPUTATION=PASS')
print('FWOF36_GATE_B_NO_LEGACY_GLOBAL_IMPORTS=PASS')
PY

git show "$FCI19_PRESERVATION_HEAD:tests/fsi/fsi04_real_headcalc_stubs.f90" > "$BUILD/fsi04_real_headcalc_stubs.f90"

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
STRICT=(-std=f2008 -ffree-line-length-none -Wall -Wextra -Werror -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
MODULE_SRC=(
  "$BUILD/fsi04_real_headcalc_stubs.f90"
  src/runtime/mod_a23bu_worker_execution_context.f90
  src/transaction/mod_transaction_reference.f90
  src/runtime/mod_canonical_contracts.f90
  src/runtime/mod_canonical_interval_runtime.f90
  src/kernel/mod_kernel_transactions.f90
  src/runtime/mod_fmr_runtime_core.f90
  src/runtime/mod_fmr_checkpoint_orchestrator.f90
  src/solver/mod_soil_water_solver_contract.f90
  src/solver/mod_reference_richards_workspace.f90
  src/solver/mod_reference_richards_state_binding.f90
  src/solver/mod_reference_linear_solver.f90
  src/solver/mod_b110_default_mvg_provider.f90
  src/solver/mod_b110_source_sink_provider.f90
  src/legacy/b1_10_port/headcalc.f90
  src/adapter/mod_reference_richards_legacy_binding.f90
  src/adapter/mod_b110_serialized_context_binding.f90
  src/process/mod_snow_process.f90
  src/solver/mod_b110_root_sink_provider.f90
  src/runtime/mod_fmr_serialized_reference_backend.f90
  src/runtime/mod_fmr_accepted_commit_receipt.f90
  src/runtime/mod_fmr_serialized_multiswap_runtime.f90
  src/crop/mod_crop_root_uptake_input_contract.f90
  src/crop/mod_wofost_actual_biomass_state.f90
  src/crop/mod_wofost_crop_owner_state.f90
  src/crop/mod_wofost_one_day_structural_evolution.f90
)

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  mkdir -p "$OUT"
  for source in "${MODULE_SRC[@]}"; do
    obj="$OUT/$(basename "${source%.*}").o"
    gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$source" -o "$obj"
  done
  gfortran "${STRICT[@]}" -O"$opt" -J "$OUT" -I "$OUT" \
    -c src/runtime/mod_fmr_wofost_accepted_window_lineage.f90 -o "$OUT/lineage.o"
  gfortran "${STRICT[@]}" -O"$opt" -J "$OUT" -I "$OUT" \
    -c src/runtime/mod_fmr_wofost_physical_trial_binding.f90 -o "$OUT/binding.o"
  echo "FWOF36_GATE_B_COMPILE_O${opt}=PASS"
done

echo 'FWOF36_GATE_B_COMPILE_GATE PASS'
