from pathlib import Path
import json

root = Path(__file__).resolve().parents[2]
reg = json.loads((root / 'docs/scientific/registries/rb1-physical-science-t0-t7-authority.json').read_text())
status = json.loads((root / 'docs/scientific/registries/F-DOC18_STATUS.json').read_text())
main = (root / 'docs/scientific/F-DOC18_RB1_PHYSICAL_SCIENCE_T0_T7_AUTHORITY.md').read_text().lower()

assert reg['work_unit'] == 'F-DOC18'
assert reg['decision_if_exact_head_green'] == 'QUALIFIED_RB1_PHYSICAL_SCIENCE_T0_T7_AUTHORITY'
assert reg['base_documentation_authority']['sha'] == 'b0bdf08b5c38771a4ee22c93ed0949f408ceeb2b'
assert reg['base_documentation_authority']['tree'] == 'fe0a864e1d3ea9fb46e302a3307fec4957ba9199'

expected = ['RB1-SW-REFERENCE', 'RB1-ET-ROOT-SERIAL', 'RB1-SURFACE-EVAP-RESTRICTED']
assert reg['fdoc11_gap_decomposition']['physical_science_capabilities'] == expected
assert [c['capability_id'] for c in reg['capabilities']] == expected

resolved = 0
not_applicable = 0
by_id = {}
for cap in reg['capabilities']:
    by_id[cap['capability_id']] = cap
    assert cap['family'] == 'PHYSICAL_SCIENCE'
    tiers = cap['tier_dispositions']
    assert list(tiers.keys()) == [f'T{i}' for i in range(8)]
    for item in tiers.values():
        if item['status'] == 'RESOLVED_RESTRICTED':
            resolved += 1
        elif item['status'] == 'NOT_APPLICABLE_WITH_RATIONALE':
            not_applicable += 1
            assert item['rationale']
        else:
            raise AssertionError(item['status'])

assert resolved == 20
assert not_applicable == 4
assert reg['closure_result']['tier_slots_unresolved_after_fdoc18_if_exact_head_green'] == 0

richards = by_id['RB1-SW-REFERENCE']
rootcap = by_id['RB1-ET-ROOT-SERIAL']
evap = by_id['RB1-SURFACE-EVAP-RESTRICTED']
assert richards['tier_dispositions']['T6']['status'] == 'RESOLVED_RESTRICTED'
assert richards['tier_dispositions']['T7']['status'] == 'RESOLVED_RESTRICTED'
assert rootcap['tier_dispositions']['T6']['status'] == 'NOT_APPLICABLE_WITH_RATIONALE'
assert rootcap['tier_dispositions']['T7']['status'] == 'NOT_APPLICABLE_WITH_RATIONALE'
assert evap['tier_dispositions']['T6']['status'] == 'NOT_APPLICABLE_WITH_RATIONALE'
assert evap['tier_dispositions']['T7']['status'] == 'NOT_APPLICABLE_WITH_RATIONALE'

assert 'swkimpl=0' in richards['rb1_scope'].lower()
assert 'swsophy=0' in richards['rb1_scope'].lower()
assert 'drought-only' in rootcap['rb1_scope'].lower()
assert 'swinter=0' in evap['rb1_scope'].lower()
assert 'swredu=0' in evap['rb1_scope'].lower()

assert reg['mass_conservation'] == 'HARD_UNCHANGED'
assert reg['invariant_review']['count'] == 30
assert reg['invariant_review']['all_reviewed'] is True
assert reg['invariant_review']['adverse_delta'] is False
assert all(v is False for v in reg['hard_nonclaims'].values())

for token in ['darcy–buckingham', 'richards equation', 'newton-raphson', 'feddes', 'swredu=0', 'not_applicable_with_rationale', 'theory–code discrepancy rule']:
    assert token in main

assert status['decision'] == 'QUALIFIED_RB1_PHYSICAL_SCIENCE_T0_T7_AUTHORITY_WHEN_EXACT_HEAD_CI_GREEN'
assert status['science']['fdoc11_physical_science_capability_count'] == 3
assert status['science']['t0_t7_unresolved_after_exact_head_green'] == 0
assert status['science']['t11_complete_closed'] is False
assert status['science']['t12_validation_closed'] is False
assert status['science']['fully_traced_promoted'] is False
assert status['rb1']['scope_broadened'] is False
assert status['production_source_changed'] is False
assert status['reference_data_changed'] is False
assert status['mass_conservation'] == 'HARD_UNCHANGED'
assert status['ready_for_formal_status_a_assessment'] is False
assert status['status_a_certified'] is False
assert status['status_aa_certified'] is False
assert status['all_30_invariants_reviewed'] is True
assert status['adverse_invariant_delta'] is False

print('FDOC18_BASE_FDOC16_EXACT=PASS')
print('FDOC18_PHYSICAL_SCIENCE_DENOMINATOR_3=PASS')
print('FDOC18_ALL_24_T0_T7_SLOTS_DISPOSED=PASS')
print('FDOC18_RICHARDS_T0_T7_RESTRICTED=PASS')
print('FDOC18_ET_ROOT_T6_T7_NA_WITH_RATIONALE=PASS')
print('FDOC18_SURFACE_EVAP_T6_T7_NA_WITH_RATIONALE=PASS')
print('FDOC18_RB1_SCOPE_NOT_BROADENED=PASS')
print('FDOC18_MASS_CONSERVATION_HARD=PASS')
print('FDOC18_NO_FULLY_TRACED_OR_VALIDATION_PROMOTION=PASS')
print('FDOC18_ALL_30_INVARIANTS_REVIEWED=PASS')
print('FDOC18_NO_STATUS_A_CERTIFICATION=PASS')
print('FDOC18_DECISION_IF_EXACT_HEAD_GREEN=QUALIFIED_RB1_PHYSICAL_SCIENCE_T0_T7_AUTHORITY')
