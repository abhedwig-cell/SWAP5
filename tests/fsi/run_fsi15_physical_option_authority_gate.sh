#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
FSI14_HEAD="d1b1553805ce11f235ac2565381c1ac31739b1f4"
BUILD="${TMPDIR:-/tmp}/swap5-fsi15-physical-authority-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

# Source-bound lineage and exact production scope.
[[ "$(git merge-base "$FSI14_HEAD" HEAD)" == "$FSI14_HEAD" ]] || {
  echo 'F-SI15_PHYSICAL_OPTION_AUTHORITY FAIL lineage' >&2; exit 1; }
changed_src="$(git diff --name-only "$FSI14_HEAD"...HEAD -- src | sort)"
expected_src=$'src/adapter/mod_reference_richards_legacy_binding.f90\nsrc/legacy/b1_10_port/headcalc.f90\nsrc/solver/mod_soil_water_solver_contract.f90'
[[ "$changed_src" == "$expected_src" ]] || {
  echo 'F-SI15_PHYSICAL_OPTION_AUTHORITY FAIL unexpected production delta:' >&2
  printf '%s\n' "$changed_src" >&2
  exit 1
}

check_blob() {
  local path="$1" expected="$2" actual
  actual="$(git rev-parse "HEAD:$path")"
  [[ "$actual" == "$expected" ]] || {
    echo "F-SI15_PHYSICAL_OPTION_AUTHORITY FAIL blob $path expected=$expected actual=$actual" >&2; exit 1; }
}
check_blob src/solver/mod_soil_water_solver_contract.f90 4271372085d800fd5da969a2ed073b00422d79c6
check_blob src/adapter/mod_reference_richards_legacy_binding.f90 9bfa182aff7f7a7ab853fe00151a1f14ed9a8492
check_blob src/legacy/b1_10_port/headcalc.f90 7ce94a4cfc4634b946f41b01f54d2d7f6efc798f

# Static contract: physical config is first-class, separate from numerical policy;
# active macropores fail closed before HeadCalc on the common route.
grep -Fq 'type, public :: soil_water_physical_config_t' src/solver/mod_soil_water_solver_contract.f90
grep -Fq 'logical :: macropore_active = .false.' src/solver/mod_soil_water_solver_contract.f90
grep -Fq 'type(soil_water_physical_config_t) :: physical' src/solver/mod_soil_water_solver_contract.f90
grep -Fq "if (request%physical%macropore_active) then" src/adapter/mod_reference_richards_legacy_binding.f90
grep -Fq "route = 'explicit-macropore-deferred'" src/adapter/mod_reference_richards_legacy_binding.f90
grep -Fq 'request%physical%macropore_active = (swmacro /= 0)' src/adapter/mod_reference_richards_legacy_binding.f90
grep -Fq 'request%evaluation, request%boundary, request%numerical, request%physical' src/adapter/mod_reference_richards_legacy_binding.f90
grep -Fq 'type(soil_water_physical_config_t), intent(in), optional :: physical_config' src/legacy/b1_10_port/headcalc.f90
grep -Fq "if (physical_config%macropore_active) error stop 'HeadCalc: active explicit macropore route not admitted'" src/legacy/b1_10_port/headcalc.f90
grep -Fq 'matrix_fraction = 1.0d0' src/legacy/b1_10_port/headcalc.f90
grep -Fq 'macropore_surface_fraction = 0.0d0' src/legacy/b1_10_port/headcalc.f90
grep -Fq 'pond_balance_option_allows = IcTopMp > 1' src/legacy/b1_10_port/headcalc.f90
grep -Fq 'macropore_exchange_retry_available = IDecMpRat < 3' src/legacy/b1_10_port/headcalc.f90

echo 'F-SI15_STATIC_PHYSICAL_OPTION_BINDING PASS'

BASE_DRIVER="$ROOT/tests/fsi/test_fsi09_b110_common_parallel.F90"
COMMON_DRIVER="$BUILD/fsi15_common.F90"
BASELINE_DRIVER="$BUILD/fsi15_baseline.F90"
POISON_DRIVER="$BUILD/fsi15_poison.F90"

# Generate the already-admitted physical profile: corrected B1.10 constitutive,
# explicit drainage/irrigation source-sink, explicit root sink, explicit top,
# explicit controls, free drainage and explicit inactive macropore configuration.
python3 - "$BASE_DRIVER" "$COMMON_DRIVER" <<'PY'
from pathlib import Path
import sys
s=Path(sys.argv[1]).read_text()
s=s.replace('program test_fsi09_b110_common_parallel','program test_fsi15_physical_option_authority',1)
s=s.replace('end program test_fsi09_b110_common_parallel','end program test_fsi15_physical_option_authority',1)
s=s.replace('use, intrinsic :: ieee_arithmetic, only: ieee_is_finite',
            'use, intrinsic :: ieee_arithmetic, only: ieee_is_finite, ieee_quiet_nan, ieee_value',1)
s=s.replace('use MOD_swap_base, only: swmacro', 'use MOD_swap_base, only: swmacro',1)
s=s.replace('use MOD_drain, only: qdra',
'''use MOD_drain, only: qdra
  use MOD_swap_mp, only: armpss, frarmtrx, qexcmpmtx, dfdhmp, ictopmp, qmplatss, idecmprat, fldecmprat, fldecMPmbf''',1)
s=s.replace('use mod_fsi08_provider_fixture, only: fsi08_source_sink_provider_t',
'''use mod_b110_source_sink_provider, only: b110_source_sink_provider_t, bind_b110_source_sink_provider
  use mod_b110_root_sink_provider, only: b110_root_sink_provider_t, bind_b110_root_sink_provider''',1)
s=s.replace('type(fsi08_source_sink_provider_t), target :: source_sink(8)',
'''type(b110_source_sink_provider_t), target :: source_sink(8)
  type(b110_root_sink_provider_t), target :: root_sink(8)
  real(real64), target :: fsi15_qdra(2,numnod,8), fsi15_qssdi(numnod,8)
  real(real64), target :: fsi15_zero_root(numnod,8), fsi15_qrot(numnod,8)''',1)
old='''       source_sink(column)%source_value = 0.0_real64
       source_sink(column)%sink_value = 0.0_real64
       top_provider(column)%surface_tracks_head = .true.'''
new='''       do node = 1, numnod
          fsi15_qdra(1,node,column) = scale(real(column*node,real64),-10)
          fsi15_qdra(2,node,column) = -scale(real(column+node,real64),-12)
          fsi15_qrot(node,column) = scale(real(2*column+node,real64),-14)
          fsi15_zero_root(node,column) = 0.0_real64
          fsi15_qssdi(node,column) = fsi15_qdra(1,node,column) + fsi15_qdra(2,node,column) + fsi15_qrot(node,column)
       end do
       call bind_b110_source_sink_provider(source_sink(column), fsi15_qdra(:,:,column), &
            fsi15_qssdi(:,column), fsi15_zero_root(:,column))
       call bind_b110_root_sink_provider(root_sink(column), fsi15_qrot(:,column))
       top_provider(column)%surface_tracks_head = .true.'''
if s.count(old)!=1: raise SystemExit('F-SI15 provider marker mismatch')
s=s.replace(old,new,1)
marker='request%evaluation%source_sink => source_sink(column)'
if s.count(marker)!=1: raise SystemExit('F-SI15 request provider marker mismatch')
s=s.replace(marker,marker+'\n    request%evaluation%root_sink => root_sink(column)',1)
marker='request%parameters => kernel_params'
if s.count(marker)!=1: raise SystemExit('F-SI15 request physical marker mismatch')
s=s.replace(marker,marker+'\n    request%physical%macropore_active = .false.',1)
# Request fingerprint must cover the new physical category.
marker="    fp = ieor(fp, transfer(request%boundary%top_flux, fp)); fp = ieor(fp, transfer(request%boundary%bottom_flux, fp))"
if s.count(marker)!=1: raise SystemExit('F-SI15 request fingerprint marker mismatch')
s=s.replace(marker,marker+"\n    fp = ieor(fp, merge(1_int64,0_int64,request%physical%macropore_active))",1)
# Use request geometry for the unrounded focused residual.
needle='residual = sum(dz*(result%candidate_state%water_content-request%base_state%water_content)) + &'
if s.count(needle)!=1: raise SystemExit('F-SI15 residual geometry marker mismatch')
s=s.replace(needle,'residual = sum(request%parameters%dz*(result%candidate_state%water_content-request%base_state%water_content)) + &',1)
# Run the negative active-option admission test for every executable.
marker='''  call run_serial_baseline(failures)
  call run_parallel(failures)
  call run_aba(failures, fp_a1, fp_a2)
'''
repl='''  call run_serial_baseline(failures)
  call run_parallel(failures)
  call run_aba(failures, fp_a1, fp_a2)
  call run_active_macropore_negative(failures)
'''
if s.count(marker)!=1: raise SystemExit('F-SI15 run marker mismatch')
s=s.replace(marker,repl,1)
# Emit fingerprints so baseline/poison and O0/O2 comparisons are byte-sensitive.
marker="  write(*,'(A,I0,A)') 'F-SI09_B110_COMMON_ROUTE_', nthreads, '_PASS'"
repl="""  do i = 1, nthreads
     write(*,'(A,I0,1X,Z16.16)') 'FP', i, serial_fp(i)
  end do
  write(*,'(A,I0,A)') 'F-SI15_PHYSICAL_OPTION_', nthreads, '_PASS'"""
if s.count(marker)!=1: raise SystemExit('F-SI15 output marker mismatch')
s=s.replace(marker,repl,1)
s=s.replace('F-SI09 requires 1/2/4/8 workers','F-SI15 requires 1/2/4/8 workers',1)
s=s.replace('F-SI09_B110_COMMON_ROUTE FAIL failures=','F-SI15_PHYSICAL_OPTION FAIL failures=',1)
# Add an active-macropore fail-closed check. HeadCalc must not be called.
marker='''  subroutine configure_kernel_parameters()
'''
insert='''  subroutine run_active_macropore_negative(fails)
    integer, intent(inout) :: fails
    type(soil_water_solve_request_t) :: bad_request
    type(soil_water_solve_result_t) :: bad_result
    type(reference_richards_legacy_solver_t) :: solver
    type(reference_richards_legacy_workspace_t) :: ws
    integer :: calls_before
    bad_request = requests(1)
    bad_request%physical%macropore_active = .true.
    call prepare_workspace(ws, 1)
    calls_before = ws%legacy_worker%diagnostics%headcalc_calls
    call solver%solve(bad_request, ws, bad_result)
    if (bad_result%status /= SW_SOLVE_FAILED) fails = fails + 1
    if (trim(bad_result%diagnostics%route) /= 'explicit-macropore-deferred') fails = fails + 1
    if (ws%legacy_worker%diagnostics%headcalc_calls /= calls_before) fails = fails + 1
    if (requests(1)%physical%macropore_active) fails = fails + 1
  end subroutine run_active_macropore_negative

'''+marker
if s.count(marker)!=1: raise SystemExit('F-SI15 negative subroutine marker mismatch')
s=s.replace(marker,insert,1)
Path(sys.argv[2]).write_text(s)
PY

cp "$COMMON_DRIVER" "$BASELINE_DRIVER"
cp "$COMMON_DRIVER" "$POISON_DRIVER"

# Poison every legacy macropore datum that the inactive admitted route must not
# consume after its request is constructed. NaNs make accidental arithmetic loud;
# non-default flags make accidental control-flow reads visible in fingerprints.
python3 - "$POISON_DRIVER" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); s=p.read_text()
marker='''  do i = 1, nthreads
     call make_request(requests(i), i)
     request_before(i) = request_fingerprint(requests(i))
  end do

  call run_serial_baseline(failures)'''
poison='''  do i = 1, nthreads
     call make_request(requests(i), i)
     request_before(i) = request_fingerprint(requests(i))
  end do

  call poison_inactive_legacy_macropore_globals()

  call run_serial_baseline(failures)'''
if s.count(marker)!=1: raise SystemExit('F-SI15 poison insertion marker mismatch')
s=s.replace(marker,poison,1)
marker='''  do i = 1, nthreads
     if (request_fingerprint(requests(i)) /= request_before(i)) failures = failures + 1
  end do

  if (failures /= 0) then'''
checks='''  do i = 1, nthreads
     if (request_fingerprint(requests(i)) /= request_before(i)) failures = failures + 1
  end do
  call verify_inactive_legacy_macropore_poison(failures)

  if (failures /= 0) then'''
if s.count(marker)!=1: raise SystemExit('F-SI15 poison verification marker mismatch')
s=s.replace(marker,checks,1)
marker='''  subroutine run_active_macropore_negative(fails)
'''
helpers='''  subroutine poison_inactive_legacy_macropore_globals()
    real(real64) :: nan
    nan = ieee_value(0.0_real64, ieee_quiet_nan)
    swmacro = 1
    armpss = nan
    frarmtrx = nan
    qexcmpmtx = nan
    dfdhmp = nan
    ictopmp = -771
    qmplatss = nan
    idecmprat = -772
    fldecmprat = .true.
    fldecMPmbf = .true.
  end subroutine poison_inactive_legacy_macropore_globals

  subroutine verify_inactive_legacy_macropore_poison(fails)
    integer, intent(inout) :: fails
    if (swmacro /= 1) fails = fails + 1
    if (ieee_is_finite(armpss)) fails = fails + 1
    if (any(ieee_is_finite(frarmtrx))) fails = fails + 1
    if (any(ieee_is_finite(qexcmpmtx))) fails = fails + 1
    if (any(ieee_is_finite(dfdhmp))) fails = fails + 1
    if (ictopmp /= -771) fails = fails + 1
    if (ieee_is_finite(qmplatss)) fails = fails + 1
    if (idecmprat /= -772) fails = fails + 1
    if (.not. fldecmprat) fails = fails + 1
    if (.not. fldecMPmbf) fails = fails + 1
  end subroutine verify_inactive_legacy_macropore_poison

'''+marker
if s.count(marker)!=1: raise SystemExit('F-SI15 poison helper marker mismatch')
s=s.replace(marker,helpers,1)
p.write_text(s)
PY

FLAGS=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow -fopenmp)
compile_driver() {
  local driver="$1" opt="$2" out="$3"
  mkdir -p "$out"
  gfortran "${FLAGS[@]}" -O"$opt" -J "$out" -I "$out" -c tests/fsi/fsi04_real_headcalc_stubs.f90 -o "$out/stubs.o"
  gfortran "${FLAGS[@]}" -O"$opt" -J "$out" -I "$out" -c src/runtime/mod_a23bu_worker_execution_context.f90 -o "$out/worker.o"
  gfortran "${FLAGS[@]}" -Werror -O"$opt" -J "$out" -I "$out" -c src/solver/mod_soil_water_solver_contract.f90 -o "$out/contract.o"
  gfortran "${FLAGS[@]}" -O"$opt" -J "$out" -I "$out" -c src/solver/mod_reference_richards_workspace.f90 -o "$out/workspace.o"
  gfortran "${FLAGS[@]}" -O"$opt" -J "$out" -I "$out" -c src/solver/mod_reference_richards_state_binding.f90 -o "$out/state.o"
  gfortran "${FLAGS[@]}" -O"$opt" -J "$out" -I "$out" -c tests/fsi/mod_fsi07_top_provider.f90 -o "$out/top.o"
  gfortran "${FLAGS[@]}" -Werror -O"$opt" -J "$out" -I "$out" -c src/solver/mod_b110_default_mvg_provider.f90 -o "$out/mvg.o"
  gfortran "${FLAGS[@]}" -Werror -O"$opt" -J "$out" -I "$out" -c src/solver/mod_b110_source_sink_provider.f90 -o "$out/process.o"
  gfortran "${FLAGS[@]}" -Werror -O"$opt" -J "$out" -I "$out" -c src/solver/mod_b110_root_sink_provider.f90 -o "$out/root.o"
  gfortran "${FLAGS[@]}" -O"$opt" -J "$out" -I "$out" -c src/legacy/b1_10_port/headcalc.f90 -o "$out/headcalc.o"
  gfortran "${FLAGS[@]}" -O"$opt" -J "$out" -I "$out" -c src/adapter/mod_reference_richards_legacy_binding.f90 -o "$out/adapter.o"
  gfortran "${FLAGS[@]}" -Werror -O"$opt" -J "$out" -I "$out" -c "$driver" -o "$out/driver.o"
  gfortran "${FLAGS[@]}" -O"$opt" "$out/driver.o" "$out/adapter.o" "$out/headcalc.o" "$out/root.o" \
    "$out/process.o" "$out/mvg.o" "$out/top.o" "$out/state.o" "$out/workspace.o" "$out/contract.o" \
    "$out/worker.o" "$out/stubs.o" -o "$out/test"
}

for opt in 0 2; do
  base="$BUILD/base-o${opt}"
  poison="$BUILD/poison-o${opt}"
  compile_driver "$BASELINE_DRIVER" "$opt" "$base"
  compile_driver "$POISON_DRIVER" "$opt" "$poison"
  for threads in 1 2 4 8; do
    timeout 30s env OMP_NUM_THREADS="$threads" OMP_DYNAMIC=false "$base/test" > "$base/t${threads}.txt"
    timeout 30s env OMP_NUM_THREADS="$threads" OMP_DYNAMIC=false "$poison/test" > "$poison/t${threads}.txt"
    grep -Fq "F-SI15_PHYSICAL_OPTION_${threads}_PASS" "$base/t${threads}.txt"
    grep -Fq "F-SI15_PHYSICAL_OPTION_${threads}_PASS" "$poison/t${threads}.txt"
    cmp "$base/t${threads}.txt" "$poison/t${threads}.txt"
  done
  echo "F-SI15_INACTIVE_MACROPORE_POISON_O${opt}_1_2_4_8_IDENTITY PASS"
done

for threads in 1 2 4 8; do
  cmp "$BUILD/base-o0/t${threads}.txt" "$BUILD/base-o2/t${threads}.txt"
  cmp "$BUILD/poison-o0/t${threads}.txt" "$BUILD/poison-o2/t${threads}.txt"
done

echo 'F-SI15_INACTIVE_MACROPORE_O0_O2_IDENTITY PASS'
echo 'F-SI15_ACTIVE_MACROPORE_FAIL_CLOSED_BEFORE_HEADCALC PASS'
echo 'F-SI15_PHYSICAL_OPTION_AUTHORITY_GATE PASS'
