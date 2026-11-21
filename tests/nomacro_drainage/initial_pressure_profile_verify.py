"""Own bounded original initialization and retain every literal prior gate."""
import ast,json,sys
from contextlib import contextmanager,ExitStack
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(ROOT/'tests/nomacro_drainage'),str(ROOT/'tests/nomacro_scheduled_subsurface'),str(ROOT/'app/hybrid_water')]
from ordinary_pond_verify import blob,norm,git,SURFACES
from analytical_hydraulic_archives import Archive
from model7_search_science import Store
from initial_pressure_profile_source_inverse import BASE,CORE,PATTERN,complete_inverse,boundary_complete_inverse,prior_source_projection
from initial_pressure_profile_central_science import read
from initial_pressure_profile_records import frontend
import vapor_boundary_verify as previous
SEALED='41d1483dab88a1cd11bb44d2b00fc01743bc0b92'
PROOF=ROOT/'integration/f-ci/nomacro-complete01'
OLD='tests/nomacro_drainage/vapor_boundary_verify.py'
GUARD_HOOK=' import initial_pressure_profile_verify as initialization\n return initialization.guard_previous_source()\n'
VERIFY_HOOK=' import initial_pressure_profile_verify as initialization\n return initialization.verify()\n'
STRIP_HOOK='import initial_pressure_profile_verify as initialization;return initialization.strip_current_evidence(text);'
PUBLICATION_HOOK=' import initial_pressure_profile_verify as initialization\n return initialization.publication_dependencies_unchanged()\n'
PARSERS=('initial_pressure_profile_source_inverse.py','initial_pressure_profile_science.py','initial_pressure_profile_central_science.py','initial_pressure_profile_runtime.py','initial_pressure_profile_inputs.py','initial_pressure_profile_frontend.py','initial_pressure_profile_records.py','initial_pressure_profile_postimage.py','initial_pressure_profile_preserve.py','initial_pressure_profile_ubuntu_preserve.py','initial_pressure_profile_bottom5_preserve.py','vapor_boundary_admission_seal.py')
RAW_NAMES=('HYDRAULIC_INITIAL_PRESSURE_WINDOWS_RAW_V1','HYDRAULIC_INITIAL_PRESSURE_UBUNTU_O0_RAW_V1','HYDRAULIC_INITIAL_PRESSURE_UBUNTU_O2_RAW_V1','HYDRAULIC_INITIAL_PRESSURE_BOTTOM5_WINDOWS_RAW_V1')


def literal(name,namespace):
 nodes=[n for n in ast.parse(blob(BASE,OLD)).body if isinstance(n,ast.FunctionDef) and n.name==name];assert len(nodes)==1
 exec(compile(ast.Module(body=nodes,type_ignores=[]),OLD,'exec'),namespace);return namespace[name]


@contextmanager
def inherited_scope():
 saved=previous.complete_inverse;previous.complete_inverse=boundary_complete_inverse
 try:
  with prior_source_projection():yield
 finally:previous.complete_inverse=saved


def prior_namespace():
 namespace=dict(vars(previous));literal('guard_previous_source',namespace);return namespace


def guard_previous_source():
 complete_inverse()
 for name in PARSERS:
  path='tests/nomacro_drainage/'+name;assert norm((ROOT/path).read_bytes())==blob(SEALED,path),'Frozen original initialization observer changed'
 raw=norm((ROOT/OLD).read_bytes()).decode()
 for hook in (GUARD_HOOK,VERIFY_HOOK,STRIP_HOOK,PUBLICATION_HOOK):assert raw.count(hook)==1;raw=raw.replace(hook,'',1)
 assert raw.encode()==blob(BASE,OLD),'Earlier native5 scientific body changed beyond exact delegation'
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
 guard_previous_source()
 names=['HYDRAULIC_INITIAL_PRESSURE_QUALIFICATION.json',*[name+'.json' for name in RAW_NAMES]]
 for name in names:
  path='integration/f-ci/nomacro-complete01/'+name;assert norm((ROOT/path).read_bytes())==blob(SEALED,path)
 qual=json.loads((PROOF/names[0]).read_text());assert qual['runtime']==CORE and qual['owning_absolute_water_and_CDE_limits']==1e-10
 for key in ('native_interface_changed','original_initialization_equations_changed','physical_process_equations_changed','new_physical_state','mass_or_convergence_limits_changed','production_authority_changed','canonical_admission','whole_historical_family_closed','RC3_changed'):assert qual[key] is False
 actual=read(PROOF)
 with ExitStack() as stack:
  for name in RAW_NAMES:
   store=Archive(PROOF,name,stack);assert store.record['sha256']==qual['raw_records'][name]['sha256']
   if name==RAW_NAMES[0]:dispatch=frontend(store)
  admission=Store(PROOF,'HYDRAULIC_VAPOR_BOUNDARY_ADMISSION_RAW_V1',stack);path='integration/f-ci/nomacro-complete01/HYDRAULIC_VAPOR_BOUNDARY_ADMISSION_RAW_V1.json';assert norm((ROOT/path).read_bytes())==blob(SEALED,path)
  record=json.loads((ROOT/path).read_text());assert record['canonical']=='56efdcbb78cbf4cdedd3b70bc44b76323f7112b4' and record['sha256']=='a16edb092e44215d1f552bae98555571b0a362f7763bb135a6f46dcc338d04a2'
  for name in admission.names:admission.get(name)
 with inherited_scope():prior=literal('verify',prior_namespace())()
 assert prior['status']=='BOUNDED_ORIGINAL_VAPOR_DRAINAGE_BOTTOM_NATIVE5_SOURCE_RAW_NATIVE_PASS'
 return dict(status='BOUNDED_ORIGINAL_INITIAL_PRESSURE_PROFILE_SOURCE_RAW_NATIVE_PASS',runtime=CORE,targeted=actual,frontend=dispatch,inherited_native5_and_all_earlier_science=prior,compiler_executions=0,model_executions=0,canonical_admission='OWNED_BY_ACTUAL_MERGE_RECEIPT',functional_completion='PARTIAL',whole_scientific_equivalence='NOT_QUALIFIED',global_family_and_gap_counts='UNKNOWN',RC3_changed=False)


if __name__=='__main__':print(json.dumps(verify(),indent=2))
