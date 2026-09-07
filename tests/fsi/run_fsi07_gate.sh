#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BASE="2fa63c41a4d7248ab7f4b5af46f72caddfda4f29"
BUILD="${TMPDIR:-/tmp}/swap5-fsi07-gate-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

HEADCALC="$ROOT/src/legacy/b1_10_port/headcalc.f90"
SOILWATER="$ROOT/src/legacy/b1_10_port/soilwater.f90"
WORKER="$ROOT/src/runtime/mod_a23bu_worker_execution_context.f90"
TRANSACTION="$ROOT/src/transaction/mod_transaction_reference.f90"
CONTRACT="$ROOT/src/solver/mod_soil_water_solver_contract.f90"
WORKSPACE="$ROOT/src/solver/mod_reference_richards_workspace.f90"
STATE="$ROOT/src/solver/mod_reference_richards_state_binding.f90"
ADAPTER="$ROOT/src/adapter/mod_reference_richards_legacy_binding.f90"
DRIVER="$ROOT/tests/fsi/test_fsi07_state_binding.F90"
FSI04_STUBS="$ROOT/tests/fsi/fsi04_real_headcalc_stubs.f90"
ADAPTER_STUBS="$ROOT/tests/fsi/fsi07_adapter_stubs.f90"
ADAPTER_TEST="$ROOT/tests/fsi/test_fsi07_adapter_binding.f90"
FSI02_TEST="$ROOT/tests/fsi/test_fsi02_solver_contract.f90"
SOILWATER_STUBS="$ROOT/tests/fsi/fsi06_soilwater_compile_stubs.f90"
OWNERSHIP="$ROOT/integration/f-si/F-SI07_STATE_BINDING_CONTRACT.json"

# F-SI07 may not change F-KT transaction/runtime ownership, the common solver
# API, or the already-qualified reference workspace layout.
for path in \
  src/runtime/mod_a23bu_worker_execution_context.f90 \
  src/transaction/mod_transaction_reference.f90 \
  src/solver/mod_soil_water_solver_contract.f90 \
  src/solver/mod_reference_richards_workspace.f90; do
  [[ "$(git rev-parse "$BASE:$path")" == "$(git rev-parse "HEAD:$path")" ]] || {
    echo "F-SI07_PROTECTED_SOURCE FAIL changed $path" >&2; exit 1; }
done

# Pin the production state-binding postimage.
[[ "$(git rev-parse HEAD:src/legacy/b1_10_port/headcalc.f90)" == "4d1a723bb4948cc611cf15df47366c968be90ebf" ]] || { echo 'F-SI07_PIN FAIL HeadCalc' >&2; exit 1; }
[[ "$(git rev-parse HEAD:src/legacy/b1_10_port/soilwater.f90)" == "0cd82e409bbf8de880320981b5c8cadf6559d847" ]] || { echo 'F-SI07_PIN FAIL SoilWater' >&2; exit 1; }
[[ "$(git rev-parse HEAD:src/adapter/mod_reference_richards_legacy_binding.f90)" == "f5334041764ae0d50732a146432572a920b27472" ]] || { echo 'F-SI07_PIN FAIL adapter' >&2; exit 1; }
[[ "$(git rev-parse HEAD:src/solver/mod_reference_richards_state_binding.f90)" == "0f7d726f1231584599b3e6838bf8cc0fb53a6814" ]] || { echo 'F-SI07_PIN FAIL state binding' >&2; exit 1; }

# Contract and structural source checks.
grep -Eq '^subroutine[[:space:]]+headcalc\(worker,[[:space:]]*fsi_workspace,[[:space:]]*history,[[:space:]]*state_binding\)' "$HEADCALC"
grep -Fq 'state => state_binding' "$HEADCALC"
grep -Fq 'do solver_numbit = 1, MaxIt1' "$HEADCALC"
! grep -Fq 'do state%numbit = 1, MaxIt1' "$HEADCALC"
grep -Fq 'call boundtop_state_bridge(2)' "$HEADCALC"
grep -Fq 'call initialize_reference_state_binding(state_binding, request)' "$ADAPTER"
grep -Fq 'call headcalc(ws%legacy_worker, ws%richards, call_history, state_binding)' "$ADAPTER"
python3 - "$OWNERSHIP" "$ADAPTER" <<'PY'
import json, pathlib, re, sys
contract=json.loads(pathlib.Path(sys.argv[1]).read_text())
assert contract['ownership']['persistent_column_owner'] is False
assert contract['ownership']['transaction_authority'] is False
assert contract['fkt_boundary']['shared_fkt_type_change'] is False
assert contract['provider_boundary']['real_parallel_headcalc_admission_expected_after_fsi07'] is False
text=pathlib.Path(sys.argv[2]).read_text()
a=text.index('  subroutine reference_richards_legacy_solve')
b=text.index('  end subroutine reference_richards_legacy_solve',a)
solve=text[a:b]
patterns=[
 r'^\s*h\s*\(', r'^\s*theta\s*\(', r'^\s*hm1\s*\(', r'^\s*thetm1\s*\(',
 r'^\s*pond\s*=', r'^\s*gwl\s*=', r'^\s*pondm1\s*=', r'^\s*gwlm1\s*=',
 r'^\s*qtop\s*=', r'^\s*qbot\s*=', r'^\s*fldecdt\s*=', r'^\s*numbit\s*='
]
for p in patterns:
    assert re.search(p,solve,re.M) is None, p
assert 'result%candidate_state%pressure_head = state_binding%h' in solve
assert 'result%top_flux = state_binding%qtop' in solve
print('F-SI07_ADAPTER_NO_WHOLE_SOLVE_GLOBAL_OVERLAY PASS')
PY

# Real HeadCalc fixture with a switch for the rare banded fallback.
STUBS="$BUILD/fsi07_real_stubs.f90"
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
assert s.count(marker)==1
s=s.replace(marker,insert,1)
old='  ierror = 0\nend subroutine tridag\n'
new='''  if (force_tridag_failure) then
    ierror = 1
  else
    ierror = 0
  end if
end subroutine tridag
'''
assert s.count(old)==1
s=s.replace(old,new,1)
Path(sys.argv[2]).write_text(s)
PY

PREIMAGE="$BUILD/headcalc_fsi06_preimage.f90"
git show "$BASE:src/legacy/b1_10_port/headcalc.f90" > "$PREIMAGE"
COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)

compile_preimage() {
  local opt="$1" out="$2"
  mkdir -p "$out"
  gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c "$STUBS" -o "$out/stubs.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c "$WORKER" -o "$out/worker.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c "$CONTRACT" -o "$out/contract.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c "$WORKSPACE" -o "$out/workspace.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c "$PREIMAGE" -o "$out/headcalc.o"
  gfortran "${COMMON[@]}" -O"$opt" -cpp -DFSI07_PREIMAGE -J "$out" -I "$out" -c "$DRIVER" -o "$out/driver.o"
  gfortran "${COMMON[@]}" -O"$opt" "$out/driver.o" "$out/headcalc.o" "$out/workspace.o" "$out/contract.o" \
    "$out/worker.o" "$out/stubs.o" -o "$out/replay"
}

compile_new() {
  local opt="$1" out="$2" mode="$3"
  mkdir -p "$out"
  gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c "$STUBS" -o "$out/stubs.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c "$WORKER" -o "$out/worker.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c "$CONTRACT" -o "$out/contract.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c "$WORKSPACE" -o "$out/workspace.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c "$STATE" -o "$out/state.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c "$HEADCALC" -o "$out/headcalc.o"
  local cpp=(-cpp)
  [[ "$mode" == compat ]] && cpp+=(-DFSI07_COMPAT_CALL)
  gfortran "${COMMON[@]}" -O"$opt" "${cpp[@]}" -J "$out" -I "$out" -c "$DRIVER" -o "$out/driver.o"
  gfortran "${COMMON[@]}" -O"$opt" "$out/driver.o" "$out/headcalc.o" "$out/state.o" "$out/workspace.o" \
    "$out/contract.o" "$out/worker.o" "$out/stubs.o" -o "$out/replay"
}

for opt in 0 2; do
  pre="$BUILD/pre-o$opt"; explicit="$BUILD/explicit-o$opt"; compat="$BUILD/compat-o$opt"
  compile_preimage "$opt" "$pre"
  compile_new "$opt" "$explicit" explicit
  compile_new "$opt" "$compat" compat
  "$pre/replay" > "$pre/output.txt"
  "$explicit/replay" > "$explicit/output.txt"
  "$compat/replay" > "$compat/output.txt"
  cmp "$pre/output.txt" "$explicit/output.txt"
  cmp "$pre/output.txt" "$compat/output.txt"
  grep -Fq 'F-SI07_STATE_BINDING PASS' "$explicit/output.txt"
  echo "F-SI07_REAL_REPLAY_O$opt PASS"
done
cmp "$BUILD/pre-o0/output.txt" "$BUILD/pre-o2/output.txt"
cmp "$BUILD/explicit-o0/output.txt" "$BUILD/explicit-o2/output.txt"
cmp "$BUILD/compat-o0/output.txt" "$BUILD/compat-o2/output.txt"
echo 'F-SI07_O0_O2_IDENTITY PASS'

# Common adapter: request/candidate transport is through explicit state binding;
# the testdouble mutates only that binding and legacy global sentinels must stay unchanged.
for opt in 0 2; do
  out="$BUILD/adapter-o$opt"; mkdir -p "$out"
  FLAGS=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -O"$opt" -J "$out" -I "$out")
  gfortran "${FLAGS[@]}" -c "$WORKER" -o "$out/worker.o"
  gfortran "${FLAGS[@]}" -c "$CONTRACT" -o "$out/contract.o"
  gfortran "${FLAGS[@]}" -c "$WORKSPACE" -o "$out/workspace.o"
  gfortran "${FLAGS[@]}" -c "$STATE" -o "$out/state.o"
  gfortran "${FLAGS[@]}" -c "$ADAPTER_STUBS" -o "$out/stubs.o"
  gfortran "${FLAGS[@]}" -c "$ADAPTER" -o "$out/adapter.o"
  gfortran "${FLAGS[@]}" -c "$ADAPTER_TEST" -o "$out/test.o"
  gfortran -O"$opt" "$out/test.o" "$out/adapter.o" "$out/stubs.o" "$out/state.o" "$out/workspace.o" \
    "$out/contract.o" "$out/worker.o" -o "$out/test"
  "$out/test" > "$out/output.txt"
  grep -Fq 'F-SI07_ADAPTER_BINDING PASS' "$out/output.txt"
done
cmp "$BUILD/adapter-o0/output.txt" "$BUILD/adapter-o2/output.txt"
echo 'F-SI07_ADAPTER_BINDING_O0_O2 PASS'

# The changed legacy SoilWater interface must still compile at O0/O2.
for opt in 0 2; do
  out="$BUILD/soilwater-o$opt"; mkdir -p "$out"
  FLAGS=(-std=f2008 -ffree-line-length-none -Wall -Wextra -O"$opt" -J "$out" -I "$out")
  gfortran "${FLAGS[@]}" -c "$SOILWATER_STUBS" -o "$out/stubs.o"
  gfortran "${FLAGS[@]}" -c "$WORKER" -o "$out/worker.o"
  gfortran "${FLAGS[@]}" -c "$CONTRACT" -o "$out/contract.o"
  gfortran "${FLAGS[@]}" -c "$WORKSPACE" -o "$out/workspace.o"
  gfortran "${FLAGS[@]}" -c "$STATE" -o "$out/state.o"
  gfortran "${FLAGS[@]}" -c "$SOILWATER" -o "$out/soilwater.o"
done
echo 'F-SI07_SOILWATER_COMPILE_O0_O2 PASS'

# Reference workspace isolation remains green at 1/2/4/8 workers.
for opt in 0 2; do
  out="$BUILD/workspace-o$opt"; mkdir -p "$out"
  gfortran -std=f2008 -Wall -Wextra -Werror -fcheck=all -fbacktrace -fopenmp -O"$opt" -J "$out" \
    "$CONTRACT" "$WORKSPACE" "$FSI02_TEST" -o "$out/test"
  for threads in 1 2 4 8; do OMP_NUM_THREADS="$threads" "$out/test" >/dev/null; done
done
echo 'F-SI07_WORKSPACE_1_2_4_8 PASS'

# Transaction/worker ownership boundary is unchanged.
bash "$ROOT/tests/fci/run_fci03_gate.sh" >/dev/null
echo 'F-SI07_FKT_BOUNDARY_REGRESSION PASS'

# Full real HeadCalc parallel admission still fails closed. Mutable whole-solve
# state is isolated now, but direct legacy process/provider calls remain shared.
grep -Fq 'call boundtop_state_bridge(2)' "$HEADCALC"
grep -Fq 'use MOD_MvG' "$HEADCALC"
grep -Fq 'use MOD_drain' "$HEADCALC"
grep -Fq 'use MOD_irrigation' "$HEADCALC"
echo 'F-SI07_REAL_PARALLEL_ADMISSION BLOCKED_LEGACY_PROVIDER_GLOBALS'
echo 'F-SI07_GATE PASS'
