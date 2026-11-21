"""Reread original Windows/Ubuntu Snow-vapor ZIPs without replay or extraction."""
import argparse,json
from contextlib import ExitStack
from pathlib import Path
from analytical_hydraulic_archives import Archive
from snow_vapor_science import audit,SHA


def read(proof):
 observations={}
 with ExitStack() as stack:
  provider=Archive(proof,'HYDRAULIC_VAPOR_WINDOWS_WATER_RAW_V1',stack)
  windows=Archive(proof,'HYDRAULIC_SNOW_VAPOR_WINDOWS_RAW_V1',stack)
  for platform,store in [('Windows',windows),*[(opt,Archive(proof,'HYDRAULIC_SNOW_VAPOR_UBUNTU_'+opt+'_RAW_V1',stack)) for opt in ('O0','O2')]]:
   compiled=json.loads(store.get('COMPILED_PROJECTION_V1.json'))
   class Reference:
    def __truediv__(self,name):
     assert name.startswith('build/')
     return (provider if platform=='Windows' else store).view('original-provider-build/'+name[6:])
   for role in store.record['roles']:
    prefix=role['profile'];profile=store.view(prefix);q=json.loads((profile/'RESULT.json').read_text())
    item=compiled[q['build_root']];build=store.view(item['archive_prefix'])
    assert SHA((build/'BUILD.json').read_bytes())==item['actual_BUILD_sha256']
    result=audit(profile,Reference(),locations=dict(build=build,inputs=profile/'input'))
    if platform!='Windows':assert result==json.loads(store.get(role['independent']))
    observations[('Windows/' if platform=='Windows' else 'Ubuntu/')+prefix.split('/')[-1]]=result
  local=json.loads(windows.get('observations/SNOW_VAPOR_LOCAL_INDEPENDENT_V1.json'))
  assert {key.split('/',1)[1]:value for key,value in observations.items() if key.startswith('Windows/')}==local['profiles']
 assert len(observations)==20
 assert sum(v['days']==1096 for v in observations.values())==4
 assert sum(v['days']==35 for v in observations.values())==16
 assert sum(v['cold_windows'] for v in observations.values())==76
 assert sum(v['native_checkpoints'] for v in observations.values())==168
 assert sum(v['exact_private_CDE_stocks'] for v in observations.values())==84
 return dict(status='INDEPENDENT_WINDOWS_UBUNTU_SNOW_VAPOR_FOUR_FULL_SIXTEEN_SHORT_76_COLD_168_NATIVE_84_CDE_STOCK_PASS',profiles=observations,compiler_executions=0,model_executions=0,original_receipts_rewritten=False,canonical_admission=False)


if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--proof',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
 result=read(a.proof)
 with a.output.open('x') as stream:json.dump(result,stream,indent=2);stream.write('\n')
 print(result['status'],len(result['profiles']))
