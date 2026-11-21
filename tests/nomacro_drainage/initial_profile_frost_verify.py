"""Own the original pressure/Frost seam and retain every earlier scientific gate."""
import ast,json,sys
from contextlib import ExitStack
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(ROOT/'tests/nomacro_drainage'),str(ROOT/'tests/nomacro_scheduled_subsurface'),str(ROOT/'app/hybrid_water')]
from analytical_hydraulic_archives import Archive
from initial_profile_frost_source_inverse import CORE,complete_inverse,git,blob,norm
from initial_profile_frost_parent_projection import PARENT,CI,PATTERN,profile_parent_complete_inverse,prior_source_projection
from initial_profile_frost_central_science import read
import initial_profile_calendar_verify as previous
PROOF=ROOT/'integration/f-ci/nomacro-complete01'
OLD='tests/nomacro_drainage/initial_profile_calendar_verify.py'
# This owner remains uninstalled until the real parent merge and its clean
# canonical public/publication observations have actually been sealed.
SEALED='PENDING_FINAL_OBSERVER_FREEZE'
PARENT_CANONICAL='PENDING_ACTUAL_PARENT_CANONICAL_ADMISSION'
PARENT_ADMISSION_SHA='PENDING_ACTUAL_PARENT_ADMISSION_ARCHIVE'
GUARD_HOOK=' import initial_profile_frost_verify as frost_owner\n return frost_owner.guard_previous_source()\n'
VERIFY_HOOK=' import initial_profile_frost_verify as frost_owner\n return frost_owner.verify()\n'
STRIP_HOOK=' import initial_profile_frost_verify as frost_owner\n return frost_owner.strip_current_evidence(text)\n'
PUBLICATION_HOOK=' import initial_profile_frost_verify as frost_owner\n return frost_owner.publication_dependencies_unchanged()\n'
PARSERS=tuple('initial_profile_frost_'+name+'.py' for name in ('source_inverse','parent_projection','science','central_science','records','postimage','frontend','inputs','preserve'))
RAW_NAMES=tuple('INITIAL_PROFILE_FROST_'+suffix+'_RAW_V1' for suffix in ('WINDOWS','UBUNTU_O0','UBUNTU_O2'))


def literal(name,namespace):
 nodes=[n for n in ast.parse(blob(PARENT,OLD)).body if isinstance(n,ast.FunctionDef) and n.name==name];assert len(nodes)==1
 exec(compile(ast.Module(body=nodes,type_ignores=[]),OLD,'exec'),namespace);return namespace[name]


def prior_namespace():
 namespace=dict(vars(previous),complete_inverse=profile_parent_complete_inverse);literal('guard_previous_source',namespace);return namespace


def guard_previous_source():
 complete_inverse();profile_parent_complete_inverse()
 for name in PARSERS:
  path='tests/nomacro_drainage/'+name;assert norm((ROOT/path).read_bytes())==blob(SEALED,path),'Frozen original pressure/Frost observer changed'
 raw=norm((ROOT/OLD).read_bytes()).decode()
 for hook in (GUARD_HOOK,VERIFY_HOOK,STRIP_HOOK,PUBLICATION_HOOK):assert raw.count(hook)==1;raw=raw.replace(hook,'',1)
 assert raw.encode()==blob(PARENT,OLD),'Previous initial/calendar scientific body changed beyond exact delegation'
 existing=set(git('ls-tree','-r','--name-only',PARENT,'--','tests').decode().splitlines());changed=set(git('diff','--name-only',PARENT,'--','tests').decode().splitlines())&existing;assert changed=={OLD},changed
 for path in CI:assert norm((ROOT/path).read_bytes()).count(PATTERN.encode())==1
 with prior_source_projection():assert literal('guard_previous_source',prior_namespace())()
 return True


def strip_current_evidence(text):
 assert text.count(PATTERN)<=1
 return literal('strip_current_evidence',dict(vars(previous)))(text.replace(PATTERN,''))


def publication_dependencies_unchanged():
 guard_previous_source()
 with prior_source_projection():return literal('publication_dependencies_unchanged',prior_namespace())()


def verify():
 guard_previous_source()
 for name in ('INITIAL_PROFILE_FROST_QUALIFICATION.json','INITIAL_PROFILE_FROST_CONTRACT_V1.json',*[name+'.json' for name in RAW_NAMES],'INITIAL_PROFILE_CALENDAR_ADMISSION_RAW_V1.json','INITIAL_PROFILE_CALENDAR_MERGE_RECEIPT_V1.json'):
  path='integration/f-ci/nomacro-complete01/'+name;assert norm((ROOT/path).read_bytes())==blob(SEALED,path)
 qual=json.loads((PROOF/'INITIAL_PROFILE_FROST_QUALIFICATION.json').read_text());assert qual['runtime']==CORE and qual['contexts']==qual['compiler_postimages']==12
 for key in ('physical_process_equations_changed','original_initialization_equations_changed','new_physical_state','new_native_codec','native_interface_changed','mass_or_convergence_limits_changed','rollback_or_rejected_trial_semantics_changed','production_authority_changed','original_receipts_rewritten','canonical_admission','whole_historical_family_closed','RC3_changed'):assert qual[key] is False
 actual=read(PROOF,RAW_NAMES);assert actual['contexts']==actual['compiler_postimages']==12 and actual['exact_cold_windows']==36 and actual['native_checkpoints']==84 and sum(actual['frontend']['counts'].values())==66
 with ExitStack() as stack:
  for name in RAW_NAMES:
   store=Archive(PROOF,name,stack);assert store.record['sha256']==qual['raw_records'][name]['sha256']
  admission=Archive(PROOF,'INITIAL_PROFILE_CALENDAR_ADMISSION_RAW_V1',stack)
  assert admission.record['candidate']==PARENT and admission.record['canonical']==PARENT_CANONICAL and admission.record['sha256']==PARENT_ADMISSION_SHA and admission.record['canonical_admission'] is True
  assert admission.record['phase1_standalone_admission_claimed'] is False
  for name in admission.names:admission.get(name)
 with prior_source_projection():prior=literal('verify',prior_namespace())()
 assert prior['status']=='BOUNDED_ORIGINAL_INITIAL_PROFILE_CALENDAR_SOURCE_RAW_NATIVE_PASS' and prior['coadmission']['contexts']==74
 return dict(status='BOUNDED_ORIGINAL_INITIAL_PRESSURE_FROST_SOURCE_RAW_NATIVE_PASS',runtime=CORE,targeted=actual,inherited_initial_calendars_and_all_prior_science=prior,compiler_executions=0,model_executions=0,canonical_admission='OWNED_BY_ACTUAL_MERGE_RECEIPT',functional_completion='PARTIAL',whole_scientific_equivalence='NOT_QUALIFIED',global_family_and_gap_counts='UNKNOWN',RC3_changed=False)


if __name__=='__main__':print(json.dumps(verify(),indent=2))
