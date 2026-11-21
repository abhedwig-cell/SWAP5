"""Read exact central Windows and Ubuntu bytes with the same independent audit."""
import argparse,json
from contextlib import ExitStack
from pathlib import Path
from analytical_hydraulic_archives import Archive
from analytical_calendar_science import audit,SHA


def read(proof):
 observations={}
 with ExitStack() as stack:
  provider=Archive(proof,'HYDRAULIC_VAPOR_WINDOWS_WATER_RAW_V1',stack)
  windows=Archive(proof,'HYDRAULIC_ANALYTICAL_CALENDAR_WINDOWS_RAW_V1',stack)
  for platform,store in [('Windows',windows),*[(opt,Archive(proof,'HYDRAULIC_ANALYTICAL_CALENDAR_UBUNTU_'+opt+'_RAW_V1',stack)) for opt in ('O0','O2')]]:
   compiled=json.loads(store.get('COMPILED_PROJECTION_V1.json'))
   class Reference:
    def __truediv__(self,name):
     assert name.startswith('build/')
     return (provider if platform=='Windows' else store).view('original-provider-build/'+name[6:])
   for role in store.record['roles']:
    profile=store.view(role['profile']);q=json.loads((profile/'RESULT.json').read_text());item=compiled[q['build_root']];build=store.view(item['archive_prefix'])
    assert SHA((build/'BUILD.json').read_bytes())==item['actual_BUILD_sha256']
    inputs=store.view('profiles/vapor-calendar-dispatch-assessment-v1/snow0-monthly') if role['original_monthly'] else profile/'input'
    result=audit(profile,Reference(),locations=dict(build=build,inputs=inputs),original_monthly=role['original_monthly'])
    if platform!='Windows':assert result==json.loads(store.get(role['independent']))
    name=role.get('observation',role['profile'].split('/')[-1]);observations[('Windows/' if platform=='Windows' else 'Ubuntu/')+name]=result
  local=json.loads(windows.get('observations/ANALYTICAL_CALENDAR_LOCAL_INDEPENDENT_V1.json'))
  assert {key.split('/',1)[1]:value for key,value in observations.items() if key.startswith('Windows/')}==local['profiles']
 assert len(observations)==20 and sum(v['days']==367 for v in observations.values())==5 and sum(v['days']==35 for v in observations.values())==13 and sum(v['days']==2 for v in observations.values())==2
 assert sum(v['cold_windows'] for v in observations.values())==65 and sum(v['native_checkpoints'] for v in observations.values())==143
 return dict(status='INDEPENDENT_WINDOWS_UBUNTU_FIVE_YEAR_THIRTEEN_SHORT_TWO_DENSITY_65_COLD_143_NATIVE_OUTPUT_CLOCK_PASS',profiles=observations,compiler_executions=0,model_executions=0,original_receipts_rewritten=False,canonical_admission=False)


if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--proof',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();q=read(a.proof)
 with a.output.open('x') as f:json.dump(q,f,indent=2);f.write('\n')
 print(q['status'],len(q['profiles']))
