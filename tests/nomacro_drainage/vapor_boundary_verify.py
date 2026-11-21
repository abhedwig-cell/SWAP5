"""Own bounded native5 vapor boundary composition and every literal prior gate."""
import ast,json,sys
from contextlib import contextmanager,ExitStack
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(ROOT/'tests/nomacro_drainage'),str(ROOT/'tests/nomacro_scheduled_subsurface'),str(ROOT/'app/hybrid_water')]
from ordinary_pond_verify import blob,norm,git,SURFACES
from analytical_hydraulic_archives import Archive
from model7_search_science import Store
from vapor_boundary_source_inverse import complete_inverse,calendar_complete_inverse,prior_source_projection,BASE,CORE
from vapor_boundary_central_science import read
from vapor_boundary_records import native,frontend,unselected
import analytical_calendar_verify as previous
SEALED='256b7c06086053c293d4d26be7c95efbc1642386'
PROOF=ROOT/'integration/f-ci/nomacro-complete01'
OLD='tests/nomacro_drainage/analytical_calendar_verify.py'
GUARD_HOOK=' import vapor_boundary_verify as boundary\n return boundary.guard_previous_source()\n'
VERIFY_HOOK=' import vapor_boundary_verify as boundary\n return boundary.verify()\n'
STRIP_HOOK='import vapor_boundary_verify as boundary;return boundary.strip_current_evidence(text);'
PUBLICATION_HOOK=' import vapor_boundary_verify as boundary\n return boundary.publication_dependencies_unchanged()\n'
PARSERS=('vapor_boundary_source_inverse.py','vapor_boundary_science.py','vapor_boundary_central_science.py','vapor_boundary_records.py','vapor_boundary_runtime.py','vapor_boundary_controls.py','vapor_boundary_inputs.py','vapor_boundary_batch.py','vapor_boundary_frontend_controls.py','vapor_boundary_preserve.py','vapor_boundary_ubuntu_preserve.py','vapor_boundary_unselected_postimage.py','vapor_boundary_assessment.py','analytical_calendar_admission_seal.py','vapor_boundary_guard_postimage.py','vapor_boundary_guard_preserve.py','vapor_boundary_guard_ubuntu_preserve.py')
INITIAL_RAW_NAMES=('HYDRAULIC_VAPOR_BOUNDARY_WINDOWS_RAW_V1','HYDRAULIC_VAPOR_BOUNDARY_UBUNTU_O0_RAW_V1','HYDRAULIC_VAPOR_BOUNDARY_UBUNTU_O2_RAW_V1')
RAW_NAMES=INITIAL_RAW_NAMES+('HYDRAULIC_VAPOR_BOUNDARY_GUARD_WINDOWS_RAW_V1','HYDRAULIC_VAPOR_BOUNDARY_GUARD_UBUNTU_O0_RAW_V1','HYDRAULIC_VAPOR_BOUNDARY_GUARD_UBUNTU_O2_RAW_V1')


def literal(name,namespace):
 nodes=[n for n in ast.parse(blob(BASE,OLD)).body if isinstance(n,ast.FunctionDef) and n.name==name];assert len(nodes)==1
 exec(compile(ast.Module(body=nodes,type_ignores=[]),OLD,'exec'),namespace);return namespace[name]


@contextmanager
def inherited_scope():
 saved=(previous.complete_inverse,previous.prior_source_projection)
 previous.complete_inverse=calendar_complete_inverse;previous.prior_source_projection=prior_source_projection
 try:
  with prior_source_projection():yield
 finally:previous.complete_inverse,previous.prior_source_projection=saved


def prior_namespace():
 namespace=dict(vars(previous));literal('guard_previous_source',namespace);return namespace


def guard_previous_source():
 complete_inverse()
 for name in PARSERS:
  path='tests/nomacro_drainage/'+name;assert norm((ROOT/path).read_bytes())==blob(SEALED,path),'Frozen vapor boundary scientific observer changed'
 raw=norm((ROOT/OLD).read_bytes()).decode()
 for hook in (GUARD_HOOK,VERIFY_HOOK,STRIP_HOOK,PUBLICATION_HOOK):assert raw.count(hook)==1;raw=raw.replace(hook,'',1)
 assert raw.encode()==blob(BASE,OLD),'Earlier analytical calendar scientific body changed beyond exact delegation'
 existing=set(git('ls-tree','-r','--name-only',BASE,'--','tests').decode().splitlines());changed=set(git('diff','--name-only',BASE,'--','tests').decode().splitlines())&existing;assert changed=={OLD},changed
 with inherited_scope():assert literal('guard_previous_source',prior_namespace())()
 return True


def strip_current_evidence(text):return literal('strip_current_evidence',dict(vars(previous)))(text)


def publication_dependencies_unchanged():
 guard_previous_source()
 with inherited_scope():return literal('publication_dependencies_unchanged',prior_namespace())()


def verify():
 guard_previous_source()
 paths=['HYDRAULIC_VAPOR_BOUNDARY_QUALIFICATION.json',*[name+'.json' for name in RAW_NAMES]]
 for name in paths:
  path='integration/f-ci/nomacro-complete01/'+name;assert norm((ROOT/path).read_bytes())==blob(SEALED,path)
 qual=json.loads((PROOF/paths[0]).read_text());assert qual['runtime']==CORE and qual['native_interface_changed'] and qual['native_domain_version']==5 and qual['owning_absolute_water_and_CDE_limits']==1e-10
 for key in ('canonical_admission','whole_historical_family_closed','physical_process_equations_changed','new_physical_water_store','mass_or_convergence_limits_changed','RC3_changed'):assert qual[key] is False
 actual=read(PROOF);controls=[]
 with ExitStack() as stack:
  for name in RAW_NAMES:
   store=Archive(PROOF,name,stack);assert store.record['sha256']==qual['raw_records'][name]['sha256'];windows=name==RAW_NAMES[0]
   if name not in INITIAL_RAW_NAMES:continue
   if windows:dispatch=frontend(store);postimages=unselected(store,PROOF,stack)
   for role in store.record['roles']:
    label=role['profile'].split('/')[-1]
    if windows:
     if not any(label==f'vapor-boundary-{case}-{opt}-v3' for case in ('undrained-water11','head5-active-cde8-11','unit8-active-cde7-8') for opt in ('O0','O2')):continue
     prefix='profiles/'+label.replace('-v3','-controls-v1')
    else:prefix=role['native_controls']
    controls.append(native(store,role,prefix))
  admission=Store(PROOF,'HYDRAULIC_ANALYTICAL_CALENDAR_ADMISSION_RAW_V1',stack);path='integration/f-ci/nomacro-complete01/HYDRAULIC_ANALYTICAL_CALENDAR_ADMISSION_RAW_V1.json';assert norm((ROOT/path).read_bytes())==blob(SEALED,path)
  record=json.loads((ROOT/path).read_text());assert record['canonical']=='1e639e0febd12922e48ed7e239f29f7fabb95909' and record['sha256']=='a6eb787101eeda0f13b31247f5db6c9801a37c2c87f3bda046029964e1745013'
  for name in admission.names:admission.get(name)
 assert len(controls)==12 and sum(v['actual_compiled_refusals'] for v in controls)==588
 with inherited_scope():prior=literal('verify',prior_namespace())()
 assert prior['status']=='BOUNDED_ORIGINAL_ANALYTICAL_WATER_OUTPUT_CALENDAR_SOURCE_RAW_NATIVE_PASS'
 return dict(status='BOUNDED_ORIGINAL_VAPOR_DRAINAGE_BOTTOM_NATIVE5_SOURCE_RAW_NATIVE_PASS',runtime=CORE,targeted=actual,native_controls=controls,frontend=dispatch,unchanged_native3_and4_compiled_postimages=postimages,inherited_actual_calendar_Snow_vapor_and_earlier_science=prior,compiler_executions=0,model_executions=0,canonical_admission='OWNED_BY_ACTUAL_MERGE_RECEIPT',functional_completion='PARTIAL',whole_scientific_equivalence='NOT_QUALIFIED',global_family_and_gap_counts='UNKNOWN',RC3_changed=False)


if __name__=='__main__':print(json.dumps(verify(),indent=2))
