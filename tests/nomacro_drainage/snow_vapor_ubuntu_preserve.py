"""Inventory original successful Ubuntu artifacts without rewriting any byte."""
import argparse,hashlib,json,subprocess,zipfile
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
SOURCE='1a1f2bc339403e4202df8decc7b22d0f8adc573e'
EXPECTED={'O0':(14699132793,27020327,'5624a8fd9d9001a877d9b0a22957f34260b93cbe271032f6736bccf364a8e1ca'),
          'O2':(14699680461,27055816,'0a541498785e8872c875b15c672a2eb3285d18cac0b1169ba05968f612c7c5ca')}
SHA=lambda raw:hashlib.sha256(raw).hexdigest()


def main():
 p=argparse.ArgumentParser();p.add_argument('--optimization',choices=('O0','O2'),required=True);a=p.parse_args()
 artifact,size,digest=EXPECTED[a.optimization];proof=ROOT/'integration/f-ci/nomacro-complete01'
 path=proof/f'HYDRAULIC_SNOW_VAPOR_UBUNTU_{a.optimization}_RAW_V1.zip';assert path.stat().st_size==size and SHA(path.read_bytes())==digest
 assert not path.with_suffix('.json').exists();members={};roles=[]
 with zipfile.ZipFile(path) as z:
  names=z.namelist();assert len(names)==len(set(names))
  source=json.loads(z.read('source/RESULT.json'));assert source['producer_head']==SOURCE
  workflow=subprocess.check_output(['git','show',SOURCE+':.github/workflows/nomacro-water-snow-groundwater.yml'],cwd=ROOT)
  assert z.read('actual-workflow.yml')==workflow
  assert z.read('actual-workflow-git-blob.txt').decode().strip()==hashlib.sha1(b'blob '+str(len(workflow)).encode()+b'\0'+workflow).hexdigest()
  projection=json.loads(z.read('COMPILED_PROJECTION_V1.json'))
  for kind in ('water','cde'):
   name=f'snow-vapor-{kind}-{a.optimization}-short';q=json.loads(z.read(name+'/RESULT.json'))
   assert q['source']==SOURCE and q['kind']==kind and q['optimization']==a.optimization and q['days']==35 and len(q['cold'])==3
   assert q['status']=='ACTUAL_SNOW_VAPOR_WATER_CDE_POSTIMAGE_SHORT_OR_FULL_EXACT_COLD_PASS_NOT_ADMITTED'
   item=projection[q['build_root']];assert SHA(z.read(item['archive_prefix']+'/BUILD.json'))==item['actual_BUILD_sha256']
   independent=json.loads(z.read(name+'-INDEPENDENT.json'));assert independent['status']=='INDEPENDENT_ORIGINAL_SNOW_VAPOR_SOURCE_PROVIDER_WATER_CDE_NATIVE_OUTPUT_PASS' and independent['days']==35 and independent['cold_windows']==3
   controls=json.loads(z.read(name+'-native-controls/RESULT.json'));assert controls['source']==SOURCE and controls['status']=='ACTUAL_SNOW_VAPOR_NATIVE4_AND_LITERAL_SNOW_DOMAIN_STARTUP_REFUSALS_PASS_NOT_ADMITTED' and len(controls['refusals'])==66 and controls['accepted_model_days']==0
   roles.append(dict(kind=kind,optimization=a.optimization,profile=name,compiled=item['archive_prefix'],independent=name+'-INDEPENDENT.json',native_controls=name+'-native-controls'))
  for name in names:raw=z.read(name);members[name]=dict(bytes=len(raw),sha256=SHA(raw))
 record=dict(status='ACTUAL_TARGETED_UBUNTU_SNOW_VAPOR_ARTIFACT_PRESERVED_NOT_ADMITTED',archive=path.name,bytes=size,sha256=digest,parts=[dict(file=path.name,bytes=size,sha256=digest)],members=members,roles=roles,actual_workflow_run=44884187780,actual_artifact=artifact,github_artifact_digest=digest,actual_producer=SOURCE,optimization=a.optimization,actual_short35_contexts=2,actual_exact_cold_windows=6,compiled_native_refusals=132,new_full1096_periods=0,original_receipts_rewritten=False,canonical_admission=False)
 path.with_suffix('.json').write_text(json.dumps(record,indent=2)+'\n');print(record['status'],a.optimization,len(members),size,digest)


if __name__=='__main__':main()
