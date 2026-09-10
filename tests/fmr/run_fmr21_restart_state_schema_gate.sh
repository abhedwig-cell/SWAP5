#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fmr21-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

fail() { echo "FMR21_GATE_FAIL $*" >&2; exit 1; }
CANDIDATE=dfffd8535b3345b105b2d71537d8149225f35c54

mapfile -t changed_src < <(git diff --name-only "$CANDIDATE"..HEAD -- src)
printf '%s\n' "${changed_src[@]}" | sort > "$BUILD/changed.txt"
printf '%s\n' src/runtime/mod_fmr_committed_restart.f90 src/runtime/mod_fmr_restart_state_contract.f90 | sort > "$BUILD/expected.txt"
cmp -s "$BUILD/changed.txt" "$BUILD/expected.txt" || {
  echo 'Observed source scope:' >&2; cat "$BUILD/changed.txt" >&2
  fail 'unexpected production source scope'
}
echo 'FMR21_SOURCE_SCOPE_RUNTIME_RESTART_ONLY=PASS'

python3 - <<'PY'
from pathlib import Path
restart=Path('src/runtime/mod_fmr_committed_restart.f90').read_text().lower()
contract=Path('src/runtime/mod_fmr_restart_state_contract.f90').read_text().lower()
restart_code='\n'.join(x.split('!',1)[0] for x in restart.splitlines())
record=restart_code.split('type, public :: fmr_committed_restart_record_t',1)[1].split('end type fmr_committed_restart_record_t',1)[0]
assert 'mod_fmr_restart_state_contract' in restart_code
assert 'fmr_restart_state_matches_template' in restart_code
assert 'fmr_b110_physical_state_t' not in restart_code
assert 'fmr_b110_temporal_indicator_state_t' not in restart_code
assert 'fmr_b110_physical_state_t' in contract
assert 'fmr_b110_temporal_indicator_state_t' in contract
assert 'type is (fmr_b110_physical_state_t)' in contract
assert 'type is (fmr_b110_temporal_indicator_state_t)' in contract
assert 'case default' in contract
for forbidden in ('worker','newton','jacobian','warm_start','forcing_handle'):
    assert forbidden not in record
for forbidden in ('open(', 'close(', 'read(', 'write('):
    assert forbidden not in restart_code
print('FMR21_GENERIC_RESTART_MODULE_NO_B110_COUPLING=PASS')
print('FMR21_RUNTIME_CONTRACT_REGISTRY_FAIL_CLOSED=PASS')
print('FMR21_NO_EXTRA_PER_COLUMN_STATE_OR_SOLVER_SCRATCH=PASS')
print('FMR21_NO_KERNEL_OR_RESTART_IO=PASS')
PY

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
MODULE_SRC=(
  tests/fsi/fsi04_real_headcalc_stubs.f90
  src/runtime/mod_a23bu_worker_execution_context.f90
  src/transaction/mod_transaction_reference.f90
  src/transaction/mod_fkt_temporal_indicator_history.f90
  src/runtime/mod_canonical_contracts.f90
  src/runtime/mod_canonical_interval_runtime.f90
  src/kernel/mod_kernel_transactions.f90
  src/kernel/mod_kernel_committed_persistence.f90
  src/runtime/mod_fmr_runtime_core.f90
  src/runtime/mod_fmr_checkpoint_orchestrator.f90
  src/solver/mod_soil_water_solver_contract.f90
  src/solver/mod_reference_richards_workspace.f90
  src/solver/mod_reference_richards_state_binding.f90
  src/solver/mod_b110_default_mvg_provider.f90
  src/solver/mod_b110_source_sink_provider.f90
  src/solver/mod_b110_root_sink_provider.f90
  src/solver/mod_fixed_flux_top_boundary_provider.f90
  src/solver/mod_reference_linear_solver.f90
  src/solver/mod_reference_richards_temporal_indicator.f90
  src/legacy/b1_10_port/headcalc.f90
  src/adapter/mod_reference_richards_legacy_binding.f90
  src/adapter/mod_b110_serialized_context_binding.f90
  src/process/mod_snow_process.f90
  src/runtime/mod_fmr_serialized_reference_backend.f90
  src/runtime/mod_fmr_serialized_multiswap_runtime.f90
  src/runtime/mod_fmr_restart_state_contract.f90
  src/runtime/mod_fmr_committed_restart.f90
  tests/fmr/mod_fmr04_fixed_top_provider.f90
)

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  mkdir -p "$OUT"
  objects=()
  for src in "${MODULE_SRC[@]}"; do
    obj="$OUT/$(basename "${src%.*}").o"
    gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$src" -o "$obj"
    objects+=("$obj")
  done

  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c tests/fmr/test_fmr19_process_restart.f90 -o "$OUT/fmr19.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/fmr19.o" -o "$OUT/fmr19"
  "$OUT/fmr19" > "$OUT/fmr19.txt" 2>&1 || { cat "$OUT/fmr19.txt" >&2; fail "FMR19 process restart O$opt"; }
  for batch in 1 2 8 17 32; do grep -Fq "FMR19_BATCH_SIZE_${batch}=PASS" "$OUT/fmr19.txt" || fail "FMR19 batch $batch O$opt"; done
  for marker in \
    FMR19_PARAMETER_SET_IDENTITY_FAIL_CLOSED=PASS \
    FMR19_TEMPLATE_LAYOUT_IDENTITY_FAIL_CLOSED=PASS \
    FMR19_PER_COLUMN_PARAMETER_REF_FAIL_CLOSED=PASS \
    FMR19_DUPLICATE_COLUMN_FAIL_CLOSED=PASS \
    FMR19_REVERSE_RECORD_ORDER=PASS \
    FMR19_REVERSE_RUNTIME_ORDER=PASS \
    FMR19_EXACT_LINEAGE_REVISION_TIME_CONTINUATION=PASS \
    FMR19_EXACT_INTERVAL_MASS_CONTINUATION=PASS \
    FMR19_CONTINUOUS_VS_RESTARTED_ENDPOINT_IDENTITY=PASS \
    FMR19_DETERMINISTIC_REPLAY=PASS \
    'FMR19_REAL_HEADCALC_PROCESS_RESTART_TEST PASS'; do
    grep -Fq "$marker" "$OUT/fmr19.txt" || fail "missing FMR19 O$opt marker $marker"
  done

  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c tests/fmr/test_fmr21_restart_state_schema_binding.f90 -o "$OUT/fmr21.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/fmr21.o" -o "$OUT/fmr21"
  "$OUT/fmr21" > "$OUT/fmr21.txt" 2>&1 || { cat "$OUT/fmr21.txt" >&2; fail "FMR21 state schema O$opt"; }
  for marker in \
    FMR21_TEMPLATE_STATE_TYPE_DISCRIMINATOR=PASS \
    FMR21_PRODUCTION_B110_EXPORT=PASS \
    FMR21_LATE_RECORD_ATOMIC_CONTROL=PASS \
    FMR21_MALFORMED_CONCRETE_STATE_REJECTED=PASS \
    FMR21_MALFORMED_STATE_WHOLE_REGISTRY_ATOMICITY=PASS \
    FMR21_VALID_PRODUCTION_RESTORE=PASS \
    'FMR21_RESTART_STATE_SCHEMA_BINDING_TEST PASS'; do
    grep -Fq "$marker" "$OUT/fmr21.txt" || fail "missing FMR21 O$opt marker $marker"
  done
  echo "FMR21_O${opt}=PASS"
done

cmp -s "$BUILD/o0/fmr19.txt" "$BUILD/o2/fmr19.txt" || fail 'FMR19 O0/O2 output identity'
cmp -s "$BUILD/o0/fmr21.txt" "$BUILD/o2/fmr21.txt" || fail 'FMR21 O0/O2 output identity'
echo 'FMR21_O0_O2_OUTPUT_IDENTITY=PASS'
cat "$BUILD/o0/fmr21.txt"
echo 'FMR21_GATE=PASS'
