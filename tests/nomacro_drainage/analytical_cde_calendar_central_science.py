"""Read all original Windows/Ubuntu calendar bytes without executing models."""
import argparse,json
from contextlib import ExitStack
from pathlib import Path
from analytical_hydraulic_archives import Archive,SHA
from analytical_cde_calendar_science import audit
from analytical_cde_calendar_control_forensics import native,parent_calendar,transactions,frontend
from analytical_cde_calendar_postimage import compare


def postimages(proof):
 results={}
 with ExitStack() as stack:
  store=Archive(proof,'ANALYTICAL_CDE_CALENDAR_POSTIMAGE_RAW_V1',stack);projection=json.loads(store.get('COMPILED_PROJECTION_V1.json'));archives={}
  for codec,version in [('native3','v1'),('native4','v1'),('native5','v3'),('calendar-interval','v3'),('calendar-clock','v3')]:
   prefix='profiles/analytical-cde-calendar-unselected-'+codec+'-O0-'+version;q=json.loads(store.get(prefix+'/RESULT.json'));assert q['model_executions']==0 and q['build']['returncode']==0
   if q['archive'] not in archives:archives[q['archive']]=Archive(proof,q['archive'],stack)
   old=archives[q['archive']];assert old.record['sha256']==q['old_archive_sha256'] and SHA(old.get(q['old_profile']+'/RESULT.json'))==q['old_RESULT_sha256']
   prior=json.loads(old.get(q['old_profile']+'/RESULT.json'));assert prior['source']==q['old_producer']
   prior_projection=json.loads(old.get('COMPILED_PROJECTION_V1.json'));before=old.view(prior_projection[prior['build_root']]['archive_prefix']);entry=projection[q['build_root']];after=store.view(entry['archive_prefix']);actual=compare(before,after)
   assert SHA((after/'BUILD.json').read_bytes())==entry['actual_BUILD_sha256']
   for name,digest in q['input_inventory']:assert SHA(store.get(prefix+'/input/'+name))==digest
   if codec=='calendar-interval':
    r=json.loads(store.get('observations/ANALYTICAL_CDE_CALENDAR_INTERVAL_POSTIMAGE_RECOVERED_V1.json'));assert q['status']=='FAILED' and r['original_failed_RESULT_sha256']==SHA(store.get(prefix+'/RESULT.json')) and r['actual_BUILD_sha256']==entry['actual_BUILD_sha256']
    assert {key:value for key,value in actual.items() if key!='status'}=={key:r[key] for key in actual if key!='status'} and r['compiler_executions']==r['model_executions']==0
   else:assert q['status']=='ACTUAL_UNSELECTED_NATIVE3_4_OR5_COMPLETE_COMPILED_POSTIMAGE_PASS_NO_MODEL_PERIOD_REPEAT' and q['postimage']==actual
   # The final one-line None guard is an exact complete-module inverse of
   # the former core. Water selection always returns a dictionary; the Snow
   # route does not enable this NoSnow terminal owner at all.
   if codec=='native3':assert json.loads((after/'BUILD.json').read_text())['identity']['original_output']['kind']=='water'
   if codec=='native4':assert json.loads((after/'BUILD.json').read_text())['identity'].get('model7_terminal_water') is None
   results[codec]=actual
  for label,diagnostic in [('native5-O0-v1',"TypeError: 'NoneType' object is not subscriptable"),('calendar-interval-O0-v2','Original CDE output currently requires daily interval reset cadence')]:
   prefix='profiles/analytical-cde-calendar-unselected-'+label;q=json.loads(store.get(prefix+'/RESULT.json'));assert q['status']=='FAILED' and q['model_executions']==0 and q['build']['returncode']!=0 and diagnostic in store.get(prefix+'/build.stderr').decode()
 return results


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
 images=postimages(proof);assert len(images)==5
 return dict(status='INDEPENDENT_38_ANALYTICAL_VAPOR_CDE_CALENDAR_CONTEXTS_118_COLD_272_NATIVE_500_COMPILED_REFUSALS_PASS',profiles=observations,native_controls=controls,parent_calendar_private_controls=parent_controls,external_transactions=replay,frontend=dispatch,whole_compiled_postimages=images,compiler_executions=0,model_executions=0,original_receipts_rewritten=False,canonical_admission=False)


if __name__=='__main__':
 p=argparse.ArgumentParser()
 for key in ('proof','output'):p.add_argument('--'+key,type=Path,required=True)
 a=p.parse_args();q=read(a.proof)
 with a.output.open('x') as f:json.dump(q,f,indent=2);f.write('\n')
 print(q['status'],len(q['profiles']))
