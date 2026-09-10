#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fmr35-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

fail() { echo "FMR35_GATE_FAIL $*" >&2; exit 35; }
BASE=c0fc660c1e68064f77f4ec4f3376d385fbe88b4a
CANDIDATE=040e34dfb169058932583431052e471dd10bd8cc
MATRIX_BLOB=26cc6e0ace986dc40db7635de7192958a1c0b868

# Source authority and production-scope lock.
git merge-base --is-ancestor "$BASE" "$CANDIDATE" || fail 'candidate is not descended from canonical source authority'
git merge-base --is-ancestor "$CANDIDATE" HEAD || fail 'HEAD is not descended from exact structural candidate'
mapfile -t src_delta < <(git diff --name-only "$BASE".."$CANDIDATE" -- src)
[[ ${#src_delta[@]} -eq 1 && "${src_delta[0]}" == "src/runtime/mod_fmr_parallel_root_uptake_pool.f90" ]] || \
  fail "unexpected candidate production scope: ${src_delta[*]:-none}"
git diff --quiet "$CANDIDATE"..HEAD -- src || fail 'production source changed after exact structural candidate'
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
echo 'FMR35_SOURCE_LOCK=PASS'
echo 'FMR35_PRODUCTION_DELTA_NEW_EXPLICIT_CAPABILITY_ONLY=PASS'
echo 'FMR35_EXISTING_PARALLEL_V1_BYTE_PRESERVED=PASS'

python3 - <<'PY'
from pathlib import Path
p=Path('src/runtime/mod_fmr_parallel_root_uptake_pool.f90').read_text().lower()
assert 'public :: fmr_run_parallel_root_uptake_multiswap' in p
assert '.not. parameter_registry(parameter_index)%root_extraction_active' in p
assert 'any(forcing_registry(forcing_index)%root_extraction_sink < 0.0_real64)' in p
assert 'fmr_execute_serialized_physical_column' in p
assert 'allocate(backends(worker_count), transaction_controls(worker_count), worker_runtime(worker_count))' in p
assert 'call canonicalize_publication(columns, results, diagnostics)' in p
old=Path('src/runtime/mod_fmr_parallel_worker_pool.f90').read_text().lower()
assert 'parameter_registry(parameter_index)%root_extraction_active .or.' in old
print('FMR35_EXPLICIT_ROOT_ACTIVE_PROFILE=PASS')
print('FMR35_WORKER_OWNED_BACKEND_TRANSACTION_SCRATCH=PASS')
print('FMR35_OLD_V1_REMAINS_ROOT_INACTIVE=PASS')
PY

# Immutable prior real-physics parallel fixture: first replay unchanged for regression preservation.
git cat-file blob "$MATRIX_BLOB" > "$BUILD/v1_preservation.f90"
[[ "$(git hash-object "$BUILD/v1_preservation.f90")" == "$MATRIX_BLOB" ]] || fail 'immutable V1 matrix blob mismatch'
cp "$BUILD/v1_preservation.f90" "$BUILD/root_active.f90"

# Deterministically derive a root-active attack fixture without importing owner conclusions.
python3 - "$BUILD/root_active.f90" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); s=p.read_text()

def one(old,new,label):
    global s
    n=s.count(old)
    if n != 1: raise SystemExit(f'{label}: expected 1 token, got {n}')
    s=s.replace(old,new,1)

one('program test_fmq26_parallel_v1_admission','program test_fmr35_parallel_root_uptake','program')
one('end program test_fmq26_parallel_v1_admission','end program test_fmr35_parallel_root_uptake','end program')
one('  use, intrinsic :: iso_fortran_env, only: int64, real64\n',
    '  use, intrinsic :: iso_fortran_env, only: int64, real64\n  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan\n','ieee import')
one('  use mod_fmr_parallel_worker_pool, only: fmr_run_parallel_physical_multiswap, FMR_PARALLEL_POOL_OK, &\n       FMR_PARALLEL_POOL_MULTIWORKER_NOT_ADMITTED\n',
    '  use mod_fmr_parallel_root_uptake_pool, only: fmr_run_parallel_root_uptake_multiswap, FMR_PARALLEL_ROOT_POOL_OK, &\n       FMR_PARALLEL_ROOT_POOL_PROFILE_NOT_ADMITTED\n','parallel import')
s=s.replace('fmr_run_parallel_physical_multiswap','fmr_run_parallel_root_uptake_multiswap')
s=s.replace('FMR_PARALLEL_POOL_MULTIWORKER_NOT_ADMITTED','FMR_PARALLEL_ROOT_POOL_PROFILE_NOT_ADMITTED')
s=s.replace('FMR_PARALLEL_POOL_OK','FMR_PARALLEL_ROOT_POOL_OK')
one('    value%root_extraction_active=.false.; value%macropore_active=.false.; value%snow_active=.false.\n',
    '    value%root_extraction_active=.true.; value%macropore_active=.false.; value%snow_active=.false.\n','root active parameter')
one('      forcing%root_extraction_sink(j)=0.0_real64\n',
    '      forcing%root_extraction_sink(j)=scale*3.0e-6_real64*real(j+2,real64)\n      forcing%subsurface_irrigation_source(j)=forcing%subsurface_irrigation_source(j)+forcing%root_extraction_sink(j)\n','root forcing')
one('    end do\n  end subroutine build_fixture\n',
    '    end do\n    ! Active-zero QROT is a valid root-active case and must still publish available zero transpiration.\n    forcings(1)%subsurface_irrigation_source = forcings(1)%subsurface_irrigation_source - forcings(1)%root_extraction_sink\n    forcings(1)%root_extraction_sink = 0.0_real64\n  end subroutine build_fixture\n','active zero fixture')
one('        case(1)\n          bad_parameters(1)%root_extraction_active = .true.\n',
    '        case(1)\n          bad_parameters(1)%root_extraction_active = .false.\n','root inactive negative profile')
one("  call run_unsupported_profile_matrix()\n  write(*,'(A)') 'FMQ26_UNSUPPORTED_PROFILES_FAIL_CLOSED=PASS'\n",
    "  call run_unsupported_profile_matrix()\n  write(*,'(A)') 'FMQ26_UNSUPPORTED_PROFILES_FAIL_CLOSED=PASS'\n  call run_invalid_root_forcing_matrix()\n  write(*,'(A)') 'FMQ26_INVALID_ROOT_FORCING_FAILS_PRE_SOLVE=PASS'\n",'invalid forcing call')
# Exact postcommit attribution must equal the forcing handle integral for every successful route.
one("    call require(max_abs_residual(r_serial) <= hard_mass_gate, 'serialized hard mass')\n",
    "    call require(max_abs_residual(r_serial) <= hard_mass_gate, 'serialized hard mass')\n    call require_exact_attribution(r_serial,columns,forcings)\n",'serial attribution')
one("    call require(all_committed(r2a) .and. max_abs_residual(r2a) <= hard_mass_gate, '2 worker mass/commit')\n",
    "    call require(all_committed(r2a) .and. max_abs_residual(r2a) <= hard_mass_gate, '2 worker mass/commit')\n    call require_exact_attribution(r2a,columns,forcings)\n",'2w attribution')
one("    call require(all_committed(r4) .and. max_abs_residual(r4) <= hard_mass_gate, '4 worker mass/commit')\n",
    "    call require(all_committed(r4) .and. max_abs_residual(r4) <= hard_mass_gate, '4 worker mass/commit')\n    call require_exact_attribution(r4,columns,forcings)\n",'4w attribution')
one("    call require(pool_status == FMR_PARALLEL_ROOT_POOL_OK, '2 worker replay status')\n",
    "    call require(pool_status == FMR_PARALLEL_ROOT_POOL_OK, '2 worker replay status')\n    call require_exact_attribution(r2b,columns,forcings)\n",'2w replay attribution')
# Include actual-transpiration publication in bitwise result identity.
one('      same_bits(left%final_committed_time,right%final_committed_time) .and. &\n      (left%final_committed_time_bound.eqv.right%final_committed_time_bound) .and. mass_identical(left%mass,right%mass)\n',
    '      same_bits(left%final_committed_time,right%final_committed_time) .and. &\n      (left%final_committed_time_bound.eqv.right%final_committed_time_bound) .and. &\n      (left%actual_transpiration_available.eqv.right%actual_transpiration_available) .and. &\n      same_bits(left%actual_transpiration_amount,right%actual_transpiration_amount) .and. mass_identical(left%mass,right%mass)\n','attribution result identity')
# Root-specific helpers.
needle='  subroutine run_overlap_control()\n'
if needle not in s: raise SystemExit('missing overlap insertion point')
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

    call build_fixture(7,columns,templates,parameters,forcings,seed,conductivity0)
    call configure_transaction(config)
    do mode=1,2
      do workers=2,4,2
        bad_forcings=forcings
        if (mode == 1) then
          bad_forcings(3)%root_extraction_sink(1)=-1.0e-8_real64
        else
          bad_forcings(3)%root_extraction_sink(1)=ieee_value(0.0_real64,ieee_quiet_nan)
        end if
        call initialize_states(states,columns,seed)
        call initialize_states(initial,columns,seed)
        call fmr_run_parallel_root_uptake_multiswap(columns,templates,parameters,bad_forcings,states,config,top_provider,t0,t1,3,workers, &
             results,diagnostics,aggregate,dispatch_status,pool_status,runtime)
        call require(pool_status == FMR_PARALLEL_ROOT_POOL_PROFILE_NOT_ADMITTED, 'invalid root forcing profile status')
        call require(dispatch_status == -1, 'invalid root forcing no fallback')
        call require(runtime%physical_solve_count == 0 .and. runtime%number_committed == 0, 'invalid root forcing zero physical solves')
        call require(all_no_solver_execution(results), 'invalid root forcing solver not executed')
        call require(states_identical(states,initial), 'invalid root forcing nonmutation')
      end do
    end do
  end subroutine run_invalid_root_forcing_matrix

  subroutine require_exact_attribution(results,columns,forcings)
    type(fmr_serialized_column_result_t), intent(in) :: results(:)
    type(fmr_logical_column_t), intent(in) :: columns(:)
    type(fmr_b110_physical_forcing_t), intent(in) :: forcings(:)
    integer :: i, idx, forcing_index
    real(real64) :: expected
    do i=1,size(columns)
      idx=find_result_index(results,columns(i)%column_id)
      call require(idx > 0,'attribution column lookup')
      forcing_index=int(columns(i)%forcing_handle)
      expected=sum(forcings(forcing_index)%root_extraction_sink)*(t1-t0)
      call require(results(idx)%actual_transpiration_available,'active root attribution available')
      call require(same_bits(results(idx)%actual_transpiration_amount,expected),'exact forcing-bound transpiration amount')
    end do
  end subroutine require_exact_attribution

'''
s=s.replace(needle,helpers+needle,1)
s=s.replace('FMQ26_','FMR35_ROOT_')
p.write_text(s)
PY

echo 'FMR35_ROOT_ACTIVE_FIXTURE_DERIVATION=PASS'

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

  # Existing root-inactive V1 remains behavior-compatible and keeps root-active requests unsupported there.
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$BUILD/v1_preservation.f90" -o "$OUT/v1.o"
  gfortran -fopenmp -O"$opt" "${objects[@]}" "$OUT/v1.o" -o "$OUT/v1"
  "$OUT/v1" > "$OUT/v1.txt" 2>&1 || { cat "$OUT/v1.txt" >&2; fail "old V1 preservation O$opt"; }
  for marker in FMQ26_INPUT_ORDER_INDEPENDENCE=PASS FMQ26_UNSUPPORTED_PROFILES_FAIL_CLOSED=PASS FMQ26_TRUE_MULTIWORKER_OVERLAP_CONTROL=PASS FMQ26_HARD_MASS_ALL_CASES=PASS FMQ26_WORKER_COUNT_INDEPENDENCE=PASS FMQ26_DETERMINISTIC_REPLAY=PASS 'FMQ26_PARALLEL_V1_ADMISSION_TEST PASS'; do
    grep -Fq "$marker" "$OUT/v1.txt" || fail "old V1 marker $marker O$opt"
  done

  # New explicitly named root-active parallel capability.
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$BUILD/root_active.f90" -o "$OUT/root.o"
  gfortran -fopenmp -O"$opt" "${objects[@]}" "$OUT/root.o" -o "$OUT/root"
  "$OUT/root" > "$OUT/root.txt" 2>&1 || { cat "$OUT/root.txt" >&2; fail "root-active O$opt"; }
  for n in 2 7 8 17 31 32; do grep -Fq "FMR35_ROOT_POSITIVE_N${n}_" "$OUT/root.txt" || fail "root positive n=$n O$opt"; done
  for marker in FMR35_ROOT_INPUT_ORDER_INDEPENDENCE=PASS FMR35_ROOT_REJECTION_AT_BATCH_BOUNDARY=PASS FMR35_ROOT_REJECTION_INTERIOR=PASS FMR35_ROOT_TWO_WORKER_SEPARATED_REJECTIONS=PASS FMR35_ROOT_UNSUPPORTED_PROFILES_FAIL_CLOSED=PASS FMR35_ROOT_INVALID_ROOT_FORCING_FAILS_PRE_SOLVE=PASS FMR35_ROOT_TRUE_MULTIWORKER_OVERLAP_CONTROL=PASS FMR35_ROOT_HARD_MASS_ALL_CASES=PASS FMR35_ROOT_WORKER_COUNT_INDEPENDENCE=PASS FMR35_ROOT_DETERMINISTIC_REPLAY=PASS; do
    grep -Fq "$marker" "$OUT/root.txt" || fail "root marker $marker O$opt"
  done
  echo "FMR35_O${opt}=PASS"
done

cmp -s "$BUILD/o0/v1.txt" "$BUILD/o2/v1.txt" || fail 'old V1 O0/O2 output identity'
cmp -s "$BUILD/o0/root.txt" "$BUILD/o2/root.txt" || fail 'root-active O0/O2 output identity'
echo 'FMR35_O0_O2_EXACT_OUTPUT_IDENTITY=PASS'
echo 'FMR35_SERIALIZED_2W_4W_ROOT_STATE_MASS_ATTRIBUTION_IDENTITY=PASS'
echo 'FMR35_NEGATIVE_AND_NAN_QROT_FAIL_PRE_SOLVE=PASS'
echo 'FMR35_ACTIVE_ZERO_QROT_ATTRIBUTION=PASS'
echo 'FMR35_MASS_CONSERVATION_HARD_GATE=PASS'
echo 'FMR35_EXISTING_V1_REGRESSION=NONE_OBSERVED'
echo 'FMR35_DECISION=OWNER_GATE_PASS'
