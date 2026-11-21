"""Preserve exact Windows initial-profile science and every original refusal."""
import argparse,json,subprocess,zipfile
from pathlib import Path
from contextlib import ExitStack
from analytical_hydraulic_archives import SHA,Archive
from groundwater_snow_archive_storage import store_original
from initial_pressure_profile_source_inverse import CORE,BASE,PATH,SURFACES,complete_inverse
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
 def build(path,label):
  tree(path,'compiled/'+label);projection[str(path)]=dict(archive_prefix='compiled/'+label,actual_BUILD_sha256=SHA((path/'BUILD.json').read_bytes()))
 local=json.loads((ev/'INITIAL_PRESSURE_PROFILE_LOCAL_INDEPENDENT_V1.json').read_text());assert len(local['profiles'])==8
 for label,independent in local['profiles'].items():
  profile=ev/label;q=json.loads((profile/'RESULT.json').read_text());assert q['status']=='ACTUAL_ORIGINAL_INITIAL_PRESSURE_PROFILE_WATER_CDE_EXACT_COLD_PASS_NOT_ADMITTED' and q['days']==35 and len(q['cold'])==3
  assert independent==json.loads((ev/(label+'-INDEPENDENT.json')).read_text());tree(profile,'profiles/'+label);build(Path(q['build_root']),label);roles.append(dict(profile='profiles/'+label,inputs='profiles/'+Path(q['input_root']).relative_to(ev).as_posix(),independent='observations/'+label+'-INDEPENDENT.json',kind=q['kind'],optimization=q['optimization']))
 for label in ('initial-pressure-legacy-zih-water-O0-v1','initial-pressure-nonhydrostatic-water-O0-v1'):
  profile=ev/label;q=json.loads((profile/'RESULT.json').read_text());assert q['status']=='FAILED' and q['build']['returncode']==0 and 'Inconsistent variable type' in (profile/'trajectory/original/swap.err').read_text() and not list((profile/'trajectory').glob('accepted-*.zip'))
  assert 'HYBRID_READY' not in (profile/'trajectory/original/donor.stdout').read_text();tree(profile,'retained-failed/'+label);build(Path(q['build_root']),'retained-failed-'+label)
 for name in ('initial-pressure-profile-inputs-v1','initial-pressure-profile-inputs-v2','initial-pressure-profile-inputs-v3','initial-pressure-profile-inputs-v4','initial-pressure-profile-frontend-v1'):tree(ev/name,'profiles/'+name)
 frontend=json.loads((ev/'initial-pressure-profile-frontend-v1/RESULT.json').read_text());assert len(frontend['checks'])==35 and frontend['status']=='ACTUAL_FOUR_NEW_THREE_PRIOR_TWENTY_EIGHT_PROFILE_REFUSALS_PASS'
 for path in ev.iterdir():
  if path.is_file() and path.name.lower().startswith(('initial_pressure_profile','initial-pressure-')):files['observations/'+path.name]=path
 git=lambda *args:subprocess.check_output(['git',*args],cwd=ROOT)
 source=git('show',CORE+':'+PATH);actual=(ROOT/PATH).read_bytes();assert actual.replace(b'\r\n',b'\n')==source
 extra={'COMPILED_PROJECTION_V1.json':(json.dumps(projection,indent=2)+'\n').encode(),'source-delta/git/'+PATH:source,'source-delta/actual-working/'+PATH:actual}
 extra['SOURCE_CUSTODY_V1.json']=(json.dumps(dict(runtime=CORE,baseline=BASE,complete_changed_source_inventory=[PATH],original_provider_archive='HYDRAULIC_VAPOR_WINDOWS_WATER_RAW_V1',original_provider_sha256='804b6c36afe0bbac5a84dd84c289a864f3ef0874b739fb9dbc15539c17ad903a',original_initializer_and_equations_changed=False,frontend_observer_actual_source_sha256=SHA((ROOT/'tests/nomacro_drainage/initial_pressure_profile_frontend.py').read_bytes().replace(b'\r\n',b'\n')),frontend_observer_executed_before_commit_under_actual_reported_HEAD=True,actual_frontend_observer_source_retained_in_current_sealer_commit=True,original_receipts_rewritten=False),indent=2)+'\n').encode()
 members={name:dict(bytes=path.stat().st_size,sha256=SHA(path.read_bytes())) for name,path in files.items()};members.update({name:dict(bytes=len(raw),sha256=SHA(raw)) for name,raw in extra.items()})
 name='HYDRAULIC_INITIAL_PRESSURE_WINDOWS_RAW_V1';archive=a.staging/(name+'.zip');assert a.staging.is_dir() and not any(a.staging.iterdir()) and not (proof/(name+'.json')).exists()
 with zipfile.ZipFile(archive,'x',compression=zipfile.ZIP_DEFLATED) as z:
  for key,path in sorted(files.items()):z.write(path,key)
  for key,raw in sorted(extra.items()):z.writestr(key,raw)
 with zipfile.ZipFile(archive) as z:
  assert len(z.namelist())==len(set(z.namelist()))==len(members)
  for key,item in members.items():raw=z.read(key);assert len(raw)==item['bytes'] and SHA(raw)==item['sha256']
 stored=store_original(archive,proof,archive.name);record=dict(status='ACTUAL_WINDOWS_ORIGINAL_INITIAL_PRESSURE_PROFILE_RAW_SEALED_NOT_ADMITTED',**stored,members=members,roles=roles,runtime=CORE,sealer_source=git('rev-parse','HEAD').decode().strip(),short35_contexts=8,exact_cold_windows=24,native_checkpoints=56,private_CDE_stocks=28,frontend_controls=35,retained_actual_TTUTIL_refusals_before_READY=2,actual_successful_compiled_closures=8,compiled_closures_with_original_reader_refusal=2,full_periods_repeated=0,canonical_admission=False)
 (proof/(name+'.json')).write_text(json.dumps(record,indent=2)+'\n')
 with ExitStack() as stack:
  central=Archive(proof,name,stack)
  for key in members:central.get(key)
 print(record['status'],record['bytes'],record['sha256'],len(members))


if __name__=='__main__':main()
