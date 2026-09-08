#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PRODUCTION_POSTIMAGE="d4c3cb5982b423de23b9b4bd2f815cfe895aca4f"
ORACLE="$ROOT/reference/swap-4.3.1/b1_10_oracles/F-SI16_SWBOTB5_MODE5_ORACLE.txt"
PROVENANCE="$ROOT/reference/swap-4.3.1/b1_10_oracles/F-SI16_SWBOTB5_MODE5_ORACLE.json"
BUILD="${TMPDIR:-/tmp}/swap5-fsi16-b110-direct-oracle-$$"
RESPONSE_STUB="$BUILD/fsi16_response_headcalc_stubs.f90"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

[[ "$(git merge-base "$PRODUCTION_POSTIMAGE" HEAD)" == "$PRODUCTION_POSTIMAGE" ]] || {
  echo 'F-SI16_B110_DIRECT_ORACLE FAIL production-postimage-lineage' >&2; exit 1; }
[[ -z "$(git diff --name-only "$PRODUCTION_POSTIMAGE"...HEAD -- src)" ]] || {
  echo 'F-SI16_B110_DIRECT_ORACLE FAIL production changed after frozen postimage' >&2
  git diff --name-only "$PRODUCTION_POSTIMAGE"...HEAD -- src >&2
  exit 1
}

python3 - "$PROVENANCE" "$ORACLE" <<'PY'
import hashlib, json, pathlib, sys
p=json.loads(pathlib.Path(sys.argv[1]).read_text())
raw=pathlib.Path(sys.argv[2]).read_bytes()
assert p['work_unit']=='F-SI16'
assert p['oracle']=='exact_B1.10_SWBOTB5_mode5_direct_headcalc'
assert p['source_provenance']['nested_swap_zip_sha256']=='1a2d7989287cd5ffcd46959ca43e1cfc354ad1642de26245feca9b0572445151'
assert p['source_provenance']['headcalc_b110_sha256']=='db6675984fbaf37290acaf96553ba0165c55caf45983411f62f30be309c113f5'
assert p['source_provenance']['tridag_b110_sha256']=='87b9b1cd6de65e6ee1d7c1775cddff6093c12d4d0744ffcde70844f5f28c6e7a'
assert p['fixture']['swbotb']==5 and p['fixture']['prescribed_bottom_head_cm']==-74.0
assert p['execution']['o0_o2_byte_identical'] is True
assert p['execution']['comparison_policy']=='bitwise_no_scientific_tolerance'
assert hashlib.sha256(raw).hexdigest()==p['execution']['oracle_vector_sha256']=='ea60f9b5e5651dc79cf27aee14612aa310e3cbaf71204770f8ba7441f2a24510'
assert p['result']=='SOURCE_BOUND_ORACLE_PERSISTED_NOT_YET_COMMON_ROUTE_QUALIFIED'
print('F-SI16_EXACT_B110_ORACLE_PROVENANCE PASS')
PY

# F-SI04's historical stub intentionally returned a zero Newton update. Derive
# the same response-capable tridiagonal solve already qualified by the focused
# F-SI16 gate. Historical predecessor files remain byte-identical.
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
    raise SystemExit(f'F-SI16 direct oracle TRIDAG marker count={src.count(old)}')
Path(sys.argv[2]).write_text(src.replace(old,new,1))
PY

FLAGS=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow -fopenmp)
compile_common_oracle() {
  local opt="$1" out="$2"
  mkdir -p "$out"
  gfortran "${FLAGS[@]}" -O"$opt" -J "$out" -I "$out" -c "$RESPONSE_STUB" -o "$out/stubs.o"
  gfortran "${FLAGS[@]}" -O"$opt" -J "$out" -I "$out" -c src/runtime/mod_a23bu_worker_execution_context.f90 -o "$out/worker.o"
  gfortran "${FLAGS[@]}" -Werror -O"$opt" -J "$out" -I "$out" -c src/solver/mod_soil_water_solver_contract.f90 -o "$out/contract.o"
  gfortran "${FLAGS[@]}" -O"$opt" -J "$out" -I "$out" -c src/solver/mod_reference_richards_workspace.f90 -o "$out/workspace.o"
  gfortran "${FLAGS[@]}" -O"$opt" -J "$out" -I "$out" -c src/solver/mod_reference_richards_state_binding.f90 -o "$out/state.o"
  gfortran "${FLAGS[@]}" -Werror -O"$opt" -J "$out" -I "$out" -c tests/fsi/mod_fsi16_b110_direct_oracle_fixture.f90 -o "$out/fixture.o"
  gfortran "${FLAGS[@]}" -O"$opt" -J "$out" -I "$out" -c src/legacy/b1_10_port/headcalc.f90 -o "$out/headcalc.o"
  gfortran "${FLAGS[@]}" -O"$opt" -J "$out" -I "$out" -c src/adapter/mod_reference_richards_legacy_binding.f90 -o "$out/adapter.o"
  gfortran "${FLAGS[@]}" -Werror -O"$opt" -J "$out" -I "$out" -c tests/fsi/test_fsi16_b110_direct_oracle_common.F90 -o "$out/driver.o"
  gfortran "${FLAGS[@]}" -O"$opt" "$out/driver.o" "$out/adapter.o" "$out/headcalc.o" "$out/fixture.o" \
    "$out/state.o" "$out/workspace.o" "$out/contract.o" "$out/worker.o" "$out/stubs.o" -o "$out/test"
}

for opt in 0 2; do
  out="$BUILD/o$opt"
  compile_common_oracle "$opt" "$out"
  timeout 30s env OMP_NUM_THREADS=1 OMP_DYNAMIC=false "$out/test" > "$out/output.txt"
  if ! cmp "$ORACLE" "$out/output.txt"; then
    echo "F-SI16_B110_DIRECT_ORACLE_O${opt} FAIL bitwise mismatch" >&2
    diff -u "$ORACLE" "$out/output.txt" >&2 || true
    exit 1
  fi
  echo "F-SI16_B110_DIRECT_NUMERICAL_IDENTITY_O${opt} PASS"
done

cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
echo 'F-SI16_B110_DIRECT_NUMERICAL_O0_O2_IDENTITY PASS'
echo 'F-SI16_B110_DIRECT_ORACLE_GATE PASS'
