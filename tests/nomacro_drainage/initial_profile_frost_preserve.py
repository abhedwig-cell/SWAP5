"""Preserve original pressure/Frost raw and build bytes without model repetition."""
import argparse,hashlib,json,subprocess,zipfile
from pathlib import Path
from analytical_hydraulic_archives import SHA
from groundwater_snow_archive_storage import store_original
from initial_profile_frost_source_inverse import ROOT,BASE,CORE,ADAPTER,SELECTOR,complete_inverse


def seal(archive,name,files,extra,metadata):
 proof=ROOT/'integration/f-ci/nomacro-complete01';assert not (proof/(name+'.json')).exists()
 members={key:dict(bytes=path.stat().st_size,sha256=SHA(path.read_bytes())) for key,path in files.items()}
 members.update({key:dict(bytes=len(raw),sha256=SHA(raw)) for key,raw in extra.items()})
 with zipfile.ZipFile(archive,'x',compression=zipfile.ZIP_DEFLATED) as z:
  for key,path in sorted(files.items()):z.write(path,key)
  for key,raw in sorted(extra.items()):z.writestr(key,raw)
 with zipfile.ZipFile(archive) as z:
  assert len(z.namelist())==len(set(z.namelist()))==len(members)
  for key,item in members.items():raw=z.read(key);assert len(raw)==item['bytes'] and SHA(raw)==item['sha256']
 stored=store_original(archive,proof,name+'.zip');record=dict(**stored,members=members,**metadata)
 (proof/(name+'.json')).write_text(json.dumps(record,indent=2)+'\n');print(name,record['bytes'],record['sha256'],len(members))


def windows(ev,staging):
 complete_inverse();files={};projection={};roles=[];postimages=[]
 def tree(path,prefix):
  assert path.is_dir() and not path.is_symlink()
  for item in sorted(path.rglob('*')):
   assert not item.is_symlink()
   if item.is_file():
    key=prefix+'/'+item.relative_to(path).as_posix();assert key not in files;files[key]=item
 def build(path):
  if str(path) not in projection:
   prefix='compiled/'+path.parent.name;tree(path,prefix);projection[str(path)]=dict(archive_prefix=prefix,actual_BUILD_sha256=SHA((path/'BUILD.json').read_bytes()))
 cohort=json.loads((ev/'INITIAL_PROFILE_FROST_WINDOWS_INDEPENDENT_COHORT_V1.json').read_text());assert len(cohort['profiles'])==8
 for path in sorted(ev.iterdir()):
  if path.is_dir() and path.name.startswith('initial-profile-frost-'):
   tree(path,'profiles/'+path.name)
   result=path/'RESULT.json'
   if not result.is_file():continue
   q=json.loads(result.read_text())
   if q.get('build',{}).get('returncode')==0 and 'build_root' in q:build(Path(q['build_root']))
   if path.name in cohort['profiles']:
    assert 'PASS_NOT_ADMITTED' in q['status'] and q['phase']=='short' and len(q['own'])==3
    roles.append(dict(profile='profiles/'+path.name,inputs='profiles/'+Path(q['input_root']).relative_to(ev).as_posix(),science=cohort['profiles'][path.name]['science'],kind=q['kind'],optimization=q['optimization']))
   elif q.get('status')=='ACTUAL_ORIGINAL_PRESSURE_FROST_INITIAL2_WHOLE_COMPILED_POSTIMAGE_AND_NATIVE_ABI_PASS_NO_MODEL_REPLAY':postimages.append('profiles/'+path.name)
  elif path.is_file() and path.name.lower().startswith(('initial_profile_frost','initial-profile-frost')):files['observations/'+path.name]=path
 assert len(roles)==len(postimages)==8 and len(projection)==16
 extra={'COMPILED_PROJECTION_V1.json':(json.dumps(projection,indent=2)+'\n').encode()}
 epochs=sorted({json.loads((ev/Path(role['profile']).name/'RESULT.json').read_text())['source'] for role in roles})
 for epoch in [BASE,CORE,*epochs]:
  for path in (ADAPTER,SELECTOR):
   if epoch==BASE and path==SELECTOR:continue
   extra['source-history/'+epoch+'/'+path]=subprocess.check_output(['git','show',epoch+':'+path],cwd=ROOT)
 extra['SOURCE_CUSTODY_V1.json']=(json.dumps(dict(baseline=BASE,core=CORE,actual_runtime_producers=epochs,original_provider_archive='HYDRAULIC_VAPOR_WINDOWS_WATER_RAW_V1',original_provider_sha256='804b6c36afe0bbac5a84dd84c289a864f3ef0874b739fb9dbc15539c17ad903a',physical_equations_changed=False,new_native_codec=False,original_receipts_rewritten=False),indent=2)+'\n').encode()
 name='INITIAL_PROFILE_FROST_WINDOWS_RAW_V1';assert staging.is_dir() and not any(staging.iterdir())
 seal(staging/(name+'.zip'),name,files,extra,dict(status='ACTUAL_WINDOWS_ORIGINAL_PRESSURE_FROST_RAW_AND_COMPILED_POSTIMAGES_SEALED_NOT_ADMITTED',roles=roles,postimages=postimages,short35_contexts=8,exact_cold_windows=24,native_checkpoints=56,compiler_postimages=8,frontend_controls=66,sealer_source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),canonical_admission=False))


def ubuntu(ev,opt):
 specs={'O0':(14722282305,15320699,'b7bce7aae6ebfe0e61caaaffe79980f762c09ff83ea15800bdeec07811080817'),'O2':(14722562216,15377311,'33004e459bba477374b19bc02c0b553ce13a253e44b69f4555c16db20f028ec4')}
 artifact,size,digest=specs[opt];source='a755331a7444395d932f22b634520b64077e1a6d';original=ev/('GITHUB_ARTIFACT_'+str(artifact)+'_ORIGINAL_V1.zip');assert original.stat().st_size==size and SHA(original.read_bytes())==digest
 proof=ROOT/'integration/f-ci/nomacro-complete01';name='INITIAL_PROFILE_FROST_UBUNTU_'+opt+'_RAW_V1';assert not (proof/(name+'.json')).exists();members={};roles=[];postimages=[]
 with zipfile.ZipFile(original) as z:
  names=z.namelist();assert len(names)==len(set(names)) and json.loads(z.read('source/RESULT.json'))['producer_head']==source
  workflow=subprocess.check_output(['git','show',source+':.github/workflows/nomacro-water-snow-groundwater.yml'],cwd=ROOT);assert z.read('actual-workflow.yml')==workflow
  assert z.read('actual-workflow-git-blob.txt').decode().strip()==hashlib.sha1(b'blob '+str(len(workflow)).encode()+b'\0'+workflow).hexdigest()
  for case in ('explicit-water','implicit-cde'):
   label='initial-profile-frost-'+case+'-'+opt+'-short';q=json.loads(z.read(label+'/RESULT.json'));science=json.loads(z.read(label+'-INDEPENDENT.json'))
   assert q['source']==source and q['optimization']==opt and q['phase']=='short' and len(q['own'])==3 and 'PASS_NOT_ADMITTED' in q['status']
   assert science['status']=='INDEPENDENT_ORIGINAL_PRESSURE_FROST_FIXED_LIMITS_SATURATED_HEADS_HISTORY_NATIVE_EXACT_COLD_PASS'
   roles.append(dict(profile=label,inputs='inputs/'+case+'-initial1',science=science,kind=q['kind'],optimization=opt))
   post=label+'-initial2-postimage';assert json.loads(z.read(post+'/RESULT.json'))['status']=='ACTUAL_ORIGINAL_PRESSURE_FROST_INITIAL2_WHOLE_COMPILED_POSTIMAGE_AND_NATIVE_ABI_PASS_NO_MODEL_REPLAY';postimages.append(post)
  for key in names:raw=z.read(key);members[key]=dict(bytes=len(raw),sha256=SHA(raw))
 stored=store_original(original,proof,name+'.zip');record=dict(status='ACTUAL_TARGETED_UBUNTU_ORIGINAL_PRESSURE_FROST_RAW_PRESERVED_NOT_ADMITTED',**stored,members=members,roles=roles,postimages=postimages,actual_producer=source,actual_workflow_run=44943177377,actual_artifact=artifact,optimization=opt,short35_contexts=2,exact_cold_windows=6,native_checkpoints=14,compiler_postimages=2,canonical_admission=False)
 (proof/(name+'.json')).write_text(json.dumps(record,indent=2)+'\n');print(name,size,digest,len(members))


if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--evidence',type=Path,required=True);p.add_argument('--staging',type=Path);p.add_argument('--optimization',choices=('O0','O2'));a=p.parse_args()
 if a.optimization:ubuntu(a.evidence,a.optimization)
 else:windows(a.evidence,a.staging)
