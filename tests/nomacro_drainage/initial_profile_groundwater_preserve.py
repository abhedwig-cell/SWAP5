"""Preserve actual pressure/groundwater outputs and complete compiled counterparts once."""
import argparse,json,subprocess,zipfile
from pathlib import Path
from analytical_hydraulic_archives import SHA
from groundwater_snow_archive_storage import store_original
from initial_profile_frost_preserve import seal
from initial_profile_groundwater_source_inverse import ROOT,BASE,CORE,ADAPTER,SELECTOR,complete_inverse

POST='ACTUAL_ORIGINAL_PRESSURE_GROUNDWATER_INITIAL2_WHOLE_COMPILED_POSTIMAGE_NATIVE_ABI_PASS_NO_MODEL_REPLAY'
SCI='INDEPENDENT_ORIGINAL_PRESSURE_GROUNDWATER_HEADS_FIXED_LEDGERS_LITERAL_NATIVE_EXACT_COLD_PASS'
PORTABLE='67cbd7028d8d63aebe2a6166b6b04cf884f21a65'
ARTIFACTS={'O0':(14730143868,19373453,'eacaf8d901157f5c27b73eed5a322ff9002f3bbbf91337333d448226dd86432f'),'O2':(14730467570,19494394,'d14a7bd50c7aa37152be9462926264566fecfc2f8ff0d827a4f88728bc7fd798')}


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
 cohort=json.loads((ev/'INITIAL_PROFILE_GROUNDWATER_WINDOWS_INDEPENDENT_COHORT_V1.json').read_text());assert len(cohort['profiles'])==40
 for path in sorted(ev.iterdir()):
  if path.is_dir() and path.name.startswith('initial-profile-groundwater-'):
   tree(path,'profiles/'+path.name)
   result=path/'RESULT.json'
   if not result.is_file():continue
   q=json.loads(result.read_text())
   if q.get('build',{}).get('returncode')==0 and 'build_root' in q:build(Path(q['build_root']))
   if path.name in cohort['profiles']:
    science=cohort['profiles'][path.name]['science'];assert science['status']==SCI and len(q['cold'])==3
    roles.append(dict(profile='profiles/'+path.name,inputs='profiles/'+Path(q['input_root']).relative_to(ev).as_posix(),science=science,activity=cohort['profiles'][path.name]['activity'],case=q['case'],optimization=q['optimization']))
   elif q.get('status')==POST:postimages.append('profiles/'+path.name)
  elif path.is_file() and path.name.lower().startswith(('initial_profile_groundwater','initial-profile-groundwater')):files['observations/'+path.name]=path
 assert len(roles)==len(postimages)==40 and len(projection)==80
 extra={'COMPILED_PROJECTION_V1.json':(json.dumps(projection,indent=2)+'\n').encode()}
 epochs=sorted({json.loads((ev/Path(role['profile']).name/'RESULT.json').read_text())['source'] for role in roles})
 for epoch in [BASE,CORE,*epochs]:
  for path in (ADAPTER,SELECTOR):
   if epoch==BASE and path==SELECTOR:continue
   extra['source-history/'+epoch+'/'+path]=subprocess.check_output(['git','show',epoch+':'+path],cwd=ROOT)
 extra['SOURCE_CUSTODY_V1.json']=(json.dumps(dict(baseline=BASE,core=CORE,actual_runtime_producers=epochs,original_provider_archive='HYDRAULIC_VAPOR_WINDOWS_WATER_RAW_V1',original_provider_sha256='804b6c36afe0bbac5a84dd84c289a864f3ef0874b739fb9dbc15539c17ad903a',physical_equations_changed=False,new_native_codec=False,original_receipts_rewritten=False),indent=2)+'\n').encode()
 name='INITIAL_PROFILE_GROUNDWATER_WINDOWS_RAW_V1';assert staging.is_dir() and not any(staging.iterdir())
 seal(staging/(name+'.zip'),name,files,extra,dict(status='ACTUAL_WINDOWS_ORIGINAL_PRESSURE_GROUNDWATER_RAW_AND_COMPILED_POSTIMAGES_SEALED_NOT_ADMITTED',roles=roles,postimages=postimages,short35_contexts=40,exact_cold_windows=120,native_checkpoints=280,compiler_postimages=40,frontend_controls=146,sealer_source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),canonical_admission=False))


def ubuntu(ev,opt):
 artifact,size,digest=ARTIFACTS[opt];original=ev/('GITHUB_ARTIFACT_'+str(artifact)+'_ORIGINAL_V1.zip');assert original.stat().st_size==size and SHA(original.read_bytes())==digest
 proof=ROOT/'integration/f-ci/nomacro-complete01';name='INITIAL_PROFILE_GROUNDWATER_UBUNTU_'+opt+'_RAW_V1';assert not (proof/(name+'.json')).exists();members={};roles=[];postimages=[]
 with zipfile.ZipFile(original) as z:
  names=z.namelist();assert len(names)==len(set(names)) and json.loads(z.read('source/RESULT.json'))['producer_head']==PORTABLE
  workflow=subprocess.check_output(['git','show',PORTABLE+':.github/workflows/nomacro-water-snow-groundwater.yml'],cwd=ROOT);assert z.read('actual-workflow.yml')==workflow
  import hashlib
  assert z.read('actual-workflow-git-blob.txt').decode().strip()==hashlib.sha1(b'blob '+str(len(workflow)).encode()+b'\0'+workflow).hexdigest()
  for case in ('water-h2-implicit-clock','cde-h1-snow-step','age-h2-monthly'):
   label='initial-profile-groundwater-'+case+'-'+opt+'-short';q=json.loads(z.read(label+'/RESULT.json'));science=json.loads(z.read(label+'-INDEPENDENT.json'))
   assert q['source']==PORTABLE and q['optimization']==opt and q['days']==35 and len(q['cold'])==3 and science['status']==SCI
   roles.append(dict(profile=label,inputs='inputs/'+case+'-initial1',science=science,activity=json.loads(z.read(label+'-ACTIVE.json')),case=case,optimization=opt))
   post=label+'-initial2-postimage';assert json.loads(z.read(post+'/RESULT.json'))['status']==POST;postimages.append(post)
  for key in names:raw=z.read(key);members[key]=dict(bytes=len(raw),sha256=SHA(raw))
 stored=store_original(original,proof,name+'.zip');record=dict(status='ACTUAL_TARGETED_UBUNTU_ORIGINAL_PRESSURE_GROUNDWATER_RAW_PRESERVED_NOT_ADMITTED',**stored,members=members,roles=roles,postimages=postimages,actual_producer=PORTABLE,actual_workflow_run=44963167155,actual_artifact=artifact,optimization=opt,short35_contexts=3,exact_cold_windows=9,native_checkpoints=21,compiler_postimages=3,canonical_admission=False)
 (proof/(name+'.json')).write_text(json.dumps(record,indent=2)+'\n');print(name,size,digest,len(members))


if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--evidence',type=Path,required=True);p.add_argument('--staging',type=Path);p.add_argument('--optimization',choices=('O0','O2'));a=p.parse_args()
 if a.optimization:ubuntu(a.evidence,a.optimization)
 else:windows(a.evidence,a.staging)
