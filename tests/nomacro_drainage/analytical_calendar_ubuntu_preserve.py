"""Inventory exact successful Ubuntu artifacts without rewriting receipts."""
import argparse,hashlib,json,subprocess,zipfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
SOURCE='77874100b21f2db832d03adb4031a2da0ec3d9c6'
EXPECTED={'O0':(14701948797,18243774,'fe7f79980cd0f5b4b030fd4b5086975e80fae5e958eeb4b5f8c1096db91d19ce'),'O2':(14702522029,18280566,'e4cc01888e303330fa0d8a2c00fd60872e18a5986ad4d40ad626c749311585c5')}
SHA=lambda raw:hashlib.sha256(raw).hexdigest()


def main():
 p=argparse.ArgumentParser();p.add_argument('--optimization',choices=EXPECTED,required=True);a=p.parse_args();artifact,size,digest=EXPECTED[a.optimization]
 path=ROOT/'integration/f-ci/nomacro-complete01'/f'HYDRAULIC_ANALYTICAL_CALENDAR_UBUNTU_{a.optimization}_RAW_V1.zip'
 assert path.stat().st_size==size and SHA(path.read_bytes())==digest and not path.with_suffix('.json').exists();members={};roles=[]
 with zipfile.ZipFile(path) as z:
  names=z.namelist();assert len(names)==len(set(names))
  assert json.loads(z.read('source/RESULT.json'))['producer_head']==SOURCE
  workflow=subprocess.check_output(['git','show',SOURCE+':.github/workflows/nomacro-water-snow-groundwater.yml'],cwd=ROOT)
  assert z.read('actual-workflow.yml')==workflow
  assert z.read('actual-workflow-git-blob.txt').decode().strip()==hashlib.sha1(b'blob '+str(len(workflow)).encode()+b'\0'+workflow).hexdigest()
  projection=json.loads(z.read('COMPILED_PROJECTION_V1.json'))
  for case in ('vapor8-nprint2','vapor8-perstep'):
   name=f'analytical-calendar-{case}-{a.optimization}-short';q=json.loads(z.read(name+'/RESULT.json'))
   assert q['source']==SOURCE and q['case']==case and q['optimization']==a.optimization and q['days']==35 and len(q['cold'])==3
   assert q['status'].startswith('ACTUAL_ORIGINAL_ANALYTICAL_WATER_OUTPUT_CLOCK')
   item=projection[q['build_root']];assert SHA(z.read(item['archive_prefix']+'/BUILD.json'))==item['actual_BUILD_sha256']
   independent=json.loads(z.read(name+'-INDEPENDENT.json'));assert independent['status']=='INDEPENDENT_ORIGINAL_ANALYTICAL_OUTPUT_CLOCK_SOURCE_PROVIDER_DAY_AND_INTERVAL_MASS_NATIVE_COLD_OUTPUT_PASS' and independent['cold_windows']==3
   controls=json.loads(z.read(name+'-native-controls/RESULT.json'));assert controls['source']==SOURCE and len(controls['native_refusals'])==24 and controls['transactions'] and controls['status'].startswith('ACTUAL_ANALYTICAL_OUTPUT_24_NATIVE_REFUSALS')
   roles.append(dict(profile=name,independent=name+'-INDEPENDENT.json',native_controls=name+'-native-controls',original_monthly=False))
  for name in names:raw=z.read(name);members[name]=dict(bytes=len(raw),sha256=SHA(raw))
 record=dict(status='ACTUAL_TARGETED_UBUNTU_ANALYTICAL_CALENDAR_ARTIFACT_PRESERVED_NOT_ADMITTED',archive=path.name,bytes=size,sha256=digest,parts=[dict(file=path.name,bytes=size,sha256=digest)],members=members,roles=roles,actual_workflow_run=44891992666,actual_artifact=artifact,github_artifact_digest=digest,actual_producer=SOURCE,optimization=a.optimization,actual_short35_contexts=2,actual_exact_cold_windows=6,compiled_native_refusals=48,external_transaction_contexts=2,full_periods_repeated=0,original_receipts_rewritten=False,canonical_admission=False)
 path.with_suffix('.json').write_text(json.dumps(record,indent=2)+'\n');print(record['status'],a.optimization,len(members),size,digest)


if __name__=='__main__':main()
