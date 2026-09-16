#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

BASE=3c5f5bd3686e1632058b906be21abd73883e30ef
BASE_TREE=6baaf40271497db831698c5a01de355b5d296dbe
BASE_REF=9d08625217d7c0a7385df9da6a04183bcd9cb9e6
COMPOSITION=5c68a732fb25535c43b768034cf8a2dd45a85e13
COMPOSITION_TREE=4e143133ff0714cbc7a5a33bd5207f9d180d798e
PE11=b436f8e70664cdb851f20f148463459358568579
PE11_POST_CLOSEOUT_RUN=34554150328
FVQ56=0cdbc193976c73bef208a82547b3c9ea81c4102c
BINDING=src/runtime/mod_fmr_process_hydraulic_view_binding.f90
BINDING_BLOB=67b346251ba21be62c6ed3077f2c71ddd2c8dd02
RUNTIME=src/runtime/mod_fmr_surface_evaporation_runtime_materialization.f90
RUNTIME_BLOB=bc40bc6b121f56071d2b811195759f86130defeb
PROCESS=src/process/mod_restricted_surface_evaporation.f90
CAPACITY_CONTRACT=src/solver/mod_surface_evaporation_capacity_contract.f90
CAPACITY_PROVIDER=src/solver/mod_b110_surface_evaporation_capacity_provider.f90

fail() { echo "FCI42_GATE_FAIL $*" >&2; exit 42; }
need_commit() {
  local sha="$1"
  git cat-file -e "${sha}^{commit}" 2>/dev/null || git fetch --no-tags origin "$sha" >/dev/null 2>&1 || fail "cannot fetch $sha"
}
for sha in "$BASE" "$COMPOSITION" "$PE11" "$FVQ56"; do need_commit "$sha"; done

git fetch --no-tags origin integration/f-ci-canonical >/dev/null 2>&1 || fail 'cannot fetch canonical'
CANONICAL_HEAD="$(git rev-parse origin/integration/f-ci-canonical)"
test "$(git rev-parse ${BASE}^{tree})" = "$BASE_TREE" || fail 'F-CI41P base tree drift'
test "$(git rev-parse ${BASE}:reference)" = "$BASE_REF" || fail 'F-CI41P reference tree drift'

if [[ "$CANONICAL_HEAD" == "$BASE" ]]; then
  echo 'FCI42_PREPROMOTION_CANONICAL_BASE=PASS'
else
  git merge-base --is-ancestor "$COMPOSITION" "$CANONICAL_HEAD" || fail 'post-promotion canonical does not descend from F-CI42 composition'
  test "$(git rev-parse ${CANONICAL_HEAD}:$BINDING)" = "$BINDING_BLOB" || fail 'post-promotion binding blob drift'
  test "$(git rev-parse ${CANONICAL_HEAD}:$RUNTIME)" = "$RUNTIME_BLOB" || fail 'post-promotion materializer blob drift'
  test "$(git rev-parse ${CANONICAL_HEAD}:reference)" = "$BASE_REF" || fail 'post-promotion reference drift'
  echo "FCI42_POSTPROMOTION_CANONICAL_HEAD=${CANONICAL_HEAD}"
  echo 'FCI42_POSTPROMOTION_CANONICAL_IDENTITY=PASS'
fi

test "$(git rev-parse ${COMPOSITION}^)" = "$BASE" || fail 'composition is not direct child of F-CI41P'
test "$(git rev-parse ${COMPOSITION}^{tree})" = "$COMPOSITION_TREE" || fail 'composition tree drift'
test "$(git rev-parse ${COMPOSITION}:$BINDING)" = "$BINDING_BLOB" || fail 'composition binding blob drift'
test "$(git rev-parse ${COMPOSITION}:$RUNTIME)" = "$RUNTIME_BLOB" || fail 'composition materializer blob drift'
test "$(git rev-parse HEAD:$BINDING)" = "$BINDING_BLOB" || fail 'governance changed binding blob'
test "$(git rev-parse HEAD:$RUNTIME)" = "$RUNTIME_BLOB" || fail 'governance changed materializer blob'
git diff --quiet "$COMPOSITION"..HEAD -- src || fail 'post-composition governance changed production source'
test "$(git rev-parse HEAD:reference)" = "$BASE_REF" || fail 'F-CI42 changed reference source'
mapfile -t delta < <(git diff --name-only "$BASE".."$COMPOSITION" -- src | sort)
expected=("$BINDING" "$RUNTIME")
[[ "${delta[*]}" == "${expected[*]}" ]] || fail "unexpected composition production delta: ${delta[*]:-none}"
echo 'FCI42_EXACT_TWO_FILE_PRODUCTION_SCOPE=PASS'
echo 'FCI42_REFERENCE_IMMUTABLE=PASS'

# The closed F-CI41P scientific/canonical authority is prerequisite, not reopened.
git show ${BASE}:integration/f-ci/F-CI41P_STATUS.json | grep -Fq '"final_closeout_complete": true' || fail 'F-CI41P is not finally closed'
git show ${BASE}:integration/f-ci/F-CI41P_STATUS.json | grep -Fq 'QUALIFIED_CURRENT_CANONICAL_SURFACE_EVAPORATION_RUNTIME_POSTIMAGE_GOVERNANCE_RECONCILIATION' || fail 'F-CI41P decision missing'
for path in "$PROCESS" "$CAPACITY_CONTRACT" "$CAPACITY_PROVIDER"; do
  test "$(git rev-parse HEAD:$path)" = "$(git rev-parse $BASE:$path)" || fail "closed scientific/capacity authority reopened: $path"
done
echo 'FCI42_FCI41P_CLOSED_AUTHORITY_PRESERVED=PASS'

# F-PE11 is the performance owner and its final postimage is imported exactly.
test "$(git rev-parse ${PE11}:$BINDING)" = "$BINDING_BLOB" || fail 'PE11 binding donor blob drift'
test "$(git rev-parse ${PE11}:$RUNTIME)" = "$RUNTIME_BLOB" || fail 'PE11 runtime donor blob drift'
git show ${PE11}:integration/f-pe/F-PE11_CLOSEOUT.json | grep -Fq 'QUALIFIED_RETAIN_OWNERSHIP_TRANSFER_CANDIDATE_FOR_FUTURE_CANONICAL_PERFORMANCE_ADMISSION' || fail 'PE11 closeout decision missing'
git show ${PE11}:integration/f-pe/F-PE11_CLOSEOUT.json | grep -Fq '"closed": true' || fail 'PE11 closeout state missing'
echo "FCI42_PE11_POST_CLOSEOUT_RUN_AUTHORITY=${PE11_POST_CLOSEOUT_RUN}"
echo 'FCI42_PE11_EXACT_DONOR_AUTHORITY=PASS'

# F-VQ56 remains the independent scientific runtime oracle. No new scientific admission is inferred from PE11.
git show ${FVQ56}:integration/f-vq/F-VQ56_STATUS.json | grep -Fq 'QUALIFIED_RESTRICTED_SURFACE_EVAPORATION_RUNTIME_MATERIALIZATION_WITHIN_FROZEN_SWINTER0_SWREDU0_SCOPE' || fail 'F-VQ56 authority missing'
echo 'FCI42_FVQ56_SCIENTIFIC_AUTHORITY_PINNED=PASS'

# Replay the frozen PE11 functional/source guard against the exact F-CI42 composition.
bash tests/fpe/run_fpe11_surface_evaporation_allocation_qualification.sh

echo 'FCI42_FUNCTIONAL_AND_SCIENTIFIC_IDENTITY_REPLAY=PASS'

# Admission requires a fresh runner-bound performance signal, but this remains a local microkernel claim.
bash tests/fpe/run_fpe11_paired_surface_evaporation_timing.sh

echo 'FCI42_LOCAL_PERFORMANCE_REPLAY=PASS'
echo 'FCI42_MULTISWAP_SPEEDUP_CLAIM=NOT_MADE'
echo 'FCI42_WHOLE_SWAP_SPEEDUP_CLAIM=NOT_MADE'
echo 'FCI42_CANONICAL_PERFORMANCE_ADMISSION_GATE=PASS'
