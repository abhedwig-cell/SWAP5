#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

CANONICAL="9770a659d5a93d9abe1341815b57c0fb2fea15ec"
DONOR="cfa4e9dcd9a283d85ade316651d34cac93958a4a"
BLOCKED_DONOR="7c1c5251a2dff94291db381cf0b66631b81e9f05"
FVQ60="773b1dec23957f2d86648b82ab76f8daede2cbbc"
GC18="774c01d69c619f463e0d471eb797f8f0418fee07"
GC18A="ac25e009b795f231a522d2f048795ccc1d64417c"
RG01="09ef05c60c5e45af218980001c8ad8ec30da2e9e"
COUPLING_BLOB="fc598d14eabafcb025bb55621f7b00d6d1816f10"
SERVICE_BLOB="f0fc25592624360802713a9487813d119e7dc4e9"
OWNER_TEST_BLOB="a9bf9b44360e78d20e271ed466cde0ea22943d85"
OWNER_GATE_BLOB="481b3da99f9838f7f0d55844f6a9fe77721d4d62"
OWNER_WORKFLOW_BLOB="ffe52a1df77a3591a0d97a0d4273f9b3498041de"
OWNER_STATUS_BLOB="a36e6c01dd06e40657ea4b0c4e5e6ac67efd5e9d"
OWNER_AUDIT_BLOB="cba91149216dfad23a6398e7fb3c242efbde5318"

# Fail closed on every moving branch used as live authority for this run.
git fetch --no-tags origin \
  "+refs/heads/integration/f-ci-canonical:refs/remotes/origin/integration/f-ci-canonical" \
  "+refs/heads/work/f-gc18r-r1-prepared-transaction-remediation:refs/remotes/origin/work/f-gc18r-r1-prepared-transaction-remediation" \
  "+refs/heads/qualification/f-vq60-gc18r-transactional-groundwater-exchange-current-canonical-qualification:refs/remotes/origin/qualification/f-vq60-gc18r-transactional-groundwater-exchange-current-canonical-qualification" \
  "+refs/heads/work/f-gc18-transactional-groundwater-exchange-service-abstraction:refs/remotes/origin/work/f-gc18-transactional-groundwater-exchange-service-abstraction" \
  "+refs/heads/work/f-gc18a-groundwater-owner-evidence-canonicalization-audit:refs/remotes/origin/work/f-gc18a-groundwater-owner-evidence-canonicalization-audit" \
  "+refs/heads/regie/f-rg01-post-rb1-program-rebaseline:refs/remotes/origin/regie/f-rg01-post-rb1-program-rebaseline"

test "$(git rev-parse refs/remotes/origin/integration/f-ci-canonical)" = "$CANONICAL"
test "$(git rev-parse refs/remotes/origin/work/f-gc18r-r1-prepared-transaction-remediation)" = "$DONOR"
test "$(git rev-parse refs/remotes/origin/qualification/f-vq60-gc18r-transactional-groundwater-exchange-current-canonical-qualification)" = "$FVQ60"
test "$(git rev-parse refs/remotes/origin/work/f-gc18-transactional-groundwater-exchange-service-abstraction)" = "$GC18"
test "$(git rev-parse refs/remotes/origin/work/f-gc18a-groundwater-owner-evidence-canonicalization-audit)" = "$GC18A"
test "$(git rev-parse refs/remotes/origin/regie/f-rg01-post-rb1-program-rebaseline)" = "$RG01"

# The remediated owner candidate is already a current-canonical descendant.
test "$(git merge-base "$CANONICAL" "$DONOR")" = "$CANONICAL"
git merge-base --is-ancestor "$BLOCKED_DONOR" "$DONOR"

test "$(git rev-parse "$DONOR:src/runtime/mod_groundwater_coupling_contract.f90")" = "$COUPLING_BLOB"
test "$(git rev-parse "$CANONICAL:src/runtime/mod_groundwater_coupling_contract.f90")" = "$COUPLING_BLOB"
test "$(git rev-parse "$DONOR:src/runtime/mod_groundwater_exchange_service_contract.f90")" = "$SERVICE_BLOB"
test "$(git rev-parse "$DONOR:tests/fgc/test_fgc18r_prepared_commit.f90")" = "$OWNER_TEST_BLOB"
test "$(git rev-parse "$DONOR:tests/fgc/run_fgc18r_prepared_commit.sh")" = "$OWNER_GATE_BLOB"
test "$(git rev-parse "$DONOR:.github/workflows/fgc18r-prepared-commit.yml")" = "$OWNER_WORKFLOW_BLOB"
test "$(git rev-parse "$DONOR:integration/f-gc/F-GC18R_R1_STATUS.json")" = "$OWNER_STATUS_BLOB"
test "$(git rev-parse "$DONOR:integration/f-gc/F-GC18R_R1_ARCHITECTURE_AUDIT.json")" = "$OWNER_AUDIT_BLOB"

# Verifier branch contains verifier-owned material only.
while IFS= read -r path; do
  case "$path" in
    .github/workflows/fvq61-gc18r-r1-independent-requalification.yml|integration/f-vq/F-VQ61_*|tests/fvq/run_fvq61_gc18r_r1_independent_gate.sh|tests/fvq/test_fvq61_gc18r_r1_independent.f90) ;;
    *) echo "FVQ61_VERIFIER_SCOPE_FAIL unexpected path: $path" >&2; exit 20 ;;
  esac
done < <(git diff --name-only "$CANONICAL..HEAD")

# Relative to current canonical the complete GC18/GC18R capability still adds
# exactly one production source file. The verifier branch imports no donor code.
mapfile -t donor_src < <(git diff --name-only "$CANONICAL..$DONOR" -- 'src/**')
test "${#donor_src[@]}" -eq 1
test "${donor_src[0]}" = "src/runtime/mod_groundwater_exchange_service_contract.f90"
mapfile -t verifier_src < <(git diff --name-only "$CANONICAL..HEAD" -- 'src/**')
test "${#verifier_src[@]}" -eq 0

python3 - <<'PY'
import json, subprocess
CANONICAL='9770a659d5a93d9abe1341815b57c0fb2fea15ec'
DONOR='cfa4e9dcd9a283d85ade316651d34cac93958a4a'
FVQ60='773b1dec23957f2d86648b82ab76f8daede2cbbc'
source=subprocess.check_output(['git','show',f'{DONOR}:src/runtime/mod_groundwater_exchange_service_contract.f90'], text=True)
low=source.lower()
for forbidden in ['modflow', '.swp', 'midnight', '86400']:
    assert forbidden not in low, forbidden
for required in [
    'safe_revision_successor',
    'GW_EXCHANGE_REVISION_EXHAUSTED',
    'GW_EXCHANGE_STALE_PREPARED',
    'free_reservation_slot',
    'next_free',
    'reservation_generation',
    'subroutine consume_prepared_slot',
    'subroutine release_prepared_slot'
]:
    assert required in source, required
for unsafe in [
    'checkpoint%origin_revision_value + 1_int64',
    'self%origin_revision_value + 1_int64'
]:
    assert unsafe not in source, unsafe
assert 'do i = 1, size(service%reservation_slots)' not in source
commit_start=source.index('subroutine groundwater_commit_prepared')
commit_consume=source.index('call consume_prepared_slot', commit_start)
commit_backend=source.index('call service%commit_prepared_backend', commit_start)
assert commit_consume < commit_backend
abort_start=source.index('subroutine groundwater_abort_prepared')
abort_consume=source.index('call consume_prepared_slot', abort_start)
abort_backend=source.index('call service%abort_prepared_backend', abort_start)
assert abort_consume < abort_backend
contract=subprocess.check_output(['git','show',f'{CANONICAL}:src/runtime/mod_groundwater_coupling_contract.f90'], text=True)
assert 'self%t1 <= self%t0' in contract
assert 'q_groundwater_m_per_s = -q_swap_m_per_s' in contract
assert 'flux_residual_m_per_s = state%q_swap_m_per_s + state%q_groundwater_m_per_s' in contract
owner=json.loads(subprocess.check_output(['git','show',f'{DONOR}:integration/f-gc/F-GC18R_R1_STATUS.json'], text=True))
assert owner['decision']=='OWNER_QUALIFIED_FVQ60_B1_B2_REMEDIATION_NOT_CANONICALLY_ADMITTED'
assert owner['authority_state']['owner_remediation_qualified'] is True
assert owner['authority_state']['independent_requalification_complete'] is False
assert owner['authority_state']['canonical_admission_complete'] is False
old=json.loads(subprocess.check_output(['git','show',f'{FVQ60}:integration/f-vq/F-VQ60_STATUS.json'], text=True))
assert old['decision']=='BLOCKED_REMEDIATION_REQUIRED_BEFORE_CANONICAL_ADMISSION'
assert old['independently_qualified_for_canonical_admission'] is False
print('FVQ61_FROZEN_FVQ60_BLOCKED_AUTHORITY_PRESERVED=PASS')
print('FVQ61_OWNER_NONCLAIMS_PRESERVED=PASS')
print('FVQ61_TYPED_GROUNDWATER_CONTRACT_COMPATIBILITY=PASS')
print('FVQ61_PRODUCTION_CONTRACT_STATIC_REMEDIATION=PASS')
PY

work="$(mktemp -d)"
trap 'git worktree remove -f "$work/donor" >/dev/null 2>&1 || true; rm -rf "$work"' EXIT

git worktree add --detach "$work/donor" "$DONOR" >/dev/null
(
  cd "$work/donor"
  bash tests/fgc/run_fgc18r_prepared_commit.sh > "$work/owner-replay.txt"
)
for marker in \
  FGC18_TRANSACTIONAL_GW_SERVICE \
  FGC18_COMMIT_ONCE_AND_STALE_REJECT \
  FGC18R_COPIED_ABORT_REPLAY_REJECTED \
  FGC18R_COPIED_COMMIT_REPLAY_REJECTED \
  FGC18R_BACKEND_TOKEN_REUSE_GENERATION_GUARDED \
  FGC18R_REVISION_INT64_BOUNDARY_FAIL_CLOSED \
  FGC18R_R1_RESERVATION_FREE_LIST \
  FGC18R_R1_O0_O2_IDENTITY; do
  grep -q "^${marker}=PASS" "$work/owner-replay.txt"
done
echo 'FVQ61_PINNED_OWNER_QUALIFICATION_REPLAY=PASS'

compile_probe() {
  local opt="$1"
  local out="$2"
  local dir="$work/probe-$opt"
  mkdir -p "$dir"
  gfortran "-$opt" -std=f2008 -Wall -Wextra -fcheck=all -ffpe-trap=invalid,zero,overflow \
    -J"$dir" -I"$dir" \
    "$work/donor/src/runtime/mod_groundwater_coupling_contract.f90" \
    "$work/donor/src/runtime/mod_groundwater_exchange_service_contract.f90" \
    "$ROOT/tests/fvq/test_fvq61_gc18r_r1_independent.f90" \
    -o "$dir/test_fvq61"
  "$dir/test_fvq61" > "$out"
}

compile_probe O0 "$work/probe-o0.txt"
compile_probe O2 "$work/probe-o2.txt"
diff -u "$work/probe-o0.txt" "$work/probe-o2.txt"
for marker in \
  FVQ61_PREPARE_REFUSAL_PRESERVES_COMMITTED_STATE \
  FVQ61_INVALID_PARTICIPANT_REJECTED_BEFORE_PREPARE \
  FVQ61_COPIED_COMMIT_REPLAY_REJECTED_BEFORE_BACKEND \
  FVQ61_NO_DUPLICATE_PUBLICATION \
  FVQ61_COPIED_ABORT_REPLAY_REJECTED_BEFORE_BACKEND \
  FVQ61_ABORT_PRESERVES_COMMITTED_STATE \
  FVQ61_BACKEND_TOKEN_REUSE_GENERATION_GUARDED \
  FVQ61_LAST_LEGAL_REVISION_ADVANCE \
  FVQ61_REVISION_EXHAUSTION_FAILS_BEFORE_BACKEND; do
  grep -q "^${marker}=PASS$" "$work/probe-o0.txt"
done
grep -q '^FVQ61_INDEPENDENT_NEGATIVE_PATH_AUDIT=PASS_BLOCKERS_CLOSED$' "$work/probe-o0.txt"
cat "$work/probe-o0.txt"
echo 'FVQ61_O0_O2_ADVERSARIAL_IDENTITY=PASS'

if [[ -f integration/f-vq/F-VQ61_ARCHITECTURE_AUDIT.json ]]; then
python3 - <<'PY'
import json
a=json.load(open('integration/f-vq/F-VQ61_ARCHITECTURE_AUDIT.json'))
assert a['overall']=='30_OF_30_NO_ADVERSE_DELTA_INDEPENDENTLY_VERIFIED'
assert a['mass_conservation']=='HARD_PRESERVED_WITH_EXACTLY_ONCE_PUBLICATION_GUARD'
assert [x['id'] for x in a['invariants']]==list(range(1,31))
assert all(x['status']=='PASS' for x in a['invariants'])
s=json.load(open('integration/f-vq/F-VQ61_STATUS.json'))
assert s['decision']=='INDEPENDENTLY_QUALIFIED_FOR_CANONICAL_ADMISSION'
assert s['independently_qualified_for_canonical_admission'] is True
assert s['canonical_admission'] is False
PY
fi

echo "FVQ61_CURRENT_CANONICAL=PASS:$CANONICAL"
echo "FVQ61_OWNER_CANDIDATE=PASS:$DONOR"
echo "FVQ61_FROZEN_BLOCKED_AUTHORITY=PASS:$FVQ60"
echo 'FVQ61_MASS_AND_TRANSACTION_VERDICT=PASS_WITHIN_QUALIFIED_CONTRACT_SCOPE'
echo 'FVQ61_DECISION=INDEPENDENTLY_QUALIFIED_FOR_CANONICAL_ADMISSION'
