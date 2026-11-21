"""Own bounded analytical water output composition and literal prior science."""
import ast,json,sys
from contextlib import contextmanager,ExitStack
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(ROOT/'tests/nomacro_drainage'),str(ROOT/'tests/nomacro_scheduled_subsurface'),str(ROOT/'app/hybrid_water')]
from ordinary_pond_verify import blob,norm,git,SURFACES
from analytical_hydraulic_archives import Archive
from model7_search_science import Store
from analytical_calendar_source_inverse import complete_inverse,snow_complete_inverse,prior_source_projection,BASE,CORE
from analytical_calendar_central_science import read
from analytical_calendar_records import native,frontend,monthly
import snow_vapor_verify as previous

SEALED='2d05d8c3a396a58913baf0834a629af1234148cf'
PROOF=ROOT/'integration/f-ci/nomacro-complete01'
OLD='tests/nomacro_drainage/snow_vapor_verify.py'
GUARD_HOOK=' import analytical_calendar_verify as calendar\n return calendar.guard_previous_source()\n'
VERIFY_HOOK=' import analytical_calendar_verify as calendar\n return calendar.verify()\n'
STRIP_HOOK=' import analytical_calendar_verify as calendar\n return calendar.strip_current_evidence(text)\n'
PUBLICATION_HOOK=' import analytical_calendar_verify as calendar\n return calendar.publication_dependencies_unchanged()\n'
PARSERS=('analytical_calendar_source_inverse.py','analytical_calendar_science.py','analytical_calendar_native_state.py','analytical_calendar_postimages.py','analytical_calendar_controls.py','analytical_calendar_frontend.py','analytical_calendar_preserve.py','analytical_calendar_ubuntu_preserve.py','analytical_calendar_central_science.py','analytical_calendar_records.py','analytical_monthly_postimage.py','analytical_calendar_batch.py','snow_vapor_admission_seal.py')
RAW_NAMES=('HYDRAULIC_ANALYTICAL_CALENDAR_WINDOWS_RAW_V1','HYDRAULIC_ANALYTICAL_CALENDAR_UBUNTU_O0_RAW_V1','HYDRAULIC_ANALYTICAL_CALENDAR_UBUNTU_O2_RAW_V1')


def literal(name,namespace):
 functions=[n for n in ast.parse(blob(BASE,OLD)).body if isinstance(n,ast.FunctionDef) and n.name==name];assert len(functions)==1
 exec(compile(ast.Module(body=functions,type_ignores=[]),OLD,'exec'),namespace);return namespace[name]


@contextmanager
def inherited_scope():
 saved=(previous.complete_inverse,previous.prior_source_projection)
 previous.complete_inverse=snow_complete_inverse;previous.prior_source_projection=prior_source_projection
 try:yield
 finally:previous.complete_inverse,previous.prior_source_projection=saved


def prior_namespace():
 namespace=dict(vars(previous));literal('guard_previous_source',namespace);return namespace


def guard_previous_source():
 complete_inverse()
 for name in PARSERS:
  path='tests/nomacro_drainage/'+name;assert norm((ROOT/path).read_bytes())==blob(SEALED,path),'Frozen analytical calendar observer changed'
 raw=norm((ROOT/OLD).read_bytes()).decode()
 for hook in (GUARD_HOOK,VERIFY_HOOK,STRIP_HOOK,PUBLICATION_HOOK):assert raw.count(hook)==1;raw=raw.replace(hook,'',1)
 assert raw.encode()==blob(BASE,OLD),'Earlier Snow vapor scientific body changed beyond exact delegation'
 existing=set(git('ls-tree','-r','--name-only',BASE,'--','tests').decode().splitlines());changed=set(git('diff','--name-only',BASE,'--','tests').decode().splitlines())&existing
 assert changed=={OLD},changed
 with inherited_scope():assert literal('guard_previous_source',prior_namespace())()
 return True


def strip_current_evidence(text):return literal('strip_current_evidence',dict(vars(previous)))(text)


def publication_dependencies_unchanged():
 guard_previous_source()
 with inherited_scope():return literal('publication_dependencies_unchanged',prior_namespace())()


def verify():
 guard_previous_source()
 names=['HYDRAULIC_ANALYTICAL_CALENDAR_QUALIFICATION.json',*[name+'.json' for name in RAW_NAMES]]
 for name in names:
  path='integration/f-ci/nomacro-complete01/'+name;assert norm((ROOT/path).read_bytes())==blob(SEALED,path)
 qual=json.loads((PROOF/names[0]).read_text());assert qual['runtime']==CORE and qual['owning_absolute_water_limit']==1e-10
 for field in ('canonical_admission','whole_historical_family_closed','physical_process_equations_changed','new_physical_state','native_interface_changed','mass_or_convergence_limits_changed','RC3_changed'):assert qual[field] is False
 actual=read(PROOF);controls=[]
 with ExitStack() as stack:
  for name in RAW_NAMES:
   store=Archive(PROOF,name,stack);assert store.record['sha256']==qual['raw_records'][name]['sha256']
   windows=name==RAW_NAMES[0]
   if windows:dispatch=frontend(store);inherited_monthly=monthly(store)
   for role in store.record['roles']:
    label=role['profile'].split('/')[-1]
    if windows:
     if not any(label==f'analytical-calendar-vapor8-{case}-{opt}-v1' for case in ('nprint2','perstep') for opt in ('O0','O2')):continue
     prefix='profiles/'+label.replace('-v1','-controls-v1')
    else:prefix=role['native_controls']
    controls.append(native(store,role,prefix))
  admission=Store(PROOF,'HYDRAULIC_SNOW_VAPOR_ADMISSION_RAW_V1',stack)
  path='integration/f-ci/nomacro-complete01/HYDRAULIC_SNOW_VAPOR_ADMISSION_RAW_V1.json';assert norm((ROOT/path).read_bytes())==blob(SEALED,path)
  record=json.loads((ROOT/path).read_text());assert record['canonical']=='a7c6936bd4c392712f5479a0a997bdc908b4ff97' and record['sha256']=='374f466a02f05d079492d26f0283a6de522e8968abc2fa02509ee877e6f46224'
  for name in admission.names:admission.get(name)
 assert len(controls)==8 and sum(v['compiled_refusals'] for v in controls)==192
 with inherited_scope():prior=literal('verify',prior_namespace())()
 assert prior['status']=='BOUNDED_ORIGINAL_SNOW_ACTIVE_VAPOR_SOURCE_RAW_NATIVE_PASS'
 return dict(status='BOUNDED_ORIGINAL_ANALYTICAL_WATER_OUTPUT_CALENDAR_SOURCE_RAW_NATIVE_PASS',runtime=CORE,targeted=actual,native_controls=controls,frontend=dispatch,monthly_exact_postimage_inheritance=inherited_monthly,inherited_actual_Snow_vapor_and_earlier_science=prior,compiler_executions=0,model_executions=0,canonical_admission='OWNED_BY_ACTUAL_MERGE_RECEIPT',functional_completion='PARTIAL',whole_scientific_equivalence='NOT_QUALIFIED',global_family_and_gap_counts='UNKNOWN',RC3_changed=False)


if __name__=='__main__':print(json.dumps(verify(),indent=2))
