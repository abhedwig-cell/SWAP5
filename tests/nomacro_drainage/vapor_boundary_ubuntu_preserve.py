"""Inventory exact successful Ubuntu artifacts without rewriting receipts."""
import argparse,hashlib,json,subprocess,zipfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
SOURCE='69710a9453365da25015d28b79ceaaeb0a50c152'
EXPECTED={'O0':(14703593176,32311200,'39f353461c412ff9777f9f785d11438b7b59883cb92a6859ac52a16e026e445e'),'O2':(14703439191,32368720,'e2c341bc6f04817ba13b4c87131b7f142229cb86cc6b1f4029a1ed66d6e6adb7')}
SHA=lambda raw:hashlib.sha256(raw).hexdigest()


def main():
 p=argparse.ArgumentParser();p.add_argument('--optimization',choices=EXPECTED,required=True);a=p.parse_args();artifact,size,digest=EXPECTED[a.optimization]
 path=ROOT/'integration/f-ci/nomacro-complete01'/f'HYDRAULIC_VAPOR_BOUNDARY_UBUNTU_{a.optimization}_RAW_V1.zip'
 assert path.stat().st_size==size and SHA(path.read_bytes())==digest and not path.with_suffix('.json').exists();members={};roles=[]
 with zipfile.ZipFile(path) as z:
  names=z.namelist();assert len(names)==len(set(names))
  assert json.loads(z.read('source/RESULT.json'))['producer_head']==SOURCE
  workflow=subprocess.check_output(['git','show',SOURCE+':.github/workflows/nomacro-water-snow-groundwater.yml'],cwd=ROOT)
  assert z.read('actual-workflow.yml')==workflow
  assert z.read('actual-workflow-git-blob.txt').decode().strip()==hashlib.sha1(b'blob '+str(len(workflow)).encode()+b'\0'+workflow).hexdigest()
  projection=json.loads(z.read('COMPILED_PROJECTION_V1.json'))
  for case in ('undrained-water11','head5-active-cde8-11','unit8-active-cde7-8'):
   name=f'vapor-boundary-{case}-{a.optimization}-short';q=json.loads(z.read(name+'/RESULT.json'))
   assert q['source']==SOURCE and q['optimization']==a.optimization and q['days']==35 and len(q['cold'])==3
   assert q['status']=='ACTUAL_VAPOR_BOUNDARY_NATIVE5_WATER_CDE_ORIGINAL_OUTPUT_EXACT_COLD_PASS_NOT_ADMITTED'
   item=projection[q['build_root']];assert SHA(z.read(item['archive_prefix']+'/BUILD.json'))==item['actual_BUILD_sha256']
   independent=json.loads(z.read(name+'-INDEPENDENT.json'));assert independent['status']=='INDEPENDENT_VAPOR_BOUNDARY_NATIVE5_LITERAL_SOURCE_WATER_CDE_TRIAL_AND_PUBLIC_MASS_EXACT_COLD_OUTPUT_PASS' and independent['cold_windows']==3
   controls=json.loads(z.read(name+'-native-controls/RESULT.json'));assert controls['source']==SOURCE and len(controls['refusals'])==49 and controls['transactions'] and controls['status']=='ACTUAL_VAPOR_BOUNDARY_NATIVE5_49_TYPED_REFUSALS_AND_EXTERNAL_DISCARD_REPLAY_RECOVERY_PASS'
   if q['kind']=='cde':assert independent['CDE_initial_stock']>0 and independent['exact_private_CDE_stocks']>0
   assert controls['native_control_accepted_model_days']==0 and controls['external_transaction_worker_prepares']==3 and controls['external_transaction_commits']==1
   roles.append(dict(profile=name,independent=name+'-INDEPENDENT.json',native_controls=name+'-native-controls',inputs='inputs/'+name,kind=q['kind']))
  for name in names:raw=z.read(name);members[name]=dict(bytes=len(raw),sha256=SHA(raw))
 record=dict(status='ACTUAL_TARGETED_UBUNTU_VAPOR_BOUNDARY_NATIVE5_ARTIFACT_PRESERVED_NOT_ADMITTED',archive=path.name,bytes=size,sha256=digest,parts=[dict(file=path.name,bytes=size,sha256=digest)],members=members,roles=roles,actual_workflow_run=44895442665,actual_artifact=artifact,github_artifact_digest=digest,actual_producer=SOURCE,optimization=a.optimization,actual_short35_contexts=3,actual_exact_cold_windows=9,compiled_native_refusals=147,external_transaction_contexts=3,full_periods_repeated=0,original_receipts_rewritten=False,canonical_admission=False)
 path.with_suffix('.json').write_text(json.dumps(record,indent=2)+'\n');print(record['status'],a.optimization,len(members),size,digest)


if __name__=='__main__':main()
