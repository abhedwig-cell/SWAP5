"""Preserve this one coherent nonlinear existing-process composition batch."""
import argparse,json
from pathlib import Path
from analytical_hydraulic_archives import SHA
from initial_profile_frost_preserve import seal
from explicit_bottom9_analytical_source_inverse import ROOT,ANALYTICAL_CORE,complete_inverse,git

def windows(ev,staging):
 complete_inverse();files={};projection={};roles=[];component_builds={}
 def tree(path,prefix):
  assert path.is_dir() and not path.is_symlink()
  for item in sorted(path.rglob('*')):
   assert not item.is_symlink()
   if item.is_file():
    key=prefix+'/'+item.relative_to(path).as_posix();assert key not in files;files[key]=item
 def build(actual):
  if actual in projection:return
  path=Path(actual);prefix='compiled/'+path.parent.name+'/bundle';tree(path,prefix);projection[actual]=dict(archive_prefix=prefix,actual_BUILD_sha256=SHA((path/'BUILD.json').read_bytes()))
 batch=json.loads((ev/'EXPLICIT_BOTTOM9_ANALYTICAL_WINDOWS_BATCH_V2.json').read_text());assert batch['status']=='ALL12_REPRESENTATIVE_NONLINEAR_PAIRED9_WINDOWS_CONTEXTS_INDEPENDENT_PASS_NOT_ADMITTED' and len(batch['contexts'])==12
 for path in sorted(ev.iterdir()):
  if not path.name.lower().startswith(('explicit-bottom9-analytical','explicit_bottom9_analytical')):continue
  if path.is_dir():
   tree(path,'profiles/'+path.name)
   result=path/'RESULT.json'
   if result.is_file():
    q=json.loads(result.read_text())
    if 'build_root' in q and (Path(q['build_root'])/'BUILD.json').is_file():build(q['build_root'])
    if 'component' in q:
     actual=q['component']['build_root']
     if actual not in component_builds:
      prefix='components/'+Path(actual).name;tree(Path(actual),prefix);component_builds[actual]=prefix
  elif path.is_file():files['observations/'+path.name]=path
 for item in batch['contexts']:
  profile=Path(item['profile']);post=Path(item['postimage']);science=Path(item['independent']);q=json.loads((profile/'RESULT.json').read_text());p=json.loads((post/'RESULT.json').read_text());s=json.loads(science.read_text());assert 'PASS_NOT_ADMITTED' in s['status'] and s['producer']==q['source'] and s['optimization']==q['optimization'] and s['case']==q['case']
  assert p['initial1_profile']==str(profile) and p['initial1_RESULT_sha256']==SHA((profile/'RESULT.json').read_bytes());build(q['build_root']);build(p['build_root']);samples=None;component=None
  if s['actual_original_pressure_samples'] is not None:
   candidates=[]
   for child in ev.iterdir():
    result=child/'RESULT.json'
    if not child.is_dir() or not child.name.startswith('explicit-bottom9-analytical') or not result.is_file():continue
    value=json.loads(result.read_text())
    if value.get('profile')==str(profile) and value.get('daily_sha256')==SHA((profile/'trajectory/daily.jsonl').read_bytes()) and value.get('stdout_sha256')==s['actual_original_pressure_samples']['raw_stdout_sha256']:candidates.append(child)
   assert len(candidates)==1;samples='profiles/'+candidates[0].name;sample=json.loads((candidates[0]/'RESULT.json').read_text());component='profiles/'+Path(sample['component_profile']).name
  roles.append(dict(profile='profiles/'+profile.name,postimage='profiles/'+post.name,independent='observations/'+science.name,inputs='profiles/'+Path(q['input_root']).relative_to(ev).as_posix(),counter_inputs='profiles/'+Path(p['input_root']).relative_to(ev).as_posix(),reference_samples=samples,reference_component=component,original_profile_path=str(profile),producer=q['source'],model=item['model'],kind=item['kind'],case=q['case'],optimization=q['optimization']))
 assert len({(r['model'],r['kind'],r['optimization']) for r in roles})==12
 extra={'COMPILED_PROJECTION_V1.json':(json.dumps(projection,indent=2)+'\n').encode(),'REFERENCE_COMPONENT_BUILD_PROJECTION_V1.json':(json.dumps(component_builds,indent=2)+'\n').encode(),'actual-sealer.py':Path(__file__).read_bytes()}
 assert staging.is_dir() and not any(staging.iterdir());name='EXPLICIT_BOTTOM9_ANALYTICAL_WINDOWS_RAW_V1'
 seal(staging/(name+'.zip'),name,files,extra,dict(status='ACTUAL_TWELVE_REPRESENTATIVE_WINDOWS_NONLINEAR_PAIRED9_ORIGINAL_SAMPLED_REFERENCE_NATIVE_COLD_ALL_COMPILED_AND_FAILURES_PRESERVED_NOT_ADMITTED',roles=roles,composition_source=ANALYTICAL_CORE,new_short35_contexts=12,new_native_checkpoints=84,new_exact_cold_windows=36,new_initial2_compiled_counterparts=12,prior216_model_periods_replayed=False,observer_repair_repeated_model_periods=0,sealer_source=git('rev-parse','HEAD').decode().strip(),canonical_admission=False))

if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--evidence',type=Path,required=True);p.add_argument('--staging',type=Path,required=True);a=p.parse_args();windows(a.evidence,a.staging)
