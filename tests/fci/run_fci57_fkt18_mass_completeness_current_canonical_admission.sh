#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

RESTART=c19a04721a05c6a00ba264e7477969807dcb258f
COMPOSITION=3e294113dfcfdf93744f314bca6f7e38de1783ee
OWNER=66fd08ca96d8be69cf6f996202e21ce624db526b
FVQ65=b1fd9e15a22d4dd68997ec38c074ce343eec0a70
FINDING=c14bd8c7f67e015bf1bd4bdcfa88eb97470194da
TX=src/transaction/mod_transaction_reference.f90
TX_BLOB=d5a71a526efaebd82054580c3186f8e3545db331

for object in "$RESTART" "$COMPOSITION" "$OWNER" "$FVQ65" "$FINDING"; do
  git cat-file -e "$object^{commit}"
done
[[ "$(git rev-parse "$COMPOSITION^")" == "$RESTART" ]]
git merge-base --is-ancestor "$COMPOSITION" HEAD
LIVE_CANONICAL="$(git ls-remote origin refs/heads/integration/f-ci-canonical | awk '{print $1}')"
[[ "$LIVE_CANONICAL" == "$RESTART" ]] || {
  echo "FCI57_LIVE_CANONICAL_DRIFT expected=$RESTART actual=$LIVE_CANONICAL" >&2
  exit 19
}
echo 'FCI57_AUTHORITY_AND_LIVE_CANONICAL_LOCKS=PASS'

mapfile -t prod_changed < <(git diff --name-only "$RESTART..$COMPOSITION" | sort)
[[ "${#prod_changed[@]}" -eq 1 && "${prod_changed[0]}" == "$TX" ]] || {
  printf 'FCI57_COMPOSITION_SCOPE_FAIL actual: %s\n' "${prod_changed[*]}" >&2
  exit 20
}
[[ "$(git rev-parse "$COMPOSITION:$TX")" == "$TX_BLOB" ]]
[[ "$(git rev-parse "HEAD:$TX")" == "$TX_BLOB" ]]
[[ "$(git rev-parse "$OWNER:$TX")" == "$TX_BLOB" ]]
[[ "$(git rev-parse "$FVQ65:$TX")" == "$TX_BLOB" ]]
[[ -z "$(git diff --name-only "$COMPOSITION..HEAD" -- src reference)" ]]
echo 'FCI57_PRODUCTION_COMPOSITION_EXACT_FVQ65_SOURCE_LOCKED=PASS'

allowed=(
  integration/f-ci/F-CI57_PRE_REGISTRATION.json
  integration/f-ci/F-CI57_ARCHITECTURE_AUDIT.json
  integration/f-ci/F-CI57_STATUS.json
  tests/fci/run_fci57_fkt18_mass_completeness_current_canonical_admission.sh
  .github/workflows/fci57-fkt18-mass-completeness-current-canonical-admission.yml
)
mapfile -t qual_changed < <(git diff --name-only "$COMPOSITION..HEAD")
for path in "${qual_changed[@]}"; do
  ok=0
  for candidate in "${allowed[@]}"; do
    [[ "$path" == "$candidate" ]] && ok=1 && break
  done
  [[ "$ok" -eq 1 ]] || { echo "FCI57_QUALIFICATION_SCOPE_FAIL unexpected path: $path" >&2; exit 21; }
done
for path in "${qual_changed[@]}"; do [[ -f "$path" ]]; done
echo 'FCI57_QUALIFICATION_SCOPE_ALLOWLIST=PASS'

python3 - "$FVQ65" <<'PY'
import json, subprocess, sys
fvq=sys.argv[1]
status=json.loads(subprocess.check_output(['git','show',fvq+':integration/f-vq/F-VQ65_STATUS.json'],text=True))
audit=json.loads(subprocess.check_output(['git','show',fvq+':integration/f-vq/F-VQ65_ARCHITECTURE_AUDIT.json'],text=True))
assert status['decision']=='INDEPENDENTLY_QUALIFIED_FKT18_FAIL_CLOSED_MASS_COMPLETENESS_READY_FOR_CANONICAL_ADMISSION'
assert status['independent_qualification'] is True
assert status['canonical_admission'] is False
assert status['owner_authority']['sha']=='66fd08ca96d8be69cf6f996202e21ce624db526b'
assert status['canonical_reference']['sha']=='c19a04721a05c6a00ba264e7477969807dcb258f'
assert status['source_identity']['transaction_source_identical_to_fkt18_authority'] is True
assert status['independent_mass_qualification']['result']=='PASS'
assert status['canonical_gap_witness']['result']=='PASS_DEFECT_REPRODUCED_ON_FROZEN_CANONICAL'
assert status['architecture_audit']['result']=='30_OF_30_NO_ADVERSE_DELTA'
assert audit['summary'].startswith('30_OF_30_NO_ADVERSE_DELTA')
assert audit['canonical_state']['invariant_13']=='FAIL_PENDING_FKT18_ADMISSION'
print('FCI57_FVQ65_INDEPENDENT_AUTHORITY_LOCKED=PASS')
PY

# Materialize the exact independently qualified F-VQ65 oracles into the checkout
# without adding them to F-CI57 history. Admission replays those independent
# tests against this exact current-canonical composition.
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

echo 'FCI57_FVQ65_INDEPENDENT_MASS_REPLAY=PASS'
echo 'FCI57_CURRENT_CANONICAL_PRESERVATION_REPLAY=PASS'

echo "FCI57_EXACT_HEAD=$(git rev-parse HEAD)"
echo 'F-CI57 CURRENT-CANONICAL ADMISSION GATE PASS'
