"""Replay original Snow9 CI bytes with explicit archived build/input locations."""
import argparse,json,types
from contextlib import ExitStack
from pathlib import Path
from analytical_hydraulic_archives import Archive,SHA
from explicit_bottom9_snow_source_inverse import ROOT,CORE,complete_inverse,git
from explicit_bottom9_snow_science import audit
from explicit_bottom9_compiled_postimage import compare
from explicit_bottom9_analytical_central import capsule


def windows(proof,scratch):
 complete_inverse();scratch=Path(scratch);assert scratch.is_dir() and not any(scratch.iterdir());results=[]
 with ExitStack() as stack:
  store=Archive(proof,'EXPLICIT_BOTTOM9_SNOW_WINDOWS_RAW_V1',stack);record=store.record
  index=json.loads(store.get('COMMITTED_SOURCE_INDEX_V1.json'));assert index['working_source_capture_claimed'] is False
  objects=set()
  for head,rows in index['epochs'].items():
   expected={line.split('\t')[1]:dict(git_blob=line.split('\t')[0].split()[2],mode=line.split('\t')[0].split()[0]) for line in git('ls-tree','-r',head,'--',*index['scope']).decode().splitlines()};assert rows==expected
   for item in rows.values():objects.add(item['git_blob'])
  import hashlib
  for digest in objects:
   raw=store.get('committed-source/blobs/'+digest);assert hashlib.sha1(b'blob '+str(len(raw)).encode()+b'\0'+raw).hexdigest()==digest
  for name in store.names:
   path=scratch/name;assert path.resolve().is_relative_to(scratch.resolve());path.parent.mkdir(parents=True,exist_ok=True)
   with path.open('xb') as out:out.write(store.get(name))
  projection=json.loads(store.get('COMPILED_PROJECTION_V1.json'));assert len(record['roles'])==4 and len(projection)==12
  def built(value):
   item=projection[value];path=scratch/item['archive_prefix'];assert SHA((path/'BUILD.json').read_bytes())==item['actual_BUILD_sha256'];return path
  for role in record['roles']:
   profile=scratch/role['profile'];post=scratch/role['postimage'];q=json.loads((profile/'RESULT.json').read_text());p=json.loads((post/'RESULT.json').read_text());first,second=built(q['build_root']),built(p['build_root'])
   assert q['source']==role['producer'] and q.get('observer_source')==role['observer'] and p['profile']==role['original_profile_path'] and p['profile_RESULT_sha256']==SHA((profile/'RESULT.json').read_bytes())
   assert p['actual_compiler_start_HEAD']==p['actual_compiler_end_HEAD']==p['source']
   meta=json.loads((first/'BUILD.json').read_text())
   for digest,path in [(meta['identity']['host'],'app/hybrid_water/daily_host.py'),(meta['identity']['lower_boundary_receipt']['source_sha256'],'app/hybrid_water/prescribed_head_flux_boundary.py')]:
    raw=store.get('committed-source/blobs/'+index['epochs'][q['source']][path]['git_blob']);assert digest in (SHA(raw),SHA(raw.replace(b'\n',b'\r\n')))
   assert compare(first,second)==p['compiled']
   for row in p['generated_sources']:
    a=(first/row['file']).read_bytes();b=(second/row['file']).read_bytes();assert SHA(a)==row['actual_initial1_sha256'] and SHA(b)==row['actual_initial2_sha256'] and a.replace(b'\r\n',b'\n')==b.replace(b'\r\n',b'\n')
   actual=audit(profile,dict(inputs=scratch/role['inputs'],build=first));assert actual==json.loads(store.get(role['independent']));results.append(actual)
   print('CENTRAL_WINDOWS_ACTIVE_SNOW9_SCIENCE_NATIVE_COLD_WHOLE_COMPILED_PASS',role['kind'],role['optimization'],flush=True)
 return dict(status='ALL4_WINDOWS_ACTIVE_SNOW9_ORIGINAL_ARCHIVE_COMMITTED_SOURCE_NATIVE_COLD_COMPILED_INDEPENDENT_PASS_NOT_ADMITTED',contexts=results,source_epochs=sorted(index['epochs']),raw_sha256=record['sha256'],compiler_executions=0,model_executions=0,canonical_admission=False)


def supplement(proof,scratch,base_scratch):
 from explicit_bottom9_snow_science import native_controls
 complete_inverse();scratch=Path(scratch);base_scratch=Path(base_scratch);assert scratch.is_dir() and not any(scratch.iterdir())
 with ExitStack() as stack:
  store=Archive(proof,'EXPLICIT_BOTTOM9_SNOW_PRIOR_CONTROLS_RAW_V1',stack);base=Archive(proof,'EXPLICIT_BOTTOM9_SNOW_WINDOWS_RAW_V1',stack);link=json.loads(store.get('BASE_SOURCE_ARCHIVE_V1.json'));assert link['sha256']==base.record['sha256']
  index=json.loads(store.get('COMMITTED_SOURCE_INDEX_V1.json'));objects=set()
  for head,rows in index['epochs'].items():
   expected={line.split('\t')[1]:dict(git_blob=line.split('\t')[0].split()[2],mode=line.split('\t')[0].split()[0]) for line in git('ls-tree','-r',head,'--',*index['scope']).decode().splitlines()};assert rows==expected;objects.update(v['git_blob'] for v in rows.values())
  import hashlib
  for digest in objects:
   name='committed-source/blobs/'+digest;raw=(store if name in store.names else base).get(name);assert hashlib.sha1(b'blob '+str(len(raw)).encode()+b'\0'+raw).hexdigest()==digest
  for name in store.names:
   path=scratch/name;assert path.resolve().is_relative_to(scratch.resolve());path.parent.mkdir(parents=True,exist_ok=True)
   with path.open('xb') as out:out.write(store.get(name))
  projection=json.loads(store.get('COMPILED_PROJECTION_V1.json'));assert len(projection)==10
  def built(actual):
   item=projection[actual];path=scratch/item['archive_prefix'];assert SHA((path/'BUILD.json').read_bytes())==item['actual_BUILD_sha256'];return path
  prior=json.loads(store.get('observations/EXPLICIT_BOTTOM9_SNOW_PRIOR_ACTUAL_PARENT_POSTIMAGES_V1.json'));assert len(prior['comparisons'])==4
  for case in prior['comparisons']:
   left,right=built(case['actual_parent']['build_root']),built(case['actual_candidate']['build_root'])
   for row in case['generated_sources']:
    a=(left/row['file']).read_bytes();b=(right/row['file']).read_bytes();assert SHA(a)==row['actual_parent_sha256'] and SHA(b)==row['actual_candidate_sha256'] and a.replace(b'\r\n',b'\n')==b.replace(b'\r\n',b'\n')
   assert compare(left,right)==case['compiled']
  from explicit_bottom9_analytical_parent_postimages import role as original_role,audit as original_audit
  for opt in ('O0','O2'):
   q=json.loads(store.get('profiles/explicit-bottom9-snow-prior-paired9-cde-monthly-'+opt+'-v1/RESULT.json'));archive,inputs,item,meta,old=original_role(proof,'cde-monthly',opt,stack)
   actual=original_audit(built(q['build_root']),old,meta,q['actual_compiler_start_HEAD']);assert actual==q['complete_original_byte_comparison']
  controls=json.loads(store.get('observations/EXPLICIT_BOTTOM9_SNOW_WINDOWS_COMPILED_NATIVE_CONTROLS_INDEPENDENT_V1.json'));results=[];base_projection=json.loads(base.get('COMPILED_PROJECTION_V1.json'))
  for case in controls['contexts']:
   role=next(x for x in base.record['roles'] if x['kind']==case['kind'] and x['optimization']==case['optimization']);profile=base_scratch/role['profile'];p=json.loads(base.get(role['profile']+'/RESULT.json'));build=base_scratch/base_projection[p['build_root']]['archive_prefix'];inputs=base_scratch/role['inputs']
   # Revalidate every base byte used by the original independent native reader.
   for prefix in (role['profile'],role['inputs'],base_projection[p['build_root']]['archive_prefix']):
    for name,item in base.names.items():
     if name.startswith(prefix+'/'):assert SHA((base_scratch/name).read_bytes())==item['sha256']
   root=scratch/'profiles'/Path(case['controls']).name;actual=native_controls(root,profile,dict(build=build,inputs=inputs));assert actual==case['science'];results.append(actual)
 return dict(status='ALL6_UNCHANGED_PRIOR_CONTEXT_POSTIMAGES_AND100_ACTUAL_COMPILED_NATIVE_REFUSALS_CENTRAL_INDEPENDENT_PASS',raw_sha256=store.record['sha256'],prior_Snow_contexts=4,prior_paired9_contexts=2,actual_compiled_refusals=100,actual_positive_startups=4,native_control_science=results,compiler_executions=0,model_periods=0,canonical_admission=False)


def ubuntu_native(proof,opt,scratch):
 import hashlib,io,tarfile
 from explicit_bottom9_snow_science import native_controls
 complete_inverse();scratch=Path(scratch);assert scratch.is_dir() and not any(scratch.iterdir());results=[]
 with ExitStack() as stack:
  store=Archive(proof,'EXPLICIT_BOTTOM9_SNOW_NATIVE_UBUNTU_'+opt+'_RAW_V1',stack);model=Archive(proof,'EXPLICIT_BOTTOM9_SNOW_UBUNTU_'+opt+'_RAW_V1',stack);record=store.record
  observed=store.get('actual-observer-head.txt').decode().strip();assert observed==record['actual_observer_source']
  source=json.loads(store.get('actual-control-source.json'));archive=stack.enter_context(tarfile.open(fileobj=io.BytesIO(store.get('actual-control-source.tar'))));assert set(archive.getnames())==set(source)
  for member in archive.getmembers():
   assert member.isfile();raw=archive.extractfile(member).read();item=source[member.name];assert len(raw)==item['bytes'] and SHA(raw)==item['sha256'] and hashlib.sha1(b'blob '+str(len(raw)).encode()+b'\0'+raw).hexdigest()==item['git_blob']
   assert git('rev-parse',observed+':'+member.name).decode().strip()==item['git_blob']
  for name in store.names:
   path=scratch/'controls'/name;assert path.resolve().is_relative_to((scratch/'controls').resolve());path.parent.mkdir(parents=True,exist_ok=True)
   with path.open('xb') as out:out.write(store.get(name))
  projection=json.loads(model.get('COMPILED_PROJECTION_V1.json'));expected=json.loads(store.get('INDEPENDENT.json'))
  for kind in ('water','cde'):
   prefix='snow9-'+kind+'-'+opt;profile=scratch/'model'/prefix;raw=model.get(prefix+'/RESULT.json');q=json.loads(raw);assert q['source']==record['actual_compiler_producer'];profile.mkdir(parents=True);(profile/'RESULT.json').write_bytes(raw)
   build=scratch/'model/compiled'/prefix;build.mkdir(parents=True);entry=projection[q['build_root']];raw=model.get(entry['archive_prefix']+'/BUILD.json');assert SHA(raw)==entry['actual_BUILD_sha256'];(build/'BUILD.json').write_bytes(raw)
   inputs=scratch/'model/inputs'/kind;inputs.mkdir(parents=True)
   for name in model.names:
    start='inputs/'+kind+'-initial1/'
    if name.startswith(start):(inputs/name[len(start):]).write_bytes(model.get(name))
   (profile/'trajectory').mkdir()
   for name in ('daily.jsonl','accepted-column-1-day-4.zip'):(profile/'trajectory'/name).write_bytes(model.get(prefix+'/trajectory/'+name))
   actual=native_controls(scratch/'controls'/kind,profile,dict(build=build,inputs=inputs));assert actual==next(x['science'] for x in expected['contexts'] if x['kind']==kind);results.append(dict(kind=kind,science=actual))
 return dict(status='ALL50_UBUNTU_ORIGINAL_SNOW9_REUSED_COMPILED_AND_IDENTICAL_PAYLOAD_NATIVE_REFUSALS_CENTRAL_PASS',optimization=opt,actual_observer_source=observed,actual_compiler_producer=record['actual_compiler_producer'],actual_run=record['actual_run'],actual_artifact=record['actual_artifact'],raw_sha256=record['sha256'],contexts=results,accepted_model_days=0,compiler_executions=0,model_periods=0,canonical_admission=False)


def ubuntu(proof,opt,scratch):
 complete_inverse();results=[];scratch=Path(scratch);assert scratch.is_dir() and not any(scratch.iterdir())
 with ExitStack() as stack:
  store=Archive(proof,'EXPLICIT_BOTTOM9_SNOW_UBUNTU_'+opt+'_RAW_V1',stack);record=store.record;producer=record['actual_producer']
  # The reused capsule checker takes this composition's actual source anchor.
  # Its complete blob/member checks execute unchanged; Git and data stay real.
  check_source=types.FunctionType(capsule.__code__,dict(capsule.__globals__,ANALYTICAL_CORE=CORE))
  source=check_source(store,'source',producer,stack,'controller-source')
  original=source.read('reference/swap-4.3.1/source-archives/SWAP.ZIP');assert SHA(original)=='1a2d798994c2990b397f9349317e3a26f40662fbcff55c9ea484dd638af45151'
  workflow=git('show',producer+':.github/workflows/nomacro-explicit-bottom9-snow.yml');assert store.get('actual-workflow.yml')==workflow
  assert store.get('actual-workflow-git-blob.txt').decode().strip()==__import__('hashlib').sha1(b'blob '+str(len(workflow)).encode()+b'\0'+workflow).hexdigest()
  prepared=json.loads(store.get('provider-PREPARED.json'));assert prepared['source_archives']['SWAP.ZIP']==SHA(original)
  for name,digest in prepared['provider_files'].items():
   if name.startswith('build/'):assert SHA(store.get('original-provider-build/'+name[len('build/'):]))==digest
  for name in store.names:
   path=scratch/name;assert path.resolve().is_relative_to(scratch.resolve());path.parent.mkdir(parents=True,exist_ok=True)
   with path.open('xb') as out:out.write(store.get(name))
  projection=json.loads(store.get('COMPILED_PROJECTION_V1.json'));batch=json.loads(store.get('SNOW-'+opt+'-BATCH.json'));assert batch['source']==producer and batch['optimization']==opt and batch['status']=='BOTH_WATER_CDE_ACTIVE_SNOW9_ORIGINAL_LEDGER_NATIVE_COLD_COMPILED_PASS_NOT_ADMITTED' and len(batch['contexts'])==2
  prefix='/home/runner/work/_temp/proof/'
  def locate(value):assert value.startswith(prefix);return scratch/value[len(prefix):]
  def built(value):
   item=projection[value];path=scratch/item['archive_prefix'];assert SHA((path/'BUILD.json').read_bytes())==item['actual_BUILD_sha256'];return path
  for role in batch['contexts']:
   profile=locate(role['profile']);post=locate(role['postimage']);q=json.loads((profile/'RESULT.json').read_text());p=json.loads((post/'RESULT.json').read_text())
   assert q['source']==p['source']==producer and q['optimization']==opt and p['profile']==role['profile'] and p['profile_RESULT_sha256']==SHA((profile/'RESULT.json').read_bytes())
   first,second=built(q['build_root']),built(p['build_root']);inputs=locate(q['input_root']);counter_inputs=locate(p['input_root'])
   assert SHA((first/'BUILD.json').read_bytes())==p['actual_initial1_BUILD_sha256'] and SHA((second/'BUILD.json').read_bytes())==p['actual_initial2_BUILD_sha256']
   assert {x.relative_to(counter_inputs).as_posix():SHA(x.read_bytes()) for x in counter_inputs.rglob('*') if x.is_file()}==p['input_inventory']
   for row in p['generated_sources']:
    a=(first/row['file']).read_bytes();b=(second/row['file']).read_bytes();assert SHA(a)==row['actual_initial1_sha256'] and SHA(b)==row['actual_initial2_sha256'] and a.replace(b'\r\n',b'\n')==b.replace(b'\r\n',b'\n')
   assert compare(first,second)==p['compiled']
   actual=audit(profile,dict(inputs=inputs,build=first));recorded=json.loads(locate(role['independent']).read_text());assert actual==recorded and SHA(locate(role['independent']).read_bytes())==role['independent_sha256']
   results.append(actual);print('CENTRAL_ORIGINAL_ACTIVE_SNOW9_SCIENCE_NATIVE_COLD_WHOLE_COMPILED_PASS',role['kind'],opt,flush=True)
 return dict(status='BOTH_UBUNTU_WATER_CDE_ACTIVE_SNOW9_ORIGINAL_ARCHIVE_INDEPENDENT_REPLAY_PASS_NOT_ADMITTED',optimization=opt,actual_producer=producer,actual_run=record['actual_run'],actual_artifact=record['actual_artifact'],raw_sha256=record['sha256'],contexts=results,compiler_executions=0,model_executions=0,canonical_admission=False)


if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--proof',type=Path,default=ROOT/'integration/f-ci/nomacro-complete01');p.add_argument('--optimization',choices=('O0','O2'));p.add_argument('--scratch',type=Path,required=True);p.add_argument('--base-scratch',type=Path);p.add_argument('--native',action='store_true');p.add_argument('--output',type=Path,required=True);a=p.parse_args();q=ubuntu_native(a.proof,a.optimization,a.scratch) if a.native else supplement(a.proof,a.scratch,a.base_scratch) if a.base_scratch else ubuntu(a.proof,a.optimization,a.scratch) if a.optimization else windows(a.proof,a.scratch)
 with a.output.open('x') as f:json.dump(q,f,indent=2);f.write('\n')
 print(q['status'],a.optimization)
