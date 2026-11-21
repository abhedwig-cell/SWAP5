"""Preserve actual pressure/calendar runs, failures and build postimages once."""
import argparse,json,subprocess,zipfile
from pathlib import Path
from analytical_hydraulic_archives import SHA
from groundwater_snow_archive_storage import store_original
from initial_profile_calendar_source_inverse import BASE,FIRST_CORE,INTERVAL_CORE,CORE,CHANGED,complete_inverse
ROOT=Path(__file__).resolve().parents[2]


def main():
 p=argparse.ArgumentParser()
 for key in ('evidence','staging'):p.add_argument('--'+key,type=Path,required=True)
 a=p.parse_args();ev=a.evidence;proof=ROOT/'integration/f-ci/nomacro-complete01';complete_inverse();files={};projection={};roles=[];postimages=[];failed=[]
 def tree(path,prefix):
  assert path.is_dir() and not path.is_symlink()
  for item in sorted(path.rglob('*')):
   assert not item.is_symlink()
   if item.is_file():
    name=prefix+'/'+item.relative_to(path).as_posix();assert name not in files;files[name]=item
 def build(path):
  if str(path) not in projection:
   prefix='compiled/'+path.parent.name;tree(path,prefix)
   projection[str(path)]=dict(archive_prefix=prefix,actual_BUILD_sha256=SHA((path/'BUILD.json').read_bytes()))
 cohort=json.loads((ev/'INITIAL_PROFILE_CALENDAR_COMPLETED_COHORT_INDEPENDENT_V2.json').read_text());assert cohort['contexts']==24 and len(cohort['results'])==24
 expected={v['profile']:v['science'] for v in cohort['results']}
 for path in sorted(ev.iterdir()):
  if path.is_dir() and path.name.startswith('initial-profile-calendar-'):
   tree(path,'profiles/'+path.name)
   result=path/'RESULT.json'
   if not result.is_file():continue
   q=json.loads(result.read_text())
   if q.get('build',{}).get('returncode')==0 and 'build_root' in q:build(Path(q['build_root']))
   if q.get('status')=='ACTUAL_ORIGINAL_INITIAL_PROFILE_CALENDAR_WATER_CDE_EXACT_COLD_PASS_NOT_ADMITTED':
    assert q['days']==35 and len(q['cold'])==3 and path.name in expected
    roles.append(dict(profile='profiles/'+path.name,inputs='profiles/'+Path(q['input_root']).relative_to(ev).as_posix(),science=expected[path.name],kind=q['kind'],optimization=q['optimization'],native_codec=q['native_codec']))
   elif q.get('status')=='ACTUAL_COMPILED_INITIAL2_BASELINE_WITH_UNCHANGED_INITIAL1_CALENDAR_ABI_PASS_NO_MODEL_REPEAT':postimages.append('profiles/'+path.name)
   elif q.get('status')=='FAILED':failed.append('profiles/'+path.name)
  elif path.is_file() and path.name.lower().startswith(('initial_profile_calendar','initial-profile-calendar')):files['observations/'+path.name]=path
 assert len(roles)==24 and len(postimages)==10 and len(failed)==2
 extra={'COMPILED_PROJECTION_V1.json':(json.dumps(projection,indent=2)+'\n').encode()}
 for epoch in (FIRST_CORE,INTERVAL_CORE,CORE):
  for path in CHANGED:extra['source-history/'+epoch+'/'+path]=subprocess.check_output(['git','show',epoch+':'+path],cwd=ROOT)
 extra['SOURCE_CUSTODY_V1.json']=(json.dumps(dict(baseline=BASE,epochs=[FIRST_CORE,INTERVAL_CORE,CORE],original_provider_archive='HYDRAULIC_VAPOR_WINDOWS_WATER_RAW_V1',original_provider_sha256='804b6c36afe0bbac5a84dd84c289a864f3ef0874b739fb9dbc15539c17ad903a',new_native_codec=False,physical_equations_changed=False,original_receipts_rewritten=False),indent=2)+'\n').encode()
 members={name:dict(bytes=path.stat().st_size,sha256=SHA(path.read_bytes())) for name,path in files.items()};members.update({name:dict(bytes=len(raw),sha256=SHA(raw)) for name,raw in extra.items()})
 name='INITIAL_PROFILE_CALENDAR_WINDOWS_RAW_V1';archive=a.staging/(name+'.zip');assert a.staging.is_dir() and not any(a.staging.iterdir()) and not (proof/(name+'.json')).exists()
 with zipfile.ZipFile(archive,'x',compression=zipfile.ZIP_DEFLATED) as z:
  for key,path in sorted(files.items()):z.write(path,key)
  for key,raw in sorted(extra.items()):z.writestr(key,raw)
 with zipfile.ZipFile(archive) as z:
  assert len(z.namelist())==len(set(z.namelist()))==len(members)
  for key,item in members.items():
   raw=z.read(key);assert len(raw)==item['bytes'] and SHA(raw)==item['sha256']
 stored=store_original(archive,proof,archive.name)
 record=dict(status='ACTUAL_WINDOWS_INITIAL_PROFILE_CALENDAR_24_CONTEXTS_AND_10_COMPILED_POSTIMAGES_SEALED_NOT_ADMITTED',**stored,members=members,roles=roles,postimages=postimages,retained_failed_observations=failed,sealer_source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),short35_contexts=24,exact_cold_windows=72,native_calendar_samples=168,frontend_controls=55,compiler_postimages=10,canonical_admission=False)
 (proof/(name+'.json')).write_text(json.dumps(record,indent=2)+'\n');print(record['status'],record['bytes'],record['sha256'],len(members))


if __name__=='__main__':main()
