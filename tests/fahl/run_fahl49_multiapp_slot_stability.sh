#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-fahl49-multiapp-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
COMMON=(-std=f2008 -ffree-line-length-none -O2)
SRC=(
  src/solver/mod_soil_water_solver_contract.f90
  src/solver/mod_b110_default_mvg_provider.f90
  src/solver/mod_b110_direct_retention_core.f90
)
objects=()
for source in "${SRC[@]}"; do
  obj="$BUILD/$(basename "${source%.*}").o"
  gfortran "${COMMON[@]}" -J "$BUILD" -I "$BUILD" -c "$source" -o "$obj"
  objects+=("$obj")
done
gfortran "${COMMON[@]}" -J "$BUILD" -I "$BUILD" -c tests/fahl/test_fahl49_multiapp_slot_stability.f90 -o "$BUILD/test.o"
gfortran -O2 "${objects[@]}" "$BUILD/test.o" -o "$BUILD/test"
set +e
"$BUILD/test" > "$BUILD/output.txt" 2>&1
rc=$?
set -e
cat "$BUILD/output.txt"
grep -Fq 'FAHL49_MULTIAPP_SLOT_STABILITY=FALSIFIED' "$BUILD/output.txt"
test "$rc" -ne 0
echo 'FAHL49_MULTIAPP_FALSIFICATION_REPRODUCED=PASS'
