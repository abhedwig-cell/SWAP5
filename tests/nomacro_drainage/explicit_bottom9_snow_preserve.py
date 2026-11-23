"""Seal actual Windows Snow9 raw, all compiled closures and committed source once."""
import argparse,hashlib,json,subprocess,sys
from pathlib import Path
from analytical_hydraulic_archives import SHA
from initial_profile_frost_preserve import seal
from explicit_bottom9_snow_source_inverse import ROOT,CORE,complete_inverse,git

ROLES=(('water','O0','explicit-bottom9-snow-water-O0-v2-model-observe-v2'),('cde','O0','explicit-bottom9-snow-cde-O0-v1'),('water','O2','explicit-bottom9-snow-water-O2-v1'),('cde','O2','explicit-bottom9-snow-cde-O2-v1'))


def committed_sources(epochs):
 scopes=('app','src','tools/solute','tools/vq','tests/nomacro_drainage','tests/nomacro_scheduled_subsurface','.github/workflows','reference/swap-4.3.1/projects','reference/swap-4.3.1/source-archives','reference/swap-4.3.1/patches','reference/swap-4.3.1/frost-corrections','reference/swap-4.3.1/hydraulic-corrections')
 index={};objects=set();extra={}
 for head in sorted(epochs):
  rows={}
  for line in git('ls-tree','-r',head,'--',*scopes).decode().splitlines():
   meta,path=line.split('\t');mode,kind,blob=meta.split();assert kind=='blob';rows[path]=dict(git_blob=blob,mode=mode);objects.add(blob)
  index[head]=rows
 process=subprocess.Popen(['git','cat-file','--batch'],cwd=ROOT,stdin=subprocess.PIPE,stdout=subprocess.PIPE)
 try:
  for digest in sorted(objects):
   process.stdin.write((digest+'\n').encode());process.stdin.flush();header=process.stdout.readline().decode().split();assert header[:2]==[digest,'blob'];size=int(header[2]);raw=process.stdout.read(size);assert len(raw)==size and process.stdout.read(1)==b'\n' and hashlib.sha1(b'blob '+str(size).encode()+b'\0'+raw).hexdigest()==digest
   extra['committed-source/blobs/'+digest]=raw
 finally:process.stdin.close();assert process.wait(timeout=30)==0
 extra['COMMITTED_SOURCE_INDEX_V1.json']=(json.dumps(dict(status='EXACT_IMMUTABLE_COMMITTED_ACTUAL_COMPILER_AND_OBSERVER_SOURCE_BLOBS_SEALED_ONCE_PER_BLOB',scope=scopes,epochs=index,working_source_capture_claimed=False,actual_generated_Fortran_and_BUILD_identities_preserved_separately=True),indent=2)+'\n').encode()
 return extra


def windows(ev,staging):
 complete_inverse();files={};projection={};roles=[];epochs={CORE,git('rev-parse','HEAD').decode().strip()}
 def tree(path,prefix):
  assert path.is_dir() and not path.is_symlink()
  for child in sorted(path.rglob('*')):
   assert not child.is_symlink()
   if child.is_file():
    key=prefix+'/'+child.relative_to(path).as_posix();assert key not in files;files[key]=child
 def build(actual):
  if actual in projection:return
  path=Path(actual);assert (path/'BUILD.json').is_file();prefix='compiled/'+path.parent.name+'/bundle';tree(path,prefix);projection[actual]=dict(archive_prefix=prefix,actual_BUILD_sha256=SHA((path/'BUILD.json').read_bytes()))
 # Preserve complete successful/failed observers and actual scientific controls.
 for path in sorted(ev.iterdir()):
  if not path.name.lower().startswith(('explicit-bottom9-snow','explicit_bottom9_snow')):continue
  if path.is_dir():
   tree(path,'profiles/'+path.name)
   for result_name in ('RESULT.json','BUILD_OBSERVE.json'):
    result=path/result_name
    if not result.is_file():continue
    q=json.loads(result.read_text())
    if isinstance(q.get('source'),str) and len(q['source'])==40:epochs.add(q['source'])
    if q.get('observer_source'):epochs.add(q['observer_source'])
    if q.get('build_root') and (Path(q['build_root'])/'BUILD.json').is_file():build(q['build_root'])
  elif path.is_file():files['observations/'+path.name]=path
 for kind,opt,name in ROLES:
  profile=ev/name;post=ev/('explicit-bottom9-snow-'+kind+'-'+opt+'-initial2-postimage-v2');q=json.loads((profile/'RESULT.json').read_text());p=json.loads((post/'RESULT.json').read_text());science=ev/('EXPLICIT_BOTTOM9_SNOW_'+kind.upper()+'_'+opt+'_INDEPENDENT_V1.json');s=json.loads(science.read_text())
  assert q['status']=='ACTUAL_EXPLICIT9_SNOW_PHYSICAL_NATIVE_OUTPUT_PERIOD_PASS_NOT_ADMITTED' and s['producer']==q['source'] and s['actual_days']==35
  assert p['actual_compiler_start_HEAD']==p['actual_compiler_end_HEAD']==p['source'] and p['profile']==str(profile) and p['profile_RESULT_sha256']==SHA((profile/'RESULT.json').read_bytes())
  build(q['build_root']);build(p['build_root']);roles.append(dict(kind=kind,optimization=opt,producer=q['source'],observer=q.get('observer_source'),profile='profiles/'+name,postimage='profiles/'+post.name,inputs='profiles/'+Path(q['input_root']).relative_to(ev).as_posix(),counter_inputs='profiles/'+Path(p['input_root']).relative_to(ev).as_posix(),independent='observations/'+science.name,original_profile_path=str(profile)))
 assert len(roles)==4 and len(projection)==12
 extra=committed_sources(epochs);extra['COMPILED_PROJECTION_V1.json']=(json.dumps(projection,indent=2)+'\n').encode();extra['actual-sealer.py']=Path(__file__).read_bytes()
 provider=json.loads((ROOT/'integration/f-ci/nomacro-complete01/HYDRAULIC_VAPOR_WINDOWS_WATER_RAW_V1.json').read_text())
 assert provider['sha256']=='804b6c36afe0bbac5a84dd84c289a864f3ef0874b739fb9dbc15539c17ad903a'
 seal(staging/'EXPLICIT_BOTTOM9_SNOW_WINDOWS_RAW_V1.zip','EXPLICIT_BOTTOM9_SNOW_WINDOWS_RAW_V1',files,extra,dict(status='ALL_FOUR_ACTUAL_WINDOWS_ACTIVE_SNOW9_PERIODS_TWELVE_COMPILED_CLOSURES_SOURCE_EPOCHS_AND_FAILURES_PRESERVED_NOT_ADMITTED',roles=roles,composition_core=CORE,actual_source_epochs=sorted(epochs),original_provider_archive='HYDRAULIC_VAPOR_WINDOWS_WATER_RAW_V1',original_provider_archive_sha256=provider['sha256'],intermediate_counterpart_source_fields_are_observer_completion_heads_not_relabelled=True,final_counterparts_have_actual_equal_start_end_HEAD=True,new_short35_contexts=4,new_native_checkpoints=28,new_exact_cold_windows=12,new_initial2_compiled_counterparts=4,actual_all_preserved_compiled_closures=12,prior_model_periods_replayed=False,canonical_admission=False))


if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--evidence',type=Path,required=True);p.add_argument('--staging',type=Path,required=True);a=p.parse_args();windows(a.evidence,a.staging)
