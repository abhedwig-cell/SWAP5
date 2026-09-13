#!/usr/bin/env bash
set -euo pipefail

CANON=c19a04721a05c6a00ba264e7477969807dcb258f
CANON_TREE=5342833575484452b34606f8854ff3f5a542e452
FCI56_SOURCE_MERGE=699021ab95df35d44e9711612d9ce97939f0025e
PRE_FCI56=df51575e18777856a47a5d0d1e2e1c7456be4601
FCI56_CANDIDATE=bbaa4f2b826b6da7bdca0dfb670b49813616a950
RG01C_DEF=971e732551abad86acccfd5f01811d855e51e939
PRESERVE=8a1aeedbaeb5bd015e7e8d098d605968bbecd94e
AUTH=integration/f-mr/F-MR42_SERIALIZED_MULTISWAP_V1_COMPLETION_AUTHORITY.json

fail() {
  echo "FMR42_FAIL $*" >&2
  exit 1
}

remote_canon="$(git ls-remote origin refs/heads/integration/f-ci-canonical | awk '{print $1}')"
[[ "$remote_canon" == "$CANON" ]] || fail "current canonical moved: expected $CANON got $remote_canon"
echo 'FMR42_CURRENT_CANONICAL_EXACT=PASS'

git fetch --quiet origin integration/f-ci-canonical regie/f-rg01c-fixed-denominator-completion-model

test "$(git rev-parse "$CANON^{tree}")" = "$CANON_TREE" || fail "canonical tree mismatch"
git merge-base --is-ancestor "$CANON" HEAD || fail "audit branch is not based on exact current canonical"
git diff --quiet "$CANON"..HEAD -- src reference || fail "F-MR42 mutated production/reference source"
test "$(git rev-parse HEAD:src)" = "$(git rev-parse "$CANON:src")" || fail "src tree changed by F-MR42"
test "$(git rev-parse HEAD:reference)" = "$(git rev-parse "$CANON:reference")" || fail "reference tree changed by F-MR42"
echo 'FMR42_NO_PRODUCTION_OR_REFERENCE_CHANGE=PASS'

# F-CI56 final closeout is metadata-only on top of its true two-parent source admission.
parent="$(git rev-parse "$CANON^")"
[[ "$parent" == "$FCI56_SOURCE_MERGE" ]] || fail "unexpected F-CI56 final-closeout parent"
git diff --quiet "$FCI56_SOURCE_MERGE" "$CANON" -- src reference || fail "F-CI56 final closeout changed source/reference"
parents=( $(git rev-list --parents -n 1 "$FCI56_SOURCE_MERGE") )
[[ ${#parents[@]} -eq 3 ]] || fail "F-CI56 source admission is not a two-parent merge"
[[ "${parents[1]}" == "$PRE_FCI56" ]] || fail "unexpected F-CI56 source-admission first parent"
[[ "${parents[2]}" == "$FCI56_CANDIDATE" ]] || fail "unexpected F-CI56 source-admission second parent"
echo 'FMR42_FCI56_ADMISSION_AND_CLOSEOUT_LINEAGE=PASS'

check_blob() {
  local path="$1" expected="$2" got
  got="$(git rev-parse "$CANON:$path")"
  [[ "$got" == "$expected" ]] || fail "blob mismatch $path expected $expected got $got"
}
check_blob src/runtime/mod_fmr_runtime_core.f90 43eef1979e0202f8ecc92f73eb7d8025dab515a4
check_blob src/runtime/mod_fmr_serialized_reference_backend.f90 d565b893a08d92c46077995fdec544584aa04664
check_blob src/runtime/mod_fmr_restart_state_contract.f90 872c28bbc345f40073396cce57e4eb43c71de850
check_blob src/kernel/mod_kernel_committed_persistence.f90 ffd886c3401fc12739a456fe60a8741c12b9848b
echo 'FMR42_CURRENT_RUNTIME_BLOB_BINDING=PASS'

MODEL="$(mktemp)"
trap 'rm -f "$MODEL"' EXIT
git show "$RG01C_DEF:integration/f-rg/SWAP5_V1_COMPLETION_MODEL_V1.json" > "$MODEL"
python3 - "$MODEL" "$AUTH" <<'PY'
import json, sys
model=json.load(open(sys.argv[1], encoding='utf-8'))
auth=json.load(open(sys.argv[2], encoding='utf-8'))

domain=next(x for x in model['technical_domains'] if x['id']=='D10')
assert domain['name']=='Serialized MultiSWAP'
assert domain['weight']==4
assert domain['earned_weight']==4.0
assert domain['completion_percent']==100.0
cap=next(x for x in domain['capabilities'] if x['id']=='M10')
assert cap['name']=='Serialized column runtime, typed optional state and restart'
assert cap['completion_fraction']==1.0
assert cap['current_maturity']=='PRESERVED_REGRESSION_PROTECTED'
assert cap['required_final_state']=='PRESERVED_REGRESSION_PROTECTED'
assert cap['evidence']==['F-MR41','F-CI35','F-CI48/F-CI48P']
assert cap['remaining_gap']=='none'

assert auth['decision']=='QUALIFIED_SERIALIZED_MULTISWAP_V1_100_PERCENT_COMPLETE'
assert auth['completion_percent']==100.0
assert auth['production_source_changed_by_F_MR42'] is False
assert auth['reference_source_changed_by_F_MR42'] is False
assert auth['scope_reduced_to_reach_100_percent'] is False
assert auth['governance']['denominator_changed_by_F_MR42'] is False
assert auth['current_canonical']['sha']=='c19a04721a05c6a00ba264e7477969807dcb258f'
assert auth['current_canonical']['tree']=='5342833575484452b34606f8854ff3f5a542e452'
assert auth['current_canonical']['broad_push_qualification_run']==34745966892
assert auth['current_canonical']['current_restricted_canonical_preservation_job']==103694059000
assert all(x['result']=='PASS' for x in auth['criteria'])
assert all(not values for values in auth['gap_audit'].values())
required={'1','3','4','5','6','7','8','9','13','16','23','24','25','26','27','29','30'}
assert required.issubset(auth['architecture_invariants'])
assert all(auth['architecture_invariants'][k].startswith('PASS') for k in required)
assert auth['F_RG01_ingestion_result']['completion_fraction']==1.0
assert auth['F_RG01_ingestion_result']['completion_percent']==100.0
assert auth['F_RG01_ingestion_result']['maturity']=='PRESERVED_REGRESSION_PROTECTED'
assert auth['F_RG01_ingestion_result']['remaining_gap']=='none'
assert auth['F_RG01_ingestion_result']['do_not_change_denominator'] is True
print('FMR42_FIXED_DENOMINATOR_D10_M10=PASS')
print('FMR42_MACHINE_READABLE_COMPLETION_AUTHORITY=PASS')
PY

python3 - <<'PY'
import json, subprocess
CANON='c19a04721a05c6a00ba264e7477969807dcb258f'
def read(path):
    return json.loads(subprocess.check_output(['git','show',f'{CANON}:{path}'], text=True))

f35=read('integration/f-ci/F-CI35_STATUS.json')
assert f35['phase']=='CLOSED_CANONICAL_ADMITTED'
assert f35['state']['canonical_admitted'] is True
assert f35['state']['independently_qualified'] is True
assert f35['state']['post_promotion_replay_passed'] is True
assert f35['production_delta']==[] and f35['reference_delta']==[]

f48p=read('integration/f-ci/F-CI48P_STATUS.json')
assert f48p['phase']=='FINAL_CLOSEOUT_COMPLETE'
assert f48p['state']['current_restricted_canonical_preservation_green'] is True
assert f48p['state']['canonical_reconciliation_promoted'] is True
assert f48p['state']['final_closeout_complete'] is True
assert f48p['state']['mass_conservation_relaxed'] is False

f49p=read('integration/f-ci/F-CI49P_STATUS.json')
assert f49p['phase']=='FINAL_CLOSEOUT_COMPLETE'
assert f49p['state']['current_restricted_canonical_preservation_green'] is True
assert f49p['state']['final_closeout_complete'] is True
assert f49p['state']['mass_conservation_relaxed'] is False

f52p=read('integration/f-ci/F-CI52P_STATUS.json')
assert f52p['phase']=='FINAL_CLOSEOUT_COMPLETE'
assert f52p['state']['fmr41_optional_state_layout_ownership_preserved'] is True
assert f52p['state']['current_restricted_canonical_preservation_green'] is True
assert f52p['state']['source_admission_finalized'] is True
assert f52p['state']['mass_conservation_relaxed'] is False

f55r=read('integration/f-ci/F-CI55R_STATUS.json')
assert f55r['phase']=='FINAL_CLOSEOUT_COMPLETE'
assert f55r['decision']=='QUALIFIED_F_CI55R_SOURCE_ADMISSION_FINALIZED'
assert f55r['qualified_production_composition']=='8a1aeedbaeb5bd015e7e8d098d605968bbecd94e'
assert f55r['qualified_production_blobs']['src/runtime/mod_fmr_serialized_reference_backend.f90']=='d565b893a08d92c46077995fdec544584aa04664'
assert f55r['mass_conservation']=='HARD_PRESERVED_NO_TOLERANCE_RELAXATION'
assert f55r['canonical_admission'] is True

f56=read('integration/f-ci/F-CI56_STATUS.json')
assert f56['phase']=='FINAL_CLOSEOUT_COMPLETE'
assert f56['decision']=='QUALIFIED_F_CI56_SOURCE_ADMISSION_FINALIZED'
assert f56['canonical_admission'] is True
assert f56['independent_qualification'] is True
assert f56['architecture_audit']=='30_OF_30_NO_ADVERSE_DELTA_FOR_CANONICAL_ADMISSION'
assert f56['mass_conservation']=='HARD_EXACT_NO_INTERFACE_TOLERANCE'
assert f56['promotion']['canonical_source_merge']=='699021ab95df35d44e9711612d9ce97939f0025e'
assert f56['postpromotion_source_postimage_evidence']['broad_canonical_push_qualification']['run']==34745820847
print('FMR42_CANONICAL_AUTHORITY_CHAIN=PASS')
PY

# Byte-bind the frozen serialized dependency surface to the latest qualified
# production composition that owns it. F-CI56 may add groundwater components,
# but those are outside the fixed D10 denominator and may not alter these blobs.
d10_surface=(
  src/runtime/mod_a23bu_worker_execution_context.f90
  src/transaction/mod_transaction_reference.f90
  src/runtime/mod_canonical_contracts.f90
  src/runtime/mod_canonical_interval_runtime.f90
  src/kernel/mod_kernel_transactions.f90
  src/kernel/mod_kernel_committed_persistence.f90
  src/runtime/mod_fmr_runtime_core.f90
  src/runtime/mod_fmr_checkpoint_orchestrator.f90
  src/runtime/mod_fmr_serialized_reference_backend.f90
  src/runtime/mod_fmr_serialized_multiswap_runtime.f90
  src/runtime/mod_fmr_committed_restart.f90
  src/runtime/mod_fmr_restart_state_contract.f90
  src/runtime/mod_fmr_reference_et_root_uptake_composition.f90
  src/runtime/mod_fmr_divdra_runtime_binding.f90
  src/runtime/mod_fmr_divdra_serialized_composition.f90
  src/runtime/mod_fmr_divdra_serialized_runtime.f90
  src/process/mod_restricted_surface_evaporation.f90
  src/runtime/mod_fmr_surface_evaporation_runtime_materialization.f90
  src/runtime/mod_fmr_process_hydraulic_view_binding.f90
  src/process/mod_soil_temperature_contract.f90
  src/process/mod_restricted_soil_temperature.f90
)
for path in "${d10_surface[@]}"; do
  test "$(git rev-parse "$CANON:$path")" = "$(git rev-parse "$PRESERVE:$path")" || fail "current D10 dependency drift: $path"
  git diff --quiet "$PRE_FCI56" "$FCI56_SOURCE_MERGE" -- "$path" || fail "F-CI56 source admission modified D10 dependency: $path"
done
echo 'FMR42_D10_DEPENDENCY_SURFACE_CURRENT_PRESERVED=PASS'

FCI="$(git show "$CANON:.github/workflows/fci-canonical.yml")"
grep -Fq "AUTH=$PRESERVE" <<<"$FCI" || fail "moving-current preservation authority mismatch"
for token in \
  mod_fmr_runtime_core.f90 \
  mod_fmr_serialized_reference_backend.f90 \
  mod_fmr_serialized_multiswap_runtime.f90 \
  mod_fmr_committed_restart.f90 \
  mod_fmr_restart_state_contract.f90 \
  mod_fmr_reference_et_root_uptake_composition.f90 \
  mod_fmr_divdra_serialized_runtime.f90 \
  mod_restricted_surface_evaporation.f90 \
  mod_restricted_soil_temperature.f90; do
  grep -Fq "$token" <<<"$FCI" || fail "canonical preservation surface missing $token"
done
echo 'FMR42_CURRENT_CANONICAL_PRESERVATION_GATE_BOUND=PASS'

python3 - "$AUTH" <<'PY'
import json, sys
x=json.load(open(sys.argv[1], encoding='utf-8'))
excluded=' '.join(x['frozen_scope']['excluded_without_scope_reduction']).lower()
for term in ['parallel_multiswap_v1','rossfast','groundwater','100k-column']:
    assert term in excluded, term
assert len(x['superseded_fail_closed_attempts'])==2
assert all(not a['capability_failure'] for a in x['superseded_fail_closed_attempts'])
print('FMR42_NO_PERCENTAGE_GAMING=PASS')
PY

echo 'FMR42_GATE QUALIFIED_SERIALIZED_MULTISWAP_V1_100_PERCENT_COMPLETE'
