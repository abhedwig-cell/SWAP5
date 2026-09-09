#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fmr19-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

python3 - <<'PY'
from pathlib import Path
import json, subprocess

src_path = Path('src/runtime/mod_fmr_committed_restart.f90')
src = src_path.read_text(encoding='utf-8')
low = src.lower()
contract = json.loads(Path('integration/f-mr/F-MR19_RESTART_CONTRACT.json').read_text())

assert 'type, public :: fmr_committed_restart_bundle_t' in low
assert 'integer(int64) :: parameter_set_identity' in low
assert 'fmr_restart_parameter_set_mismatch' in low
assert 'call reconstruct_kernel_persistence_snapshot_trusted' in low
assert 'call restore_kernel_committed_state' in low
assert 'state_registry = candidate_states' in low
assert contract['schema_version'] == 2
assert contract['scope']['filesystem_or_file_format'] is False
assert contract['scope']['kernel_io'] is False
assert contract['scope']['parallel_real_physics'] is False

record = low.split('type, public :: fmr_committed_restart_record_t',1)[1].split('end type fmr_committed_restart_record_t',1)[0]
bundle = low.split('type, public :: fmr_committed_restart_bundle_t',1)[1].split('end type fmr_committed_restart_bundle_t',1)[0]
for forbidden in ('parameter_set_identity', 'forcing_handle', 'worker', 'newton', 'jacobian', 'warm_start'):
    assert forbidden not in record, f'per-column restart record contains forbidden {forbidden}'
assert bundle.count('parameter_set_identity') == 1
for forbidden in ('fmr_b110_physical_parameters_t', 'cofgen', 'forcing_handle', 'jacobian'):
    assert forbidden not in low, f'restart production module contains payload/scratch dependency {forbidden}'
for forbidden in ('open(', 'close(', 'read(', 'write('):
    assert forbidden not in low, f'restart production module performs IO: {forbidden}'

changed = subprocess.check_output([
    'git','diff','--name-only','66c2d682330c9637c6f0cbfbaca2a3ef755346ba','HEAD','--','src'
], text=True).splitlines()
assert changed == ['src/runtime/mod_fmr_committed_restart.f90'], f'unexpected production source scope: {changed}'
print('FMR19_SOURCE_SCOPE_RUNTIME_ONLY=PASS')
print('FMR19_NO_KERNEL_IO_FILESYSTEM_FORMAT=PASS')
print('FMR19_SHARED_PARAMETER_SET_IDENTITY_COMPACT_RECORDS=PASS')
print('FMR19_NO_PARAMETER_PAYLOAD_OR_SOLVER_SCRATCH_PERSISTENCE=PASS')
PY

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
MODULE_SRC=(
  tests/fsi/fsi04_real_headcalc_stubs.f90
  src/runtime/mod_a23bu_worker_execution_context.f90
  src/transaction/mod_transaction_reference.f90
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
  src/legacy/b1_10_port/headcalc.f90
  src/adapter/mod_reference_richards_legacy_binding.f90
  src/adapter/mod_b110_serialized_context_binding.f90
  src/runtime/mod_fmr_serialized_reference_backend.f90
  src/runtime/mod_fmr_serialized_multiswap_runtime.f90
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
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c \
    tests/fmr/test_fmr19_process_restart.f90 -o "$OUT/test_fmr19.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/test_fmr19.o" -o "$OUT/fmr19_process_restart"
  "$OUT/fmr19_process_restart" > "$OUT/output.txt" 2>&1 || { cat "$OUT/output.txt" >&2; exit 1; }
  for batch in 1 2 8 17 32; do grep -Fq "FMR19_BATCH_SIZE_${batch}=PASS" "$OUT/output.txt"; done
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
    grep -Fq "$marker" "$OUT/output.txt"
  done
  echo "FMR19_O${opt}=PASS"
done

cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
echo 'FMR19_O0_O2_OUTPUT_IDENTITY=PASS'
cat "$BUILD/o0/output.txt"
echo 'FMR19_GATE PASS_EXECUTABLE_CANDIDATE'
