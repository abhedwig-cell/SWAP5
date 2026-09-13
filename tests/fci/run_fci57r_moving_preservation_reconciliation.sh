#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"; cd "$ROOT"

CANON=7bbc7360280ddf27419293db4160bee0b070f7f9
PRE=c19a04721a05c6a00ba264e7477969807dcb258f
QUAL=7c7f8519c94499f3628ef1a08181fdd5d8418d07
OWNER=66fd08ca96d8be69cf6f996202e21ce624db526b
FVQ65=b1fd9e15a22d4dd68997ec38c074ce343eec0a70
FINDING=c14bd8c7f67e015bf1bd4bdcfa88eb97470194da
OLD_AUTH=8a1aeedbaeb5bd015e7e8d098d605968bbecd94e
TX=src/transaction/mod_transaction_reference.f90
TX_BLOB=d5a71a526efaebd82054580c3186f8e3545db331
CB=integration/f-ci-canonical
OB=work/f-kt18-fail-closed-mass-completeness-transaction-admission
VB=qualification/f-vq65-fkt18-fail-closed-mass-completeness-independent-qualification
QB=qualification/f-ci57-fkt18-mass-completeness-current-canonical-admission

for object in "$CANON" "$PRE" "$QUAL" "$OWNER" "$FVQ65" "$FINDING" "$OLD_AUTH"; do
  git cat-file -e "$object^{commit}"
done

for spec in "$CB:$CANON" "$OB:$OWNER" "$VB:$FVQ65" "$QB:$QUAL"; do
  b=${spec%%:*}; e=${spec##*:}
  a=$(git ls-remote origin "refs/heads/$b" | awk '{print $1}')
  test "$a" = "$e" || { echo "FCI57R_FAIL live authority drift: $b expected=$e actual=$a" >&2; exit 20; }
done

git merge-base --is-ancestor "$CANON" HEAD
mapfile -t parents < <(git show -s --format='%P' "$CANON")
read -r p1 p2 extra <<<"${parents[0]}"
test "$p1" = "$PRE"
test "$p2" = "$QUAL"
test -z "${extra:-}"
echo 'FCI57R_CANONICAL_TWO_PARENT_PROMOTION_PROVENANCE=PASS'

# Governance/test reconciliation only: production and reference trees are frozen at admitted F-CI57 postimage.
test "$(git rev-parse HEAD:src)" = "$(git rev-parse "$CANON:src")"
test "$(git rev-parse HEAD:reference)" = "$(git rev-parse "$CANON:reference")"
test "$(git rev-parse "HEAD:$TX")" = "$TX_BLOB"
test "$(git rev-parse "$CANON:$TX")" = "$TX_BLOB"
test "$(git rev-parse "$OWNER:$TX")" = "$TX_BLOB"
test "$(git rev-parse "$FVQ65:$TX")" = "$TX_BLOB"
echo 'FCI57R_PRODUCTION_REFERENCE_AND_TRANSACTION_BLOB_LOCKS=PASS'

allowed='^(\.github/workflows/fci-canonical\.yml|\.github/workflows/fci57r-moving-preservation-reconciliation\.yml|integration/f-ci/F-CI57R_(PRE_REGISTRATION|ARCHITECTURE_AUDIT|STATUS)\.json|tests/fci/run_fci57r_moving_preservation_reconciliation\.sh)$'
unexpected=$(git diff --name-only "$CANON..HEAD" | grep -Ev "$allowed" || true)
test -z "$unexpected" || { printf 'FCI57R_FAIL non-allowlisted delta:\n%s\n' "$unexpected" >&2; exit 21; }

test -z "$(git diff --name-only "$CANON..HEAD" -- src reference)"
echo 'FCI57R_GOVERNANCE_ONLY_SCOPE=PASS'

# fci-canonical dependency surface and all logic remain byte-identical after normalizing only AUTH.
patch=$(git diff --unified=0 "$CANON..HEAD" -- .github/workflows/fci-canonical.yml)
test "$(printf '%s\n' "$patch" | grep '^-' | grep -v '^---' | wc -l)" -eq 1
test "$(printf '%s\n' "$patch" | grep '^+' | grep -v '^+++' | wc -l)" -eq 1
printf '%s\n' "$patch" | grep -Fq -- "-          AUTH=$OLD_AUTH"
printf '%s\n' "$patch" | grep -Fq -- "+          AUTH=$CANON"
old=$(mktemp); new=$(mktemp)
git show "$CANON:.github/workflows/fci-canonical.yml" | sed "s/AUTH=$OLD_AUTH/AUTH=__FCI57R_AUTH__/" > "$old"
sed "s/AUTH=$CANON/AUTH=__FCI57R_AUTH__/" .github/workflows/fci-canonical.yml > "$new"
cmp "$old" "$new"
rm -f "$old" "$new"
grep -Fq "AUTH=$CANON" .github/workflows/fci-canonical.yml
! grep -Fq "AUTH=$OLD_AUTH" .github/workflows/fci-canonical.yml
echo 'FCI57R_MOVING_AUTH_ONLY_WORKFLOW_DELTA=PASS'

python3 - "$FVQ65" <<'PY'
import json, subprocess, sys
fvq=sys.argv[1]
pre=json.load(open('integration/f-ci/F-CI57R_PRE_REGISTRATION.json'))
audit=json.load(open('integration/f-ci/F-CI57R_ARCHITECTURE_AUDIT.json'))
fvq_status=json.loads(subprocess.check_output(['git','show',fvq+':integration/f-vq/F-VQ65_STATUS.json'],text=True))
fci57=json.load(open('integration/f-ci/F-CI57_STATUS.json'))
assert pre['canonical_postimage']=='7bbc7360280ddf27419293db4160bee0b070f7f9'
assert pre['stale_moving_preservation_authority']=='8a1aeedbaeb5bd015e7e8d098d605968bbecd94e'
assert pre['target_moving_preservation_authority']==pre['canonical_postimage']
assert audit['overall']=='30_OF_30_NO_ADVERSE_DELTA_FOR_MOVING_PRESERVATION_RECONCILIATION'
assert len(audit['invariants'])==30 and all(x['status']=='PASS' for x in audit['invariants'])
assert audit['mass_conservation']=='HARD_PRESERVED_FAIL_CLOSED_NO_TOLERANCE_RELAXATION'
assert fvq_status['decision']=='INDEPENDENTLY_QUALIFIED_FKT18_FAIL_CLOSED_MASS_COMPLETENESS_READY_FOR_CANONICAL_ADMISSION'
assert fvq_status['independent_qualification'] is True
assert fci57['decision']=='QUALIFIED_F_CI57_READY_FOR_CANONICAL_PROMOTION'
assert fci57['kernel_transactions_generic_time_mass_v1_qualified_100_percent'] is False
print('FCI57R_AUTHORITY_METADATA_AND_30_INVARIANTS=PASS')
PY

# Replay the independent F-VQ65 oracles against the exact admitted canonical source postimage.
mkdir -p tests/fvq
for f in \
  mod_fvq65_mass_attack_support.f90 \
  test_fvq65_mass_fail_closed.f90 \
  test_fvq65_canonical_gap_witness.f90 \
  run_fvq65_mass_completeness_independent.sh \
  run_fvq65_current_preservation.sh; do
  git show "$FVQ65:tests/fvq/$f" > "tests/fvq/$f"
done
chmod +x tests/fvq/run_fvq65_mass_completeness_independent.sh tests/fvq/run_fvq65_current_preservation.sh
bash tests/fvq/run_fvq65_mass_completeness_independent.sh
bash tests/fvq/run_fvq65_current_preservation.sh

echo 'FCI57R_FVQ65_INDEPENDENT_MASS_AND_PRESERVATION_REPLAY=PASS'
echo "FCI57R_EXACT_HEAD=$(git rev-parse HEAD)"
echo 'F-CI57R MOVING PRESERVATION RECONCILIATION PASS'
