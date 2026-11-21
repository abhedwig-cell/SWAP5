"""Own bounded state composition and retain all literal earlier public science."""
import ast,json,sys
from contextlib import contextmanager,ExitStack
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(ROOT/'tests/nomacro_drainage'),str(ROOT/'tests/nomacro_scheduled_subsurface'),str(ROOT/'app/hybrid_water')]
from ordinary_pond_verify import blob,norm,git
from analytical_hydraulic_archives import Archive
from model7_search_science import Store
from initial_state_composition_source_inverse import PARENT,CORE,PATTERN,complete_inverse,initial_parent_complete_inverse,prior_source_projection
from initial_state_composition_central_science import read
import initial_pressure_profile_verify as previous
SEALED='3f21faf68e02a9435164f570f738b5ec0905f125'
PARENT_ADMISSION_SHA='3b98d9542200b247fe77d03033cee4cc5b42c3b3d445e3265da40e6cd40286a0'
PROOF=ROOT/'integration/f-ci/nomacro-complete01'
OLD='tests/nomacro_drainage/initial_pressure_profile_verify.py'
GUARD_HOOK=' import initial_state_composition_verify as state_owner\n return state_owner.guard_previous_source()\n'
VERIFY_HOOK=' import initial_state_composition_verify as state_owner\n return state_owner.verify()\n'
STRIP_HOOK=' import initial_state_composition_verify as state_owner\n return state_owner.strip_current_evidence(text)\n'
PUBLICATION_HOOK=' import initial_state_composition_verify as state_owner\n return state_owner.publication_dependencies_unchanged()\n'
PARSERS=('initial_state_composition_source_inverse.py','initial_state_composition_science.py','initial_state_composition_central_science.py','initial_state_composition_runtime.py','initial_state_composition_inputs.py','initial_state_composition_frontend.py','initial_state_composition_records.py','initial_state_composition_postimage.py','initial_state_composition_root_controls.py','initial_state_composition_source_controls.py','initial_state_composition_transactions.py','initial_state_composition_control_forensics.py','initial_state_composition_windows_preserve.py','initial_state_composition_ubuntu_preserve.py','initial_pressure_profile_admission_seal.py')
RAW_NAMES=('INITIAL_STATE_COMPOSITION_WINDOWS_RAW_V1','INITIAL_STATE_COMPOSITION_UBUNTU_O0_RAW_V1','INITIAL_STATE_COMPOSITION_UBUNTU_O2_RAW_V1')


def literal(name,namespace):
 nodes=[n for n in ast.parse(blob(PARENT,OLD)).body if isinstance(n,ast.FunctionDef) and n.name==name];assert len(nodes)==1
 exec(compile(ast.Module(body=nodes,type_ignores=[]),OLD,'exec'),namespace);return namespace[name]


@contextmanager
def inherited_scope():
 with prior_source_projection():yield


def prior_namespace():
 namespace=dict(vars(previous),complete_inverse=initial_parent_complete_inverse);literal('guard_previous_source',namespace);return namespace


def guard_previous_source():
 complete_inverse()
 for name in PARSERS:
  path='tests/nomacro_drainage/'+name;assert norm((ROOT/path).read_bytes())==blob(SEALED,path),'Frozen original state composition observer changed'
 raw=norm((ROOT/OLD).read_bytes()).decode()
 for hook in (GUARD_HOOK,VERIFY_HOOK,STRIP_HOOK,PUBLICATION_HOOK):assert raw.count(hook)==1;raw=raw.replace(hook,'',1)
 assert raw.encode()==blob(PARENT,OLD),'Earlier initial-profile scientific body changed beyond exact delegation'
 existing=set(git('ls-tree','-r','--name-only',PARENT,'--','tests').decode().splitlines());changed=set(git('diff','--name-only',PARENT,'--','tests').decode().splitlines())&existing;assert changed=={OLD},changed
 with inherited_scope():assert literal('guard_previous_source',prior_namespace())()
 return True


def strip_current_evidence(text):
 assert text.count(PATTERN)<=1
 return literal('strip_current_evidence',dict(vars(previous)))(text.replace(PATTERN,''))


def publication_dependencies_unchanged():
 guard_previous_source()
 with inherited_scope():return literal('publication_dependencies_unchanged',prior_namespace())()


def verify():
 guard_previous_source();names=['INITIAL_STATE_COMPOSITION_QUALIFICATION.json',*[name+'.json' for name in RAW_NAMES]]
 for name in names:
  path='integration/f-ci/nomacro-complete01/'+name;assert norm((ROOT/path).read_bytes())==blob(SEALED,path)
 qual=json.loads((PROOF/names[0]).read_text());assert qual['runtime']==CORE and qual['owning_absolute_water_and_CDE_limits']==1e-10 and qual['native_interface_changed'] and qual['new_native_codec']=='S5IRC003'
 for key in ('original_initialization_equations_changed','physical_process_equations_changed','new_physical_state','root_diagnostic_provider_body_changed','mass_or_convergence_limits_changed','rollback_or_rejected_trial_semantics_changed','production_authority_changed','canonical_admission','whole_historical_family_closed','RC3_changed'):assert qual[key] is False
 actual=read(PROOF)
 with ExitStack() as stack:
  for name in RAW_NAMES:
   store=Archive(PROOF,name,stack);assert store.record['sha256']==qual['raw_records'][name]['sha256']
  admission=Store(PROOF,'HYDRAULIC_INITIAL_PRESSURE_ADMISSION_RAW_V1',stack);path='integration/f-ci/nomacro-complete01/HYDRAULIC_INITIAL_PRESSURE_ADMISSION_RAW_V1.json';assert norm((ROOT/path).read_bytes())==blob(SEALED,path)
  record=json.loads((ROOT/path).read_text());assert record['canonical']==PARENT and record['sha256']==PARENT_ADMISSION_SHA
  for name in admission.names:admission.get(name)
 with inherited_scope():prior=literal('verify',prior_namespace())()
 assert prior['status']=='BOUNDED_ORIGINAL_INITIAL_PRESSURE_PROFILE_SOURCE_RAW_NATIVE_PASS'
 return dict(status='BOUNDED_ORIGINAL_INITIAL_STATE_COMPOSITION_SOURCE_RAW_NATIVE_PASS',runtime=CORE,targeted=actual,inherited_initialization_and_all_prior_science=prior,compiler_executions=0,model_executions=0,canonical_admission='OWNED_BY_ACTUAL_MERGE_RECEIPT',functional_completion='PARTIAL',whole_scientific_equivalence='NOT_QUALIFIED',global_family_and_gap_counts='UNKNOWN',RC3_changed=False)


if __name__=='__main__':print(json.dumps(verify(),indent=2))
