#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fmq30-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

fail() { echo "FMQ30_GATE_FAIL $*" >&2; exit 30; }
BASE=8fa79a70a9faccaf8b63826df607a685eb75b046
OWNER=996038433690bb4c19f36774a633e485daa7f0db
CANDIDATE=6b9e47df37513705d3db13edc2c7035526c9c0de
CANDIDATE_BLOB=c78c13997642617376b8d118122c86c60ca77189
MATRIX_BLOB=26cc6e0ace986dc40db7635de7192958a1c0b868

# Qualification branch is current-canonical based. Only the immutable F-MR35
# production blob may be overlaid; no owner qualification harness is imported.
git merge-base --is-ancestor "$BASE" HEAD || fail 'qualification branch not descended from current canonical base'
mapfile -t src_delta < <(git diff --name-only "$BASE"..HEAD -- src)
[[ ${#src_delta[@]} -eq 1 && "${src_delta[0]}" == "src/runtime/mod_fmr_parallel_root_uptake_pool.f90" ]] || \
  fail "unexpected qualification source delta: ${src_delta[*]:-none}"
[[ "$(git rev-parse HEAD:src/runtime/mod_fmr_parallel_root_uptake_pool.f90)" == "$CANDIDATE_BLOB" ]] || \
  fail 'candidate root-active production blob drift'
if git cat-file -e "$BASE:src/runtime/mod_fmr_parallel_root_uptake_pool.f90" 2>/dev/null; then
  fail 'candidate capability unexpectedly present on canonical base'
fi
check_blob() {
  local path="$1" expected="$2" actual
  actual="$(git rev-parse "HEAD:$path")"
  [[ "$actual" == "$expected" ]] || fail "blob drift $path expected=$expected actual=$actual"
}
check_blob src/runtime/mod_fmr_parallel_worker_pool.f90 0e700797cbaed4aaab7f04db0054f72faddcfc15
check_blob src/runtime/mod_fmr_parallel_physical_scheduler.f90 544a1ca16fdeebdfce7f89d1ddf1825fa32fa654
check_blob src/runtime/mod_fmr_serialized_multiswap_runtime.f90 fe5a06c9af59308cdad86c5126379f413591b0cd
check_blob src/runtime/mod_fmr_serialized_reference_backend.f90 9af5a494526810324dc00706b444e448e770cba9
check_blob src/runtime/mod_fmr_reference_et_root_uptake_composition.f90 8ed7610144700f58d0b89482925471fcb2ff7d69
echo 'FMQ30_CURRENT_CANONICAL_SOURCE_LOCK=PASS'
echo 'FMQ30_EXACT_FMR35_CANDIDATE_BLOB=PASS'
echo 'FMQ30_OWNER_HARNESS_NOT_IMPORTED=PASS'
echo 'FMQ30_EXISTING_PARALLEL_V1_BYTE_PRESERVED=PASS'

python3 - <<'PY'
import json
from pathlib import Path
lock=json.loads(Path('integration/f-mq/F-MQ30_CANDIDATE_LOCK.json').read_text())
mat=json.loads(Path('integration/f-mq/F-MQ30_QUALIFICATION_MATRIX.json').read_text())
assert lock['canonical_source_authority']['head']=='8fa79a70a9faccaf8b63826df607a685eb75b046'
assert lock['owner_authority']['scientific_candidate']=='6b9e47df37513705d3db13edc2c7035526c9c0de'
assert lock['candidate_overlay']['blob']=='c78c13997642617376b8d118122c86c60ca77189'
assert mat['held_out_positive_cases']==[
 {'n':3,'batch':2,'order':3},{'n':5,'batch':4,'order':1},{'n':9,'batch':5,'order':2},
 {'n':16,'batch':7,'order':0},{'n':23,'batch':11,'order':3},{'n':33,'batch':17,'order':1}]
assert mat['hard_mass_gate_cm']==1e-12
print('FMQ30_PERSISTED_MATRIX_LOCK=PASS')
PY

# Structural audit of the exact candidate. It must be an explicit root-active
# capability using worker-owned backend/transaction scratch and the already
# admitted per-column transaction executor.
python3 - <<'PY'
from pathlib import Path
p=Path('src/runtime/mod_fmr_parallel_root_uptake_pool.f90').read_text().lower()
old=Path('src/runtime/mod_fmr_parallel_worker_pool.f90').read_text().lower()
assert 'public :: fmr_run_parallel_root_uptake_multiswap' in p
assert '.not. parameter_registry(parameter_index)%root_extraction_active' in p
assert 'if (any(.not. ieee_is_finite(forcing_registry(forcing_index)%root_extraction_sink))) return' in p
assert 'if (any(forcing_registry(forcing_index)%root_extraction_sink < 0.0_real64)) return' in p
assert p.index('ieee_is_finite(forcing_registry(forcing_index)%root_extraction_sink)') < p.index('root_extraction_sink < 0.0_real64')
assert 'allocate(backends(worker_count), transaction_controls(worker_count), worker_runtime(worker_count))' in p
assert 'fmr_execute_serialized_physical_column' in p
assert 'call canonicalize_publication(columns, results, diagnostics)' in p
assert 'parameter_registry(parameter_index)%root_extraction_active .or.' in old
print('FMQ30_EXPLICIT_DISTINCT_ROOT_ACTIVE_CAPABILITY=PASS')
print('FMQ30_NONFINITE_CHECK_PRECEDES_SIGN_CHECK=PASS')
print('FMQ30_WORKER_OWNED_HEAVY_RUNTIME=PASS')
print('FMQ30_OLD_V1_STILL_ROOT_INACTIVE=PASS')
PY

# Rehydrate an immutable prior-independent real-physics scaffold. The new
# root-active attack is derived here with held-out sizes and new oracles; no
# F-MR35-generated root-active fixture is read.
git cat-file blob "$MATRIX_BLOB" > "$BUILD/v1_regression.f90"
[[ "$(git hash-object "$BUILD/v1_regression.f90")" == "$MATRIX_BLOB" ]] || fail 'neutral scaffold blob mismatch'
cp "$BUILD/v1_regression.f90" "$BUILD/root_attack.f90"
python3 - "$BUILD/root_attack.f90" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); s=p.read_text()

def one(old,new,label):
    global s
    n=s.count(old)
    if n != 1: raise SystemExit(f'{label}: expected 1 token, got {n}')
    s=s.replace(old,new,1)

one('program test_fmq26_parallel_v1_admission','program test_fmq30_parallel_root_uptake','program')
one('end program test_fmq26_parallel_v1_admission','end program test_fmq30_parallel_root_uptake','end program')
one('  use, intrinsic :: iso_fortran_env, only: int64, real64\n',
    '  use, intrinsic :: iso_fortran_env, only: int64, real64\n  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan\n','ieee import')
one('  use mod_fmr_parallel_worker_pool, only: fmr_run_parallel_physical_multiswap, FMR_PARALLEL_POOL_OK, &\n       FMR_PARALLEL_POOL_MULTIWORKER_NOT_ADMITTED\n',
    '  use mod_fmr_parallel_root_uptake_pool, only: fmr_run_parallel_root_uptake_multiswap, FMR_PARALLEL_ROOT_POOL_OK, &\n       FMR_PARALLEL_ROOT_POOL_PROFILE_NOT_ADMITTED\n','root pool import')
s=s.replace('fmr_run_parallel_physical_multiswap','fmr_run_parallel_root_uptake_multiswap')
s=s.replace('FMR_PARALLEL_POOL_MULTIWORKER_NOT_ADMITTED','FMR_PARALLEL_ROOT_POOL_PROFILE_NOT_ADMITTED')
s=s.replace('FMR_PARALLEL_POOL_OK','FMR_PARALLEL_ROOT_POOL_OK')

# Held-out positive matrix.
one('  integer, parameter :: ncases = 14\n  integer, parameter :: case_n(ncases) = [2,2,7,7,7,8,8,17,17,31,31,32,32,32]\n  integer, parameter :: case_batch(ncases) = [1,2,2,3,7,3,5,4,9,7,16,8,9,17]\n',
    '  integer, parameter :: ncases = 6\n  integer, parameter :: case_n(ncases) = [3,5,9,16,23,33]\n  integer, parameter :: case_batch(ncases) = [2,4,5,7,11,17]\n  integer, parameter :: case_order(ncases) = [3,1,2,0,3,1]\n','held-out matrix')
one('    call run_positive_case(case_n(k), case_batch(k), mod(k-1,4))\n    write(*,\'(A,I0,A,I0,A,I0,A)\') \'FMQ26_POSITIVE_N\',case_n(k),\'_B\',case_batch(k),\'_O\',mod(k-1,4),\'=PASS\'\n',
    '    call run_positive_case(case_n(k), case_batch(k), case_order(k))\n    write(*,\'(A,I0,A,I0,A,I0,A)\') \'FMQ30_POSITIVE_N\',case_n(k),\'_B\',case_batch(k),\'_O\',case_order(k),\'=PASS\'\n','held-out call')

# Root-active profile with a distinct sink pattern. Add the same amount to the
# subsurface source so the hydraulic state remains a demanding exact oracle
# while QROT is still physically booked and independently attributed.
one('    value%root_extraction_active=.false.; value%macropore_active=.false.; value%snow_active=.false.\n',
    '    value%root_extraction_active=.true.; value%macropore_active=.false.; value%snow_active=.false.\n','root active')
one('      forcing%root_extraction_sink(j)=0.0_real64\n',
    '      forcing%root_extraction_sink(j)=scale*4.0e-6_real64*real(numnod-j+2,real64)\n      forcing%subsurface_irrigation_source(j)=forcing%subsurface_irrigation_source(j)+forcing%root_extraction_sink(j)\n','root forcing')
one('    end do\n  end subroutine build_fixture\n',
    '    end do\n    ! A true root-active zero-QROT case is valid and must retain available zero attribution.\n    forcings(1)%subsurface_irrigation_source = forcings(1)%subsurface_irrigation_source - forcings(1)%root_extraction_sink\n    forcings(1)%root_extraction_sink = 0.0_real64\n  end subroutine build_fixture\n','active zero')

# Exact attribution is part of scientific identity, not merely metadata.
one("    call require(max_abs_residual(r_serial) <= hard_mass_gate, 'serialized hard mass')\n",
    "    call require(max_abs_residual(r_serial) <= hard_mass_gate, 'serialized hard mass')\n    call require_exact_attribution(r_serial,columns,forcings)\n",'serial attribution')
one("    call require(all_committed(r2a) .and. max_abs_residual(r2a) <= hard_mass_gate, '2 worker mass/commit')\n",
    "    call require(all_committed(r2a) .and. max_abs_residual(r2a) <= hard_mass_gate, '2 worker mass/commit')\n    call require_exact_attribution(r2a,columns,forcings)\n",'2w attribution')
one("    call require(all_committed(r4) .and. max_abs_residual(r4) <= hard_mass_gate, '4 worker mass/commit')\n",
    "    call require(all_committed(r4) .and. max_abs_residual(r4) <= hard_mass_gate, '4 worker mass/commit')\n    call require_exact_attribution(r4,columns,forcings)\n",'4w attribution')
one("    call require(pool_status == FMR_PARALLEL_ROOT_POOL_OK, '2 worker replay status')\n",
    "    call require(pool_status == FMR_PARALLEL_ROOT_POOL_OK, '2 worker replay status')\n    call require_exact_attribution(r2b,columns,forcings)\n",'replay attribution')
one('      same_bits(left%final_committed_time,right%final_committed_time) .and. &\n      (left%final_committed_time_bound.eqv.right%final_committed_time_bound) .and. mass_identical(left%mass,right%mass)\n',
    '      same_bits(left%final_committed_time,right%final_committed_time) .and. &\n      (left%final_committed_time_bound.eqv.right%final_committed_time_bound) .and. &\n      (left%actual_transpiration_available.eqv.right%actual_transpiration_available) .and. &\n      same_bits(left%actual_transpiration_amount,right%actual_transpiration_amount) .and. mass_identical(left%mass,right%mass)\n','result attribution identity')

# Independent order/isolation sizes.
s=s.replace('call run_order_independence_case(17, 4)','call run_order_independence_case(13, 5)',1)
s=s.replace('call run_rejection_isolation_case(17, 4, [4], 4)','call run_rejection_isolation_case(19, 6, [6], 4)',1)
s=s.replace('call run_rejection_isolation_case(17, 9, [7], 4)','call run_rejection_isolation_case(19, 10, [7], 4)',1)
s=s.replace('call run_rejection_isolation_case(31, 7, [3,4], 4)','call run_rejection_isolation_case(29, 8, [3,4], 4)',1)
s=s.replace('call build_fixture(32,columns,templates,parameters,forcings,seed,conductivity0)','call build_fixture(33,columns,templates,parameters,forcings,seed,conductivity0)',1)
s=s.replace('t0,t1,17,workers, &','t0,t1,18,workers, &',1)

# The explicit root-active entry point has its own unsupported matrix.
one('        case(1)\n          bad_parameters(1)%root_extraction_active = .true.\n',
    '        case(1)\n          bad_parameters(1)%root_extraction_active = .false.\n','root inactive negative')
one('    do mode = 1, 5\n', '    do mode = 1, 9\n','unsupported modes')
one('        case(5)\n          bad_parameters(1)%macropore_active = .true.\n',
    '        case(5)\n          bad_parameters(1)%macropore_active = .true.\n        case(6)\n          bad_parameters(1)%frost_active = .true.\n        case(7)\n          bad_parameters(1)%hysteresis_active = .true.\n        case(8)\n          bad_parameters(1)%tabulated_hydraulics_active = .true.\n        case(9)\n          bad_parameters(1)%elasticity_active = .true.\n','extra unsupported modes')

# New hard-negative and publication oracles.
one("  call run_unsupported_profile_matrix()\n  write(*,'(A)') 'FMQ26_UNSUPPORTED_PROFILES_FAIL_CLOSED=PASS'\n",
    "  call run_unsupported_profile_matrix()\n  write(*,'(A)') 'FMQ30_UNSUPPORTED_PROFILES_FAIL_CLOSED=PASS'\n  call run_invalid_root_forcing_matrix()\n  write(*,'(A)') 'FMQ30_NEGATIVE_AND_NAN_QROT_FAIL_PRE_SOLVE=PASS'\n  call run_worker_count_rejections()\n  write(*,'(A)') 'FMQ30_WORKER_COUNT_SCOPE_FAIL_CLOSED=PASS'\n  call run_canonical_publication_case()\n  write(*,'(A)') 'FMQ30_CANONICAL_PUBLICATION_ORDER=PASS'\n",'new oracle calls')

needle='  subroutine run_overlap_control()\n'
if needle not in s: raise SystemExit('helper insertion point missing')
helpers=r'''  subroutine run_invalid_root_forcing_matrix()
    type(fmr_logical_column_t), allocatable :: columns(:)
    type(fmr_template_t) :: templates(1)
    type(fmr_b110_physical_parameters_t) :: parameters(1)
    type(fmr_b110_physical_forcing_t), allocatable :: forcings(:), bad_forcings(:)
    type(fmr_b110_physical_state_t) :: seed
    type(kernel_committed_state_t), allocatable :: states(:), initial(:)
    type(fmr_serialized_column_result_t), allocatable :: results(:)
    type(fmr_column_diagnostics_t), allocatable :: diagnostics(:)
    type(fmr_aggregate_diagnostics_t) :: aggregate
    type(fmr_serialized_batch_diagnostics_t) :: runtime
    type(fixed_flux_top_boundary_provider_t), target :: top_provider
    type(canonical_numerical_config_t) :: config
    real(real64) :: conductivity0
    integer :: mode, workers, dispatch_status, pool_status
    call build_fixture(9,columns,templates,parameters,forcings,seed,conductivity0)
    call configure_transaction(config)
    do mode=1,2
      do workers=2,4,2
        bad_forcings=forcings
        if (mode == 1) then
          bad_forcings(4)%root_extraction_sink(1)=-1.0e-9_real64
        else
          bad_forcings(4)%root_extraction_sink(1)=ieee_value(0.0_real64,ieee_quiet_nan)
        end if
        call initialize_states(states,columns,seed)
        call initialize_states(initial,columns,seed)
        call fmr_run_parallel_root_uptake_multiswap(columns,templates,parameters,bad_forcings,states,config,top_provider,t0,t1,5,workers, &
             results,diagnostics,aggregate,dispatch_status,pool_status,runtime)
        call require(pool_status == FMR_PARALLEL_ROOT_POOL_PROFILE_NOT_ADMITTED, 'invalid QROT profile status')
        call require(dispatch_status == -1, 'invalid QROT no fallback')
        call require(runtime%physical_solve_count == 0 .and. runtime%number_committed == 0, 'invalid QROT zero solves')
        call require(all_no_solver_execution(results), 'invalid QROT solver not executed')
        call require(states_identical(states,initial), 'invalid QROT state nonmutation')
      end do
    end do
  end subroutine run_invalid_root_forcing_matrix

  subroutine run_worker_count_rejections()
    type(fmr_logical_column_t), allocatable :: columns(:)
    type(fmr_template_t) :: templates(1)
    type(fmr_b110_physical_parameters_t) :: parameters(1)
    type(fmr_b110_physical_forcing_t), allocatable :: forcings(:)
    type(fmr_b110_physical_state_t) :: seed
    type(kernel_committed_state_t), allocatable :: states(:), initial(:)
    type(fmr_serialized_column_result_t), allocatable :: results(:)
    type(fmr_column_diagnostics_t), allocatable :: diagnostics(:)
    type(fmr_aggregate_diagnostics_t) :: aggregate
    type(fmr_serialized_batch_diagnostics_t) :: runtime
    type(fixed_flux_top_boundary_provider_t), target :: top_provider
    type(canonical_numerical_config_t) :: config
    real(real64) :: conductivity0
    integer :: workers, dispatch_status, pool_status
    call build_fixture(9,columns,templates,parameters,forcings,seed,conductivity0)
    call configure_transaction(config)
    do workers=1,3,2
      call initialize_states(states,columns,seed)
      call initialize_states(initial,columns,seed)
      call fmr_run_parallel_root_uptake_multiswap(columns,templates,parameters,forcings,states,config,top_provider,t0,t1,5,workers, &
           results,diagnostics,aggregate,dispatch_status,pool_status,runtime)
      call require(pool_status == FMR_PARALLEL_ROOT_POOL_PROFILE_NOT_ADMITTED, 'unsupported worker count status')
      call require(dispatch_status == -1, 'unsupported worker count no serialized fallback')
      call require(runtime%physical_solve_count == 0 .and. runtime%number_committed == 0, 'unsupported worker count zero solves')
      call require(states_identical(states,initial), 'unsupported worker count nonmutation')
    end do
  end subroutine run_worker_count_rejections

  subroutine run_canonical_publication_case()
    type(fmr_logical_column_t), allocatable :: base(:), columns(:)
    type(fmr_template_t) :: templates(1)
    type(fmr_b110_physical_parameters_t) :: parameters(1)
    type(fmr_b110_physical_forcing_t), allocatable :: forcings(:)
    type(fmr_b110_physical_state_t) :: seed
    type(kernel_committed_state_t), allocatable :: states(:)
    type(fmr_serialized_column_result_t), allocatable :: results(:)
    type(fmr_column_diagnostics_t), allocatable :: diagnostics(:)
    type(fmr_aggregate_diagnostics_t) :: aggregate
    type(fmr_serialized_batch_diagnostics_t) :: runtime
    type(fixed_flux_top_boundary_provider_t), target :: top_provider
    type(canonical_numerical_config_t) :: config
    real(real64) :: conductivity0
    integer :: i, dispatch_status, pool_status
    call build_fixture(9,base,templates,parameters,forcings,seed,conductivity0)
    call permute_columns(base,1,columns)
    call configure_transaction(config)
    call initialize_states(states,base,seed)
    call fmr_run_parallel_root_uptake_multiswap(columns,templates,parameters,forcings,states,config,top_provider,t0,t1,5,4, &
         results,diagnostics,aggregate,dispatch_status,pool_status,runtime)
    call require(pool_status == FMR_PARALLEL_ROOT_POOL_OK .and. dispatch_status == FMR_SERIAL_DISPATCH_OK, 'canonical publication status')
    do i=2,size(results)
      call require(results(i-1)%column_id < results(i)%column_id, 'result canonical order')
      call require(diagnostics(i-1)%column_id < diagnostics(i)%column_id, 'diagnostic canonical order')
    end do
  end subroutine run_canonical_publication_case

  subroutine require_exact_attribution(results,columns,forcings)
    type(fmr_serialized_column_result_t), intent(in) :: results(:)
    type(fmr_logical_column_t), intent(in) :: columns(:)
    type(fmr_b110_physical_forcing_t), intent(in) :: forcings(:)
    integer :: i, idx, forcing_index
    real(real64) :: expected, summed_mass_out
    summed_mass_out=0.0_real64
    do i=1,size(columns)
      idx=find_result_index(results,columns(i)%column_id)
      call require(idx > 0,'attribution id lookup')
      forcing_index=int(columns(i)%forcing_handle)
      expected=sum(forcings(forcing_index)%root_extraction_sink)*(t1-t0)
      call require(results(idx)%actual_transpiration_available,'root-active attribution available')
      call require(same_bits(results(idx)%actual_transpiration_amount,expected),'exact QROT integral attribution')
      summed_mass_out=summed_mass_out+results(idx)%mass%total_out
    end do
  end subroutine require_exact_attribution

'''
s=s.replace(needle,helpers+needle,1)

# Rename remaining output markers so O0/O2 comparison is F-MQ30-specific.
s=s.replace('FMQ26_','FMQ30_ROOT_')
p.write_text(s)
PY

echo 'FMQ30_INDEPENDENT_ROOT_ATTACK_DERIVATION=PASS'

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow -fopenmp)
MODULE_SRC=(
  tests/fsi/fsi04_real_headcalc_stubs.f90
  src/runtime/mod_a23bu_worker_execution_context.f90
  src/transaction/mod_transaction_reference.f90
  src/transaction/mod_fkt_temporal_indicator_history.f90
  src/runtime/mod_canonical_contracts.f90
  src/runtime/mod_canonical_interval_runtime.f90
  src/kernel/mod_kernel_transactions.f90
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
  src/runtime/mod_fmr_parallel_physical_scheduler.f90
  src/runtime/mod_fmr_parallel_worker_pool.f90
  src/runtime/mod_fmr_parallel_root_uptake_pool.f90
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

  # Frozen prior independent V1 matrix proves the additive candidate did not
  # mutate the existing root-inactive API; it must still reject root-active.
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$BUILD/v1_regression.f90" -o "$OUT/v1.o"
  gfortran -fopenmp -O"$opt" "${objects[@]}" "$OUT/v1.o" -o "$OUT/v1"
  "$OUT/v1" > "$OUT/v1.txt" 2>&1 || { cat "$OUT/v1.txt" >&2; fail "V1 regression O$opt"; }
  for marker in FMQ26_INPUT_ORDER_INDEPENDENCE=PASS FMQ26_UNSUPPORTED_PROFILES_FAIL_CLOSED=PASS FMQ26_TRUE_MULTIWORKER_OVERLAP_CONTROL=PASS FMQ26_HARD_MASS_ALL_CASES=PASS FMQ26_WORKER_COUNT_INDEPENDENCE=PASS FMQ26_DETERMINISTIC_REPLAY=PASS 'FMQ26_PARALLEL_V1_ADMISSION_TEST PASS'; do
    grep -Fq "$marker" "$OUT/v1.txt" || fail "missing V1 marker O$opt: $marker"
  done

  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$BUILD/root_attack.f90" -o "$OUT/root.o"
  gfortran -fopenmp -O"$opt" "${objects[@]}" "$OUT/root.o" -o "$OUT/root"
  "$OUT/root" > "$OUT/root.txt" 2>&1 || { cat "$OUT/root.txt" >&2; fail "root attack O$opt"; }
  while read -r n b o; do
    grep -Fq "FMQ30_POSITIVE_N${n}_B${b}_O${o}=PASS" "$OUT/root.txt" || fail "held-out positive n=$n b=$b order=$o O$opt"
  done <<'CASES'
3 2 3
5 4 1
9 5 2
16 7 0
23 11 3
33 17 1
CASES
  for marker in \
    FMQ30_ROOT_INPUT_ORDER_INDEPENDENCE=PASS \
    FMQ30_ROOT_REJECTION_AT_BATCH_BOUNDARY=PASS \
    FMQ30_ROOT_REJECTION_INTERIOR=PASS \
    FMQ30_ROOT_TWO_WORKER_SEPARATED_REJECTIONS=PASS \
    FMQ30_UNSUPPORTED_PROFILES_FAIL_CLOSED=PASS \
    FMQ30_NEGATIVE_AND_NAN_QROT_FAIL_PRE_SOLVE=PASS \
    FMQ30_WORKER_COUNT_SCOPE_FAIL_CLOSED=PASS \
    FMQ30_CANONICAL_PUBLICATION_ORDER=PASS \
    FMQ30_ROOT_TRUE_MULTIWORKER_OVERLAP_CONTROL=PASS \
    FMQ30_ROOT_HARD_MASS_ALL_CASES=PASS \
    FMQ30_ROOT_WORKER_COUNT_INDEPENDENCE=PASS \
    FMQ30_ROOT_DETERMINISTIC_REPLAY=PASS \
    'FMQ30_ROOT_PARALLEL_V1_ADMISSION_TEST PASS'; do
    grep -Fq "$marker" "$OUT/root.txt" || fail "missing root marker O$opt: $marker"
  done
  echo "FMQ30_O${opt}=PASS"
done

cmp -s "$BUILD/o0/v1.txt" "$BUILD/o2/v1.txt" || { diff -u "$BUILD/o0/v1.txt" "$BUILD/o2/v1.txt" >&2 || true; fail 'V1 O0/O2 identity'; }
cmp -s "$BUILD/o0/root.txt" "$BUILD/o2/root.txt" || { diff -u "$BUILD/o0/root.txt" "$BUILD/o2/root.txt" >&2 || true; fail 'root O0/O2 identity'; }
echo 'FMQ30_O0_O2_EXACT_OUTPUT_IDENTITY=PASS'
echo 'FMQ30_HARD_MASS_CONSERVATION=PASS'
echo 'FMQ30_PRODUCTION_CHANGE=NONE'
echo 'FMQ30_DECISION=QUALIFIED_IF_WORKFLOW_GREEN'
