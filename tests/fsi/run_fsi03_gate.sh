#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fsi03-gate-$$"
BASE="da1d5da0d909c5ce55efa17507b805bffd6b82f9"
mkdir -p "$BUILD/o0" "$BUILD/o2" "$BUILD/fsi02-o0" "$BUILD/fsi02-o2"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

# F-SI03 is an adapter-only migration slice. The qualified reference source and
# F-KT-owned runtime/transaction substrate remain byte-identical to F-SI02.
for path in \
  src/legacy/b1_10_port/headcalc.f90 \
  src/legacy/b1_10_port/soilwater.f90 \
  src/runtime/mod_a23bu_worker_execution_context.f90 \
  src/transaction/mod_transaction_reference.f90 \
  src/solver/mod_soil_water_solver_contract.f90 \
  src/solver/mod_reference_richards_workspace.f90; do
  before="$(git rev-parse "$BASE:$path")"
  after="$(git rev-parse "HEAD:$path")"
  if [[ "$before" != "$after" ]]; then
    echo "F-SI03_SOURCE_GUARD FAIL changed protected source: $path" >&2
    exit 1
  fi
done

COMMON_SOLVER="$ROOT/src/solver"
ADAPTER="$ROOT/src/adapter/mod_reference_richards_legacy_binding.f90"
HEADCALC="$ROOT/src/legacy/b1_10_port/headcalc.f90"
SOILWATER="$ROOT/src/legacy/b1_10_port/soilwater.f90"

# The common solver layer must stay independent of legacy globals and file I/O.
if grep -REin '\bsave\b|open[[:space:]]*\(|read[[:space:]]*\(|write[[:space:]]*\(' "$COMMON_SOLVER"; then
  echo 'F-SI03_COMMON_LAYER_GATE FAIL hidden state or file I/O in src/solver' >&2
  exit 1
fi
if grep -REin '\buse[[:space:]]+variables\b|\buse[[:space:]]+MOD_grid\b|\buse[[:space:]]+MOD_swap_base\b' "$COMMON_SOLVER"; then
  echo 'F-SI03_COMMON_LAYER_GATE FAIL legacy globals leaked into src/solver' >&2
  exit 1
fi

# The legacy binding is explicit, bounded and itself free of file I/O/SAVE state.
if grep -Ein '\bsave\b|open[[:space:]]*\(|read[[:space:]]*\(|write[[:space:]]*\(' "$ADAPTER"; then
  echo 'F-SI03_ADAPTER_GATE FAIL hidden SAVE state or file I/O in legacy binding' >&2
  exit 1
fi
for token in \
  'use MOD_swap_base, only: swmacro' \
  'use MOD_grid, only: numnod, z, dz, disnod' \
  'use variables, only:' \
  'call headcalc(ws%legacy_worker)' \
  'legacy-macropore-deferred' \
  'legacy-implicit-k-deferred' \
  'legacy-min-dt-deferred' \
  'legacy-bottom-mode-deferred' \
  'legacy-workspace-type-error'; do
  if ! grep -Fq "$token" "$ADAPTER"; then
    echo "F-SI03_ADAPTER_GATE FAIL missing explicit binding/fail-closed token: $token" >&2
    exit 1
  fi
done

# The real B1.10 symbol remains the source-bound target. F-SI03 adds exactly one
# adapter caller; the old SoilWater caller remains present and unchanged.
if ! grep -Eq '^subroutine[[:space:]]+headcalc\(worker\)' "$HEADCALC"; then
  echo 'F-SI03_BINDING_GATE FAIL canonical HeadCalc signature changed or missing' >&2
  exit 1
fi
python3 - "$ROOT" <<'PY'
import pathlib, re, sys
root = pathlib.Path(sys.argv[1])
callers = set()
rx = re.compile(r'\bcall\s+headcalc\s*\(', re.I)
for path in root.glob('src/**/*.f90'):
    if rx.search(path.read_text()):
        callers.add(path.relative_to(root).as_posix())
expected = {
    'src/legacy/b1_10_port/soilwater.f90',
    'src/adapter/mod_reference_richards_legacy_binding.f90',
}
if callers != expected:
    raise SystemExit(f'F-SI03_BINDING_GATE FAIL unexpected HeadCalc callers: {sorted(callers)}')
print('F-SI03_BINDING_GATE callers=' + ','.join(sorted(callers)))
PY

# Keep the F-SI03 delta inside adapter/tests/evidence/workflow scope.
while IFS= read -r path; do
  case "$path" in
    src/adapter/mod_reference_richards_legacy_binding.f90|tests/fsi/*|integration/f-si/*|docs/integration/*|.github/workflows/*) ;;
    *)
      echo "F-SI03_SCOPE_GATE FAIL unexpected path relative to F-SI02: $path" >&2
      exit 1
      ;;
  esac
done < <(git diff --name-only "$BASE"..HEAD)

COMMON=(-std=f2008 -Wall -Wextra -Werror -fcheck=all -fbacktrace)
WORKER="$ROOT/src/runtime/mod_a23bu_worker_execution_context.f90"
CONTRACT="$ROOT/src/solver/mod_soil_water_solver_contract.f90"
WORKSPACE="$ROOT/src/solver/mod_reference_richards_workspace.f90"
STUBS="$ROOT/tests/fsi/fsi03_legacy_binding_stubs.f90"
TEST="$ROOT/tests/fsi/test_fsi03_reference_binding.f90"
FSI02_TEST="$ROOT/tests/fsi/test_fsi02_solver_contract.f90"

for opt in 0 2; do
  out="$BUILD/o$opt"
  gfortran "${COMMON[@]}" -O"$opt" -J "$out" \
    "$WORKER" "$CONTRACT" "$WORKSPACE" "$STUBS" "$ADAPTER" "$TEST" \
    -o "$out/fsi03_test"
  "$out/fsi03_test"

done

# Re-run the F-SI02 common contract/workspace executable checks without its
# historical whole-diff scope assertion, which intentionally predates adapters.
for opt in 0 2; do
  out="$BUILD/fsi02-o$opt"
  gfortran "${COMMON[@]}" -fopenmp -O"$opt" -J "$out" \
    "$CONTRACT" "$WORKSPACE" "$FSI02_TEST" -o "$out/fsi02_test"
  for threads in 1 2 4 8; do
    OMP_NUM_THREADS="$threads" "$out/fsi02_test"
  done
done

echo 'F-SI03_GATE PASS'
