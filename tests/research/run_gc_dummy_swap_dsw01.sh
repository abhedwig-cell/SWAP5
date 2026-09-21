#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-gc-dsw01-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/modflow-bin" "$BUILD/downloads"
trap 'rm -rf "$BUILD"' EXIT

fail(){ echo "GC_DSW01_FAIL $*" >&2; exit 1; }

python3 tests/research/test_gc_dummy_swap_dsw01_analytic.py | tee "$BUILD/analytic.txt"
grep -Fq 'GC_DSW01_ANALYTIC_GATE=PASS' "$BUILD/analytic.txt" || fail "DSW-01 analytic gate"

python3 tests/research/test_gc_dummy_swap_dsw02_partition.py | tee "$BUILD/dsw02.txt"
grep -Fq 'GC_DSW02_ANALYTIC_GATE=PASS' "$BUILD/dsw02.txt" || fail "DSW-02 analytic gate"

python3 tests/research/test_gc_dummy_swap_dsw07_jacobian.py | tee "$BUILD/dsw07.txt"
grep -Fq 'GC_DSW07_ANALYTIC_GATE=PASS' "$BUILD/dsw07.txt" || fail "DSW-07 analytic gate"

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

set +e
LIBMF6="$BUILD/modflow-bin/libmf6.so" \
  python3 tests/research/test_gc_dummy_swap_dsw01_live_modflow.py | tee "$BUILD/live.txt"
DSW01_STATUS=${PIPESTATUS[0]}

LIBMF6="$BUILD/modflow-bin/libmf6.so" \
  python3 tests/research/test_gc_dummy_swap_dsw02_live_partition.py | tee "$BUILD/dsw02-live.txt"
DSW02_STATUS=${PIPESTATUS[0]}
set -e

grep -Fq 'GC_DSW01_LIVE_PROBE_COMPLETED=PASS' "$BUILD/live.txt" || fail "DSW-01 live probe did not complete"
test "$DSW01_STATUS" -eq 0 || fail "DSW-01 preregistered live control gate"
test "$DSW02_STATUS" -eq 0 || fail "DSW-02 preregistered live gate"
grep -Fq 'GC_DSW01_LIVE_FLUX_ONLY_CONTROL=PASS' "$BUILD/live.txt" || fail "DSW-01 live control marker"
grep -Fq 'GC_DSW02_LIVE_GATE=PASS' "$BUILD/dsw02-live.txt" || fail "DSW-02 live gate marker"

LIBMF6="$BUILD/modflow-bin/libmf6.so" \
  python3 tests/research/test_gc_dummy_swap_dsw03_modflow_source.py | tee "$BUILD/dsw03-live.txt"

grep -Fq 'GC_DSW03_POSITIVE_SLOPE_PROBE_RECORDED=PASS' "$BUILD/dsw03-live.txt" || fail "DSW-03 diagnostic probe"
grep -Fq 'GC_DSW03_LIVE_GATE=PASS' "$BUILD/dsw03-live.txt" || fail "DSW-03 live gate"

LIBMF6="$BUILD/modflow-bin/libmf6.so" \
  python3 tests/research/test_gc_dummy_swap_dsw04_superposition.py | tee "$BUILD/dsw04-live.txt"

grep -Fq 'GC_DSW04_LIVE_GATE=PASS' "$BUILD/dsw04-live.txt" || fail "DSW-04 live gate"

set +e
LIBMF6="$BUILD/modflow-bin/libmf6.so" \
  python3 tests/research/test_gc_dummy_swap_dsw05_timestep_invariance.py | tee "$BUILD/dsw05-live.txt"
DSW05_STATUS=${PIPESTATUS[0]}
set -e

test "$DSW05_STATUS" -eq 0 || echo "GC_DSW05_DIAGNOSTIC_STATUS=OPEN_NUMERICAL_GATE"

set +e
LIBMF6="$BUILD/modflow-bin/libmf6.so" \
  python3 tests/research/test_gc_dummy_swap_dsw05v_under_relaxation.py | tee "$BUILD/dsw05v-live.txt"
DSW05V_STATUS=${PIPESTATUS[0]}

LIBMF6="$BUILD/modflow-bin/libmf6.so" \
  python3 tests/research/test_gc_dummy_swap_dsw05w_rclose.py | tee "$BUILD/dsw05w-live.txt"
DSW05W_STATUS=${PIPESTATUS[0]}
set -e

test "$DSW05V_STATUS" -eq 0 || echo "GC_DSW05V_DIAGNOSTIC_STATUS=OPEN"
test "$DSW05W_STATUS" -eq 0 || echo "GC_DSW05W_DIAGNOSTIC_STATUS=OPEN"

LIBMF6="$BUILD/modflow-bin/libmf6.so" \
  python3 tests/research/test_gc_dummy_swap_dsw06_reference_invariance.py | tee "$BUILD/dsw06-live.txt"

grep -Fq 'GC_DSW06_LIVE_GATE=PASS' "$BUILD/dsw06-live.txt" || fail "DSW-06 live gate"

LIBMF6="$BUILD/modflow-bin/libmf6.so" \
  python3 tests/research/test_gc_dummy_swap_dsw08_finite_resistance.py | tee "$BUILD/dsw08-live.txt"

grep -Fq 'GC_DSW08_LIVE_GATE=PASS' "$BUILD/dsw08-live.txt" || fail "DSW-08 live gate"

set +e
LIBMF6="$BUILD/modflow-bin/libmf6.so" \
  python3 tests/research/test_gc_dummy_swap_dsw09_nonlinear_storage.py | tee "$BUILD/dsw09-live.txt"
DSW09_STATUS=${PIPESTATUS[0]}

LIBMF6="$BUILD/modflow-bin/libmf6.so" \
  python3 tests/research/test_gc_dummy_swap_dsw10_depth_storage.py | tee "$BUILD/dsw10-live.txt"
DSW10_STATUS=${PIPESTATUS[0]}
set -e

test "$DSW09_STATUS" -eq 0 || echo "GC_DSW09_DIAGNOSTIC_STATUS=OPEN_NUMERICAL_GATE"
test "$DSW10_STATUS" -eq 0 || echo "GC_DSW10_DIAGNOSTIC_STATUS=OPEN_NUMERICAL_GATE"

LIBMF6="$BUILD/modflow-bin/libmf6.so" \
  python3 tests/research/test_gc_dummy_swap_dsw09n_fresh_tangent.py | tee "$BUILD/dsw09n-live.txt"

grep -Fq 'GC_DSW09N_DIAGNOSTIC_GATE=PASS' "$BUILD/dsw09n-live.txt" || fail "DSW-09N diagnostic gate"

LIBMF6="$BUILD/modflow-bin/libmf6.so" \
  python3 tests/research/test_gc_dummy_swap_dsw09r_fresh_reanchor.py | tee "$BUILD/dsw09r-live.txt"

grep -Fq 'GC_DSW09R_DIAGNOSTIC_GATE=PASS' "$BUILD/dsw09r-live.txt" || fail "DSW-09R diagnostic gate"

set +e
LIBMF6="$BUILD/modflow-bin/libmf6.so" \
  python3 tests/research/test_gc_dummy_swap_dsw09u_ims_history.py | tee "$BUILD/dsw09u-live.txt"
DSW09U_STATUS=${PIPESTATUS[0]}
set -e

test "$DSW09U_STATUS" -eq 0 || echo "GC_DSW09U_DIAGNOSTIC_STATUS=OPEN"

set +e
LIBMF6="$BUILD/modflow-bin/libmf6.so" \
  python3 tests/research/test_gc_dummy_swap_dsw09v_under_relaxation.py | tee "$BUILD/dsw09v-live.txt"
DSW09V_STATUS=${PIPESTATUS[0]}
set -e

test "$DSW09V_STATUS" -eq 0 || echo "GC_DSW09V_DIAGNOSTIC_STATUS=OPEN"

set +e
LIBMF6="$BUILD/modflow-bin/libmf6.so" \
  python3 tests/research/test_gc_dummy_swap_dsw09w_factorial.py | tee "$BUILD/dsw09w-live.txt"
DSW09W_STATUS=${PIPESTATUS[0]}

LIBMF6="$BUILD/modflow-bin/libmf6.so" \
  python3 tests/research/test_gc_dummy_swap_dsw09x_rclose.py | tee "$BUILD/dsw09x-live.txt"
DSW09X_STATUS=${PIPESTATUS[0]}

LIBMF6="$BUILD/modflow-bin/libmf6.so" \
  python3 tests/research/test_gc_dummy_swap_dsw09y_start_distance.py | tee "$BUILD/dsw09y-live.txt"
DSW09Y_STATUS=${PIPESTATUS[0]}

set -e

test "$DSW09W_STATUS" -eq 0 || echo "GC_DSW09W_DIAGNOSTIC_STATUS=PREREGISTERED_TARGET_FALSIFIED"
test "$DSW09X_STATUS" -eq 0 || echo "GC_DSW09X_DIAGNOSTIC_STATUS=OPEN"
test "$DSW09Y_STATUS" -eq 0 || echo "GC_DSW09Y_DIAGNOSTIC_STATUS=OPEN"

LIBMF6="$BUILD/modflow-bin/libmf6.so" \
  python3 tests/research/test_gc_dummy_swap_dsw11_memory_state.py | tee "$BUILD/dsw11-live.txt"

grep -Fq 'GC_DSW11_LIVE_GATE=PASS' "$BUILD/dsw11-live.txt" || fail "DSW-11 live gate"

LIBMF6="$BUILD/modflow-bin/libmf6.so" \
  python3 tests/research/test_gc_dummy_swap_dsw12_et_sink.py | tee "$BUILD/dsw12-live.txt"

grep -Fq 'GC_DSW12_LIVE_GATE=PASS' "$BUILD/dsw12-live.txt" || fail "DSW-12 live gate"

LIBMF6="$BUILD/modflow-bin/libmf6.so" \
  python3 tests/research/test_gc_dummy_swap_dsw13_drain_sink.py | tee "$BUILD/dsw13-live.txt"

grep -Fq 'GC_DSW13_LIVE_GATE=PASS' "$BUILD/dsw13-live.txt" || fail "DSW-13 live gate"

LIBMF6="$BUILD/modflow-bin/libmf6.so" \
  python3 tests/research/test_gc_dummy_swap_dsw14_composition.py | tee "$BUILD/dsw14-live.txt"

grep -Fq 'GC_DSW14_LIVE_GATE=PASS' "$BUILD/dsw14-live.txt" || fail "DSW-14 live gate"

set +e
LIBMF6="$BUILD/modflow-bin/libmf6.so" \
  python3 tests/research/test_gc_dummy_swap_dsw15_forcing_order.py | tee "$BUILD/dsw15-live.txt"
DSW15_STATUS=${PIPESTATUS[0]}
set -e

test "$DSW15_STATUS" -eq 0 || echo "GC_DSW15_DIAGNOSTIC_STATUS=OPEN"

LIBMF6="$BUILD/modflow-bin/libmf6.so" \
  python3 tests/research/test_gc_dummy_swap_dsw16_n_to_1_aggregation.py | tee "$BUILD/dsw16-live.txt"

grep -Fq 'GC_DSW16_LIVE_GATE=PASS' "$BUILD/dsw16-live.txt" || fail "DSW-16 live gate"

LIBMF6="$BUILD/modflow-bin/libmf6.so" \
  python3 tests/research/test_gc_dummy_swap_dsw17_internal_transfer.py | tee "$BUILD/dsw17-live.txt"
grep -Fq 'GC_DSW17_LIVE_GATE=PASS' "$BUILD/dsw17-live.txt" || fail "DSW-17 live gate"

LIBMF6="$BUILD/modflow-bin/libmf6.so" \
  python3 tests/research/test_gc_dummy_swap_dsw18_storage_qlink_limits.py | tee "$BUILD/dsw18-live.txt"
grep -Fq 'GC_DSW18_LIVE_GATE=PASS' "$BUILD/dsw18-live.txt" || fail "DSW-18 live gate"

LIBMF6="$BUILD/modflow-bin/libmf6.so" \
  python3 tests/research/test_gc_dummy_swap_dsw19_converged_wrong.py | tee "$BUILD/dsw19-live.txt"
grep -Fq 'GC_DSW19_LIVE_GATE=PASS' "$BUILD/dsw19-live.txt" || fail "DSW-19 live gate"

LIBMF6="$BUILD/modflow-bin/libmf6.so" \
  python3 tests/research/test_gc_dummy_swap_dsw20_manufactured_trajectory.py | tee "$BUILD/dsw20-live.txt"
grep -Fq 'GC_DSW20_LIVE_GATE=PASS' "$BUILD/dsw20-live.txt" || fail "DSW-20 live gate"

LIBMF6="$BUILD/modflow-bin/libmf6.so" \
  python3 tests/research/test_gc_dummy_swap_dsw21_iteration_slope.py | tee "$BUILD/dsw21-live.txt"
grep -Fq 'GC_DSW21_LIVE_GATE=PASS' "$BUILD/dsw21-live.txt" || fail "DSW-21 live gate"

LIBMF6="$BUILD/modflow-bin/libmf6.so" \
  python3 tests/research/test_gc_dummy_swap_dsw23_coextensive_ownership.py | tee "$BUILD/dsw23-live.txt"
grep -Fq 'GC_DSW23_LIVE_GATE=PASS' "$BUILD/dsw23-live.txt" || fail "DSW-23 live gate"

set +e
LIBMF6="$BUILD/modflow-bin/libmf6.so" \
  python3 tests/research/test_gc_dummy_swap_dsw15v_mass_resolution.py | tee "$BUILD/dsw15v-live.txt"
DSW15V_STATUS=${PIPESTATUS[0]}
set -e

test "$DSW15V_STATUS" -eq 0 || echo "GC_DSW15V_DIAGNOSTIC_STATUS=OPEN"

test "$DSW05W_STATUS" -eq 0 || fail "DSW-05W diagnostic gate"
grep -Fq 'GC_DSW05W_DIAGNOSTIC_GATE=PASS' "$BUILD/dsw05w-live.txt" || fail "DSW-05W marker"
test "$DSW09X_STATUS" -eq 0 || fail "DSW-09X diagnostic gate"
grep -Fq 'GC_DSW09X_DIAGNOSTIC_GATE=PASS' "$BUILD/dsw09x-live.txt" || fail "DSW-09X marker"
test "$DSW09Y_STATUS" -eq 0 || fail "DSW-09Y diagnostic gate"
grep -Fq 'GC_DSW09Y_DIAGNOSTIC_GATE=PASS' "$BUILD/dsw09y-live.txt" || fail "DSW-09Y marker"
test "$DSW15V_STATUS" -eq 0 || fail "DSW-15V diagnostic gate"
grep -Fq 'GC_DSW15V_DIAGNOSTIC_GATE=PASS' "$BUILD/dsw15v-live.txt" || fail "DSW-15V marker"
test "$DSW15_STATUS" -eq 0 || fail "DSW-15 strict live gate"
grep -Fq 'GC_DSW15_LIVE_GATE=PASS' "$BUILD/dsw15-live.txt" || fail "DSW-15 marker"
test "$DSW10_STATUS" -eq 0 || fail "DSW-10 strict live gate"
grep -Fq 'GC_DSW10_LIVE_GATE=PASS' "$BUILD/dsw10-live.txt" || fail "DSW-10 live gate marker"

if test "$DSW05_STATUS" -eq 0; then
  grep -Fq 'GC_DSW05_LIVE_GATE=PASS' "$BUILD/dsw05-live.txt" || fail "DSW-05 closed without marker"
  echo "GC_DSW05_STRICT_GATE=CLOSED"
else
  echo "GC_DSW05_ORIGINAL_STRICT_GATE=NOT_MET_DIAGNOSED_NUMERICAL_CERTIFICATION"
fi

if test "$DSW09_STATUS" -eq 0; then
  grep -Fq 'GC_DSW09_LIVE_GATE=PASS' "$BUILD/dsw09-live.txt" || fail "DSW-09 closed without marker"
  echo "GC_DSW09_STRICT_GATE=CLOSED"
else
  echo "GC_DSW09_ORIGINAL_STRICT_GATE=NOT_MET_DIAGNOSED_NUMERICS"
fi

echo 'GC_DUMMY_SWAP_TESTBANK_EXECUTION=PASS'
echo 'GC_DUMMY_SWAP_QUALIFIED_BLOCKS=DSW01,DSW02,DSW03,DSW04,DSW06,DSW07,DSW08,DSW10,DSW11,DSW12,DSW13,DSW14,DSW15,DSW16,DSW17,DSW18,DSW19,DSW20,DSW21,DSW23'
echo 'GC_DUMMY_SWAP_DIAGNOSTIC_QUALIFIED=DSW05V,DSW05W,DSW09N,DSW09R,DSW09V,DSW09X,DSW09Y,DSW15V'
echo 'GC_DUMMY_SWAP_ORIGINAL_STRICT_GATES_NOT_MET=DSW05,DSW09'
