#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
FSI14_HEAD="d1b1553805ce11f235ac2565381c1ac31739b1f4"
BUILD="${TMPDIR:-/tmp}/swap5-fsi15-fsi14-identity-$$"
COMMON="$BUILD/common-only.sh"
OLD="$BUILD/fsi14"
mkdir -p "$BUILD"
cleanup() {
  if git -C "$ROOT" worktree list --porcelain | grep -Fq "worktree $OLD"; then
    git -C "$ROOT" worktree remove --force "$OLD" >/dev/null 2>&1 || true
  fi
  rm -rf "$BUILD"
}
trap cleanup EXIT
cd "$ROOT"

[[ "$(git merge-base "$FSI14_HEAD" HEAD)" == "$FSI14_HEAD" ]] || {
  echo 'F-SI15_FSI14_IDENTITY FAIL lineage' >&2; exit 1; }
changed_src="$(git diff --name-only "$FSI14_HEAD"...HEAD -- src | sort)"
expected_src=$'src/adapter/mod_reference_richards_legacy_binding.f90\nsrc/legacy/b1_10_port/headcalc.f90\nsrc/solver/mod_soil_water_solver_contract.f90'
[[ "$changed_src" == "$expected_src" ]] || {
  echo 'F-SI15_FSI14_IDENTITY FAIL unexpected production delta:' >&2
  printf '%s\n' "$changed_src" >&2
  exit 1
}

# Reuse the exact qualified F-SI14 common-route identity generator, but bind its
# old side to the final F-SI14 head and update only its source-scope/blob guards.
awk '/^# The direct legacy route must remain byte-identical too:/{exit} {print}' \
  "$ROOT/tests/fsi/run_fsi14_fsi13_same_geometry_identity_gate.sh" > "$COMMON"
python3 - "$COMMON" "$ROOT" "$FSI14_HEAD" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); root=sys.argv[2]; old=sys.argv[3]
s=p.read_text()
s=s.replace('FSI13_HEAD="485d702c720cd9532addf9cba8cf2c5bd3b3ee43"', f'FSI13_HEAD="{old}"', 1)
orig="expected_src=$'src/adapter/mod_reference_richards_legacy_binding.f90\\nsrc/legacy/b1_10_port/headcalc.f90\\nsrc/solver/mod_reference_richards_workspace.f90'"
new="expected_src=$'src/adapter/mod_reference_richards_legacy_binding.f90\\nsrc/legacy/b1_10_port/headcalc.f90\\nsrc/solver/mod_soil_water_solver_contract.f90'"
if s.count(orig)!=1: raise SystemExit('F-SI15 identity expected-source marker mismatch')
s=s.replace(orig,new,1)
start=s.index('check_blob "$FSI13_HEAD" src/legacy/b1_10_port/headcalc.f90')
end_marker='check_blob HEAD src/solver/mod_reference_richards_workspace.f90 a09ba3457a8ce3685df446bfacbf5220cd401507\n'
end=s.index(end_marker,start)+len(end_marker)
block='''check_blob "$FSI13_HEAD" src/legacy/b1_10_port/headcalc.f90 c46756412df7527d6298246570b2aa31bd983823
check_blob "$FSI13_HEAD" src/adapter/mod_reference_richards_legacy_binding.f90 b17b65563fef826772923afe9c32ca7e0463ec14
check_blob "$FSI13_HEAD" src/solver/mod_soil_water_solver_contract.f90 0a57b07712f93538cbfaf9130838682307cede09
check_blob HEAD src/legacy/b1_10_port/headcalc.f90 7ce94a4cfc4634b946f41b01f54d2d7f6efc798f
check_blob HEAD src/adapter/mod_reference_richards_legacy_binding.f90 9bfa182aff7f7a7ab853fe00151a1f14ed9a8492
check_blob HEAD src/solver/mod_soil_water_solver_contract.f90 4271372085d800fd5da969a2ed073b00422d79c6
'''
s=s[:start]+block+s[end:]
# The copied script may live under /tmp; force the real repository root.
marker='ROOT="$(cd "$(dirname "$0")/../.." && pwd)"'
if s.count(marker)!=1: raise SystemExit('F-SI15 identity ROOT marker mismatch')
s=s.replace(marker,f'ROOT="{root}"',1)
p.write_text(s)
PY
chmod +x "$COMMON"
bash "$COMMON"
echo 'F-SI15_FSI14_SAME_PROFILE_COMMON_ROUTE_IDENTITY PASS'

# Legacy direct must remain byte-identical. Generate an explicit interface matching
# each source tree exactly: F-SI14 has parameter_set; F-SI15 additionally has the
# physical_config dummy between numerical config and step duration.
git worktree add --detach "$OLD" "$FSI14_HEAD" >/dev/null

make_direct_driver() {
  local root="$1" out="$2"
  python3 - "$root/tests/fsi/test_fsi04_real_headcalc_replay.F90" \
    "$root/src/legacy/b1_10_port/headcalc.f90" "$out" <<'PY'
from pathlib import Path
import sys
src=Path(sys.argv[1]).read_text()
head=Path(sys.argv[2]).read_text().lower()
has_parameter='type(soil_water_parameter_set_t), target, intent(in), optional :: parameter_set' in head
has_physical='type(soil_water_physical_config_t), intent(in), optional :: physical_config' in head
if has_physical and not has_parameter:
    raise SystemExit('F-SI15 direct interface unexpected physical without parameter_set')
start=src.index('  interface\n')
end=src.index('  end interface\n',start)+len('  end interface\n')
if has_physical:
    interface='''  interface
    subroutine headcalc(worker, fsi_workspace, history, state_binding, evaluation_context, boundary_conditions, &
                        numerical_config, physical_config, explicit_step_duration, parameter_set)
      use mod_a23bu_worker_execution_context, only: a23bu_worker_context_t, a23bu_solver_history_t
      use mod_reference_richards_workspace, only: reference_richards_workspace_t
      use mod_reference_richards_state_binding, only: reference_richards_state_binding_t
      use mod_soil_water_solver_contract, only: hydraulic_evaluation_context_t, soil_water_boundary_conditions_t, &
           soil_water_numerical_config_t, soil_water_physical_config_t, soil_water_parameter_set_t
      type(a23bu_worker_context_t), target, intent(inout), optional :: worker
      type(reference_richards_workspace_t), target, intent(inout), optional :: fsi_workspace
      type(a23bu_solver_history_t), target, intent(inout), optional :: history
      type(reference_richards_state_binding_t), target, intent(inout), optional :: state_binding
      type(hydraulic_evaluation_context_t), intent(in), optional :: evaluation_context
      type(soil_water_boundary_conditions_t), intent(in), optional :: boundary_conditions
      type(soil_water_numerical_config_t), intent(in), optional :: numerical_config
      type(soil_water_physical_config_t), intent(in), optional :: physical_config
      real(8), intent(in), optional :: explicit_step_duration
      type(soil_water_parameter_set_t), target, intent(in), optional :: parameter_set
    end subroutine headcalc
  end interface
'''
elif has_parameter:
    interface='''  interface
    subroutine headcalc(worker, fsi_workspace, history, state_binding, evaluation_context, boundary_conditions, &
                        numerical_config, explicit_step_duration, parameter_set)
      use mod_a23bu_worker_execution_context, only: a23bu_worker_context_t, a23bu_solver_history_t
      use mod_reference_richards_workspace, only: reference_richards_workspace_t
      use mod_reference_richards_state_binding, only: reference_richards_state_binding_t
      use mod_soil_water_solver_contract, only: hydraulic_evaluation_context_t, soil_water_boundary_conditions_t, &
           soil_water_numerical_config_t, soil_water_parameter_set_t
      type(a23bu_worker_context_t), target, intent(inout), optional :: worker
      type(reference_richards_workspace_t), target, intent(inout), optional :: fsi_workspace
      type(a23bu_solver_history_t), target, intent(inout), optional :: history
      type(reference_richards_state_binding_t), target, intent(inout), optional :: state_binding
      type(hydraulic_evaluation_context_t), intent(in), optional :: evaluation_context
      type(soil_water_boundary_conditions_t), intent(in), optional :: boundary_conditions
      type(soil_water_numerical_config_t), intent(in), optional :: numerical_config
      real(8), intent(in), optional :: explicit_step_duration
      type(soil_water_parameter_set_t), target, intent(in), optional :: parameter_set
    end subroutine headcalc
  end interface
'''
else:
    raise SystemExit('F-SI15 direct interface expected F-SI14+ parameter_set source')
Path(sys.argv[3]).write_text(src[:start]+interface+src[end:])
PY
}

FLAGS=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
compile_direct() {
  local root="$1" opt="$2" out="$3"
  mkdir -p "$out"
  local driver="$out/driver.F90"
  make_direct_driver "$root" "$driver"
  gfortran "${FLAGS[@]}" -O"$opt" -J "$out" -I "$out" -c "$root/tests/fsi/fsi04_real_headcalc_stubs.f90" -o "$out/stubs.o"
  gfortran "${FLAGS[@]}" -O"$opt" -J "$out" -I "$out" -c "$root/src/runtime/mod_a23bu_worker_execution_context.f90" -o "$out/worker.o"
  gfortran "${FLAGS[@]}" -O"$opt" -J "$out" -I "$out" -c "$root/src/solver/mod_soil_water_solver_contract.f90" -o "$out/contract.o"
  gfortran "${FLAGS[@]}" -O"$opt" -J "$out" -I "$out" -c "$root/src/solver/mod_reference_richards_workspace.f90" -o "$out/workspace.o"
  gfortran "${FLAGS[@]}" -O"$opt" -J "$out" -I "$out" -c "$root/src/solver/mod_reference_richards_state_binding.f90" -o "$out/state.o"
  gfortran "${FLAGS[@]}" -O"$opt" -J "$out" -I "$out" -c "$root/src/legacy/b1_10_port/headcalc.f90" -o "$out/headcalc.o"
  gfortran "${FLAGS[@]}" -O"$opt" -cpp -J "$out" -I "$out" -c "$driver" -o "$out/driver.o"
  gfortran "${FLAGS[@]}" -O"$opt" "$out/driver.o" "$out/headcalc.o" "$out/state.o" "$out/workspace.o" \
    "$out/contract.o" "$out/worker.o" "$out/stubs.o" -o "$out/replay"
  "$out/replay" > "$out/output.txt"
  grep -Fq 'F-SI04_REAL_HEADCALC_REPLAY PASS' "$out/output.txt"
}

for opt in 0 2; do
  oldout="$BUILD/direct-fsi14-o${opt}"
  newout="$BUILD/direct-fsi15-o${opt}"
  compile_direct "$OLD" "$opt" "$oldout"
  compile_direct "$ROOT" "$opt" "$newout"
  cmp "$oldout/output.txt" "$newout/output.txt"
  echo "F-SI15_FSI14_LEGACY_DIRECT_O${opt}_IDENTITY PASS"
done
cmp "$BUILD/direct-fsi14-o0/output.txt" "$BUILD/direct-fsi14-o2/output.txt"
cmp "$BUILD/direct-fsi15-o0/output.txt" "$BUILD/direct-fsi15-o2/output.txt"
echo 'F-SI15_FSI14_LEGACY_DIRECT_O0_O2_IDENTITY PASS'
echo 'F-SI15_FSI14_IDENTITY_GATE PASS'
