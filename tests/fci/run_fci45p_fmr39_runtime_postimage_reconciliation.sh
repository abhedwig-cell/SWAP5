#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

OLD=e342f4f9c9d45e2ec2d23a6be6032cc0498d98e2
QUAL=2decde7d4d2ac3cee040d63b25ff7a97ca6db63e
PROMOTED=14db7be4827e73650da18d494af5cf190e687490
PROMOTED_TREE=10e5f8fc1038a77bb0fad88249bf8d524858f6a2
BASE_REF=9d08625217d7c0a7385df9da6a04183bcd9cb9e6
STRONG_REPLAY=e7d667d703f7e9f1e62cfab5d3457172540259e1
BACKEND=src/runtime/mod_fmr_serialized_reference_backend.f90
RESTART=src/runtime/mod_fmr_restart_state_contract.f90
BACKEND_BLOB=07877429f94ccf07c353fa5f8ba969c341ad88dd
RESTART_BLOB=bb2c37efce37a73441181f14d15847c652ab45ea
FCI45_STATUS=integration/f-ci/F-CI45_STATUS.json
FCI45_EVIDENCE=integration/f-ci/F-CI45_EVIDENCE.json
FCI45_STATUS_BLOB=8ed79e93798a8a92f8b4540c6bafa1fba5bde34b
FCI45_EVIDENCE_BLOB=b9ce85c47141fe1f95dc1b485a3d592e19f52fd8

fail(){ echo "FCI45P_GATE_FAIL $*" >&2; exit 46; }
for sha in "$OLD" "$QUAL" "$PROMOTED" "$STRONG_REPLAY"; do git cat-file -e "$sha^{commit}" || fail "missing $sha"; done

git fetch --no-tags origin integration/f-ci-canonical >/dev/null 2>&1 || fail 'cannot fetch canonical'
CURRENT="$(git rev-parse origin/integration/f-ci-canonical)"
[[ "$CURRENT" == "$PROMOTED" ]] || fail "canonical race expected $PROMOTED got $CURRENT"
echo 'FCI45P_CANONICAL_POSTIMAGE_RACE_GUARD=PASS'

read -r commit p1 p2 extra <<< "$(git rev-list --parents -n 1 "$PROMOTED")"
[[ "$commit" == "$PROMOTED" && "$p1" == "$OLD" && "$p2" == "$QUAL" && -z "${extra:-}" ]] || fail 'promotion is not exact true two-parent merge'
[[ "$(git rev-parse ${PROMOTED}^{tree})" == "$PROMOTED_TREE" ]] || fail 'promoted tree mismatch'
[[ "$(git rev-parse ${QUAL}^{tree})" == "$PROMOTED_TREE" ]] || fail 'promoted tree differs from exact qualified candidate tree'
echo 'FCI45P_TRUE_TWO_PARENT_PROMOTION_TOPOLOGY=PASS'
echo 'FCI45P_PROMOTED_TREE_IDENTICAL_TO_QUALIFIED_CANDIDATE=PASS'

# Reconciliation work itself may add support evidence only.
test -z "$(git diff --name-only "$PROMOTED"..HEAD -- src)" || fail 'postimage branch changed production source'
test -z "$(git diff --name-only "$PROMOTED"..HEAD -- reference)" || fail 'postimage branch changed frozen reference'
test "$(git rev-parse HEAD:$BACKEND)" = "$BACKEND_BLOB" || fail 'backend blob drift after promotion'
test "$(git rev-parse HEAD:$RESTART)" = "$RESTART_BLOB" || fail 'restart blob drift after promotion'
test "$(git rev-parse HEAD:reference)" = "$BASE_REF" || fail 'reference tree changed after promotion'
mapfile -t delta < <(git diff --name-only "$OLD".."$PROMOTED" -- src | sort)
printf '%s\n' "${delta[@]}" > /tmp/fci45p-delta
printf '%s\n' "$BACKEND" "$RESTART" | sort > /tmp/fci45p-expected
cmp -s /tmp/fci45p-delta /tmp/fci45p-expected || { cat /tmp/fci45p-delta >&2; fail 'promoted production delta differs from qualified two-file scope'; }
echo 'FCI45P_NO_POSTPROMOTION_PRODUCTION_DRIFT=PASS'
echo 'FCI45P_PROMOTED_PRODUCTION_SCOPE_EXACT=PASS'
echo 'FCI45P_REFERENCE_IMMUTABLE=PASS'

# The promoted tree must contain exactly the prepromotion status/evidence that accompanied the qualified head.
test "$(git rev-parse ${PROMOTED}:$FCI45_STATUS)" = "$FCI45_STATUS_BLOB" || fail 'promoted F-CI45 status drift'
test "$(git rev-parse ${PROMOTED}:$FCI45_EVIDENCE)" = "$FCI45_EVIDENCE_BLOB" || fail 'promoted F-CI45 evidence drift'
python3 - <<'PY'
import json
from pathlib import Path
s=json.loads(Path('integration/f-ci/F-CI45_STATUS.json').read_text())
e=json.loads(Path('integration/f-ci/F-CI45_EVIDENCE.json').read_text())
a=json.loads(Path('integration/f-ci/F-CI45_ARCHITECTURE_AUDIT.json').read_text())
assert s['canonical_base']=='e342f4f9c9d45e2ec2d23a6be6032cc0498d98e2'
assert s['composition_head']=='97515d75c96e9766f3b8697a7b40b28ec237118f'
assert s['promotion_gate']['require_true_two_parent_merge_commit'] is True
assert e['first_green_run']==34633372426 and e['first_green_job']==103375339565
assert e['runtime_output_sha256']=='cb08b8dc528f9a1dfc11db9ffffad5598fa9c4584b12feada1d129e47a236942'
assert e['corroborating_F_MR40R']['result']=='PASS'
assert len(a['invariants'])==30 and sorted(x['id'] for x in a['invariants'])==list(range(1,31))
print('FCI45P_PROMOTED_QUALIFICATION_EVIDENCE_BOUND=PASS')
print('FCI45P_ALL_30_ARCHITECTURE_INVARIANTS_PRESERVED=PASS')
PY

# Bind the independently replayed promoted-tree runtime evidence. The replay branch may
# differ in governance files only; production and frozen reference trees must be identical.
test "$(git rev-parse ${STRONG_REPLAY}:$BACKEND)" = "$BACKEND_BLOB" || fail 'strong replay backend blob drift'
test "$(git rev-parse ${STRONG_REPLAY}:$RESTART)" = "$RESTART_BLOB" || fail 'strong replay restart blob drift'
test "$(git rev-parse ${STRONG_REPLAY}:reference)" = "$BASE_REF" || fail 'strong replay reference drift'
git diff --quiet "$STRONG_REPLAY"..HEAD -- src || fail 'strong replay production tree differs from final reconciliation tree'
git diff --quiet "$STRONG_REPLAY"..HEAD -- reference || fail 'strong replay reference differs from final reconciliation tree'
python3 - <<'PY'
import json
from pathlib import Path
e=json.loads(Path('integration/f-ci/F-CI45P_EVIDENCE.json').read_text())
a=json.loads(Path('integration/f-ci/F-CI45P_ARCHITECTURE_RECONCILIATION.json').read_text())
assert e['promoted_canonical_head']=='14db7be4827e73650da18d494af5cf190e687490'
assert e['strong_runtime_replay']['head']=='e7d667d703f7e9f1e62cfab5d3457172540259e1'
assert e['strong_runtime_replay']['run']==34634089100
assert e['strong_runtime_replay']['job']==103377667419
assert e['strong_runtime_replay']['conclusion']=='success'
assert e['strong_runtime_replay']['runtime_output_sha256']=='cb08b8dc528f9a1dfc11db9ffffad5598fa9c4584b12feada1d129e47a236942'
for key in ('runtime_O0_O2','FMR19_preservation','FVQ58_replay','FCI44_contract_oracle','all_30_invariants'):
    assert e['strong_runtime_replay']['checks'][key]=='PASS'
assert len(a['invariants'])==30 and sorted(x['id'] for x in a['invariants'])==list(range(1,31))
assert a['result']=='PASS_SUBJECT_TO_EXACT_POSTIMAGE_GATE'
print('FCI45P_STRONG_PROMOTED_RUNTIME_REPLAY_BOUND=PASS')
print('FCI45P_POSTIMAGE_ARCHITECTURE_RECONCILIATION_BOUND=PASS')
PY

# Final branch scope is support-only and enumerated.
mapfile -t support_delta < <(git diff --name-only "$PROMOTED"..HEAD | sort)
for path in "${support_delta[@]}"; do
  case "$path" in
    .github/workflows/fci45p-fmr39-runtime-postimage-reconciliation.yml|\
    integration/f-ci/F-CI45P_STATUS.json|\
    integration/f-ci/F-CI45P_EVIDENCE.json|\
    integration/f-ci/F-CI45P_ARCHITECTURE_RECONCILIATION.json|\
    tests/fci/run_fci45p_fmr39_runtime_postimage_reconciliation.sh) ;;
    *) fail "unexpected F-CI45P support delta: $path" ;;
  esac
done
echo 'FCI45P_SUPPORT_ONLY_SCOPE_ENUMERATED=PASS'

git diff --check "$PROMOTED" -- integration/f-ci tests/fci .github/workflows || fail 'postimage support diff check failed'
echo 'FCI45P_PREPROMOTION_EXACT_HEAD_RUN=34633690114'
echo 'FCI45P_PREPROMOTION_EXACT_HEAD_JOB=103376369124'
echo 'FCI45P_PREPROMOTION_STATUS_VALIDATION_RUN=34633690125'
echo 'FCI45P_PREPROMOTION_STATUS_VALIDATION_JOB=103376369188'
echo 'FCI45P_STRONG_PROMOTED_RUNTIME_REPLAY_RUN=34634089100'
echo 'FCI45P_STRONG_PROMOTED_RUNTIME_REPLAY_JOB=103377667419'
echo 'FCI45P_RUNTIME_OUTPUT_SHA256=cb08b8dc528f9a1dfc11db9ffffad5598fa9c4584b12feada1d129e47a236942'
echo 'FCI45P_PRODUCTION_SOURCE_CHANGED=NO'
echo 'FCI45P_RB1_REOPENED=NO'
echo 'FCI45P_POSTIMAGE_RECONCILIATION_GATE=PASS'
