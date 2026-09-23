#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-rm15-census-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/bridge"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "RM15_FAIL $*" >&2; exit 1; }

eval "$(sed -n '/^MODULE_SRC=(/,/^)/p' tests/ribasim-management/run_rm13b_real_three_model_transaction.sh)"
COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fPIC -fopenmp)
objects=()
for source in "${MODULE_SRC[@]}"; do
  obj="$BUILD/bridge/$(basename "${source%.*}").o"
  gfortran "${COMMON[@]}" -O2 -J "$BUILD/bridge" -I "$BUILD/bridge" -c "$source" -o "$obj" || fail "compile $source"
  objects+=("$obj")
done
gfortran -shared -fopenmp -O2 "${objects[@]}" -o "$BUILD/bridge/libfgc44_swap.so" || fail "link bridge"

: > "$BUILD/points.txt"
for seconds in 8.64 4.32 2.16 1.08 0.54 0.27 0.135 0.0675 0.03375 0.016875 0.0084375; do
  RM15_SWAP_LIB="$BUILD/bridge/libfgc44_swap.so"     python3 tests/ribasim-management/test_rm15_dynamic_top_point.py "$seconds" | tee -a "$BUILD/points.txt"
done
python3 tests/ribasim-management/aggregate_rm15_dynamic_top_census.py "$BUILD/points.txt" | tee "$BUILD/summary.txt"
grep -Fq 'RM15_DYNAMIC_TOP_DURATION_CENSUS=PASS' "$BUILD/summary.txt" || fail "missing census marker"
