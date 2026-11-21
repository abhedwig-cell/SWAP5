"""Preserve actual calendar compositions and failed controllers once centrally."""
import argparse,json,subprocess,zipfile
from pathlib import Path
from analytical_hydraulic_archives import SHA
from groundwater_snow_archive_storage import store_original
from analytical_cde_calendar_source_inverse import CORE,BASE,CHANGED,complete_inverse
ROOT=Path(__file__).resolve().parents[2]


def main():
 p=argparse.ArgumentParser()
 for key in ('evidence','staging'):p.add_argument('--'+key,type=Path,required=True)
 a=p.parse_args();ev=a.evidence;proof=ROOT/'integration/f-ci/nomacro-complete01';complete_inverse();files={};projection={};roles=[]
 def tree(path,prefix):
  assert path.is_dir() and not path.is_symlink()
  for item in sorted(path.rglob('*')):
   assert not item.is_symlink()
   if item.is_file():name=prefix+'/'+item.relative_to(path).as_posix();assert name not in files;files[name]=item
 cohort=json.loads((ev/'ANALYTICAL_CDE_CALENDAR_COMPLETE_WINDOWS_INDEPENDENT_V2.json').read_text())
 assert cohort['status']=='THIRTY_WINDOWS_ANALYTICAL_CDE_CALENDAR_COMPOSITIONS_INDEPENDENT_PASS' and len(cohort['profiles'])==30 and cohort['cold_windows']==94 and cohort['native_samples']==216
 for label,item in cohort['profiles'].items():
  profile=Path(item['profile']);q=json.loads((profile/'RESULT.json').read_text());assert q['status']=='ACTUAL_ORIGINAL_ANALYTICAL_CDE_CALENDAR_FIXED_MASS_NATIVE_EXACT_COLD_PASS_NOT_ADMITTED'
  assert item['observation']==json.loads(Path(item['independent']).read_text())
  build=Path(q['build_root']);tree(build,'compiled/'+label);projection[str(build)]=dict(archive_prefix='compiled/'+label,actual_BUILD_sha256=SHA((build/'BUILD.json').read_bytes()))
  roles.append(dict(profile='profiles/'+label,inputs='profiles/'+Path(q['input_root']).relative_to(ev).as_posix(),independent='observations/'+Path(item['independent']).name,kind='cde',optimization=q['optimization'],days=q['days']))
 # Include all unique input versions, exact native attacks/transactions,
 # partial/failed controller probes, and both initial and final raw receipts.
 for path in sorted(ev.iterdir()):
  if path.is_dir() and path.name.startswith('analytical-cde-calendar-'):tree(path,'profiles/'+path.name)
  elif path.is_file() and path.name.lower().startswith(('analytical_cde_calendar','analytical-cde-calendar')):files['observations/'+path.name]=path
 extra={'COMPILED_PROJECTION_V1.json':(json.dumps(projection,indent=2)+'\n').encode()}
 for path in CHANGED:
  extra['source-current/'+path]=(ROOT/path).read_bytes()
  if CHANGED[path] is not None:extra['source-parent/'+path]=subprocess.check_output(['git','show',BASE+':'+path],cwd=ROOT)
 extra['SOURCE_CUSTODY_V1.json']=(json.dumps(dict(runtime=CORE,baseline=BASE,original_provider_archive='HYDRAULIC_VAPOR_WINDOWS_WATER_RAW_V1',original_provider_sha256='804b6c36afe0bbac5a84dd84c289a864f3ef0874b739fb9dbc15539c17ad903a',all_physical_equations_unchanged=True,original_receipts_rewritten=False,new_native_codec='S5HCC006'),indent=2)+'\n').encode()
 members={name:dict(bytes=path.stat().st_size,sha256=SHA(path.read_bytes())) for name,path in files.items()};members.update({name:dict(bytes=len(raw),sha256=SHA(raw)) for name,raw in extra.items()})
 name='ANALYTICAL_CDE_CALENDAR_WINDOWS_RAW_V1';archive=a.staging/(name+'.zip');assert a.staging.is_dir() and not any(a.staging.iterdir()) and not (proof/(name+'.json')).exists()
 with zipfile.ZipFile(archive,'x',compression=zipfile.ZIP_DEFLATED) as z:
  for key,path in sorted(files.items()):z.write(path,key)
  for key,raw in sorted(extra.items()):z.writestr(key,raw)
 with zipfile.ZipFile(archive) as z:
  assert len(z.namelist())==len(set(z.namelist()))==len(members)
  for key,item in members.items():raw=z.read(key);assert len(raw)==item['bytes'] and SHA(raw)==item['sha256']
 stored=store_original(archive,proof,archive.name)
 record=dict(status='ACTUAL_WINDOWS_ANALYTICAL_VAPOR_CDE_CALENDARS_ALL_RAW_SEALED_NOT_ADMITTED',**stored,members=members,roles=roles,runtime=CORE,sealer_source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),short35_contexts=28,year367_contexts=2,exact_cold_windows=94,native_checkpoints=216,actual_compiled_native6_refusals=208,actual_compiled_parent_calendar_private_refusals=188,frontend_controls=39,external_transaction_contexts=4,canonical_admission=False)
 (proof/(name+'.json')).write_text(json.dumps(record,indent=2)+'\n');print(record['status'],record['bytes'],record['sha256'],len(members))


if __name__=='__main__':main()
