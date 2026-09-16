#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$ROOT"

BASE=50346642bd565f79134ea17d5462e544b354998c
BASE_TREE=3b085d7dea3d3f3fce42ad9d8f259a8350205846
OUT="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/fvq99-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$OUT"
trap 'rm -rf "$OUT"' EXIT
RESULT_DIR="$ROOT/tests/qualification/fvq99-swap431-status-a-equivalence/results"
rm -rf "$RESULT_DIR"
mkdir -p "$RESULT_DIR"

fail() { echo "FVQ99_FAIL $*" >&2; exit 199; }

[[ "$(git rev-parse "$BASE^{tree}")" == "$BASE_TREE" ]] || fail 'pinned scientific baseline tree mismatch'
git merge-base --is-ancestor "$BASE" HEAD || fail 'qualification head does not descend from scientific baseline'
git diff --quiet "$BASE" -- src reference || {
  git diff --name-only "$BASE" -- src reference >&2
  fail 'production/reference delta from pinned scientific baseline'
}
echo 'FVQ99_PINNED_SCIENTIFIC_TREE=PASS'
echo 'FVQ99_NO_PRODUCTION_OR_REFERENCE_DELTA=PASS'

check_blob() {
  local path="$1" expected="$2" actual
  actual="$(git hash-object "$path")"
  [[ "$actual" == "$expected" ]] || fail "blob drift $path expected=$expected actual=$actual"
}

# Exact current scientific postimage locks used by the independent process oracles.
check_blob src/process/mod_reference_et_demand_process.f90 f5e88ec5089fd3b57ac111065fab2aa32dde0fae
check_blob src/runtime/mod_fmr_reference_et_demand_binding.f90 8c679f911c9a82c498258224d83f5fce3cb09163
check_blob tests/fvq/test_fvq35_reference_et_demand_oracle.f90 a340980b5d5086cdd61e4bb7a212c9c63632513e
check_blob tests/fvq/test_fvq36_fmr23_reference_et_runtime_oracle.f90 de94b4678da5a1cefb6d04c38cd55cb4768925d4
check_blob tests/fci/run_fci21_si25_scientific_replay.sh 76dcc529d7240b1d5b3374498634d64d23de8f90
echo 'FVQ99_ORACLE_AND_PRODUCTION_BLOB_LOCKS=PASS'

# ---------------------------------------------------------------------------
# RICHARDS-15: existing independent B1.10-derived nonlinear oracle versus
# current SWAP5 production seam. This gate owns its frozen tolerance and
# source/evidence locks; do not duplicate or widen them here.
# ---------------------------------------------------------------------------
bash tests/fci/run_fci21_si25_scientific_replay.sh > "$OUT/richards15.txt" 2>&1 || {
  cat "$OUT/richards15.txt" >&2
  fail 'RICHARDS-15 replay failed'
}
for marker in \
  'FCI21_SI25_CASESET_LOCK=PASS:CASES=15' \
  'FCI21_SI25_O0_O2_IDENTITY=PASS' \
  'FCI21_SI25_OWNER_REPLAY_CASES=15' \
  'FCI21_SI25_OWNER_REPLAY=PASS' \
  'FCI21_SI25_SCIENTIFIC_REPLAY PASS'; do
  grep -Fq "$marker" "$OUT/richards15.txt" || fail "RICHARDS-15 missing marker: $marker"
done
cp "$OUT/richards15.txt" "$RESULT_DIR/RICHARDS-15.txt"
echo 'FVQ99_RICHARDS15=PASS'

# ---------------------------------------------------------------------------
# ET-GRID-1700: independently rederived B1.10 ET equations versus the exact
# Status-A process source. We intentionally bypass the historical branch-delta
# precondition while retaining the exact immutable oracle and source blobs.
# ---------------------------------------------------------------------------
COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -Werror -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
for opt in 0 2; do
  D="$OUT/et35-o$opt"; mkdir -p "$D"
  gfortran "${COMMON[@]}" -O"$opt" -J "$D" -I "$D" -c \
    src/process/mod_reference_et_demand_process.f90 -o "$D/process.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$D" -I "$D" -c \
    tests/fvq/test_fvq35_reference_et_demand_oracle.f90 -o "$D/oracle.o"
  gfortran -O"$opt" "$D/process.o" "$D/oracle.o" -o "$D/test"
  "$D/test" > "$D/output.txt" 2>&1 || { cat "$D/output.txt" >&2; fail "ET-GRID-1700 O$opt"; }
  for marker in \
    'FVQ35_INDEPENDENT_GRID_CASES=1700' \
    'FVQ35_INDEPENDENT_B110_EQUATION_ORACLE=PASS' \
    'FVQ35_MM_TO_CM_UNIT_CONVERSION=PASS' \
    'FVQ35_NONEMERGED_VCOVER_SEMANTICS=PASS' \
    'FVQ35_INACTIVE_CROP_FACTOR_DEPENDENCY=PASS' \
    'FVQ35_FAIL_CLOSED_ACTIVE_DOMAIN=PASS' \
    'FVQ35_STATELESS_REPLAY=PASS' \
    'FVQ35_REFERENCE_ET_SCIENTIFIC_ORACLE PASS'; do
    grep -Fq "$marker" "$D/output.txt" || fail "ET-GRID-1700 missing marker O$opt: $marker"
  done
done
cmp "$OUT/et35-o0/output.txt" "$OUT/et35-o2/output.txt" || fail 'ET-GRID-1700 O0/O2 output drift'
cp "$OUT/et35-o0/output.txt" "$RESULT_DIR/ET-GRID-1700.txt"
echo 'FVQ99_ET_GRID_1700=PASS'
echo 'FVQ99_ET_GRID_1700_O0_O2_IDENTITY=PASS'

# ---------------------------------------------------------------------------
# ET-RUNTIME: same B1.10 equation oracle through the admitted generic-time
# runtime binding. Again preserve immutable source/oracle blobs, not the old
# qualification branch-cleanliness condition.
# ---------------------------------------------------------------------------
for opt in 0 2; do
  D="$OUT/et36-o$opt"; mkdir -p "$D"
  gfortran "${COMMON[@]}" -O"$opt" -J "$D" -I "$D" -c \
    src/transaction/mod_transaction_reference.f90 -o "$D/transaction.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$D" -I "$D" -c \
    src/runtime/mod_canonical_contracts.f90 -o "$D/contracts.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$D" -I "$D" -c \
    src/process/mod_reference_et_demand_process.f90 -o "$D/process.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$D" -I "$D" -c \
    src/runtime/mod_fmr_reference_et_demand_binding.f90 -o "$D/binding.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$D" -I "$D" -c \
    tests/fvq/test_fvq36_fmr23_reference_et_runtime_oracle.f90 -o "$D/oracle.o"
  gfortran -O"$opt" "$D/transaction.o" "$D/contracts.o" "$D/process.o" "$D/binding.o" "$D/oracle.o" -o "$D/test"
  "$D/test" > "$D/output.txt" 2>&1 || { cat "$D/output.txt" >&2; fail "ET-RUNTIME O$opt"; }
  for marker in \
    'FVQ36_INDEPENDENT_GRID_CASES=13824' \
    'FVQ36_GENERIC_SIGNED_TIME_ORIGINS=PASS' \
    'FVQ36_VARIABLE_FORCING_SPAN_LENGTHS=PASS' \
    'FVQ36_INDEPENDENT_ET_RATE_ORACLE=PASS' \
    'FVQ36_RATE_INVARIANT_TO_CONTAINED_INTERVAL_DURATION=PASS' \
    'FVQ36_EXACT_FORCING_BOUNDARIES=PASS' \
    'FVQ36_OUTSIDE_FORCING_FAILS_BEFORE_PROCESS=PASS' \
    'FVQ36_INVALID_TIME_GEOMETRY_FAIL_CLOSED=PASS' \
    'FVQ36_NONEMERGED_DEPENDENCY_SEMANTICS=PASS' \
    'FVQ36_STATELESS_A_B_A_IDENTITY=PASS' \
    'FVQ36_FMR23_REFERENCE_ET_RUNTIME_ORACLE PASS'; do
    grep -Fq "$marker" "$D/output.txt" || fail "ET-RUNTIME missing marker O$opt: $marker"
  done
done
cmp "$OUT/et36-o0/output.txt" "$OUT/et36-o2/output.txt" || fail 'ET-RUNTIME O0/O2 output drift'
cp "$OUT/et36-o0/output.txt" "$RESULT_DIR/ET-RUNTIME.txt"
echo 'FVQ99_ET_RUNTIME=PASS'
echo 'FVQ99_ET_RUNTIME_O0_O2_IDENTITY=PASS'

# Build a machine-readable summary without inventing precision not emitted by
# the frozen oracles.
python3 - "$RESULT_DIR/RICHARDS-15.txt" "$RESULT_DIR/RESULTS.json" <<'PY'
import json,re,sys
src,out=sys.argv[1:]
text=open(src, encoding='utf-8').read()
m=re.search(r'FCI21_SI25_OWNER_REPLAY_MAX_ABS_DIFF=([^\s]+)', text)
summary={
  'schema':'fvq99-process-oracle-results-v1',
  'scientific_baseline':'50346642bd565f79134ea17d5462e544b354998c',
  'scientific_tree':'3b085d7dea3d3f3fce42ad9d8f259a8350205846',
  'results':{
    'RICHARDS-15':{
      'status':'PASS',
      'classification':'II_NUMERICALLY_EQUIVALENT',
      'cases':15,
      'max_abs_diff_reported': m.group(1) if m else None,
      'tolerance_authority':'tests/fci/run_fci21_si25_scientific_replay.sh'
    },
    'ET-GRID-1700':{
      'status':'PASS',
      'classification':'II_NUMERICALLY_EQUIVALENT',
      'cases':1700,
      'o0_o2_output_identity':True,
      'oracle_authority':'tests/fvq/test_fvq35_reference_et_demand_oracle.f90'
    },
    'ET-RUNTIME':{
      'status':'PASS',
      'classification':'II_NUMERICALLY_EQUIVALENT',
      'cases':13824,
      'o0_o2_output_identity':True,
      'oracle_authority':'tests/fvq/test_fvq36_fmr23_reference_et_runtime_oracle.f90'
    }
  }
}
open(out,'w',encoding='utf-8').write(json.dumps(summary,indent=2,sort_keys=True)+'\n')
PY
cat "$RESULT_DIR/RESULTS.json"

# Adversarial postcondition: the replay itself did not alter production/reference.
git diff --quiet "$BASE" -- src reference || fail 'post-run production/reference delta'
echo 'FVQ99_PROCESS_ORACLES_QUALIFY=PASS'
