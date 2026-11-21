"""Read all actual central initial-state observations without models or compilers."""
import argparse,json
from contextlib import ExitStack
from pathlib import Path
from analytical_hydraulic_archives import Archive,SHA
from initial_state_composition_science import audit
from initial_state_composition_postimage import compare
from initial_state_composition_control_forensics import native_controls,transactions
from initial_state_composition_records import frontend


def read(proof):
 observations={};controls={};transaction_results={};postimages={}
 with ExitStack() as stack:
  provider=Archive(proof,'HYDRAULIC_VAPOR_WINDOWS_WATER_RAW_V1',stack);windows=Archive(proof,'INITIAL_STATE_COMPOSITION_WINDOWS_RAW_V1',stack)
  for platform,store in [('Windows',windows),*[(opt,Archive(proof,'INITIAL_STATE_COMPOSITION_UBUNTU_'+opt+'_RAW_V1',stack)) for opt in ('O0','O2')]]:
   projection=json.loads(store.get('COMPILED_PROJECTION_V1.json'))
   class Reference:
    def __truediv__(self,name):
     assert name.startswith('build/');return (provider if platform=='Windows' else store).view('original-provider-build/'+name[6:])
   for role in store.record['roles']:
    profile=store.view(role['profile']);q=json.loads((profile/'RESULT.json').read_text());item=projection[q['build_root']];build=store.view(item['archive_prefix']);assert SHA((build/'BUILD.json').read_bytes())==item['actual_BUILD_sha256']
    actual=audit(profile,Reference(),locations=dict(build=build,inputs=store.view(role['inputs'])));assert actual==json.loads(store.get(role['independent']));key=platform+'/'+role['profile'].split('/')[-1];observations[key]=actual
    if 'native_controls' in role:controls[key]=native_controls(store,role,projection,role['native_controls'])
    if platform=='Windows' and q['initial_selector']==1 and q['native_codec']=='S5IRC003':
     opt=q['optimization'];old=next(v for v in store.record['roles'] if v['initial_selector']==2 and v['optimization']==opt);previous=json.loads(store.get(old['profile']+'/RESULT.json'));postimages[opt]=compare(store.view(projection[previous['build_root']]['archive_prefix']),build)
     prefix='profiles/initial-state-implicit-snow-cde-initial1-'+opt+'-transactions-'+('v2' if opt=='O0' else 'v1');transaction_results[opt]=transactions(store,role,projection,prefix)
  dispatch=frontend(windows)
 assert len(observations)==30 and sum(v['initial_selector']==1 for v in observations.values())==28 and all(v['days']==35 for v in observations.values())
 assert sum(v['cold_windows'] for v in observations.values())==90 and sum(v['native_checkpoints'] for v in observations.values())==210 and sum(v['exact_private_CDE_stocks'] for v in observations.values())==126
 assert len(controls)==4 and sum(v['actual_compiled_refusals'] for v in controls.values())==112 and len(transaction_results)==len(postimages)==2
 return dict(status='INDEPENDENT_30_ORIGINAL_INITIAL_STATE_CONTEXTS_90_COLD_210_NATIVE_126_PRIVATE_CDE_112_REFUSALS_PASS',profiles=observations,native_controls=controls,frontend=dispatch,root3_complete_actual_compiled_postimages=postimages,root3_external_transactions=transaction_results,compiler_executions=0,model_executions=0,original_receipts_rewritten=False,canonical_admission=False)


if __name__=='__main__':
 p=argparse.ArgumentParser()
 for key in ('proof','output'):p.add_argument('--'+key,type=Path,required=True)
 a=p.parse_args();q=read(a.proof)
 with a.output.open('x') as f:json.dump(q,f,indent=2);f.write('\n')
 print(q['status'],len(q['profiles']))
