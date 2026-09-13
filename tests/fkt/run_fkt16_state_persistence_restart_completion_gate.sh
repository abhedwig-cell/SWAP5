#!/usr/bin/env bash
set -euo pipefail

CANON=c19a04721a05c6a00ba264e7477969807dcb258f
CANON_TREE=5342833575484452b34606f8854ff3f5a542e452
RG01C_DEF=971e732551abad86acccfd5f01811d855e51e939
FMR42_CLOSEOUT=e370f95c2e50c2fef46fe99eac11522046560938
FMQ27_CLOSEOUT=33beccd7b38f5a3c29131025e1b06166026851e3
FMQ29_CLOSEOUT=5ea88d81a63e6c706c87e99ac360f91f08711fc1
FWOF42_CLOSEOUT=ed0219402072f121856d82cb6068ab74c70f34d1
AUTH=integration/f-kt/F-KT16_STATE_PERSISTENCE_RESTART_V1_COMPLETION_AUTHORITY.json

fail() {
  echo "FKT16_FAIL $*" >&2
  exit 1
}

remote_canon="$(git ls-remote origin refs/heads/integration/f-ci-canonical | awk '{print $1}')"
[[ "$remote_canon" == "$CANON" ]] || fail "current canonical moved: expected $CANON got $remote_canon"
test "$(git rev-parse "$CANON^{tree}")" = "$CANON_TREE" || fail "canonical tree mismatch"
git merge-base --is-ancestor "$CANON" HEAD || fail "F-KT16 is not based on exact current canonical"
git diff --quiet "$CANON"..HEAD -- src reference || fail "F-KT16 modified production/reference source"
test "$(git rev-parse HEAD:src)" = "$(git rev-parse "$CANON:src")" || fail "src tree changed"
test "$(git rev-parse HEAD:reference)" = "$(git rev-parse "$CANON:reference")" || fail "reference tree changed"
echo 'FKT16_EXACT_CURRENT_CANONICAL_AND_NO_SOURCE_DELTA=PASS'

check_blob() {
  local path="$1" expected="$2" got
  got="$(git rev-parse "$CANON:$path")"
  [[ "$got" == "$expected" ]] || fail "blob mismatch $path expected $expected got $got"
}
check_blob src/kernel/mod_kernel_transactions.f90 c7c5b7d3357e4e6739c8f647d6232baca45563e6
check_blob src/kernel/mod_kernel_committed_persistence.f90 ffd886c3401fc12739a456fe60a8741c12b9848b
check_blob src/runtime/mod_fmr_runtime_core.f90 43eef1979e0202f8ecc92f73eb7d8025dab515a4
check_blob src/runtime/mod_fmr_serialized_reference_backend.f90 d565b893a08d92c46077995fdec544584aa04664
check_blob src/runtime/mod_fmr_restart_state_contract.f90 872c28bbc345f40073396cce57e4eb43c71de850
check_blob src/runtime/mod_fmr_wofost_accepted_window_lineage.f90 61ffdf21a00c23924184c9117d91d84a88544d1a
check_blob src/runtime/mod_fmr_wofost_crop_transaction.f90 dad15717e5794b7489c9fecf6dbc17e12435c61e
echo 'FKT16_CURRENT_STATE_RESTART_PROCESS_BLOB_BINDING=PASS'

git fetch --quiet origin \
  regie/f-rg01c-fixed-denominator-completion-model \
  work/f-mr42-serialized-multiswap-v1-completeness-audit-r2 \
  qualification/f-mq27-fmr21-restart-schema-requalification \
  qualification/f-mq29-parallel-committed-restart-composition \
  work/f-wof42-crop-persistence-layout-completeness

MODEL="$(mktemp)"
MR42="$(mktemp)"
MQ27="$(mktemp)"
MQ29="$(mktemp)"
WOF42="$(mktemp)"
trap 'rm -f "$MODEL" "$MR42" "$MQ27" "$MQ29" "$WOF42"' EXIT

git show "$RG01C_DEF:integration/f-rg/SWAP5_V1_COMPLETION_MODEL_V1.json" > "$MODEL"
git show "$FMR42_CLOSEOUT:integration/f-mr/F-MR42_SERIALIZED_MULTISWAP_V1_COMPLETION_AUTHORITY.json" > "$MR42"
git show "$FMQ27_CLOSEOUT:integration/f-mq/F-MQ27_STATUS.json" > "$MQ27"
git show "$FMQ29_CLOSEOUT:integration/f-mq/F-MQ29_STATUS.json" > "$MQ29"
git show "$FWOF42_CLOSEOUT:integration/f-wof/F-WOF42_CLOSEOUT.json" > "$WOF42"

python3 - "$MODEL" "$MR42" "$MQ27" "$MQ29" "$WOF42" "$AUTH" <<'PY'
import json, sys
model, mr42, mq27, mq29, wof42, auth = [json.load(open(p, encoding='utf-8')) for p in sys.argv[1:]]

d02=next(x for x in model['domains'] if x['id']=='D02')
assert d02['name']=='State / persistence / restart'
assert d02['weight']==7
assert d02['earned_weight']==7.0
assert d02['completion_percent']==100.0
caps={x['id']:x for x in d02['capabilities']}
assert set(caps)=={'S01','S02'}
assert caps['S01']['completion_fraction']==1.0 and caps['S01']['remaining_gap']=='none'
assert caps['S02']['completion_fraction']==1.0 and caps['S02']['remaining_gap']=='none'
assert all(caps[k]['current_maturity']=='PRESERVED_REGRESSION_PROTECTED' for k in caps)
hg3=next(x for x in model['hard_gates'] if x['id']=='HG03_RESTART')
assert hg3['currently_active'] is False

d07=next(x for x in model['domains'] if x['id']=='D07')
c01=next(x for x in d07['capabilities'] if x['id']=='C01')
assert c01['completion_fraction']==1.0 and c01['current_maturity']=='PRESERVED_REGRESSION_PROTECTED'

assert mr42['decision']=='QUALIFIED_SERIALIZED_MULTISWAP_V1_100_PERCENT_COMPLETE'
assert mr42['completion_percent']==100.0
assert mr42['current_canonical']['sha']=='c19a04721a05c6a00ba264e7477969807dcb258f'
assert mr42['current_canonical']['tree']=='5342833575484452b34606f8854ff3f5a542e452'
assert mr42['production_source_changed_by_F_MR42'] is False
assert mr42['reference_source_changed_by_F_MR42'] is False
assert all(x['result']=='PASS' for x in mr42['criteria'])
assert all(not v for v in mr42['gap_audit'].values())

assert mq27['QUALIFIED'] is True
assert mq27['closed'] is True
assert mq27['observations']['exact_lineage_revision_time_continuation']=='PASS'
assert mq27['observations']['exact_interval_mass_continuation']=='PASS'
assert mq27['observations']['continuous_vs_restarted_endpoint_identity']=='PASS'
assert mq27['observations']['deterministic_replay']=='PASS'
assert mq27['observations']['late_record_whole_registry_atomicity']=='PASS'

assert mq29['decision']=='QUALIFIED_PARALLEL_COMMITTED_BOUNDARY_RESTART_COMPOSITION'
assert mq29['qualified'] is True
assert mq29['closed'] is True
q=mq29['qualification']
for key in ['committed_state_only_restart','whole_registry_atomic_restore_before_parallel_dispatch','worker_scratch_rebuilt_not_persisted','fresh_reconstructed_target_identity','endpoint_result_and_committed_state_identity','lineage_revision_committed_time_identity','aggregate_mass_and_ledger_identity','o0_o2_exact_output_identity']:
    assert q[key] is True, key
assert q['per_column_mass_residual_max_cm'] <= 1e-12

assert wof42['qualified'] is True and wof42['production_persisted'] is True and wof42['tested'] is True
assert wof42['decision']=='QUALIFIED_CROP_PERSISTENCE_LAYOUT_COMPLETENESS_READY_FOR_NEXT_RUNTIME/CANONICAL_COMPOSITION'

assert auth['decision']=='QUALIFIED_STATE_PERSISTENCE_RESTART_V1_100_PERCENT_COMPLETE'
assert auth['completion_percent']==100.0
assert auth['production_source_changed_by_F_KT16'] is False
assert auth['reference_source_changed_by_F_KT16'] is False
assert auth['scope_reduced_to_reach_100_percent'] is False
assert auth['governance']['denominator_changed_by_F_KT16'] is False
assert auth['current_canonical']['sha']=='c19a04721a05c6a00ba264e7477969807dcb258f'
assert auth['current_canonical']['tree']=='5342833575484452b34606f8854ff3f5a542e452'
assert all(x['result']=='PASS' for x in auth['criteria'])
assert len(auth['criteria'])==14
assert all(not v for v in auth['gap_audit'].values())
assert all(v.startswith('PASS') for v in auth['hard_100_percent_gates'].values())
required={'3','4','5','7','8','9','13','16','19','23','25','26','27','29','30'}
assert required.issubset(auth['architecture_invariants'])
assert all(auth['architecture_invariants'][k].startswith('PASS') for k in required)
ing=auth['F_RG01_ingestion_result']
assert ing['domain']=='D02' and ing['weight']==7.0 and ing['earned_weight']==7.0
assert ing['completion_fraction']==1.0 and ing['completion_percent']==100.0
assert ing['maturity']=='PRESERVED_REGRESSION_PROTECTED'
assert ing['remaining_gap']=='none' and ing['hard_gate_HG03_RESTART_active'] is False
assert ing['do_not_change_denominator'] is True
print('FKT16_FIXED_DENOMINATOR_D02=PASS')
print('FKT16_INDEPENDENT_RESTART_CHAIN=PASS')
print('FKT16_PROCESS_STATE_COMPLETENESS_CHAIN=PASS')
print('FKT16_MACHINE_READABLE_COMPLETION_AUTHORITY=PASS')
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

f48p=read('integration/f-ci/F-CI48P_STATUS.json')
assert f48p['phase']=='FINAL_CLOSEOUT_COMPLETE'
assert f48p['state']['current_restricted_canonical_preservation_green'] is True
assert f48p['state']['mass_conservation_relaxed'] is False

f49p=read('integration/f-ci/F-CI49P_STATUS.json')
assert f49p['phase']=='FINAL_CLOSEOUT_COMPLETE'
assert f49p['state']['current_restricted_canonical_preservation_green'] is True
assert f49p['state']['mass_conservation_relaxed'] is False

f52p=read('integration/f-ci/F-CI52P_STATUS.json')
assert f52p['phase']=='FINAL_CLOSEOUT_COMPLETE'
assert f52p['state']['fmr41_optional_state_layout_ownership_preserved'] is True
assert f52p['state']['current_restricted_canonical_preservation_green'] is True
assert f52p['state']['mass_conservation_relaxed'] is False
assert f52p['postpromotion_failure_classification']['restart_regression'] is False

f55r=read('integration/f-ci/F-CI55R_STATUS.json')
assert f55r['phase']=='FINAL_CLOSEOUT_COMPLETE'
assert f55r['canonical_admission'] is True
assert f55r['mass_conservation']=='HARD_PRESERVED_NO_TOLERANCE_RELAXATION'

f56=read('integration/f-ci/F-CI56_STATUS.json')
assert f56['phase']=='FINAL_CLOSEOUT_COMPLETE'
assert f56['canonical_admission'] is True
assert f56['independent_qualification'] is True
assert f56['architecture_audit']=='30_OF_30_NO_ADVERSE_DELTA_FOR_CANONICAL_ADMISSION'
assert f56['mass_conservation']=='HARD_EXACT_NO_INTERFACE_TOLERANCE'
print('FKT16_CURRENT_CANONICAL_ADMISSION_PRESERVATION_CHAIN=PASS')
PY

# Structural source checks for the audited separation boundaries.
PERSIST="$(git show "$CANON:src/kernel/mod_kernel_committed_persistence.f90")"
grep -Fq 'KERNEL_PERSISTENCE_SCHEMA_VERSION = 1' <<<"$PERSIST" || fail 'missing persistence schema version'
grep -Fq 'There is deliberately no file, path, byte-format or solver-scratch state.' <<<"$PERSIST" || fail 'kernel persistence boundary changed'
grep -Fq 'KERNEL_PERSISTENCE_SCHEMA_MISMATCH' <<<"$PERSIST" || fail 'schema mismatch fail-closed status missing'
grep -Fq 'KERNEL_PERSISTENCE_LAYOUT_MISMATCH' <<<"$PERSIST" || fail 'layout mismatch fail-closed status missing'

TX="$(git show "$CANON:src/kernel/mod_kernel_transactions.f90")"
grep -Fq 'type, public :: kernel_checkpoint_t' <<<"$TX" || fail 'checkpoint type missing'
grep -Fq 'type, public :: kernel_candidate_state_t' <<<"$TX" || fail 'candidate type missing'
grep -Fq 'type(kernel_committed_state_t), intent(in) :: committed_state' <<<"$TX" || fail 'trial no longer read-only on committed state'
grep -Fq 'call move_alloc(candidate_state%state, committed_state%physical_state)' <<<"$TX" || fail 'commit publication path changed'
grep -Fq 'call clear_candidate(candidate_state)' <<<"$TX" || fail 'candidate rollback/clear path changed'
grep -Fq 'Model instances are worker/job-local execution' <<<"$TX" || fail 'worker-local model contract marker missing'

RST="$(git show "$CANON:src/runtime/mod_fmr_restart_state_contract.f90")"
grep -Fq 'FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY' <<<"$RST" || fail 'temporal continuation layout missing'
grep -Fq 'Unknown backends are' <<<"$RST" || fail 'fail-closed backend marker missing'

WOF="$(git show "$CANON:src/runtime/mod_fmr_wofost_crop_transaction.f90")"
grep -Fq 'Compact physical continuation view. Parameters, forcing and retired' <<<"$WOF" || fail 'crop compact persistence boundary marker missing'
grep -Fq 'export_fmr_wofost_crop_transaction_persistence' <<<"$WOF" || fail 'crop persistence export missing'
grep -Fq 'reconstruct_fmr_wofost_crop_transaction_from_persistence' <<<"$WOF" || fail 'crop persistence reconstruction missing'
echo 'FKT16_STATE_OWNERSHIP_AND_SCHEMA_STRUCTURE=PASS'

echo 'FKT16_GATE QUALIFIED_STATE_PERSISTENCE_RESTART_V1_100_PERCENT_COMPLETE'
