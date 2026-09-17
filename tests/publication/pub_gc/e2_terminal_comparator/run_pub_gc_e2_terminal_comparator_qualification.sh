#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
cd "$ROOT"

BASE="d2e810649c5deae20bb22f42c92918eb1795d786"
SOURCE_TREE="d7ef6c045263de821db7800459289efcd8a6420b"
SPEC_COMMIT="4e9d891f9a4d1678e5fa4590adae13471597d72e"
SPEC_PATH="docs/publications/PUB-GC_E2_TERMINAL_FLUX_COMPARATOR_SPEC.md"
SPEC_BLOB="7c9f8cdea10a302a84a470e4fc452d44cd6c7967"
MANIFEST_COMMIT="ceb695cbdbf08f5f8c6a97f1af3deac4da69ebc2"
MANIFEST_PATH="docs/publications/manifests/PUB-GC-E2-COMPARATOR-QUAL-0001.yaml"
MANIFEST_BLOB="bfee56e8b61e0d3ffe38546681ede5ddb0468f2c"
GW_A_DIR="tests/publication/pub_gc/gw_a"
ORIGIN_DIR="tests/publication/pub_gc/e1_origin"
ENGINE_DIR="tests/publication/pub_gc/e1_primary_engine"
DIR="tests/publication/pub_gc/e2_terminal_comparator"
MODULE="$DIR/mod_pub_gc_e2_terminal_comparator.f90"
TEST="$DIR/test_pub_gc_e2_terminal_comparator.f90"
RUNNER="$DIR/run_pub_gc_e2_terminal_comparator_qualification.sh"
WORKFLOW=".github/workflows/pub-gc-e2-terminal-comparator-qualification.yml"

fail(){ echo "PUB_GC_E2_COMPARATOR_QUAL_FAIL $*" >&2; exit 71; }

git cat-file -e "$BASE^{commit}" 2>/dev/null || fail "base unavailable"
git merge-base --is-ancestor "$BASE" HEAD || fail "branch does not descend from frozen research base"
[[ "$(git rev-parse HEAD:src)" == "$SOURCE_TREE" ]] || fail "production source tree drift"
[[ "$(git rev-parse HEAD:$GW_A_DIR)" == "$(git rev-parse "$BASE:$GW_A_DIR")" ]] || fail "qualified GW-A changed"
[[ "$(git rev-parse HEAD:$ORIGIN_DIR)" == "$(git rev-parse "$BASE:$ORIGIN_DIR")" ]] || fail "qualified E1 origin harness changed"
[[ "$(git rev-parse HEAD:$ENGINE_DIR)" == "$(git rev-parse "$BASE:$ENGINE_DIR")" ]] || fail "qualified E1 engine changed"

mapfile -t changed < <(git diff --name-only "$BASE..HEAD")
for path in "${changed[@]}"; do
  case "$path" in
    "$DIR"/*|"$WORKFLOW") ;;
    *) fail "out-of-scope comparator mutation: $path" ;;
  esac
done

git fetch --quiet --no-tags origin refs/heads/work/pub-gc-scientific-contract:refs/remotes/origin/work/pub-gc-scientific-contract
for commit in "$SPEC_COMMIT" "$MANIFEST_COMMIT"; do
  git cat-file -e "$commit^{commit}" 2>/dev/null || fail "documentation authority unavailable: $commit"
done
[[ "$(git rev-parse "$SPEC_COMMIT:$SPEC_PATH")" == "$SPEC_BLOB" ]] || fail "comparator spec blob drift"
[[ "$(git rev-parse "$MANIFEST_COMMIT:$MANIFEST_PATH")" == "$MANIFEST_BLOB" ]] || fail "qualification manifest blob drift"

if grep -Eiq 'backend%run_trial|soil_water|mod_fmr|reference_richards|headcalc' "$MODULE" "$TEST"; then
  fail "comparator path contains forbidden SWAP execution dependency"
fi
if grep -Eiq 'groundwater_commit_candidate|groundwater_commit_prepared|%commit' "$MODULE" "$TEST"; then
  fail "comparator path contains forbidden groundwater commit"
fi
grep -Fq 'groundwater_trial_from_checkpoint' "$MODULE" || fail "GW-A trial projection missing"
grep -Fq 'groundwater_discard_candidate' "$MODULE" || fail "GW-A discard missing"
grep -Fq 'q_terminal_flux_cm_per_day * duration_days' "$MODULE" || fail "terminal rectangle formula missing"
grep -Fq 'q_whole_cm - result%q_terminal_cm' "$MODULE" || fail "terminal residual identity missing"

echo "PUB_GC_E2_COMPARATOR_SPEC_LOCK=PASS:$SPEC_COMMIT:$SPEC_BLOB"
echo "PUB_GC_E2_COMPARATOR_MANIFEST_LOCK=PASS:$MANIFEST_COMMIT:$MANIFEST_BLOB"
echo "PUB_GC_E2_COMPARATOR_PRODUCTION_SRC_UNCHANGED=PASS:$SOURCE_TREE"
echo "PUB_GC_E2_COMPARATOR_GW_A_BYTES_UNCHANGED=PASS"
echo "PUB_GC_E2_COMPARATOR_E1_BYTES_UNCHANGED=PASS"
echo "PUB_GC_E2_COMPARATOR_NO_SWAP_EXECUTION_STATIC=PASS"
echo "PUB_GC_E2_COMPARATOR_NO_GW_COMMIT_STATIC=PASS"

BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-pub-gc-e2-comparator-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
SRC=(
  src/runtime/mod_groundwater_coupling_contract.f90
  src/runtime/mod_groundwater_exchange_service_contract.f90
  tests/publication/pub_gc/gw_a/mod_pub_gc_gw_a.f90
  "$MODULE"
)

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  mkdir -p "$OUT"
  objects=()
  for source in "${SRC[@]}"; do
    obj="$OUT/$(echo "$source" | tr '/.' '__').o"
    gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$source" -o "$obj"
    objects+=("$obj")
  done
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$TEST" -o "$OUT/test.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/test.o" -o "$OUT/test"
  timeout 60s "$OUT/test" > "$OUT/output.txt" 2>&1 || {
    cat "$OUT/output.txt" >&2
    fail "O$opt comparator oracle"
  }
  for marker in     'PUB_GC_E2_SYN_EQUAL_EQUIVALENCE=PASS'     'PUB_GC_E2_SYN_TERMINAL_ONLY_SELECTIVITY=PASS'     'PUB_GC_E2_SYN_WHOLE_ONLY_SELECTIVITY=PASS'     'PUB_GC_E2_REAL_E1_B_ANALYTIC=PASS'     'PUB_GC_E2_NONFINITE_FAIL_CLOSED=PASS'     'PUB_GC_E2_COMPARATOR_NO_H2_PRIMARY_INFERENCE=true'     'PUB_GC_E2_TERMINAL_COMPARATOR_ORACLE=PASS'; do
    grep -Fq "$marker" "$OUT/output.txt" || { cat "$OUT/output.txt" >&2; fail "O$opt missing marker $marker"; }
  done
  [[ "$(grep -c '^PUB_GC_E2_COMPARATOR_ROW|' "$OUT/output.txt")" -eq 4 ]] || fail "O$opt comparator row count"
  echo "PUB_GC_E2_COMPARATOR_O$opt=PASS"
done

cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" || {
  diff -u "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" >&2 || true
  fail "O0/O2 scientific output drift"
}

cat "$BUILD/o0/output.txt"
echo "PUB_GC_E2_COMPARATOR_O0_O2_IDENTITY=PASS"
echo "PUB_GC_E2_COMPARATOR_OUTPUT_SHA256=$(sha256sum "$BUILD/o0/output.txt" | awk '{print $1}')"
echo "PUB_GC_E2_COMPARATOR_HEAD=$(git rev-parse HEAD)"
echo "PUB_GC_E2_COMPARATOR_MODULE_BLOB=$(git rev-parse HEAD:$MODULE)"
echo "PUB_GC_E2_COMPARATOR_TEST_BLOB=$(git rev-parse HEAD:$TEST)"
echo "PUB_GC_E2_COMPARATOR_RUNNER_BLOB=$(git rev-parse HEAD:$RUNNER)"
echo "PUB_GC_E2_COMPARATOR_QUALIFICATION=PASS"
