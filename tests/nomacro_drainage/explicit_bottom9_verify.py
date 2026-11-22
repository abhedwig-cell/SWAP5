"""Own explicit9 composition; retain complete literal admitted156 science."""
import ast,hashlib,io,json,sys
from pathlib import Path
from contextlib import ExitStack,redirect_stdout
ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(ROOT/'tests/nomacro_drainage'),str(ROOT/'tests/nomacro_scheduled_subsurface'),str(ROOT/'app/hybrid_water')]
from analytical_hydraulic_archives import Archive
from explicit_bottom9_source_inverse import BASE,CORE,CDE_CORE,CDE_POLICY_CORE,complete_inverse,git,blob,norm
from explicit_bottom9_parent_projection import prior_source_projection,workflow_metadata_inverse,PATTERN
from explicit_bottom9_archive_science import windows as original_windows,ubuntu as original_ubuntu
from explicit_bottom9_last_node_central import windows as last_windows,ubuntu as last_ubuntu,inherited42
from explicit_bottom9_cde_central import windows as cde_windows,monthly as cde_monthly,drain as cde_drain
import initial_profile_age_groundwater_verify as previous
PROOF=ROOT/'integration/f-ci/nomacro-complete01'
OLD='tests/nomacro_drainage/initial_profile_age_groundwater_verify.py'
SEALED='c59731559d7dd675263306cee900d57863f6ecf2'
PREVIOUS_CANONICAL='79ff3ab235f8b07535bf5273dcda32f4bef15f7d'
PARENT_ADMISSION_SHA='d40920872fcb4946417ffc3e4bbe6b2f5a545ae45bd271a8f9373ae9739b7f2f'
CONTRACT_SHA='3517d5e50630e31e78e4df34cf8b09fc4ec1e7103c3e1e33b9cd0b8423a889b3'
HOOKS={name:' import explicit_bottom9_verify as explicit_owner\n return explicit_owner.'+name+'('+('text' if name=='strip_current_evidence' else '')+')\n' for name in ('guard_previous_source','verify','strip_current_evidence','publication_dependencies_unchanged')}


def parent_literal(name):
 nodes=[n for n in ast.parse(blob(BASE,OLD)).body if isinstance(n,ast.FunctionDef) and n.name==name];assert len(nodes)==1
 namespace=dict(vars(previous));exec(compile(ast.Module(body=nodes,type_ignores=[]),OLD,'exec'),namespace);return namespace[name]


def checked_current_source():
 complete_inverse();workflow_metadata_inverse()
 contract=norm((PROOF/'EXPLICIT_BOTTOM9_COADMISSION_CONTRACT_V1.json').read_bytes());assert hashlib.sha256(contract).hexdigest()==CONTRACT_SHA,'Current coadmission contract changed'
 values=json.loads(contract);assert values['parent_contexts']==156 and values['new_explicit9_contexts']==60 and values['combined_contexts']==216 and values['previous_actual_canonical']==PREVIOUS_CANONICAL and values['parent_qualified_head']==BASE and values['parent_admission_sha256']==PARENT_ADMISSION_SHA
 assert values['canonical_admission'] is False and values['whole_historical_family_closed'] is False and values['RC3_changed'] is False
 for path in git('ls-tree','-r','--name-only',SEALED,'--','tests/nomacro_drainage').decode().splitlines():
  if Path(path).name.startswith('explicit_bottom9_') and path.endswith('.py'):assert norm((ROOT/path).read_bytes())==blob(SEALED,path),'Frozen explicit9 proof dependency changed: '+path
 for path in git('ls-tree','-r','--name-only',SEALED,'--','integration/f-ci/nomacro-complete01').decode().splitlines():
  if Path(path).name.startswith('EXPLICIT_BOTTOM9') and path.endswith('.json'):assert norm((ROOT/path).read_bytes())==blob(SEALED,path),'Frozen explicit9 raw/qualification record changed: '+path
 raw=norm((ROOT/OLD).read_bytes()).decode()
 for hook in HOOKS.values():assert raw.count(hook)==1;raw=raw.replace(hook,'',1)
 assert raw.encode()==blob(BASE,OLD),'Previous joint156 body differs beyond four exact delegations'
 return True


def guard_previous_source():
 checked_current_source()
 with prior_source_projection():assert parent_literal('guard_previous_source')()
 return True


def strip_current_evidence(text):
 assert text.count(PATTERN)<=1
 return parent_literal('strip_current_evidence')(text.replace(PATTERN,''))


def publication_dependencies_unchanged():
 checked_current_source()
 with prior_source_projection():return parent_literal('publication_dependencies_unchanged')()


def checked_raw_custody():
 # Refuse corrupt raw bytes before entering the expensive complete parent
 # scientific replay. Every original numerical assertion still runs on valid
 # evidence; this only makes real raw/inherited negative controls fail early.
 names=['EXPLICIT_BOTTOM9_WINDOWS_RAW_V1']+['EXPLICIT_BOTTOM9_UBUNTU_'+o+'_RAW_V1' for o in ('O0','O2')]+['EXPLICIT_BOTTOM9_LAST_NODE_WINDOWS_RAW_V1']+['EXPLICIT_BOTTOM9_LAST_NODE_UBUNTU_'+o+'_RAW_V1' for o in ('O0','O2')]+['EXPLICIT_BOTTOM9_CDE_WINDOWS_RAW_V1']+['EXPLICIT_BOTTOM9_CDE_UBUNTU_'+c+'_'+o+'_RAW_V1' for c in ('MONTHLY','DRAIN') for o in ('O0','O2')]+['INITIAL_PROFILE_FROST_ADMISSION_RAW_V1','HYDRAULIC_VAPOR_WINDOWS_WATER_RAW_V1']
 assert len(names)==13;observed=[]
 for name in names:
  path='integration/f-ci/nomacro-complete01/'+name+'.json'
  expected=BASE if name in ('INITIAL_PROFILE_FROST_ADMISSION_RAW_V1','HYDRAULIC_VAPOR_WINDOWS_WATER_RAW_V1') else SEALED
  raw=norm((ROOT/path).read_bytes());assert raw==blob(expected,path)
  q=json.loads(raw);whole=hashlib.sha256();size=0
  for index,part in enumerate(q['parts'],1):
   assert part['file']==(q['archive'] if len(q['parts'])==1 else q['archive']+f'.part{index:03d}')
   total=0;digest=hashlib.sha256()
   with (PROOF/part['file']).open('rb') as stream:
    while value:=stream.read(1024*1024):digest.update(value);whole.update(value);total+=len(value);size+=len(value)
   assert total==part['bytes'] and digest.hexdigest()==part['sha256'],'Actual raw part differs: '+name
  assert size==q['bytes'] and whole.hexdigest()==q['sha256'],'Actual whole raw archive differs: '+name
  observed.append(dict(archive=name,actual_bytes=size,actual_sha256=whole.hexdigest()))
 return observed


def parent_admission():
 assert len(PARENT_ADMISSION_SHA)==64,'Actual canonical parent proof must be sealed first'
 with ExitStack() as stack:
  store=Archive(PROOF,'INITIAL_PROFILE_AGE_GROUNDWATER_ADMISSION_RAW_V1',stack)
  assert store.record['sha256']==PARENT_ADMISSION_SHA and store.record['candidate']==BASE and store.record['canonical']==PREVIOUS_CANONICAL and store.record['canonical_admission'] is True
  for name in store.names:store.get(name)
 receipt=json.loads((PROOF/'INITIAL_PROFILE_AGE_GROUNDWATER_MERGE_RECEIPT_V1.json').read_text())
 assert receipt['status']=='ACTUAL_CANONICAL_156CONTEXT_PRESSURE_AGE_GROUNDWATER_ADMISSION_VERIFIED' and receipt['qualified_head']==BASE and receipt['actual_merge']==PREVIOUS_CANONICAL and receipt['admission_archive_sha256']==PARENT_ADMISSION_SHA and receipt['contexts']==156 and receipt['canonical_admission'] is True
 return receipt


def cde_prior_inheritance():
 from analytical_hydraulic_archives import SHA
 q=json.loads((PROOF/'EXPLICIT_BOTTOM9_CDE_PRIOR46_INHERITANCE_V2.json').read_text());assert len(q['observations'])==46 and q['source']=='ec40937ed483b6948eca15f29a6752df638342a1'
 for owner in ('cde_clock_output','cde_interval_output'):
  path='app/hybrid_water/'+owner+'.py'
  function=lambda raw:next(n for n in ast.parse(raw).body if isinstance(n,ast.FunctionDef) and n.name=='active_selection')
  assert ast.dump(function(norm((ROOT/path).read_bytes())),include_attributes=False)==ast.dump(function(blob(q['source'],path)),include_attributes=False),'Recorded prior46 selector code changed'
 with ExitStack() as stack:
  stores={}
  for item in q['observations']:
   name=item['archive']
   if name not in stores:stores[name]=Archive(PROOF,name,stack)
   raw=stores[name].get(item['profile']+'/RESULT.json');assert SHA(raw)==item['actual_prior_RESULT_sha256']
   assert item['actual_input_hashes_verified'] and all(owner['selection'] is None and owner['new_paired_condition_executed'] is False for owner in item['owners'])
 assert q['model_executions']==q['compiler_executions']==0 and q['prior_native_binding_or_producer_rewritten'] is False
 return q


def verify():
 # The literal parent verify executes its own whole SOURCE guard. Do not run
 # that complete guard a second time merely to enter this composed owner.
 checked_current_source();raw_custody=checked_raw_custody();admission=parent_admission()
 messages=io.StringIO()
 def observe(function,*args):
  with redirect_stdout(messages):return function(*args)
 path='integration/f-ci/nomacro-complete01/EXPLICIT_BOTTOM9_QUALIFICATION_V1.json';assert norm((ROOT/path).read_bytes())==blob(SEALED,path)
 qual=json.loads((ROOT/path).read_text());assert qual['targeted60_counts']==dict(contexts=60,native_checkpoints=420,exact_cold_windows=180,whole_compiled_counterparts=56,prior_intermediate_compiled_SOURCE_comparisons=24,canonical_admission=False)
 with prior_source_projection():prior=observe(parent_literal('verify'))
 assert prior['status']=='BOUNDED_ORIGINAL_INITIAL_PRESSURE_AGE_GROUNDWATER_SOURCE_RAW_NATIVE_PASS' and prior['coadmission']['contexts']==156
 observed={}
 def compare(key,actual,record):
  path='integration/f-ci/nomacro-complete01/'+record;assert norm((ROOT/path).read_bytes())==blob(SEALED,path)
  assert actual==json.loads((ROOT/path).read_text()),key
  observed[key]=actual
 compare('original_windows36',observe(original_windows,PROOF),'EXPLICIT_BOTTOM9_WINDOWS_CENTRAL_INDEPENDENT_V2.json')
 for opt in ('O0','O2'):compare('original_linux3_'+opt,observe(original_ubuntu,PROOF,opt),'EXPLICIT_BOTTOM9_UBUNTU_'+opt+'_CENTRAL_INDEPENDENT_V1.json')
 compare('last_node_windows2',observe(last_windows,PROOF),'EXPLICIT_BOTTOM9_LAST_NODE_WINDOWS_CENTRAL_INDEPENDENT_V1.json')
 for opt in ('O0','O2'):compare('last_node_linux1_'+opt,observe(last_ubuntu,PROOF,opt),'EXPLICIT_BOTTOM9_LAST_NODE_UBUNTU_'+opt+'_CENTRAL_INDEPENDENT_V1.json')
 compare('last_node_prior42',observe(inherited42,PROOF),'EXPLICIT_BOTTOM9_LAST_NODE_PRIOR42_ARCHIVE_INHERITANCE_V1.json')
 observed['cde_prior46']=cde_prior_inheritance()
 compare('cde_windows10',observe(cde_windows,PROOF),'EXPLICIT_BOTTOM9_CDE_WINDOWS_CENTRAL_INDEPENDENT_V2.json')
 for opt in ('O0','O2'):
  compare('cde_monthly_linux1_'+opt,observe(cde_monthly,PROOF,opt),'EXPLICIT_BOTTOM9_CDE_UBUNTU_MONTHLY_'+opt+'_CENTRAL_INDEPENDENT_V1.json')
  compare('cde_drain_linux1_'+opt,observe(cde_drain,PROOF,opt),'EXPLICIT_BOTTOM9_CDE_UBUNTU_DRAIN_'+opt+'_CENTRAL_INDEPENDENT_V1.json')
 return dict(status='BOUNDED_ORIGINAL_EXPLICIT9_WATER_CDE_AGE_CALENDAR_DRAINAGE_SOURCE_RAW_NATIVE_PASS',physical_equations_anchor=CORE,CDE_composition=CDE_CORE,descriptive_policy_source=CDE_POLICY_CORE,targeted_explicit9=observed,actual_current_raw_custody=raw_custody,scientific_reader_messages=messages.getvalue(),inherited_joint156_and_all_prior_science=prior,parent_actual_admission=admission,coadmission=dict(contexts=216,short35_contexts=214,year367_contexts=2,exact_cold_windows=652,native_calendar_samples=1518,compiled_postimages=159,previous_canonical=PREVIOUS_CANONICAL,standalone_AGE110_admission_claimed=False),compiler_executions=0,model_executions=0,canonical_admission='OWNED_BY_ACTUAL_MERGE_RECEIPT',functional_completion='PARTIAL',whole_scientific_equivalence='NOT_QUALIFIED',global_family_and_gap_counts='UNKNOWN',RC3_changed=False)


if __name__=='__main__':print(json.dumps(verify(),indent=2))
