#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
FSI11_HEAD="9f488bfb4805791e9513bfa7146c59d38423917b"
BUILD="${TMPDIR:-/tmp}/swap5-fsi12-controls-$$"
mkdir -p "$BUILD"
cleanup() {
  for wt in "$BUILD/fsi11-direct" "$BUILD/fsi11-regression"; do
    if git -C "$ROOT" worktree list --porcelain | grep -Fq "worktree $wt"; then
      git -C "$ROOT" worktree remove --force "$wt" >/dev/null 2>&1 || true
    fi
  done
  rm -rf "$BUILD"
}
trap cleanup EXIT
cd "$ROOT"

CONTRACT="$ROOT/src/solver/mod_soil_water_solver_contract.f90"
HEADCALC="$ROOT/src/legacy/b1_10_port/headcalc.f90"
ADAPTER="$ROOT/src/adapter/mod_reference_richards_legacy_binding.f90"
WORKER="$ROOT/src/runtime/mod_a23bu_worker_execution_context.f90"
WORKSPACE="$ROOT/src/solver/mod_reference_richards_workspace.f90"
STATE="$ROOT/src/solver/mod_reference_richards_state_binding.f90"
STUBS="$ROOT/tests/fsi/fsi04_real_headcalc_stubs.f90"
TOP_PROVIDER="$ROOT/tests/fsi/mod_fsi07_top_provider.f90"
B110_PROVIDER="$ROOT/src/solver/mod_b110_default_mvg_provider.f90"
SOURCE_SINK="$ROOT/src/solver/mod_b110_source_sink_provider.f90"
ROOT_SINK="$ROOT/src/solver/mod_b110_root_sink_provider.f90"
BASE_DRIVER="$ROOT/tests/fsi/test_fsi09_b110_common_parallel.F90"
DIRECT_DRIVER="$ROOT/tests/fsi/test_fsi04_real_headcalc_replay.F90"
OWNER="$ROOT/integration/f-si/F-SI12_CONTROL_BINDING_CONTRACT.json"

# F-SI12 production scope is exactly HeadCalc + the F-SI reference adapter.
changed_src="$(git diff --name-only "$FSI11_HEAD"...HEAD -- src | sort)"
expected_src=$'src/adapter/mod_reference_richards_legacy_binding.f90\nsrc/legacy/b1_10_port/headcalc.f90'
if [[ "$changed_src" != "$expected_src" ]]; then
  echo 'F-SI12_SCOPE FAIL unexpected production-source delta:' >&2
  printf '%s\n' "$changed_src" >&2
  exit 1
fi
for path in \
  src/runtime/mod_a23bu_worker_execution_context.f90 \
  src/transaction/mod_transaction_reference.f90 \
  src/solver/mod_soil_water_solver_contract.f90 \
  src/solver/mod_reference_richards_workspace.f90 \
  src/solver/mod_reference_richards_state_binding.f90 \
  src/solver/mod_b110_default_mvg_provider.f90 \
  src/solver/mod_b110_source_sink_provider.f90 \
  src/solver/mod_b110_root_sink_provider.f90; do
  [[ "$(git rev-parse "$FSI11_HEAD:$path")" == "$(git rev-parse "HEAD:$path")" ]] || {
    echo "F-SI12_PROTECTED_SOURCE FAIL changed $path" >&2; exit 1; }
done

python3 - "$OWNER" "$HEADCALC" "$ADAPTER" <<'PY'
import json,pathlib,sys
owner=json.loads(pathlib.Path(sys.argv[1]).read_text())
h=pathlib.Path(sys.argv[2]).read_text().lower()
a=pathlib.Path(sys.argv[3]).read_text().lower()
assert owner['basis']['fsi11_qualification_head']=='9f488bfb4805791e9513bfa7146c59d38423917b'
assert owner['basis']['fkt_fsi_boundary_blob']=='ee1a153c30bbae9416ce08414e8b56049d3d14db'
assert owner['basis']['shared_fkt_type_change_required'] is False
assert owner['implementation_contract']['policy_change'] is False
assert owner['implementation_contract']['formula_change'] is False
for token in [
 'legacy_dt => dt','legacy_swkimpl => swkimpl','legacy_swkmean => swkmean',
 'legacy_maxit => maxit','legacy_maxbacktr => maxbacktr',
 'legacy_dtmin => dtmin','legacy_critdevbalcp => critdevbalcp','legacy_critdevbaltot => critdevbaltot',
 'type(soil_water_numerical_config_t), intent(in), optional :: numerical_config',
 'real(8), intent(in), optional :: explicit_step_duration',
 'dt = explicit_step_duration','swkimpl = numerical_config%conductivity_implicit_mode',
 'swkmean = numerical_config%conductivity_mean_method','maxit = numerical_config%max_iterations',
 'maxbacktr = numerical_config%max_backtracking']:
    assert token in h, token
for token in [
 'request%evaluation, request%boundary, request%numerical, request%step_duration',
 'if (request%numerical%conductivity_implicit_mode /= 0) then']:
    assert token in a, token
for forbidden in [
 'same_real(request%step_duration, dt)',
 'request%numerical%max_iterations /= maxit',
 'request%numerical%max_backtracking /= maxbacktr',
 'request%numerical%conductivity_mean_method /= swkmean',
 'same_real(request%numerical%compartment_balance_tolerance, critdevbalcp)']:
    assert forbidden not in a, forbidden
print('F-SI12_STATIC_CONTROL_BINDING PASS')
PY

# Generate the admitted F-SI11 physical profile. Only the F-SI12 control-poison
# variant differs: requests are constructed first, then legacy numerical globals
# are deliberately set to contradictory values. Result fingerprints are printed so
# control and poisoned runs can be compared byte-for-byte.
CONTROL_DRIVER="$BUILD/test_fsi12_control.F90"
POISON_DRIVER="$BUILD/test_fsi12_poison.F90"
python3 - "$BASE_DRIVER" "$CONTROL_DRIVER" "$POISON_DRIVER" <<'PY'
from pathlib import Path
import sys
base=Path(sys.argv[1]).read_text()

def physical_profile(s):
    s=s.replace('program test_fsi09_b110_common_parallel','program test_fsi12_explicit_controls',1)
    s=s.replace('end program test_fsi09_b110_common_parallel','end program test_fsi12_explicit_controls',1)
    s=s.replace('use mod_fsi08_provider_fixture, only: fsi08_source_sink_provider_t',
'''use mod_b110_source_sink_provider, only: b110_source_sink_provider_t, bind_b110_source_sink_provider\n  use mod_b110_root_sink_provider, only: b110_root_sink_provider_t, bind_b110_root_sink_provider''')
    s=s.replace('type(fsi08_source_sink_provider_t), target :: source_sink(8)',
'''type(b110_source_sink_provider_t), target :: source_sink(8)\n  type(b110_root_sink_provider_t), target :: root_sink(8)\n  real(real64), target :: fsi12_qdra(2,numnod,8), fsi12_qssdi(numnod,8)\n  real(real64), target :: fsi12_zero_root(numnod,8), fsi12_qrot(numnod,8)''')
    old='''       source_sink(column)%source_value = 0.0_real64\n       source_sink(column)%sink_value = 0.0_real64\n       top_provider(column)%surface_tracks_head = .true.'''
    new='''       do node = 1, numnod\n          fsi12_qdra(1,node,column) = scale(real(column*node,real64),-10)\n          fsi12_qdra(2,node,column) = -scale(real(column+node,real64),-12)\n          fsi12_qrot(node,column) = scale(real(2*column+node,real64),-14)\n          fsi12_zero_root(node,column) = 0.0_real64\n          fsi12_qssdi(node,column) = fsi12_qdra(1,node,column) + fsi12_qdra(2,node,column) + fsi12_qrot(node,column)\n       end do\n       call bind_b110_source_sink_provider(source_sink(column), fsi12_qdra(:,:,column), &\n            fsi12_qssdi(:,column), fsi12_zero_root(:,column))\n       call bind_b110_root_sink_provider(root_sink(column), fsi12_qrot(:,column))\n       top_provider(column)%surface_tracks_head = .true.'''
    if old not in s: raise SystemExit('F-SI12 provider marker missing')
    s=s.replace(old,new,1)
    marker='request%evaluation%source_sink => source_sink(column)'
    if marker not in s: raise SystemExit('F-SI12 request provider marker missing')
    s=s.replace(marker,marker+'\n    request%evaluation%root_sink => root_sink(column)',1)
    s=s.replace('F-SI09 requires 1/2/4/8 workers','F-SI12 requires 1/2/4/8 workers')
    s=s.replace('F-SI09_B110_COMMON_ROUTE FAIL failures=','F-SI12_EXPLICIT_CONTROLS FAIL failures=')
    s=s.replace('F-SI09_B110_COMMON_ROUTE_','F-SI12_EXPLICIT_CONTROLS_')
    # Print exact solver/result fingerprints after all internal checks.
    marker="  write(*,'(A,I0,A)') 'F-SI12_EXPLICIT_CONTROLS_', nthreads, '_PASS'"
    repl="""  do i = 1, nthreads\n     write(*,'(A,I0,1X,Z16.16)') 'FP', i, serial_fp(i)\n  end do\n"""+marker
    if marker not in s: raise SystemExit('F-SI12 output marker missing')
    return s.replace(marker,repl,1)

control=physical_profile(base)
poison=control
# Poison only after request construction. Physical-route guards swmacro/swbotb/fldtmin
# intentionally remain untouched because they are outside F-SI12 control ownership.
marker='''  do i = 1, nthreads\n     call make_request(requests(i), i)\n     request_before(i) = request_fingerprint(requests(i))\n  end do\n\n  call run_serial_baseline(failures)'''
poison_block='''  do i = 1, nthreads\n     call make_request(requests(i), i)\n     request_before(i) = request_fingerprint(requests(i))\n  end do\n\n  dt = 99.0_real64\n  maxit = 0\n  maxbacktr = 0\n  swkimpl = 1\n  swkmean = 99\n  dtmin = 88.0_real64\n  CritDevBalCp = -71.0_real64\n  CritDevBalTot = -72.0_real64\n  critdevh2cp = -73.0_real64\n  critdevh1cp = -74.0_real64\n  critdevponddt = -75.0_real64\n\n  call run_serial_baseline(failures)'''
if marker not in poison: raise SystemExit('F-SI12 poison insertion marker missing')
poison=poison.replace(marker,poison_block,1)
# Prove the solve did not publish or restore the deliberately poisoned numerical globals.
marker='''  if (global_state_fingerprint() /= globals_before) failures = failures + 1\n  do i = 1, nthreads'''
check='''  if (global_state_fingerprint() /= globals_before) failures = failures + 1\n  if (transfer(dt,0_int64) /= transfer(99.0_real64,0_int64)) failures = failures + 1\n  if (maxit /= 0 .or. maxbacktr /= 0 .or. swkimpl /= 1 .or. swkmean /= 99) failures = failures + 1\n  if (transfer(dtmin,0_int64) /= transfer(88.0_real64,0_int64)) failures = failures + 1\n  if (transfer(CritDevBalCp,0_int64) /= transfer(-71.0_real64,0_int64)) failures = failures + 1\n  if (transfer(CritDevBalTot,0_int64) /= transfer(-72.0_real64,0_int64)) failures = failures + 1\n  if (transfer(critdevh2cp,0_int64) /= transfer(-73.0_real64,0_int64)) failures = failures + 1\n  if (transfer(critdevh1cp,0_int64) /= transfer(-74.0_real64,0_int64)) failures = failures + 1\n  if (transfer(critdevponddt,0_int64) /= transfer(-75.0_real64,0_int64)) failures = failures + 1\n  do i = 1, nthreads'''
if marker not in poison: raise SystemExit('F-SI12 poison persistence marker missing')
poison=poison.replace(marker,check,1)
Path(sys.argv[2]).write_text(control)
Path(sys.argv[3]).write_text(poison)
PY

grep -Fq 'request%evaluation%root_sink => root_sink(column)' "$CONTROL_DRIVER"
grep -Fq 'swkimpl = 1' "$POISON_DRIVER"
grep -Fq 'CritDevBalCp = -71.0_real64' "$POISON_DRIVER"

OMP=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow -fopenmp)
compile_common() {
  local opt="$1" out="$2" driver="$3"
  mkdir -p "$out"
  gfortran "${OMP[@]}" -O"$opt" -J "$out" -I "$out" -c "$STUBS" -o "$out/stubs.o"
  gfortran "${OMP[@]}" -O"$opt" -J "$out" -I "$out" -c "$WORKER" -o "$out/worker.o"
  gfortran "${OMP[@]}" -O"$opt" -J "$out" -I "$out" -c "$CONTRACT" -o "$out/contract.o"
  gfortran "${OMP[@]}" -O"$opt" -J "$out" -I "$out" -c "$WORKSPACE" -o "$out/workspace.o"
  gfortran "${OMP[@]}" -O"$opt" -J "$out" -I "$out" -c "$STATE" -o "$out/state.o"
  gfortran "${OMP[@]}" -O"$opt" -J "$out" -I "$out" -c "$TOP_PROVIDER" -o "$out/top.o"
  gfortran "${OMP[@]}" -Werror -O"$opt" -J "$out" -I "$out" -c "$B110_PROVIDER" -o "$out/mvg.o"
  gfortran "${OMP[@]}" -Werror -O"$opt" -J "$out" -I "$out" -c "$SOURCE_SINK" -o "$out/process.o"
  gfortran "${OMP[@]}" -Werror -O"$opt" -J "$out" -I "$out" -c "$ROOT_SINK" -o "$out/root.o"
  gfortran "${OMP[@]}" -O"$opt" -J "$out" -I "$out" -c "$HEADCALC" -o "$out/headcalc.o"
  gfortran "${OMP[@]}" -O"$opt" -J "$out" -I "$out" -c "$ADAPTER" -o "$out/adapter.o"
  gfortran "${OMP[@]}" -Werror -O"$opt" -J "$out" -I "$out" -c "$driver" -o "$out/driver.o"
  gfortran "${OMP[@]}" -O"$opt" "$out/driver.o" "$out/adapter.o" "$out/headcalc.o" "$out/root.o" \
    "$out/process.o" "$out/mvg.o" "$out/top.o" "$out/state.o" "$out/workspace.o" "$out/contract.o" \
    "$out/worker.o" "$out/stubs.o" -o "$out/test"
}

for opt in 0 2; do
  control="$BUILD/control-o$opt"; poison="$BUILD/poison-o$opt"
  compile_common "$opt" "$control" "$CONTROL_DRIVER"
  compile_common "$opt" "$poison" "$POISON_DRIVER"
  for threads in 1 2 4 8; do
    timeout 30s env OMP_NUM_THREADS="$threads" OMP_DYNAMIC=false "$control/test" > "$control/t${threads}.txt"
    timeout 30s env OMP_NUM_THREADS="$threads" OMP_DYNAMIC=false "$poison/test" > "$poison/t${threads}.txt"
    grep -Fq "F-SI12_EXPLICIT_CONTROLS_${threads}_PASS" "$control/t${threads}.txt"
    cmp "$control/t${threads}.txt" "$poison/t${threads}.txt"
  done
  echo "F-SI12_REQUEST_CONTROLS_AUTHORITATIVE_O${opt}_1_2_4_8 PASS"
done
for threads in 1 2 4 8; do
  cmp "$BUILD/control-o0/t${threads}.txt" "$BUILD/control-o2/t${threads}.txt"
  cmp "$BUILD/poison-o0/t${threads}.txt" "$BUILD/poison-o2/t${threads}.txt"
done
echo 'F-SI12_REQUEST_CONTROL_POISON_IDENTITY PASS'
echo 'F-SI12_COMMON_ROUTE_O0_O2_IDENTITY PASS'

# Legacy direct-call compatibility: compile the same replay fixture against the exact
# F-SI11 qualified source and against F-SI12 current source. The new HeadCalc control
# arguments are optional; a direct legacy caller must remain byte-identical.
FSI11_DIRECT="$BUILD/fsi11-direct"
git worktree add --detach "$FSI11_DIRECT" "$FSI11_HEAD" >/dev/null
compile_direct() {
  local root="$1" opt="$2" out="$3"
  mkdir -p "$out"
  local flags=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
  gfortran "${flags[@]}" -O"$opt" -J "$out" -I "$out" -c "$root/tests/fsi/fsi04_real_headcalc_stubs.f90" -o "$out/stubs.o"
  gfortran "${flags[@]}" -O"$opt" -J "$out" -I "$out" -c "$root/src/runtime/mod_a23bu_worker_execution_context.f90" -o "$out/worker.o"
  gfortran "${flags[@]}" -O"$opt" -J "$out" -I "$out" -c "$root/src/solver/mod_soil_water_solver_contract.f90" -o "$out/contract.o"
  gfortran "${flags[@]}" -O"$opt" -J "$out" -I "$out" -c "$root/src/solver/mod_reference_richards_workspace.f90" -o "$out/workspace.o"
  gfortran "${flags[@]}" -O"$opt" -J "$out" -I "$out" -c "$root/src/solver/mod_reference_richards_state_binding.f90" -o "$out/state.o"
  gfortran "${flags[@]}" -O"$opt" -J "$out" -I "$out" -c "$root/src/legacy/b1_10_port/headcalc.f90" -o "$out/headcalc.o"
  gfortran "${flags[@]}" -O"$opt" -cpp -J "$out" -I "$out" -c "$root/tests/fsi/test_fsi04_real_headcalc_replay.F90" -o "$out/driver.o"
  gfortran "${flags[@]}" -O"$opt" "$out/driver.o" "$out/headcalc.o" "$out/state.o" "$out/workspace.o" \
    "$out/contract.o" "$out/worker.o" "$out/stubs.o" -o "$out/replay"
  "$out/replay" > "$out/output.txt"
  grep -Fq 'F-SI04_REAL_HEADCALC_REPLAY PASS' "$out/output.txt"
}
for opt in 0 2; do
  old="$BUILD/direct-fsi11-o$opt"; new="$BUILD/direct-fsi12-o$opt"
  compile_direct "$FSI11_DIRECT" "$opt" "$old"
  compile_direct "$ROOT" "$opt" "$new"
  cmp "$old/output.txt" "$new/output.txt"
  echo "F-SI12_LEGACY_DIRECT_IDENTITY_O${opt} PASS"
done
cmp "$BUILD/direct-fsi12-o0/output.txt" "$BUILD/direct-fsi12-o2/output.txt"
echo 'F-SI12_LEGACY_DIRECT_O0_O2_IDENTITY PASS'
git worktree remove --force "$FSI11_DIRECT" >/dev/null

# Exact F-SI11 qualification remains green in its own pinned tree. These gates must
# not be reinterpreted against F-SI12 source because their source guards are intentional.
FSI11_REG="$BUILD/fsi11-regression"
git worktree add --detach "$FSI11_REG" "$FSI11_HEAD" >/dev/null
(
  cd "$FSI11_REG"
  bash tests/fsi/run_fsi11_root_sink_provider_gate.sh >/dev/null
  bash tests/fsi/run_fsi11_swkimpl1_reject_gate.sh >/dev/null
  bash tests/fsi/run_fsi11_fsi10_pinned_regression_gate.sh >/dev/null
)
git worktree remove --force "$FSI11_REG" >/dev/null
echo 'F-SI12_FSI11_PINNED_REGRESSION PASS'

# Current request-side implicit-K hold remains fail closed before HeadCalc. The
# F-SI11 negative gate itself is pinned, so assert the current adapter source and
# compile behavior via the main control-poison case: global swkimpl=1 is ignored,
# whereas request swkimpl=1 remains rejected by this source token.
grep -Fq 'if (request%numerical%conductivity_implicit_mode /= 0) then' "$ADAPTER"
grep -Fq "route = 'legacy-implicit-k-deferred'" "$ADAPTER"
echo 'F-SI12_SWKIMPL1_REQUEST_HOLD PRESERVED'

bash "$ROOT/tests/fci/run_fci03_gate.sh" >/dev/null
echo 'F-SI12_FKT_BOUNDARY_REGRESSION PASS'

echo 'F-SI12_EXPLICIT_SOLVER_CONTROLS QUALIFIED_CANDIDATE'
echo 'F-SI12_SWKIMPL1 NOT_ADMITTED'
echo 'F-SI12_MACROPORE NOT_ADMITTED'
echo 'F-SI12_PARALLEL_REFERENCE_BACKEND NOT_ADMITTED'
echo 'F-SI12_GATE PASS'
