#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
FSI15_HEAD="fe5e55d5d5ebff42e8212cba8df15652e5f1a52b"
BUILD="${TMPDIR:-/tmp}/swap5-fsi16-qualification-matrix-$$"
RESPONSE_STUB="$BUILD/fsi16_response_headcalc_stubs.f90"
MATRIX_BASE="$BUILD/fsi16_matrix_base.F90"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

[[ "$(git merge-base "$FSI15_HEAD" HEAD)" == "$FSI15_HEAD" ]] || {
  echo 'F-SI16_MATRIX FAIL lineage' >&2; exit 1; }
changed_src="$(git diff --name-only "$FSI15_HEAD"...HEAD -- src | sort)"
expected_src=$'src/adapter/mod_reference_richards_legacy_binding.f90\nsrc/legacy/b1_10_port/headcalc.f90'
[[ "$changed_src" == "$expected_src" ]] || {
  echo 'F-SI16_MATRIX FAIL unexpected production delta:' >&2; printf '%s\n' "$changed_src" >&2; exit 1; }

grep -Fq 'fsi_ws%head_gradient(NN+1) = (state%h(NN) - state%hbot) / grid_disnod(NN+1) + 1.0d0' \
  src/legacy/b1_10_port/headcalc.f90
grep -Fq 'result%unrounded_mass_balance_residual = sum(ws%richards%residual(1:n))' \
  src/adapter/mod_reference_richards_legacy_binding.f90

echo 'F-SI16_MATRIX_EXACT_B110_SOURCE_ROUTE PASS'

# Derive only the test linear solver from the historical equilibrium-only stub.
# Historical F-SI04/F-SI15 fixture source remains unchanged.
python3 - tests/fsi/fsi04_real_headcalc_stubs.f90 "$RESPONSE_STUB" <<'PY'
from pathlib import Path
import sys
src=Path(sys.argv[1]).read_text()
old='''subroutine tridag(n, upper, main, lower, rhs, solution, ierror)
  implicit none
  integer, intent(in) :: n
  real(8), intent(in) :: upper(*), main(*), lower(*), rhs(*)
  real(8), intent(out) :: solution(*)
  integer, intent(out) :: ierror
  integer :: i
  if (n <= 0 .or. upper(1) > huge(upper(1)) .or. main(1) > huge(main(1)) .or. &
      lower(1) > huge(lower(1)) .or. rhs(1) > huge(rhs(1))) error stop 'invalid tridag arguments'
  do i = 1, n
    solution(i) = 0.0d0
  end do
  ierror = 0
end subroutine tridag
'''
new='''subroutine tridag(n, upper, main, lower, rhs, solution, ierror)
  implicit none
  integer, intent(in) :: n
  real(8), intent(in) :: upper(*), main(*), lower(*), rhs(*)
  real(8), intent(out) :: solution(*)
  integer, intent(out) :: ierror
  integer :: i, j
  real(8) :: beta, gamma(n)
  ierror = 0
  if (n <= 0) then
    ierror = 1
    return
  end if
  beta = main(1)
  if (abs(beta) <= tiny(1.0d0)) then
    ierror = 1
    do j = 1, n
      solution(j) = 0.0d0
    end do
    return
  end if
  gamma(1) = 0.0d0
  solution(1) = rhs(1)/beta
  do i = 2, n
    gamma(i) = lower(i-1)/beta
    beta = main(i) - upper(i)*gamma(i)
    if (abs(beta) <= tiny(1.0d0)) then
      ierror = 1
      do j = 1, n
        solution(j) = 0.0d0
      end do
      return
    end if
    solution(i) = (rhs(i) - upper(i)*solution(i-1))/beta
  end do
  do i = n-1, 1, -1
    solution(i) = solution(i) - gamma(i+1)*solution(i+1)
  end do
end subroutine tridag
'''
if src.count(old) != 1:
    raise SystemExit(f'F-SI16_MATRIX TRIDAG marker count={src.count(old)}')
Path(sys.argv[2]).write_text(src.replace(old,new,1))
PY

# Extend the already-qualified focused driver runner-locally with A/B/A and
# serialized 1/2/4/8 worker isolation. No concurrent HeadCalc call is admitted.
python3 - tests/fsi/test_fsi16_prescribed_bottom_head.F90 "$MATRIX_BASE" <<'PY'
from pathlib import Path
import sys
s=Path(sys.argv[1]).read_text()
repls=[
("  type(soil_water_solve_result_t) :: result_a, result_b, result_c, reject_result\n",
 "  type(soil_water_solve_result_t) :: result_a, result_b, result_c, result_a2, worker_result, reject_result\n"),
("  type(reference_richards_legacy_workspace_t) :: workspace\n",
 "  type(reference_richards_legacy_workspace_t) :: workspace, worker_ws(8)\n"),
("  integer :: mode, failures, calls_before\n",
 "  integer :: mode, failures, calls_before, worker_count_index, worker_index\n"
 "  integer, parameter :: worker_counts(4) = [1,2,4,8]\n"),
("  write(*,'(A,Z16.16)') 'F-SI16_PERTURBED_HEAD_BITS ', transfer(result_c%candidate_state%pressure_head(numnod),0_int64)\n",
 "  write(*,'(A,Z16.16)') 'F-SI16_PERTURBED_HEAD_BITS ', transfer(result_c%candidate_state%pressure_head(numnod),0_int64)\n"
 "  write(*,'(A,ES24.16)') 'F-SI16_PERTURBED_QBOT ', result_c%bottom_flux\n"
 "  write(*,'(A,I0)') 'F-SI16_PERTURBED_ITERATIONS ', result_c%diagnostics%nonlinear_iterations\n")]
for old,new in repls:
    if s.count(old) != 1:
        raise SystemExit(f'F-SI16_MATRIX declaration/output marker count={s.count(old)} for {old[:70]!r}')
    s=s.replace(old,new,1)

marker="  if (request_fingerprint(request_a) /= request_a_before) failures = failures + 1\n"
inject='''  ! Explicit A/B/A replay: same request, newly poisoned scratch, identical
  ! accepted state, flux, residual and solver route/cost diagnostics.
  call prepare_workspace(workspace)
  call solver%solve(request_a, workspace, result_a2)
  if (result_a2%status /= result_a%status) failures = failures + 1
  if (trim(result_a2%diagnostics%route) /= trim(result_a%diagnostics%route)) failures = failures + 1
  if (.not. all(bitwise_same(result_a2%candidate_state%pressure_head, result_a%candidate_state%pressure_head))) failures = failures + 1
  if (.not. all(bitwise_same(result_a2%candidate_state%water_content, result_a%candidate_state%water_content))) failures = failures + 1
  if (transfer(result_a2%bottom_flux,0_int64) /= transfer(result_a%bottom_flux,0_int64)) failures = failures + 1
  if (transfer(result_a2%unrounded_mass_balance_residual,0_int64) /= &
      transfer(result_a%unrounded_mass_balance_residual,0_int64)) failures = failures + 1
  if (result_a2%diagnostics%nonlinear_iterations /= result_a%diagnostics%nonlinear_iterations) failures = failures + 1
  if (result_a2%diagnostics%jacobian_builds /= result_a%diagnostics%jacobian_builds) failures = failures + 1
  if (result_a2%diagnostics%linear_solves /= result_a%diagnostics%linear_solves) failures = failures + 1
  if (result_a2%diagnostics%backtracking_attempts /= result_a%diagnostics%backtracking_attempts) failures = failures + 1
  if (result_a2%diagnostics%alternative_solver_calls /= result_a%diagnostics%alternative_solver_calls) failures = failures + 1
  if (result_a2%diagnostics%internal_retries /= result_a%diagnostics%internal_retries) failures = failures + 1
  print *, 'F-SI16_ABA_ROUTE_ITERATION_IDENTITY PASS'

  ! Focused worker isolation only: use independent worker/workspace objects in
  ! serialized execution. This deliberately does NOT admit the parallel
  ! reference backend.
  do worker_count_index = 1, size(worker_counts)
     do worker_index = 1, worker_counts(worker_count_index)
        call prepare_workspace(worker_ws(worker_index))
        if (.not. worker_ws(worker_index)%richards%poisoned) failures = failures + 1
        worker_ws(worker_index)%legacy_worker%worker_id = 516 + worker_index
        call solver%solve(request_c, worker_ws(worker_index), worker_result)
        if (worker_result%status /= result_c%status) failures = failures + 1
        if (trim(worker_result%diagnostics%route) /= trim(result_c%diagnostics%route)) failures = failures + 1
        if (.not. all(bitwise_same(worker_result%candidate_state%pressure_head, result_c%candidate_state%pressure_head))) failures = failures + 1
        if (.not. all(bitwise_same(worker_result%candidate_state%water_content, result_c%candidate_state%water_content))) failures = failures + 1
        if (transfer(worker_result%bottom_flux,0_int64) /= transfer(result_c%bottom_flux,0_int64)) failures = failures + 1
        if (transfer(worker_result%unrounded_mass_balance_residual,0_int64) /= &
            transfer(result_c%unrounded_mass_balance_residual,0_int64)) failures = failures + 1
        if (worker_result%diagnostics%nonlinear_iterations /= result_c%diagnostics%nonlinear_iterations) failures = failures + 1
        if (worker_result%diagnostics%jacobian_builds /= result_c%diagnostics%jacobian_builds) failures = failures + 1
        if (worker_result%diagnostics%linear_solves /= result_c%diagnostics%linear_solves) failures = failures + 1
        if (worker_result%diagnostics%backtracking_attempts /= result_c%diagnostics%backtracking_attempts) failures = failures + 1
        if (worker_result%diagnostics%alternative_solver_calls /= result_c%diagnostics%alternative_solver_calls) failures = failures + 1
        if (worker_result%diagnostics%internal_retries /= result_c%diagnostics%internal_retries) failures = failures + 1
        if (swbotb /= 3 .or. .not. ieee_is_nan(hbot) .or. .not. ieee_is_nan(gwlinp) .or. .not. ieee_is_nan(qbot)) &
             failures = failures + 1
     end do
     write(*,'(A,I0,A)') 'F-SI16_SERIALIZED_WORKER_ISOLATION_', worker_counts(worker_count_index), ' PASS'
  end do

  if (abs(result_c%unrounded_mass_balance_residual) > request_c%numerical%total_balance_tolerance) failures = failures + 1
  print *, 'F-SI16_EXISTING_UNROUNDED_BALANCE_TOLERANCE PASS'

'''
if s.count(marker) != 1:
    raise SystemExit(f'F-SI16_MATRIX injection marker count={s.count(marker)}')
s=s.replace(marker,inject+marker,1)
Path(sys.argv[2]).write_text(s)
PY

FLAGS=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow -fopenmp)
compile_common() {
  local opt="$1" out="$2"
  mkdir -p "$out"
  gfortran "${FLAGS[@]}" -O"$opt" -J "$out" -I "$out" -c "$RESPONSE_STUB" -o "$out/stubs.o"
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
}

run_case() {
  local opt="$1" label="$2" offset="$3" out="$4"
  local driver="$out/driver_${label}.F90"
  python3 - "$MATRIX_BASE" "$driver" "$offset" <<'PY'
from pathlib import Path
import sys
s=Path(sys.argv[1]).read_text()
offset=sys.argv[3]
old='request_c%boundary%bottom_head = head_value + 0.01_real64'
new=f'request_c%boundary%bottom_head = head_value + ({offset})_real64'
if s.count(old) != 1:
    raise SystemExit(f'F-SI16_MATRIX head marker count={s.count(old)}')
Path(sys.argv[2]).write_text(s.replace(old,new,1))
PY
  gfortran "${FLAGS[@]}" -Werror -O"$opt" -J "$out" -I "$out" -c "$driver" -o "$out/driver_${label}.o"
  gfortran "${FLAGS[@]}" -O"$opt" "$out/driver_${label}.o" "$out/adapter.o" "$out/headcalc.o" "$out/root.o" \
    "$out/process.o" "$out/mvg.o" "$out/top.o" "$out/state.o" "$out/workspace.o" "$out/contract.o" \
    "$out/worker.o" "$out/stubs.o" -o "$out/test_${label}"
  timeout 60s env OMP_NUM_THREADS=1 OMP_DYNAMIC=false "$out/test_${label}" > "$out/${label}.txt"
  grep -Fq 'F-SI16_PRESCRIBED_BOTTOM_HEAD_GATE PASS' "$out/${label}.txt"
  grep -Fq 'F-SI16_ABA_ROUTE_ITERATION_IDENTITY PASS' "$out/${label}.txt"
  grep -Fq 'F-SI16_SERIALIZED_WORKER_ISOLATION_1 PASS' "$out/${label}.txt"
  grep -Fq 'F-SI16_SERIALIZED_WORKER_ISOLATION_2 PASS' "$out/${label}.txt"
  grep -Fq 'F-SI16_SERIALIZED_WORKER_ISOLATION_4 PASS' "$out/${label}.txt"
  grep -Fq 'F-SI16_SERIALIZED_WORKER_ISOLATION_8 PASS' "$out/${label}.txt"
  grep -Fq 'F-SI16_EXISTING_UNROUNDED_BALANCE_TOLERANCE PASS' "$out/${label}.txt"
  printf 'F-SI16_HEAD_CASE_%s ' "${label^^}"
  grep -F 'F-SI16_PERTURBED_QBOT ' "$out/${label}.txt" | tail -1
}

for opt in 0 2; do
  out="$BUILD/o$opt"
  compile_common "$opt" "$out"
  # Fixed lower-face heads relative to -75 cm reference: -76, -74.99, -74 cm.
  run_case "$opt" low  '-1.0' "$out"
  run_case "$opt" mid  '0.01' "$out"
  run_case "$opt" high '1.0'  "$out"
done

for label in low mid high; do
  cmp "$BUILD/o0/${label}.txt" "$BUILD/o2/${label}.txt"
done
echo 'F-SI16_MATRIX_O0_O2_IDENTITY PASS'

python3 - "$BUILD/o0/low.txt" "$BUILD/o0/mid.txt" "$BUILD/o0/high.txt" <<'PY'
from pathlib import Path
import re,sys
vals=[]
for p in sys.argv[1:]:
    text=Path(p).read_text()
    m=re.findall(r'F-SI16_PERTURBED_QBOT\s+([-+0-9.Ee]+)', text)
    if len(m) != 1:
        raise SystemExit(f'F-SI16_MATRIX QBOT parse failure {p}: {m}')
    vals.append(float(m[0]))
print('F-SI16_MATRIX_QBOT_VALUES', *[f'{v:.16e}' for v in vals])
if not any(v > 0.0 for v in vals):
    raise SystemExit('F-SI16_MATRIX missing positive bottom flux')
if not any(v < 0.0 for v in vals):
    raise SystemExit('F-SI16_MATRIX missing negative bottom flux')
PY

echo 'F-SI16_MULTIPLE_PRESCRIBED_HEADS PASS'
echo 'F-SI16_POSITIVE_AND_NEGATIVE_BOTTOM_FLUX PASS'
echo 'F-SI16_SERIALIZED_WORKER_MATRIX_1_2_4_8 PASS'
echo 'F-SI16_QUALIFICATION_MATRIX_GATE PASS'
