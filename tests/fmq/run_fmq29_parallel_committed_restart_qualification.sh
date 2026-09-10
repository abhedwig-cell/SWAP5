#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fmq29-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

fail() { echo "FMQ29_GATE_FAIL $*" >&2; exit 29; }
BASE=6318f04bd4d7dd8f9a587f03decaaea63d4f5f36
OWNER_CANDIDATE=1e27f2758d9dbed11350aec5a089662921826d21
OWNER_CLOSEOUT=eef9cfa2cdb6b272ae9c0dd1f4ad0c90153953f4
PARALLEL_BLOB=26cc6e0ace986dc40db7635de7192958a1c0b868
ORDER_BLOB=f2584b0236e85d4f6e8b687cee97981eaaa909c9

# --- Independent source/candidate authority ---------------------------------
git merge-base --is-ancestor "$BASE" HEAD || fail 'qualification branch not descended from current canonical'
if git merge-base --is-ancestor "$OWNER_CANDIDATE" HEAD; then
  fail 'qualification branch improperly descends from owner candidate'
fi
git merge-base --is-ancestor "$BASE" "$OWNER_CANDIDATE" || fail 'owner candidate not descended from canonical source authority'
git merge-base --is-ancestor "$OWNER_CANDIDATE" "$OWNER_CLOSEOUT" || fail 'owner closeout not descended from immutable owner candidate'
git diff --quiet "$BASE".."$OWNER_CANDIDATE" -- src reference || fail 'owner candidate unexpectedly changes production/reference source'
git diff --quiet "$OWNER_CANDIDATE".."$OWNER_CLOSEOUT" -- src reference || fail 'owner closeout unexpectedly changes production/reference source'
git diff --quiet "$BASE"..HEAD -- src reference || fail 'F-MQ29 qualification mutated production/reference source'

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
check_blob tests/fmq/test_fmq27_restart_contract_requalification.f90 cb5e6973a8a5d207e6dffa657d2539224826072d

echo 'FMQ29_CURRENT_CANONICAL_SOURCE_LOCK=PASS'
echo 'FMQ29_OWNER_CANDIDATE_ZERO_SOURCE_DELTA=PASS'
echo 'FMQ29_QUALIFICATION_INDEPENDENT_BRANCH_BASE=PASS'
echo 'FMQ29_PRODUCTION_REFERENCE_IMMUTABLE=PASS'

python3 - <<'PY'
import json, subprocess
from pathlib import Path
lock=json.loads(Path('integration/f-mq/F-MQ29_CANDIDATE_LOCK.json').read_text())
mat=json.loads(Path('integration/f-mq/F-MQ29_QUALIFICATION_MATRIX.json').read_text())
assert lock['owner']['candidate']=='1e27f2758d9dbed11350aec5a089662921826d21'
assert lock['owner']['closeout']=='eef9cfa2cdb6b272ae9c0dd1f4ad0c90153953f4'
assert lock['independence_rule'].startswith('Do not import owner scientific conclusions')
assert mat['owner_composition_fixture']=='EXCLUDED_FROM_QUALIFICATION_EVIDENCE' if 'owner_composition_fixture' in mat else mat['independent_attack_basis']['owner_composition_fixture']=='EXCLUDED_FROM_QUALIFICATION_EVIDENCE'
assert [c['n'] for c in mat['held_out_composition_cases']]==[3,5,9,16,23,33]
owner_status=subprocess.check_output(['git','show','eef9cfa2cdb6b272ae9c0dd1f4ad0c90153953f4:integration/f-mr/F-MR32_STATUS.json'],text=True)
os=json.loads(owner_status)
assert os['immutable_owner_candidate']['commit']=='1e27f2758d9dbed11350aec5a089662921826d21'
assert os['independently_qualified'] is False
print('FMQ29_CANDIDATE_AND_MATRIX_LOCK=PASS')
print('FMQ29_OWNER_DECISION_NOT_INHERITED=PASS')
PY

# Static composition audit reconstructed from production source only.
python3 - <<'PY'
from pathlib import Path
r=Path('src/runtime/mod_fmr_committed_restart.f90').read_text().lower()
p=Path('src/runtime/mod_fmr_parallel_worker_pool.f90').read_text().lower()
record=r.split('type, public :: fmr_committed_restart_record_t',1)[1].split('end type fmr_committed_restart_record_t',1)[0]
for forbidden in ('worker','newton','jacobian','warm_start','forcing_handle'):
    assert forbidden not in record
assert 'state_registry = candidate_states' in r
assert r.index('state_registry = candidate_states') > r.index('do i = 1, size(columns)')
assert 'parallel_v1_profile_admitted' in p
alloc='allocate(backends(worker_count), transaction_controls(worker_count), worker_runtime(worker_count))'
assert alloc in p and p.index(alloc) > p.index('parallel_v1_profile_admitted')
assert 'call canonicalize_publication(columns, results, diagnostics)' in p
print('FMQ29_COMMITTED_STATE_ONLY_RESTART=PASS')
print('FMQ29_ATOMIC_RESTORE_BEFORE_PARALLEL_DISPATCH=PASS')
print('FMQ29_WORKER_SCRATCH_REBUILT_NOT_PERSISTED=PASS')
print('FMQ29_CANONICAL_PUBLICATION_STATIC=PASS')
PY

# Rehydrate prior independent attacks; do not import F-MR32 owner composition fixture.
git cat-file blob "$PARALLEL_BLOB" > "$BUILD/prior_parallel.f90"
git cat-file blob "$ORDER_BLOB" > "$BUILD/prior_order.f90"
[[ "$(git hash-object "$BUILD/prior_parallel.f90")" == "$PARALLEL_BLOB" ]] || fail 'parallel attack blob mismatch'
[[ "$(git hash-object "$BUILD/prior_order.f90")" == "$ORDER_BLOB" ]] || fail 'publication attack blob mismatch'

# Build a new held-out cross-worker restart attack independently from the prior
# independent parallel fixture. The owner F-MR32 generated test is never read.
cp "$BUILD/prior_parallel.f90" "$BUILD/heldout_restart.f90"
python3 - "$BUILD/heldout_restart.f90" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); s=p.read_text()

old="  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t\n"
new=("  use mod_fmr_committed_restart, only: fmr_committed_restart_bundle_t, fmr_export_committed_restart, &\n"
     "       fmr_restore_committed_restart, FMR_RESTART_OK\n"+old)
assert old in s; s=s.replace(old,new,1)
old="  real(real64), parameter :: t1 = 4100.6875_real64\n"
assert old in s; s=s.replace(old,"  real(real64), parameter :: tm29 = 4100.40625_real64\n"+old,1)
old="  integer, parameter :: ncases = 14\n"
new=old+("  integer, parameter :: nheld29 = 6\n"
         "  integer, parameter :: held_n29(nheld29) = [3,5,9,16,23,33]\n"
         "  integer, parameter :: held_batch29(nheld29) = [2,4,4,7,10,14]\n"
         "  integer, parameter :: held_order29(nheld29) = [3,2,1,3,2,1]\n")
assert old in s; s=s.replace(old,new,1)
old="  call run_order_independence_case(17, 4)\n"
block=("  do k = 1, nheld29\n"
       "    call run_fmq29_restart_route(held_n29(k),held_batch29(k),held_order29(k),0,2,1+mod(k,2))\n"
       "    call run_fmq29_restart_route(held_n29(k),held_batch29(k),held_order29(k),0,4,1+mod(k+1,2))\n"
       "    call run_fmq29_restart_route(held_n29(k),held_batch29(k),held_order29(k),2,2,1+mod(k,2))\n"
       "    call run_fmq29_restart_route(held_n29(k),held_batch29(k),held_order29(k),2,4,1+mod(k+1,2))\n"
       "    call run_fmq29_restart_route(held_n29(k),held_batch29(k),held_order29(k),4,2,1+mod(k,2))\n"
       "    call run_fmq29_restart_route(held_n29(k),held_batch29(k),held_order29(k),4,4,1+mod(k+1,2))\n"
       "    write(*,'(A,I0,A,I0,A,I0,A)') 'FMQ29_HELDOUT_N',held_n29(k),'_B',held_batch29(k),'_O',held_order29(k),'=PASS'\n"
       "  end do\n"
       "  write(*,'(A)') 'FMQ29_SERIALIZED_ORIGIN_RESTART=PASS'\n"
       "  write(*,'(A)') 'FMQ29_PARALLEL_2_ORIGIN_RESTART=PASS'\n"
       "  write(*,'(A)') 'FMQ29_PARALLEL_4_ORIGIN_RESTART=PASS'\n"
       "  write(*,'(A)') 'FMQ29_CROSS_WORKER_2_TO_4=PASS'\n"
       "  write(*,'(A)') 'FMQ29_CROSS_WORKER_4_TO_2=PASS'\n"
       "  write(*,'(A)') 'FMQ29_REVERSE_AND_INTERLEAVED_RECORD_ORDER=PASS'\n"
       "  write(*,'(A)') 'FMQ29_INDEPENDENT_PARALLEL_RESTART_COMPOSITION=PASS'\n\n")
assert old in s; s=s.replace(old,block+old,1)
old="contains\n"
sub=r'''contains

  subroutine run_fmq29_restart_route(n,batch_size,order_code,origin_workers,continuation_workers,record_mode)
    integer, intent(in) :: n,batch_size,order_code,origin_workers,continuation_workers,record_mode
    integer(int64), parameter :: parameter_set_identity29 = 29002901_int64
    type(fmr_logical_column_t), allocatable :: base(:), cols(:), rebuilt_base(:), rebuilt_cols(:)
    type(fmr_template_t) :: templates(1), rebuilt_templates(1)
    type(fmr_b110_physical_parameters_t) :: parameters(1), parameters_before(1), rebuilt_parameters(1)
    type(fmr_b110_physical_forcing_t), allocatable :: forcings(:), rebuilt_forcings(:)
    type(fmr_b110_physical_state_t) :: seed, rebuilt_seed
    type(kernel_committed_state_t), allocatable :: reference_states(:), reference_mid(:), origin_states(:), restored_states(:)
    type(fmr_serialized_column_result_t), allocatable :: ref_first(:), ref_second(:), origin_first(:), restarted_second(:)
    type(fmr_column_diagnostics_t), allocatable :: d_ref_first(:), d_ref_second(:), d_origin_first(:), d_restarted_second(:)
    type(fmr_aggregate_diagnostics_t) :: a_ref_first,a_ref_second,a_origin_first,a_restarted_second
    type(fmr_serialized_batch_diagnostics_t) :: rt_ref_first,rt_ref_second,rt_origin_first,rt_restarted_second
    type(fixed_flux_top_boundary_provider_t), target :: top_provider
    type(canonical_numerical_config_t) :: config
    type(fmr_committed_restart_bundle_t) :: bundle
    real(real64) :: conductivity0, rebuilt_conductivity0
    integer :: serial_status,dispatch_status,pool_status,restart_status,i
    logical :: exported,restored

    call build_fixture(n,base,templates,parameters,forcings,seed,conductivity0)
    parameters_before=parameters
    call permute_columns(base,order_code,cols)
    call configure_transaction(config)
    call initialize_states(reference_states,base,seed)
    call initialize_states(origin_states,base,seed)

    ! Independent uninterrupted oracle: serialized midpoint, then the exact
    ! continuation worker count being tested.
    call fmr_run_serialized_physical_multiswap(cols,templates,parameters,forcings,reference_states,config,top_provider, &
         t0,tm29,batch_size,ref_first,d_ref_first,a_ref_first,serial_status,rt_ref_first)
    call require(serial_status==FMR_SERIAL_DISPATCH_OK .and. all_committed(ref_first),'FMQ29 reference midpoint')
    call require(max_abs_residual(ref_first)<=hard_mass_gate,'FMQ29 reference midpoint mass')
    reference_mid=reference_states
    call fmr_run_parallel_physical_multiswap(cols,templates,parameters,forcings,reference_states,config,top_provider, &
         tm29,t1,batch_size,continuation_workers,ref_second,d_ref_second,a_ref_second,dispatch_status,pool_status,rt_ref_second)
    call require(pool_status==FMR_PARALLEL_POOL_OK .and. dispatch_status==FMR_SERIAL_DISPATCH_OK,'FMQ29 uninterrupted continuation')
    call require(all_committed(ref_second) .and. max_abs_residual(ref_second)<=hard_mass_gate,'FMQ29 uninterrupted mass')
    call require(rt_ref_second%authoritative_aggregate_mass%complete,'FMQ29 reference aggregate mass complete')

    select case(origin_workers)
    case(0)
      call fmr_run_serialized_physical_multiswap(cols,templates,parameters,forcings,origin_states,config,top_provider, &
           t0,tm29,batch_size,origin_first,d_origin_first,a_origin_first,serial_status,rt_origin_first)
      call require(serial_status==FMR_SERIAL_DISPATCH_OK,'FMQ29 serialized origin status')
    case(2,4)
      call fmr_run_parallel_physical_multiswap(cols,templates,parameters,forcings,origin_states,config,top_provider, &
           t0,tm29,batch_size,origin_workers,origin_first,d_origin_first,a_origin_first,dispatch_status,pool_status,rt_origin_first)
      call require(pool_status==FMR_PARALLEL_POOL_OK .and. dispatch_status==FMR_SERIAL_DISPATCH_OK,'FMQ29 parallel origin status')
    case default
      call require(.false.,'FMQ29 invalid origin worker code')
    end select
    call require(all_committed(origin_first) .and. max_abs_residual(origin_first)<=hard_mass_gate,'FMQ29 origin midpoint mass')
    call require(result_sets_by_id_identical(ref_first,origin_first),'FMQ29 midpoint result identity')
    call require(states_identical(reference_mid,origin_states),'FMQ29 exact committed midpoint state identity')

    call fmr_export_committed_restart(cols,templates,origin_states,parameter_set_identity29,bundle,exported,restart_status)
    call require(exported .and. restart_status==FMR_RESTART_OK,'FMQ29 export')
    call reorder_records29(bundle,record_mode)

    ! Reconstruct configuration independently and deliberately change caller
    ! column ordering after restart. Only the decoded bundle survives physically.
    deallocate(base,cols,forcings,origin_states)
    call build_fixture(n,rebuilt_base,rebuilt_templates,rebuilt_parameters,rebuilt_forcings,rebuilt_seed,rebuilt_conductivity0)
    call permute_columns(rebuilt_base,mod(order_code+2,4),rebuilt_cols)
    allocate(restored_states(n))
    do i=1,n
      call require(.not.restored_states(i)%ready(),'FMQ29 fresh target before restore')
    end do
    call fmr_restore_committed_restart(bundle,parameter_set_identity29,rebuilt_cols,rebuilt_templates,restored_states,restored,restart_status)
    call require(restored .and. restart_status==FMR_RESTART_OK,'FMQ29 restore')
    call require(states_identical(reference_mid,restored_states),'FMQ29 restored midpoint identity')
    call require(parameters_identical(parameters_before,rebuilt_parameters),'FMQ29 immutable parameter identity')

    call fmr_run_parallel_physical_multiswap(rebuilt_cols,rebuilt_templates,rebuilt_parameters,rebuilt_forcings,restored_states,config,top_provider, &
         tm29,t1,batch_size,continuation_workers,restarted_second,d_restarted_second,a_restarted_second,dispatch_status,pool_status,rt_restarted_second)
    call require(pool_status==FMR_PARALLEL_POOL_OK .and. dispatch_status==FMR_SERIAL_DISPATCH_OK,'FMQ29 restarted continuation status')
    call require(all_committed(restarted_second) .and. max_abs_residual(restarted_second)<=hard_mass_gate,'FMQ29 restarted mass')
    call require(rt_restarted_second%authoritative_aggregate_mass%complete,'FMQ29 restarted aggregate mass complete')
    call require(result_sets_by_id_identical(ref_second,restarted_second),'FMQ29 endpoint result identity by id')
    call require(diagnostics_by_id_semantically_identical(d_ref_second,d_restarted_second),'FMQ29 endpoint diagnostic identity')
    call require(states_identical(reference_states,restored_states),'FMQ29 endpoint committed state identity')
    call require(aggregate_semantically_identical(a_ref_second,a_restarted_second),'FMQ29 aggregate residual identity')
    call require(runtime_semantically_identical(rt_ref_second,rt_restarted_second),'FMQ29 authoritative aggregate mass identity')
    do i=2,size(restarted_second)
      call require(restarted_second(i-1)%column_id<restarted_second(i)%column_id,'FMQ29 canonical published result order')
    end do
  end subroutine run_fmq29_restart_route

  subroutine reorder_records29(bundle,mode)
    type(fmr_committed_restart_bundle_t), intent(inout) :: bundle
    integer, intent(in) :: mode
    integer, allocatable :: order(:)
    integer :: i,k,n
    n=size(bundle%records)
    select case(mode)
    case(1)
      bundle%records=bundle%records(n:1:-1)
    case(2)
      allocate(order(n)); k=0
      do i=1,n,2; k=k+1; order(k)=i; end do
      do i=2,n,2; k=k+1; order(k)=i; end do
      bundle%records=bundle%records(order)
    case default
      call require(.false.,'FMQ29 invalid record reorder mode')
    end select
  end subroutine reorder_records29

'''
assert old in s; s=s.replace(old,sub,1)
p.write_text(s)
PY

echo 'FMQ29_HELDOUT_FIXTURE_RECONSTRUCTED_INDEPENDENTLY=PASS'

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

  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c tests/fmq/test_fmq27_restart_contract_requalification.f90 -o "$OUT/negative.o"
  gfortran -fopenmp -O"$opt" "${objects[@]}" "$OUT/negative.o" -o "$OUT/negative"
  "$OUT/negative" > "$OUT/negative.txt" 2>&1 || { cat "$OUT/negative.txt" >&2; fail "restart negative O$opt"; }
  for marker in FMQ27_MALFORMED_CONCRETE_STATE_REJECTED=PASS FMQ27_LATE_RECORD_ATOMICITY=PASS FMQ27_REGISTERED_WRONG_FAMILY_REJECTED=PASS FMQ27_LATE_PROVENANCE_ATOMICITY=PASS FMQ27_FULL_NEGATIVE_MATRIX=PASS FMQ27_VALID_PRODUCTION_RESTORE=PASS; do
    grep -Fq "$marker" "$OUT/negative.txt" || fail "restart negative $marker O$opt"
  done
  grep -Fq 'FMR_RESTART_TARGET_ALREADY_INITIALIZED' src/runtime/mod_fmr_committed_restart.f90 || fail 'non-fresh target gate absent'

  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$BUILD/prior_parallel.f90" -o "$OUT/prior_parallel.o"
  gfortran -fopenmp -O"$opt" "${objects[@]}" "$OUT/prior_parallel.o" -o "$OUT/prior_parallel"
  "$OUT/prior_parallel" > "$OUT/prior_parallel.txt" 2>&1 || { cat "$OUT/prior_parallel.txt" >&2; fail "prior parallel O$opt"; }
  for marker in FMQ26_INPUT_ORDER_INDEPENDENCE=PASS FMQ26_REJECTION_AT_BATCH_BOUNDARY=PASS FMQ26_REJECTION_INTERIOR=PASS FMQ26_TWO_WORKER_SEPARATED_REJECTIONS=PASS FMQ26_UNSUPPORTED_PROFILES_FAIL_CLOSED=PASS FMQ26_TRUE_MULTIWORKER_OVERLAP_CONTROL=PASS FMQ26_HARD_MASS_ALL_CASES=PASS FMQ26_WORKER_COUNT_INDEPENDENCE=PASS FMQ26_DETERMINISTIC_REPLAY=PASS 'FMQ26_PARALLEL_V1_ADMISSION_TEST PASS'; do
    grep -Fq "$marker" "$OUT/prior_parallel.txt" || fail "parallel preservation $marker O$opt"
  done

  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$BUILD/prior_order.f90" -o "$OUT/prior_order.o"
  gfortran -fopenmp -O"$opt" "${objects[@]}" "$OUT/prior_order.o" -o "$OUT/prior_order"
  "$OUT/prior_order" > "$OUT/prior_order.txt" 2>&1 || { cat "$OUT/prior_order.txt" >&2; fail "prior publication O$opt"; }
  grep -Fq 'FMQ26_CANONICAL_PUBLICATION_ORDER=PASS' "$OUT/prior_order.txt" || fail "publication preservation O$opt"

  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$BUILD/heldout_restart.f90" -o "$OUT/heldout.o"
  gfortran -fopenmp -O"$opt" "${objects[@]}" "$OUT/heldout.o" -o "$OUT/heldout"
  "$OUT/heldout" > "$OUT/heldout.txt" 2>&1 || { cat "$OUT/heldout.txt" >&2; fail "heldout composition O$opt"; }
  for n in 3 5 9 16 23 33; do grep -Fq "FMQ29_HELDOUT_N${n}_" "$OUT/heldout.txt" || fail "heldout n=$n O$opt"; done
  for marker in FMQ29_SERIALIZED_ORIGIN_RESTART=PASS FMQ29_PARALLEL_2_ORIGIN_RESTART=PASS FMQ29_PARALLEL_4_ORIGIN_RESTART=PASS FMQ29_CROSS_WORKER_2_TO_4=PASS FMQ29_CROSS_WORKER_4_TO_2=PASS FMQ29_REVERSE_AND_INTERLEAVED_RECORD_ORDER=PASS FMQ29_INDEPENDENT_PARALLEL_RESTART_COMPOSITION=PASS; do
    grep -Fq "$marker" "$OUT/heldout.txt" || fail "heldout marker $marker O$opt"
  done
  echo "FMQ29_O${opt}=PASS"
done

cmp -s "$BUILD/o0/negative.txt" "$BUILD/o2/negative.txt" || fail 'restart negative O0/O2 mismatch'
cmp -s "$BUILD/o0/prior_parallel.txt" "$BUILD/o2/prior_parallel.txt" || fail 'parallel preservation O0/O2 mismatch'
cmp -s "$BUILD/o0/prior_order.txt" "$BUILD/o2/prior_order.txt" || fail 'publication preservation O0/O2 mismatch'
cmp -s "$BUILD/o0/heldout.txt" "$BUILD/o2/heldout.txt" || fail 'heldout composition O0/O2 mismatch'
echo 'FMQ29_O0_O2_EXACT_OUTPUT_IDENTITY=PASS'
echo 'FMQ29_HARD_MASS_CONSERVATION=PASS'
echo 'FMQ29_PRODUCTION_CHANGE=NONE'
echo 'FMQ29_DECISION=QUALIFIED_PARALLEL_COMMITTED_BOUNDARY_RESTART_COMPOSITION'
