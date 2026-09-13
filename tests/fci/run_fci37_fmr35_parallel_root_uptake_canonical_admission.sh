#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
EVIDENCE_DIR="${FCI37_EVIDENCE_DIR:-_fci37_evidence}"
mkdir -p "$EVIDENCE_DIR"

fail() { echo "FCI37_GATE_FAIL $*" >&2; exit 37; }
BASE=8fa79a70a9faccaf8b63826df607a685eb75b046
FMQ30=48ee2841d783ee023c29391a7ea1e5d7ee0d20e0
CANDIDATE=6b9e47df37513705d3db13edc2c7035526c9c0de
CANDIDATE_BLOB=c78c13997642617376b8d118122c86c60ca77189
CANDIDATE_PATH=src/runtime/mod_fmr_parallel_root_uptake_pool.f90

# Exact current-canonical recomposition scope.
git merge-base --is-ancestor "$BASE" HEAD || fail 'HEAD is not descended from exact F-CI36 canonical base'
mapfile -t src_delta < <(git diff --name-only "$BASE"..HEAD -- src)
[[ ${#src_delta[@]} -eq 1 && "${src_delta[0]}" == "$CANDIDATE_PATH" ]] || \
  fail "unexpected production source delta: ${src_delta[*]:-none}"
git diff --quiet "$BASE"..HEAD -- reference || fail 'reference source changed'
[[ "$(git rev-parse "HEAD:$CANDIDATE_PATH")" == "$CANDIDATE_BLOB" ]] || fail 'candidate blob drift on admission postimage'
if git cat-file -e "$BASE:$CANDIDATE_PATH" 2>/dev/null; then fail 'candidate path unexpectedly existed on F-CI36 base'; fi
git cat-file -e "$CANDIDATE^{commit}" || fail 'F-MR35 candidate commit unavailable'
git cat-file -e "$FMQ30^{commit}" || fail 'F-MQ30 closeout unavailable'

# Existing canonical authorities touched by the composition must remain byte-identical.
check_base_blob() {
  local path="$1" expected actual
  expected="$(git rev-parse "$BASE:$path")"
  actual="$(git rev-parse "HEAD:$path")"
  [[ "$actual" == "$expected" ]] || fail "base authority drift $path expected=$expected actual=$actual"
}
check_base_blob src/runtime/mod_fmr_parallel_worker_pool.f90
check_base_blob src/runtime/mod_fmr_parallel_physical_scheduler.f90
check_base_blob src/runtime/mod_fmr_serialized_multiswap_runtime.f90
check_base_blob src/runtime/mod_fmr_serialized_reference_backend.f90
check_base_blob src/runtime/mod_fmr_reference_et_root_uptake_composition.f90
check_base_blob src/runtime/mod_fmr_divdra_serialized_composition.f90
check_base_blob src/runtime/mod_fmr_divdra_serialized_runtime.f90

echo 'FCI37_CURRENT_CANONICAL_SOURCE_LOCK=PASS'
echo 'FCI37_EXACT_SINGLE_PRODUCTION_OVERLAY=PASS'
echo 'FCI37_REFERENCE_DELTA=NONE'
echo 'FCI37_FCI30_FCI31_FCI34_FCI36_SOURCE_PRESERVATION=PASS'

python3 - <<'PY'
import json
from pathlib import Path
p=Path('integration/f-ci/F-CI37_SOURCE_LOCK.json')
lock=json.loads(p.read_text())
assert lock['canonical_base']['head']=='8fa79a70a9faccaf8b63826df607a685eb75b046'
assert lock['owner_authority']['scientific_candidate']=='6b9e47df37513705d3db13edc2c7035526c9c0de'
assert lock['independent_authority']['closeout']=='48ee2841d783ee023c29391a7ea1e5d7ee0d20e0'
assert lock['production_overlay']['blob']=='c78c13997642617376b8d118122c86c60ca77189'
assert lock['production_overlay']['allowed_src_delta_count']==1
print('FCI37_PERSISTED_SOURCE_LOCK=PASS')
PY

# Rehydrate the exact independently-qualified F-MQ30 gate from its immutable
# closeout. These are temporary working-tree files, never F-CI37 evidence copies.
TMP_PATHS=(
  integration/f-mq/F-MQ30_CANDIDATE_LOCK.json
  integration/f-mq/F-MQ30_QUALIFICATION_MATRIX.json
  tests/fmq/run_fmq30_parallel_root_uptake_qualification.sh
  tests/fmq/run_fmq30_parallel_root_uptake_qualification_v2.sh
)
for p in "${TMP_PATHS[@]}"; do
  [[ ! -e "$p" ]] || fail "temporary F-MQ30 replay path unexpectedly tracked/present: $p"
done
cleanup() { rm -f "${TMP_PATHS[@]}"; }
trap cleanup EXIT
for p in "${TMP_PATHS[@]}"; do
  mkdir -p "$(dirname "$p")"
  git show "$FMQ30:$p" > "$p"
  expected="$(git rev-parse "$FMQ30:$p")"
  actual="$(git hash-object "$p")"
  [[ "$actual" == "$expected" ]] || fail "rehydrated F-MQ30 artifact mismatch: $p"
done
echo 'FCI37_EXACT_FMQ30_CLOSEOUT_GATE_REHYDRATED=PASS'

set +e
bash tests/fmq/run_fmq30_parallel_root_uptake_qualification_v2.sh 2>&1 | tee "$EVIDENCE_DIR/fmq30_replay.txt"
rc=${PIPESTATUS[0]}
set -e
[[ $rc -eq 0 ]] || fail "F-MQ30 replay failed rc=$rc"
grep -Fq 'FMQ30_O0=PASS' "$EVIDENCE_DIR/fmq30_replay.txt" || fail 'missing O0 pass'
grep -Fq 'FMQ30_O2=PASS' "$EVIDENCE_DIR/fmq30_replay.txt" || fail 'missing O2 pass'
grep -Fq 'FMQ30_O0_O2_EXACT_OUTPUT_IDENTITY=PASS' "$EVIDENCE_DIR/fmq30_replay.txt" || fail 'missing O0/O2 identity'
grep -Fq 'FMQ30_HARD_MASS_CONSERVATION=PASS' "$EVIDENCE_DIR/fmq30_replay.txt" || fail 'missing hard mass pass'
grep -Fq 'FMQ30_DECISION=QUALIFIED_IF_WORKFLOW_GREEN' "$EVIDENCE_DIR/fmq30_replay.txt" || fail 'missing independent decision marker'

{
  echo "head=$(git rev-parse HEAD)"
  echo "tree=$(git rev-parse HEAD^{tree})"
  echo "base=$BASE"
  echo "fmq30_closeout=$FMQ30"
  echo "candidate=$CANDIDATE"
  echo "candidate_blob=$(git rev-parse HEAD:$CANDIDATE_PATH)"
  echo "src_delta=${src_delta[*]}"
} > "$EVIDENCE_DIR/source_lock.txt"

echo 'FCI37_INDEPENDENT_FMQ30_REPLAY=PASS'
echo 'FCI37_HARD_MASS_CONSERVATION=PASS'
echo 'FCI37_PRE_ADMISSION=PASS'
