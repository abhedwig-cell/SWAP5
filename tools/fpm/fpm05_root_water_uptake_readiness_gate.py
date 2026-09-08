#!/usr/bin/env python3
import json
import subprocess
from pathlib import Path

ROOT = Path('.')
BASE = '46ef693672dda13261a966cc9904e72437c7bcfb'
FSI11_QUALIFIED = '9f488bfb4805791e9513bfa7146c59d38423917b'
CURRENT_SOLVER_CONTRACT_BLOB = '57b51997d28807fbe2da1b2e5bf654fc4167adb9'
CURRENT_SOURCE_SINK_BLOB = 'd6c57add72387e5c0022a44319fff08046194aac'
FSI11_SOLVER_CONTRACT_BLOB = '0a57b07712f93538cbfaf9130838682307cede09'
FSI11_ROOT_PROVIDER_BLOB = 'ef2d2fd883d116c314b98e8f0f14330150b4778a'
HYDRAULIC_VIEW_BLOB = 'd7d85fe71ced0d94b29c8d9395859ae1834f7dd6'
COMMITTED_VIEW_BINDING_BLOB = '37f5968ffe00b1ff56f824f77ab94d3825171acf'
ROOTEXTRACTION_SHA256 = '8b7b2846618a8f82f3ed676c2c489d2d34be8c44b0a0d952f7f22ff09af78cd5'

inventory = json.loads((ROOT/'integration/f-pm/F-PM05_ROOT_WATER_UPTAKE_INVENTORY.json').read_text())
contract = json.loads((ROOT/'integration/f-pm/F-PM05_READINESS_CONTRACT.json').read_text())
manifest = (ROOT/'reference/swap-4.3.1/b0/file-manifest.sha256').read_text()

assert inventory['exact_base'] == BASE
assert contract['exact_branch_base'] == BASE
assert contract['expected_decision_from_current_source_state'] == 'BLOCKED_ROOT_WATER_UPTAKE_MIGRATION_REQUIRES_QUALIFIED_COMPOSED_ROOT_SINK_ROUTE'
print('FPM05_READINESS_CONTRACT PASS')

subprocess.run(['git','merge-base','--is-ancestor',BASE,'HEAD'], check=True)
changed = subprocess.check_output(['git','diff','--name-only',BASE,'HEAD','--','src','reference'], text=True).splitlines()
assert changed == [], f'F-PM05 readiness changed production/reference source: {changed}'
print('FPM05_NO_PRODUCTION_CHANGE PASS')

assert ROOTEXTRACTION_SHA256 in manifest and 'SWAP/rootextraction.f90' in manifest
assert inventory['source_basis']['rootextraction_sha256'] == ROOTEXTRACTION_SHA256
assert inventory['source_basis']['canonical_nested_archive_sha256'] == '1a2d798994c2990b397f9349317e3a26f40662fbcff55c9ea484dd638af45151'
print('FPM05_B110_ROOTEXTRACTION_SOURCE_LOCK PASS')

view_blob = subprocess.check_output(['git','hash-object','src/solver/mod_process_hydraulic_view.f90'], text=True).strip()
binding_blob = subprocess.check_output(['git','hash-object','src/runtime/mod_fmr_process_hydraulic_view_binding.f90'], text=True).strip()
assert view_blob == HYDRAULIC_VIEW_BLOB
assert binding_blob == COMMITTED_VIEW_BINDING_BLOB
view_text = (ROOT/'src/solver/mod_process_hydraulic_view.f90').read_text().lower()
binding_text = (ROOT/'src/runtime/mod_fmr_process_hydraulic_view_binding.f90').read_text().lower()
assert 'pressure_head' in view_text and 'water_content' in view_text
assert 'kernel_committed_state_t' in binding_text and 'snapshot' in binding_text
print('FPM05_COMMITTED_HYDRAULIC_VIEW_AVAILABLE PASS')

solver_blob = subprocess.check_output(['git','hash-object','src/solver/mod_soil_water_solver_contract.f90'], text=True).strip()
source_sink_blob = subprocess.check_output(['git','hash-object','src/solver/mod_b110_source_sink_provider.f90'], text=True).strip()
assert solver_blob == CURRENT_SOLVER_CONTRACT_BLOB
assert source_sink_blob == CURRENT_SOURCE_SINK_BLOB
solver_text = (ROOT/'src/solver/mod_soil_water_solver_contract.f90').read_text().lower()
source_sink_text = (ROOT/'src/solver/mod_b110_source_sink_provider.f90').read_text().lower()
assert 'root_sink_provider_t' not in solver_text
assert 'active root extraction not admitted by f-si10' in source_sink_text
assert 'if (any(abs(root_extraction_sink) > 0.0_real64))' in source_sink_text
assert 'sink = sink + self%drainage_flux_by_level(level,:)' in source_sink_text
print('FPM05_CURRENT_BASE_ROOT_SINK_REJECTS_NONZERO PASS')

fsi_solver_blob = subprocess.check_output(['git','rev-parse',f'{FSI11_QUALIFIED}:src/solver/mod_soil_water_solver_contract.f90'], text=True).strip()
fsi_root_blob = subprocess.check_output(['git','rev-parse',f'{FSI11_QUALIFIED}:src/solver/mod_b110_root_sink_provider.f90'], text=True).strip()
assert fsi_solver_blob == FSI11_SOLVER_CONTRACT_BLOB
assert fsi_root_blob == FSI11_ROOT_PROVIDER_BLOB
fsi_solver = subprocess.check_output(['git','show',f'{FSI11_QUALIFIED}:src/solver/mod_soil_water_solver_contract.f90'], text=True).lower()
fsi_root = subprocess.check_output(['git','show',f'{FSI11_QUALIFIED}:src/solver/mod_b110_root_sink_provider.f90'], text=True).lower()
fsi_qual = json.loads(subprocess.check_output(['git','show',f'{FSI11_QUALIFIED}:integration/f-si/F-SI11_QUALIFICATION.json'], text=True))
assert 'root_sink_provider_t' in fsi_solver
assert 'root_sink = self%root_extraction_sink' in fsi_root
assert fsi_qual['status'] == 'QUALIFIED_PRECOMPUTED_ROOT_SINK_SWKIMPL0'
assert fsi_qual['qualified'] is True
print('FPM05_FSI11_SEPARATE_ROOT_SINK_QUALIFIED PASS')

ancestor = subprocess.run(['git','merge-base','--is-ancestor',FSI11_QUALIFIED,BASE]).returncode == 0
assert not ancestor, 'F-SI11 unexpectedly already ancestor of F-PM05 base'
print('FPM05_FSI11_NOT_COMPOSED_IN_BASE PASS')

selected = inventory['smallest_structural_candidate_if_owner_route_exists']
assert selected['profile'] == 'MACRO_FEDDES_DROUGHT_ONLY_PRECOMPUTED_QROT'
assert selected['sw_oxygen'] == 0 and selected['sw_salinity'] == 0 and selected['swfrost'] == 0
assert selected['sw_compensate'] == 0 and selected['microscopic_root_uptake'] is False
assert selected['persistent_process_state_required'] is False
print('FPM05_SMALLEST_FEDDES_SEAM_SOURCE_BOUND PASS')

print('FPM05_ROOT_WATER_UPTAKE_READINESS BLOCKED_ROOT_WATER_UPTAKE_MIGRATION_REQUIRES_QUALIFIED_COMPOSED_ROOT_SINK_ROUTE')
