"""Own bounded original pressure/calendar composition and every prior gate."""
import ast,json,sys
from contextlib import ExitStack
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(ROOT/'tests/nomacro_drainage'),str(ROOT/'tests/nomacro_scheduled_subsurface'),str(ROOT/'app/hybrid_water')]
from analytical_hydraulic_archives import Archive
from initial_profile_calendar_source_inverse import BASE,CORE,PATTERN,complete_inverse,calendar_parent_complete_inverse,prior_source_projection
from initial_profile_calendar_central_science import read
from ordinary_pond_verify import git,blob,norm
import analytical_cde_calendar_verify as previous
PROOF=ROOT/'integration/f-ci/nomacro-complete01'
OLD='tests/nomacro_drainage/analytical_cde_calendar_verify.py'
SEALED='PENDING_FINAL_OBSERVER_FREEZE'
PREVIOUS_CANONICAL='904d3cdd1fb9132839bec689c22cdeecdba79676'
PARENT_STAGE_SHA='PENDING_ACTUAL_CANDIDATE_STAGE_CLOSURE'
GUARD_HOOK=' import initial_profile_calendar_verify as profile_owner\n return profile_owner.guard_previous_source()\n'
VERIFY_HOOK=' import initial_profile_calendar_verify as profile_owner\n return profile_owner.verify()\n'
STRIP_HOOK=' import initial_profile_calendar_verify as profile_owner\n return profile_owner.strip_current_evidence(text)\n'
PUBLICATION_HOOK=' import initial_profile_calendar_verify as profile_owner\n return profile_owner.publication_dependencies_unchanged()\n'
PARSERS=tuple('initial_profile_calendar_'+name+'.py' for name in ('source_inverse','science','central_science','runtime','inputs','frontend','records','postimage','windows_preserve','ubuntu_preserve'))+('analytical_cde_calendar_candidate_stage_seal.py',)
RAW_NAMES=('INITIAL_PROFILE_CALENDAR_WINDOWS_RAW_V1','INITIAL_PROFILE_CALENDAR_UBUNTU_O0_RAW_V1','INITIAL_PROFILE_CALENDAR_UBUNTU_O2_RAW_V1','INITIAL_PROFILE_CALENDAR_IMPLICIT_UBUNTU_O0_RAW_V1','INITIAL_PROFILE_CALENDAR_IMPLICIT_UBUNTU_O2_RAW_V1')


def literal(name,namespace):
 nodes=[n for n in ast.parse(blob(BASE,OLD)).body if isinstance(n,ast.FunctionDef) and n.name==name];assert len(nodes)==1
 exec(compile(ast.Module(body=nodes,type_ignores=[]),OLD,'exec'),namespace);return namespace[name]


def prior_namespace():
 namespace=dict(vars(previous),complete_inverse=calendar_parent_complete_inverse);literal('guard_previous_source',namespace);return namespace


def guard_previous_source():
 complete_inverse()
 for name in PARSERS:
  path='tests/nomacro_drainage/'+name;assert norm((ROOT/path).read_bytes())==blob(SEALED,path),'Frozen initial profile calendar observer changed'
 raw=norm((ROOT/OLD).read_bytes()).decode()
 for hook in (GUARD_HOOK,VERIFY_HOOK,STRIP_HOOK,PUBLICATION_HOOK):assert raw.count(hook)==1;raw=raw.replace(hook,'',1)
 assert raw.encode()==blob(BASE,OLD),'Previous analytical CDE scientific body changed beyond exact delegation'
 existing=set(git('ls-tree','-r','--name-only',BASE,'--','tests').decode().splitlines());changed=set(git('diff','--name-only',BASE,'--','tests').decode().splitlines())&existing;assert changed=={OLD},changed
 with prior_source_projection():assert literal('guard_previous_source',prior_namespace())()
 return True


def strip_current_evidence(text):
 assert text.count(PATTERN)<=1
 return literal('strip_current_evidence',dict(vars(previous)))(text.replace(PATTERN,''))


def publication_dependencies_unchanged():
 guard_previous_source()
 with prior_source_projection():return literal('publication_dependencies_unchanged',prior_namespace())()


def verify():
 guard_previous_source();names=['INITIAL_PROFILE_CALENDAR_QUALIFICATION.json',*[name+'.json' for name in RAW_NAMES]]
 for name in names:
  path='integration/f-ci/nomacro-complete01/'+name;assert norm((ROOT/path).read_bytes())==blob(SEALED,path)
 qual=json.loads((PROOF/names[0]).read_text());assert qual['runtime']==CORE and qual['owning_absolute_water_and_CDE_limits']==1e-10
 for key in ('original_initialization_equations_changed','physical_process_equations_changed','new_physical_state','new_native_codec','native_interface_changed','mass_or_convergence_limits_changed','rollback_or_rejected_trial_semantics_changed','production_authority_changed','original_receipts_rewritten','canonical_admission','whole_historical_family_closed','RC3_changed'):assert qual[key] is False
 actual=read(PROOF,RAW_NAMES);assert actual['contexts']==36 and actual['exact_cold_windows']==108 and actual['native_calendar_samples']==252 and actual['compiler_postimages']==16 and sum(actual['frontend']['counts'].values())==55
 with ExitStack() as stack:
  for name in RAW_NAMES:
   store=Archive(PROOF,name,stack);assert store.record['sha256']==qual['raw_records'][name]['sha256']
  admission=Archive(PROOF,'ANALYTICAL_CDE_CALENDAR_CANDIDATE_STAGE_RAW_V1',stack)
  assert admission.record['candidate']==BASE and admission.record['previous_canonical']==PREVIOUS_CANONICAL and admission.record['sha256']==PARENT_STAGE_SHA
  assert admission.record['canonical_admission'] is False and admission.record['standalone_merge_claimed'] is False and admission.record['final_integrated_head_gates_required'] is True
  for name in admission.names:admission.get(name)
 with prior_source_projection():prior=literal('verify',prior_namespace())()
 assert prior['status']=='BOUNDED_ORIGINAL_ANALYTICAL_VAPOR_CDE_CALENDAR_SOURCE_RAW_NATIVE_PASS'
 assert len(prior['targeted']['profiles'])==38
 return dict(status='BOUNDED_ORIGINAL_INITIAL_PROFILE_CALENDAR_SOURCE_RAW_NATIVE_PASS',runtime=CORE,targeted=actual,inherited_analytical_CDE_and_all_prior_science=prior,coadmission=dict(contexts=74,exact_cold_windows=226,native_calendar_samples=524,actual_compiled_refusals=500,frontend_observations=94,compiled_postimages=21,previous_canonical=PREVIOUS_CANONICAL,phase1_standalone_admission_claimed=False),compiler_executions=0,model_executions=0,canonical_admission='OWNED_BY_ACTUAL_MERGE_RECEIPT',functional_completion='PARTIAL',whole_scientific_equivalence='NOT_QUALIFIED',global_family_and_gap_counts='UNKNOWN',RC3_changed=False)


if __name__=='__main__':print(json.dumps(verify(),indent=2))
