#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fmq25-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

CANDIDATE=dfffd8535b3345b105b2d71537d8149225f35c54
[[ -z "$(git diff --name-only "$CANDIDATE"..HEAD -- src)" ]] || { echo 'FMQ25_SOURCE_DRIFT=FAIL'; exit 2; }
[[ "$(git rev-parse HEAD:src/runtime/mod_fmr_committed_restart.f90)" == bb4d0e27b8131f62ae4860660addbc39e0fc125a ]] || exit 3
[[ "$(git rev-parse HEAD:src/kernel/mod_kernel_committed_persistence.f90)" == ffd886c3401fc12739a456fe60a8741c12b9848b ]] || exit 3
[[ "$(git rev-parse HEAD:src/kernel/mod_kernel_transactions.f90)" == f1acff10dd99c308a00f434440d6a9ef14632f0d ]] || exit 3
echo 'FMQ25_SOURCE_LOCK=PASS'

python3 - <<'PY'
from pathlib import Path
src = Path('src/runtime/mod_fmr_committed_restart.f90').read_text(encoding='utf-8').lower()
record = src.split('type, public :: fmr_committed_restart_record_t',1)[1].split('end type fmr_committed_restart_record_t',1)[0]
for forbidden in ('worker', 'newton', 'jacobian', 'warm_start', 'forcing_handle'):
    assert forbidden not in record, forbidden
assert 'class(transaction_state_t), allocatable :: physical_state' in record
assert 'state_registry = candidate_states' in src
print('FMQ25_NO_SOLVER_SCRATCH_IN_RECORD=PASS')
print('FMQ25_TEMPORARY_REGISTRY_PUBLICATION_SEAM_PRESENT=PASS')
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
  src/runtime/mod_fmr_committed_restart.f90
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
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c tests/fmq/test_fmq25_restart_malformed_state.f90 -o "$OUT/test.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/test.o" -o "$OUT/test"

  set +e
  "$OUT/test" > "$OUT/output.txt" 2>&1
  rc=$?
  set -e
  cat "$OUT/output.txt"
  [[ $rc -eq 25 ]] || { echo "FMQ25_O${opt}_UNEXPECTED_SENTINEL_RC=$rc"; exit 4; }
  grep -Fq 'FMQ25_LATE_RECORD_ATOMIC_CONTROL=PASS' "$OUT/output.txt"
  grep -Fq 'FMQ25_MALFORMED_CONCRETE_STATE_REJECTED=FAIL' "$OUT/output.txt"
  grep -Fq 'FMQ25_OBSERVED_RESTORE_STATUS=0' "$OUT/output.txt"
  grep -Fq 'FMQ25_OBSERVED_RESTORED=T' "$OUT/output.txt"
  grep -Fq 'FMQ25_TARGET1_READY=T' "$OUT/output.txt"
  grep -Fq 'FMQ25_TARGET2_READY=T' "$OUT/output.txt"
  echo "FMQ25_O${opt}_MALFORMED_STATE_FAIL_OPEN_REPRODUCED=PASS"
done

cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
echo 'FMQ25_O0_O2_DEFECT_REPRODUCTION_IDENTITY=PASS'
echo 'FMQ25_CANDIDATE_HARD_NEGATIVE_VIOLATION=OBSERVED'
echo 'FMQ25_DECISION=NOT_QUALIFIED'
exit 25
