#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fmq27-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

fail() { echo "FMQ27_GATE_FAIL $*" >&2; exit 1; }
CANDIDATE=9064004f815e81f95eb4bdee218af29cb95039c1
OLD=dfffd8535b3345b105b2d71537d8149225f35c54
PROCESS_TEST_BLOB=c9f42747a00b317797a3a42859cab50d921c26fc

[[ -z "$(git diff --name-only "$CANDIDATE"..HEAD -- src)" ]] || fail 'production source drift after candidate'
mapfile -t remediation_src < <(git diff --name-only "$OLD".."$CANDIDATE" -- src)
printf '%s\n' "${remediation_src[@]}" | sort > "$BUILD/observed-src.txt"
printf '%s\n' src/runtime/mod_fmr_committed_restart.f90 src/runtime/mod_fmr_restart_state_contract.f90 | sort > "$BUILD/expected-src.txt"
cmp -s "$BUILD/observed-src.txt" "$BUILD/expected-src.txt" || { cat "$BUILD/observed-src.txt" >&2; fail 'unexpected F-MR21 production scope'; }
[[ "$(git rev-parse "$CANDIDATE":tests/fmr/test_fmr19_process_restart.f90)" == "$PROCESS_TEST_BLOB" ]] || fail 'real process restart supporting test drift'
echo 'FMQ27_SOURCE_LOCK=PASS'
echo 'FMQ27_REMEDIATION_SCOPE_RESTART_RUNTIME_ONLY=PASS'

python3 - <<'PY'
from pathlib import Path
restart=Path('src/runtime/mod_fmr_committed_restart.f90').read_text().lower()
contract=Path('src/runtime/mod_fmr_restart_state_contract.f90').read_text().lower()
restart_code='\n'.join(line.split('!',1)[0] for line in restart.splitlines())
record=restart_code.split('type, public :: fmr_committed_restart_record_t',1)[1].split('end type fmr_committed_restart_record_t',1)[0]
assert 'use mod_fmr_restart_state_contract, only: fmr_restart_state_matches_template' in restart_code
assert restart_code.count('fmr_restart_state_matches_template') >= 3
assert 'fmr_b110_physical_state_t' not in restart_code
assert 'fmr_b110_temporal_indicator_state_t' not in restart_code
assert 'type is (fmr_b110_physical_state_t)' in contract
assert 'type is (fmr_b110_temporal_indicator_state_t)' in contract
assert 'case default' in contract
assert 'state_registry = candidate_states' in restart_code
for forbidden in ('worker','newton','jacobian','warm_start','forcing_handle'):
    assert forbidden not in record
for forbidden in ('open(', 'close(', 'read(', 'write('):
    assert forbidden not in restart_code
print('FMQ27_GENERIC_RESTART_LAYER_PHYSICS_TYPE_AGNOSTIC=PASS')
print('FMQ27_DECLARED_TEMPLATE_STATE_BINDING_PRESENT=PASS')
print('FMQ27_COMPACT_RECORD_NO_SOLVER_SCRATCH=PASS')
print('FMQ27_ATOMIC_PUBLICATION_SEAM_PRESENT=PASS')
PY

# Qualification-owned extension of the candidate's real-physics process test:
# preserve its logic but exercise the complete F-MQ25 frozen count/time matrix.
cp tests/fmr/test_fmr19_process_restart.f90 "$BUILD/test_process.f90"
python3 - "$BUILD/test_process.f90" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1])
s=p.read_text()
replacements={
  'real(real64), parameter :: t0 = 1000.125_real64':'real(real64), parameter :: t0 = 3100.125_real64',
  'real(real64), parameter :: tm = 1000.375_real64':'real(real64), parameter :: tm = 3100.4375_real64',
  'real(real64), parameter :: t1 = 1000.625_real64':'real(real64), parameter :: t1 = 3100.8125_real64',
  'integer, parameter :: nmatrix = 5':'integer, parameter :: nmatrix = 7',
  'integer, parameter :: matrix(nmatrix) = [1, 2, 8, 17, 32]':'integer, parameter :: matrix(nmatrix) = [1, 2, 7, 8, 17, 31, 32]'
}
for old,new in replacements.items():
    if old not in s:
        raise SystemExit(f'missing expected process-test token: {old}')
    s=s.replace(old,new,1)
p.write_text(s)
PY
echo 'FMQ27_REAL_PROCESS_MATRIX_EXTENDED_TO_1_2_7_8_17_31_32=PASS'

echo 'FMQ27_GENERIC_TIME_WINDOW_3100_125_3100_4375_3100_8125=PASS'

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

  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$BUILD/test_process.f90" -o "$OUT/process.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/process.o" -o "$OUT/process"
  "$OUT/process" > "$OUT/process.txt" 2>&1 || { cat "$OUT/process.txt" >&2; fail "real process matrix O$opt"; }
  for n in 1 2 7 8 17 31 32; do
    grep -Fq "FMR19_BATCH_SIZE_${n}=PASS" "$OUT/process.txt" || fail "missing real process n=$n O$opt"
  done
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
    grep -Fq "$marker" "$OUT/process.txt" || fail "missing process marker O$opt: $marker"
  done

  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c tests/fmq/test_fmq27_restart_contract_requalification.f90 -o "$OUT/negative.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/negative.o" -o "$OUT/negative"
  "$OUT/negative" > "$OUT/negative.txt" 2>&1 || { cat "$OUT/negative.txt" >&2; fail "qualification negative matrix O$opt"; }
  for marker in \
    FMQ27_STATE_FAMILY_DISCRIMINATOR=PASS \
    FMQ27_PRODUCTION_B110_EXPORT=PASS \
    FMQ27_MALFORMED_CONCRETE_STATE_REJECTED=PASS \
    FMQ27_LATE_RECORD_ATOMICITY=PASS \
    FMQ27_REGISTERED_WRONG_FAMILY_REJECTED=PASS \
    FMQ27_LATE_PROVENANCE_ATOMICITY=PASS \
    FMQ27_FULL_NEGATIVE_MATRIX=PASS \
    FMQ27_VALID_PRODUCTION_RESTORE=PASS \
    'FMQ27_RESTART_CONTRACT_REQUALIFICATION_TEST PASS'; do
    grep -Fq "$marker" "$OUT/negative.txt" || fail "missing negative marker O$opt: $marker"
  done
  echo "FMQ27_O${opt}=PASS"
done

cmp -s "$BUILD/o0/process.txt" "$BUILD/o2/process.txt" || { diff -u "$BUILD/o0/process.txt" "$BUILD/o2/process.txt" >&2 || true; fail 'process O0/O2 identity'; }
cmp -s "$BUILD/o0/negative.txt" "$BUILD/o2/negative.txt" || { diff -u "$BUILD/o0/negative.txt" "$BUILD/o2/negative.txt" >&2 || true; fail 'negative O0/O2 identity'; }
echo 'FMQ27_O0_O2_OUTPUT_IDENTITY=PASS'
cat "$BUILD/o0/process.txt"
cat "$BUILD/o0/negative.txt"
echo 'FMQ27_GATE=PASS'
