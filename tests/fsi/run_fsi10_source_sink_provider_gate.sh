#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BASE="0f9f84e6f98e43c4ada39f1a8d9b180b0f672330"
BUILD="${TMPDIR:-/tmp}/swap5-fsi10-source-sink-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

CONTRACT_SRC="$ROOT/src/solver/mod_soil_water_solver_contract.f90"
SOURCE_SINK="$ROOT/src/solver/mod_b110_source_sink_provider.f90"
MAPPING_DRIVER="$ROOT/tests/fsi/test_fsi10_source_sink_provider.f90"
HEADCALC="$ROOT/src/legacy/b1_10_port/headcalc.f90"
ADAPTER="$ROOT/src/adapter/mod_reference_richards_legacy_binding.f90"
WORKER="$ROOT/src/runtime/mod_a23bu_worker_execution_context.f90"
WORKSPACE="$ROOT/src/solver/mod_reference_richards_workspace.f90"
STATE="$ROOT/src/solver/mod_reference_richards_state_binding.f90"
STUBS="$ROOT/tests/fsi/fsi04_real_headcalc_stubs.f90"
TOP_PROVIDER="$ROOT/tests/fsi/mod_fsi07_top_provider.f90"
B110_PROVIDER="$ROOT/src/solver/mod_b110_default_mvg_provider.f90"
BASE_DRIVER="$ROOT/tests/fsi/test_fsi09_b110_common_parallel.F90"
OWNER="$ROOT/integration/f-si/F-SI10_SOURCE_SINK_PROVIDER_CONTRACT.json"

# F-SI10 adds only the source/sink binding and qualification assets. Solver, adapter,
# transaction substrate, common interface and qualified constitutive provider remain pinned.
for path in \
  src/legacy/b1_10_port/headcalc.f90 \
  src/adapter/mod_reference_richards_legacy_binding.f90 \
  src/runtime/mod_a23bu_worker_execution_context.f90 \
  src/transaction/mod_transaction_reference.f90 \
  src/solver/mod_soil_water_solver_contract.f90 \
  src/solver/mod_reference_richards_workspace.f90 \
  src/solver/mod_reference_richards_state_binding.f90 \
  src/solver/mod_b110_default_mvg_provider.f90; do
  [[ "$(git rev-parse "$BASE:$path")" == "$(git rev-parse "HEAD:$path")" ]] || {
    echo "F-SI10_PROTECTED_SOURCE FAIL changed $path" >&2; exit 1; }
done

python3 - "$OWNER" "$SOURCE_SINK" <<'PY'
import json,pathlib,sys
owner=json.loads(pathlib.Path(sys.argv[1]).read_text())
src=pathlib.Path(sys.argv[2]).read_text().lower()
assert owner['basis']['fsi09_qualified_head']=='0f9f84e6f98e43c4ada39f1a8d9b180b0f672330'
assert owner['admitted_profile']['root_extraction']=='inactive, qrot=0 only'
assert owner['holds']['parallel_reference_backend_admitted'] is False
assert owner['scope_flags_before_qualification']['production_b1_10_source_sink_provider_admitted'] is False
for token in [
    'type, extends(source_sink_provider_t), public :: b110_source_sink_provider_t',
    'procedure :: evaluate => b110_source_sink_evaluate',
    'source = self%subsurface_irrigation_source',
    'sink = 0.0_real64',
    'sink = sink + self%drainage_flux_by_level(level,:)',
    'active root extraction not admitted by f-si10']:
    assert token in src, token
for forbidden in ['use mod_drain','use mod_irrigation','use mod_rootextraction','use variables','save ::']:
    assert forbidden not in src, forbidden
print('F-SI10_STATIC_SOURCE_SINK_CONTRACT PASS')
PY

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace)
for opt in 0 2; do
  out="$BUILD/map-o$opt"; mkdir -p "$out"
  gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c "$CONTRACT_SRC" -o "$out/contract.o"
  gfortran "${COMMON[@]}" -Werror -O"$opt" -J "$out" -I "$out" -c "$SOURCE_SINK" -o "$out/provider.o"
  gfortran "${COMMON[@]}" -Werror -O"$opt" -J "$out" -I "$out" -c "$MAPPING_DRIVER" -o "$out/driver.o"
  gfortran -O"$opt" "$out/driver.o" "$out/provider.o" "$out/contract.o" -o "$out/test"
  "$out/test" > "$out/output.txt"
  grep -Fq 'F-SI10_SOURCE_SINK_MAPPING PASS' "$out/output.txt"
  echo "F-SI10_SOURCE_SINK_MAPPING_O${opt} PASS"
done
cmp "$BUILD/map-o0/output.txt" "$BUILD/map-o2/output.txt"
echo 'F-SI10_SOURCE_SINK_MAPPING_O0_O2_IDENTITY PASS'

# The admitted F-SI10 provider must fail closed when active root extraction is supplied.
ROOT_REJECT="$BUILD/test_root_reject.f90"
cat > "$ROOT_REJECT" <<'F90'
program test_root_reject
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t, bind_b110_source_sink_provider
  implicit none
  type(b110_source_sink_provider_t) :: provider
  real(real64), target :: drainage(1,2), irrigation(2), root_sink(2)
  drainage = 0.0_real64
  irrigation = 0.0_real64
  root_sink = [1.0e-8_real64, 0.0_real64]
  call bind_b110_source_sink_provider(provider, drainage, irrigation, root_sink)
  error stop 'F-SI10 negative test: active root extraction was not rejected'
end program test_root_reject
F90
for opt in 0 2; do
  out="$BUILD/reject-o$opt"; mkdir -p "$out"
  gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c "$CONTRACT_SRC" -o "$out/contract.o"
  gfortran "${COMMON[@]}" -Werror -O"$opt" -J "$out" -I "$out" -c "$SOURCE_SINK" -o "$out/provider.o"
  gfortran "${COMMON[@]}" -Werror -O"$opt" -J "$out" -I "$out" -c "$ROOT_REJECT" -o "$out/driver.o"
  gfortran -O"$opt" "$out/driver.o" "$out/provider.o" "$out/contract.o" -o "$out/test"
  if "$out/test" > "$out/output.txt" 2>&1; then
    echo "F-SI10_ROOT_EXTRACTION_FAILCLOSED_O${opt} FAIL accepted nonzero root sink" >&2
    exit 1
  fi
  grep -Fqi 'active root extraction not admitted by F-SI10' "$out/output.txt"
  echo "F-SI10_ROOT_EXTRACTION_FAILCLOSED_O${opt} PASS"
done
echo 'F-SI10_ROOT_EXTRACTION_FAILCLOSED PASS'

# Reuse the qualified F-SI09 real-HeadCalc fixture, replacing only the synthetic
# source/sink provider by the production F-SI10 binding. Drainage and subsurface
# irrigation are heterogeneous and nonzero but balance per node, preserving the
# zero focused residual. Root extraction stays physically inactive in this slice.
DRIVER="$BUILD/test_fsi10_common_parallel.F90"
python3 - "$BASE_DRIVER" "$DRIVER" <<'PY'
from pathlib import Path
import sys
s=Path(sys.argv[1]).read_text()
s=s.replace('program test_fsi09_b110_common_parallel','program test_fsi10_source_sink_common_parallel',1)
s=s.replace('end program test_fsi09_b110_common_parallel','end program test_fsi10_source_sink_common_parallel',1)
s=s.replace('use mod_fsi08_provider_fixture, only: fsi08_source_sink_provider_t',
'''use mod_b110_source_sink_provider, only: b110_source_sink_provider_t, bind_b110_source_sink_provider''')
s=s.replace('type(fsi08_source_sink_provider_t), target :: source_sink(8)',
'''type(b110_source_sink_provider_t), target :: source_sink(8)\n  real(real64), target :: fsi10_qdra(2,numnod,8), fsi10_qssdi(numnod,8), fsi10_qrot(numnod,8)''')
old='''       source_sink(column)%source_value = 0.0_real64\n       source_sink(column)%sink_value = 0.0_real64\n       top_provider(column)%surface_tracks_head = .true.'''
new='''       do node = 1, numnod\n          fsi10_qdra(1,node,column) = 1.0e-4_real64*real(column*node,real64)\n          fsi10_qdra(2,node,column) = -2.0e-5_real64*real(column+node,real64)\n          fsi10_qrot(node,column) = 0.0_real64\n          fsi10_qssdi(node,column) = fsi10_qdra(1,node,column) + fsi10_qdra(2,node,column)\n       end do\n       call bind_b110_source_sink_provider(source_sink(column), fsi10_qdra(:,:,column), &\n            fsi10_qssdi(:,column), fsi10_qrot(:,column))\n       top_provider(column)%surface_tracks_head = .true.'''
if old not in s: raise SystemExit('F-SI10 source/sink configure marker missing')
s=s.replace(old,new,1)
s=s.replace('qrot = 3000000.0_real64','qrot = 0.0_real64',1)
s=s.replace('F-SI09 requires 1/2/4/8 workers','F-SI10 requires 1/2/4/8 workers')
s=s.replace('F-SI09_B110_COMMON_ROUTE FAIL failures=','F-SI10_SOURCE_SINK_COMMON FAIL failures=')
s=s.replace('F-SI09_B110_COMMON_ROUTE_','F-SI10_SOURCE_SINK_COMMON_')
Path(sys.argv[2]).write_text(s)
PY

grep -Fq 'bind_b110_source_sink_provider' "$DRIVER"
grep -Fq 'qrot = 0.0_real64' "$DRIVER"
grep -Fq 'qdra = 1000000.0_real64' "$DRIVER"
grep -Fq 'qssdi = -2000000.0_real64' "$DRIVER"

OMP=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow -fopenmp)
compile_common() {
  local opt="$1" out="$2"
  mkdir -p "$out"
  gfortran "${OMP[@]}" -O"$opt" -J "$out" -I "$out" -c "$STUBS" -o "$out/stubs.o"
  gfortran "${OMP[@]}" -O"$opt" -J "$out" -I "$out" -c "$WORKER" -o "$out/worker.o"
  gfortran "${OMP[@]}" -O"$opt" -J "$out" -I "$out" -c "$CONTRACT_SRC" -o "$out/contract.o"
  gfortran "${OMP[@]}" -O"$opt" -J "$out" -I "$out" -c "$WORKSPACE" -o "$out/workspace.o"
  gfortran "${OMP[@]}" -O"$opt" -J "$out" -I "$out" -c "$STATE" -o "$out/state.o"
  gfortran "${OMP[@]}" -O"$opt" -J "$out" -I "$out" -c "$TOP_PROVIDER" -o "$out/top.o"
  gfortran "${OMP[@]}" -Werror -O"$opt" -J "$out" -I "$out" -c "$B110_PROVIDER" -o "$out/mvg.o"
  gfortran "${OMP[@]}" -Werror -O"$opt" -J "$out" -I "$out" -c "$SOURCE_SINK" -o "$out/process.o"
  gfortran "${OMP[@]}" -O"$opt" -J "$out" -I "$out" -c "$HEADCALC" -o "$out/headcalc.o"
  gfortran "${OMP[@]}" -O"$opt" -J "$out" -I "$out" -c "$ADAPTER" -o "$out/adapter.o"
  gfortran "${OMP[@]}" -Werror -O"$opt" -J "$out" -I "$out" -c "$DRIVER" -o "$out/driver.o"
  gfortran "${OMP[@]}" -O"$opt" "$out/driver.o" "$out/adapter.o" "$out/headcalc.o" "$out/process.o" \
    "$out/mvg.o" "$out/top.o" "$out/state.o" "$out/workspace.o" "$out/contract.o" "$out/worker.o" "$out/stubs.o" -o "$out/test"
}

for opt in 0 2; do
  out="$BUILD/common-o$opt"
  compile_common "$opt" "$out"
  for threads in 1 2 4 8; do
    timeout 30s env OMP_NUM_THREADS="$threads" OMP_DYNAMIC=false "$out/test" > "$out/t${threads}.txt"
    grep -Fq "F-SI10_SOURCE_SINK_COMMON_${threads}_PASS" "$out/t${threads}.txt"
  done
  echo "F-SI10_COMMON_ROUTE_O${opt}_1_2_4_8 PASS"
done
for threads in 1 2 4 8; do
  cmp "$BUILD/common-o0/t${threads}.txt" "$BUILD/common-o2/t${threads}.txt"
done
echo 'F-SI10_COMMON_ROUTE_O0_O2_IDENTITY PASS'

# F-SI09 remains the constitutive/reference-regression oracle and transitively reruns
# the F-SI08 provider-context and F-KT/worker isolation gates.
bash "$ROOT/tests/fsi/run_fsi09_b110_provider_gate.sh" >/dev/null
echo 'F-SI10_FSI09_REGRESSION PASS'

echo 'F-SI10_ACTIVE_ROOT_EXTRACTION NOT_ADMITTED_ARITHMETIC_ORDER_SEAM_REQUIRED'
echo 'F-SI10_SWKIMPL1 NOT_ADMITTED'
echo 'F-SI10_PRODUCTION_DRAINAGE_IRRIGATION_BINDING QUALIFIED_CANDIDATE'
echo 'F-SI10_PARALLEL_REFERENCE_BACKEND NOT_ADMITTED'
echo 'F-SI10_GATE PASS'
