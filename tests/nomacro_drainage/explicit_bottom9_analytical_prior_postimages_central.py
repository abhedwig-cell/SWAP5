"""Preserve and replay the twelve compile-only unchanged-parent postimages."""
import argparse,json
from contextlib import ExitStack
from pathlib import Path
from analytical_hydraulic_archives import Archive,SHA
from explicit_bottom9_archive_science import ReadView
from explicit_bottom9_analytical_parent_postimages import audit,role
from explicit_bottom9_analytical_source_inverse import ROOT,ANALYTICAL_CORE,complete_inverse,git
from initial_profile_frost_preserve import seal

NAME='EXPLICIT_BOTTOM9_ANALYTICAL_PRIOR_POSTIMAGES_RAW_V1'
CASES={'water-pressure-step','age-pressure-step','cde-pressure-daily','cde-monthly','cde-distributed-subdaily','water-last-node-drainage'}


def preserve(ev,staging):
 complete_inverse();batch=json.loads((ev/'EXPLICIT_BOTTOM9_ANALYTICAL_PRIOR_POSTIMAGES_BATCH_V1.json').read_text())
 assert batch['status']=='ALL12_ACTUAL_PRIOR_CONFIGURATION_COMPLETE_GENERATED_SOURCE_AND_WHOLE_COMPILED_POSTIMAGES_VERIFIED_NO_MODEL_PERIODS'
 assert batch['model_executions']==0 and batch['compiler_only_new_builds']==11
 files={};roles=[]
 def tree(path,prefix):
  assert path.is_dir() and not path.is_symlink()
  for child in sorted(path.rglob('*')):
   assert not child.is_symlink()
   if child.is_file():
    key=prefix+'/'+child.relative_to(path).as_posix();assert key not in files;files[key]=child
 for item in batch['profiles']:
  profile=Path(item['profile']);q=json.loads((profile/'RESULT.json').read_text());build=Path(item['build_root'])
  assert q['case']==item['case'] and q['optimization']==item['optimization'] and q['actual_new_producer']==item['producer'] and q['model_executions']==0
  assert SHA((build/'BUILD.json').read_bytes())==q['actual_new_BUILD_sha256']
  prefix='compiled/'+build.parent.name+'/bundle';tree(build,prefix)
  tree(profile,'profiles/'+profile.name);inputs=Path(q['inputs']);tree(inputs,'inputs/'+inputs.name)
  roles.append(dict(case=q['case'],optimization=q['optimization'],producer=item['producer'],profile='profiles/'+profile.name,compiled=prefix,inputs='inputs/'+inputs.name))
 assert {(x['case'],x['optimization']) for x in roles}=={(case,opt) for case in CASES for opt in ('O0','O2')}
 # Retain failed initial observer and original source captures alongside recovery.
 for path in sorted(ev.iterdir()):
  if path.name.lower().startswith(('explicit-bottom9-analytical-prior','explicit_bottom9_analytical_prior')):
   if path.is_file():files['observations/'+path.name]=path
   elif path.name=='explicit-bottom9-analytical-prior-cde-monthly-O0-postimage-v2':tree(path,'failed-observers/'+path.name)
 extra={'actual-sealer.py':Path(__file__).read_bytes()}
 for producer in sorted({x['producer'] for x in roles}):
  for path in ['tests/nomacro_drainage/explicit_bottom9_analytical_parent_postimages.py','app/hybrid_water/prescribed_head_flux_boundary.py']:
   extra['actual-source/'+producer+'/'+path]=git('show',producer+':'+path)
 seal(staging/(NAME+'.zip'),NAME,files,extra,dict(status='ACTUAL_TWELVE_PRIOR_CONTEXT_COMPILE_ONLY_POSTIMAGES_AND_OBSERVER_FAILURES_PRESERVED_NOT_ADMITTED',roles=roles,composition_source=ANALYTICAL_CORE,sealer_source=git('rev-parse','HEAD').decode().strip(),model_executions=0,canonical_admission=False))


def read(proof):
 observations=[]
 with ExitStack() as stack:
  store=Archive(proof,NAME,stack)
  assert store.record['composition_source']==ANALYTICAL_CORE and store.record['model_executions']==0
  roles=store.record['roles'];assert len(roles)==12
  assert {(x['case'],x['optimization']) for x in roles}=={(case,opt) for case in CASES for opt in ('O0','O2')}
  for item in roles:
   q=json.loads(store.get(item['profile']+'/RESULT.json'));prior_store,inputs,original_item,original_q,old=role(proof,item['case'],item['optimization'],stack)
   assert q['archive_sha256']==prior_store.record['sha256'] and q['actual_new_producer']==item['producer']
   assert not git('diff',ANALYTICAL_CORE,item['producer'],'--','app','src','tools/solute','tools/vq','reference')
   actual_inputs={name[len(item['inputs'])+1:]:SHA(store.get(name)) for name in store.names if name.startswith(item['inputs']+'/')}
   assert actual_inputs==dict(original_q['input_inventory'])==q['actual_input_inventory']
   actual=audit(ReadView(store,item['compiled']),old,original_q,item['producer'])
   assert all(q[key]==value for key,value in actual.items()),'Preserved actual postimage observation differs from independent replay'
   observations.append(dict(case=item['case'],optimization=item['optimization'],actual_producer=item['producer'],actual_BUILD_sha256=actual['actual_new_BUILD_sha256'],complete_generated_sources=len(actual['generated_source']),complete_compiled_files=len(actual['compiled']['files']),model_executions=0))
 return dict(status='ALL12_ARCHIVED_PRIOR_CONTEXT_COMPLETE_SOURCE_AND_COMPILED_POSTIMAGES_INDEPENDENTLY_VERIFIED',observations=observations,archive_sha256=store.record['sha256'],composition_source=ANALYTICAL_CORE,compiler_executions=0,model_executions=0,canonical_admission=False)


if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--evidence',type=Path);p.add_argument('--staging',type=Path);p.add_argument('--read-output',type=Path);a=p.parse_args()
 if a.read_output:
  q=read(ROOT/'integration/f-ci/nomacro-complete01')
  with a.read_output.open('x') as f:json.dump(q,f,indent=2);f.write('\n')
  print(q['status'],len(q['observations']))
 else:assert a.evidence and a.staging;preserve(a.evidence,a.staging)
