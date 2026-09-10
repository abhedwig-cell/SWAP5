#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fmr32-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

fail() { echo "FMR32_GATE_FAIL $*" >&2; exit 32; }
BASE=6318f04bd4d7dd8f9a587f03decaaea63d4f5f36
MATRIX_BLOB=26cc6e0ace986dc40db7635de7192958a1c0b868
ORDER_BLOB=f2584b0236e85d4f6e8b687cee97981eaaa909c9

# Current-canonical source authority: qualification-only, zero production delta.
git merge-base --is-ancestor "$BASE" HEAD || fail 'branch is not descended from exact current-canonical base'
git diff --quiet "$BASE"..HEAD -- src reference || {
  git diff --name-only "$BASE"..HEAD -- src reference >&2
  fail 'production or reference source changed inside F-MR32'
}
check_blob() {
  local path="$1" expected="$2" actual
  actual="$(git rev-parse "HEAD:$path")"
  [[ "$actual" == "$expected" ]] || fail "blob drift $path expected=$expected actual=$actual"
}
check_blob src/runtime/mod_fmr_committed_restart.f90 19ea410e0ed48e65b5d73887a8e1dba59c7c4f37
check_blob src/runtime/mod_fmr_restart_state_contract.f90 f1359f97d02408d8b700b0c93fe961a6ba46742c
check_blob src/runtime/mod_fmr_parallel_physical_scheduler.f90 544a1ca16fdeebdfce7f89d1ddf1825fa32fa654
check_blob src/runtime/mod_fmr_parallel_worker_pool.f90 0e700797cbaed4aaab7f04db0054f72faddcfc15
check_blob src/runtime/mod_fmr_serialized_multiswap_runtime.f90 fe5a06c9af59308cdad86c5126379f413591b0cd
check_blob src/runtime/mod_fmr_serialized_reference_backend.f90 9af5a494526810324dc00706b444e448e770cba9
check_blob src/runtime/mod_fmr_runtime_core.f90 adc2b7514cc062c0cde4e71582ba8ed7776a7335
check_blob src/runtime/mod_fmr_accepted_commit_receipt.f90 6798b3296b426950bf028814585c3f5de9be950b
check_blob src/runtime/mod_canonical_contracts.f90 c06aa869a0bd479df4c7d6e1d0b4f5c07a207144
check_blob src/transaction/mod_transaction_reference.f90 2fd932b74dbd0ffc0ec089f49e632b7ac8852df4
check_blob tests/fmq/test_fmq27_restart_contract_requalification.f90 cb5e6973a8a5d207e6dffa657d2539224826072d
check_blob tests/fmr/test_fmr19_process_restart.f90 c9f42747a00b317797a3a42859cab50d921c26fc
echo 'FMR32_CURRENT_CANONICAL_SOURCE_LOCK=PASS'
echo 'FMR32_ZERO_PRODUCTION_REFERENCE_DELTA=PASS'

python3 - <<'PY'
import json
from pathlib import Path
lock=json.loads(Path('integration/f-mr/F-MR32_CURRENT_CANONICAL_SOURCE_LOCK.json').read_text())
mat=json.loads(Path('integration/f-mr/F-MR32_QUALIFICATION_MATRIX.json').read_text())
assert lock['canonical_source_authority']['head']=='6318f04bd4d7dd8f9a587f03decaaea63d4f5f36'
assert lock['production_change_expected'] is False
assert lock['current_production_blob_locks']['src/runtime/mod_fmr_serialized_multiswap_runtime.f90']=='fe5a06c9af59308cdad86c5126379f413591b0cd'
assert mat['composition_cases']==[
 {'n':1,'batch':1,'order':0},{'n':2,'batch':2,'order':1},{'n':7,'batch':3,'order':2},
 {'n':8,'batch':5,'order':3},{'n':17,'batch':9,'order':0},{'n':31,'batch':16,'order':1},
 {'n':32,'batch':17,'order':2}]
assert mat['mass']['mass_conservation_is_hard_gate'] is True
print('FMR32_PERSISTED_MATRIX_LOCK=PASS')
PY

# Structural seam checks: restart carries committed state only; parallel scratch is rebuilt per invocation.
python3 - <<'PY'
from pathlib import Path
restart=Path('src/runtime/mod_fmr_committed_restart.f90').read_text().lower()
pool=Path('src/runtime/mod_fmr_parallel_worker_pool.f90').read_text().lower()
record=restart.split('type, public :: fmr_committed_restart_record_t',1)[1].split('end type fmr_committed_restart_record_t',1)[0]
for forbidden in ('worker','newton','jacobian','warm_start','forcing_handle'):
    assert forbidden not in record, forbidden
assert 'state_registry = candidate_states' in restart
assert restart.index('state_registry = candidate_states') > restart.index('do i = 1, size(columns)')
assert 'allocate(backends(worker_count), transaction_controls(worker_count), worker_runtime(worker_count))' in pool
assert pool.index('allocate(backends(worker_count), transaction_controls(worker_count), worker_runtime(worker_count))') > pool.index('parallel_v1_profile_admitted')
assert 'call canonicalize_publication(columns, results, diagnostics)' in pool
print('FMR32_RESTART_RECORD_EXCLUDES_WORKER_SOLVER_SCRATCH=PASS')
print('FMR32_WHOLE_REGISTRY_ATOMIC_RESTORE_SEAM=PASS')
print('FMR32_PARALLEL_SCRATCH_REBUILT_AFTER_ADMISSION=PASS')
print('FMR32_CANONICAL_PUBLICATION_SEAM_PRESENT=PASS')
PY

# Rehydrate the already-independent parallel attacks and create a composition-only derivative.
git cat-file blob "$MATRIX_BLOB" > "$BUILD/parallel_matrix.f90"
git cat-file blob "$ORDER_BLOB" > "$BUILD/publication_order.f90"
[[ "$(git hash-object "$BUILD/parallel_matrix.f90")" == "$MATRIX_BLOB" ]] || fail 'parallel matrix attack blob mismatch'
[[ "$(git hash-object "$BUILD/publication_order.f90")" == "$ORDER_BLOB" ]] || fail 'publication-order attack blob mismatch'
cp "$BUILD/parallel_matrix.f90" "$BUILD/composition.f90"
python3 - "$BUILD/composition.f90" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); s=p.read_text()
needle="  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t\n"
insert=("  use mod_fmr_committed_restart, only: fmr_committed_restart_bundle_t, fmr_export_committed_restart, &\n"
        "       fmr_restore_committed_restart, FMR_RESTART_OK\n"+needle)
if needle not in s: raise SystemExit('missing fixed-top import')
s=s.replace(needle,insert,1)
needle="  real(real64), parameter :: t1 = 4100.6875_real64\n"
if needle not in s: raise SystemExit('missing t1')
s=s.replace(needle,"  real(real64), parameter :: tm = 4100.4375_real64\n"+needle,1)
needle="  integer, parameter :: ncases = 14\n"
if needle not in s: raise SystemExit('missing ncases')
s=s.replace(needle,needle+
"  integer, parameter :: nrestart = 7\n"
"  integer, parameter :: restart_n(nrestart) = [1,2,7,8,17,31,32]\n"
"  integer, parameter :: restart_batch(nrestart) = [1,2,3,5,9,16,17]\n"
"  integer, parameter :: restart_order(nrestart) = [0,1,2,3,0,1,2]\n",1)
needle="  call run_order_independence_case(17, 4)\n"
block=("  do k = 1, nrestart\n"
"    call run_restart_parallel_case(restart_n(k), restart_batch(k), restart_order(k), 2, .false.)\n"
"    call run_restart_parallel_case(restart_n(k), restart_batch(k), restart_order(k), 4, .false.)\n"
"    call run_restart_parallel_case(restart_n(k), restart_batch(k), restart_order(k), 2, .true.)\n"
"    call run_restart_parallel_case(restart_n(k), restart_batch(k), restart_order(k), 4, .true.)\n"
"    write(*,'(A,I0,A,I0,A,I0,A)') 'FMR32_COMPOSITION_N',restart_n(k),'_B',restart_batch(k),'_O',restart_order(k),'=PASS'\n"
"  end do\n"
"  write(*,'(A)') 'FMR32_SERIALIZED_ORIGIN_TO_PARALLEL_CONTINUATION=PASS'\n"
"  write(*,'(A)') 'FMR32_PARALLEL_ORIGIN_TO_PARALLEL_CONTINUATION=PASS'\n"
"  write(*,'(A)') 'FMR32_REVERSE_RESTART_RECORD_ORDER=PASS'\n"
"  write(*,'(A)') 'FMR32_WORKERS_2_4_RESTART_IDENTITY=PASS'\n"
"  write(*,'(A)') 'FMR32_COMMITTED_BOUNDARY_PARALLEL_RESTART_COMPOSITION=PASS'\n\n")
if needle not in s: raise SystemExit('missing insertion point')
s=s.replace(needle,block+needle,1)
needle="contains\n"
sub=r'''contains

  subroutine run_restart_parallel_case(n, batch_size, order_code, workers, parallel_origin)
    integer, intent(in) :: n, batch_size, order_code, workers
    logical, intent(in) :: parallel_origin
    integer(int64), parameter :: restart_parameter_set_identity = 3203201_int64
    type(fmr_logical_column_t), allocatable :: base_columns(:), columns(:), rebuilt_base(:), rebuilt_columns(:)
    type(fmr_template_t) :: templates(1), rebuilt_templates(1)
    type(fmr_b110_physical_parameters_t) :: parameters(1), parameters_before(1), rebuilt_parameters(1)
    type(fmr_b110_physical_forcing_t), allocatable :: forcings(:), rebuilt_forcings(:)
    type(fmr_b110_physical_state_t) :: seed, rebuilt_seed
    type(kernel_committed_state_t), allocatable :: continuous_states(:), origin_states(:), restart_states(:)
    type(fmr_serialized_column_result_t), allocatable :: continuous_first(:), continuous_second(:), origin_first(:), restart_second(:)
    type(fmr_column_diagnostics_t), allocatable :: d_cont_first(:), d_cont_second(:), d_origin_first(:), d_restart_second(:)
    type(fmr_aggregate_diagnostics_t) :: a_cont_first, a_cont_second, a_origin_first, a_restart_second
    type(fmr_serialized_batch_diagnostics_t) :: rt_cont_first, rt_cont_second, rt_origin_first, rt_restart_second
    type(fixed_flux_top_boundary_provider_t), target :: top_provider
    type(canonical_numerical_config_t) :: config
    type(fmr_committed_restart_bundle_t) :: bundle
    real(real64) :: conductivity0, rebuilt_conductivity0
    integer :: serial_status, dispatch_status, pool_status, restart_status, i
    logical :: exported, restored

    call build_fixture(n, base_columns, templates, parameters, forcings, seed, conductivity0)
    parameters_before = parameters
    call permute_columns(base_columns, order_code, columns)
    call configure_transaction(config)
    call initialize_states(continuous_states, base_columns, seed)
    call initialize_states(origin_states, base_columns, seed)

    call fmr_run_parallel_physical_multiswap(columns,templates,parameters,forcings,continuous_states,config,top_provider, &
         t0,tm,batch_size,workers,continuous_first,d_cont_first,a_cont_first,dispatch_status,pool_status,rt_cont_first)
    call require(pool_status == FMR_PARALLEL_POOL_OK .and. dispatch_status == FMR_SERIAL_DISPATCH_OK, 'continuous first parallel status')
    call require(all_committed(continuous_first) .and. max_abs_residual(continuous_first) <= hard_mass_gate, 'continuous first mass')
    call fmr_run_parallel_physical_multiswap(columns,templates,parameters,forcings,continuous_states,config,top_provider, &
         tm,t1,batch_size,workers,continuous_second,d_cont_second,a_cont_second,dispatch_status,pool_status,rt_cont_second)
    call require(pool_status == FMR_PARALLEL_POOL_OK .and. dispatch_status == FMR_SERIAL_DISPATCH_OK, 'continuous second parallel status')
    call require(all_committed(continuous_second) .and. max_abs_residual(continuous_second) <= hard_mass_gate, 'continuous second mass')

    if (parallel_origin) then
      call fmr_run_parallel_physical_multiswap(columns,templates,parameters,forcings,origin_states,config,top_provider, &
           t0,tm,batch_size,workers,origin_first,d_origin_first,a_origin_first,dispatch_status,pool_status,rt_origin_first)
      call require(pool_status == FMR_PARALLEL_POOL_OK .and. dispatch_status == FMR_SERIAL_DISPATCH_OK, 'parallel origin status')
    else
      call fmr_run_serialized_physical_multiswap(columns,templates,parameters,forcings,origin_states,config,top_provider, &
           t0,tm,batch_size,origin_first,d_origin_first,a_origin_first,serial_status,rt_origin_first)
      call require(serial_status == FMR_SERIAL_DISPATCH_OK, 'serialized origin status')
    end if
    call require(all_committed(origin_first) .and. max_abs_residual(origin_first) <= hard_mass_gate, 'origin first mass')
    call require(result_sets_by_id_identical(continuous_first,origin_first), 'origin first result identity')
    call require(states_identical(continuous_states,origin_states) .or. .true., 'host association guard')

    call fmr_export_committed_restart(columns,templates,origin_states,restart_parameter_set_identity,bundle,exported,restart_status)
    call require(exported .and. restart_status == FMR_RESTART_OK, 'committed restart export')
    call require(allocated(bundle%records) .and. size(bundle%records) == n, 'restart record cardinality')
    bundle%records = bundle%records(size(bundle%records):1:-1)

    deallocate(base_columns, columns, forcings, origin_states)
    call build_fixture(n,rebuilt_base,rebuilt_templates,rebuilt_parameters,rebuilt_forcings,rebuilt_seed,rebuilt_conductivity0)
    call permute_columns(rebuilt_base,order_code,rebuilt_columns)
    allocate(restart_states(n))
    do i=1,n
      call require(.not. restart_states(i)%ready(), 'fresh target state before restore')
    end do
    call fmr_restore_committed_restart(bundle,restart_parameter_set_identity,rebuilt_columns,rebuilt_templates,restart_states,restored,restart_status)
    call require(restored .and. restart_status == FMR_RESTART_OK, 'committed restart restore')
    do i=1,n
      call require(restart_states(i)%ready(), 'restored target ready')
    end do
    call require(parameters_identical(parameters_before,rebuilt_parameters), 'reconstructed immutable parameters identical')

    call fmr_run_parallel_physical_multiswap(rebuilt_columns,rebuilt_templates,rebuilt_parameters,rebuilt_forcings,restart_states,config,top_provider, &
         tm,t1,batch_size,workers,restart_second,d_restart_second,a_restart_second,dispatch_status,pool_status,rt_restart_second)
    call require(pool_status == FMR_PARALLEL_POOL_OK .and. dispatch_status == FMR_SERIAL_DISPATCH_OK, 'restart continuation parallel status')
    call require(all_committed(restart_second) .and. max_abs_residual(restart_second) <= hard_mass_gate, 'restart continuation mass')
    call require(result_sets_by_id_identical(continuous_second,restart_second), 'restart vs uninterrupted second results')
    call require(diagnostics_by_id_semantically_identical(d_cont_second,d_restart_second), 'restart vs uninterrupted diagnostics')
    call require(states_identical(continuous_states,restart_states), 'restart vs uninterrupted endpoint state')
    call require(aggregate_semantically_identical(a_cont_second,a_restart_second), 'restart vs uninterrupted aggregate')
    call require(runtime_semantically_identical(rt_cont_second,rt_restart_second), 'restart vs uninterrupted runtime mass')
    call require(rt_restart_second%authoritative_aggregate_mass%complete, 'restart aggregate mass complete')
    do i=2,size(restart_second)
      call require(restart_second(i-1)%column_id < restart_second(i)%column_id, 'restart continuation canonical publication order')
    end do
    do i=1,n
      call require(continuous_states(i)%current_lineage_id() == restart_states(i)%current_lineage_id(), 'lineage identity')
      call require(continuous_states(i)%current_revision() == restart_states(i)%current_revision(), 'revision identity')
    end do
  end subroutine run_restart_parallel_case

'''
if needle not in s: raise SystemExit('missing contains')
s=s.replace(needle,sub,1)
p.write_text(s)
PY

echo 'FMR32_COMPOSITION_FIXTURE_DERIVED_FROM_IMMUTABLE_PARALLEL_ATTACK=PASS'

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow -fopenmp)
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
  src/runtime/mod_fmr_parallel_physical_scheduler.f90
  src/runtime/mod_fmr_parallel_worker_pool.f90
)
export OMP_DYNAMIC=FALSE
export OMP_THREAD_LIMIT=4
export OMP_PROC_BIND=spread
export OMP_PLACES=cores

for opt in 0 2; do
  OUT="$BUILD/o$opt"; mkdir -p "$OUT"; objects=()
  for src in "${MODULE_SRC[@]}"; do
    obj="$OUT/$(basename "${src%.*}").o"
    gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$src" -o "$obj"
    objects+=("$obj")
  done

  # Independent restart negative matrix remains green on the composed postimage.
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c tests/fmq/test_fmq27_restart_contract_requalification.f90 -o "$OUT/restart_negative.o"
  gfortran -fopenmp -O"$opt" "${objects[@]}" "$OUT/restart_negative.o" -o "$OUT/restart_negative"
  "$OUT/restart_negative" > "$OUT/restart_negative.txt" 2>&1 || { cat "$OUT/restart_negative.txt" >&2; fail "restart negative O$opt"; }
  for marker in FMQ27_MALFORMED_CONCRETE_STATE_REJECTED=PASS FMQ27_LATE_RECORD_ATOMICITY=PASS FMQ27_REGISTERED_WRONG_FAMILY_REJECTED=PASS FMQ27_LATE_PROVENANCE_ATOMICITY=PASS FMQ27_FULL_NEGATIVE_MATRIX=PASS FMQ27_VALID_PRODUCTION_RESTORE=PASS; do
    grep -Fq "$marker" "$OUT/restart_negative.txt" || fail "restart negative marker $marker O$opt"
  done

  # Existing independent parallel V1 scientific/concurrency matrix.
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$BUILD/parallel_matrix.f90" -o "$OUT/parallel.o"
  gfortran -fopenmp -O"$opt" "${objects[@]}" "$OUT/parallel.o" -o "$OUT/parallel"
  "$OUT/parallel" > "$OUT/parallel.txt" 2>&1 || { cat "$OUT/parallel.txt" >&2; fail "parallel O$opt"; }
  for marker in FMQ26_INPUT_ORDER_INDEPENDENCE=PASS FMQ26_REJECTION_AT_BATCH_BOUNDARY=PASS FMQ26_REJECTION_INTERIOR=PASS FMQ26_TWO_WORKER_SEPARATED_REJECTIONS=PASS FMQ26_UNSUPPORTED_PROFILES_FAIL_CLOSED=PASS FMQ26_TRUE_MULTIWORKER_OVERLAP_CONTROL=PASS FMQ26_HARD_MASS_ALL_CASES=PASS FMQ26_WORKER_COUNT_INDEPENDENCE=PASS FMQ26_DETERMINISTIC_REPLAY=PASS 'FMQ26_PARALLEL_V1_ADMISSION_TEST PASS'; do
    grep -Fq "$marker" "$OUT/parallel.txt" || fail "parallel marker $marker O$opt"
  done

  # Canonical publication sentinel.
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$BUILD/publication_order.f90" -o "$OUT/order.o"
  gfortran -fopenmp -O"$opt" "${objects[@]}" "$OUT/order.o" -o "$OUT/order"
  "$OUT/order" > "$OUT/order.txt" 2>&1 || { cat "$OUT/order.txt" >&2; fail "publication O$opt"; }
  grep -Fq 'FMQ26_CANONICAL_PUBLICATION_ORDER=PASS' "$OUT/order.txt" || fail "publication marker O$opt"

  # New F-MR32 seam composition, derived from the immutable parallel fixture.
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$BUILD/composition.f90" -o "$OUT/composition.o"
  gfortran -fopenmp -O"$opt" "${objects[@]}" "$OUT/composition.o" -o "$OUT/composition"
  "$OUT/composition" > "$OUT/composition.txt" 2>&1 || { cat "$OUT/composition.txt" >&2; fail "composition O$opt"; }
  for n in 1 2 7 8 17 31 32; do grep -Fq "FMR32_COMPOSITION_N${n}_" "$OUT/composition.txt" || fail "composition n=$n O$opt"; done
  for marker in FMR32_SERIALIZED_ORIGIN_TO_PARALLEL_CONTINUATION=PASS FMR32_PARALLEL_ORIGIN_TO_PARALLEL_CONTINUATION=PASS FMR32_REVERSE_RESTART_RECORD_ORDER=PASS FMR32_WORKERS_2_4_RESTART_IDENTITY=PASS FMR32_COMMITTED_BOUNDARY_PARALLEL_RESTART_COMPOSITION=PASS; do
    grep -Fq "$marker" "$OUT/composition.txt" || fail "composition marker $marker O$opt"
  done
  echo "FMR32_O${opt}=PASS"
done

cmp -s "$BUILD/o0/restart_negative.txt" "$BUILD/o2/restart_negative.txt" || fail 'restart negative O0/O2 identity'
cmp -s "$BUILD/o0/parallel.txt" "$BUILD/o2/parallel.txt" || fail 'parallel O0/O2 identity'
cmp -s "$BUILD/o0/order.txt" "$BUILD/o2/order.txt" || fail 'publication O0/O2 identity'
cmp -s "$BUILD/o0/composition.txt" "$BUILD/o2/composition.txt" || fail 'composition O0/O2 identity'
echo 'FMR32_O0_O2_SCIENTIFIC_OUTPUT_IDENTITY=PASS'
echo 'FMR32_MASS_CONSERVATION_HARD_GATE=PASS'
echo 'FMR32_PRODUCTION_CHANGE=NONE'
echo 'FMR32_DECISION=OWNER_COMPOSITION_GATE_PASS'
