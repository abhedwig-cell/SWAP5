"""Read preserved initial pressure/calendar trajectories and compiled postimages."""
import argparse,json
from contextlib import ExitStack
from pathlib import Path
from analytical_hydraulic_archives import Archive,SHA
from initial_profile_calendar_science import audit
from initial_profile_calendar_postimage import compare
from initial_profile_calendar_records import frontend


def read(proof,names):
 observations=[];postimages=[];dispatch=None
 with ExitStack() as stack:
  for name in names:
   store=Archive(proof,name,stack);projection=json.loads(store.get('COMPILED_PROJECTION_V1.json'));portable='UBUNTU' in name
   if not portable:
    provider=Archive(proof,'HYDRAULIC_VAPOR_WINDOWS_WATER_RAW_V1',stack)
    dispatch=frontend(store)
    # Preserve the original shared provider rather than copying its build into
    # each configuration archive. Its accepted whole ZIP is checked above.
   class Reference:
    def __truediv__(self,key):
     assert key.startswith('build/');return (store if portable else provider).view('original-provider-build/'+key[6:])
   reference=Reference()
   for role in store.record['roles']:
    profile=store.view(role['profile']);q=json.loads((profile/'RESULT.json').read_text());item=projection[q['build_root']];build=store.view(item['archive_prefix'])
    assert SHA((build/'BUILD.json').read_bytes())==item['actual_BUILD_sha256']
    result=audit(profile,reference,dict(build=build,inputs=store.view(role['inputs'])))
    assert result==role['science'],'Archived independent scientific observation differs'
    observations.append(dict(archive=name,profile=role['profile'],science=result))
   for prefix in store.record['postimages']:
    q=json.loads(store.get(prefix+'/RESULT.json'));assert q['status']=='ACTUAL_COMPILED_INITIAL2_BASELINE_WITH_UNCHANGED_INITIAL1_CALENDAR_ABI_PASS_NO_MODEL_REPEAT'
    original=projection[q['initial1_build_root']];baseline=projection[q['build_root']]
    result=compare(store.view(baseline['archive_prefix']),store.view(original['archive_prefix']))
    assert result==q['postimage'],'Archived complete compiled postimage differs'
    postimages.append(dict(archive=name,profile=prefix,postimage=result))
 return dict(status='CENTRAL_ORIGINAL_INITIAL_PROFILE_CALENDAR_SCIENCE_AND_COMPLETE_COMPILED_POSTIMAGES_PASS',contexts=len(observations),exact_cold_windows=3*len(observations),native_calendar_samples=7*len(observations),compiler_postimages=len(postimages),observations=observations,postimages=postimages,frontend=dispatch,compiler_executions=0,model_executions=0,canonical_admission=False)


if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--proof',type=Path,required=True);p.add_argument('--names',nargs='+',required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();q=read(a.proof,a.names)
 with a.output.open('x') as f:json.dump(q,f,indent=2);f.write('\n')
 print(q['status'],q['contexts'],q['compiler_postimages'])
