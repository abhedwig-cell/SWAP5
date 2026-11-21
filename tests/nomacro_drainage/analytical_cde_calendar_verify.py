"""Own analytical/vapor CDE calendars and every literal prior scientific gate."""
import ast,json,sys
from contextlib import contextmanager,ExitStack
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(ROOT/'tests/nomacro_drainage'),str(ROOT/'tests/nomacro_scheduled_subsurface'),str(ROOT/'app/hybrid_water')]
from ordinary_pond_verify import blob,norm,git
from analytical_hydraulic_archives import Archive
from model7_search_science import Store
from analytical_cde_calendar_source_inverse import BASE,CORE,PATTERN,complete_inverse,state_parent_complete_inverse,prior_source_projection
from analytical_cde_calendar_central_science import read
import initial_state_composition_verify as previous
SEALED='b4877cec308ccd764830a995f84f02bab572a978'
PARENT_CANONICAL='904d3cdd1fb9132839bec689c22cdeecdba79676'
PARENT_ADMISSION_SHA='ef54d7540f754c1a206c1258a910a1e3b893d582dbaae6c091d4eb931ed041cb'
PROOF=ROOT/'integration/f-ci/nomacro-complete01'
OLD='tests/nomacro_drainage/initial_state_composition_verify.py'
GUARD_HOOK=' import analytical_cde_calendar_verify as calendar_owner\n return calendar_owner.guard_previous_source()\n'
VERIFY_HOOK=' import analytical_cde_calendar_verify as calendar_owner\n return calendar_owner.verify()\n'
STRIP_HOOK=' import analytical_cde_calendar_verify as calendar_owner\n return calendar_owner.strip_current_evidence(text)\n'
PUBLICATION_HOOK=' import analytical_cde_calendar_verify as calendar_owner\n return calendar_owner.publication_dependencies_unchanged()\n'
PARSERS=('analytical_cde_calendar_source_inverse.py','analytical_cde_calendar_science.py','analytical_cde_calendar_central_science.py','analytical_cde_calendar_runtime.py','analytical_cde_calendar_inputs.py','analytical_cde_calendar_frontend.py','analytical_cde_calendar_controls.py','analytical_cde_calendar_control_forensics.py','analytical_cde_calendar_postimage.py','analytical_cde_calendar_windows_preserve.py','analytical_cde_calendar_ubuntu_preserve.py','analytical_cde_calendar_continuation_preserve.py','initial_state_composition_admission_seal.py')
RAW_NAMES=('ANALYTICAL_CDE_CALENDAR_WINDOWS_RAW_V1','ANALYTICAL_CDE_CALENDAR_UBUNTU_O0_RAW_V1','ANALYTICAL_CDE_CALENDAR_UBUNTU_O2_RAW_V1','ANALYTICAL_CDE_CALENDAR_POSTIMAGE_RAW_V1')


def literal(name,namespace):
 nodes=[n for n in ast.parse(blob(BASE,OLD)).body if isinstance(n,ast.FunctionDef) and n.name==name];assert len(nodes)==1
 exec(compile(ast.Module(body=nodes,type_ignores=[]),OLD,'exec'),namespace);return namespace[name]


@contextmanager
def inherited_scope():
 with prior_source_projection():yield


def prior_namespace():
 namespace=dict(vars(previous),complete_inverse=state_parent_complete_inverse);literal('guard_previous_source',namespace);return namespace


def guard_previous_source():
 complete_inverse()
 for name in PARSERS:
  path='tests/nomacro_drainage/'+name;assert norm((ROOT/path).read_bytes())==blob(SEALED,path),'Frozen analytical CDE calendar observer changed'
 raw=norm((ROOT/OLD).read_bytes()).decode()
 for hook in (GUARD_HOOK,VERIFY_HOOK,STRIP_HOOK,PUBLICATION_HOOK):assert raw.count(hook)==1;raw=raw.replace(hook,'',1)
 assert raw.encode()==blob(BASE,OLD),'Earlier original state scientific body changed beyond exact delegation'
 existing=set(git('ls-tree','-r','--name-only',BASE,'--','tests').decode().splitlines());changed=set(git('diff','--name-only',BASE,'--','tests').decode().splitlines())&existing;assert changed=={OLD},changed
 with inherited_scope():assert literal('guard_previous_source',prior_namespace())()
 return True


def strip_current_evidence(text):
 assert text.count(PATTERN)<=1
 return literal('strip_current_evidence',dict(vars(previous)))(text.replace(PATTERN,''))


def publication_dependencies_unchanged():
 guard_previous_source()
 with inherited_scope():return literal('publication_dependencies_unchanged',prior_namespace())()


def verify():
 guard_previous_source();names=['ANALYTICAL_CDE_CALENDAR_QUALIFICATION.json',*[name+'.json' for name in RAW_NAMES]]
 for name in names:
  path='integration/f-ci/nomacro-complete01/'+name;assert norm((ROOT/path).read_bytes())==blob(SEALED,path)
 qual=json.loads((PROOF/names[0]).read_text());assert qual['runtime']==CORE and qual['owning_absolute_water_and_CDE_limits']==1e-10 and qual['native_interface_changed'] and qual['new_native_codec']=='S5HCC006'
 for key in ('physical_process_equations_changed','new_physical_state','mass_or_convergence_limits_changed','rollback_or_rejected_trial_semantics_changed','production_authority_changed','original_receipts_rewritten','canonical_admission','whole_historical_family_closed','RC3_changed'):assert qual[key] is False
 actual=read(PROOF)
 with ExitStack() as stack:
  for name in RAW_NAMES:
   store=Archive(PROOF,name,stack);assert store.record['sha256']==qual['raw_records'][name]['sha256']
  admission=Store(PROOF,'INITIAL_STATE_COMPOSITION_ADMISSION_RAW_V1',stack);path='integration/f-ci/nomacro-complete01/INITIAL_STATE_COMPOSITION_ADMISSION_RAW_V1.json';assert norm((ROOT/path).read_bytes())==blob(SEALED,path)
  record=json.loads((ROOT/path).read_text());assert record['canonical']==PARENT_CANONICAL and record['candidate']==BASE and record['sha256']==PARENT_ADMISSION_SHA
  for name in admission.names:admission.get(name)
 with inherited_scope():prior=literal('verify',prior_namespace())()
 assert prior['status']=='BOUNDED_ORIGINAL_INITIAL_STATE_COMPOSITION_SOURCE_RAW_NATIVE_PASS'
 return dict(status='BOUNDED_ORIGINAL_ANALYTICAL_VAPOR_CDE_CALENDAR_SOURCE_RAW_NATIVE_PASS',runtime=CORE,targeted=actual,inherited_state_and_all_prior_science=prior,compiler_executions=0,model_executions=0,canonical_admission='OWNED_BY_ACTUAL_MERGE_RECEIPT',functional_completion='PARTIAL',whole_scientific_equivalence='NOT_QUALIFIED',global_family_and_gap_counts='UNKNOWN',RC3_changed=False)


if __name__=='__main__':print(json.dumps(verify(),indent=2))
