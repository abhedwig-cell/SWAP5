#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fmr20-readiness-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

CORE=src/runtime/mod_fmr_runtime_core.f90
CORE_BLOB=543af573b34bfccd8fbdecf719af22994c5236b2
READINESS=integration/f-mr/F-MR20_PARALLEL_READINESS.json
READINESS_BLOB=de0bf5c778d9a2710eb486d289628faf411b6fbd
TEST=tests/fmr/test_fmr20_parallel_readiness.f90
TEST_BLOB=4df4e8f8ed0aeced2671770d7b71675eb2d1d388
MQ23_EVIDENCE=integration/f-mq/F-MQ23_QUALIFICATION_EVIDENCE.json
MQ23_EVIDENCE_BLOB=4b5f6373850a7c701eb5c56961c37b219a3a6e36
BASE_REF=origin/qualification/f-mq23-fvq14-real-physics-runtime

fail() { echo "FMR20_GATE_FAIL $*" >&2; exit 1; }

for spec in \
  "$CORE:$CORE_BLOB" \
  "$READINESS:$READINESS_BLOB" \
  "$TEST:$TEST_BLOB" \
  "$MQ23_EVIDENCE:$MQ23_EVIDENCE_BLOB"; do
  path="${spec%%:*}"; blob="${spec##*:}"
  [[ "$(git rev-parse HEAD:"$path")" == "$blob" ]] || fail "source lock drift $path"
done

echo 'FMR20_G01_SOURCE_LOCK=PASS'

git fetch --quiet --no-tags origin \
  qualification/f-mq23-fvq14-real-physics-runtime:refs/remotes/origin/qualification/f-mq23-fvq14-real-physics-runtime
git diff --name-only "$BASE_REF" HEAD > "$BUILD/changed.txt"
if grep -q '^src/' "$BUILD/changed.txt"; then
  cat "$BUILD/changed.txt" >&2
  fail 'readiness branch modifies production src'
fi
echo 'FMR20_G02_NO_PRODUCTION_SOURCE_CHANGE=PASS'

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)

build_run() {
  local opt="$1"
  local tag="$2"
  local dir="$BUILD/$tag"
  mkdir -p "$dir"
  gfortran "${COMMON[@]}" "$opt" -J "$dir" -I "$dir" \
    "$CORE" "$TEST" -o "$dir/fmr20_readiness"
  "$dir/fmr20_readiness" > "$dir/output.txt"
  grep -Fq 'FMR20_MATRIX_CASES=28' "$dir/output.txt" || fail "matrix count $tag"
  grep -Fq 'FMR20_CANONICAL_TEMPLATE_COLUMN_ORDER=PASS' "$dir/output.txt" || fail "canonical order $tag"
  grep -Fq 'FMR20_STATIC_PARTITION_FORMULA=PASS' "$dir/output.txt" || fail "partition formula $tag"
  grep -Fq 'FMR20_INPUT_ORDER_INDEPENDENCE=PASS' "$dir/output.txt" || fail "input order $tag"
  grep -Fq 'FMR20_COMPLETION_ORDER_INDEPENDENCE=PASS' "$dir/output.txt" || fail "completion order $tag"
  grep -Fq 'FMR20_EXACTLY_ONCE_ASSIGNMENT=PASS' "$dir/output.txt" || fail "exactly once $tag"
  grep -Fq 'FMR20_EMPTY_WORKER_DETERMINISM=PASS' "$dir/output.txt" || fail "empty workers $tag"
  grep -Fq 'FMR20_BOUNDED_DIFFICULT_LANE_ROUTING=PASS' "$dir/output.txt" || fail "difficult lanes $tag"
  grep -Fq 'FMR20_PHYSICAL_IDENTITY_NONMUTATION=PASS' "$dir/output.txt" || fail "identity nonmutation $tag"
  grep -Fq 'FMR20_HARD_MASS_GATE_REQUIREMENT_PRESERVED=PASS' "$dir/output.txt" || fail "mass requirement $tag"
  grep -Fq 'FMR20_REFERENCE_COMPLETION_AVAILABLE=PASS' "$dir/output.txt" || fail "reference completion $tag"
  grep -Fq 'FMR20_DETERMINISTIC_REPLAY=PASS' "$dir/output.txt" || fail "replay $tag"
  grep -Fq 'FMR20_SCHEDULER_READINESS_ORACLE=PASS' "$dir/output.txt" || fail "final marker $tag"
  echo "FMR20_${tag}=PASS"
}

build_run -O0 O0
build_run -O2 O2
cmp -s "$BUILD/O0/output.txt" "$BUILD/O2/output.txt" || { diff -u "$BUILD/O0/output.txt" "$BUILD/O2/output.txt" >&2 || true; fail 'O0/O2 output identity'; }
echo 'FMR20_G03_O0_O2_OUTPUT_IDENTITY=PASS'
echo 'FMR20_PARALLEL_READINESS_GATE=PASS'
