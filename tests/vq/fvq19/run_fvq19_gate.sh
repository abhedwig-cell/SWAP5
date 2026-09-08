#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$ROOT"

CANDIDATE="439432ad91d64353e70afda4ff0837f69521a9e5"
EXPECTED_TREE="6fb99c994ab88435a3eaf675d6d9e945cc3a9d79"
FVQ17_CLOSEOUT="1d9ff946f45488557d10700f047089d3298a4794"
ARTIFACTS=".fvq19-artifacts"
BUILD="${TMPDIR:-/tmp}/swap5-fvq19-$$"
rm -rf "$ARTIFACTS" "$BUILD"
mkdir -p "$ARTIFACTS" "$BUILD"
trap 'rm -rf "$BUILD"' EXIT

actual_tree="$(git rev-parse "${CANDIDATE}^{tree}")"
[[ "$actual_tree" == "$EXPECTED_TREE" ]] || {
  echo "FVQ19_CANDIDATE_TREE_MISMATCH expected=$EXPECTED_TREE actual=$actual_tree" >&2
  exit 1
}
git merge-base --is-ancestor "$CANDIDATE" HEAD

git diff --exit-code "$CANDIDATE"..HEAD -- src reference
printf '%s\n' "$CANDIDATE" > "$ARTIFACTS/candidate.txt"
printf '%s\n' "$EXPECTED_TREE" > "$ARTIFACTS/candidate-tree.txt"
printf '%s\n' "$FVQ17_CLOSEOUT" > "$ARTIFACTS/fvq17-closeout.txt"
echo 'FVQ19_QUALIFICATION_SOURCE_IMMUTABILITY=PASS'

audit_out="$ARTIFACTS/source-audit.out"
python3 tools/vq/fvq19_fmr08_nonstationary_audit.py > "$audit_out"
for marker in \
  'FVQ19_CANDIDATE_TREE_LOCK=PASS' \
  'FVQ19_CURRENT_EVIDENCE_BLOB_LOCK=PASS' \
  'FVQ19_PREEXISTING_FMR06_FILES_UNCHANGED=PASS' \
  'FVQ19_NON_MIDNIGHT_ONE_CALL_DAILY_INTERVAL=PASS' \
  'FVQ19_NONSTATIONARY_PERSISTENT_SNOW_STATE=PASS' \
  'FVQ19_ZERO_TEMPORAL_TOLERANCE=PASS' \
  'FVQ19_ACTIVE_SNOW_IN_EXACT_TEMPORAL_COMPARATOR=PASS' \
  'FVQ19_HARD_MASS_AND_TRANSACTION_CONTRACT=PASS' \
  'FVQ19_INDEPENDENT_SOURCE_AUDIT PASS'; do
    grep -Fq "$marker" "$audit_out"
done
cat "$audit_out"

FVQ17_WORKTREE="$BUILD/fvq17-worktree"
git worktree add --detach "$FVQ17_WORKTREE" "$FVQ17_CLOSEOUT" > "$ARTIFACTS/fvq17-worktree-add.out" 2>&1
(
  cd "$FVQ17_WORKTREE"
  bash tests/vq/fvq17/run_fvq17_gate.sh
) > "$ARTIFACTS/fvq17-direct-replay.out" 2>&1 || {
  cat "$ARTIFACTS/fvq17-direct-replay.out" >&2
  exit 1
}
grep -Fq 'FVQ17_SOURCE_IMMUTABILITY=PASS' "$ARTIFACTS/fvq17-direct-replay.out"
grep -Fq 'FVQ17_FMR06_ENGINEERING_REPLAY=PASS' "$ARTIFACTS/fvq17-direct-replay.out"
grep -Fq 'FVQ17_DIRECT_FVQ16_ORACLE_REPLAY=PASS' "$ARTIFACTS/fvq17-direct-replay.out"
grep -Fq 'FVQ17_O0=PASS' "$ARTIFACTS/fvq17-direct-replay.out"
grep -Fq 'FVQ17_O2=PASS' "$ARTIFACTS/fvq17-direct-replay.out"
grep -Fq 'FVQ17_O0_O2_OUTPUT_IDENTITY=PASS' "$ARTIFACTS/fvq17-direct-replay.out"
grep -Fq 'FVQ17_GATE PASS_INDEPENDENT_FMR06_SNOW_MULTISWAP_SCIENTIFIC_ADMISSION' "$ARTIFACTS/fvq17-direct-replay.out"
git worktree remove --force "$FVQ17_WORKTREE" > "$ARTIFACTS/fvq17-worktree-remove.out" 2>&1

echo 'FVQ19_DIRECT_FVQ17_CLOSEOUT_REPLAY=PASS'
git diff --exit-code "$CANDIDATE"..HEAD -- src reference
sha256sum "$audit_out" "$ARTIFACTS/fvq17-direct-replay.out" > "$ARTIFACTS/evidence.sha256"
echo 'FVQ19_GATE PASS_INDEPENDENT_NONSTATIONARY_EXACT_TEMPORAL_ACCEPTANCE'
