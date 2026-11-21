"""Inventory exact successful Ubuntu artifacts without rewriting receipts."""
import argparse,hashlib,json,subprocess,zipfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
SOURCE='c884760037ab77a08586f69b03fa5621dbcdaaa2'
EXPECTED={'O0':(14707925390,11957446,'037cb8435eb8ef2bd79b17e0725a0eee3015799e4119eedcfacd0a0a9be3d8c7'),'O2':(14707955213,11989946,'b5091c8d02eabc26a826fe8378c3231c4f5f162ef6bccc846f2ff0090ab59913')}
SHA=lambda raw:hashlib.sha256(raw).hexdigest()


def main():
 p=argparse.ArgumentParser();p.add_argument('--optimization',choices=EXPECTED,required=True);a=p.parse_args();artifact,size,digest=EXPECTED[a.optimization]
 path=ROOT/'integration/f-ci/nomacro-complete01'/f'HYDRAULIC_INITIAL_PRESSURE_UBUNTU_{a.optimization}_RAW_V1.zip'
 assert path.stat().st_size==size and SHA(path.read_bytes())==digest and not path.with_suffix('.json').exists();members={};roles=[]
 with zipfile.ZipFile(path) as z:
  names=z.namelist();assert len(names)==len(set(names))
  assert json.loads(z.read('source/RESULT.json'))['producer_head']==SOURCE
  workflow=subprocess.check_output(['git','show',SOURCE+':.github/workflows/nomacro-water-snow-groundwater.yml'],cwd=ROOT)
  assert z.read('actual-workflow.yml')==workflow
  assert z.read('actual-workflow-git-blob.txt').decode().strip()==hashlib.sha1(b'blob '+str(len(workflow)).encode()+b'\0'+workflow).hexdigest()
  projection=json.loads(z.read('COMPILED_PROJECTION_V1.json'))
  for case in ('legacy-zih-water','saturated-vapor-cde'):
   name=f'initial-pressure-{case}-{a.optimization}-short';q=json.loads(z.read(name+'/RESULT.json'))
   assert q['source']==SOURCE and q['optimization']==a.optimization and q['days']==35 and len(q['cold'])==3
   assert q['status']=='ACTUAL_ORIGINAL_INITIAL_PRESSURE_PROFILE_WATER_CDE_EXACT_COLD_PASS_NOT_ADMITTED'
   item=projection[q['build_root']];assert SHA(z.read(item['archive_prefix']+'/BUILD.json'))==item['actual_BUILD_sha256']
   independent=json.loads(z.read(name+'-INDEPENDENT.json'));assert independent['status']=='INDEPENDENT_ORIGINAL_PRESSURE_PROFILE_INITIAL_HEADS_SOURCE_FIXED_WATER_CDE_NATIVE_EXACT_COLD_PASS' and independent['cold_windows']==3
   assert independent['native_checkpoints']==7 and independent['exact_initial_pressure_nodes']==34
   assert independent['exact_private_CDE_stocks']==(7 if q['kind']=='cde' else 0)
   if q['kind']=='cde':assert independent['CDE_initial_stock']>0
   roles.append(dict(profile=name,independent=name+'-INDEPENDENT.json',inputs='inputs/'+case,kind=q['kind']))
  for name in names:raw=z.read(name);members[name]=dict(bytes=len(raw),sha256=SHA(raw))
 record=dict(status='ACTUAL_TARGETED_UBUNTU_ORIGINAL_INITIAL_PRESSURE_PROFILES_PRESERVED_NOT_ADMITTED',archive=path.name,bytes=size,sha256=digest,parts=[dict(file=path.name,bytes=size,sha256=digest)],members=members,roles=roles,actual_workflow_run=44904767975,actual_artifact=artifact,github_artifact_digest=digest,actual_producer=SOURCE,optimization=a.optimization,actual_short35_contexts=2,actual_exact_cold_windows=6,compiled_native_refusals_repeated=0,external_transaction_contexts_repeated=0,full_periods_repeated=0,original_receipts_rewritten=False,canonical_admission=False)
 path.with_suffix('.json').write_text(json.dumps(record,indent=2)+'\n');print(record['status'],a.optimization,len(members),size,digest)


if __name__=='__main__':main()
