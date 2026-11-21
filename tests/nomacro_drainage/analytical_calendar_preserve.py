"""Preserve actual clock postimages once, including original monthly evidence."""
import argparse,hashlib,json,subprocess,zipfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
CORE='102e95eb6d33107b81ab06576707fe0be9b215e2'
BASE='bd9426711347a1bd7694d39e5c65345db0e25406'
SHA=lambda raw:hashlib.sha256(raw).hexdigest()


def main():
 p=argparse.ArgumentParser();p.add_argument('--evidence',type=Path,required=True);a=p.parse_args();ev=a.evidence;proof=ROOT/'integration/f-ci/nomacro-complete01'
 git=lambda *args:subprocess.check_output(['git',*args],cwd=ROOT)
 assert not git('diff',CORE,'HEAD','--','app','src','tools/solute','tools/vq','reference')
 local=json.loads((ev/'ANALYTICAL_CALENDAR_LOCAL_INDEPENDENT_V1.json').read_text());assert len(local['profiles'])==16 and local['status'].startswith('INDEPENDENT_FIVE_YEAR_NINE_SHORT_TWO_DENSITY')
 files={};compiled={};roles=[]
 def tree(path,prefix):
  assert path.is_dir() and not path.is_symlink()
  for file in sorted(path.rglob('*')):
   assert not file.is_symlink()
   if file.is_file():
    name=prefix+'/'+file.relative_to(path).as_posix();assert name not in files;files[name]=file
 def build(path,label):
  if str(path) in compiled:return
  tree(path,'compiled/'+label)
  if (path/'BUILD.json').is_file():compiled[str(path)]=dict(archive_prefix='compiled/'+label,actual_BUILD_sha256=SHA((path/'BUILD.json').read_bytes()))
 for name in sorted(local['profiles']):
  old=name=='original-monthly-vapor8-O2-source208';folder='vapor-monthly-current-postimage-v1' if old else name
  profile=ev/folder;q=json.loads((profile/'RESULT.json').read_text());tree(profile,'profiles/'+folder);build(Path(q['build_root']),folder)
  assert old or q['status'].startswith('ACTUAL_ORIGINAL_ANALYTICAL_WATER_OUTPUT_CLOCK')
  roles.append(dict(profile='profiles/'+folder,observation=name,original_monthly=old,days=q['days'],optimization=q['optimization']))
 assert sum(r['original_monthly'] for r in roles)==1
 name='analytical-calendar-vapor8-monthly-O2-postimage-v1';q=json.loads((ev/name/'RESULT.json').read_text());tree(ev/name,'profiles/'+name);build(Path(q['build_root']),name)
 assert q['model_executions']==0
 inheritance=json.loads((ev/'ANALYTICAL_MONTHLY_EXACT_POSTIMAGE_INHERITANCE_V1.json').read_text());assert inheritance['status'].startswith('ACTUAL_MONTHLY_NEW_COMPILED_POSTIMAGE_EXACT')
 for case in ('nprint2','perstep'):
  for opt in ('O0','O2'):
   name=f'analytical-calendar-vapor8-{case}-{opt}-controls-v1';q=json.loads((ev/name/'RESULT.json').read_text());assert q['status'].startswith('ACTUAL_ANALYTICAL_OUTPUT_24_NATIVE_REFUSALS') and len(q['native_refusals'])==24 and q['transactions'];tree(ev/name,'profiles/'+name)
 for name in ('analytical-calendar-frontend-v1','vapor-calendar-dispatch-assessment-v1','vapor-calendar-build-assessment-v1'):tree(ev/name,'profiles/'+name)
 assert json.loads((ev/'analytical-calendar-frontend-v1/RESULT.json').read_text())['status']=='ACTUAL_ANALYTICAL_OUTPUT_SEVEN_POSITIVE_EIGHT_BOUNDARY_REFUSALS_PASS'
 # Keep both actual old probe build roots, including the original refused
 # subdaily attempt. Their original RESULT and diagnostics stay unchanged.
 assessment=json.loads((ev/'vapor-calendar-build-assessment-v1/RESULT.json').read_text())
 for q in assessment['cases']:
  path=Path(q['build_root']);build(path,'original-probe-'+path.parent.name)
 for path in sorted(ev.iterdir()):
  if path.is_file() and path.name.lower().startswith(('analytical_calendar','analytical_monthly','analytical-calendar','vapor_calendar','vapor_monthly','vapor-monthly')):files['observations/'+path.name]=path
 changed=git('diff','--name-only',BASE,CORE,'--','app','src','tools/solute','tools/vq','reference').decode().splitlines();assert changed==['app/hybrid_water/model7_terminal_water.py']
 extra={'COMPILED_PROJECTION_V1.json':(json.dumps(compiled,indent=2)+'\n').encode()}
 for path in changed:
  raw=git('show',CORE+':'+path);working=(ROOT/path).read_bytes();assert working.replace(b'\r\n',b'\n')==raw;extra['source-delta/git/'+path]=raw
  if working!=raw:extra['source-delta/actual-working/'+path]=working
 extra['SOURCE_CUSTODY_V1.json']=(json.dumps(dict(runtime=CORE,baseline=BASE,baseline_source_archive='HYDRAULIC_SNOW_VAPOR_WINDOWS_RAW_V1',baseline_archive_sha256='5819dd2a62b50c519a7160cbb92f38e29408f33ee1098704b22e436f62e554ac',complete_changed_source_inventory=changed,original_monthly_producer='208c25624268589b5f26cbc10f2113aca4276ae6',original_provider_archive='HYDRAULIC_VAPOR_WINDOWS_WATER_RAW_V1',original_receipts_rewritten=False),indent=2)+'\n').encode()
 members={name:dict(bytes=path.stat().st_size,sha256=SHA(path.read_bytes())) for name,path in files.items()};members.update({name:dict(bytes=len(raw),sha256=SHA(raw)) for name,raw in extra.items()})
 archive=proof/'HYDRAULIC_ANALYTICAL_CALENDAR_WINDOWS_RAW_V1.zip';assert not archive.exists() and not archive.with_suffix('.json').exists()
 with zipfile.ZipFile(archive,'x',compression=zipfile.ZIP_DEFLATED) as z:
  for name,path in sorted(files.items()):z.write(path,name)
  for name,raw in sorted(extra.items()):z.writestr(name,raw)
 with zipfile.ZipFile(archive) as z:
  assert len(z.namelist())==len(set(z.namelist()))==len(members)
  for name,item in members.items():raw=z.read(name);assert len(raw)==item['bytes'] and SHA(raw)==item['sha256']
 digest=SHA(archive.read_bytes());size=archive.stat().st_size
 record=dict(status='ACTUAL_WINDOWS_ANALYTICAL_CALENDAR_RAW_SEALED_NOT_ADMITTED',runtime=CORE,sealer_source=git('rev-parse','HEAD').decode().strip(),archive=archive.name,bytes=size,sha256=digest,members=members,parts=[dict(file=archive.name,bytes=size,sha256=digest)],roles=roles,actual_year367_contexts=5,actual_short35_contexts=9,actual_density2day_contexts=2,actual_exact_cold_windows=53,actual_native_checkpoints=115,compiled_native_refusals=96,external_transaction_contexts=4,frontend_controls=15,model_periods_repeated_for_metadata=0,canonical_admission=False)
 archive.with_suffix('.json').write_text(json.dumps(record,indent=2)+'\n');print(record['status'],size,digest,len(members))


if __name__=='__main__':main()
