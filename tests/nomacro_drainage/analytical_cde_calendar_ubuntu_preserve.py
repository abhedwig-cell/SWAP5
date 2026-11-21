"""Inventory original successful portable calendar artifacts without rewriting."""
import argparse,hashlib,json,subprocess,zipfile
from pathlib import Path
from analytical_hydraulic_archives import SHA
ROOT=Path(__file__).resolve().parents[2]
SOURCE='cbced0e1de4eb354dca0a2eecf4e1c9044259b18'
EXPECTED={'O0':(14714942293,22997484,'02b35a0e15395cf22e9ef1d60f55e91a0998a2d0ab5f0f40fce378e2223de655'),'O2':(14715370586,23073771,'20f88e1afb0dc11ce0a64775a94137568667be885dad2b7d24a6b2cb815070d2')}
CASES=('model7-perstep6','vapor8-monthly5','mixed7-8-clock-undrained8','vapor8-explicit-undrained5')


def main():
 p=argparse.ArgumentParser();p.add_argument('--optimization',choices=EXPECTED,required=True);a=p.parse_args();artifact,size,digest=EXPECTED[a.optimization]
 path=ROOT/'integration/f-ci/nomacro-complete01'/('ANALYTICAL_CDE_CALENDAR_UBUNTU_'+a.optimization+'_RAW_V1.zip')
 assert path.stat().st_size==size and SHA(path.read_bytes())==digest and not path.with_suffix('.json').exists();roles=[];members={}
 with zipfile.ZipFile(path) as z:
  names=z.namelist();assert len(names)==len(set(names)) and json.loads(z.read('source/RESULT.json'))['producer_head']==SOURCE
  workflow=subprocess.check_output(['git','show',SOURCE+':.github/workflows/nomacro-water-snow-groundwater.yml'],cwd=ROOT)
  assert z.read('actual-workflow.yml')==workflow and z.read('actual-workflow-git-blob.txt').decode().strip()==hashlib.sha1(b'blob '+str(len(workflow)).encode()+b'\0'+workflow).hexdigest()
  projection=json.loads(z.read('COMPILED_PROJECTION_V1.json'))
  for case in CASES:
   label='analytical-cde-calendar-'+case+'-'+a.optimization+'-short';q=json.loads(z.read(label+'/RESULT.json'));independent=json.loads(z.read(label+'-INDEPENDENT.json'))
   assert q['source']==SOURCE and q['optimization']==a.optimization and q['days']==35 and len(q['cold'])==3
   assert q['status']=='ACTUAL_ORIGINAL_ANALYTICAL_CDE_CALENDAR_FIXED_MASS_NATIVE_EXACT_COLD_PASS_NOT_ADMITTED'
   assert independent['status']=='INDEPENDENT_ORIGINAL_ANALYTICAL_CDE_CALENDAR6_FIXED_MASS_CALENDAR_PRIVATE_STATE_EXACT_COLD_PASS' and independent['cold_windows']==3 and len(independent['native_calendar_samples'])==7
   item=projection[q['build_root']];assert SHA(z.read(item['archive_prefix']+'/BUILD.json'))==item['actual_BUILD_sha256']
   role=dict(profile=label,inputs='inputs/'+case,independent=label+'-INDEPENDENT.json',kind='cde',optimization=a.optimization)
   if case=='mixed7-8-clock-undrained8':
    role['native_controls']=label+'-native-controls';control=json.loads(z.read(role['native_controls']+'/RESULT.json'))
    assert control['status']=='ACTUAL_CDE_CALENDAR_VAPOR_NATIVE6_52_TYPED_REFUSALS_AND_EXTERNAL_DISCARD_REPLAY_RECOVERY_PASS' and len(control['refusals'])==52 and control['native_control_accepted_model_days']==0
   roles.append(role)
  for name in names:raw=z.read(name);members[name]=dict(bytes=len(raw),sha256=SHA(raw))
 record=dict(status='ACTUAL_FOUR_TARGETED_UBUNTU_ANALYTICAL_VAPOR_CDE_CALENDARS_PRESERVED_NOT_ADMITTED',archive=path.name,bytes=size,sha256=digest,parts=[dict(file=path.name,bytes=size,sha256=digest)],members=members,roles=roles,actual_workflow_run=44923973785,actual_artifact=artifact,github_artifact_digest=digest,actual_producer=SOURCE,optimization=a.optimization,actual_short35_contexts=4,actual_exact_cold_windows=12,actual_compiled_native_refusals=52,external_transaction_contexts=1,original_receipts_rewritten=False,canonical_admission=False)
 path.with_suffix('.json').write_text(json.dumps(record,indent=2)+'\n');print(record['status'],a.optimization,len(members),size,digest)


if __name__=='__main__':main()
