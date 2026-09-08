#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

BASE=530c36b8e9e6b6e9c7b6f179bc0edf199a40d1bf
ASSESSMENT_HEAD=1e8e35b20d11cf00114d41dd5b340aa73656b278
HISTORICAL_FWO06=28e127b1555f05a1862652ee6f33abe1619bbbec
EXPECTED_MERGE_BASE=7f906fcc53a4133b0e410eac7cf79fbb4eb672ab

changed_src="$(git diff --name-only "$BASE" -- src)"
[[ -z "$changed_src" ]] || {
  echo 'FWOF22_UNEXPECTED_PRODUCTION_DELTA' >&2
  printf '%s\n' "$changed_src" >&2
  exit 1
}
echo 'FWOF22_ZERO_PRODUCTION_DELTA=PASS'

check_blob() {
  local path="$1" expected="$2" actual
  actual="$(git hash-object "$path")"
  [[ "$actual" == "$expected" ]] || {
    echo "FWOF22_BLOB_MISMATCH $path expected=$expected actual=$actual" >&2
    exit 1
  }
}

check_blob src/crop/mod_crop_lifecycle_state.f90 c1fbb2c615254cfda0b26a7aff20447fb9960502
check_blob src/crop/mod_swrd2_crop_lifecycle_state.f90 206a2b472119c459b884ee360bd19c7a2ac7077b
check_blob src/crop/mod_crop_root_geometry_snapshot_producer.f90 56c3e10ccd25e6790882a649d472bd67a31d0f7b
check_blob integration/f-wof/F-WOF21_STATUS.json df9099c709a7ed0a0596b90ddbd11ad0c6ade22e
check_blob integration/f-wof/F-WOF21_SOURCE_BOUND_ROOT_HISTORY_EVIDENCE.json 8d3f0f365f65320518b9254f823a59429d07bc38
echo 'FWOF22_CURRENT_LINEAGE_LOCKS=PASS'

historic_owner_blob="$(git show "$HISTORICAL_FWO06:integration/f-wof/F-WOF06_STATE_OWNERSHIP.md" | git hash-object --stdin)"
historic_status_blob="$(git show "$HISTORICAL_FWO06:integration/f-wof/F-WOF06_STATUS.json" | git hash-object --stdin)"
[[ "$historic_owner_blob" == "ababdb87e3c644bb65cf32665698af596aefffa8" ]] || {
  echo "FWOF22_HISTORICAL_OWNER_BLOB_MISMATCH actual=$historic_owner_blob" >&2
  exit 1
}
[[ "$historic_status_blob" == "3d1d182820d3e4c2d5884e4ba84ac0a508991c3d" ]] || {
  echo "FWOF22_HISTORICAL_STATUS_BLOB_MISMATCH actual=$historic_status_blob" >&2
  exit 1
}

actual_merge_base="$(git merge-base "$HISTORICAL_FWO06" "$ASSESSMENT_HEAD")"
[[ "$actual_merge_base" == "$EXPECTED_MERGE_BASE" ]] || {
  echo "FWOF22_HISTORICAL_MERGE_BASE_MISMATCH actual=$actual_merge_base" >&2
  exit 1
}
read -r historical_only current_only < <(git rev-list --left-right --count "$HISTORICAL_FWO06...$ASSESSMENT_HEAD")
[[ "$historical_only" == "17" && "$current_only" == "355" ]] || {
  echo "FWOF22_HISTORICAL_DIVERGENCE_MISMATCH historical_only=$historical_only current_only=$current_only" >&2
  exit 1
}
echo 'FWOF22_HISTORICAL_FWO06_OWNERSHIP_EVIDENCE_LOCK=PASS'

python3 - <<'PY'
from pathlib import Path
import json

contract = json.loads(Path('integration/f-wof/F-WOF22_WRT_BIOMASS_OWNER_READINESS_CONTRACT.json').read_text())
evidence = json.loads(Path('integration/f-wof/F-WOF22_SOURCE_BOUND_BIOMASS_OWNER_EVIDENCE.json').read_text())
status21 = json.loads(Path('integration/f-wof/F-WOF21_STATUS.json').read_text())

assert contract['base']['commit'] == '530c36b8e9e6b6e9c7b6f179bc0edf199a40d1bf'
assert status21['status'] == 'QUALIFIED_OPTIONAL_SWRD2_TRANSACTIONAL_ROOT_HISTORY_STATE'
assert status21['qualified_mode_state']['SWRD_3']['status'] == 'BLOCKED_BROADER_CROP_BIOMASS_OWNER_REQUIRED'

own = contract['ownership_resolution']
assert own['actual_WRT']['classification'] == 'READ_ONLY_FIELD_OF_PRIMARY_COMMITTED_CROP_BIOMASS_STATE'
assert own['actual_WRT']['standalone_root_geometry_state'] is False
assert own['potential_WRTPOT']['classification'] == 'OPTIONAL_TRANSACTIONAL_SHADOW_BIOMASS_STATE_WHEN_POTENTIAL_TRAJECTORY_IS_ENABLED'
assert own['potential_WRTPOT']['mandatory_per_column'] is False
assert own['potential_WRTPOT']['needed_by_F_WOF17_current_geometry'] is False
assert contract['current_lineage_gate']['primary_biomass_owner_present'] is False
assert contract['current_lineage_gate']['authoritative_actual_WRT_view_present'] is False
assert contract['current_lineage_gate']['optional_potential_shadow_host_present'] is False
assert contract['current_lineage_gate']['SWRD3_production_composition_allowed'] is False
assert 'WRT-only committed helper state' in contract['forbidden']
assert 'simple-crop SWRD=3 admission contrary to B1.10' in contract['forbidden']

legacy = evidence['legacy_scientific_binding']
assert legacy['simple_crop_restriction']['classification'] == 'SWRD3_NOT_ADMITTED_FOR_CROPTYPE1_SIMPLE_CROP'
assert legacy['fixed_crop_WRT']['classification'] == 'CROP_BIOMASS_STATE'
assert legacy['WOFOST_WRT']['classification'] == 'PRIMARY_ACTUAL_CROP_BIOMASS_STATE'
assert legacy['WOFOST_WRTPOT']['classification'] == 'POTENTIAL_SHADOW_BIOMASS_STATE'

historic = evidence['historical_owner_resolution']
assert historic['semantic_decision'] == 'ACTUAL_PRIMARY_POTENTIAL_OPTIONAL_SHADOW'
assert historic['production_merge_permitted'] is False
assert historic['current_compare']['status'] == 'diverged'
assert historic['current_compare']['historical_only_commits'] == 17
assert historic['current_compare']['current_only_commits'] == 355

inv = evidence['current_lineage_inventory']
assert inv['primary_biomass_owner']['present'] is False
assert inv['authoritative_actual_WRT_view']['present'] is False
assert inv['optional_potential_shadow_host']['present'] is False
consumer = inv['SWRD3_geometry_consumer']
assert consumer['present'] is True
assert consumer['entrypoint'] == 'build_swrd3_root_geometry_snapshot'
assert consumer['input'] == 'actual_root_biomass'
assert consumer['uses_WRTPOT'] is False

geom = Path('src/crop/mod_crop_root_geometry_snapshot_producer.f90').read_text().lower()
assert 'subroutine build_swrd3_root_geometry_snapshot' in geom
assert 'actual_root_biomass' in geom
assert 'wrtpot' not in geom
assert 'potential_root_biomass' not in geom

common = Path('src/crop/mod_crop_lifecycle_state.f90').read_text().lower()
swrd2 = Path('src/crop/mod_swrd2_crop_lifecycle_state.f90').read_text().lower()
for code in (common, swrd2):
    assert 'wrtpot' not in code
    assert 'root_biomass' not in code

assert evidence['ownership_decision']['actual_WRT'] == 'READ_ONLY_VIEW_FIELD_FROM_PRIMARY_COMMITTED_CROP_BIOMASS_OWNER'
assert evidence['ownership_decision']['WRTPOT'] == 'OPTIONAL_TRANSACTIONAL_SHADOW_FIELD_ONLY_WHEN_POTENTIAL_REFERENCE_TRAJECTORY_ENABLED'
assert evidence['ownership_decision']['WRT_only_root_geometry_helper_state'] == 'FORBIDDEN'
assert evidence['ownership_decision']['SWRD3_current_geometry_composition'] == 'BLOCKED_UNTIL_AUTHORITATIVE_ACTUAL_WRT_VIEW_EXISTS'
assert evidence['decision'] == 'QUALIFY_OWNERSHIP_RECONCILIATION_BLOCK_PRODUCTION_SWRD3_UNTIL_BIOMASS_OWNER_VIEW_EXISTS'

print('FWOF22_ACTUAL_WRT_PRIMARY_BIOMASS_OWNER_CLASSIFICATION=PASS')
print('FWOF22_WRTPOT_OPTIONAL_TRANSACTIONAL_SHADOW_CLASSIFICATION=PASS')
print('FWOF22_SWRD3_EXISTING_CONSUMER_SEAM=PASS')
print('FWOF22_SIMPLE_CROP_SWRD3_REMAINS_FORBIDDEN=PASS')
print('FWOF22_WRT_ONLY_DUPLICATE_STATE_FORBIDDEN=PASS')
print('FWOF22_PRODUCTION_SWRD3_REMAINS_FAIL_CLOSED=PASS')
PY

echo 'FWOF22_WRT_BIOMASS_OWNER_READINESS_GATE PASS'
