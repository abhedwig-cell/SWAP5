#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BASE="0227ae94edc3364b013f831f1efa6aaccac29b11"
BUILD="${TMPDIR:-/tmp}/swap5-fsi06-gate-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

HEADCALC="$ROOT/src/legacy/b1_10_port/headcalc.f90"
SOILWATER="$ROOT/src/legacy/b1_10_port/soilwater.f90"
WORKER="$ROOT/src/runtime/mod_a23bu_worker_execution_context.f90"
TRANSACTION="$ROOT/src/transaction/mod_transaction_reference.f90"
CONTRACT="$ROOT/src/solver/mod_soil_water_solver_contract.f90"
WORKSPACE="$ROOT/src/solver/mod_reference_richards_workspace.f90"
ADAPTER="$ROOT/src/adapter/mod_reference_richards_legacy_binding.f90"
DRIVER="$ROOT/tests/fsi/test_fsi06_history_isolation.F90"
FSI04_STUBS="$ROOT/tests/fsi/fsi04_real_headcalc_stubs.f90"
FSI03_STUBS="$ROOT/tests/fsi/fsi03_legacy_binding_stubs.f90"
FSI03_TEST="$ROOT/tests/fsi/test_fsi03_reference_binding.f90"
FSI02_TEST="$ROOT/tests/fsi/test_fsi02_solver_contract.f90"
SOILWATER_STUBS="$ROOT/tests/fsi/fsi06_soilwater_compile_stubs.f90"
OWNERSHIP="$ROOT/integration/f-si/F-SI06_HISTORY_OWNERSHIP_CONTRACT.json"

# F-SI06 does not modify F-KT transaction semantics, the shared worker type,
# common solver contract or F-SI05 workspace layout.
for path in \
  src/runtime/mod_a23bu_worker_execution_context.f90 \
  src/transaction/mod_transaction_reference.f90 \
  src/solver/mod_soil_water_solver_contract.f90 \
  src/solver/mod_reference_richards_workspace.f90; do
  [[ "$(git rev-parse "$BASE:$path")" == "$(git rev-parse "HEAD:$path")" ]] || {
    echo "F-SI06_PROTECTED_SOURCE FAIL changed $path" >&2; exit 1; }
done

# Pin the materialized F-SI06 production source.
[[ "$(git rev-parse HEAD:src/legacy/b1_10_port/headcalc.f90)" == "38de52dd9f13b70a61f418c29a5c2e4bc9a449a9" ]] || { echo 'F-SI06_PIN FAIL HeadCalc' >&2; exit 1; }
[[ "$(git rev-parse HEAD:src/legacy/b1_10_port/soilwater.f90)" == "aa072804768b7a982b275d3a7d6988bfed6b9faa" ]] || { echo 'F-SI06_PIN FAIL SoilWater' >&2; exit 1; }
[[ "$(git rev-parse HEAD:src/adapter/mod_reference_richards_legacy_binding.f90)" == "f60f7ef2d60ccb8cc78e80d56ef88a739e50ab2e" ]] || { echo 'F-SI06_PIN FAIL adapter' >&2; exit 1; }

# Hidden HeadCalc singleton/history ownership must be gone from HeadCalc.
! grep -Fq 'save :: legacy_worker' "$HEADCALC"
! grep -Fq 'ctx%history%' "$HEADCALC"
grep -Eq '^subroutine[[:space:]]+headcalc\(worker,[[:space:]]*fsi_workspace,[[:space:]]*history\)' "$HEADCALC"
grep -Fq 'hist => history' "$HEADCALC"
grep -Fq 'hist => local_history' "$HEADCALC"

# Legacy compatibility is explicit in the legacy caller; common solver history
# is call-local and does not become persistent worker scratch.
grep -Fq 'type(a23bu_worker_context_t), save :: legacy_headcalc_worker' "$SOILWATER"
grep -Fq 'type(a23bu_solver_history_t), save :: legacy_headcalc_history' "$SOILWATER"
grep -Fq 'call headcalc(worker, history=worker%history)' "$SOILWATER"
grep -Fq 'call headcalc(legacy_headcalc_worker, history=legacy_headcalc_history)' "$SOILWATER"
grep -Fq 'type(a23bu_solver_history_t) :: call_history' "$ADAPTER"
grep -Fq 'call headcalc(ws%legacy_worker, ws%richards, call_history)' "$ADAPTER"
python3 - "$OWNERSHIP" <<'PY'
import json, pathlib, sys
j=json.loads(pathlib.Path(sys.argv[1]).read_text())
assert j['ownership']['nstep']['worker_scratch'] is False
assert j['ownership']['nstep']['common_reference_route_now'].startswith('not_consumed')
assert j['fkt_boundary']['shared_fkt_type_change'] is False
assert j['fkt_boundary']['transaction_semantics_change'] is False
print('F-SI06_OWNERSHIP_CONTRACT PASS')
PY

# Reuse the real HeadCalc focused fixture and force the rare band fallback.
STUBS="$BUILD/fsi06_real_stubs.f90"
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

PREIMAGE="$BUILD/headcalc_fsi05_preimage.f90"
git show "$BASE:src/legacy/b1_10_port/headcalc.f90" > "$PREIMAGE"
COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)

compile_replay() {
  local opt="$1" out="$2" source="$3" mode="$4"
  mkdir -p "$out"
  gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c "$STUBS" -o "$out/stubs.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c "$WORKER" -o "$out/worker.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c "$CONTRACT" -o "$out/contract.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c "$WORKSPACE" -o "$out/workspace.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c "$source" -o "$out/headcalc.o"
  local cpp=(-cpp)
  [[ "$mode" == pre ]] && cpp+=(-DFSI06_PREIMAGE)
  [[ "$mode" == compat ]] && cpp+=(-DFSI06_COMPAT_CALL)
  gfortran "${COMMON[@]}" -O"$opt" "${cpp[@]}" -J "$out" -I "$out" -c "$DRIVER" -o "$out/driver.o"
  gfortran "${COMMON[@]}" -O"$opt" "$out/driver.o" "$out/headcalc.o" "$out/workspace.o" "$out/contract.o" \
    "$out/worker.o" "$out/stubs.o" -o "$out/replay"
}

for opt in 0 2; do
  pre="$BUILD/pre-o$opt"; explicit="$BUILD/explicit-o$opt"; compat="$BUILD/compat-o$opt"
  compile_replay "$opt" "$pre" "$PREIMAGE" pre
  compile_replay "$opt" "$explicit" "$HEADCALC" explicit
  compile_replay "$opt" "$compat" "$HEADCALC" compat
  "$pre/replay" > "$pre/output.txt"
  "$explicit/replay" > "$explicit/output.txt"
  "$compat/replay" > "$compat/output.txt"
  cmp "$pre/output.txt" "$explicit/output.txt"
  cmp "$pre/output.txt" "$compat/output.txt"
  grep -Fq 'F-SI06_HISTORY_ISOLATION PASS' "$explicit/output.txt"
  echo "F-SI06_REAL_REPLAY_O$opt PASS"
done
cmp "$BUILD/pre-o0/output.txt" "$BUILD/pre-o2/output.txt"
cmp "$BUILD/explicit-o0/output.txt" "$BUILD/explicit-o2/output.txt"
cmp "$BUILD/compat-o0/output.txt" "$BUILD/compat-o2/output.txt"
echo 'F-SI06_O0_O2_IDENTITY PASS'

# Common adapter history isolation: the test double deliberately mutates the
# explicit history argument. The persistent legacy_worker history must remain
# untouched, proving the adapter supplies a call-local history carrier.
FSI03_PATCHED="$BUILD/fsi03_history_stub.f90"
python3 - "$FSI03_STUBS" "$FSI03_PATCHED" <<'PY'
from pathlib import Path
import sys
s=Path(sys.argv[1]).read_text()
s=s.replace('subroutine headcalc(worker)\n', 'subroutine headcalc(worker, fsi_workspace, history)\n', 1)
s=s.replace('  use mod_a23bu_worker_execution_context, only: a23bu_worker_context_t\n',
'''  use mod_a23bu_worker_execution_context, only: a23bu_worker_context_t, a23bu_solver_history_t
  use mod_reference_richards_workspace, only: reference_richards_workspace_t
''', 1)
s=s.replace('  type(a23bu_worker_context_t), intent(inout), optional :: worker\n',
'''  type(a23bu_worker_context_t), intent(inout), optional :: worker
  type(reference_richards_workspace_t), target, intent(inout), optional :: fsi_workspace
  type(a23bu_solver_history_t), target, intent(inout), optional :: history
''', 1)
needle='  headcalc_calls = headcalc_calls + 1\n'
insert='''  headcalc_calls = headcalc_calls + 1
  if (present(history)) then
     history%flwarn = .not. history%flwarn
     history%iwarn = history%iwarn + 1000
     history%nstep = history%nstep + 1000
  end if
'''
assert s.count(needle)==1
s=s.replace(needle,insert,1)
Path(sys.argv[2]).write_text(s)
PY
FSI03_TEST_PATCHED="$BUILD/fsi03_history_test.f90"
python3 - "$FSI03_TEST" "$FSI03_TEST_PATCHED" <<'PY'
from pathlib import Path
import sys
s=Path(sys.argv[1]).read_text()
needle='  use mod_reference_richards_legacy_binding\n'
s=s.replace(needle, needle+'  use mod_a23bu_worker_execution_context, only: a23bu_initialize_worker\n', 1)
needle='  call seed_legacy_sentinels()\n'
insert='''  call a23bu_initialize_worker(workspace%legacy_worker, numnod)
  workspace%legacy_worker%history%flwarn = .false.
  workspace%legacy_worker%history%iwarn = 777
  workspace%legacy_worker%history%nstep = 888
  call seed_legacy_sentinels()
'''
assert s.count(needle)==1
s=s.replace(needle,insert,1)
needle='  call expect(trim(result_a1%diagnostics%route) == \'legacy-reference-bound\', failures)\n'
insert=needle+'''  call expect(.not. workspace%legacy_worker%history%flwarn, failures)
  call expect(workspace%legacy_worker%history%iwarn == 777, failures)
  call expect(workspace%legacy_worker%history%nstep == 888, failures)
'''
assert s.count(needle)==1
s=s.replace(needle,insert,1)
needle='  call expect_same_candidate(result_a1, result_a2, failures)\n\n  request_retry = .true.\n'
insert='''  call expect_same_candidate(result_a1, result_a2, failures)
  call expect(.not. workspace%legacy_worker%history%flwarn, failures)
  call expect(workspace%legacy_worker%history%iwarn == 777, failures)
  call expect(workspace%legacy_worker%history%nstep == 888, failures)

  request_retry = .true.
'''
assert s.count(needle)==1
s=s.replace(needle,insert,1)
Path(sys.argv[2]).write_text(s)
PY
for opt in 0 2; do
  out="$BUILD/adapter-o$opt"; mkdir -p "$out"
  gfortran -std=f2008 -Wall -Wextra -fcheck=all -fbacktrace -O"$opt" -J "$out" \
    "$WORKER" "$CONTRACT" "$WORKSPACE" "$FSI03_PATCHED" "$ADAPTER" "$FSI03_TEST_PATCHED" -o "$out/fsi03_history"
  "$out/fsi03_history" > "$out/output.txt"
  grep -Fq 'F-SI03_REFERENCE_BINDING PASS' "$out/output.txt"
done
cmp "$BUILD/adapter-o0/output.txt" "$BUILD/adapter-o2/output.txt"
echo 'F-SI06_ADAPTER_HISTORY_ISOLATION PASS'

# Compile the changed production MOD_SoilWater interface itself at O0/O2. This
# is a compile-only seam check with minimal deterministic module stubs.
for opt in 0 2; do
  out="$BUILD/soilwater-o$opt"; mkdir -p "$out"
  gfortran -std=f2008 -ffree-line-length-none -Wall -Wextra -O"$opt" -J "$out" -I "$out" -c "$SOILWATER_STUBS" -o "$out/stubs.o"
  gfortran -std=f2008 -ffree-line-length-none -Wall -Wextra -O"$opt" -J "$out" -I "$out" -c "$WORKER" -o "$out/worker.o"
  gfortran -std=f2008 -ffree-line-length-none -Wall -Wextra -O"$opt" -J "$out" -I "$out" -c "$CONTRACT" -o "$out/contract.o"
  gfortran -std=f2008 -ffree-line-length-none -Wall -Wextra -O"$opt" -J "$out" -I "$out" -c "$WORKSPACE" -o "$out/workspace.o"
  gfortran -std=f2008 -ffree-line-length-none -Wall -Wextra -O"$opt" -J "$out" -I "$out" -c "$SOILWATER" -o "$out/soilwater.o"
done
echo 'F-SI06_SOILWATER_COMPILE_O0_O2 PASS'

# The workspace type itself remains isolated under 1/2/4/8 OpenMP workers.
for opt in 0 2; do
  out="$BUILD/workspace-o$opt"; mkdir -p "$out"
  gfortran -std=f2008 -Wall -Wextra -Werror -fcheck=all -fbacktrace -fopenmp -O"$opt" -J "$out" \
    "$CONTRACT" "$WORKSPACE" "$FSI02_TEST" -o "$out/fsi02_test"
  for threads in 1 2 4 8; do OMP_NUM_THREADS="$threads" "$out/fsi02_test" >/dev/null; done
done
echo 'F-SI06_WORKSPACE_1_2_4_8 PASS'

# Full real HeadCalc parallel admission remains fail-closed because the common
# legacy adapter still translates each request through mutable module globals.
for token in \
  'h(1:numnod) = request%base_state%pressure_head' \
  'theta(1:numnod) = request%base_state%water_content' \
  'pond = request%base_state%ponding_depth' \
  'gwl = request%base_state%groundwater_level'; do
  grep -Fq "$token" "$ADAPTER" || { echo "F-SI06_PARALLEL_BLOCKER unexpectedly absent: $token" >&2; exit 1; }
done
echo 'F-SI06_REAL_PARALLEL_ADMISSION BLOCKED_SHARED_LEGACY_GLOBAL_TRANSLATION'

# Re-run the unchanged F-KT transaction/worker substrate gate.
bash "$ROOT/tests/fci/run_fci03_gate.sh" >/dev/null
echo 'F-SI06_FKT_BOUNDARY_REGRESSION PASS'

echo 'F-SI06_GATE PASS'
