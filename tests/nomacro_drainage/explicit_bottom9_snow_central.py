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
 p=argparse.ArgumentParser();p.add_argument('--proof',type=Path,default=ROOT/'integration/f-ci/nomacro-complete01');p.add_argument('--optimization',choices=('O0','O2'));p.add_argument('--scratch',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();q=ubuntu(a.proof,a.optimization,a.scratch) if a.optimization else windows(a.proof,a.scratch)
 with a.output.open('x') as f:json.dump(q,f,indent=2);f.write('\n')
 print(q['status'],a.optimization)
