"""Seal actual Windows history9 proofs, failed inputs and complete compiled bytes."""
import argparse,ast,hashlib,json,subprocess,sys
from pathlib import Path
ROOT=Path.cwd()
sys.path[:0]=[str(ROOT/'tests/nomacro_drainage'),str(ROOT/'tests/nomacro_scheduled_subsurface'),str(ROOT/'app/hybrid_water')]
from analytical_hydraulic_archives import SHA
from initial_profile_frost_preserve import seal
from explicit_bottom9_history_science import audit
from explicit_bottom9_source_inverse import git

CORE='cc33a863437ca3cf34cade7d6f2aba9c32729f22'


def committed_sources(epochs):
 # Reuse the literal existing source-object encoder. Only actual Git objects
 # are read; this is not a working-file, Git-status or HEAD projection.
 path='tests/nomacro_drainage/explicit_bottom9_snow_preserve.py';raw=git('show','4c9f1823c0f739e8f0fe09b4a244ddebcfecf74f:'+path)
 function=next(n for n in ast.parse(raw).body if isinstance(n,ast.FunctionDef) and n.name=='committed_sources')
 namespace=dict(ROOT=ROOT,git=git,subprocess=subprocess,hashlib=hashlib,json=json)
 exec(compile(ast.fix_missing_locations(ast.Module(body=[function],type_ignores=[])),path,'exec'),namespace)
 extra=namespace['committed_sources'](epochs);extra['actual-existing-committed-source-encoder.py']=raw
 return extra


def windows(ev,staging,reference):
 files={};projection={};diagnostics={};roles=[];current_results={};epochs={CORE,git('rev-parse','HEAD').decode().strip()}
 def tree(path,prefix):
  assert path.is_dir() and not path.is_symlink()
  for child in sorted(path.rglob('*')):
   assert not child.is_symlink()
   if child.is_file():
    key=prefix+'/'+child.relative_to(path).as_posix();assert key not in files;files[key]=child
 def build(actual):
  if actual in projection:return
  path=Path(actual);assert (path/'BUILD.json').is_file();assert path.parent.name.startswith('explicit-bottom9-history-')
  prefix='compiled/'+path.parent.name+'/bundle';tree(path,prefix);projection[actual]=dict(archive_prefix=prefix,actual_BUILD_sha256=SHA((path/'BUILD.json').read_bytes()))
 def observe(q):
  if not isinstance(q,dict):return
  for key in ('source','observer_source','actual_observer_source','actual_source','actual_batch_source','actual_compiler_producer'):
   value=q.get(key)
   if isinstance(value,str) and len(value)==40 and all(c in '0123456789abcdef' for c in value):epochs.add(value)
  if q.get('build_root') and (Path(q['build_root'])/'BUILD.json').is_file():build(q['build_root'])
  if q.get('diagnostic_executable_sha256') and q.get('allocation'):
   path=Path(q['allocation']['path']);prefix='diagnostic-compiled/'+path.name;tree(path,prefix);diagnostics[str(path)]=dict(archive_prefix=prefix,diagnostic_executable_sha256=q['diagnostic_executable_sha256'],scientific_admission=False)
 for path in sorted(ev.iterdir()):
  if not path.name.lower().startswith(('explicit-bottom9-history','explicit_bottom9_history')):continue
  if '_capacity_' in path.name.lower() or '_prior_own_registered_resource_sizes_' in path.name.lower():continue
  if path.is_dir():
   tree(path,'profiles/'+path.name)
   result=path/'RESULT.json'
   if result.is_file():observe(json.loads(result.read_text()))
  elif path.is_file():
   # Input archives are preserved once as their already sealed inputs, not as
   # nested duplicate ZIPs. Their exact manifests and original sealers remain.
   if path.suffix.lower()=='.zip' and 'inputs_raw' in path.name.lower():continue
   files['observations/'+path.name]=path
   if path.suffix.lower()=='.json':observe(json.loads(path.read_text()))
 primary_total=counter_total=native_total=0
 for name in ['EXPLICIT_BOTTOM9_HISTORY_WINDOWS_BATCH_V1.json','EXPLICIT_BOTTOM9_HISTORY_DRAINAGE_WINDOWS_BATCH_V3.json','EXPLICIT_BOTTOM9_HISTORY_DRAINAGE_CDE_INITIAL2_WINDOWS_BATCH_V1.json']:
  batch=json.loads((ev/name).read_text());assert batch['status'].endswith('PASS_NOT_ADMITTED')
  for entry in batch['profiles']:
   profile=Path(entry['profile']);q=json.loads((profile/'RESULT.json').read_text());assert q['status']=='ACTUAL_EXPLICIT9_HYSTERESIS_PHYSICAL_NATIVE_OUTPUT_PERIOD_PASS_NOT_ADMITTED'
   counter=Path(entry.get('initial2_postimage',entry.get('initial1_postimage','')));c=json.loads((counter/'RESULT.json').read_text());assert c['status'] in ('ACTUAL_HISTORY9_INITIAL2_WHOLE_GENERATED_AND_COMPILED_POSTIMAGE_PASS_NO_MODEL_REPLAY','ACTUAL_HISTORY9_INITIALIZATION_COUNTERPART_WHOLE_GENERATED_AND_COMPILED_POSTIMAGE_PASS_NO_MODEL_REPLAY')
   controls=Path(entry['native_controls']);nc=json.loads((controls/'RESULT.json').read_text());assert nc['status']=='ALL28_ACTUAL_COMPILED_HISTORY9_NATIVE_AND_IDENTICAL_PAYLOAD_INDEPENDENT_REFUSALS_PASS' and len(nc['refusals'])==28 and nc['accepted_model_days']==0
   assert q['build']['actual_completion_head']==q['source'] and c['build']['actual_completion_head']==c['source']
   actual=audit(profile,reference)
   inputs=Path(q['input_root']);text=(inputs/'swap.swp').read_text(encoding='cp1252');import re
   drainage=int(re.findall(r'(?mi)^[ \t]*SWDRA[ \t]*=[ \t]*([01])',text)[0]);initial=actual['initialization'];key=q['kind']+'-hys'+str(q['hysteresis'])+'-dra'+str(drainage)+'-'+q['optimization']
   build(q['build_root']);build(c['build_root']);primary_total+=1;counter_total+=1;native_total+=28
   roles.append(dict(kind=q['kind'],hysteresis=q['hysteresis'],drainage=drainage,optimization=q['optimization'],primary_initial=initial,counterpart_initial=3-initial,producer=q['source'],profile='profiles/'+profile.name,postimage='profiles/'+counter.name,native_controls='profiles/'+controls.name,inputs='profiles/'+inputs.relative_to(ev).as_posix(),counter_inputs='profiles/'+Path(c['input_root']).relative_to(ev).as_posix(),independent='current-independent/'+key+'.json',original_profile_path=str(profile)))
   assert key not in current_results;current_results[key]=actual
 assert primary_total==counter_total==16 and native_total==448 and len(roles)==16
 assert len({(x['kind'],x['hysteresis'],x['drainage'],x['optimization']) for x in roles})==16
 assert all(x['primary_initial']==(2 if x['kind']=='cde' and x['drainage']==1 else 1) for x in roles)
 extra=committed_sources(epochs)
 for role in roles:
  key=Path(role['independent']).stem;extra[role['independent']]=(json.dumps(current_results[key],indent=2)+'\n').encode()
 extra['COMPILED_PROJECTION_V1.json']=(json.dumps(projection,indent=2)+'\n').encode();extra['DIAGNOSTIC_COMPILED_PROJECTION_V1.json']=(json.dumps(diagnostics,indent=2)+'\n').encode();extra['actual-sealer.py']=Path(__file__).read_bytes()
 assert len(projection)==36 and len(diagnostics)==1,(len(projection),len(diagnostics))
 provider=json.loads((ROOT/'integration/f-ci/nomacro-complete01/HYDRAULIC_VAPOR_WINDOWS_WATER_RAW_V1.json').read_text());assert provider['sha256']=='804b6c36afe0bbac5a84dd84c289a864f3ef0874b739fb9dbc15539c17ad903a'
 seal(staging/'EXPLICIT_BOTTOM9_HISTORY_WINDOWS_RAW_V1.zip','EXPLICIT_BOTTOM9_HISTORY_WINDOWS_RAW_V1',files,extra,dict(status='ALL16_WINDOWS_HISTORY9_PERIODS_NATIVE112_COLD48_COMPILED16_NATIVE448_AND_FOUR_RETAINED_NUMERICAL_REFUSALS_CENTRAL_RAW_NOT_ADMITTED',roles=roles,composition_core=CORE,actual_source_epochs=sorted(epochs),original_provider_archive='HYDRAULIC_VAPOR_WINDOWS_WATER_RAW_V1',original_provider_archive_sha256=provider['sha256'],new_short35_contexts=16,new_native_checkpoints=112,new_exact_cold_windows=48,new_compiled_initialization_counterparts=16,actual_compiled_native_refusals=448,identical_payload_independent_refusals=448,actual_all_preserved_production_and_control_compiled_closures=len(projection),separate_unqualified_diagnostic_closures=len(diagnostics),source_or_data_identity_rewritten=False,prior_model_periods_replayed=False,initial1_saturated_distributed_CDE_startup_numerical_gap_remains_open=True,whole_historical_family_closed=False,canonical_admission=False))


if __name__=='__main__':
 p=argparse.ArgumentParser()
 for name in ('evidence','staging','reference'):p.add_argument('--'+name,type=Path,required=True)
 a=p.parse_args();windows(a.evidence,a.staging,a.reference)
