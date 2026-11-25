"""Own pressure/AGE and prescribed-groundwater composition and retain every literal admitted Frost proof."""
import ast,json,sys
from contextlib import ExitStack
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(ROOT/'tests/nomacro_drainage'),str(ROOT/'tests/nomacro_scheduled_subsurface'),str(ROOT/'app/hybrid_water')]
from analytical_hydraulic_archives import Archive
from initial_profile_groundwater_source_inverse import CORE,complete_inverse,git,blob,norm
BASE='06e980f4bb17e43e4cc61cf4fc2d6ea17204526d'
from initial_profile_groundwater_parent_projection import CI,PATTERN,age_complete_inverse,prior_source_projection
from initial_profile_age_parent_projection import frost_parent_complete_inverse
from initial_profile_age_central_science import read as read_age
from initial_profile_groundwater_central_science import read as read_groundwater
import initial_profile_frost_verify as previous
PROOF=ROOT/'integration/f-ci/nomacro-complete01'
OLD='tests/nomacro_drainage/initial_profile_frost_verify.py'
SEALED='1e9aa98b5f92a60e8be195ee2f89ebc903f44069'
PREVIOUS_CANONICAL='84e815a0ba9f59a2d56fe838a3b13361ad8670a2'
PARENT_ADMISSION_SHA='db03a988270bd3ad29a745bf51d30f825d4f6455157e73d11ef2daa1d7d54b73'
GUARD_HOOK=' import initial_profile_age_groundwater_verify as joint_owner\n return joint_owner.guard_previous_source()\n'
VERIFY_HOOK=' import initial_profile_age_groundwater_verify as joint_owner\n return joint_owner.verify()\n'
STRIP_HOOK=' import initial_profile_age_groundwater_verify as joint_owner\n return joint_owner.strip_current_evidence(text)\n'
PUBLICATION_HOOK=' import initial_profile_age_groundwater_verify as joint_owner\n return joint_owner.publication_dependencies_unchanged()\n'
PARSERS=tuple('initial_profile_age_'+name+'.py' for name in ('source_inverse','parent_projection','science','central_science','ledger','runtime','discovery','postimage','frontend','inputs','preserve'))+tuple('initial_profile_groundwater_'+name+'.py' for name in ('source_inverse','parent_projection','science','central_science','runtime','discovery','postimage','activity','frontend','inputs','preserve'))+('initial_profile_frost_admission_seal.py',)
AGE_RAW_NAMES=tuple('INITIAL_PROFILE_AGE_'+suffix+'_RAW_V1' for suffix in ('WINDOWS','UBUNTU_O0','UBUNTU_O2'))
GROUNDWATER_RAW_NAMES=tuple('INITIAL_PROFILE_GROUNDWATER_'+suffix+'_RAW_V1' for suffix in ('WINDOWS','UBUNTU_O0','UBUNTU_O2'))
RAW_NAMES=AGE_RAW_NAMES+GROUNDWATER_RAW_NAMES


def literal(name,namespace):
 nodes=[n for n in ast.parse(blob(BASE,OLD)).body if isinstance(n,ast.FunctionDef) and n.name==name];assert len(nodes)==1
 exec(compile(ast.Module(body=nodes,type_ignores=[]),OLD,'exec'),namespace);return namespace[name]


def prior_namespace():
 namespace=dict(vars(previous),complete_inverse=frost_parent_complete_inverse);literal('guard_previous_source',namespace);return namespace


def guard_previous_source():
 import frost_boundary_verify as boundary_owner
 return boundary_owner.guard_previous_source()
 complete_inverse();age_complete_inverse()
 for name in PARSERS:
  path='tests/nomacro_drainage/'+name;assert norm((ROOT/path).read_bytes())==blob(SEALED,path),'Frozen pressure/AGE observer changed'
 raw=norm((ROOT/OLD).read_bytes()).decode()
 for hook in (GUARD_HOOK,VERIFY_HOOK,STRIP_HOOK,PUBLICATION_HOOK):assert raw.count(hook)==1;raw=raw.replace(hook,'',1)
 assert raw.encode()==blob(BASE,OLD),'Previous Frost scientific body changed beyond exact delegation'
 existing=set(git('ls-tree','-r','--name-only',BASE,'--','tests').decode().splitlines());changed=set(git('diff','--name-only',BASE,'--','tests').decode().splitlines())&existing
 assert changed=={OLD,'tests/nomacro_drainage/initial_profile_age_discovery.py','tests/nomacro_drainage/initial_profile_age_runtime.py','tests/nomacro_drainage/initial_profile_frost_admission_seal.py'},changed
 for path in CI:assert norm((ROOT/path).read_bytes()).count(PATTERN.encode())==1
 with prior_source_projection():assert literal('guard_previous_source',prior_namespace())()
 return True


def strip_current_evidence(text):
 import frost_boundary_verify as boundary_owner
 return boundary_owner.strip_current_evidence(text)
 assert text.count(PATTERN)<=1
 return literal('strip_current_evidence',dict(vars(previous)))(text.replace(PATTERN,''))


def publication_dependencies_unchanged():
 import frost_boundary_verify as boundary_owner
 return boundary_owner.publication_dependencies_unchanged()
 guard_previous_source()
 with prior_source_projection():return literal('publication_dependencies_unchanged',prior_namespace())()


def verify():
 import frost_boundary_verify as boundary_owner
 return boundary_owner.verify()
 guard_previous_source()
 names=['INITIAL_PROFILE_AGE_GROUNDWATER_QUALIFICATION.json','INITIAL_PROFILE_AGE_QUALIFICATION.json','INITIAL_PROFILE_AGE_CONTRACT_V2.json','INITIAL_PROFILE_AGE_CENTRAL_INDEPENDENT_V2.json','INITIAL_PROFILE_GROUNDWATER_CONTRACT_V1.json','INITIAL_PROFILE_AGE_GROUNDWATER_COADMISSION_CONTRACT_V1.json','INITIAL_PROFILE_GROUNDWATER_CENTRAL_INDEPENDENT_V1.json',*[name+'.json' for name in RAW_NAMES],'INITIAL_PROFILE_FROST_ADMISSION_RAW_V1.json','INITIAL_PROFILE_FROST_MERGE_RECEIPT_V1.json']
 for name in names:
  path='integration/f-ci/nomacro-complete01/'+name;assert norm((ROOT/path).read_bytes())==blob(SEALED,path),'Frozen joint qualification record changed: '+name
 qual=json.loads((PROOF/'INITIAL_PROFILE_AGE_GROUNDWATER_QUALIFICATION.json').read_text())
 assert qual['groundwater_runtime']==CORE and qual['age_runtime']=='9694eb2c4cc69f71c2ef90bc64b500fd35cb9924'
 assert qual['contexts']==qual['compiler_postimages']==70 and qual['required_actual_parent_canonical']==PREVIOUS_CANONICAL
 assert qual['exact_cold_windows']==210 and qual['native_checkpoints']==490 and qual['combined_contexts']==156
 for key in ('physical_process_equations_changed','original_initialization_equations_changed','new_physical_state','new_native_codec','native_interface_changed','mass_or_convergence_limits_changed','rollback_or_rejected_trial_semantics_changed','production_authority_changed','original_receipts_rewritten','explicit_positive_incoming_AGE_policy_cross_qualified','dry_surface_AGE_gap_closed','canonical_admission','whole_historical_family_closed','RC3_changed'):assert qual[key] is False
 actual_groundwater=read_groundwater(PROOF,GROUNDWATER_RAW_NAMES)
 assert actual_groundwater['contexts']==actual_groundwater['compiler_postimages']==46 and actual_groundwater['exact_cold_windows']==138 and actual_groundwater['native_checkpoints']==322 and sum(actual_groundwater['frontend']['counts'].values())==146
 assert actual_groundwater==json.loads((PROOF/'INITIAL_PROFILE_GROUNDWATER_CENTRAL_INDEPENDENT_V1.json').read_text())
 with prior_source_projection():actual_age=read_age(PROOF,AGE_RAW_NAMES)
 assert actual_age['contexts']==actual_age['compiler_postimages']==24 and actual_age['exact_cold_windows']==72 and actual_age['native_checkpoints']==168 and sum(actual_age['frontend']['counts'].values())==92
 assert actual_age==json.loads((PROOF/'INITIAL_PROFILE_AGE_CENTRAL_INDEPENDENT_V2.json').read_text())
 oldqual=json.loads((PROOF/'INITIAL_PROFILE_AGE_QUALIFICATION.json').read_text())
 assert oldqual['runtime']==qual['age_runtime'] and oldqual['canonical_admission'] is False
 with ExitStack() as stack:
  for name in RAW_NAMES:
   store=Archive(PROOF,name,stack);assert store.record['sha256']==qual['raw_records'][name]['sha256'] and store.record['bytes']==qual['raw_records'][name]['bytes']
  admission=Archive(PROOF,'INITIAL_PROFILE_FROST_ADMISSION_RAW_V1',stack)
  assert admission.record['candidate']==BASE and admission.record['canonical']==PREVIOUS_CANONICAL and admission.record['sha256']==PARENT_ADMISSION_SHA and admission.record['canonical_admission'] is True
  assert admission.record['phase1_and2_standalone_admission_claimed'] is False
  for name in admission.names:admission.get(name)
 receipt=json.loads((PROOF/'INITIAL_PROFILE_FROST_MERGE_RECEIPT_V1.json').read_text())
 assert receipt['status']=='ACTUAL_CANONICAL_86CONTEXT_PRESSURE_CALENDAR_FROST_ADMISSION_VERIFIED' and receipt['qualified_head']==BASE and receipt['actual_merge']==PREVIOUS_CANONICAL and receipt['admission_archive_sha256']==PARENT_ADMISSION_SHA and receipt['contexts']==86 and receipt['canonical_admission'] is True
 with prior_source_projection():prior=literal('verify',prior_namespace())()
 assert prior['status']=='BOUNDED_ORIGINAL_INITIAL_PRESSURE_FROST_SOURCE_RAW_NATIVE_PASS' and prior['coadmission']['contexts']==86
 return dict(status='BOUNDED_ORIGINAL_INITIAL_PRESSURE_AGE_GROUNDWATER_SOURCE_RAW_NATIVE_PASS',runtime=CORE,targeted_age=actual_age,targeted_groundwater=actual_groundwater,inherited_frost_and_all_prior_science=prior,coadmission=dict(contexts=156,short35_contexts=154,year367_contexts=2,exact_cold_windows=472,native_calendar_samples=1098,compiled_postimages=103,previous_canonical=PREVIOUS_CANONICAL,standalone_AGE110_admission_claimed=False),compiler_executions=0,model_executions=0,canonical_admission='OWNED_BY_ACTUAL_MERGE_RECEIPT',functional_completion='PARTIAL',whole_scientific_equivalence='NOT_QUALIFIED',global_family_and_gap_counts='UNKNOWN',RC3_changed=False)


if __name__=='__main__':print(json.dumps(verify(),indent=2))
