"""Reread original Windows and Ubuntu pressure-profile archive bytes."""
import argparse,json
from contextlib import ExitStack
from pathlib import Path
from analytical_hydraulic_archives import Archive,SHA
from initial_pressure_profile_science import audit


def read(proof):
 observations={}
 with ExitStack() as stack:
  provider=Archive(proof,'HYDRAULIC_VAPOR_WINDOWS_WATER_RAW_V1',stack)
  windows=Archive(proof,'HYDRAULIC_INITIAL_PRESSURE_WINDOWS_RAW_V1',stack)
  for platform,store in [('Windows',windows),*[(opt,Archive(proof,'HYDRAULIC_INITIAL_PRESSURE_UBUNTU_'+opt+'_RAW_V1',stack)) for opt in ('O0','O2')]]:
   projection=json.loads(store.get('COMPILED_PROJECTION_V1.json'))
   class Reference:
    def __truediv__(self,name):
     assert name.startswith('build/')
     return (provider if platform=='Windows' else store).view('original-provider-build/'+name[6:])
   for role in store.record['roles']:
    profile=store.view(role['profile']);q=json.loads((profile/'RESULT.json').read_text());item=projection[q['build_root']];build=store.view(item['archive_prefix']);assert SHA((build/'BUILD.json').read_bytes())==item['actual_BUILD_sha256']
    actual=audit(profile,Reference(),locations=dict(build=build,inputs=store.view(role['inputs'])));assert actual==json.loads(store.get(role['independent']))
    observations[('Windows/' if platform=='Windows' else 'Ubuntu/')+role['profile'].split('/')[-1]]=actual
  local=json.loads(windows.get('observations/INITIAL_PRESSURE_PROFILE_LOCAL_INDEPENDENT_V1.json'));assert {k.split('/',1)[1]:v for k,v in observations.items() if k.startswith('Windows/')}==local['profiles']
 assert len(observations)==12 and all(v['days']==35 for v in observations.values())
 assert sum(v['cold_windows'] for v in observations.values())==36 and sum(v['native_checkpoints'] for v in observations.values())==84 and sum(v['exact_private_CDE_stocks'] for v in observations.values())==42
 return dict(status='INDEPENDENT_TWELVE_WINDOWS_UBUNTU_ORIGINAL_PRESSURE_PROFILES_36_COLD_84_NATIVE_42_PRIVATE_CDE_STOCKS_PASS',profiles=observations,compiler_executions=0,model_executions=0,original_receipts_rewritten=False,canonical_admission=False)


if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--proof',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();q=read(a.proof)
 with a.output.open('x') as f:json.dump(q,f,indent=2);f.write('\n')
 print(q['status'],len(q['profiles']))
