#!/usr/bin/env bash
set -euo pipefail

PRE_CANONICAL=36ebfcfe39fb9a70b522508933bfcf331545d7e0
OWNER_CHECKPOINT=8ec8958cb0cc7e68f4342e8c6f5568db8a78ebd1
STATUS=integration/f-ci/F-CI84_STATUS.json
CHECKPOINT=integration/f-wof/F-WOF-PP02_CHECKPOINT.json
TEN_CASE=tests/fwof/pp02/F-WOF-PP02_TEN_CASE_PRESERVATION_QUALIFICATION.json

expected_sources=(
  src/crop/mod_wofost81_assimilation.f90
  src/crop/mod_wofost81_crop_owner_state.f90
  src/crop/mod_wofost81_daily_parameter_contract.f90
  src/crop/mod_wofost81_leaf_structural_evolution.f90
  src/crop/mod_wofost81_n_owner_state.f90
  src/crop/mod_wofost81_n_stress.f90
  src/crop/mod_wofost81_nitrogen.f90
  src/crop/mod_wofost81_one_day_candidate.f90
  src/crop/mod_wofost81_parameter_contract.f90
  src/crop/mod_wofost81_prepare_assimilation.f90
  src/crop/mod_wofost81_rate_correction.f90
)
expected_hashes=(
  be5865fbce5e128fbb9ecf62d10a59443878d821
  689ae451c7ddc3a8c61fbc27a7a5d5ac15e68b5d
  736f0b2645955ae2333bc17d259316d55106b990
  c2338813d2d5d64454e17222afb6f7abff8c9c69
  10019345b281cb00cffa4a74f8fa6cf4a1ae46ae
  2c437012196db6a0886f6cd01101b5552013a952
  49d75092fd06920468eb8665a3e1138022d19751
  74055565400c501f8a9f0bbe12d5d235c3990b61
  cb62f049db15ad116d91037f1b2aae817e528483
  787773d17ad42c1651bf7e87c8731674d7193bcc
  b30939392ef5c20a6cebdec2db381a047b64bf6c
)

for i in "${!expected_sources[@]}"; do
  got=$(git hash-object "${expected_sources[$i]}")
  [[ "$got" == "${expected_hashes[$i]}" ]] || {
    echo "SOURCE_BLOB_MISMATCH ${expected_sources[$i]} got=$got expected=${expected_hashes[$i]}" >&2
    exit 1
  }
done
echo 'FCI84_SOURCE_BLOBS=PASS'

mapfile -t actual_delta < <(git diff --name-only "$PRE_CANONICAL"..HEAD -- src | sort)
printf '%s\n' "${expected_sources[@]}" | sort > /tmp/fci84_expected_sources.txt
printf '%s\n' "${actual_delta[@]}" > /tmp/fci84_actual_sources.txt
diff -u /tmp/fci84_expected_sources.txt /tmp/fci84_actual_sources.txt
echo 'FCI84_PRODUCTION_DELTA=PASS ELEVEN_ADDITIVE_WOFOST81_MODULES'

[[ ! -e tests/fwof/pp02/case001_fixture.tar.gz.b64 ]]
[[ ! -e tests/fwof/pp02/case001_fixture.b64.part04 ]]
[[ -e tests/fwof/pp02/case001_fixture.b64.part04a ]]
[[ -e tests/fwof/pp02/case001_fixture.b64.part04b ]]

git fetch --no-tags origin work/f-wof-pp02-wofost81-migration-preservation >/dev/null
git cat-file -e "$OWNER_CHECKPOINT^{commit}"
python3 - "$STATUS" "$CHECKPOINT" "$TEN_CASE" <<'PY'
import json, pathlib, sys
status=json.loads(pathlib.Path(sys.argv[1]).read_text())
checkpoint=json.loads(pathlib.Path(sys.argv[2]).read_text())
ten=json.loads(pathlib.Path(sys.argv[3]).read_text())
assert status['work_unit']=='F-CI84'
assert status['canonical']['pre_admission_head']=='36ebfcfe39fb9a70b522508933bfcf331545d7e0'
assert status['canonical']['relevant_pp02_dependency_delta'] is False
assert status['owner']['qualified_checkpoint_head']=='8ec8958cb0cc7e68f4342e8c6f5568db8a78ebd1'
assert checkpoint['verdict']=='QUALIFIED_TEN_CASE_WOFOST81_MIGRATION_PRESERVATION_READY_FOR_ADMISSION_RECONCILE'
assert checkpoint['ten_case_preservation']['status']=='PASS'
assert checkpoint['ten_case_preservation']['cases']==10
assert checkpoint['ten_case_preservation']['states']==1045
assert checkpoint['ten_case_preservation']['accepted_transitions']==1035
assert checkpoint['ten_case_preservation']['RD_included'] is False
assert checkpoint['ten_case_preservation']['TRA_included'] is False
assert checkpoint['mutations']['runtime_behavior_changed'] is False
assert checkpoint['mutations']['tolerances_changed'] is False
assert ten['status']=='QUALIFIED'
assert ten['verdict']=='QUALIFIED_TEN_CASE_WOFOST81_MIGRATION_PRESERVATION'
assert ten['totals']=={'accepted_transitions':1035,'cases':10,'states':1045}
assert ten['tolerances_changed'] is False
assert ten['production_semantics_changed_to_force_pass'] is False
assert ten['explicitly_outside_surface']==['RD','TRA']
assert all(v['first_divergence'] is None for v in ten['global_maxima'].values())
print('FCI84_GOVERNANCE_EVIDENCE=PASS')
PY

bash tests/fwof/pp02/run_wofost81_one_day_candidate_integration.sh
bash tests/fwof/pp02/run_wofost81_case001_fullseason_gate.sh
bash tests/fwof/pp02/run_wofost81_case002_fullseason_gate.sh

echo 'FCI84_DECISION=QUALIFIED_FOR_CANONICAL_ADMISSION'
