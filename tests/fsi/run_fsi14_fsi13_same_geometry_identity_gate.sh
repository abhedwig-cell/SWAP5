#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
FSI13_HEAD="485d702c720cd9532addf9cba8cf2c5bd3b3ee43"
BUILD="${TMPDIR:-/tmp}/swap5-fsi14-fsi13-identity-$$"
OLD="$BUILD/fsi13"
mkdir -p "$BUILD"
cleanup() {
  if git -C "$ROOT" worktree list --porcelain | grep -Fq "worktree $OLD"; then
    git -C "$ROOT" worktree remove --force "$OLD" >/dev/null 2>&1 || true
  fi
  rm -rf "$BUILD"
}
trap cleanup EXIT
cd "$ROOT"

# Exact lineage and source postimages. F-SI14 may alter only the three F-SI-owned
# production files below relative to the final qualified F-SI13 head.
[[ "$(git merge-base "$FSI13_HEAD" HEAD)" == "$FSI13_HEAD" ]] || {
  echo 'F-SI14_FSI13_IDENTITY FAIL lineage does not descend from final F-SI13 qualification head' >&2; exit 1; }
changed_src="$(git diff --name-only "$FSI13_HEAD"...HEAD -- src | sort)"
expected_src=$'src/adapter/mod_reference_richards_legacy_binding.f90\nsrc/legacy/b1_10_port/headcalc.f90\nsrc/solver/mod_reference_richards_workspace.f90'
[[ "$changed_src" == "$expected_src" ]] || {
  echo 'F-SI14_FSI13_IDENTITY FAIL unexpected production delta:' >&2
  printf '%s\n' "$changed_src" >&2
  exit 1
}

check_blob() {
  local ref="$1" path="$2" expected="$3"
  local actual
  actual="$(git rev-parse "$ref:$path")"
  [[ "$actual" == "$expected" ]] || {
    echo "F-SI14_FSI13_IDENTITY FAIL blob $ref:$path expected=$expected actual=$actual" >&2; exit 1; }
}
check_blob "$FSI13_HEAD" src/legacy/b1_10_port/headcalc.f90 355bf276e3564bdf9128c23077dbe03da712a17c
check_blob "$FSI13_HEAD" src/adapter/mod_reference_richards_legacy_binding.f90 9e9d21ff7ae2b62c95b1b93c016ae95abb447137
check_blob "$FSI13_HEAD" src/solver/mod_reference_richards_workspace.f90 93285b2ca24669494c93c00403e3783fca6758e9
check_blob HEAD src/legacy/b1_10_port/headcalc.f90 c46756412df7527d6298246570b2aa31bd983823
check_blob HEAD src/adapter/mod_reference_richards_legacy_binding.f90 b17b65563fef826772923afe9c32ca7e0463ec14
check_blob HEAD src/solver/mod_reference_richards_workspace.f90 a09ba3457a8ce3685df446bfacbf5220cd401507

git worktree add --detach "$OLD" "$FSI13_HEAD" >/dev/null

# Generate one admitted physical-profile driver and use that exact driver source for
# both F-SI13 and F-SI14. It exercises the corrected B1.10 constitutive provider,
# precomputed drainage/irrigation source-sink provider, precomputed root-sink
# provider, explicit top provider, explicit numerical controls, and bottom mode 7/-2.
make_driver() {
  local mode="$1" out="$2"
  python3 - "$ROOT/tests/fsi/test_fsi09_b110_common_parallel.F90" "$out" "$mode" <<'PY'
from pathlib import Path
import sys
s=Path(sys.argv[1]).read_text()
mode=int(sys.argv[3])
if mode not in (7,-2): raise SystemExit('F-SI14 identity supports only admitted bottom modes 7 and -2')
s=s.replace('program test_fsi09_b110_common_parallel','program test_fsi14_fsi13_identity',1)
s=s.replace('end program test_fsi09_b110_common_parallel','end program test_fsi14_fsi13_identity',1)
s=s.replace('use mod_fsi08_provider_fixture, only: fsi08_source_sink_provider_t',
'''use mod_b110_source_sink_provider, only: b110_source_sink_provider_t, bind_b110_source_sink_provider\n  use mod_b110_root_sink_provider, only: b110_root_sink_provider_t, bind_b110_root_sink_provider''',1)
s=s.replace('type(fsi08_source_sink_provider_t), target :: source_sink(8)',
'''type(b110_source_sink_provider_t), target :: source_sink(8)\n  type(b110_root_sink_provider_t), target :: root_sink(8)\n  real(real64), target :: fsi14_qdra(2,numnod,8), fsi14_qssdi(numnod,8)\n  real(real64), target :: fsi14_zero_root(numnod,8), fsi14_qrot(numnod,8)''',1)
old='''       source_sink(column)%source_value = 0.0_real64\n       source_sink(column)%sink_value = 0.0_real64\n       top_provider(column)%surface_tracks_head = .true.'''
new='''       do node = 1, numnod\n          fsi14_qdra(1,node,column) = scale(real(column*node,real64),-10)\n          fsi14_qdra(2,node,column) = -scale(real(column+node,real64),-12)\n          fsi14_qrot(node,column) = scale(real(2*column+node,real64),-14)\n          fsi14_zero_root(node,column) = 0.0_real64\n          fsi14_qssdi(node,column) = fsi14_qdra(1,node,column) + fsi14_qdra(2,node,column) + fsi14_qrot(node,column)\n       end do\n       call bind_b110_source_sink_provider(source_sink(column), fsi14_qdra(:,:,column), &\n            fsi14_qssdi(:,column), fsi14_zero_root(:,column))\n       call bind_b110_root_sink_provider(root_sink(column), fsi14_qrot(:,column))\n       top_provider(column)%surface_tracks_head = .true.'''
if s.count(old)!=1: raise SystemExit('F-SI14 identity provider marker mismatch')
s=s.replace(old,new,1)
marker='request%evaluation%source_sink => source_sink(column)'
if s.count(marker)!=1: raise SystemExit('F-SI14 identity request provider marker mismatch')
s=s.replace(marker,marker+'\n    request%evaluation%root_sink => root_sink(column)',1)
if mode == -2:
    needle='request%boundary%bottom_mode = 7'
    if s.count(needle)!=1: raise SystemExit('F-SI14 identity bottom mode marker mismatch')
    s=s.replace(needle,'request%boundary%bottom_mode = -2',1)
# The diagnostic residual must use the request geometry, not a hidden MOD_grid copy.
needle='residual = sum(dz*(result%candidate_state%water_content-request%base_state%water_content)) + &'
if s.count(needle)!=1: raise SystemExit('F-SI14 identity residual geometry marker mismatch')
s=s.replace(needle,'residual = sum(request%parameters%dz*(result%candidate_state%water_content-request%base_state%water_content)) + &',1)
s=s.replace('F-SI09 requires 1/2/4/8 workers','F-SI14 identity requires 1/2/4/8 workers',1)
s=s.replace('F-SI09_B110_COMMON_ROUTE FAIL failures=','F-SI14_FSI13_IDENTITY FAIL failures=',1)
s=s.replace('F-SI09_B110_COMMON_ROUTE_','F-SI14_FSI13_IDENTITY_',1)
marker="  write(*,'(A,I0,A)') 'F-SI14_FSI13_IDENTITY_', nthreads, '_PASS'"
fp="""  do i = 1, nthreads\n     write(*,'(A,I0,1X,Z16.16)') 'FP', i, serial_fp(i)\n  end do\n"""+marker
if s.count(marker)!=1: raise SystemExit('F-SI14 identity output marker mismatch')
s=s.replace(marker,fp,1)
Path(sys.argv[2]).write_text(s)
PY
}

COMMON_FLAGS=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow -fopenmp)
compile_common() {
  local root="$1" opt="$2" out="$3" driver="$4"
  mkdir -p "$out"
  gfortran "${COMMON_FLAGS[@]}" -O"$opt" -J "$out" -I "$out" -c "$root/tests/fsi/fsi04_real_headcalc_stubs.f90" -o "$out/stubs.o"
  gfortran "${COMMON_FLAGS[@]}" -O"$opt" -J "$out" -I "$out" -c "$root/src/runtime/mod_a23bu_worker_execution_context.f90" -o "$out/worker.o"
  gfortran "${COMMON_FLAGS[@]}" -O"$opt" -J "$out" -I "$out" -c "$root/src/solver/mod_soil_water_solver_contract.f90" -o "$out/contract.o"
  gfortran "${COMMON_FLAGS[@]}" -O"$opt" -J "$out" -I "$out" -c "$root/src/solver/mod_reference_richards_workspace.f90" -o "$out/workspace.o"
  gfortran "${COMMON_FLAGS[@]}" -O"$opt" -J "$out" -I "$out" -c "$root/src/solver/mod_reference_richards_state_binding.f90" -o "$out/state.o"
  gfortran "${COMMON_FLAGS[@]}" -O"$opt" -J "$out" -I "$out" -c "$root/tests/fsi/mod_fsi07_top_provider.f90" -o "$out/top.o"
  gfortran "${COMMON_FLAGS[@]}" -Werror -O"$opt" -J "$out" -I "$out" -c "$root/src/solver/mod_b110_default_mvg_provider.f90" -o "$out/mvg.o"
  gfortran "${COMMON_FLAGS[@]}" -Werror -O"$opt" -J "$out" -I "$out" -c "$root/src/solver/mod_b110_source_sink_provider.f90" -o "$out/process.o"
  gfortran "${COMMON_FLAGS[@]}" -Werror -O"$opt" -J "$out" -I "$out" -c "$root/src/solver/mod_b110_root_sink_provider.f90" -o "$out/root.o"
  gfortran "${COMMON_FLAGS[@]}" -O"$opt" -J "$out" -I "$out" -c "$root/src/legacy/b1_10_port/headcalc.f90" -o "$out/headcalc.o"
  gfortran "${COMMON_FLAGS[@]}" -O"$opt" -J "$out" -I "$out" -c "$root/src/adapter/mod_reference_richards_legacy_binding.f90" -o "$out/adapter.o"
  gfortran "${COMMON_FLAGS[@]}" -Werror -O"$opt" -J "$out" -I "$out" -c "$driver" -o "$out/driver.o"
  gfortran "${COMMON_FLAGS[@]}" -O"$opt" "$out/driver.o" "$out/adapter.o" "$out/headcalc.o" "$out/root.o" \
    "$out/process.o" "$out/mvg.o" "$out/top.o" "$out/state.o" "$out/workspace.o" "$out/contract.o" \
    "$out/worker.o" "$out/stubs.o" -o "$out/test"
}

for mode in 7 -2; do
  driver="$BUILD/mode-${mode}.F90"
  make_driver "$mode" "$driver"
  for opt in 0 2; do
    oldout="$BUILD/common-fsi13-m${mode}-o${opt}"
    newout="$BUILD/common-fsi14-m${mode}-o${opt}"
    compile_common "$OLD" "$opt" "$oldout" "$driver"
    compile_common "$ROOT" "$opt" "$newout" "$driver"
    for threads in 1 2 4 8; do
      timeout 30s env OMP_NUM_THREADS="$threads" OMP_DYNAMIC=false "$oldout/test" > "$oldout/t${threads}.txt"
      timeout 30s env OMP_NUM_THREADS="$threads" OMP_DYNAMIC=false "$newout/test" > "$newout/t${threads}.txt"
      grep -Fq "F-SI14_FSI13_IDENTITY_${threads}_PASS" "$oldout/t${threads}.txt"
      grep -Fq "F-SI14_FSI13_IDENTITY_${threads}_PASS" "$newout/t${threads}.txt"
      cmp "$oldout/t${threads}.txt" "$newout/t${threads}.txt"
    done
    echo "F-SI14_FSI13_SAME_GEOMETRY_MODE_${mode}_O${opt}_1_2_4_8_IDENTITY PASS"
  done
  for threads in 1 2 4 8; do
    cmp "$BUILD/common-fsi13-m${mode}-o0/t${threads}.txt" "$BUILD/common-fsi13-m${mode}-o2/t${threads}.txt"
    cmp "$BUILD/common-fsi14-m${mode}-o0/t${threads}.txt" "$BUILD/common-fsi14-m${mode}-o2/t${threads}.txt"
  done
  echo "F-SI14_FSI13_SAME_GEOMETRY_MODE_${mode}_O0_O2_IDENTITY PASS"
done

# The direct legacy route must remain byte-identical too: F-SI14 geometry selection is
# only active when an explicit state/request binding is present.
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
  gfortran "${flags[@]}" -O"$opt" -cpp -J "$out" -I "$out" -c "$ROOT/tests/fsi/test_fsi04_real_headcalc_replay.F90" -o "$out/driver.o"
  gfortran "${flags[@]}" -O"$opt" "$out/driver.o" "$out/headcalc.o" "$out/state.o" "$out/workspace.o" \
    "$out/contract.o" "$out/worker.o" "$out/stubs.o" -o "$out/replay"
  "$out/replay" > "$out/output.txt"
  grep -Fq 'F-SI04_REAL_HEADCALC_REPLAY PASS' "$out/output.txt"
}
for opt in 0 2; do
  oldout="$BUILD/direct-fsi13-o${opt}"
  newout="$BUILD/direct-fsi14-o${opt}"
  compile_direct "$OLD" "$opt" "$oldout"
  compile_direct "$ROOT" "$opt" "$newout"
  cmp "$oldout/output.txt" "$newout/output.txt"
  echo "F-SI14_FSI13_LEGACY_DIRECT_O${opt}_IDENTITY PASS"
done
cmp "$BUILD/direct-fsi14-o0/output.txt" "$BUILD/direct-fsi14-o2/output.txt"
echo 'F-SI14_FSI13_LEGACY_DIRECT_O0_O2_IDENTITY PASS'

echo 'F-SI14_FSI13_SAME_GEOMETRY_COMMON_ROUTE_IDENTITY PASS'
echo 'F-SI14_FSI13_IDENTITY_GATE PASS'
