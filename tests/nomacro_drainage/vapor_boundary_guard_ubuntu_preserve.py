"""Inventory exact successful Ubuntu artifacts without rewriting receipts."""
import argparse,hashlib,json,subprocess,zipfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
SOURCE='7ee1fbcc8d18e91b9c3b5b6bf12eafd3a5df5a63'
EXPECTED={'O0':(14705613363,10223569,'87dc98c451022f70c58779aa2ca1079a2080c1c8165827be3b021d46c53fe6f6'),'O2':(14705638320,10240104,'8a57dd12a0bbb3d4f573e173e6f8f8310f092756767c17724aa797e9ebf7bebc')}
SHA=lambda raw:hashlib.sha256(raw).hexdigest()


def main():
 p=argparse.ArgumentParser();p.add_argument('--optimization',choices=EXPECTED,required=True);a=p.parse_args();artifact,size,digest=EXPECTED[a.optimization]
 path=ROOT/'integration/f-ci/nomacro-complete01'/f'HYDRAULIC_VAPOR_BOUNDARY_GUARD_UBUNTU_{a.optimization}_RAW_V1.zip'
 assert path.stat().st_size==size and SHA(path.read_bytes())==digest and not path.with_suffix('.json').exists();members={};roles=[]
 with zipfile.ZipFile(path) as z:
  names=z.namelist();assert len(names)==len(set(names))
  assert json.loads(z.read('source/RESULT.json'))['producer_head']==SOURCE
  workflow=subprocess.check_output(['git','show',SOURCE+':.github/workflows/nomacro-water-snow-groundwater.yml'],cwd=ROOT)
  assert z.read('actual-workflow.yml')==workflow
  assert z.read('actual-workflow-git-blob.txt').decode().strip()==hashlib.sha1(b'blob '+str(len(workflow)).encode()+b'\0'+workflow).hexdigest()
  projection=json.loads(z.read('COMPILED_PROJECTION_V1.json'))
  for case in ('closed-unit8-active-cde7-8',):
   name=f'vapor-boundary-{case}-{a.optimization}-short';q=json.loads(z.read(name+'/RESULT.json'))
   assert q['source']==SOURCE and q['optimization']==a.optimization and q['days']==35 and len(q['cold'])==3
   assert q['status']=='ACTUAL_VAPOR_BOUNDARY_NATIVE5_WATER_CDE_ORIGINAL_OUTPUT_EXACT_COLD_PASS_NOT_ADMITTED'
   item=projection[q['build_root']];assert SHA(z.read(item['archive_prefix']+'/BUILD.json'))==item['actual_BUILD_sha256']
   independent=json.loads(z.read(name+'-INDEPENDENT.json'));assert independent['status']=='INDEPENDENT_VAPOR_BOUNDARY_NATIVE5_LITERAL_SOURCE_WATER_CDE_TRIAL_AND_PUBLIC_MASS_EXACT_COLD_OUTPUT_PASS' and independent['cold_windows']==3
   assert independent['CDE_initial_stock']>0 and independent['exact_private_CDE_stocks']==7
   roles.append(dict(profile=name,independent=name+'-INDEPENDENT.json',inputs='inputs/'+name,kind=q['kind']))
  for name in names:raw=z.read(name);members[name]=dict(bytes=len(raw),sha256=SHA(raw))
 record=dict(status='ACTUAL_TARGETED_UBUNTU_EXPLICIT_CLOSED_GUARD_CONTINUATION_PRESERVED_NOT_ADMITTED',archive=path.name,bytes=size,sha256=digest,parts=[dict(file=path.name,bytes=size,sha256=digest)],members=members,roles=roles,actual_workflow_run=44900460727,actual_artifact=artifact,github_artifact_digest=digest,actual_producer=SOURCE,optimization=a.optimization,actual_short35_contexts=1,actual_exact_cold_windows=3,compiled_native_refusals_repeated=0,external_transaction_contexts_repeated=0,full_periods_repeated=0,original_receipts_rewritten=False,canonical_admission=False)
 path.with_suffix('.json').write_text(json.dumps(record,indent=2)+'\n');print(record['status'],a.optimization,len(members),size,digest)


if __name__=='__main__':main()
