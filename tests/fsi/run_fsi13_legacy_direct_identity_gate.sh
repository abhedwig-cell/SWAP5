#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
FSI12_HEAD="3dacdb03503a5ac5f6ce3fe86a55612e9b08a46d"
BUILD="${TMPDIR:-/tmp}/swap5-fsi13-direct-$$"
OLD="$BUILD/fsi12"
mkdir -p "$BUILD"
cleanup() {
  if git -C "$ROOT" worktree list --porcelain | grep -Fq "worktree $OLD"; then
    git -C "$ROOT" worktree remove --force "$OLD" >/dev/null 2>&1 || true
  fi
  rm -rf "$BUILD"
}
trap cleanup EXIT
cd "$ROOT"
git worktree add --detach "$OLD" "$FSI12_HEAD" >/dev/null

make_driver() {
  local root="$1" out="$2"
  python3 - "$root/tests/fsi/test_fsi04_real_headcalc_replay.F90" "$out" <<'PY'
from pathlib import Path
import sys
src=Path(sys.argv[1]).read_text()
start=src.index('  interface\n')
end=src.index('  end interface\n', start)+len('  end interface\n')
interface='''  interface\n    subroutine headcalc(worker, fsi_workspace, history, state_binding, evaluation_context, boundary_conditions, &\n                        numerical_config, explicit_step_duration)\n      use mod_a23bu_worker_execution_context, only: a23bu_worker_context_t, a23bu_solver_history_t\n      use mod_reference_richards_workspace, only: reference_richards_workspace_t\n      use mod_reference_richards_state_binding, only: reference_richards_state_binding_t\n      use mod_soil_water_solver_contract, only: hydraulic_evaluation_context_t, soil_water_boundary_conditions_t, &\n           soil_water_numerical_config_t\n      type(a23bu_worker_context_t), target, intent(inout), optional :: worker\n      type(reference_richards_workspace_t), target, intent(inout), optional :: fsi_workspace\n      type(a23bu_solver_history_t), target, intent(inout), optional :: history\n      type(reference_richards_state_binding_t), target, intent(inout), optional :: state_binding\n      type(hydraulic_evaluation_context_t), intent(in), optional :: evaluation_context\n      type(soil_water_boundary_conditions_t), intent(in), optional :: boundary_conditions\n      type(soil_water_numerical_config_t), intent(in), optional :: numerical_config\n      real(8), intent(in), optional :: explicit_step_duration\n    end subroutine headcalc\n  end interface\n'''
Path(sys.argv[2]).write_text(src[:start]+interface+src[end:])
PY
}

compile_direct() {
  local root="$1" opt="$2" out="$3"
  mkdir -p "$out"
  local driver="$out/driver.F90"
  make_driver "$root" "$driver"
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
  oldout="$BUILD/fsi12-o$opt"
  newout="$BUILD/fsi13-o$opt"
  compile_direct "$OLD" "$opt" "$oldout"
  compile_direct "$ROOT" "$opt" "$newout"
  cmp "$oldout/output.txt" "$newout/output.txt"
  echo "F-SI13_LEGACY_DIRECT_IDENTITY_O${opt} PASS"
done
cmp "$BUILD/fsi12-o0/output.txt" "$BUILD/fsi12-o2/output.txt"
cmp "$BUILD/fsi13-o0/output.txt" "$BUILD/fsi13-o2/output.txt"
echo 'F-SI13_LEGACY_DIRECT_O0_O2_IDENTITY PASS'
echo 'F-SI13_LEGACY_DIRECT_GATE PASS'
