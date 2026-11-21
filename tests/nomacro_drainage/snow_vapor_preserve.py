"""Seal actual Windows Snow-vapor science and retain original failed attempts."""
import argparse,hashlib,json,subprocess,zipfile
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
CORE='6e77aeb829a45e1f1781a429f60e632ecaa316ea'
BASE='8e27dd9eb0f633050d2d82d00d28992435c313cb'
SHA=lambda raw:hashlib.sha256(raw).hexdigest()


def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--evidence',type=Path,required=True);a=p.parse_args();ev=a.evidence;proof=ROOT/'integration/f-ci/nomacro-complete01'
 git=lambda *args:subprocess.check_output(['git',*args],cwd=ROOT)
 assert not git('diff',CORE,'HEAD','--','app','src','tools/solute','tools/vq','reference')
 local=json.loads((ev/'SNOW_VAPOR_LOCAL_INDEPENDENT_V1.json').read_text());assert local['status']=='INDEPENDENT_FOUR_FULL_TWELVE_SHORT_SNOW_VAPOR_64_COLD_140_NATIVE_70_CDE_STOCK_POSTIMAGES_PASS'
 batch=json.loads((ev/'SNOW_VAPOR_TARGETED_BATCH_V1.json').read_text());assert batch['status']=='TWELVE_TARGETED_SNOW_VAPOR_35DAY_CONTEXTS_PASS_NOT_ADMITTED'
 files={};compiled={};roles=[]
 def add_tree(path,prefix):
  assert path.is_dir() and not path.is_symlink()
  for file in sorted(path.rglob('*')):
   assert not file.is_symlink()
   if file.is_file():
    name=prefix+'/'+file.relative_to(path).as_posix();assert name not in files;files[name]=file
 profiles=[ev/f'snow-vapor-{kind}-{opt}-v3' for kind in ('water','cde') for opt in ('O0','O2')]
 profiles+=sorted(p.parent for p in ev.glob('snow-vapor-*-short-v1/RESULT.json'));assert len(profiles)==16
 for profile in profiles:
  q=json.loads((profile/'RESULT.json').read_text());assert q['status']=='ACTUAL_SNOW_VAPOR_WATER_CDE_POSTIMAGE_SHORT_OR_FULL_EXACT_COLD_PASS_NOT_ADMITTED' and len(q['cold'])==(7 if q['days']==1096 else 3)
  add_tree(profile,'profiles/'+profile.name);build=Path(q['build_root']);prefix='compiled/'+profile.name;add_tree(build,prefix)
  compiled[q['build_root']]=dict(archive_prefix=prefix,actual_BUILD_sha256=SHA((build/'BUILD.json').read_bytes()))
  roles.append(dict(profile='profiles/'+profile.name,days=q['days'],kind=q['kind'],optimization=q['optimization'],models=q['layer_models'],flags=q['vapor_flags']))
  for suffix in ('.stdout.txt','.stderr.txt'):files['observations/'+profile.name+suffix]=ev/(profile.name+suffix)
 for kind,opt in (('water','O0'),('cde','O2')):
  for version in (1,2):
   profile=ev/f'snow-vapor-{kind}-{opt}-v{version}';q=json.loads((profile/'RESULT.json').read_text());assert q['status']=='FAILED'
   if version==1:assert q['error']=="ValueError('Unselected model7 terminal source')" and not (profile/'trajectory').exists()
   else:assert q['error']=="TimeoutError('Model wall cap 240s')" and len((profile/'trajectory/daily.jsonl').read_text().splitlines())==1
   add_tree(profile,'retained-failed/'+profile.name);build=Path(q['build_root']);prefix='compiled-retained-failed/'+profile.name;add_tree(build,prefix)
   compiled[q['build_root']]=dict(archive_prefix=prefix,actual_BUILD_sha256=SHA((build/'BUILD.json').read_bytes()),role='ORIGINAL_FAILED_NOT_PERIOD_PASS')
   for suffix in ('.stdout.txt','.stderr.txt'):files['observations/'+profile.name+suffix]=ev/(profile.name+suffix)
 for kind in ('water','cde'):
  for opt in ('O0','O2'):
   folder=ev/f'snow-vapor-{kind}-{opt}-native-controls-v1';q=json.loads((folder/'RESULT.json').read_text());assert q['status']=='ACTUAL_SNOW_VAPOR_NATIVE4_AND_LITERAL_SNOW_DOMAIN_STARTUP_REFUSALS_PASS_NOT_ADMITTED' and len(q['refusals'])==66 and q['positive_original_native_startup']
   add_tree(folder,'profiles/'+folder.name)
 for name in ('snow-vapor-frontend-controls-v1','snow-vapor-frontend-controls-v2','snow-vapor-transactions-v1','original-snow-vapor-reader-v1'):add_tree(ev/name,'profiles/'+name)
 assert json.loads((ev/'snow-vapor-frontend-controls-v2/RESULT.json').read_text())['status']=='ACTUAL_SNOW_VAPOR_72_DISPATCH_BOUNDS_AND_PRIOR_CODEC_CONTROLS_PASS'
 assert json.loads((ev/'snow-vapor-transactions-v1/RESULT.json').read_text())['status']=='FOUR_ACTUAL_SNOW_VAPOR_EXTERNAL_DISCARD_REPLAY_ACCEPT_RECOVERY_CONTEXTS_PASS'
 original=json.loads((ev/'original-snow-vapor-reader-v1/RESULT.json').read_text());assert original['status']=='FOUR_ORIGINAL_SNOW_ACTIVE_VAPOR_CONFIGURATIONS_READER_ACCEPTED_ZERO_MODEL_DAYS'
 inherited=json.loads((proof/'HYDRAULIC_VAPOR_WINDOWS_CDE_RAW_V1.json').read_text());matches=[name for name,item in inherited['members'].items() if item['sha256']==original['executable_sha256']];assert len(matches)==1
 for name in ('SNOW_VAPOR_LOCAL_INDEPENDENT_V1.json','SNOW_VAPOR_LOCAL_INDEPENDENT_V1.stdout.txt','SNOW_VAPOR_LOCAL_INDEPENDENT_V1.stderr.txt','SNOW_VAPOR_TARGETED_BATCH_V1.json','SNOW_VAPOR_INITIAL_WATER_O0_INDEPENDENT_V1.json','snow_vapor_local_science_v1.py','original_snow_vapor_reader_v1.py','snow_vapor_targeted_batch_v1.stdout.txt','snow_vapor_targeted_batch_v1.stderr.txt'):files['observations/'+name]=ev/name
 changed=git('diff','--name-only',BASE,CORE,'--','app','src','tools/solute','tools/vq','reference').decode().splitlines()
 assert changed==['app/hybrid_water/cde_native_receipt.py','app/hybrid_water/daily_host.py','app/hybrid_water/hydraulic_vapor.py','app/hybrid_water/original_output_thermal.py','app/hybrid_water/snow_vapor_composition.py']
 assert not git('diff','a5038b98597e9ff83364aa454b7250387c3716be',BASE,'--','app','src','tools/solute','tools/vq','reference')
 extra={};custody={}
 for name in changed:
  raw=git('show',CORE+':'+name);actual=(ROOT/name).read_bytes();assert actual.replace(b'\r\n',b'\n')==raw
  extra['source-delta/git/'+name]=raw
  if actual!=raw:extra['source-delta/actual-working/'+name]=actual
  custody[name]=dict(git_sha256=SHA(raw),actual_working_sha256=SHA(actual),actual_bytes=len(actual),git_bytes=len(raw))
 extra['COMPILED_PROJECTION_V1.json']=(json.dumps(compiled,indent=2)+'\n').encode()
 extra['SOURCE_CUSTODY_V1.json']=(json.dumps(dict(runtime=CORE,baseline=BASE,baseline_source_archive='HYDRAULIC_DEFAULT_MODEL_GRAMMAR_WINDOWS_RAW_V1',baseline_archive_sha256='37547bbeb5696de11dba78915e47e05a02428e0f1975ee76ff06d9be045f861e',complete_changed_source_inventory=changed,sources=custody,original_reader_archive='HYDRAULIC_VAPOR_WINDOWS_CDE_RAW_V1',original_reader_member=matches[0],original_reader_executable_sha256=original['executable_sha256']),indent=2)+'\n').encode()
 members={name:dict(bytes=path.stat().st_size,sha256=SHA(path.read_bytes())) for name,path in files.items()};members.update({name:dict(bytes=len(raw),sha256=SHA(raw)) for name,raw in extra.items()})
 archive=proof/'HYDRAULIC_SNOW_VAPOR_WINDOWS_RAW_V1.zip';assert not archive.exists() and not archive.with_suffix('.json').exists()
 with zipfile.ZipFile(archive,'x',compression=zipfile.ZIP_DEFLATED) as z:
  for name,path in sorted(files.items()):z.write(path,name)
  for name,raw in sorted(extra.items()):z.writestr(name,raw)
 with zipfile.ZipFile(archive) as z:
  assert len(z.namelist())==len(set(z.namelist()))==len(members)
  for name,item in members.items():raw=z.read(name);assert len(raw)==item['bytes'] and SHA(raw)==item['sha256']
 digest=SHA(archive.read_bytes());record=dict(status='ACTUAL_WINDOWS_SNOW_VAPOR_RAW_SEALED_NOT_ADMITTED',runtime=CORE,sealer_source=git('rev-parse','HEAD').decode().strip(),archive=archive.name,bytes=archive.stat().st_size,sha256=digest,members=members,parts=[dict(file=archive.name,bytes=archive.stat().st_size,sha256=digest)],roles=roles,actual_full1096_contexts=4,actual_short35_contexts=12,actual_exact_cold_windows=64,actual_native_checkpoints=140,exact_private_CDE_stocks=70,compiled_native_refusals=264,external_transaction_contexts=4,frontend_controls=72,original_reader_startups=4,accepted_original_reader_model_days=0,retained_failed_compilations_and_partial_periods=4,canonical_admission=False)
 archive.with_suffix('.json').write_text(json.dumps(record,indent=2)+'\n');print(record['status'],record['bytes'],digest,len(members))


if __name__=='__main__':main()
