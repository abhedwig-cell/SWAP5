"""Read all original Windows/Ubuntu calendar bytes without executing models."""
import argparse,json
from contextlib import ExitStack
from pathlib import Path
from analytical_hydraulic_archives import Archive,SHA
from analytical_cde_calendar_science import audit
from analytical_cde_calendar_control_forensics import native,parent_calendar,transactions,frontend


def read(proof):
 observations={};controls={};parent_controls={};replay={}
 with ExitStack() as stack:
  provider=Archive(proof,'HYDRAULIC_VAPOR_WINDOWS_WATER_RAW_V1',stack)
  windows=Archive(proof,'ANALYTICAL_CDE_CALENDAR_WINDOWS_RAW_V1',stack)
  for platform,store in [('Windows',windows),*[(opt,Archive(proof,'ANALYTICAL_CDE_CALENDAR_UBUNTU_'+opt+'_RAW_V1',stack)) for opt in ('O0','O2')]]:
   projection=json.loads(store.get('COMPILED_PROJECTION_V1.json'))
   class Reference:
    def __truediv__(self,name):
     assert name.startswith('build/');return (provider if platform=='Windows' else store).view('original-provider-build/'+name[6:])
   for role in store.record['roles']:
    profile=store.view(role['profile']);q=json.loads((profile/'RESULT.json').read_text());item=projection[q['build_root']];build=store.view(item['archive_prefix'])
    assert SHA((build/'BUILD.json').read_bytes())==item['actual_BUILD_sha256']
    actual=audit(profile,Reference(),locations=dict(build=build,inputs=store.view(role['inputs'])));assert actual==json.loads(store.get(role['independent']))
    key=platform+'/'+role['profile'].split('/')[-1];observations[key]=actual
    if platform=='Windows' and q['case'] in ('vapor8-periodic6','mixed7-8-clock-undrained8'):
     prefix=role['profile'][:-3]+'-native-controls-v1';parent=role['profile'][:-3]+'-parent-controls-'+('v1' if q['case']=='vapor8-periodic6' else 'v2')
     controls[key]=native(store,role,prefix);parent_controls[key]=parent_calendar(store,role,projection,parent);replay[key]=transactions(store,role,projection,prefix)
    elif 'native_controls' in role:
     prefix=role['native_controls'];controls[key]=native(store,role,prefix);replay[key]=transactions(store,role,projection,prefix)
  dispatch=frontend(windows)
 assert len(observations)==38 and sum(v['days']==367 for v in observations.values())==2 and sum(v['days']==35 for v in observations.values())==36
 assert sum(v['cold_windows'] for v in observations.values())==118 and sum(len(v['native_calendar_samples']) for v in observations.values())==272
 assert len(controls)==len(replay)==6 and sum(v['actual_compiled_refusals'] for v in controls.values())==312
 assert len(parent_controls)==4 and sum(v['actual_compiled_refusals'] for v in parent_controls.values())==188
 return dict(status='INDEPENDENT_38_ANALYTICAL_VAPOR_CDE_CALENDAR_CONTEXTS_118_COLD_272_NATIVE_500_COMPILED_REFUSALS_PASS',profiles=observations,native_controls=controls,parent_calendar_private_controls=parent_controls,external_transactions=replay,frontend=dispatch,compiler_executions=0,model_executions=0,original_receipts_rewritten=False,canonical_admission=False)


if __name__=='__main__':
 p=argparse.ArgumentParser()
 for key in ('proof','output'):p.add_argument('--'+key,type=Path,required=True)
 a=p.parse_args();q=read(a.proof)
 with a.output.open('x') as f:json.dump(q,f,indent=2);f.write('\n')
 print(q['status'],len(q['profiles']))
