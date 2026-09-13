#!/usr/bin/env bash
set -euo pipefail

CANON=df51575e18777856a47a5d0d1e2e1c7456be4601
CANON_TREE=9102c9ac3c9bfceea8b7a9e94b2d1ef48c81b363
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
git merge-base --is-ancestor "$CANON" HEAD || fail "audit branch is not based on exact canonical"
git diff --quiet "$CANON"..HEAD -- src reference || fail "F-MR42 mutated production/reference source"
test "$(git rev-parse HEAD:src)" = "$(git rev-parse "$CANON:src")" || fail "src tree changed"
test "$(git rev-parse HEAD:reference)" = "$(git rev-parse "$CANON:reference")" || fail "reference tree changed"
echo 'FMR42_NO_PRODUCTION_OR_REFERENCE_CHANGE=PASS'

check_blob() {
  local path="$1" expected="$2"
  local got
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
model = json.load(open(sys.argv[1], encoding='utf-8'))
auth = json.load(open(sys.argv[2], encoding='utf-8'))

domain = next(x for x in model['technical_domains'] if x['id'] == 'D10')
assert domain['name'] == 'Serialized MultiSWAP'
assert domain['weight'] == 4
assert domain['earned_weight'] == 4.0
assert domain['completion_percent'] == 100.0
cap = next(x for x in domain['capabilities'] if x['id'] == 'M10')
assert cap['completion_fraction'] == 1.0
assert cap['current_maturity'] == 'PRESERVED_REGRESSION_PROTECTED'
assert cap['required_final_state'] == 'PRESERVED_REGRESSION_PROTECTED'
assert cap['remaining_gap'] == 'none'
assert cap['evidence'] == ['F-MR41', 'F-CI35', 'F-CI48/F-CI48P']

assert auth['decision'] == 'QUALIFIED_SERIALIZED_MULTISWAP_V1_100_PERCENT_COMPLETE'
assert auth['completion_percent'] == 100.0
assert auth['production_source_changed'] is False
assert auth['scope_reduced_to_reach_100_percent'] is False
assert auth['governance']['F_RG01C_definition_authority'] == '971e732551abad86acccfd5f01811d855e51e939'
assert auth['current_canonical_binding']['sha'] == 'df51575e18777856a47a5d0d1e2e1c7456be4601'
assert auth['current_canonical_binding']['tree'] == '9102c9ac3c9bfceea8b7a9e94b2d1ef48c81b363'
assert all(x['result'] == 'PASS' for x in auth['completeness_criteria'])
assert all(not values for values in auth['gap_audit'].values())
required = {'1','3','4','5','6','7','8','9','13','16','23','24','25','26','27','29','30'}
assert required.issubset(auth['architecture_invariants'])
assert all(auth['architecture_invariants'][k].startswith('PASS') for k in required)
assert auth['F_RG01_ingestion_result']['completion_fraction'] == 1.0
assert auth['F_RG01_ingestion_result']['maturity'] == 'PRESERVED_REGRESSION_PROTECTED'
assert auth['F_RG01_ingestion_result']['remaining_gap'] == 'none'
print('FMR42_FIXED_DENOMINATOR_D10_M10=PASS')
print('FMR42_MACHINE_READABLE_COMPLETION_AUTHORITY=PASS')
PY

python3 - <<'PY'
import json, subprocess
CANON = 'df51575e18777856a47a5d0d1e2e1c7456be4601'
def read(path):
    raw = subprocess.check_output(['git','show',f'{CANON}:{path}'], text=True)
    return json.loads(raw)

f35 = read('integration/f-ci/F-CI35_STATUS.json')
assert f35['phase'] == 'CLOSED_CANONICAL_ADMITTED'
assert f35['state']['canonical_admitted'] is True
assert f35['state']['independently_qualified'] is True
assert f35['state']['post_promotion_replay_passed'] is True
assert f35['production_delta'] == []
assert f35['reference_delta'] == []

f48p = read('integration/f-ci/F-CI48P_STATUS.json')
assert f48p['phase'] == 'FINAL_CLOSEOUT_COMPLETE'
assert f48p['state']['current_restricted_canonical_preservation_green'] is True
assert f48p['state']['canonical_reconciliation_promoted'] is True
assert f48p['state']['final_closeout_complete'] is True
assert f48p['state']['mass_conservation_relaxed'] is False

f49p = read('integration/f-ci/F-CI49P_STATUS.json')
assert f49p['phase'] == 'FINAL_CLOSEOUT_COMPLETE'
assert f49p['state']['current_restricted_canonical_preservation_green'] is True
assert f49p['state']['final_closeout_complete'] is True
assert f49p['state']['mass_conservation_relaxed'] is False

f52p = read('integration/f-ci/F-CI52P_STATUS.json')
assert f52p['phase'] == 'FINAL_CLOSEOUT_COMPLETE'
assert f52p['state']['fmr41_optional_state_layout_ownership_preserved'] is True
assert f52p['state']['current_restricted_canonical_preservation_green'] is True
assert f52p['state']['source_admission_finalized'] is True
assert f52p['state']['mass_conservation_relaxed'] is False

f55r = read('integration/f-ci/F-CI55R_STATUS.json')
assert f55r['phase'] == 'FINAL_CLOSEOUT_COMPLETE'
assert f55r['decision'] == 'QUALIFIED_F_CI55R_SOURCE_ADMISSION_FINALIZED'
assert f55r['qualified_production_composition'] == '8a1aeedbaeb5bd015e7e8d098d605968bbecd94e'
assert f55r['qualified_production_blobs']['src/runtime/mod_fmr_serialized_reference_backend.f90'] == 'd565b893a08d92c46077995fdec544584aa04664'
assert f55r['mass_conservation'] == 'HARD_PRESERVED_NO_TOLERANCE_RELAXATION'
assert f55r['canonical_admission'] is True
print('FMR42_CANONICAL_AUTHORITY_CHAIN=PASS')
PY

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
done
echo 'FMR42_D10_DEPENDENCY_SURFACE_CURRENT_PRESERVED=PASS'

FCI="$(git show "$CANON:.github/workflows/fci-canonical.yml")"
grep -Fq "AUTH=$PRESERVE" <<<"$FCI" || fail "canonical preservation authority mismatch"
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
excluded=' '.join(x['frozen_scope']['excluded_without_scope_reduction'])
for term in ['PARALLEL_MULTISWAP_V1','RossFast','groundwater','100k-column']:
    assert term.lower() in excluded.lower(), term
assert x['governance']['denominator_changed_by_F_MR42'] is False
print('FMR42_NO_PERCENTAGE_GAMING=PASS')
PY

echo 'FMR42_GATE QUALIFIED_SERIALIZED_MULTISWAP_V1_100_PERCENT_COMPLETE'
