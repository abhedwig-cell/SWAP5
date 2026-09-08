#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
FSI13_HEAD="485d702c720cd9532addf9cba8cf2c5bd3b3ee43"
BUILD="${TMPDIR:-/tmp}/swap5-fsi14-qualified-identity-$$"
OLD="$BUILD/fsi13"
COMMON="$BUILD/common-only.sh"
mkdir -p "$BUILD"
cleanup() {
  if git -C "$ROOT" worktree list --porcelain | grep -Fq "worktree $OLD"; then
    git -C "$ROOT" worktree remove --force "$OLD" >/dev/null 2>&1 || true
  fi
  rm -rf "$BUILD"
}
trap cleanup EXIT
cd "$ROOT"

# Execute the already source-pinned F-SI13<->F-SI14 common-route identity proof, but
# stop before its development-version legacy-direct section. That section used a
# shortened explicit interface and correctly exposed an ABI mismatch once F-SI14
# added the optional parameter_set dummy. The common proof itself is unchanged.
awk '/^# The direct legacy route must remain byte-identical too:/{exit} {print}' \
  "$ROOT/tests/fsi/run_fsi14_fsi13_same_geometry_identity_gate.sh" > "$COMMON"
python3 - "$COMMON" "$ROOT" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); root=sys.argv[2]
s=p.read_text()
marker='ROOT="$(cd "$(dirname "$0")/../.." && pwd)"'
if s.count(marker)!=1: raise SystemExit('F-SI14 qualification common-root marker mismatch')
s=s.replace(marker,f'ROOT="{root}"',1)
p.write_text(s)
PY
chmod +x "$COMMON"
bash "$COMMON"
echo 'F-SI14_FSI13_SAME_GEOMETRY_COMMON_ROUTE_IDENTITY PASS'

# Re-run legacy-direct identity with an explicit interface that exactly matches each
# source tree's actual HeadCalc signature. F-SI13 ends at explicit_step_duration;
# F-SI14 adds the optional parameter_set. No common request is supplied here, so the
# legacy route must remain MOD_grid-authoritative and byte-identical.
git worktree add --detach "$OLD" "$FSI13_HEAD" >/dev/null

make_direct_driver() {
  local root="$1" out="$2"
  python3 - "$root/tests/fsi/test_fsi04_real_headcalc_replay.F90" \
    "$root/src/legacy/b1_10_port/headcalc.f90" "$out" <<'PY'
from pathlib import Path
import sys
src=Path(sys.argv[1]).read_text()
head=Path(sys.argv[2]).read_text().lower()
has_parameter_set='type(soil_water_parameter_set_t), target, intent(in), optional :: parameter_set' in head
start=src.index('  interface\n')
end=src.index('  end interface\n',start)+len('  end interface\n')
if has_parameter_set:
    interface='''  interface\n    subroutine headcalc(worker, fsi_workspace, history, state_binding, evaluation_context, boundary_conditions, &\n                        numerical_config, explicit_step_duration, parameter_set)\n      use mod_a23bu_worker_execution_context, only: a23bu_worker_context_t, a23bu_solver_history_t\n      use mod_reference_richards_workspace, only: reference_richards_workspace_t\n      use mod_reference_richards_state_binding, only: reference_richards_state_binding_t\n      use mod_soil_water_solver_contract, only: hydraulic_evaluation_context_t, soil_water_boundary_conditions_t, &\n           soil_water_numerical_config_t, soil_water_parameter_set_t\n      type(a23bu_worker_context_t), target, intent(inout), optional :: worker\n      type(reference_richards_workspace_t), target, intent(inout), optional :: fsi_workspace\n      type(a23bu_solver_history_t), target, intent(inout), optional :: history\n      type(reference_richards_state_binding_t), target, intent(inout), optional :: state_binding\n      type(hydraulic_evaluation_context_t), intent(in), optional :: evaluation_context\n      type(soil_water_boundary_conditions_t), intent(in), optional :: boundary_conditions\n      type(soil_water_numerical_config_t), intent(in), optional :: numerical_config\n      real(8), intent(in), optional :: explicit_step_duration\n      type(soil_water_parameter_set_t), target, intent(in), optional :: parameter_set\n    end subroutine headcalc\n  end interface\n'''
else:
    interface='''  interface\n    subroutine headcalc(worker, fsi_workspace, history, state_binding, evaluation_context, boundary_conditions, &\n                        numerical_config, explicit_step_duration)\n      use mod_a23bu_worker_execution_context, only: a23bu_worker_context_t, a23bu_solver_history_t\n      use mod_reference_richards_workspace, only: reference_richards_workspace_t\n      use mod_reference_richards_state_binding, only: reference_richards_state_binding_t\n      use mod_soil_water_solver_contract, only: hydraulic_evaluation_context_t, soil_water_boundary_conditions_t, &\n           soil_water_numerical_config_t\n      type(a23bu_worker_context_t), target, intent(inout), optional :: worker\n      type(reference_richards_workspace_t), target, intent(inout), optional :: fsi_workspace\n      type(a23bu_solver_history_t), target, intent(inout), optional :: history\n      type(reference_richards_state_binding_t), target, intent(inout), optional :: state_binding\n      type(hydraulic_evaluation_context_t), intent(in), optional :: evaluation_context\n      type(soil_water_boundary_conditions_t), intent(in), optional :: boundary_conditions\n      type(soil_water_numerical_config_t), intent(in), optional :: numerical_config\n      real(8), intent(in), optional :: explicit_step_duration\n    end subroutine headcalc\n  end interface\n'''
Path(sys.argv[3]).write_text(src[:start]+interface+src[end:])
PY
}

compile_direct() {
  local root="$1" opt="$2" out="$3"
  mkdir -p "$out"
  local driver="$out/driver.F90"
  make_direct_driver "$root" "$driver"
  local flags=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
  gfortran "${flags[@]}" -O"$opt" -J "$out" -I "$out" -c "$root/tests/fsi/fsi04_real_headcalc_stubs.f90" -o "$out/stubs.o"
  gfortran "${flags[@]}" -O"$opt" -J "$out" -I "$out" -c "$root/src/runtime/mod_a23bu_worker_execution_context.f90" -o "$out/worker.o"
  gfortran "${flags[@]}" -O"$opt" -J "$out" -I "$out" -c "$root/src/solver/mod_soil_water_solver_contract.f90" -o "$out/contract.o"
  gfortran "${flags[@]}" -O"$opt" -J "$out" -I "$out" -c "$root/src/solver/mod_reference_richards_workspace.f90" -o "$out/workspace.o"
  gfortran "${flags[@]}" -O"$opt" -J "$out" -I "$out" -c "$root/src/solver/mod_reference_richards_state_binding.f90" -o "$out/state.o"
  gfortran "${flags[@]}" -O"$opt" -J "$out" -I "$out" -c "$root/src/legacy/b1_10_port/headcalc.f90" -o "$out/headcalc.o"
  gfortran "${flags[@]}" -O"$opt" -cpp -J "$out" -I "$out" -c "$driver" -o "$out/driver.o"
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
cmp "$BUILD/direct-fsi13-o0/output.txt" "$BUILD/direct-fsi13-o2/output.txt"
cmp "$BUILD/direct-fsi14-o0/output.txt" "$BUILD/direct-fsi14-o2/output.txt"
echo 'F-SI14_FSI13_LEGACY_DIRECT_O0_O2_IDENTITY PASS'
echo 'F-SI14_QUALIFICATION_IDENTITY_GATE PASS'
