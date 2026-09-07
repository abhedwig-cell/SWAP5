#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BASE="c14ad3e032dd0285825051d8cf0e7d11ade01cd6"
PINNED_HEADCALC_BLOB="225b9f2cc1ecff01414b5691799103b92bc068c5"
BUILD="${TMPDIR:-/tmp}/swap5-fsi04-gate-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

HEADCALC="$ROOT/src/legacy/b1_10_port/headcalc.f90"
WORKER="$ROOT/src/runtime/mod_a23bu_worker_execution_context.f90"
CONTRACT="$ROOT/src/solver/mod_soil_water_solver_contract.f90"
WORKSPACE="$ROOT/src/solver/mod_reference_richards_workspace.f90"
ADAPTER="$ROOT/src/adapter/mod_reference_richards_legacy_binding.f90"
STUBS="$ROOT/tests/fsi/fsi04_real_headcalc_stubs.f90"
DRIVER="$ROOT/tests/fsi/test_fsi04_real_headcalc_replay.F90"
GENERATOR="$ROOT/tools/fsi/fsi04_generate_workspace_headcalc.py"
FSI03_STUBS="$ROOT/tests/fsi/fsi03_legacy_binding_stubs.f90"
FSI03_TEST="$ROOT/tests/fsi/test_fsi03_reference_binding.f90"
FSI02_TEST="$ROOT/tests/fsi/test_fsi02_solver_contract.f90"

# Preserve the exact qualified F-SI03 production/runtime/contracts. F-SI04 is a
# generated source-bound isolation experiment, not a production-route switch.
for path in \
  src/legacy/b1_10_port/headcalc.f90 \
  src/legacy/b1_10_port/soilwater.f90 \
  src/runtime/mod_a23bu_worker_execution_context.f90 \
  src/transaction/mod_transaction_reference.f90 \
  src/solver/mod_soil_water_solver_contract.f90 \
  src/solver/mod_reference_richards_workspace.f90 \
  src/adapter/mod_reference_richards_legacy_binding.f90; do
  before="$(git rev-parse "$BASE:$path")"
  after="$(git rev-parse "HEAD:$path")"
  if [[ "$before" != "$after" ]]; then
    echo "F-SI04_SOURCE_GUARD FAIL changed qualified source: $path" >&2
    exit 1
  fi
done
if [[ "$(git rev-parse "HEAD:src/legacy/b1_10_port/headcalc.f90")" != "$PINNED_HEADCALC_BLOB" ]]; then
  echo 'F-SI04_SOURCE_GUARD FAIL HeadCalc is not the pinned canonical blob' >&2
  exit 1
fi

GENERATED="$BUILD/headcalc_workspace.f90"
MANIFEST="$BUILD/transform.json"
python3 "$GENERATOR" "$HEADCALC" "$GENERATED" --manifest "$MANIFEST"
python3 - "$MANIFEST" <<'PY'
import json, pathlib, sys
m = json.loads(pathlib.Path(sys.argv[1]).read_text())
assert m['pinned_headcalc_blob'] == '225b9f2cc1ecff01414b5691799103b92bc068c5'
assert m['physics_formula_change_intended'] is False
assert m['numerical_policy_change_intended'] is False
assert m['fallback_banded_scratch_local'] is True
assert m['edits']['signature'] == 1
assert m['edits']['workspace_argument'] == 1
assert m['edits']['workspace_init'] == 1
for i in range(1, 8):
    assert m['edits'][f'declaration_{i}'] == 1
print('F-SI04_TRANSFORM_MANIFEST PASS')
PY

# Main Newton/Jacobian scratch must no longer be automatic locals on the generated path.
if grep -Eiq 'dimension\(macp\).*::.*(dFdhL|dFdhM|dFdhU|difh|sink|source|hold|flnonconv1|flnonconv2)' "$GENERATED"; then
  echo 'F-SI04_WORKSPACE_GATE FAIL main HeadCalc scratch declaration remains' >&2
  exit 1
fi
for token in \
  'fsi_workspace%dfdh_lower' \
  'fsi_workspace%dfdh_main' \
  'fsi_workspace%dfdh_upper' \
  'fsi_workspace%delta_head' \
  'fsi_workspace%residual' \
  'fsi_workspace%sink' \
  'fsi_workspace%source' \
  'fsi_workspace%old_head' \
  'fsi_workspace%vertical_flux' \
  'fsi_workspace%head_gradient' \
  'fsi_workspace%nonconverged_balance' \
  'fsi_workspace%nonconverged_head' \
  'fsi_workspace%unsaturated_flags' \
  'fsi_workspace%dconductivity_dhead'; do
  grep -Fqi "$token" "$GENERATED" || { echo "F-SI04_WORKSPACE_GATE FAIL missing $token" >&2; exit 1; }
done
# Rare banded fallback scratch is intentionally still local and must remain visible as a hold.
grep -Fqi 'dimension(macp,3) :: a' "$GENERATED" || { echo 'F-SI04_HOLD_GATE FAIL fallback scratch unexpectedly changed' >&2; exit 1; }

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)

compile_original() {
  local opt="$1" out="$2"
  mkdir -p "$out"
  gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c "$STUBS" -o "$out/stubs.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c "$WORKER" -o "$out/worker.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c "$HEADCALC" -o "$out/headcalc.o"
  gfortran "${COMMON[@]}" -O"$opt" -cpp -J "$out" -I "$out" -c "$DRIVER" -o "$out/driver.o"
  gfortran "${COMMON[@]}" -O"$opt" "$out/driver.o" "$out/headcalc.o" "$out/worker.o" "$out/stubs.o" -o "$out/replay"
}

compile_workspace() {
  local opt="$1" out="$2"
  mkdir -p "$out"
  gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c "$STUBS" -o "$out/stubs.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c "$WORKER" -o "$out/worker.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c "$CONTRACT" -o "$out/contract.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c "$WORKSPACE" -o "$out/workspace.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c "$GENERATED" -o "$out/headcalc.o"
  gfortran "${COMMON[@]}" -O"$opt" -cpp -DFSI04_WORKSPACE -J "$out" -I "$out" -c "$DRIVER" -o "$out/driver.o"
  gfortran "${COMMON[@]}" -O"$opt" "$out/driver.o" "$out/headcalc.o" "$out/workspace.o" "$out/contract.o" \
    "$out/worker.o" "$out/stubs.o" -o "$out/replay"
}

for opt in 0 2; do
  original="$BUILD/original-o$opt"
  candidate="$BUILD/workspace-o$opt"
  compile_original "$opt" "$original"
  compile_workspace "$opt" "$candidate"
  "$original/replay" > "$original/output.txt"
  "$candidate/replay" > "$candidate/output.txt"
  cmp "$original/output.txt" "$candidate/output.txt"
  grep -Fq 'F-SI04_REAL_HEADCALC_REPLAY PASS' "$candidate/output.txt"
  echo "F-SI04_REAL_REPLAY_O$opt PASS"
done
cmp "$BUILD/original-o0/output.txt" "$BUILD/original-o2/output.txt"
cmp "$BUILD/workspace-o0/output.txt" "$BUILD/workspace-o2/output.txt"
echo 'F-SI04_O0_O2_IDENTITY PASS'

# Re-run the F-SI03 adapter executable contract without its historical diff-scope guard.
for opt in 0 2; do
  out="$BUILD/fsi03-o$opt"
  mkdir -p "$out"
  gfortran -std=f2008 -Wall -Wextra -Werror -fcheck=all -fbacktrace -O"$opt" -J "$out" \
    "$WORKER" "$CONTRACT" "$WORKSPACE" "$FSI03_STUBS" "$ADAPTER" "$FSI03_TEST" -o "$out/fsi03_test"
  "$out/fsi03_test" >/dev/null
done
echo 'F-SI04_FSI03_REGRESSION PASS'

# Re-run the F-SI02 common contract/workspace test at O0/O2 and 1/2/4/8 workers.
for opt in 0 2; do
  out="$BUILD/fsi02-o$opt"
  mkdir -p "$out"
  gfortran -std=f2008 -Wall -Wextra -Werror -fcheck=all -fbacktrace -fopenmp -O"$opt" -J "$out" \
    "$CONTRACT" "$WORKSPACE" "$FSI02_TEST" -o "$out/fsi02_test"
  for threads in 1 2 4 8; do
    OMP_NUM_THREADS="$threads" "$out/fsi02_test" >/dev/null
  done
done
echo 'F-SI04_FSI02_REGRESSION PASS'

echo 'F-SI04_GATE PASS'
