#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fsi02-gate-$$"
BASE="ae6da038ee7e98dfe1758f5f86b4be0fb48b4743"
mkdir -p "$BUILD/o0" "$BUILD/o2"
trap 'rm -rf "$BUILD"' EXIT

cd "$ROOT"

# F-SI02 is structural. Protect the qualified F-SI01 production preimage exactly.
for path in \
  src/legacy/b1_10_port/headcalc.f90 \
  src/legacy/b1_10_port/soilwater.f90 \
  src/runtime/mod_a23bu_worker_execution_context.f90 \
  src/transaction/mod_transaction_reference.f90; do
  before="$(git rev-parse "$BASE:$path")"
  after="$(git rev-parse "HEAD:$path")"
  if [[ "$before" != "$after" ]]; then
    echo "F-SI02_SOURCE_GUARD FAIL changed protected source: $path" >&2
    exit 1
  fi
done

# No hidden legacy globals, SAVE state or file I/O are allowed in the common solver layer.
if grep -REin '\bsave\b|open[[:space:]]*\(|read[[:space:]]*\(|write[[:space:]]*\(' "$ROOT/src/solver"; then
  echo 'F-SI02_STATIC_GATE FAIL hidden state or file I/O in src/solver' >&2
  exit 1
fi
if grep -REin '\buse[[:space:]]+variables\b|\buse[[:space:]]+MOD_grid\b|\buse[[:space:]]+MOD_swap_base\b' "$ROOT/src/solver"; then
  echo 'F-SI02_STATIC_GATE FAIL common solver contract depends on legacy production globals' >&2
  exit 1
fi

# F-SI02 may add solver-owned code and qualification material only.
while IFS= read -r path; do
  case "$path" in
    src/solver/*|tests/fsi/*|integration/f-si/*|docs/integration/*|.github/workflows/fsi-solver-isolation.yml) ;;
    *)
      echo "F-SI02_SCOPE_GATE FAIL unexpected path relative to F-SI01: $path" >&2
      exit 1
      ;;
  esac
done < <(git diff --name-only "$BASE"..HEAD)

COMMON=(-std=f2008 -Wall -Wextra -Werror -fcheck=all -fbacktrace -fopenmp)
CONTRACT="$ROOT/src/solver/mod_soil_water_solver_contract.f90"
WORKSPACE="$ROOT/src/solver/mod_reference_richards_workspace.f90"
TEST="$ROOT/tests/fsi/test_fsi02_solver_contract.f90"

for opt in 0 2; do
  out="$BUILD/o$opt"
  gfortran "${COMMON[@]}" -O"$opt" -J "$out" "$CONTRACT" "$WORKSPACE" "$TEST" -o "$out/fsi02_test"
  for threads in 1 2 4 8; do
    OMP_NUM_THREADS="$threads" "$out/fsi02_test"
  done
done

# Re-run the prior source-bound boundary gate as a regression check.
bash "$ROOT/tests/fsi/run_fsi01_gate.sh"

echo 'F-SI02_GATE PASS'
