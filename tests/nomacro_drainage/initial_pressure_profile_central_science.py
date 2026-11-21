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
  continuation=Archive(proof,'HYDRAULIC_INITIAL_PRESSURE_BOTTOM5_WINDOWS_RAW_V1',stack);projection=json.loads(continuation.get('COMPILED_PROJECTION_V1.json'))
  class WindowsReference:
   def __truediv__(self,name):assert name.startswith('build/');return provider.view('original-provider-build/'+name[6:])
  for role in continuation.record['roles']:
   profile=continuation.view(role['profile']);q=json.loads((profile/'RESULT.json').read_text());item=projection[q['build_root']];build=continuation.view(item['archive_prefix']);assert SHA((build/'BUILD.json').read_bytes())==item['actual_BUILD_sha256']
   actual=audit(profile,WindowsReference(),locations=dict(build=build,inputs=continuation.view(role['inputs'])));assert actual==json.loads(continuation.get(role['independent']));observations['Windows/'+role['profile'].split('/')[-1]]=actual
  from initial_pressure_profile_postimage import compare
  previous=Archive(proof,'HYDRAULIC_VAPOR_BOUNDARY_GUARD_WINDOWS_RAW_V1',stack);a=json.loads(previous.get('COMPILED_PROJECTION_V1.json'));b=json.loads(windows.get('COMPILED_PROJECTION_V1.json'));postimages={}
  for opt in ('O0','O2'):
   old=json.loads(previous.get('profiles/vapor-boundary-closed-unit8-active-cde7-8-'+opt+'-v2/RESULT.json'));new=json.loads(windows.get('profiles/initial-pressure-closed-vapor-cde-'+opt+'-v1/RESULT.json'));postimages[opt]=compare(previous.view(a[old['build_root']]['archive_prefix']),windows.view(b[new['build_root']]['archive_prefix']))
 assert len(observations)==14 and all(v['days']==35 for v in observations.values())
 assert sum(v['cold_windows'] for v in observations.values())==42 and sum(v['native_checkpoints'] for v in observations.values())==98 and sum(v['exact_private_CDE_stocks'] for v in observations.values())==56
 return dict(status='INDEPENDENT_FOURTEEN_WINDOWS_UBUNTU_ORIGINAL_PRESSURE_PROFILES_42_COLD_98_NATIVE_56_PRIVATE_CDE_STOCKS_PASS',profiles=observations,unchanged_native5_compiled_postimages=postimages,compiler_executions=0,model_executions=0,original_receipts_rewritten=False,canonical_admission=False)


if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--proof',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();q=read(a.proof)
 with a.output.open('x') as f:json.dump(q,f,indent=2);f.write('\n')
 print(q['status'],len(q['profiles']))
