#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-gc-dsw21-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/modflow-bin" "$BUILD/downloads"
trap 'rm -rf "$BUILD"' EXIT

fail(){ echo "GC_DSW21_FAIL $*" >&2; exit 1; }

python3 - <<PY
from pathlib import Path
from flopy.utils.get_modflow import run_main
run_main(
    Path("$BUILD/modflow-bin"),
    owner="MODFLOW-ORG",
    repo="modflow6",
    release_id="6.8.0",
    subset={"mf6", "libmf6.so"},
    downloads_dir=Path("$BUILD/downloads"),
    force=True,
    quiet=False,
)
PY

ARCHIVE="$BUILD/downloads/modflow6-6.8.0-linux.zip"
echo "33edf988b672a9f282d6773304c079d0f180541f6fe0c6555265d9c71841256e  $ARCHIVE" | sha256sum -c - || fail "MODFLOW asset hash"
test -f "$BUILD/modflow-bin/libmf6.so" || fail "missing libmf6.so"

LIBMF6="$BUILD/modflow-bin/libmf6.so" \
  python3 tests/research/test_gc_dummy_swap_dsw21_iteration_slope.py | tee "$BUILD/dsw21.txt"

for marker in \
  'GC_DSW21_PHYSICAL_J_ONE_STEP_ROOT=PASS' \
  'GC_DSW21_INTERCEPT_ONLY_RHO_MATCH=PASS' \
  'GC_DSW21_POSITIVE_HALF_RHO_MATCH=PASS' \
  'GC_DSW21_POSITIVE_U_RHO_MATCH=PASS' \
  'GC_DSW21_FIXED_POINT_INDEPENDENT_OF_SLOPE_POLICY=PASS' \
  'GC_DSW21_ANALYTIC_ERROR_FACTORS=PASS' \
  'GC_DSW21_SINGULAR_OVERLAP=PASS' \
  'GC_DSW21_LIVE_GATE=PASS'; do
  grep -Fq "$marker" "$BUILD/dsw21.txt" || fail "missing marker $marker"
done

git diff --check -- \
  tests/research/test_gc_dummy_swap_dsw21_iteration_slope.py \
  tests/research/run_gc_dummy_swap_dsw21.sh \
  integration/research/GC_DUMMY_SWAP_DSW21_PREREGISTRATION.json

echo 'GC DUMMY SWAP DSW21 ITERATION SLOPE GATE PASS'
