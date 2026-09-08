#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

BASE=828350c4f48e7004993af90b3b9e2f3874babec3
OLD_FWO10=98a26f0294aafac6d1ed46ace2d6bcc05914d9f0
EXPECTED_MERGE_BASE=7f906fcc53a4133b0e410eac7cf79fbb4eb672ab

changed_src="$(git diff --name-only "$BASE" -- src)"
[[ -z "$changed_src" ]] || {
  echo 'FWOF19_UNEXPECTED_PRODUCTION_DELTA' >&2
  printf '%s\n' "$changed_src" >&2
  exit 1
}
echo 'FWOF19_ZERO_PRODUCTION_DELTA=PASS'

check_blob() {
  local path="$1" expected="$2" actual
  actual="$(git hash-object "$path")"
  [[ "$actual" == "$expected" ]] || {
    echo "FWOF19_BLOB_MISMATCH $path expected=$expected actual=$actual" >&2
    exit 1
  }
}

check_blob src/crop/mod_crop_root_geometry_snapshot_producer.f90 56c3e10ccd25e6790882a649d472bd67a31d0f7b
check_blob src/crop/mod_crop_root_uptake_input_assembly.f90 71f1e237c41af56ee85dcadfaae330f5d50ae0f7
check_blob src/crop/mod_crop_root_uptake_input_contract.f90 cc5594f6c7a91ac2ff37af611d40c740b7f25521
check_blob src/crop/mod_nonadaptive_crop_root_view_producer.f90 32e827c70f733b5451328ac7a95a1001a0d711f7
check_blob src/process/mod_reference_et_transpiration_process.f90 497b42f2450a003a070dbc4020573866d1ef93b0
check_blob integration/f-wof/F-WOF15_STATUS.json 7d3451fbd69258422d4131f00449870819d8bf92
echo 'FWOF19_QUALIFIED_UPSTREAM_SOURCE_LOCKS=PASS'

actual_merge_base="$(git merge-base "$OLD_FWO10" "$BASE")"
[[ "$actual_merge_base" == "$EXPECTED_MERGE_BASE" ]] || {
  echo "FWOF19_UNEXPECTED_FWO10_MERGE_BASE actual=$actual_merge_base" >&2
  exit 1
}
read -r old_only current_only < <(git rev-list --left-right --count "$OLD_FWO10...$BASE")
[[ "$old_only" == "35" && "$current_only" == "331" ]] || {
  echo "FWOF19_UNEXPECTED_FWO10_DIVERGENCE old_only=$old_only current_only=$current_only" >&2
  exit 1
}
echo 'FWOF19_FWO10_DIVERGENCE_LOCK=PASS'

python3 - <<'PY'
from pathlib import Path
import json

expected_crop = [
    'mod_crop_root_geometry_snapshot_producer.f90',
    'mod_crop_root_uptake_input_assembly.f90',
    'mod_crop_root_uptake_input_contract.f90',
    'mod_nonadaptive_crop_root_view_producer.f90',
]
actual_crop = sorted(p.name for p in Path('src/crop').glob('*.f90'))
assert actual_crop == expected_crop, (actual_crop, expected_crop)

crop_code = '\n'.join(Path('src/crop', name).read_text().lower() for name in actual_crop)
assert 'save ::' not in crop_code
assert 'module mod_crop_lifecycle' not in crop_code
assert 'type, public :: crop_lifecycle' not in crop_code

contract = json.loads(Path('integration/f-wof/F-WOF19_CROP_CANOPY_OWNER_READINESS_CONTRACT.json').read_text())
evidence = json.loads(Path('integration/f-wof/F-WOF19_SOURCE_BOUND_OWNER_EVIDENCE.json').read_text())

assert contract['base']['commit'] == '828350c4f48e7004993af90b3b9e2f3874babec3'
assert contract['current_lineage_admission_gate']['requires_concrete_crop_lifecycle_host'] is True
assert contract['current_lineage_admission_gate']['requires_transaction_binding_for_crop_state'] is True
assert contract['current_lineage_admission_gate']['blind_merge_of_F_WOF04_through_F_WOF10'] is False

owners = contract['owner_classification']
assert owners['committed_crop_lifecycle_state'] == ['crop_emerged', 'development_stage_DVS', 'leaf_area_index_LAI']
assert owners['option_dependent_committed_root_state']['SWRD_1'] == []
assert owners['option_dependent_committed_root_state']['SWRD_2'] == ['actual_root_depth', 'potential_root_depth']
assert owners['option_dependent_committed_root_state']['SWRD_3'] == ['actual_root_biomass_WRT']

recon = owners['reconstructible_not_commit_authority']
for key in ['vegetation_cover_fraction', 'crop_factor_CF_for_SWCF1', 'rooted_nodes', 'cumulative_root_fraction_nonadaptive', 'potential_transpiration']:
    assert key in recon

inventory = evidence['current_admitted_lineage_inventory']
assert inventory['concrete_crop_lifecycle_host_present'] is False
assert inventory['committed_DVS_owner_present'] is False
assert inventory['committed_LAI_owner_present'] is False
assert inventory['committed_WRT_owner_present'] is False
assert inventory['committed_SWRD2_depth_owner_present'] is False
assert inventory['qualified_root_geometry_producer_present'] is True
assert inventory['qualified_nonadaptive_root_view_producer_present'] is True
assert inventory['qualified_restricted_ET_result_producer_present'] is True

historic = evidence['historical_F_WOF04_to_F_WOF10_lineage']
assert historic['contains_full_crop_lifecycle_host'] is False
assert historic['compare_to_F_WOF18']['status'] == 'diverged'
assert historic['compare_to_F_WOF18']['F_WOF10_only_commits'] == 35
assert historic['compare_to_F_WOF18']['F_WOF18_only_commits'] == 331
assert historic['blind_merge_permitted'] is False

assert evidence['transaction_gap']['current_lineage_has_crop_lifecycle_state_binding'] is False
assert evidence['transaction_gap']['current_lineage_has_crop_lifecycle_checkpoint_rollback_tests'] is False
assert evidence['decision'] == 'BLOCK_FULL_OWNER_COMPOSITION_UNTIL_TRANSACTIONAL_CROP_LIFECYCLE_HOST_EXISTS'

print('FWOF19_OWNER_CLASSIFICATION=PASS')
print('FWOF19_RECONSTRUCTIBLE_STATE_MINIMIZATION=PASS')
print('FWOF19_CURRENT_CROP_LIFECYCLE_HOST_ABSENT=PASS')
print('FWOF19_TRANSACTIONAL_CROP_OWNER_GAP=PASS')
print('FWOF19_BLIND_HISTORICAL_LINEAGE_MERGE_FORBIDDEN=PASS')
PY

echo 'FWOF19_CROP_CANOPY_OWNER_READINESS_GATE PASS'
