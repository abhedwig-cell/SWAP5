#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fsi13-bottom-reject-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

CONTRACT_SRC="$ROOT/src/solver/mod_soil_water_solver_contract.f90"
SOURCE_SINK="$ROOT/src/solver/mod_b110_source_sink_provider.f90"
ROOT_PROVIDER="$ROOT/src/solver/mod_b110_root_sink_provider.f90"
HEADCALC="$ROOT/src/legacy/b1_10_port/headcalc.f90"
ADAPTER="$ROOT/src/adapter/mod_reference_richards_legacy_binding.f90"
WORKER="$ROOT/src/runtime/mod_a23bu_worker_execution_context.f90"
WORKSPACE="$ROOT/src/solver/mod_reference_richards_workspace.f90"
STATE="$ROOT/src/solver/mod_reference_richards_state_binding.f90"
STUBS="$ROOT/tests/fsi/fsi04_real_headcalc_stubs.f90"
TOP_PROVIDER="$ROOT/tests/fsi/mod_fsi07_top_provider.f90"
B110_PROVIDER="$ROOT/src/solver/mod_b110_default_mvg_provider.f90"
BASE_DRIVER="$ROOT/tests/fsi/test_fsi09_b110_common_parallel.F90"
DRIVER="$BUILD/test_fsi13_bottom_mode_reject.F90"

python3 - "$BASE_DRIVER" "$DRIVER" <<'PY'
from pathlib import Path
import sys
s=Path(sys.argv[1]).read_text()
s=s.replace('program test_fsi09_b110_common_parallel','program test_fsi13_bottom_mode_reject',1)
s=s.replace('end program test_fsi09_b110_common_parallel','end program test_fsi13_bottom_mode_reject',1)
s=s.replace('use mod_fsi08_provider_fixture, only: fsi08_source_sink_provider_t',
'''use mod_b110_source_sink_provider, only: b110_source_sink_provider_t, bind_b110_source_sink_provider\n  use mod_b110_root_sink_provider, only: b110_root_sink_provider_t, bind_b110_root_sink_provider''')
s=s.replace('type(fsi08_source_sink_provider_t), target :: source_sink(8)',
'''type(b110_source_sink_provider_t), target :: source_sink(8)\n  type(b110_root_sink_provider_t), target :: root_sink(8)\n  real(real64), target :: fsi13_qdra(2,numnod,8), fsi13_qssdi(numnod,8)\n  real(real64), target :: fsi13_zero_root(numnod,8), fsi13_qrot(numnod,8)''')
old='''       source_sink(column)%source_value = 0.0_real64\n       source_sink(column)%sink_value = 0.0_real64\n       top_provider(column)%surface_tracks_head = .true.'''
new='''       do node = 1, numnod\n          fsi13_qdra(1,node,column) = scale(real(column*node,real64),-10)\n          fsi13_qdra(2,node,column) = -scale(real(column+node,real64),-12)\n          fsi13_qrot(node,column) = scale(real(2*column+node,real64),-14)\n          fsi13_zero_root(node,column) = 0.0_real64\n          fsi13_qssdi(node,column) = fsi13_qdra(1,node,column) + fsi13_qdra(2,node,column) + fsi13_qrot(node,column)\n       end do\n       call bind_b110_source_sink_provider(source_sink(column), fsi13_qdra(:,:,column), &\n            fsi13_qssdi(:,column), fsi13_zero_root(:,column))\n       call bind_b110_root_sink_provider(root_sink(column), fsi13_qrot(:,column))\n       top_provider(column)%surface_tracks_head = .true.'''
if old not in s: raise SystemExit('F-SI13 reject provider marker missing')
s=s.replace(old,new,1)
marker='request%evaluation%source_sink => source_sink(column)'
if marker not in s: raise SystemExit('F-SI13 reject request provider marker missing')
s=s.replace(marker,marker+'\n    request%evaluation%root_sink => root_sink(column)',1)
marker='  call run_serial_baseline(failures)'
check='''  requests(1)%boundary%bottom_mode = 5\n  call prepare_workspace(serial_ws(1), 1)\n  call serial_solvers(1)%solve(requests(1), serial_ws(1), serial_results(1))\n  if (serial_results(1)%status /= SW_SOLVE_FAILED) error stop 'F-SI13 unsupported bottom mode was accepted'\n  if (trim(serial_results(1)%diagnostics%route) /= 'legacy-bottom-mode-deferred') &\n       error stop 'F-SI13 wrong unsupported bottom-mode rejection route'\n  if (serial_ws(1)%legacy_worker%diagnostics%headcalc_calls /= 0) &\n       error stop 'F-SI13 unsupported bottom mode reached HeadCalc'\n  print *, 'F-SI13_UNSUPPORTED_BOTTOM_MODE_FAILCLOSED PASS'\n  stop\n\n  call run_serial_baseline(failures)'''
if marker not in s: raise SystemExit('F-SI13 reject execution marker missing')
s=s.replace(marker,check,1)
Path(sys.argv[2]).write_text(s)
PY

grep -Fq 'request%evaluation%root_sink => root_sink(column)' "$DRIVER"
grep -Fq 'bottom_mode = 5' "$DRIVER"
grep -Fq 'legacy-bottom-mode-deferred' "$DRIVER"

OMP=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow -fopenmp)
for opt in 0 2; do
  out="$BUILD/o$opt"; mkdir -p "$out"
  gfortran "${OMP[@]}" -O"$opt" -J "$out" -I "$out" -c "$STUBS" -o "$out/stubs.o"
  gfortran "${OMP[@]}" -O"$opt" -J "$out" -I "$out" -c "$WORKER" -o "$out/worker.o"
  gfortran "${OMP[@]}" -O"$opt" -J "$out" -I "$out" -c "$CONTRACT_SRC" -o "$out/contract.o"
  gfortran "${OMP[@]}" -O"$opt" -J "$out" -I "$out" -c "$WORKSPACE" -o "$out/workspace.o"
  gfortran "${OMP[@]}" -O"$opt" -J "$out" -I "$out" -c "$STATE" -o "$out/state.o"
  gfortran "${OMP[@]}" -O"$opt" -J "$out" -I "$out" -c "$TOP_PROVIDER" -o "$out/top.o"
  gfortran "${OMP[@]}" -Werror -O"$opt" -J "$out" -I "$out" -c "$B110_PROVIDER" -o "$out/mvg.o"
  gfortran "${OMP[@]}" -Werror -O"$opt" -J "$out" -I "$out" -c "$SOURCE_SINK" -o "$out/process.o"
  gfortran "${OMP[@]}" -Werror -O"$opt" -J "$out" -I "$out" -c "$ROOT_PROVIDER" -o "$out/root.o"
  gfortran "${OMP[@]}" -O"$opt" -J "$out" -I "$out" -c "$HEADCALC" -o "$out/headcalc.o"
  gfortran "${OMP[@]}" -O"$opt" -J "$out" -I "$out" -c "$ADAPTER" -o "$out/adapter.o"
  gfortran "${OMP[@]}" -Werror -O"$opt" -J "$out" -I "$out" -c "$DRIVER" -o "$out/driver.o"
  gfortran "${OMP[@]}" -O"$opt" "$out/driver.o" "$out/adapter.o" "$out/headcalc.o" "$out/root.o" \
    "$out/process.o" "$out/mvg.o" "$out/top.o" "$out/state.o" "$out/workspace.o" "$out/contract.o" \
    "$out/worker.o" "$out/stubs.o" -o "$out/test"
  timeout 30s env OMP_NUM_THREADS=1 OMP_DYNAMIC=false "$out/test" > "$out/output.txt"
  grep -Fq 'F-SI13_UNSUPPORTED_BOTTOM_MODE_FAILCLOSED PASS' "$out/output.txt"
  echo "F-SI13_UNSUPPORTED_BOTTOM_MODE_FAILCLOSED_O${opt} PASS"
done
cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
echo 'F-SI13_UNSUPPORTED_BOTTOM_MODE_O0_O2_IDENTITY PASS'
echo 'F-SI13_BOTTOM_MODE_REJECT_GATE PASS'
