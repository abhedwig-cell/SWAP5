#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BASE="2fa63c41a4d7248ab7f4b5af46f72caddfda4f29"
BUILD="${TMPDIR:-/tmp}/swap5-fsi07-gate-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

HEADCALC="$ROOT/src/legacy/b1_10_port/headcalc.f90"
ADAPTER="$ROOT/src/adapter/mod_reference_richards_legacy_binding.f90"
WORKER="$ROOT/src/runtime/mod_a23bu_worker_execution_context.f90"
TRANSACTION="$ROOT/src/transaction/mod_transaction_reference.f90"
CONTRACT="$ROOT/src/solver/mod_soil_water_solver_contract.f90"
WORKSPACE="$ROOT/src/solver/mod_reference_richards_workspace.f90"
STATE="$ROOT/src/solver/mod_reference_richards_state_binding.f90"
STATE_TEST="$ROOT/tests/fsi/test_fsi07_state_binding.f90"
DRIVER="$ROOT/tests/fsi/test_fsi07_real_state_binding.F90"
STUB_BASE="$ROOT/tests/fsi/fsi04_real_headcalc_stubs.f90"
FSI03_STUBS="$ROOT/tests/fsi/fsi03_legacy_binding_stubs.f90"
FSI03_TEST="$ROOT/tests/fsi/test_fsi03_reference_binding.f90"
OWNERSHIP="$ROOT/integration/f-si/F-SI07_STATE_BINDING_CONTRACT.json"

# F-KT-owned and previously qualified common solver/workspace sources must not drift.
for path in \
  src/runtime/mod_a23bu_worker_execution_context.f90 \
  src/transaction/mod_transaction_reference.f90 \
  src/solver/mod_soil_water_solver_contract.f90 \
  src/solver/mod_reference_richards_workspace.f90; do
  [[ "$(git rev-parse "$BASE:$path")" == "$(git rev-parse "HEAD:$path")" ]] || {
    echo "F-SI07_PROTECTED_SOURCE FAIL changed $path" >&2; exit 1; }
done

[[ "$(git rev-parse HEAD:src/legacy/b1_10_port/headcalc.f90)" == "9ba77a52cd88f3cfe838d342d04092990e59ce3a" ]] || { echo 'F-SI07_PIN FAIL HeadCalc' >&2; exit 1; }
[[ "$(git rev-parse HEAD:src/adapter/mod_reference_richards_legacy_binding.f90)" == "33bed56161dbc278febe869df0fa2079ad378914" ]] || { echo 'F-SI07_PIN FAIL adapter' >&2; exit 1; }
[[ "$(git rev-parse HEAD:src/solver/mod_reference_richards_state_binding.f90)" == "7de02815e7c554077bcd41f973f15b99d32b7d09" ]] || { echo 'F-SI07_PIN FAIL state binding' >&2; exit 1; }

python3 - "$OWNERSHIP" "$HEADCALC" "$ADAPTER" <<'PY'
import json, pathlib, re, sys
j=json.loads(pathlib.Path(sys.argv[1]).read_text())
assert j['decision']=='EXPLICIT_REFERENCE_ATTEMPT_STATE_BINDING_OUTSIDE_COMMITTED_STATE'
assert j['admission']['full_parallel_reference_admitted'] is False
assert 'nstep' not in sum(j['attempt_state_fields'].values(), [])
h=pathlib.Path(sys.argv[2]).read_text()
a=pathlib.Path(sys.argv[3]).read_text()
assert 'subroutine headcalc(worker, fsi_workspace, history, state_binding)' in h
assert 'st => state_binding' in h
assert 'call fsi07_publish_state_to_legacy()' in h
assert 'call fsi07_absorb_state_from_legacy()' in h
assert 'do solver_numbit = 1, MaxIt1' in h
assert 'st%numbit = solver_numbit' in h
assert 'ws%state%h = request%base_state%pressure_head' in a
assert 'ws%state%theta = request%base_state%water_content' in a
assert 'result%candidate_state%pressure_head = ws%state%h' in a
assert 'h(1:numnod) = request%base_state%pressure_head' not in a
assert 'theta(1:numnod) = request%base_state%water_content' not in a
# Between state selection and CONTAINS, direct mutable Richards state must use st%.
body=h.split('canonical_trial = present(worker)',1)[1].split('\ncontains\n',1)[0]
for raw in body.splitlines():
    code=raw.split('!',1)[0]
    for name in ('h','theta','hm1','thetm1','k','kmean','dimoca','pond','pondm1','gwl','gwlm1','qtop','qbot','hbot','gwlinp','fllowgwl','fldecdt','numbit'):
        if re.search(rf'(?<![%A-Za-z0-9_]){name}(?![A-Za-z0-9_])', code, re.I):
            raise SystemExit(f'F-SI07_DIRECT_STATE FAIL {name}: {raw}')
print('F-SI07_STATIC_STATE_BINDING PASS')
PY

# Type ownership/deep-copy behavior at O0/O2.
for opt in 0 2; do
  out="$BUILD/state-o$opt"; mkdir -p "$out"
  gfortran -std=f2008 -Wall -Wextra -fcheck=all -fbacktrace -O"$opt" -J "$out" "$STATE" "$STATE_TEST" -o "$out/test"
  "$out/test" > "$out/output.txt"
  grep -Fq 'F-SI07_STATE_BINDING PASS' "$out/output.txt"
done
cmp "$BUILD/state-o0/output.txt" "$BUILD/state-o2/output.txt"
echo 'F-SI07_STATE_TYPE_O0_O2 PASS'

# Real HeadCalc replay fixture with normal and forced band fallback routes.
STUBS="$BUILD/fsi07_real_stubs.f90"
python3 - "$STUB_BASE" "$STUBS" <<'PY'
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

compile_replay() {
  local opt="$1" out="$2" source="$3" mode="$4"
  mkdir -p "$out"
  gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c "$STUBS" -o "$out/stubs.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c "$WORKER" -o "$out/worker.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c "$CONTRACT" -o "$out/contract.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c "$WORKSPACE" -o "$out/workspace.o"
  if [[ "$mode" == new ]]; then
    gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c "$STATE" -o "$out/state.o"
  fi
  gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c "$source" -o "$out/headcalc.o"
  local cpp=(-cpp)
  [[ "$mode" == pre ]] && cpp+=(-DFSI07_PREIMAGE)
  gfortran "${COMMON[@]}" -O"$opt" "${cpp[@]}" -J "$out" -I "$out" -c "$DRIVER" -o "$out/driver.o"
  objs=("$out/driver.o" "$out/headcalc.o" "$out/workspace.o" "$out/contract.o" "$out/worker.o" "$out/stubs.o")
  [[ "$mode" == new ]] && objs+=("$out/state.o")
  gfortran "${COMMON[@]}" -O"$opt" "${objs[@]}" -o "$out/replay"
}

for opt in 0 2; do
  pre="$BUILD/pre-o$opt"; new="$BUILD/new-o$opt"
  compile_replay "$opt" "$pre" "$PREIMAGE" pre
  compile_replay "$opt" "$new" "$HEADCALC" new
  "$pre/replay" > "$pre/output.txt"
  "$new/replay" > "$new/output.txt"
  cmp "$pre/output.txt" "$new/output.txt"
  grep -Fq 'F-SI07_REAL_STATE_BINDING PASS' "$new/output.txt"
  echo "F-SI07_REAL_REPLAY_O$opt PASS"
done
cmp "$BUILD/pre-o0/output.txt" "$BUILD/pre-o2/output.txt"
cmp "$BUILD/new-o0/output.txt" "$BUILD/new-o2/output.txt"
echo 'F-SI07_REAL_REPLAY_O0_O2_IDENTITY PASS'

# Adapter regression: mutate/read explicit state in the test double, never require request-state globals.
PATCHED_STUB="$BUILD/fsi03_state_stub.f90"
python3 - "$FSI03_STUBS" "$PATCHED_STUB" <<'PY'
from pathlib import Path
import sys
s=Path(sys.argv[1]).read_text()
needle='  integer :: numbit = 0\nend module variables\n'
replacement='''  integer :: numbit = 0
  real(real64) :: k(numnod) = 1.0_real64
  real(real64) :: kmean(numnod+1) = 1.0_real64
  real(real64) :: dimoca(numnod) = 0.0_real64
  real(real64) :: hbot = -100.0_real64, gwlinp = -5.0_real64
  logical :: fllowgwl = .false.
end module variables
'''
assert s.count(needle)==1
s=s.replace(needle,replacement,1)
start=s.index('subroutine headcalc(worker)')
end=s.index('end subroutine headcalc', start)+len('end subroutine headcalc')
new='''subroutine headcalc(worker, fsi_workspace, history, state_binding)
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_a23bu_worker_execution_context, only: a23bu_worker_context_t, a23bu_solver_history_t
  use mod_reference_richards_workspace, only: reference_richards_workspace_t
  use mod_reference_richards_state_binding, only: reference_richards_state_binding_t
  use fsi03_stub_control, only: headcalc_calls, request_retry, observed_head, observed_theta, observed_pond, observed_gwl
  implicit none
  type(a23bu_worker_context_t), intent(inout), optional :: worker
  type(reference_richards_workspace_t), target, intent(inout), optional :: fsi_workspace
  type(a23bu_solver_history_t), target, intent(inout), optional :: history
  type(reference_richards_state_binding_t), target, intent(inout), optional :: state_binding
  headcalc_calls = headcalc_calls + 1
  if (.not. present(state_binding)) error stop 'F-SI07 adapter test requires explicit state'
  observed_head = state_binding%h
  observed_theta = state_binding%theta
  observed_pond = state_binding%pond
  observed_gwl = state_binding%gwl
  state_binding%h = state_binding%h - 1.0_real64
  state_binding%theta = state_binding%theta + 0.01_real64
  state_binding%pond = state_binding%pond + 0.02_real64
  state_binding%gwl = state_binding%gwl - 0.03_real64
  state_binding%qtop = 1.25_real64
  state_binding%qbot = -0.75_real64
  state_binding%numbit = 4
  if (present(worker)) then
     worker%diagnostics%headcalc_calls = worker%diagnostics%headcalc_calls + 1
     worker%diagnostics%nonlinear_iterations = 4
     worker%diagnostics%jacobian_builds = 4
     worker%diagnostics%linear_solves = 4
     worker%diagnostics%backtracking_attempts = 6
     if (request_retry) then
        worker%control%request_dt_reduction = .true.
        worker%diagnostics%internal_retries = 1
     end if
  end if
  if (request_retry) state_binding%fldecdt = .true.
end subroutine headcalc'''
s=s[:start]+new+s[end:]
Path(sys.argv[2]).write_text(s)
PY
for opt in 0 2; do
  out="$BUILD/adapter-o$opt"; mkdir -p "$out"
  gfortran -std=f2008 -Wall -Wextra -fcheck=all -fbacktrace -O"$opt" -J "$out" \
    "$WORKER" "$CONTRACT" "$WORKSPACE" "$STATE" "$PATCHED_STUB" "$ADAPTER" "$FSI03_TEST" -o "$out/test"
  "$out/test" > "$out/output.txt"
  grep -Fq 'F-SI03_REFERENCE_BINDING PASS' "$out/output.txt"
done
cmp "$BUILD/adapter-o0/output.txt" "$BUILD/adapter-o2/output.txt"
echo 'F-SI07_ADAPTER_REQUEST_CANDIDATE_BINDING PASS'

# Transaction/worker boundary stays green.
bash "$ROOT/tests/fci/run_fci03_gate.sh" >/dev/null
echo 'F-SI07_FKT_BOUNDARY_REGRESSION PASS'

# Remaining process-global bridges are explicit blockers, not silently admitted concurrency.
grep -Fq 'call fsi07_publish_state_to_legacy()' "$HEADCALC"
grep -Fq 'call fsi07_absorb_state_from_legacy()' "$HEADCALC"
grep -Fq 'use MOD_top' "$HEADCALC"
grep -Fq 'use MOD_rootextraction' "$HEADCALC"
echo 'F-SI07_REAL_PARALLEL_ADMISSION BLOCKED_PROCESS_EVALUATION_GLOBALS'

echo 'F-SI07_GATE PASS'
