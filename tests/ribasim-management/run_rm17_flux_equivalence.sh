#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-rm17-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/bridge"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "RM17_FAIL $*" >&2; exit 1; }
eval "$(sed -n '/^MODULE_SRC=(/,/^)/p' tests/ribasim-management/run_rm13b_real_three_model_transaction.sh)"
COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fPIC -fopenmp)
objects=()
for source in "${MODULE_SRC[@]}"; do
  obj="$BUILD/bridge/$(basename "${source%.*}").o"
  gfortran "${COMMON[@]}" -O2 -J "$BUILD/bridge" -I "$BUILD/bridge" -c "$source" -o "$obj" || fail "compile $source"
  objects+=("$obj")
done
gfortran -shared -fopenmp -O2 "${objects[@]}" -o "$BUILD/bridge/libfgc44_swap.so" || fail "link bridge"
RM17_SWAP_LIB="$BUILD/bridge/libfgc44_swap.so" python3 tests/ribasim-management/test_rm17_flux_equivalence.py | tee "$BUILD/output.txt"
grep -Fq 'RM17_DYNAMIC_FIXED_FLUX_EQUIVALENCE=PASS' "$BUILD/output.txt" || fail "missing equivalence marker"
