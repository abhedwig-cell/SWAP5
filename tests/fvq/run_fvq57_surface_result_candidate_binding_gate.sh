#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
SOURCE_AUTH=0aeb0a2ed4096e1f9493d3dabc70962ea5270182
OWNER=a5e31470091e2008512141934fced47983449983
OWNER_FILE=src/runtime/mod_fmr_surface_evaporation_accepted_publication.f90
OWNER_BLOB=3ab9cb4be6eb211e8f6cd86f89665bb42c2332e1
BUILD="${RUNNER_TEMP:-/tmp}/fvq57-${GITHUB_RUN_ID:-local}"
rm -rf "$BUILD"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT

fail() { echo "FVQ57_GATE_FAIL $*" >&2; exit 1; }
need_commit() {
  local sha="$1"
  git cat-file -e "${sha}^{commit}" 2>/dev/null || git fetch --no-tags origin "$sha" >/dev/null 2>&1 || fail "cannot fetch $sha"
}
need_commit "$SOURCE_AUTH"
need_commit "$OWNER"
test "$(git merge-base "$SOURCE_AUTH" HEAD)" = "$SOURCE_AUTH" || fail 'qualification branch does not descend from pinned canonical source authority'
if git diff --name-only "$SOURCE_AUTH"..HEAD -- src | grep -q .; then
  git diff --name-only "$SOURCE_AUTH"..HEAD -- src >&2
  fail 'independent qualification branch must have no src delta'
fi
echo 'FVQ57_CLEAN_CANONICAL_QUALIFICATION_BRANCH_NO_SRC_DELTA=PASS'

git show "$OWNER:$OWNER_FILE" > "$BUILD/candidate.f90"
[[ "$(git hash-object "$BUILD/candidate.f90")" == "$OWNER_BLOB" ]] || fail 'exact pinned owner candidate blob mismatch'
echo 'FVQ57_EXACT_PINNED_FPM06G_CANDIDATE_BLOB=PASS'

python3 - "$BUILD/candidate.f90" <<'PY'
from pathlib import Path
import sys
s = Path(sys.argv[1]).read_text(encoding='utf-8').lower()
required = ['surface_evaporation_result_t','kernel_candidate_state_t','fmr_accepted_commit_receipt_t']
for token in required:
    if token not in s:
        raise SystemExit(f'missing candidate token: {token}')
# Candidate-level risk characterization: the surface result type supplied to
# prepare has no result-side lineage/revision/interval receipt. Dynamic HN1 is
# the decisive gate; this source check merely documents why the attack is valid.
print('FVQ57_CANDIDATE_INTERFACE_RISK_CHARACTERIZED=PASS')
PY

COMMON=(-std=f2008 -Wall -Wextra -ffree-line-length-none -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
MODULES=(
  src/transaction/mod_transaction_reference.f90
  src/runtime/mod_canonical_contracts.f90
  src/runtime/mod_canonical_interval_runtime.f90
  src/kernel/mod_kernel_transactions.f90
  src/process/mod_restricted_surface_evaporation.f90
  src/runtime/mod_fmr_accepted_commit_receipt.f90
  tests/fvq/mod_fvq57_independent_publication_backend.f90
)

hn1_fail_open=0
for opt in 0 2; do
  OUT="$BUILD/o$opt"
  mkdir -p "$OUT"
  objects=()
  for src in "${MODULES[@]}"; do
    obj="$OUT/$(basename "${src%.*}").o"
    gfortran "${COMMON[@]}" -O"$opt" -J"$OUT" -I"$OUT" -c "$src" -o "$obj"
    objects+=("$obj")
  done
  gfortran "${COMMON[@]}" -O"$opt" -J"$OUT" -I"$OUT" -c "$BUILD/candidate.f90" -o "$OUT/candidate.o"
  objects+=("$OUT/candidate.o")
  gfortran "${COMMON[@]}" -O"$opt" -J"$OUT" -I"$OUT" -c tests/fvq/test_fvq57_surface_result_candidate_binding.f90 -o "$OUT/test.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/test.o" -o "$OUT/test"
  set +e
  "$OUT/test" > "$OUT/out.txt" 2>&1
  rc=$?
  set -e
  cat "$OUT/out.txt"
  grep -Fq 'FVQ57_GENERIC_TRANSACTION_HARD_MASS_CONTROL=PASS' "$OUT/out.txt" || fail "O$opt hard-mass positive control missing"
  if grep -Fq 'FVQ57_HN1_SURFACE_RESULT_CANDIDATE_BINDING=PASS' "$OUT/out.txt"; then
    [[ $rc -eq 0 ]] || fail "O$opt safe HN1 path returned nonzero"
    echo "FVQ57_HN1_O${opt}=PASS_REJECTED_MISMATCH"
  elif grep -Fq 'FVQ57_HN1_FAIL_OPEN=YES' "$OUT/out.txt"; then
    [[ $rc -ne 0 ]] || fail "O$opt fail-open marker unexpectedly returned zero"
    grep -Fq 'FVQ57_MATCHING_A_POSITIVE_CONTROL=PASS' "$OUT/out.txt" || fail "O$opt matching positive control missing"
    grep -Fq 'FVQ57_COMMITTED_PHYSICAL_CASE_A=PASS' "$OUT/out.txt" || fail "O$opt physical-case control missing"
    echo "FVQ57_HN1_O${opt}=FAIL_OPEN_REPRODUCED"
    hn1_fail_open=$((hn1_fail_open+1))
  else
    fail "O$opt HN1 produced neither safe rejection nor classified fail-open"
  fi
done

# Observable fail-open must reproduce across optimization levels. Normalize the
# compiler's final ERROR STOP line before comparing because runtime formatting
# can contain non-semantic process metadata.
sed '/^ERROR STOP 57$/d' "$BUILD/o0/out.txt" > "$BUILD/o0.norm"
sed '/^ERROR STOP 57$/d' "$BUILD/o2/out.txt" > "$BUILD/o2.norm"
cmp -s "$BUILD/o0.norm" "$BUILD/o2.norm" || { diff -u "$BUILD/o0.norm" "$BUILD/o2.norm" >&2 || true; fail 'O0/O2 HN1 observation drift'; }
echo 'FVQ57_O0_O2_HN1_OBSERVATION_IDENTITY=PASS'

if [[ $hn1_fail_open -eq 2 ]]; then
  echo 'FVQ57_HARD_NEGATIVE_HN1=FAIL_OPEN'
  echo 'FVQ57_DECISION=NOT_QUALIFIED_RESTRICTED_ACCEPTED_SURFACE_EVAPORATION_PUBLICATION_PROVENANCE'
  echo 'FVQ57_ROUTE_BACK=OWNER_OR_RUNTIME_COMPOSITION_MUST_BIND_EXACT_SURFACE_RESULT_TO_PHYSICAL_CANDIDATE_BY_CONSTRUCTION'
  exit 57
fi

echo 'FVQ57_HARD_NEGATIVE_HN1=PASS'
echo 'FVQ57_DECISION=HN1_PASSED_CONTINUE_SECONDARY_MATRIX'
