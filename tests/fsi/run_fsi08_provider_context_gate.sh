#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BASE="762b939876ce56f155a944f4cd21febdd763f6a9"
FSI07_TESTED="8658ad70cfcc03d693ca5aa8c946a6d1d87554bf"
BUILD="${TMPDIR:-/tmp}/swap5-fsi08-provider-context-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

HEADCALC="$ROOT/src/legacy/b1_10_port/headcalc.f90"
ADAPTER="$ROOT/src/adapter/mod_reference_richards_legacy_binding.f90"
WORKER="$ROOT/src/runtime/mod_a23bu_worker_execution_context.f90"
CONTRACT="$ROOT/src/solver/mod_soil_water_solver_contract.f90"
WORKSPACE="$ROOT/src/solver/mod_reference_richards_workspace.f90"
STATE="$ROOT/src/solver/mod_reference_richards_state_binding.f90"
STUBS_SRC="$ROOT/tests/fsi/fsi04_real_headcalc_stubs.f90"
TOP_PROVIDER="$ROOT/tests/fsi/mod_fsi07_top_provider.f90"
PROVIDER_FIXTURE="$ROOT/tests/fsi/mod_fsi08_provider_fixture.f90"
HET_DRIVER="$ROOT/tests/fsi/test_fsi08_provider_context_parallel.F90"
FAIL_STUBS="$ROOT/tests/fsi/fsi07_adapter_stubs.f90"
FAIL_DRIVER="$ROOT/tests/fsi/test_fsi08_provider_failclosed.f90"
OWNER="$ROOT/integration/f-si/F-SI08_PROVIDER_CONTEXT_CONTRACT.json"

# Protect F-KT, common solver API and the qualified workspace/state layout.
for path in \
  src/runtime/mod_a23bu_worker_execution_context.f90 \
  src/transaction/mod_transaction_reference.f90 \
  src/solver/mod_soil_water_solver_contract.f90 \
  src/solver/mod_reference_richards_workspace.f90 \
  src/solver/mod_reference_richards_state_binding.f90; do
  [[ "$(git rev-parse "$BASE:$path")" == "$(git rev-parse "HEAD:$path")" ]] || {
    echo "F-SI08_PROTECTED_SOURCE FAIL changed $path" >&2; exit 1; }
done
[[ "$(git rev-parse HEAD:reference/swap-4.3.1/snapshots/B1.10.yml)" == "8d768f00d47224a663941f79bb2d35eacc66d16b" ]] || {
  echo 'F-SI08_ORACLE_PIN FAIL' >&2; exit 1; }

# Structural contract checks. Legacy direct providers remain for standalone compatibility,
# but the admitted explicit route must require and invoke all three common providers.
grep -Fq "provider_constitutive_active = associated(evaluation_context%constitutive)" "$HEADCALC"
grep -Fq "provider_source_sink_active = associated(evaluation_context%source_sink)" "$HEADCALC"
grep -Fq "evaluation_context%constitutive%evaluate" "$HEADCALC"
grep -Fq "evaluation_context%source_sink%evaluate" "$HEADCALC"
grep -Fq "state%k(1:numnod) = provider_k(1:numnod)" "$HEADCALC"
grep -Fq "state%dimoca(1:NN) = provider_capacity(1:NN)" "$HEADCALC"
grep -Fq "state%theta(1:NN) = provider_theta(1:NN)" "$HEADCALC"
grep -Fq "state%kmean(numnod+1) = provider_k(numnod)" "$HEADCALC"
grep -Fq "root_sink_term = 0.0d0" "$HEADCALC"
grep -Fq "root_sink_term = qrot(node)" "$HEADCALC"
grep -Fq "route = 'constitutive-provider-required'" "$ADAPTER"
grep -Fq "route = 'source-sink-provider-required'" "$ADAPTER"
python3 - "$OWNER" "$ADAPTER" "$HEADCALC" <<'PY'
import json,pathlib,re,sys
contract=json.loads(pathlib.Path(sys.argv[1]).read_text())
assert contract['fkt_boundary']['shared_fkt_type_change'] is False
assert contract['explicit_holds']['production_b1_10_constitutive_provider_admitted'] is False
assert contract['explicit_holds']['parallel_reference_backend'].startswith('NOT_ADMITTED')
a=pathlib.Path(sys.argv[2]).read_text()
start=a.index('  subroutine reference_richards_legacy_solve')
end=a.index('  end subroutine reference_richards_legacy_solve',start)
solve=a[start:end]
for name in ['qdra','qssdi','qrot','watcon','hconduc','moiscap','dhconduc','cofgen']:
    if re.search(r'\b'+name+r'\b',solve,re.I):
        raise SystemExit(f'F-SI08 adapter solve leaks legacy provider token: {name}')
h=pathlib.Path(sys.argv[3]).read_text()
# Three constitutive evaluations are intentional in the admitted swkimpl=0 profile:
# initial K, per-Newton capacity, and post-step theta/K refresh. Free drainage reuses
# the refreshed provider_k, matching the legacy use of the current bottom-node K.
assert h.count('evaluation_context%constitutive%evaluate') == 3
assert h.count('evaluation_context%source_sink%evaluate') == 1
assert 'state%kmean(numnod+1) = provider_k(numnod)' in h
print('F-SI08_STATIC_PROVIDER_BOUNDARY PASS')
PY

# Create deterministic real-HeadCalc stubs with switchable band fallback.
STUBS="$BUILD/stubs.f90"
python3 - "$STUBS_SRC" "$STUBS" <<'PY'
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
if s.count(marker)!=1: raise SystemExit('F-SI08 tridag marker mismatch')
s=s.replace(marker,insert,1)
old='  ierror = 0\nend subroutine tridag\n'
new='''  if (force_tridag_failure) then
    ierror = 1
  else
    ierror = 0
  end if
end subroutine tridag
'''
if s.count(old)!=1: raise SystemExit('F-SI08 tridag result marker mismatch')
Path(sys.argv[2]).write_text(s.replace(old,new,1))
PY

# Build an identity driver: provider outputs exactly reproduce the F-SI07 legacy fixture,
# and legacy provider globals are not poisoned. The same driver is used on the exact
# F-SI07 tested source postimage and current F-SI08 source.
IDENTITY_DRIVER="$BUILD/test_identity.F90"
python3 - "$HET_DRIVER" "$IDENTITY_DRIVER" <<'PY'
from pathlib import Path
import sys
s=Path(sys.argv[1]).read_text()
s=s.replace('0.50_real64 + 0.10_real64*real(j,real64)','1.0_real64')
s=s.replace('source_sink(j)%source_value = 0.001_real64*real(j,real64)','source_sink(j)%source_value = 0.0_real64')
s=s.replace('source_sink(j)%sink_value = source_sink(j)%source_value','source_sink(j)%sink_value = 0.0_real64')
s=s.replace('qdra=1000000.0_real64','qdra=0.0_real64')
s=s.replace('qssdi=-2000000.0_real64','qssdi=0.0_real64')
s=s.replace('qrot=3000000.0_real64','qrot=0.0_real64')
Path(sys.argv[2]).write_text(s)
PY

PRE_H="$BUILD/headcalc_fsi07.f90"
PRE_A="$BUILD/adapter_fsi07.f90"
git show "$FSI07_TESTED:src/legacy/b1_10_port/headcalc.f90" > "$PRE_H"
git show "$FSI07_TESTED:src/adapter/mod_reference_richards_legacy_binding.f90" > "$PRE_A"

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow -fopenmp)
compile_real() {
  local opt="$1" out="$2" headcalc="$3" adapter="$4" driver="$5"
  mkdir -p "$out"
  gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c "$STUBS" -o "$out/stubs.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c "$WORKER" -o "$out/worker.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c "$CONTRACT" -o "$out/contract.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c "$WORKSPACE" -o "$out/workspace.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c "$STATE" -o "$out/state.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c "$TOP_PROVIDER" -o "$out/top.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c "$PROVIDER_FIXTURE" -o "$out/provider.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c "$headcalc" -o "$out/headcalc.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c "$adapter" -o "$out/adapter.o"
  gfortran "${COMMON[@]}" -Werror -O"$opt" -J "$out" -I "$out" -c "$driver" -o "$out/driver.o"
  gfortran "${COMMON[@]}" -O"$opt" "$out/driver.o" "$out/adapter.o" "$out/headcalc.o" "$out/provider.o" \
    "$out/top.o" "$out/state.o" "$out/workspace.o" "$out/contract.o" "$out/worker.o" "$out/stubs.o" -o "$out/test"
}

# Gate 1: exact F-SI07 source identity under provider-equivalent inputs.
for opt in 0 2; do
  pre="$BUILD/pre-o$opt"; cur="$BUILD/cur-id-o$opt"
  compile_real "$opt" "$pre" "$PRE_H" "$PRE_A" "$IDENTITY_DRIVER"
  compile_real "$opt" "$cur" "$HEADCALC" "$ADAPTER" "$IDENTITY_DRIVER"
  for threads in 1 2 4 8; do
    timeout 30s env OMP_NUM_THREADS="$threads" OMP_DYNAMIC=false "$pre/test" > "$pre/t${threads}.txt"
    timeout 30s env OMP_NUM_THREADS="$threads" OMP_DYNAMIC=false "$cur/test" > "$cur/t${threads}.txt"
    cmp "$pre/t${threads}.txt" "$cur/t${threads}.txt"
    grep -Fq "F-SI08_PROVIDER_CONTEXT_${threads}_PASS" "$cur/t${threads}.txt"
  done
  echo "F-SI08_FSI07_IDENTITY_O${opt}_1_2_4_8 PASS"
done
for threads in 1 2 4 8; do
  cmp "$BUILD/cur-id-o0/t${threads}.txt" "$BUILD/cur-id-o2/t${threads}.txt"
done
echo 'F-SI08_IDENTITY_O0_O2 PASS'

# Gate 2: heterogeneous providers, poisoned legacy qdra/qssdi/qrot, real HeadCalc.
for opt in 0 2; do
  out="$BUILD/hetero-o$opt"
  compile_real "$opt" "$out" "$HEADCALC" "$ADAPTER" "$HET_DRIVER"
  for threads in 1 2 4 8; do
    timeout 30s env OMP_NUM_THREADS="$threads" OMP_DYNAMIC=false "$out/test" > "$out/t${threads}.txt"
    grep -Fq "F-SI08_PROVIDER_CONTEXT_${threads}_PASS" "$out/t${threads}.txt"
  done
  echo "F-SI08_HETEROGENEOUS_O${opt}_1_2_4_8 PASS"
done
for threads in 1 2 4 8; do
  cmp "$BUILD/hetero-o0/t${threads}.txt" "$BUILD/hetero-o2/t${threads}.txt"
done
echo 'F-SI08_HETEROGENEOUS_O0_O2 PASS'

# Gate 3: missing providers fail before HeadCalc entry.
for opt in 0 2; do
  out="$BUILD/fail-o$opt"; mkdir -p "$out"
  FLAGS=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -O"$opt" -J "$out" -I "$out")
  gfortran "${FLAGS[@]}" -c "$WORKER" -o "$out/worker.o"
  gfortran "${FLAGS[@]}" -c "$CONTRACT" -o "$out/contract.o"
  gfortran "${FLAGS[@]}" -c "$WORKSPACE" -o "$out/workspace.o"
  gfortran "${FLAGS[@]}" -c "$STATE" -o "$out/state.o"
  gfortran "${FLAGS[@]}" -c "$TOP_PROVIDER" -o "$out/top.o"
  gfortran "${FLAGS[@]}" -c "$FAIL_STUBS" -o "$out/stubs.o"
  gfortran "${FLAGS[@]}" -c "$ADAPTER" -o "$out/adapter.o"
  gfortran "${FLAGS[@]}" -c "$FAIL_DRIVER" -o "$out/driver.o"
  gfortran -O"$opt" "$out/driver.o" "$out/adapter.o" "$out/stubs.o" "$out/top.o" "$out/state.o" \
    "$out/workspace.o" "$out/contract.o" "$out/worker.o" -o "$out/test"
  "$out/test" > "$out/output.txt"
  grep -Fq 'F-SI08_PROVIDER_FAILCLOSED PASS' "$out/output.txt"
done
cmp "$BUILD/fail-o0/output.txt" "$BUILD/fail-o2/output.txt"
echo 'F-SI08_PROVIDER_FAILCLOSED_O0_O2 PASS'

# Gate 4: transaction and worker ownership remains unchanged and executable.
bash "$ROOT/tests/fci/run_fci03_gate.sh" >/dev/null
echo 'F-SI08_FKT_BOUNDARY_REGRESSION PASS'

# Gate 5: explicit holds are part of qualification, not omissions.
echo 'F-SI08_PRODUCTION_B1_10_CONSTITUTIVE_PROVIDER BLOCKED_EXACT_SOURCE_BOUND_IMPLEMENTATION'
echo 'F-SI08_SWKIMPL1 BLOCKED_DYNAMIC_ROOT_DKDH_PROVIDER'
echo 'F-SI08_MACROPORE BLOCKED_FSI_FKT_COMPOSITION'
echo 'F-SI08_PARALLEL_REFERENCE_BACKEND NOT_ADMITTED'
echo 'F-SI08_GATE PASS'
