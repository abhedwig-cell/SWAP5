#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BASE="2fa63c41a4d7248ab7f4b5af46f72caddfda4f29"
BUILD="${TMPDIR:-/tmp}/swap5-fsi07-common-route-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

FSI04_STUBS="$ROOT/tests/fsi/fsi04_real_headcalc_stubs.f90"
WORKER="$ROOT/src/runtime/mod_a23bu_worker_execution_context.f90"
CONTRACT="$ROOT/src/solver/mod_soil_water_solver_contract.f90"
WORKSPACE="$ROOT/src/solver/mod_reference_richards_workspace.f90"
STATE="$ROOT/src/solver/mod_reference_richards_state_binding.f90"
TOP_PROVIDER="$ROOT/tests/fsi/mod_fsi07_top_provider.f90"
HEADCALC="$ROOT/src/legacy/b1_10_port/headcalc.f90"
ADAPTER="$ROOT/src/adapter/mod_reference_richards_legacy_binding.f90"
PREIMAGE_DRIVER="$ROOT/tests/fsi/test_fsi07_state_binding.F90"
SERIAL_DRIVER="$ROOT/tests/fsi/test_fsi07_common_route_serial.F90"
PARALLEL_DRIVER="$ROOT/tests/fsi/test_fsi07_common_route_parallel.F90"
PREIMAGE="$BUILD/headcalc_fsi06_preimage.f90"
STUBS="$BUILD/fsi07_common_stubs.f90"

git show "$BASE:src/legacy/b1_10_port/headcalc.f90" > "$PREIMAGE"
python3 - "$FSI04_STUBS" "$STUBS" <<'PY'
from pathlib import Path
import sys
s=Path(sys.argv[1]).read_text()
marker='subroutine tridag(n, upper, main, lower, rhs, solution, ierror)\n  implicit none\n'
insert='''module fsi05_fixture_control
  implicit none
  logical :: force_tridag_failure = .false.
end module fsi05_fixture_control

subroutine tridag(n, upper, main, lower, rhs, solution, ierror)
  use fsi05_fixture_control, only: force_tridag_failure
  implicit none
'''
if s.count(marker)!=1: raise SystemExit('F-SI07 common gate: tridag marker mismatch')
s=s.replace(marker,insert,1)
old='  ierror = 0\nend subroutine tridag\n'
new='''  if (force_tridag_failure) then
    ierror = 1
  else
    ierror = 0
  end if
end subroutine tridag
'''
if s.count(old)!=1: raise SystemExit('F-SI07 common gate: tridag result marker mismatch')
Path(sys.argv[2]).write_text(s.replace(old,new,1))
PY

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow -fopenmp)
for opt in 0 2; do
  pre="$BUILD/pre-o$opt"; cur="$BUILD/current-o$opt"
  mkdir -p "$pre" "$cur"

  # Qualified F-SI06/F-SI05 preimage replay.
  gfortran "${COMMON[@]}" -O"$opt" -J "$pre" -I "$pre" -c "$STUBS" -o "$pre/stubs.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$pre" -I "$pre" -c "$WORKER" -o "$pre/worker.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$pre" -I "$pre" -c "$CONTRACT" -o "$pre/contract.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$pre" -I "$pre" -c "$WORKSPACE" -o "$pre/workspace.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$pre" -I "$pre" -c "$PREIMAGE" -o "$pre/headcalc.o"
  gfortran "${COMMON[@]}" -O"$opt" -cpp -DFSI07_PREIMAGE -J "$pre" -I "$pre" -c "$PREIMAGE_DRIVER" -o "$pre/driver.o"
  gfortran "${COMMON[@]}" -O"$opt" "$pre/driver.o" "$pre/headcalc.o" "$pre/workspace.o" \
    "$pre/contract.o" "$pre/worker.o" "$pre/stubs.o" -o "$pre/replay"
  "$pre/replay" > "$pre/output.txt"

  # Current admitted common route: request -> adapter -> explicit state -> real HeadCalc -> result.
  gfortran "${COMMON[@]}" -O"$opt" -J "$cur" -I "$cur" -c "$STUBS" -o "$cur/stubs.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$cur" -I "$cur" -c "$WORKER" -o "$cur/worker.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$cur" -I "$cur" -c "$CONTRACT" -o "$cur/contract.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$cur" -I "$cur" -c "$WORKSPACE" -o "$cur/workspace.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$cur" -I "$cur" -c "$STATE" -o "$cur/state.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$cur" -I "$cur" -c "$TOP_PROVIDER" -o "$cur/top_provider.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$cur" -I "$cur" -c "$HEADCALC" -o "$cur/headcalc.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$cur" -I "$cur" -c "$ADAPTER" -o "$cur/adapter.o"
  gfortran "${COMMON[@]}" -Werror -O"$opt" -J "$cur" -I "$cur" -c "$SERIAL_DRIVER" -o "$cur/serial_driver.o"
  gfortran "${COMMON[@]}" -O"$opt" "$cur/serial_driver.o" "$cur/adapter.o" "$cur/headcalc.o" \
    "$cur/top_provider.o" "$cur/state.o" "$cur/workspace.o" "$cur/contract.o" "$cur/worker.o" "$cur/stubs.o" \
    -o "$cur/serial"
  "$cur/serial" > "$cur/serial_output.txt"
  cmp "$pre/output.txt" "$cur/serial_output.txt"
  echo "F-SI07_COMMON_SERIAL_FSI06_IDENTITY_O${opt} PASS"

  gfortran "${COMMON[@]}" -Werror -O"$opt" -J "$cur" -I "$cur" -c "$PARALLEL_DRIVER" -o "$cur/parallel_driver.o"
  gfortran "${COMMON[@]}" -O"$opt" "$cur/parallel_driver.o" "$cur/adapter.o" "$cur/headcalc.o" \
    "$cur/top_provider.o" "$cur/state.o" "$cur/workspace.o" "$cur/contract.o" "$cur/worker.o" "$cur/stubs.o" \
    -o "$cur/parallel"
  for threads in 1 2 4 8; do
    timeout 30s env OMP_NUM_THREADS="$threads" OMP_DYNAMIC=false "$cur/parallel" > "$cur/t${threads}.txt"
    grep -Fq "F-SI07_COMMON_ROUTE_MAIN_${threads} PASS" "$cur/t${threads}.txt"
    grep -Fq "F-SI07_COMMON_ROUTE_BAND_${threads} PASS" "$cur/t${threads}.txt"
  done
  echo "F-SI07_COMMON_ROUTE_O${opt}_1_2_4_8 PASS"
done

cmp "$BUILD/current-o0/serial_output.txt" "$BUILD/current-o2/serial_output.txt"
echo 'F-SI07_COMMON_ROUTE_O0_O2_IDENTITY PASS'

grep -Fq 'request%evaluation, request%boundary)' "$ADAPTER"
grep -Fq "route = 'explicit-top-provider-required'" "$ADAPTER"
python3 - "$ADAPTER" <<'PY'
from pathlib import Path
import re,sys
text=Path(sys.argv[1]).read_text()
a=text.index('  subroutine reference_richards_legacy_solve')
b=text.index('  end subroutine reference_richards_legacy_solve',a)
solve=text[a:b]
for name in ['gwlinp','dtold','itnumb','kmean','dimoca','fllowgwl','q0','hsurf','runots','flrunoff','ftoph']:
    if re.search(r'\b'+name+r'\b',solve,re.I):
        raise SystemExit(f'F-SI07_COMMON_ROUTE_GLOBAL_STATE_READ FAIL {name}')
print('F-SI07_COMMON_ROUTE_GLOBAL_STATE_READ NONE')
PY

echo 'F-SI07_COMMON_ROUTE_GATE PASS'
