"""Own bounded original Snow vapor source, original raw and inherited science."""
import ast,io,json,re,struct,sys,types,zipfile
from contextlib import ExitStack
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(ROOT/'tests/nomacro_drainage'),str(ROOT/'tests/nomacro_scheduled_subsurface'),str(ROOT/'app/hybrid_water')]
from ordinary_pond_verify import blob,norm,git,SURFACES
from analytical_hydraulic_archives import Archive,SHA
from model7_search_science import Store
from snow_vapor_source_inverse import complete_inverse,prior_source_projection,CheckedParent,PARENT,RUNTIME,SEALED,CI,WORKFLOW,PATTERN
from snow_vapor_central_science import read
import default_model_grammar_verify as previous

SOURCE_SEALED='148d6dae6ac8ed3594d578abc7e36d0c42125d66'
PROOF=ROOT/'integration/f-ci/nomacro-complete01'
OLD='tests/nomacro_drainage/default_model_grammar_verify.py'
GUARD_HOOK='    import snow_vapor_verify as snow_vapor\n    return snow_vapor.guard_previous_source()\n'
VERIFY_HOOK='    import snow_vapor_verify as snow_vapor\n    return snow_vapor.verify()\n'
STRIP_HOOK='    import snow_vapor_verify as snow_vapor\n    return snow_vapor.strip_current_evidence(text)\n'
PUBLICATION_HOOK='    import snow_vapor_verify as snow_vapor\n    return snow_vapor.publication_dependencies_unchanged()\n'
PARSERS=('snow_vapor_science.py','snow_vapor_central_science.py','snow_vapor_runtime.py','snow_vapor_native_controls.py','snow_vapor_frontend_controls.py','snow_vapor_batch.py','snow_vapor_transactions.py','snow_vapor_preserve.py','snow_vapor_ubuntu_preserve.py')
RAW_NAMES=('HYDRAULIC_SNOW_VAPOR_WINDOWS_RAW_V1','HYDRAULIC_SNOW_VAPOR_UBUNTU_O0_RAW_V1','HYDRAULIC_SNOW_VAPOR_UBUNTU_O2_RAW_V1')


def literal(name,namespace):
 functions=[n for n in ast.parse(blob(PARENT,OLD)).body if isinstance(n,ast.FunctionDef) and n.name==name]
 assert len(functions)==1;exec(compile(ast.Module(body=functions,type_ignores=[]),OLD,'exec'),namespace);return namespace[name]


def prior_namespace():
 namespace=dict(vars(previous),ROOT=CheckedParent());literal('guard_previous_source',namespace);return namespace


def guard_previous_source():
 complete_inverse()
 for name in PARSERS:
  path='tests/nomacro_drainage/'+name;assert norm((ROOT/path).read_bytes())==blob(SEALED,path),'Frozen Snow vapor scientific observer changed'
 path='tests/nomacro_drainage/snow_vapor_source_inverse.py';assert norm((ROOT/path).read_bytes())==blob(SOURCE_SEALED,path)
 raw=norm((ROOT/OLD).read_bytes()).decode()
 for hook in (GUARD_HOOK,VERIFY_HOOK,STRIP_HOOK,PUBLICATION_HOOK):assert raw.count(hook)==1;raw=raw.replace(hook,'',1)
 assert raw.encode()==blob(PARENT,OLD),'Earlier default-model scientific body changed beyond exact delegation'
 existing=set(git('ls-tree','-r','--name-only',PARENT,'--','tests').decode().splitlines())
 changed=set(git('diff','--name-only',PARENT,'--','tests').decode().splitlines())&existing
 assert changed=={OLD},changed
 for path in CI:
  raw=norm((ROOT/path).read_bytes()).decode();assert raw.count(PATTERN)==1 and raw.replace(PATTERN,'',1).encode()==blob(PARENT,path)
 assert set(git('diff','--name-only',PARENT,'--','.github/workflows').decode().splitlines())=={*CI,WORKFLOW}
 with prior_source_projection():assert literal('guard_previous_source',prior_namespace())()
 return True


def strip_current_evidence(text):
 if PATTERN in text:assert text.count(PATTERN)==1;text=text.replace(PATTERN,'',1)
 return literal('strip_current_evidence',dict(vars(previous)))(text)


def publication_dependencies_unchanged():
 guard_previous_source()
 with prior_source_projection():return literal('publication_dependencies_unchanged',prior_namespace())()


def frontend_records(store):
 from hydraulic_vapor import selection
 from experimental_project import switches
 selected=types.FunctionType(selection.__code__,dict(selection.__globals__,Path=lambda value:value))
 prefix='profiles/snow-vapor-frontend-controls-v2/'
 q=json.loads(store.get(prefix+'RESULT.json'));assert q['status']=='ACTUAL_SNOW_VAPOR_72_DISPATCH_BOUNDS_AND_PRIOR_CODEC_CONTROLS_PASS' and len(q['checks'])==72
 assert not git('diff',RUNTIME,q['source'],'--',*SURFACES)
 counts={}
 for index,item in enumerate(q['checks']):
  kind='water' if index<36 else 'cde';i=index%36
  label=(f'{kind}-positive-{i}' if i<8 else f'{kind}-negative-{i-8}' if i<32 else f'{kind}-inactive-'+('model1','ignored-model7','all-off')[i-32] if i<35 else f'{kind}-prior-NoSnow')
  folder=store.view(prefix+label)
  for name,digest in item['input_inventory']:assert SHA((folder/name).read_bytes())==digest
  text=(folder/'swap.swp').read_text(encoding='cp1252')
  try:switch=switches(text);actual=selected(folder,switch,True)
  except ValueError:
   assert item['status']=='REFUSED_BEFORE_BUILD' and 8<=i<32;actual='REFUSED'
  else:
   assert item['status']!='REFUSED_BEFORE_BUILD'
   if i<8:assert actual and switch['SWSNOW']==1
   elif i<35:assert actual is None
   else:assert actual and switch['SWSNOW']==0
  counts[item['status']]=counts.get(item['status'],0)+1
 assert counts=={'ACTUAL_SELECTED_NATIVE4':16,'REFUSED_BEFORE_BUILD':48,'HISTORICAL_INACTIVE_FLAGS_PRESERVED':6,'PRIOR_NATIVE3_PRESERVED':2}
 original=json.loads(store.get('profiles/original-snow-vapor-reader-v1/RESULT.json'))
 assert original['status']=='FOUR_ORIGINAL_SNOW_ACTIVE_VAPOR_CONFIGURATIONS_READER_ACCEPTED_ZERO_MODEL_DAYS' and len(original['cases'])==4 and original['accepted_model_days']==original['compiler_executions']==0
 for item in original['cases']:
  prefix='profiles/original-snow-vapor-reader-v1/'+item['label']+'/'
  assert item['original_reader_ready'] and item['no_model_day'] and item['stderr_empty'] and item['returncode'] in (0,100)
  assert SHA(store.get(prefix+'swap.swp'))==item['input_sha256']
  stdout=store.get(prefix+'donor.stdout');assert b'HYBRID_READY' in stdout and b'HYBRID_DAY_RETURN' not in stdout and not store.get(prefix+'donor.stderr')
 transactions=json.loads(store.get('profiles/snow-vapor-transactions-v1/RESULT.json'))
 assert transactions['status']=='FOUR_ACTUAL_SNOW_VAPOR_EXTERNAL_DISCARD_REPLAY_ACCEPT_RECOVERY_CONTEXTS_PASS' and len(transactions['contexts'])==4
 assert not git('diff',RUNTIME,transactions['source'],'--',*SURFACES)
 for item in transactions['contexts'].values():assert item==dict(discard_no_day_advance=True,replay_exact=True,accept_exact=True,recovered_next_day_exact=True,origin_unchanged=True)
 custody=json.loads(store.get('SOURCE_CUSTODY_V1.json'));assert custody['runtime']==RUNTIME and custody['baseline']==PARENT
 from snow_vapor_source_inverse import CHANGED
 assert set(custody['complete_changed_source_inventory'])==set(custody['sources'])==set(CHANGED)
 for name,item in custody['sources'].items():
  raw=store.get('source-delta/git/'+name);assert raw==blob(RUNTIME,name) and SHA(raw)==item['git_sha256']
  actual=store.get('source-delta/actual-working/'+name) if 'source-delta/actual-working/'+name in store.names else raw
  assert actual.replace(b'\r\n',b'\n')==raw and SHA(actual)==item['actual_working_sha256']
 assert custody['original_reader_executable_sha256']==original['executable_sha256']
 return dict(frontend=counts,original_reader_startups=4,external_transactions=4,source_custody='COMPLETE_FIVE_FILE_ACTUAL_GIT_AND_WORKING_DELTA')


def native_records(store,role,windows):
 profile=store.view(role['profile']);profile_q=json.loads((profile/'RESULT.json').read_text());projection=json.loads(store.get('COMPILED_PROJECTION_V1.json'))
 compiled=store.view(projection[profile_q['build_root']]['archive_prefix']);meta=json.loads((compiled/'BUILD.json').read_text());vapor=meta['identity']['hydraulic_vapor']
 prefix=(f"profiles/snow-vapor-{role['kind']}-{role['optimization']}-native-controls-v1" if windows else role['native_controls'])
 q=json.loads(store.get(prefix+'/RESULT.json'));assert q['status']=='ACTUAL_SNOW_VAPOR_NATIVE4_AND_LITERAL_SNOW_DOMAIN_STARTUP_REFUSALS_PASS_NOT_ADMITTED' and len(q['refusals'])==66
 assert q['accepted_model_days']==q['compiler_executions']==0 and q['positive_original_native_startup']
 assert not git('diff',RUNTIME,q['source'],'--',*SURFACES)
 assert SHA((compiled/'BUILD.json').read_bytes())==q['actual_BUILD_sha256']
 checkpoint=(profile/'trajectory/accepted-column-1-day-4.zip').read_bytes();assert SHA(checkpoint)==q['checkpoint_sha256']
 with zipfile.ZipFile(io.BytesIO(checkpoint)) as z:good=z.read('macro.bin')
 assert good[:8]==vapor['native_codec'].encode()
 values=[4,meta['project']['nodes'],vapor['numlay'],0,int(role['kind']=='cde'),0,0,1,0,0,1,2,1,6]+vapor['models']+[f if m>=8 else 0 for m,f in zip(vapor['models'],vapor['SWVAPOR'])]
 header=struct.pack('<'+str(len(values))+'i',*values);snow=[1,meta['project']['nodes'],0,int(role['kind']=='cde'),0,1,0,1,1,2];thermal=struct.pack('<10i',*snow)
 attacks={}
 for label,raw,fields in (('vapor',header,values),('snow',thermal,snow)):
  assert good.count(raw+raw)==1;offset=good.index(raw+raw)
  for witness in (False,True):
   for index,value in enumerate(fields):
    edits=[(offset+4*index,struct.pack('<i',value+1))]
    if not witness:edits.append((offset+len(raw)+4*index,struct.pack('<i',value+1)))
    bad=bytearray(good)
    for at,replacement in edits:bad[at:at+len(replacement)]=replacement
    attacks[label+('-witness-' if witness else '-domain-')+str(index)]=bytes(bad)
 for magic in (b'S5HVW003',b'S5HVC003',b'S5ITW001',b'S5ITC001',b'S5HSW003',b'S5HSC003'):attacks[magic.decode()]=magic+good[8:]
 for size in (0,48,48+2*len(header)-1,len(good)-1):attacks['truncated-'+str(size)]=good[:size]
 assert set(attacks)=={item['label'] for item in q['refusals']} and len(attacks)==66
 assert store.get(prefix+'/positive/origin/macro.bin')==good
 assert not store.get(prefix+'/positive/original/donor.stderr')
 stdout=store.get(prefix+'/positive/original/donor.stdout');assert b'HYBRID_READY' in stdout and b'HYBRID_DAY_RETURN' not in stdout
 for item in q['refusals']:
  root=prefix+'/'+item['label'];assert store.get(root+'/origin/macro.bin')==attacks[item['label']]
  stderr=store.get(root+'/original/donor.stderr').decode(errors='replace');stdout=store.get(root+'/original/donor.stdout')
  assert item['returncode']!=0 and stderr==item['diagnostic'] and b'HYBRID_READY' not in stdout and b'HYBRID_DAY_RETURN' not in stdout
 return dict(kind=role['kind'],optimization=role['optimization'],actual_compiled_refusals=66,original_good_checkpoint_unchanged=True,all_actual_mutant_native_bytes_independently_rebuilt=True,accepted_model_days=0)


def verify():
 guard_previous_source()
 paths=['HYDRAULIC_SNOW_VAPOR_QUALIFICATION.json',*[name+'.json' for name in RAW_NAMES]]
 for name in paths:
  path='integration/f-ci/nomacro-complete01/'+name;assert norm((ROOT/path).read_bytes())==blob(SEALED,path)
 qual=json.loads((PROOF/paths[0]).read_text());assert qual['runtime']==RUNTIME and qual['migration_class']=='B_EXISTING_UNCHANGED_PROCESS_COMPOSITION'
 for field in ('canonical_admission','whole_historical_family_closed','physical_process_equations_changed','new_physical_water_store','mass_or_convergence_limits_changed','RC3_changed'):assert qual[field] is False
 assert qual['native_interface_changed'] is True and qual['owning_absolute_water_and_CDE_limits']==1e-10
 actual=read(PROOF);controls=[]
 with ExitStack() as stack:
  for name in RAW_NAMES:
   store=Archive(PROOF,name,stack);assert store.record['sha256']==qual['raw_records'][name]['sha256']
   windows=name==RAW_NAMES[0]
   if windows:frontend=frontend_records(store)
   for role in store.record['roles']:
    if not windows or role['days']==1096:controls.append(native_records(store,role,windows))
  admission=Store(PROOF,'HYDRAULIC_DEFAULT_MODEL_GRAMMAR_ADMISSION_RAW_V1',stack)
  path='integration/f-ci/nomacro-complete01/HYDRAULIC_DEFAULT_MODEL_GRAMMAR_ADMISSION_RAW_V1.json';assert norm((ROOT/path).read_bytes())==blob(SEALED,path)
  record=json.loads((ROOT/path).read_text());assert record['canonical']=='49a0641cb836d044c14c7146761ccff480c2f262' and record['sha256']=='82a33caa6379897f0da647ee7f5a29bed91833520e09b9e1b90b0428f176f420'
  for name in admission.names:admission.get(name)
 assert len(controls)==8 and sum(v['actual_compiled_refusals'] for v in controls)==528
 with prior_source_projection():prior=literal('verify',prior_namespace())()
 assert prior['status']=='BOUNDED_ORIGINAL_DEFAULT_MODEL_INTEGER_GRAMMAR_SOURCE_RAW_NATIVE_PASS'
 return dict(status='BOUNDED_ORIGINAL_SNOW_ACTIVE_VAPOR_SOURCE_RAW_NATIVE_PASS',runtime=RUNTIME,targeted=actual,native_controls=controls,frontend_and_transactions=frontend,inherited_actual_default_signed_vapor_and_earlier_science=prior,compiler_executions=0,model_executions=0,canonical_admission='OWNED_BY_ACTUAL_MERGE_RECEIPT',functional_completion='PARTIAL',whole_scientific_equivalence='NOT_QUALIFIED',global_family_and_gap_counts='UNKNOWN',RC3_changed=False)


if __name__=='__main__':print(json.dumps(verify(),indent=2))
