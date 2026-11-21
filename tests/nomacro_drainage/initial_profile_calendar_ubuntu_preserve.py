"""Inventory exact original portable artifacts without rerunning model periods."""
import argparse,json,subprocess,zipfile
from pathlib import Path
from analytical_hydraulic_archives import SHA
from groundwater_snow_archive_storage import store_original
ROOT=Path(__file__).resolve().parents[2]


def preserve(original,optimization,source,artifact,run,cases,name,size,digest):
 proof=ROOT/'integration/f-ci/nomacro-complete01';assert original.stat().st_size==size and SHA(original.read_bytes())==digest
 assert not (proof/(name+'.json')).exists();members={};roles=[];postimages=[]
 with zipfile.ZipFile(original) as z:
  names=z.namelist();assert len(names)==len(set(names)) and json.loads(z.read('source/RESULT.json'))['producer_head']==source
  workflow=subprocess.check_output(['git','show',source+':.github/workflows/nomacro-water-snow-groundwater.yml'],cwd=ROOT);assert z.read('actual-workflow.yml')==workflow
  import hashlib
  assert z.read('actual-workflow-git-blob.txt').decode().strip()==hashlib.sha1(b'blob '+str(len(workflow)).encode()+b'\0'+workflow).hexdigest()
  projection=json.loads(z.read('COMPILED_PROJECTION_V1.json'))
  for case in cases:
   label='initial-profile-calendar-'+case+'-'+optimization+'-short';q=json.loads(z.read(label+'/RESULT.json'));science=json.loads(z.read(label+'-INDEPENDENT.json'))
   assert q['source']==source and q['optimization']==optimization and q['days']==35 and len(q['cold'])==3
   assert q['status']=='ACTUAL_ORIGINAL_INITIAL_PROFILE_CALENDAR_WATER_CDE_EXACT_COLD_PASS_NOT_ADMITTED' and science['status']=='INDEPENDENT_ORIGINAL_INITIAL_PROFILE_CALENDAR_HEADS_FIXED_MASS_PRIVATE_STATE_EXACT_COLD_PASS'
   assert science['exact_initial_pressure_nodes']==34 and len(science['native_calendar_samples'])==7 and science['exact_private_CDE_samples']==(7 if q['kind']=='cde' else 0)
   item=projection[q['build_root']];assert SHA(z.read(item['archive_prefix']+'/BUILD.json'))==item['actual_BUILD_sha256']
   roles.append(dict(profile=label,inputs='inputs/'+case,science=science,kind=q['kind'],optimization=optimization,native_codec=q['native_codec']))
   post=label+'-initial2-postimage'
   if post+'/RESULT.json' in names:
    observation=json.loads(z.read(post+'/RESULT.json'));assert observation['status']=='ACTUAL_COMPILED_INITIAL2_BASELINE_WITH_UNCHANGED_INITIAL1_CALENDAR_ABI_PASS_NO_MODEL_REPEAT';postimages.append(post)
  for key in names:
   raw=z.read(key);members[key]=dict(bytes=len(raw),sha256=SHA(raw))
 stored=store_original(original,proof,name+'.zip')
 record=dict(status='ACTUAL_TARGETED_UBUNTU_INITIAL_PROFILE_CALENDAR_ORIGINAL_RAW_PRESERVED_NOT_ADMITTED',**stored,members=members,roles=roles,postimages=postimages,actual_workflow_run=run,actual_artifact=artifact,actual_producer=source,optimization=optimization,short35_contexts=len(cases),exact_cold_windows=3*len(cases),native_calendar_samples=7*len(cases),original_receipts_rewritten=False,canonical_admission=False)
 (proof/(name+'.json')).write_text(json.dumps(record,indent=2)+'\n');print(name,len(members),size,digest)


if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--evidence',type=Path,required=True);p.add_argument('--optimization',choices=('O0','O2'),required=True);a=p.parse_args()
 specs={'O0':(14717626410,18086788,'392acb320eb6738d78e3578ffc6f62e34ed61dee27a8fc9ee0ade81f08e08860'),'O2':(14717042966,18163071,'13ecc28bfbc94dfb63dd4dd0a77e16da4f7698d4f4f9dc073155ae9257bb0225')}
 artifact,size,digest=specs[a.optimization]
 preserve(a.evidence/('GITHUB_ARTIFACT_'+str(artifact)+'_ORIGINAL_V1.zip'),a.optimization,'5ffc03cda0f50922fd44d41519b7c85e4df1aec0',artifact,44930126230,('vapor-dra0-clock8-cde','hys2-periodic-cde','implicit-snow-clock-cde','plain-periodic-water'),'INITIAL_PROFILE_CALENDAR_UBUNTU_'+a.optimization+'_RAW_V1',size,digest)
