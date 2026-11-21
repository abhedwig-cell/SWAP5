"""Inventory unchanged original portable artifacts and real compiled refusals."""
import argparse,json,subprocess,zipfile
from pathlib import Path
from analytical_hydraulic_archives import SHA
ROOT=Path(__file__).resolve().parents[2]
SOURCE='31c32def70aa66861ca03f518bc0bb3d8d8973c4'
EXPECTED={'O0':(14710532568,19532728,'387044c382acb5690494a3d73a31f40019f50a4c6ba8fc975cb8952ef2fb88b9'),'O2':(14710960536,19592256,'da0f5fabbfc4871452dd48f69ac1d44099e47ed0cc29fe64bcbc6b3acd0e730a')}
CASES=('hys2-cde','implicit-cde','snow-vapor-water','implicit-snow-cde')


def main():
 p=argparse.ArgumentParser();p.add_argument('--optimization',choices=EXPECTED,required=True);a=p.parse_args();artifact,size,digest=EXPECTED[a.optimization]
 path=ROOT/'integration/f-ci/nomacro-complete01'/('INITIAL_STATE_COMPOSITION_UBUNTU_'+a.optimization+'_RAW_V1.zip');assert path.stat().st_size==size and SHA(path.read_bytes())==digest and not path.with_suffix('.json').exists();members={};roles=[]
 with zipfile.ZipFile(path) as z:
  names=z.namelist();assert len(names)==len(set(names));assert json.loads(z.read('source/RESULT.json'))['producer_head']==SOURCE
  workflow=subprocess.check_output(['git','show',SOURCE+':.github/workflows/nomacro-water-snow-groundwater.yml'],cwd=ROOT);assert z.read('actual-workflow.yml')==workflow
  import hashlib
  assert z.read('actual-workflow-git-blob.txt').decode().strip()==hashlib.sha1(b'blob '+str(len(workflow)).encode()+b'\0'+workflow).hexdigest()
  projection=json.loads(z.read('COMPILED_PROJECTION_V1.json'))
  for case in CASES:
   label='initial-state-'+case+'-'+a.optimization+'-short';q=json.loads(z.read(label+'/RESULT.json'));independent=json.loads(z.read(label+'-INDEPENDENT.json'));assert q['source']==SOURCE and q['optimization']==a.optimization and q['days']==35 and q['initial_selector']==1 and len(q['cold'])==3
   assert q['status']=='ACTUAL_ORIGINAL_INITIAL_STATE_COMPOSITION_WATER_CDE_EXACT_COLD_PASS_NOT_ADMITTED' and independent['status']=='INDEPENDENT_ORIGINAL_INITIAL_STATE_COMPOSITION_PRESSURE_FIXED_MASS_NATIVE_HISTORY_EXACT_COLD_PASS'
   assert independent['cold_windows']==3 and independent['native_checkpoints']==7 and independent['exact_initial_pressure_nodes']==34 and independent['exact_private_CDE_stocks']==(7 if q['kind']=='cde' else 0)
   item=projection[q['build_root']];assert SHA(z.read(item['archive_prefix']+'/BUILD.json'))==item['actual_BUILD_sha256'];role=dict(profile=label,inputs='inputs/'+case,independent=label+'-INDEPENDENT.json',kind=q['kind'],optimization=a.optimization)
   if case=='implicit-snow-cde':
    role['native_controls']=label+'-native-controls';control=json.loads(z.read(role['native_controls']+'/RESULT.json'));assert control['status']=='ACTUAL_COMPILED_DENSE_DAILY_CDE_ROOT_NATIVE3_28_REFUSALS_PASS' and len(control['refusals'])==28 and control['accepted_model_days']==0
   roles.append(role)
  for name in names:raw=z.read(name);members[name]=dict(bytes=len(raw),sha256=SHA(raw))
 record=dict(status='ACTUAL_FOUR_TARGETED_UBUNTU_INITIAL_STATE_COMPOSITIONS_PRESERVED_NOT_ADMITTED',archive=path.name,bytes=size,sha256=digest,parts=[dict(file=path.name,bytes=size,sha256=digest)],members=members,roles=roles,actual_workflow_run=44912666408,actual_artifact=artifact,github_artifact_digest=digest,actual_producer=SOURCE,optimization=a.optimization,actual_short35_contexts=4,actual_exact_cold_windows=12,actual_compiled_native_refusals=28,full_periods_repeated=0,original_receipts_rewritten=False,canonical_admission=False)
 path.with_suffix('.json').write_text(json.dumps(record,indent=2)+'\n');print(record['status'],a.optimization,len(members),size,digest)


if __name__=='__main__':main()
