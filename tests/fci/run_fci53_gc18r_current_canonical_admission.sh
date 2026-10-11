#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

BASE=9770a659d5a93d9abe1341815b57c0fb2fea15ec
BASE_TREE=110384fcfa939040eb517f5dfe4f139251b95aef
COMPOSITION=e0e8462c0d09034dcbdadb99ec16670667d37715
COMPOSITION_TREE=e4e78fab23e5fd3d8b5735ff92053f906cee11a0
OWNER=cfa4e9dcd9a283d85ade316651d34cac93958a4a
FVQ61=e83fe9a4955275935903730c4484c77fb0b117ff
FVQ60=773b1dec23957f2d86648b82ab76f8daede2cbbc
GC18A=ac25e009b795f231a522d2f048795ccc1d64417c
GOV=09ef05c60c5e45af218980001c8ad8ec30da2e9e
SERVICE_BLOB=f0fc25592624360802713a9487813d119e7dc4e9
COUPLING_BLOB=fc598d14eabafcb025bb55621f7b00d6d1816f10
OWNER_STATUS_BLOB=a36e6c01dd06e40657ea4b0c4e5e6ac67efd5e9d
FVQ61_STATUS_BLOB=dca81320a9208a8bd140fff96de11f4f6e25b691
BUILD="${RUNNER_TEMP:-/tmp}/fci53-${GITHUB_RUN_ID:-local}"
rm -rf "$BUILD"; mkdir -p "$BUILD"
trap 'git worktree remove -f "$BUILD/owner" >/dev/null 2>&1 || true; git worktree remove -f "$BUILD/vq" >/dev/null 2>&1 || true; rm -rf "$BUILD"' EXIT
fail(){ echo "FCI53_GATE_FAIL $*" >&2; exit 53; }
need(){ git cat-file -e "$1^{commit}" 2>/dev/null || git fetch --no-tags origin "$1" >/dev/null 2>&1 || fail "cannot fetch $1"; }
for c in "$BASE" "$COMPOSITION" "$OWNER" "$FVQ61" "$FVQ60" "$GC18A" "$GOV"; do need "$c"; done

# Live race guards. No successful earlier run may be promoted after an authority moves.
git fetch --no-tags origin \
  "+refs/heads/integration/f-ci-canonical:refs/remotes/origin/integration/f-ci-canonical" \
  "+refs/heads/work/f-gc18r-r1-prepared-transaction-remediation:refs/remotes/origin/work/f-gc18r-r1-prepared-transaction-remediation" \
  "+refs/heads/qualification/f-vq61-gc18r-r1-transactional-groundwater-exchange-independent-requalification:refs/remotes/origin/qualification/f-vq61-gc18r-r1-transactional-groundwater-exchange-independent-requalification" \
  "+refs/heads/qualification/f-vq60-gc18r-transactional-groundwater-exchange-current-canonical-qualification:refs/remotes/origin/qualification/f-vq60-gc18r-transactional-groundwater-exchange-current-canonical-qualification" \
  "+refs/heads/work/f-gc18a-groundwater-owner-evidence-canonicalization-audit:refs/remotes/origin/work/f-gc18a-groundwater-owner-evidence-canonicalization-audit" \
  "+refs/heads/regie/f-rg01-post-rb1-program-rebaseline:refs/remotes/origin/regie/f-rg01-post-rb1-program-rebaseline" >/dev/null
[[ "$(git rev-parse refs/remotes/origin/integration/f-ci-canonical)" == "$BASE" ]] || fail 'current canonical moved'
[[ "$(git rev-parse refs/remotes/origin/work/f-gc18r-r1-prepared-transaction-remediation)" == "$OWNER" ]] || fail 'owner authority moved'
[[ "$(git rev-parse refs/remotes/origin/qualification/f-vq61-gc18r-r1-transactional-groundwater-exchange-independent-requalification)" == "$FVQ61" ]] || fail 'F-VQ61 authority moved'
[[ "$(git rev-parse refs/remotes/origin/qualification/f-vq60-gc18r-transactional-groundwater-exchange-current-canonical-qualification)" == "$FVQ60" ]] || fail 'F-VQ60 historical authority moved'
[[ "$(git rev-parse refs/remotes/origin/work/f-gc18a-groundwater-owner-evidence-canonicalization-audit)" == "$GC18A" ]] || fail 'F-GC18A evidence authority moved'
[[ "$(git rev-parse refs/remotes/origin/regie/f-rg01-post-rb1-program-rebaseline)" == "$GOV" ]] || fail 'governance authority moved'
[[ "$(git rev-parse ${BASE}^{tree})" == "$BASE_TREE" ]] || fail 'canonical base tree drift'
echo 'FCI53_LIVE_AUTHORITY_RACE_GUARDS=PASS'

# Exact one-file production composition directly on current canonical.
[[ "$(git rev-parse ${COMPOSITION}^)" == "$BASE" ]] || fail 'composition is not a direct child of canonical'
[[ "$(git rev-parse ${COMPOSITION}^{tree})" == "$COMPOSITION_TREE" ]] || fail 'composition tree drift'
printf '%s\n' src/runtime/mod_groundwater_exchange_service_contract.f90 > "$BUILD/expected-src"
git diff --name-only "$BASE".."$COMPOSITION" -- src | sort > "$BUILD/actual-src"
cmp "$BUILD/expected-src" "$BUILD/actual-src" || fail 'unexpected composition production delta'
[[ "$(git rev-parse ${COMPOSITION}:src/runtime/mod_groundwater_exchange_service_contract.f90)" == "$SERVICE_BLOB" ]] || fail 'composition service blob drift'
[[ "$(git rev-parse HEAD:src/runtime/mod_groundwater_exchange_service_contract.f90)" == "$SERVICE_BLOB" ]] || fail 'qualification service blob drift'
[[ "$(git rev-parse ${OWNER}:src/runtime/mod_groundwater_exchange_service_contract.f90)" == "$SERVICE_BLOB" ]] || fail 'owner service blob drift'
git diff --quiet "$COMPOSITION"..HEAD -- src || fail 'production source changed after composition'
[[ "$(git rev-parse HEAD:src/runtime/mod_groundwater_coupling_contract.f90)" == "$COUPLING_BLOB" ]] || fail 'typed groundwater contract drift in candidate'
[[ "$(git rev-parse ${BASE}:src/runtime/mod_groundwater_coupling_contract.f90)" == "$COUPLING_BLOB" ]] || fail 'typed groundwater contract drift in canonical base'
[[ "$(git rev-parse ${OWNER}:src/runtime/mod_groundwater_coupling_contract.f90)" == "$COUPLING_BLOB" ]] || fail 'typed groundwater contract drift in owner authority'
[[ "$(git rev-parse HEAD:reference)" == "$(git rev-parse ${BASE}:reference)" ]] || fail 'reference tree changed'
echo 'FCI53_EXACT_ONE_BLOB_PRODUCTION_COMPOSITION=PASS'
echo 'FCI53_TYPED_GROUNDWATER_CONTRACT_BYTE_PRESERVED=PASS'

# Qualification branch may add only F-CI53 governance/test material around the composition.
while IFS= read -r p; do
  case "$p" in
    src/runtime/mod_groundwater_exchange_service_contract.f90|.github/workflows/fci53-gc18r-current-canonical-admission.yml|tests/fci/run_fci53_gc18r_current_canonical_admission.sh|integration/f-ci/F-CI53_PRE_REGISTRATION.json|integration/f-ci/F-CI53_ARCHITECTURE_AUDIT.json|integration/f-ci/F-CI53_STATUS.json) ;;
    *) fail "unexpected qualification path $p" ;;
  esac
done < <(git diff --name-only "$BASE"..HEAD)
echo 'FCI53_QUALIFICATION_SCOPE_ALLOWLIST=PASS'

# Immutable owner, verifier and historical-blocked status semantics.
[[ "$(git rev-parse ${OWNER}:integration/f-gc/F-GC18R_R1_STATUS.json)" == "$OWNER_STATUS_BLOB" ]] || fail 'owner status blob drift'
[[ "$(git rev-parse ${FVQ61}:integration/f-vq/F-VQ61_STATUS.json)" == "$FVQ61_STATUS_BLOB" ]] || fail 'F-VQ61 status blob drift'
git show "${OWNER}:integration/f-gc/F-GC18R_R1_STATUS.json" > "$BUILD/owner.json"
git show "${FVQ61}:integration/f-vq/F-VQ61_STATUS.json" > "$BUILD/vq61.json"
git show "${FVQ60}:integration/f-vq/F-VQ60_STATUS.json" > "$BUILD/vq60.json"
python3 - "$BUILD/owner.json" "$BUILD/vq61.json" "$BUILD/vq60.json" <<'PY'
import json,sys
owner,vq,old=[json.load(open(p)) for p in sys.argv[1:]]
assert owner['decision']=='OWNER_QUALIFIED_FVQ60_B1_B2_REMEDIATION_NOT_CANONICALLY_ADMITTED'
assert owner['authority_state']['owner_remediation_qualified'] is True
assert owner['authority_state']['canonical_admission_complete'] is False
assert vq['decision']=='INDEPENDENTLY_QUALIFIED_FOR_CANONICAL_ADMISSION'
assert vq['independently_qualified_for_canonical_admission'] is True
assert vq['canonical_admission'] is False
assert vq['owner_candidate']=='cfa4e9dcd9a283d85ade316651d34cac93958a4a'
assert vq['current_canonical']=='9770a659d5a93d9abe1341815b57c0fb2fea15ec'
assert old['decision']=='BLOCKED_REMEDIATION_REQUIRED_BEFORE_CANONICAL_ADMISSION'
assert old['independently_qualified_for_canonical_admission'] is False
print('FCI53_OWNER_AND_INDEPENDENT_AUTHORITIES=PASS')
print('FCI53_FVQ60_FROZEN_BLOCKED_HISTORY=PASS')
PY

# Static transaction, mass-interface, generic-time and hidden-dependency checks.
python3 - <<'PY'
from pathlib import Path
s=Path('src/runtime/mod_groundwater_exchange_service_contract.f90').read_text()
low=s.lower()
for forbidden in ('modflow','.swp','midnight','86400'):
    assert forbidden not in low, forbidden
for required in ('safe_revision_successor','GW_EXCHANGE_REVISION_EXHAUSTED','GW_EXCHANGE_STALE_PREPARED',
                 'free_reservation_slot','reservation_generation','subroutine consume_prepared_slot',
                 'subroutine release_prepared_slot'):
    assert required in s, required
assert 'checkpoint%origin_revision_value + 1_int64' not in s
assert 'self%origin_revision_value + 1_int64' not in s
c=s.index('subroutine groundwater_commit_prepared')
assert s.index('call consume_prepared_slot',c) < s.index('call service%commit_prepared_backend',c)
a=s.index('subroutine groundwater_abort_prepared')
assert s.index('call consume_prepared_slot',a) < s.index('call service%abort_prepared_backend',a)
t=Path('src/runtime/mod_groundwater_coupling_contract.f90').read_text()
assert 'self%t1 <= self%t0' in t
assert 'q_groundwater_m_per_s = -q_swap_m_per_s' in t
assert 'flux_residual_m_per_s = state%q_swap_m_per_s + state%q_groundwater_m_per_s' in t
print('FCI53_TRANSACTION_STATIC_CONTRACT=PASS')
print('FCI53_TYPED_MASS_INTERFACE_CONTRACT=PASS')
print('FCI53_GENERIC_TIME_AND_NO_HIDDEN_IO_MODFLOW_DEPENDENCY=PASS')
PY

# Re-run owner and independent qualification from their immutable authorities.
git worktree add --detach "$BUILD/owner" "$OWNER" >/dev/null
(cd "$BUILD/owner" && bash tests/fgc/run_fgc18r_prepared_commit.sh) > "$BUILD/owner-replay.log"
grep -Fq 'FGC18R_COPIED_COMMIT_REPLAY_REJECTED=PASS' "$BUILD/owner-replay.log" || fail 'owner copied-commit replay missing'
grep -Fq 'FGC18R_BACKEND_TOKEN_REUSE_GENERATION_GUARDED=PASS' "$BUILD/owner-replay.log" || fail 'owner generation guard missing'
grep -Fq 'FGC18R_REVISION_INT64_BOUNDARY_FAIL_CLOSED=PASS' "$BUILD/owner-replay.log" || fail 'owner revision boundary missing'
grep -Fq 'FGC18R_R1_O0_O2_IDENTITY=PASS' "$BUILD/owner-replay.log" || fail 'owner O0/O2 identity missing'
echo 'FCI53_PINNED_OWNER_REPLAY=PASS'

git worktree add --detach "$BUILD/vq" "$FVQ61" >/dev/null
(cd "$BUILD/vq" && bash tests/fvq/run_fvq61_gc18r_r1_independent_gate.sh) > "$BUILD/vq-replay.log"
grep -Fq 'FVQ61_DECISION=INDEPENDENTLY_QUALIFIED_FOR_CANONICAL_ADMISSION' "$BUILD/vq-replay.log" || fail 'independent decision replay missing'
grep -Fq 'FVQ61_BACKEND_TOKEN_REUSE_GENERATION_GUARDED=PASS' "$BUILD/vq-replay.log" || fail 'independent generation guard missing'
grep -Fq 'FVQ61_REVISION_EXHAUSTION_FAILS_BEFORE_BACKEND=PASS' "$BUILD/vq-replay.log" || fail 'independent revision exhaustion missing'
grep -Fq 'FVQ61_MASS_AND_TRANSACTION_VERDICT=PASS_WITHIN_QUALIFIED_CONTRACT_SCOPE' "$BUILD/vq-replay.log" || fail 'independent mass/transaction verdict missing'
echo 'FCI53_PINNED_INDEPENDENT_REPLAY=PASS'

# Compile and run the exact admission image with both owner and independent tests.
cp "$BUILD/owner/tests/fgc/test_fgc18r_prepared_commit.f90" "$BUILD/owner-test.f90"
cp "$BUILD/vq/tests/fvq/test_fvq61_gc18r_r1_independent.f90" "$BUILD/vq-test.f90"
run_test(){
  local opt="$1" test="$2" stem="$3"
  local dir="$BUILD/${stem}-${opt}"; mkdir -p "$dir"
  gfortran "-$opt" -std=f2008 -Wall -Wextra -fcheck=all -ffpe-trap=invalid,zero,overflow \
    -J"$dir" -I"$dir" src/runtime/mod_groundwater_coupling_contract.f90 \
    src/runtime/mod_groundwater_exchange_service_contract.f90 "$test" -o "$dir/test"
  "$dir/test" > "$BUILD/${stem}-${opt}.txt"
}
for o in O0 O2; do run_test "$o" "$BUILD/owner-test.f90" owner; run_test "$o" "$BUILD/vq-test.f90" vq; done
diff -u "$BUILD/owner-O0.txt" "$BUILD/owner-O2.txt"
diff -u "$BUILD/vq-O0.txt" "$BUILD/vq-O2.txt"
grep -Fq 'FGC18R_COPIED_COMMIT_REPLAY_REJECTED=PASS' "$BUILD/owner-O0.txt" || fail 'admission owner replay marker missing'
grep -Fq 'FVQ61_INDEPENDENT_NEGATIVE_PATH_AUDIT=PASS_BLOCKERS_CLOSED' "$BUILD/vq-O0.txt" || fail 'admission independent negative-path marker missing'
echo 'FCI53_EXACT_ADMISSION_IMAGE_O0_O2_TESTED=PASS'

# F-CI53 architecture audit and status must remain internally conservative.
python3 - <<'PY'
import json
A=json.load(open('integration/f-ci/F-CI53_ARCHITECTURE_AUDIT.json'))
assert A['work_unit']=='F-CI53'
assert A['canonical_base']=='9770a659d5a93d9abe1341815b57c0fb2fea15ec'
assert A['composition_commit']=='e0e8462c0d09034dcbdadb99ec16670667d37715'
assert A['scope']['new_groundwater_runtime_capability'] is True
assert A['scope']['physical_modflow_adapter'] is False
assert A['scope']['mass_conservation']=='HARD_UNCHANGED_AND_TRANSACTION_PUBLICATION_GUARDED'
assert [x['id'] for x in A['invariants']]==list(range(1,31))
assert all(x['status'] in {'PRESERVED','QUALIFIED'} for x in A['invariants'])
S=json.load(open('integration/f-ci/F-CI53_STATUS.json'))
assert S['work_unit']=='F-CI53'
assert S['canonical_base']=='9770a659d5a93d9abe1341815b57c0fb2fea15ec'
assert S['composition_commit']=='e0e8462c0d09034dcbdadb99ec16670667d37715'
assert S['state']['canonical_admitted'] is False
assert S['state']['production_coupling_admitted'] is False
assert S['decision'] in {'F_CI53_CURRENT_CANONICAL_ADMISSION_CANDIDATE','QUALIFIED_F_CI53_READY_FOR_CANONICAL_PROMOTION'}
print('FCI53_ARCHITECTURE_INVARIANTS_30_OF_30=PASS')
print('FCI53_NONCLAIMS_FAIL_CLOSED=PASS')
PY

git diff --check "$BASE"..HEAD || fail 'diff hygiene failed'
echo 'FCI53_DIFF_CHECK=PASS'
echo 'FCI53_MASS_CONSERVATION=HARD_UNCHANGED'
echo 'FCI53_TRANSACTIONAL_PUBLICATION=EXACTLY_ONCE_GUARDED'
echo 'FCI53_MODFLOW_ADAPTER_ADMISSION=NO'
echo 'FCI53_PRODUCTION_COUPLING_ADMISSION=NO'
echo 'FCI53_LARGE_BATCH_THROUGHPUT_CLAIM=NOT_MADE'
echo 'FCI53_RB1_REOPENED=NO'
echo 'FCI53_CANONICAL_ADMISSION_GATE=PASS'
