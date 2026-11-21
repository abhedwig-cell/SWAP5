"""Reread exact central Windows and Ubuntu native5 bytes without replay."""
import argparse,json
from contextlib import ExitStack
from pathlib import Path
from analytical_hydraulic_archives import Archive
from vapor_boundary_science import audit,SHA


def read(proof):
 observations={}
 with ExitStack() as stack:
  provider=Archive(proof,'HYDRAULIC_VAPOR_WINDOWS_WATER_RAW_V1',stack)
  windows=Archive(proof,'HYDRAULIC_VAPOR_BOUNDARY_WINDOWS_RAW_V1',stack)
  for platform,store in [('Windows',windows),*[(opt,Archive(proof,'HYDRAULIC_VAPOR_BOUNDARY_UBUNTU_'+opt+'_RAW_V1',stack)) for opt in ('O0','O2')]]:
   projection=json.loads(store.get('COMPILED_PROJECTION_V1.json'))
   class Reference:
    def __truediv__(self,name):
     assert name.startswith('build/')
     return (provider if platform=='Windows' else store).view('original-provider-build/'+name[6:])
   for role in store.record['roles']:
    profile=store.view(role['profile']);q=json.loads((profile/'RESULT.json').read_text());item=projection[q['build_root']];build=store.view(item['archive_prefix']);assert SHA((build/'BUILD.json').read_bytes())==item['actual_BUILD_sha256']
    observed=audit(profile,Reference(),locations=dict(build=build,inputs=store.view(role['inputs'])))
    if platform!='Windows':assert observed==json.loads(store.get(role['independent']))
    observations[('Windows/' if platform=='Windows' else 'Ubuntu/')+role['profile'].split('/')[-1]]=observed
  local=json.loads(windows.get('observations/VAPOR_BOUNDARY_LOCAL_INDEPENDENT_V2.json'));assert {k.split('/',1)[1]:v for k,v in observations.items() if k.startswith('Windows/')}==local['profiles']
  from vapor_boundary_guard_postimage import compare
  guard_windows=Archive(proof,'HYDRAULIC_VAPOR_BOUNDARY_GUARD_WINDOWS_RAW_V1',stack);projection=json.loads(guard_windows.get('COMPILED_PROJECTION_V1.json'));original_projection=json.loads(windows.get('COMPILED_PROJECTION_V1.json'));postimages={}
  for prefix in guard_windows.record['postimages']:
   q=json.loads(guard_windows.get(prefix+'/RESULT.json'));prior=json.loads(windows.get(q['original_profile']+'/RESULT.json'));old=windows.view(original_projection[prior['build_root']]['archive_prefix']);new=guard_windows.view(projection[q['build_root']]['archive_prefix']);actual=compare(old,new);assert actual==q['postimage'] and q['model_executions']==0;postimages[q['optimization']]=actual
  for platform,store in [('Windows',guard_windows),*[(opt,Archive(proof,'HYDRAULIC_VAPOR_BOUNDARY_GUARD_UBUNTU_'+opt+'_RAW_V1',stack)) for opt in ('O0','O2')]]:
   projection=json.loads(store.get('COMPILED_PROJECTION_V1.json'))
   class Reference:
    def __truediv__(self,name):
     assert name.startswith('build/')
     return (provider if platform=='Windows' else store).view('original-provider-build/'+name[6:])
   for role in store.record['roles']:
    profile=store.view(role['profile']);q=json.loads((profile/'RESULT.json').read_text());item=projection[q['build_root']];build=store.view(item['archive_prefix']);assert SHA((build/'BUILD.json').read_bytes())==item['actual_BUILD_sha256'];observed=audit(profile,Reference(),locations=dict(build=build,inputs=store.view(role['inputs'])));assert observed==json.loads(store.get(role['independent'])) and observed['CDE_initial_stock']>0
    observations[('Windows/' if platform=='Windows' else 'Ubuntu/')+role['profile'].split('/')[-1]]=observed
 assert len(observations)==30 and sum(v['days']==367 for v in observations.values())==4 and sum(v['days']==35 for v in observations.values())==26
 assert sum(v['cold_windows'] for v in observations.values())==98 and sum(v['native_checkpoints'] for v in observations.values())==222 and sum(v['exact_private_CDE_stocks'] for v in observations.values())==160
 return dict(status='INDEPENDENT_WINDOWS_UBUNTU_NATIVE5_FOUR_YEAR_TWENTY_SIX_SHORT_98_COLD_222_NATIVE_160_PRIVATE_CDE_STOCK_EXPLICIT_GUARD_PASS',profiles=observations,explicit_guard_postimage_inheritance=postimages,compiler_executions=0,model_executions=0,original_receipts_rewritten=False,canonical_admission=False)


if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--proof',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();q=read(a.proof)
 with a.output.open('x') as f:json.dump(q,f,indent=2);f.write('\n')
 print(q['status'],len(q['profiles']))
