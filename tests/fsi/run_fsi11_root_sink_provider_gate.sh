#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BASE="8dc05bd4133cd24f13e794d7410d408f9337cf74"
BUILD="${TMPDIR:-/tmp}/swap5-fsi11-root-sink-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

CONTRACT_SRC="$ROOT/src/solver/mod_soil_water_solver_contract.f90"
ROOT_PROVIDER="$ROOT/src/solver/mod_b110_root_sink_provider.f90"
ROOT_DRIVER="$ROOT/tests/fsi/test_fsi11_root_sink_provider.f90"
HEADCALC="$ROOT/src/legacy/b1_10_port/headcalc.f90"
ADAPTER="$ROOT/src/adapter/mod_reference_richards_legacy_binding.f90"
WORKER="$ROOT/src/runtime/mod_a23bu_worker_execution_context.f90"
WORKSPACE="$ROOT/src/solver/mod_reference_richards_workspace.f90"
STATE="$ROOT/src/solver/mod_reference_richards_state_binding.f90"
STUBS="$ROOT/tests/fsi/fsi04_real_headcalc_stubs.f90"
TOP_PROVIDER="$ROOT/tests/fsi/mod_fsi07_top_provider.f90"
B110_PROVIDER="$ROOT/src/solver/mod_b110_default_mvg_provider.f90"
SOURCE_SINK="$ROOT/src/solver/mod_b110_source_sink_provider.f90"
BASE_DRIVER="$ROOT/tests/fsi/test_fsi09_b110_common_parallel.F90"
OWNER="$ROOT/integration/f-si/F-SI11_ROOT_SINK_PROVIDER_CONTRACT.json"

# Only the F-SI-owned common evaluation seam, new root provider, and HeadCalc root binding
# may differ from the qualified F-SI10 baseline. Transaction/runtime/adapter/provider physics stay pinned.
for path in \
  src/adapter/mod_reference_richards_legacy_binding.f90 \
  src/runtime/mod_a23bu_worker_execution_context.f90 \
  src/transaction/mod_transaction_reference.f90 \
  src/solver/mod_reference_richards_workspace.f90 \
  src/solver/mod_reference_richards_state_binding.f90 \
  src/solver/mod_b110_default_mvg_provider.f90 \
  src/solver/mod_b110_source_sink_provider.f90; do
  [[ "$(git rev-parse "$BASE:$path")" == "$(git rev-parse "HEAD:$path")" ]] || {
    echo "F-SI11_PROTECTED_SOURCE FAIL changed $path" >&2; exit 1; }
done

python3 - "$OWNER" "$CONTRACT_SRC" "$ROOT_PROVIDER" "$HEADCALC" <<'PY'
import json,pathlib,re,sys
owner=json.loads(pathlib.Path(sys.argv[1]).read_text())
contract=pathlib.Path(sys.argv[2]).read_text().lower()
provider=pathlib.Path(sys.argv[3]).read_text().lower()
head=pathlib.Path(sys.argv[4]).read_text()
assert owner['basis']['fsi10_qualified_head']=='8dc05bd4133cd24f13e794d7410d408f9337cf74'
assert owner['basis']['fkt_fsi_boundary_blob']=='ee1a153c30bbae9416ce08414e8b56049d3d14db'
assert owner['shared_contract_change']['fkt_owned_types_changed'] is False
assert owner['legacy_arithmetic_contract']['fold_root_into_sink_forbidden'] is True
assert owner['holds']['parallel_reference_backend_admitted'] is False
for token in [
    'type, abstract, public :: root_sink_provider_t',
    'class(root_sink_provider_t), pointer :: root_sink => null()',
    'subroutine root_sink_evaluate_ifc']:
    assert token in contract, token
for token in [
    'type, extends(root_sink_provider_t), public :: b110_root_sink_provider_t',
    'procedure :: evaluate => b110_root_sink_evaluate',
    'root_sink = self%root_extraction_sink']:
    assert token in provider, token
for forbidden in ['use mod_rootextraction','use variables','save ::']:
    assert forbidden not in provider, forbidden
assert head.count('evaluation_context%root_sink%evaluate') == 1
assert head.count('root_sink_term = provider_root_sink(node)') == 1
assert "root-sink provider requires swkimpl=0 in F-SI11" in head
# The three storage/residual forms must still add root_sink_term after sink-source.
patterns=[
    r'fsi_ws%residual\(1\).*fsi_ws%sink\(1\) - fsi_ws%source\(1\) \+ root_sink_term\(1\)',
    r'fsi_ws%residual\(i\).*fsi_ws%sink\(i\) - fsi_ws%source\(i\) \+ root_sink_term\(i\)',
    r'fsi_ws%residual\(NN\).*fsi_ws%sink\(NN\) - fsi_ws%source\(NN\) \+ root_sink_term\(NN\)']
for p in patterns:
    if not re.search(p,head): raise SystemExit('F-SI11 arithmetic-order source marker missing: '+p)
print('F-SI11_STATIC_ROOT_SINK_SEAM PASS')
PY

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace)
for opt in 0 2; do
  out="$BUILD/unit-o$opt"; mkdir -p "$out"
  gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c "$CONTRACT_SRC" -o "$out/contract.o"
  gfortran "${COMMON[@]}" -Werror -O"$opt" -J "$out" -I "$out" -c "$ROOT_PROVIDER" -o "$out/root.o"
  gfortran "${COMMON[@]}" -Werror -O"$opt" -J "$out" -I "$out" -c "$ROOT_DRIVER" -o "$out/driver.o"
  gfortran -O"$opt" "$out/driver.o" "$out/root.o" "$out/contract.o" -o "$out/test"
  "$out/test" > "$out/output.txt"
  grep -Fq 'F-SI11_ROOT_SINK_MAPPING PASS' "$out/output.txt"
  grep -Fq 'F-SI11_ARITHMETIC_ORDER_SENTINEL PASS' "$out/output.txt"
  echo "F-SI11_ROOT_SINK_UNIT_O${opt} PASS"
done
cmp "$BUILD/unit-o0/output.txt" "$BUILD/unit-o2/output.txt"
echo 'F-SI11_ROOT_SINK_UNIT_O0_O2_IDENTITY PASS'

# Generate a real common-route fixture from the qualified F-SI09 baseline driver.
# Drainage and irrigation use the qualified F-SI10 binding with a zero root array;
# active root extraction is carried only by the new F-SI11 provider. Source is chosen
# as drainage_sum + root so the exact legacy expression sink-source+root is zero.
ACTIVE_DRIVER="$BUILD/test_fsi11_common_parallel.F90"
python3 - "$BASE_DRIVER" "$ACTIVE_DRIVER" <<'PY'
from pathlib import Path
import sys
s=Path(sys.argv[1]).read_text()
s=s.replace('program test_fsi09_b110_common_parallel','program test_fsi11_root_sink_common_parallel',1)
s=s.replace('end program test_fsi09_b110_common_parallel','end program test_fsi11_root_sink_common_parallel',1)
s=s.replace('use mod_fsi08_provider_fixture, only: fsi08_source_sink_provider_t',
'''use mod_b110_source_sink_provider, only: b110_source_sink_provider_t, bind_b110_source_sink_provider\n  use mod_b110_root_sink_provider, only: b110_root_sink_provider_t, bind_b110_root_sink_provider''')
s=s.replace('type(fsi08_source_sink_provider_t), target :: source_sink(8)',
'''type(b110_source_sink_provider_t), target :: source_sink(8)\n  type(b110_root_sink_provider_t), target :: root_sink(8)\n  real(real64), target :: fsi11_qdra(2,numnod,8), fsi11_qssdi(numnod,8)\n  real(real64), target :: fsi11_zero_root(numnod,8), fsi11_qrot(numnod,8)''')
old='''       source_sink(column)%source_value = 0.0_real64\n       source_sink(column)%sink_value = 0.0_real64\n       top_provider(column)%surface_tracks_head = .true.'''
new='''       do node = 1, numnod\n          fsi11_qdra(1,node,column) = scale(real(column*node,real64),-10)\n          fsi11_qdra(2,node,column) = -scale(real(column+node,real64),-12)\n          fsi11_qrot(node,column) = scale(real(2*column+node,real64),-14)\n          fsi11_zero_root(node,column) = 0.0_real64\n          fsi11_qssdi(node,column) = fsi11_qdra(1,node,column) + fsi11_qdra(2,node,column) + fsi11_qrot(node,column)\n       end do\n       call bind_b110_source_sink_provider(source_sink(column), fsi11_qdra(:,:,column), &\n            fsi11_qssdi(:,column), fsi11_zero_root(:,column))\n       call bind_b110_root_sink_provider(root_sink(column), fsi11_qrot(:,column))\n       top_provider(column)%surface_tracks_head = .true.'''
if old not in s: raise SystemExit('F-SI11 provider configure marker missing')
s=s.replace(old,new,1)
marker='request%evaluation%source_sink => source_sink(column)'
if marker not in s: raise SystemExit('F-SI11 request source/sink marker missing')
s=s.replace(marker,marker+'\n    request%evaluation%root_sink => root_sink(column)',1)
s=s.replace('F-SI09 requires 1/2/4/8 workers','F-SI11 requires 1/2/4/8 workers')
s=s.replace('F-SI09_B110_COMMON_ROUTE FAIL failures=','F-SI11_ROOT_SINK_COMMON FAIL failures=')
s=s.replace('F-SI09_B110_COMMON_ROUTE_','F-SI11_ROOT_SINK_COMMON_')
Path(sys.argv[2]).write_text(s)
PY

grep -Fq 'bind_b110_root_sink_provider' "$ACTIVE_DRIVER"
grep -Fq 'request%evaluation%root_sink => root_sink(column)' "$ACTIVE_DRIVER"
# The original global qrot poison is deliberately retained. Any legacy-global read on
# the explicit route destroys the focused residual.
grep -Fq 'qrot = 3000000.0_real64' "$ACTIVE_DRIVER"

# Create a root-inactive control with exactly the same outputs expected: remove the
# root provider association and set qrot/source compensation to zero. This is the F-SI10
# compatibility reference for the same physical solver state/boundaries.
INACTIVE_DRIVER="$BUILD/test_fsi11_inactive_parallel.F90"
python3 - "$ACTIVE_DRIVER" "$INACTIVE_DRIVER" <<'PY'
from pathlib import Path
import sys,re
s=Path(sys.argv[1]).read_text()
s=s.replace('program test_fsi11_root_sink_common_parallel','program test_fsi11_inactive_common_parallel',1)
s=s.replace('end program test_fsi11_root_sink_common_parallel','end program test_fsi11_inactive_common_parallel',1)
s=s.replace('          fsi11_qrot(node,column) = scale(real(2*column+node,real64),-14)',
            '          fsi11_qrot(node,column) = 0.0_real64')
s=s.replace('    request%evaluation%root_sink => root_sink(column)\n','')
# Keep output labels identical so active and root-inactive control files can be cmp'ed.
Path(sys.argv[2]).write_text(s)
PY

OMP=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow -fopenmp)
compile_common() {
  local opt="$1" out="$2" driver="$3"
  mkdir -p "$out"
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
  gfortran "${OMP[@]}" -Werror -O"$opt" -J "$out" -I "$out" -c "$driver" -o "$out/driver.o"
  gfortran "${OMP[@]}" -O"$opt" "$out/driver.o" "$out/adapter.o" "$out/headcalc.o" "$out/root.o" \
    "$out/process.o" "$out/mvg.o" "$out/top.o" "$out/state.o" "$out/workspace.o" "$out/contract.o" \
    "$out/worker.o" "$out/stubs.o" -o "$out/test"
}

for opt in 0 2; do
  active="$BUILD/active-o$opt"; inactive="$BUILD/inactive-o$opt"
  compile_common "$opt" "$active" "$ACTIVE_DRIVER"
  compile_common "$opt" "$inactive" "$INACTIVE_DRIVER"
  for threads in 1 2 4 8; do
    timeout 30s env OMP_NUM_THREADS="$threads" OMP_DYNAMIC=false "$active/test" > "$active/t${threads}.txt"
    timeout 30s env OMP_NUM_THREADS="$threads" OMP_DYNAMIC=false "$inactive/test" > "$inactive/t${threads}.txt"
    grep -Fq "F-SI11_ROOT_SINK_COMMON_${threads}_PASS" "$active/t${threads}.txt"
    cmp "$active/t${threads}.txt" "$inactive/t${threads}.txt"
  done
  echo "F-SI11_COMMON_ROUTE_O${opt}_1_2_4_8 PASS"
  echo "F-SI11_ROOT_ACTIVE_VS_INACTIVE_REFERENCE_O${opt} PASS"
done
for threads in 1 2 4 8; do
  cmp "$BUILD/active-o0/t${threads}.txt" "$BUILD/active-o2/t${threads}.txt"
done
echo 'F-SI11_COMMON_ROUTE_O0_O2_IDENTITY PASS'

# Existing F-KT/worker substrate must remain executable after the F-SI-owned API extension.
bash "$ROOT/tests/fci/run_fci03_gate.sh" >/dev/null
echo 'F-SI11_FKT_BOUNDARY_REGRESSION PASS'

echo 'F-SI11_PRECOMPUTED_ROOT_SINK QUALIFIED_CANDIDATE'
echo 'F-SI11_SWKIMPL1_DYNAMIC_ROOT NOT_ADMITTED'
echo 'F-SI11_MACROPORE NOT_ADMITTED'
echo 'F-SI11_PARALLEL_REFERENCE_BACKEND NOT_ADMITTED'
echo 'F-SI11_GATE PASS'
