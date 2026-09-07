#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fsi07-concurrency-probe-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

STUB_BASE="$ROOT/tests/fsi/fsi04_real_headcalc_stubs.f90"
STUBS="$BUILD/fsi07_concurrency_stubs.f90"
WORKER="$ROOT/src/runtime/mod_a23bu_worker_execution_context.f90"
CONTRACT="$ROOT/src/solver/mod_soil_water_solver_contract.f90"
WORKSPACE="$ROOT/src/solver/mod_reference_richards_workspace.f90"
STATE="$ROOT/src/solver/mod_reference_richards_state_binding.f90"
HEADCALC="$ROOT/src/legacy/b1_10_port/headcalc.f90"
DRIVER="$ROOT/tests/fsi/test_fsi07_real_concurrency.F90"

python3 - "$STUB_BASE" "$STUBS" <<'PY'
from pathlib import Path
import sys
s=Path(sys.argv[1]).read_text()
old='''module MOD_top
  implicit none
  real(8) :: q0 = 0.0d0
  logical :: flrunoff = .false., ftoph = .false.
  real(8) :: hsurf = 0.0d0
contains
  subroutine boundtop(task)
    use variables, only: qtop
    integer, intent(in) :: task
    if (task < 0) error stop 'invalid boundtop task'
    ftoph = .false.
    qtop = -1.0d0
  end subroutine boundtop
  subroutine pondrunoff()
  end subroutine pondrunoff
end module MOD_top
'''
new='''module fsi07_concurrency_control
  implicit none
  logical :: parallel_probe = .false.
end module fsi07_concurrency_control

module MOD_top
  use, intrinsic :: iso_c_binding, only: c_int
  use fsi07_concurrency_control, only: parallel_probe
  implicit none
  real(8) :: q0 = 0.0d0
  logical :: flrunoff = .false., ftoph = .false.
  real(8) :: hsurf = 0.0d0
  interface
    function usleep(usec) bind(C, name='usleep') result(rc)
      import :: c_int
      integer(c_int), value :: usec
      integer(c_int) :: rc
    end function usleep
  end interface
contains
  subroutine boundtop(task)
    use variables, only: h, qtop
    integer, intent(in) :: task
    integer(c_int) :: rc
    if (task < 0) error stop 'invalid boundtop task'
    if (parallel_probe) rc = usleep(20000_c_int)
    ftoph = .false.
    qtop = -1.0d0
    ! State-sensitive but equation-neutral probe: hsurf is not used when ftoph=.false.
    hsurf = h(1)
  end subroutine boundtop
  subroutine pondrunoff()
  end subroutine pondrunoff
end module MOD_top
'''
if s.count(old) != 1:
    raise SystemExit(f'F-SI07_CONCURRENCY_STUB FAIL MOD_top count={s.count(old)}')
Path(sys.argv[2]).write_text(s.replace(old,new,1))
PY

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -fopenmp)
for opt in 0 2; do
  out="$BUILD/o$opt"; mkdir -p "$out"
  gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c "$STUBS" -o "$out/stubs.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c "$WORKER" -o "$out/worker.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c "$CONTRACT" -o "$out/contract.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c "$WORKSPACE" -o "$out/workspace.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c "$STATE" -o "$out/state.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c "$HEADCALC" -o "$out/headcalc.o"
  gfortran "${COMMON[@]}" -O"$opt" -cpp -DFSI07_EXPECT_LEAK -J "$out" -I "$out" -c "$DRIVER" -o "$out/driver.o"
  gfortran "${COMMON[@]}" -O"$opt" "$out/driver.o" "$out/headcalc.o" "$out/state.o" "$out/workspace.o" \
    "$out/contract.o" "$out/worker.o" "$out/stubs.o" -o "$out/probe"

  for threads in 1 2 4 8; do
    timeout 30s env OMP_NUM_THREADS="$threads" OMP_DYNAMIC=false "$out/probe" > "$out/t${threads}.txt"
    if [[ "$threads" == 1 ]]; then
      grep -Fq 'F-SI07_REAL_HEADCALC_1 PASS' "$out/t${threads}.txt"
    else
      grep -Fq "F-SI07_REAL_HEADCALC_${threads} LEAK_CONFIRMED" "$out/t${threads}.txt"
    fi
  done
  echo "F-SI07_CONCURRENCY_PROBE_O${opt} BLOCKER_CONFIRMED"
done

echo 'F-SI07_CONCURRENCY_PROBE BLOCKED_BOUNDARY_STATE_BRIDGE'
