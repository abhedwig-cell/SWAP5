#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

BASE=3144c35eb8c60f822cc363dc48c21591e14b4cf4
MANIFEST=integration/f-ci/F-CI20_CANDIDATE_LOCK_MANIFEST.json
MATRIX=integration/f-ci/F-CI20_CANDIDATE_REPLAY_MATRIX.md
VERDICT=integration/f-ci/F-CI20_CANDIDATE_INTEGRITY_VERDICT.md

fail() { echo "FCI20_CANDIDATE_INTEGRITY_FAIL $*" >&2; exit 1; }

[[ -f "$MANIFEST" ]] || fail "manifest missing"
[[ -f "$MATRIX" ]] || fail "replay matrix missing"
[[ -f "$VERDICT" ]] || fail "verdict missing"

git cat-file -e "$BASE^{commit}" || fail "canonical base commit unavailable"
git merge-base --is-ancestor "$BASE" HEAD || fail "F-CI20 evidence branch no longer descends from locked canonical base"

python3 - "$MANIFEST" <<'PY'
import json, sys
p=sys.argv[1]
m=json.load(open(p, encoding='utf-8'))
assert m['work_unit']=='F-CI20'
assert m['canonical_base']['commit']=='3144c35eb8c60f822cc363dc48c21591e14b4cf4'
assert m['canonical_base']['tree']=='a0c1a4f135589b2b6304427b29341317e867c522'
assert m['governance']['persist_before_composition'] is True
assert m['governance']['production_composition_performed_by_this_manifest'] is False
assert m['governance']['canonical_ref_update_performed'] is False
assert m['governance']['whole_divergent_branch_merge_admitted'] is False

c=m['candidates']
assert c['F-WOF42']['staging_decision']=='ADMIT_AS_PRIMARY_SPINE_FOR_LATER_CONTROLLED_COMPOSITION'
assert c['F-WOF42']['relationship_to_canonical_base']['behind_by']==0
assert c['F-MR18']['staging_decision']=='NO_SEPARATE_OVERLAY'
assert c['F-KT13']['production_identity_against_F-WOF42']['src/kernel/mod_kernel_committed_persistence.f90']['identity']=='EXACT'
assert c['F-KT13']['production_identity_against_F-WOF42']['src/kernel/mod_kernel_transactions.f90']['identity']=='EXACT'
assert c['F-KT13']['staging_decision']=='NO_SEPARATE_PRODUCTION_OVERLAY_SOURCE_EQUIVALENT_IN_WOF42'
assert c['F-KT11']['authoritative_remediated_candidate_source']['commit']=='6e9a684baff6812c3e1be5286f48447a6b4bff76'
assert c['F-KT11']['authoritative_remediated_candidate_source']['tree']=='d24f20559653b028d7967bf57da37da432803221'
assert c['F-KT11']['whole_branch_merge']=='PROHIBITED'
assert c['F-KT11']['staging_decision']=='REPLAY_REQUIRED_DEPENDENCY_BEARING_TEMPORAL_SUBSYSTEM_CANDIDATE'
assert c['F-VQ33']['staging_decision']=='NEGATIVE_HISTORICAL_EVIDENCE_DO_NOT_COUNT_AS_PASS'
assert c['F-VQ33']['decision'].startswith('COMPLETE_FAIL_CLOSED_')
assert c['F-VQ34']['candidate_source_commit']==c['F-KT11']['authoritative_remediated_candidate_source']['commit']
assert c['F-VQ34']['candidate_source_tree']==c['F-KT11']['authoritative_remediated_candidate_source']['tree']
assert c['F-VQ34']['workflow_conclusion']=='success'
assert m['current_admission_verdict']['canonical_promotion_admitted'] is False
assert m['current_admission_verdict']['production_composition_admitted_by_F_CI20_at_this_stage'] is False
print('FCI20_MANIFEST_SEMANTICS=PASS')
PY

grep -Fq 'F-VQ33 failed diagnostic case retained as a negative regression sentinel' "$MATRIX" || fail "VQ33 negative replay sentinel missing"
grep -Fq 'Do not merge branch wholesale' "$MATRIX" || fail "KT11 whole-branch prohibition missing"
grep -Fq 'Only then a separate F-CI composition-postimage qualification' "$MATRIX" || fail "postimage qualification boundary missing"
grep -Fq 'QUALIFIED_ADMISSION_DAG_PERSISTED_COMPOSITION_NOT_YET_AUTHORIZED' "$VERDICT" || fail "verdict decision missing"
grep -Fq 'production `src/` changes by F-CI20: none' "$VERDICT" || fail "no-src-change claim missing"

unexpected=0
while IFS= read -r path; do
  [[ -z "$path" ]] && continue
  case "$path" in
    integration/f-ci/F-CI20_*|tests/fci/run_fci20_candidate_integrity_gate.sh|.github/workflows/fci20-candidate-integrity.yml)
      ;;
    *)
      echo "Unexpected F-CI20 path relative to canonical base: $path" >&2
      unexpected=1
      ;;
  esac
done < <(git diff --name-only "$BASE" HEAD)
[[ "$unexpected" -eq 0 ]] || fail "scope guard"

if git diff --name-only "$BASE" HEAD | grep -q '^src/'; then
  fail "production src changed during admission-only F-CI20"
fi

printf '%s\n' \
  'FCI20_CANONICAL_BASE_LOCK=PASS' \
  'FCI20_SOURCE_AUTHORITY_LOCK=PASS' \
  'FCI20_NEGATIVE_EVIDENCE_PRESERVATION=PASS' \
  'FCI20_REPLAY_POLICY=PASS' \
  'FCI20_ADMISSION_SCOPE_GUARD=PASS' \
  'FCI20_CANDIDATE_INTEGRITY_GATE PASS'
