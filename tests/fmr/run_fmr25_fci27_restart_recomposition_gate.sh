#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fmr25-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

fail() { echo "FMR25_GATE_FAIL $*" >&2; exit 1; }
BASE=0aa4f7ca88a1cd2f3cf7333a35946c4415d9258d
RESTART_BLOB=19ea410e0ed48e65b5d73887a8e1dba59c7c4f37
CONTRACT_BLOB=f1359f97d02408d8b700b0c93fe961a6ba46742c
PROCESS_TEST_BLOB=c9f42747a00b317797a3a42859cab50d921c26fc
NEGATIVE_TEST_BLOB=cb5e6973a8a5d207e6dffa657d2539224826072d
RUNTIME_CORE_BLOB=adc2b7514cc062c0cde4e71582ba8ed7776a7335
KERNEL_PERSISTENCE_BLOB=ffd886c3401fc12739a456fe60a8741c12b9848b
KERNEL_TRANSACTIONS_BLOB=f1acff10dd99c308a00f434440d6a9ef14632f0d
TRANSACTION_REFERENCE_BLOB=2fd932b74dbd0ffc0ec089f49e632b7ac8852df4
RECEIPT_BLOB=6798b3296b426950bf028814585c3f5de9be950b
ET_PROCESS_BLOB=f5e88ec5089fd3b57ac111065fab2aa32dde0fae
ET_BINDING_BLOB=8c679f911c9a82c498258224d83f5fce3cb09163
CANONICAL_CONTRACTS_BLOB=c06aa869a0bd479df4c7d6e1d0b4f5c07a207144
FMR23_STATUS_BLOB=3e2aef36f902e7525adabc133fddb3c26f31c78f
FMR23_TEST_BLOB=fcc555c4b29369d7e47be34c6d104799aeb92b65
FVQ36_TEST_BLOB=de94b4678da5a1cefb6d04c38cd55cb4768925d4

mapfile -t changed_src < <(git diff --name-only "$BASE"..HEAD -- src)
printf '%s\n' "${changed_src[@]}" | sort > "$BUILD/changed-src.txt"
printf '%s\n' src/runtime/mod_fmr_committed_restart.f90 src/runtime/mod_fmr_restart_state_contract.f90 | sort > "$BUILD/expected-src.txt"
cmp -s "$BUILD/changed-src.txt" "$BUILD/expected-src.txt" || {
  echo 'Observed production source delta:' >&2
  cat "$BUILD/changed-src.txt" >&2
  fail 'production delta is not exactly the two qualified restart modules'
}

check_blob() {
  local path="$1" expected="$2" actual
  actual="$(git rev-parse "HEAD:$path")"
  [[ "$actual" == "$expected" ]] || fail "blob drift $path expected=$expected actual=$actual"
}

check_blob src/runtime/mod_fmr_committed_restart.f90 "$RESTART_BLOB"
check_blob src/runtime/mod_fmr_restart_state_contract.f90 "$CONTRACT_BLOB"
check_blob src/runtime/mod_fmr_runtime_core.f90 "$RUNTIME_CORE_BLOB"
check_blob src/kernel/mod_kernel_committed_persistence.f90 "$KERNEL_PERSISTENCE_BLOB"
check_blob src/kernel/mod_kernel_transactions.f90 "$KERNEL_TRANSACTIONS_BLOB"
check_blob src/transaction/mod_transaction_reference.f90 "$TRANSACTION_REFERENCE_BLOB"
check_blob src/runtime/mod_fmr_accepted_commit_receipt.f90 "$RECEIPT_BLOB"
check_blob src/process/mod_reference_et_demand_process.f90 "$ET_PROCESS_BLOB"
check_blob src/runtime/mod_fmr_reference_et_demand_binding.f90 "$ET_BINDING_BLOB"
check_blob src/runtime/mod_canonical_contracts.f90 "$CANONICAL_CONTRACTS_BLOB"
check_blob integration/f-mr/F-MR23_STATUS.json "$FMR23_STATUS_BLOB"
check_blob tests/fmr/test_fmr19_process_restart.f90 "$PROCESS_TEST_BLOB"
check_blob tests/fmq/test_fmq27_restart_contract_requalification.f90 "$NEGATIVE_TEST_BLOB"
check_blob tests/fmr/test_fmr23_reference_et_runtime_binding.f90 "$FMR23_TEST_BLOB"
check_blob tests/fvq/test_fvq36_fmr23_reference_et_runtime_oracle.f90 "$FVQ36_TEST_BLOB"
echo 'FMR25_FCI27_SOURCE_LOCK=PASS'
echo 'FMR25_EXACT_FMR24_RESTART_BLOBS=PASS'
echo 'FMR25_FCI27_ET_RUNTIME_BLOBS_PRESERVED=PASS'
echo 'FMR25_FROZEN_RESTART_ATTACK_PROVENANCE=PASS'

python3 - <<'PY'
from pathlib import Path
restart = Path('src/runtime/mod_fmr_committed_restart.f90').read_text().lower()
contract = Path('src/runtime/mod_fmr_restart_state_contract.f90').read_text().lower()
etbind = Path('src/runtime/mod_fmr_reference_et_demand_binding.f90').read_text().lower()
record = restart.split('type, public :: fmr_committed_restart_record_t',1)[1].split('end type fmr_committed_restart_record_t',1)[0]
assert 'fmr_restart_state_matches_template' in restart
assert 'type is (fmr_b110_physical_state_t)' in contract
assert 'type is (fmr_b110_temporal_indicator_state_t)' in contract
assert 'state_registry = candidate_states' in restart
for forbidden in ('worker','newton','jacobian','warm_start','forcing_handle'):
    assert forbidden not in record
for forbidden in ('open(', 'close(', 'read(', 'write('):
    assert forbidden not in restart
assert 'canonical_interval_t' in etbind
assert 'fmr_reference_et_forcing_span_t' in etbind
for forbidden in ('headcalc','newton','jacobian','root_water_uptake','mass_accounting','calendar'):
    assert forbidden not in etbind
print('FMR25_RESTART_STATE_FAMILY_BINDING=PASS')
print('FMR25_RESTART_ATOMIC_PUBLICATION_SEAM=PASS')
print('FMR25_RESTART_COMPACT_NO_SOLVER_SCRATCH=PASS')
print('FMR25_ET_RUNTIME_SCOPE_SEPARATION_PRESERVED=PASS')
PY

# Frozen F-MQ27/F-MR19 process attack, extended in a temporary copy only to
# retain the independently exercised irregular 1,2,7,8,17,31,32 matrix.
cp tests/fmr/test_fmr19_process_restart.f90 "$BUILD/test_process.f90"
python3 - "$BUILD/test_process.f90" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1])
s=p.read_text()
replacements={
  'real(real64), parameter :: t0 = 1000.125_real64':'real(real64), parameter :: t0 = 5100.125_real64',
  'real(real64), parameter :: tm = 1000.375_real64':'real(real64), parameter :: tm = 5100.4375_real64',
  'real(real64), parameter :: t1 = 1000.625_real64':'real(real64), parameter :: t1 = 5100.8125_real64',
  'integer, parameter :: nmatrix = 5':'integer, parameter :: nmatrix = 7',
  'integer, parameter :: matrix(nmatrix) = [1, 2, 8, 17, 32]':'integer, parameter :: matrix(nmatrix) = [1, 2, 7, 8, 17, 31, 32]'
}
for old,new in replacements.items():
    if old not in s:
        raise SystemExit(f'missing frozen process-test token: {old}')
    s=s.replace(old,new,1)
p.write_text(s)
PY
echo 'FMR25_REAL_PROCESS_MATRIX_1_2_7_8_17_31_32=PASS'
echo 'FMR25_GENERIC_TIME_WINDOW_5100_125_5100_4375_5100_8125=PASS'

RESTART_COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
ET_COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -Werror -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
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
  src/runtime/mod_fmr_accepted_commit_receipt.f90
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
    gfortran "${RESTART_COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$src" -o "$obj"
    objects+=("$obj")
  done

  gfortran "${RESTART_COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$BUILD/test_process.f90" -o "$OUT/process.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/process.o" -o "$OUT/process"
  "$OUT/process" > "$OUT/process.txt" 2>&1 || { cat "$OUT/process.txt" >&2; fail "restart process matrix O$opt"; }
  for n in 1 2 7 8 17 31 32; do
    grep -Fq "FMR19_BATCH_SIZE_${n}=PASS" "$OUT/process.txt" || fail "missing restart n=$n O$opt"
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
    grep -Fq "$marker" "$OUT/process.txt" || fail "missing restart marker O$opt: $marker"
  done

  gfortran "${RESTART_COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c tests/fmq/test_fmq27_restart_contract_requalification.f90 -o "$OUT/negative.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/negative.o" -o "$OUT/negative"
  "$OUT/negative" > "$OUT/negative.txt" 2>&1 || { cat "$OUT/negative.txt" >&2; fail "restart negative matrix O$opt"; }
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

  # Composition-aware preservation of the already-canonical F-CI27 ET runtime.
  gfortran "${ET_COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c src/process/mod_reference_et_demand_process.f90 -o "$OUT/et_process.o"
  gfortran "${ET_COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c src/runtime/mod_fmr_reference_et_demand_binding.f90 -o "$OUT/et_binding.o"
  gfortran "${ET_COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c tests/fmr/test_fmr23_reference_et_runtime_binding.f90 -o "$OUT/et_owner_test.o"
  gfortran -O"$opt" "$OUT/mod_transaction_reference.o" "$OUT/mod_canonical_contracts.o" "$OUT/et_process.o" "$OUT/et_binding.o" "$OUT/et_owner_test.o" -o "$OUT/et_owner"
  "$OUT/et_owner" > "$OUT/et_owner.txt" 2>&1 || { cat "$OUT/et_owner.txt" >&2; fail "ET owner preservation O$opt"; }
  for marker in \
    FMR23_ARBITRARY_SUBDAY_INTERVAL=PASS \
    FMR23_FORCING_SPAN_CONTAINMENT=PASS \
    FMR23_RATE_NOT_IMPLICITLY_TIME_INTEGRATED=PASS \
    FMR23_INVALID_TIME_FAIL_CLOSED=PASS \
    FMR23_PROCESS_REJECTION_FAIL_CLOSED=PASS \
    FMR23_NONEMERGED_CANOPY_SEMANTICS=PASS \
    FMR23_STATELESS_A_B_A_IDENTITY=PASS \
    'FMR23_REFERENCE_ET_RUNTIME_BINDING_TEST PASS'; do
    grep -Fq "$marker" "$OUT/et_owner.txt" || fail "missing ET owner marker O$opt: $marker"
  done

  gfortran "${ET_COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c tests/fvq/test_fvq36_fmr23_reference_et_runtime_oracle.f90 -o "$OUT/et_oracle_test.o"
  gfortran -O"$opt" "$OUT/mod_transaction_reference.o" "$OUT/mod_canonical_contracts.o" "$OUT/et_process.o" "$OUT/et_binding.o" "$OUT/et_oracle_test.o" -o "$OUT/et_oracle"
  "$OUT/et_oracle" > "$OUT/et_oracle.txt" 2>&1 || { cat "$OUT/et_oracle.txt" >&2; fail "ET independent oracle preservation O$opt"; }
  for marker in \
    FVQ36_INDEPENDENT_GRID_CASES=13824 \
    FVQ36_GENERIC_SIGNED_TIME_ORIGINS=PASS \
    FVQ36_VARIABLE_FORCING_SPAN_LENGTHS=PASS \
    FVQ36_INDEPENDENT_ET_RATE_ORACLE=PASS \
    FVQ36_RATE_INVARIANT_TO_CONTAINED_INTERVAL_DURATION=PASS \
    FVQ36_EXACT_FORCING_BOUNDARIES=PASS \
    FVQ36_OUTSIDE_FORCING_FAILS_BEFORE_PROCESS=PASS \
    FVQ36_INVALID_TIME_GEOMETRY_FAIL_CLOSED=PASS \
    FVQ36_NONEMERGED_DEPENDENCY_SEMANTICS=PASS \
    FVQ36_STATELESS_A_B_A_IDENTITY=PASS \
    'FVQ36_FMR23_REFERENCE_ET_RUNTIME_ORACLE PASS'; do
    grep -Fq "$marker" "$OUT/et_oracle.txt" || fail "missing ET oracle marker O$opt: $marker"
  done
  echo "FMR25_O${opt}=PASS"
done

cmp -s "$BUILD/o0/process.txt" "$BUILD/o2/process.txt" || fail 'restart process O0/O2 output identity'
cmp -s "$BUILD/o0/negative.txt" "$BUILD/o2/negative.txt" || fail 'restart negative O0/O2 output identity'
cmp -s "$BUILD/o0/et_owner.txt" "$BUILD/o2/et_owner.txt" || fail 'ET owner O0/O2 output identity'
cmp -s "$BUILD/o0/et_oracle.txt" "$BUILD/o2/et_oracle.txt" || fail 'ET oracle O0/O2 output identity'
echo 'FMR25_O0_O2_OUTPUT_IDENTITY=PASS'
echo 'FMR25_FCI27_ET_RUNTIME_OWNER_PRESERVATION=PASS'
echo 'FMR25_FCI27_ET_RUNTIME_INDEPENDENT_ORACLE_PRESERVATION=PASS'
cat "$BUILD/o0/process.txt"
cat "$BUILD/o0/negative.txt"
cat "$BUILD/o0/et_owner.txt"
cat "$BUILD/o0/et_oracle.txt"
echo 'FMR25_FCI27_RESTART_RECOMPOSITION_GATE=PASS'
