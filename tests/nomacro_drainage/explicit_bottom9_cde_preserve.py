"""Preserve only new CDE9 evidence; prior46 archives remain immutable."""
import argparse,json
from pathlib import Path
from analytical_hydraulic_archives import SHA
from initial_profile_frost_preserve import seal
from explicit_bottom9_source_inverse import ROOT,CDE_CORE,complete_inverse,git


def windows(ev,staging):
 complete_inverse();files={};projection={};roles=[]
 def tree(path,prefix):
  assert path.is_dir() and not path.is_symlink()
  for file in sorted(path.rglob('*')):
   assert not file.is_symlink()
   if file.is_file():
    key=prefix+'/'+file.relative_to(path).as_posix();assert key not in files;files[key]=file
 def build(actual):
  if actual in projection:return
  path=Path(actual);prefix='compiled/'+path.parent.name+'/bundle';tree(path,prefix)
  projection[actual]=dict(archive_prefix=prefix,actual_BUILD_sha256=SHA((path/'BUILD.json').read_bytes()))
 for path in sorted(ev.iterdir()):
  if not path.name.lower().startswith(('explicit-bottom9-cde','explicit_bottom9_cde')):continue
  if path.is_dir():tree(path,'profiles/'+path.name)
  elif path.is_file():files['observations/'+path.name]=path
 batch=json.loads((ev/'EXPLICIT_BOTTOM9_CDE_WINDOWS_REMAINING9_V1.json').read_text());assert batch['status'].startswith('ACTUAL_REMAINING_NINE_') and len(batch['contexts'])==9
 first=ev/'explicit-bottom9-cde-subdaily-O0-v1'
 contexts=[dict(profile=str(first),postimage=str(first)+'-initial2-postimage',independent=str(ev/'EXPLICIT_BOTTOM9_CDE_SUBDAILY_O0_INDEPENDENT_V1.json'))]+batch['contexts']
 for item in contexts:
  primary=Path(item['profile']);post=Path(item['postimage']);q=json.loads((primary/'RESULT.json').read_text());p=json.loads((post/'RESULT.json').read_text());science=Path(item['independent']);obs=json.loads(science.read_text())
  assert obs['status']=='INDEPENDENT_EXPLICIT9_CDE_CALENDAR_DAILY_LEDGERS_PRIVATE_NATIVE_EOF_EXACT_COLD_WHOLE_COMPILED_PASS_NOT_ADMITTED' and obs['producer']==q['source'] and obs['case']==q['case'] and obs['optimization']==q['optimization']
  assert q['status']=='ACTUAL_EXPLICIT_PAIRED_HEAD_FLUX_PHYSICAL_NATIVE_EXACT_COLD_USER_OUTPUT_PASS_NOT_ADMITTED' and q['kind']=='cde'
  distributed=q['case']=='cde-distributed-subdaily';key='reference_profile' if distributed else 'initial1_profile';digest='reference_RESULT_sha256' if distributed else 'initial1_RESULT_sha256'
  assert p[key]==str(primary) and p[digest]==SHA((primary/'RESULT.json').read_bytes())
  build(q['build_root']);build(p['build_root'])
  roles.append(dict(profile='profiles/'+primary.name,postimage='profiles/'+post.name,inputs='profiles/'+Path(q['input_root']).relative_to(ev).as_posix(),counter_inputs='profiles/'+Path(p['input_root']).relative_to(ev).as_posix(),independent='observations/'+science.name,original_profile_path=str(primary),producer=q['source'],case=q['case'],optimization=q['optimization'],distributed=distributed))
 assert len(roles)==10 and len(projection)==20 and len({(i['case'],i['optimization']) for i in roles})==10
 proof=ROOT/'integration/f-ci/nomacro-complete01';names=['EXPLICIT_BOTTOM9_WINDOWS_RAW_V1']+['EXPLICIT_BOTTOM9_UBUNTU_'+o+'_RAW_V1' for o in ('O0','O2')]+['EXPLICIT_BOTTOM9_LAST_NODE_WINDOWS_RAW_V1']+['EXPLICIT_BOTTOM9_LAST_NODE_UBUNTU_'+o+'_RAW_V1' for o in ('O0','O2')]+['HYDRAULIC_VAPOR_WINDOWS_WATER_RAW_V1']
 links={}
 for name in names:
  q=json.loads((proof/(name+'.json')).read_text());links[name]=dict(bytes=q['bytes'],sha256=q['sha256'],members=len(q['members']))
 extra={key:(json.dumps(value,indent=2)+'\n').encode() for key,value in [('COMPILED_PROJECTION_V1.json',projection),('PARENT_CENTRAL_RAW_LINKS_V1.json',links)]};extra['actual-sealer.py']=Path(__file__).read_bytes()
 assert staging.is_dir() and not any(staging.iterdir());name='EXPLICIT_BOTTOM9_CDE_WINDOWS_RAW_V1'
 seal(staging/(name+'.zip'),name,files,extra,dict(status='ACTUAL_TEN_NEW_WINDOWS_CDE9_CALENDAR_RAW_SOURCE_NATIVE_COLD_COMPILED_AND_FRONTEND_PRESERVED_NOT_ADMITTED',roles=roles,composition_source=CDE_CORE,new_short35_contexts=10,new_native_checkpoints=70,new_exact_cold_windows=30,new_compiled_counterparts=10,prior46_archives_rewritten=False,prior46_model_periods_replayed=False,sealer_source=git('rev-parse','HEAD').decode().strip(),canonical_admission=False))


if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--evidence',type=Path,required=True);p.add_argument('--staging',type=Path,required=True);a=p.parse_args();windows(a.evidence,a.staging)
