"""Preserve all native5 observations, actual source closures and original failures."""
import argparse,json,subprocess,zipfile
from pathlib import Path
from analytical_hydraulic_archives import SHA,Archive
from contextlib import ExitStack
from groundwater_snow_archive_storage import store_original
ROOT=Path(__file__).resolve().parents[2]
CORE='9cde60cff60e1a0b2d4a21019e69eefb1007bd8b'
BASE='70bae8871ec71b3c0969a6628cae596354f9c2e8'


def main():
 p=argparse.ArgumentParser()
 for key in ('evidence','staging'):p.add_argument('--'+key,type=Path,required=True)
 a=p.parse_args();ev=a.evidence;proof=ROOT/'integration/f-ci/nomacro-complete01';git=lambda *args:subprocess.check_output(['git',*args],cwd=ROOT)
 assert not git('diff',CORE,'HEAD','--','app','src','tools/solute','tools/vq','reference')
 local=json.loads((ev/'VAPOR_BOUNDARY_LOCAL_INDEPENDENT_V2.json').read_text());assert len(local['profiles'])==20 and local['status'].startswith('INDEPENDENT_FOUR_YEAR_SIXTEEN_SHORT_NATIVE5_ALL_FIVE')
 files={};projection={};roles=[]
 def tree(path,prefix):
  assert path.is_dir() and not path.is_symlink()
  for file in sorted(path.rglob('*')):
   assert not file.is_symlink()
   if file.is_file():
    name=prefix+'/'+file.relative_to(path).as_posix();assert name not in files;files[name]=file
 def build(path,label):
  prefix='compiled/'+label;tree(path,prefix)
  projection[str(path)]=dict(archive_prefix=prefix,actual_BUILD_sha256=SHA((path/'BUILD.json').read_bytes()) if (path/'BUILD.json').is_file() else None)
 for name in sorted(local['profiles']):
  path=ev/name;q=json.loads((path/'RESULT.json').read_text());assert q['status']=='ACTUAL_VAPOR_BOUNDARY_NATIVE5_WATER_CDE_ORIGINAL_OUTPUT_EXACT_COLD_PASS_NOT_ADMITTED';tree(path,'profiles/'+name);build(Path(q['build_root']),name)
  roles.append(dict(profile='profiles/'+name,inputs='profiles/'+Path(q['input_root']).relative_to(ev).as_posix(),days=q['days'],kind=q['kind'],optimization=q['optimization']))
 for label in ('undrained-water','undrained-cde','head5-water','unit8-cde'):
  name=f'vapor-boundary-{label}-O0-v1';path=ev/name;q=json.loads((path/'RESULT.json').read_text());assert q['status']=='FAILED' and 'Foreign complete pre-terminal model7 HeadCalc parent' in (path/'build.stderr').read_text() and not (path/'trajectory').exists();tree(path,'retained-failed/'+name);build(Path(q['build_root']),'retained-failed-'+name)
 for codec in ('native3','native4'):
  name=f'vapor-boundary-unselected-{codec}-O0-v1';path=ev/name;q=json.loads((path/'RESULT.json').read_text());assert q['model_executions']==0;tree(path,'profiles/'+name);build(Path(q['build_root']),name)
 assert json.loads((ev/'VAPOR_BOUNDARY_NATIVE4_UNSELECTED_POSTIMAGE_RECOVERED_V1.json').read_text())['status'].startswith('ACTUAL_OLD_NATIVE4_COMPILED_POSTIMAGE_EXACT_RECOVERED')
 for case in ('undrained-water11','head5-active-cde8-11','unit8-active-cde7-8'):
  for opt in ('O0','O2'):
   name=f'vapor-boundary-{case}-{opt}-controls-v1';q=json.loads((ev/name/'RESULT.json').read_text());assert len(q['refusals'])==49 and q['native_control_accepted_model_days']==0 and q['transactions'] and q['status']=='ACTUAL_VAPOR_BOUNDARY_NATIVE5_49_TYPED_REFUSALS_AND_EXTERNAL_DISCARD_REPLAY_RECOVERY_PASS';tree(ev/name,'profiles/'+name)
 for name in ('vapor-boundary-original-dispatch-v1','vapor-boundary-inputs-v1','vapor-boundary-cross-inputs-v1','vapor-boundary-frontend-v1'):tree(ev/name,'profiles/'+name)
 frontend=json.loads((ev/'vapor-boundary-frontend-v1/RESULT.json').read_text());assert len(frontend['checks'])==55 and frontend['status']=='ACTUAL_VAPOR_BOUNDARY_24_SELECTED_26_REFUSED_TWO_PRIOR_THREE_INACTIVE_CONTROLS_PASS'
 for path in sorted(ev.iterdir()):
  if path.is_file() and path.name.lower().startswith(('vapor_boundary','vapor-boundary')):files['observations/'+path.name]=path
 changed=git('diff','--name-only',BASE,CORE,'--','app','src','tools/solute','tools/vq','reference').decode().splitlines();assert changed==['app/hybrid_water/cde_native_receipt.py','app/hybrid_water/hydraulic_vapor.py','app/hybrid_water/model7_terminal_water.py','app/hybrid_water/original_output.py','app/hybrid_water/vapor_boundary_composition.py']
 extra={'COMPILED_PROJECTION_V1.json':(json.dumps(projection,indent=2)+'\n').encode()};custody={}
 for path in changed:
  raw=git('show',CORE+':'+path);actual=(ROOT/path).read_bytes();assert actual.replace(b'\r\n',b'\n')==raw;extra['source-delta/git/'+path]=raw
  if actual!=raw:extra['source-delta/actual-working/'+path]=actual
  custody[path]=dict(git_sha256=SHA(raw),actual_working_sha256=SHA(actual))
  extra['retained-failed-source-a286/'+path]=git('show','a286aaadb6212b4c7613d75a24a6b40f73d06b37:'+path)
 extra['SOURCE_CUSTODY_V1.json']=(json.dumps(dict(runtime=CORE,baseline=BASE,baseline_source_archive='HYDRAULIC_ANALYTICAL_CALENDAR_WINDOWS_RAW_V1',baseline_archive_sha256='7ea50f59d6977e528067906553a566762d2c9e0cd9405ce78fea9e4e2d468aca',complete_changed_source_inventory=changed,sources=custody,original_provider_archive='HYDRAULIC_VAPOR_WINDOWS_WATER_RAW_V1',old_native4_postimage_archive='HYDRAULIC_SNOW_VAPOR_WINDOWS_RAW_V1',retained_failed_precompiler_source='a286aaadb6212b4c7613d75a24a6b40f73d06b37',original_receipts_rewritten=False),indent=2)+'\n').encode()
 members={name:dict(bytes=path.stat().st_size,sha256=SHA(path.read_bytes())) for name,path in files.items()};members.update({name:dict(bytes=len(raw),sha256=SHA(raw)) for name,raw in extra.items()})
 name='HYDRAULIC_VAPOR_BOUNDARY_WINDOWS_RAW_V1';assert not (proof/(name+'.json')).exists();archive=a.staging/(name+'.zip');assert a.staging.is_dir() and not any(a.staging.iterdir())
 with zipfile.ZipFile(archive,'x',compression=zipfile.ZIP_DEFLATED) as z:
  for key,path in sorted(files.items()):z.write(path,key)
  for key,raw in sorted(extra.items()):z.writestr(key,raw)
 with zipfile.ZipFile(archive) as z:
  assert len(z.namelist())==len(set(z.namelist()))==len(members)
  for key,item in members.items():raw=z.read(key);assert len(raw)==item['bytes'] and SHA(raw)==item['sha256']
 stored=store_original(archive,proof,archive.name)
 record=dict(status='ACTUAL_WINDOWS_VAPOR_BOUNDARY_NATIVE5_RAW_SEALED_NOT_ADMITTED',**stored,members=members,roles=roles,runtime=CORE,sealer_source=git('rev-parse','HEAD').decode().strip(),actual_year367_contexts=4,actual_short35_contexts=16,actual_exact_cold_windows=68,actual_native_checkpoints=152,exact_private_CDE_stocks=104,compiled_native_refusals=294,external_transaction_contexts=6,frontend_controls=55,retained_failed_precompiler_builds=4,successful_actual_compiled_closures=22,unchanged_native3_and4_model_periods_repeated=0,canonical_admission=False)
 (proof/(name+'.json')).write_text(json.dumps(record,indent=2)+'\n')
 with ExitStack() as stack:
  central=Archive(proof,name,stack)
  for key in members:central.get(key)
 print(record['status'],record['bytes'],record['sha256'],len(members),len(record['parts']),flush=True)


if __name__=='__main__':main()
