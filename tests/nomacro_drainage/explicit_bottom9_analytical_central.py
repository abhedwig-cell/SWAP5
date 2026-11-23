"""Recompute nonlinear paired9 science from immutable central original bytes."""
import argparse,hashlib,io,json,tarfile,types,zipfile
from contextlib import ExitStack
from pathlib import Path
from analytical_hydraulic_archives import Archive,SHA
from explicit_bottom9_archive_science import ReadView,Reference
from explicit_bottom9_last_node_central import built
from explicit_bottom9_analytical_science import audit
from explicit_bottom9_analytical_source_inverse import ROOT,ANALYTICAL_CORE,complete_inverse,git

def capsule(store,prefix,head,stack,controller):
 q=json.loads(store.get(prefix+'/RESULT.json'));raw=store.get(prefix+'/actual-producer-source.zip')
 assert q['producer_head']==head and len(raw)==q['bytes'] and SHA(raw)==q['sha256'] and not git('diff',ANALYTICAL_CORE,head,'--','app','src','tools/solute','tools/vq','reference')
 expected={line.split('\t',1)[1]:line.split('\t',1)[0].split()[2] for line in git('ls-tree','-r',head).decode().splitlines()}
 def check(name,value,item):
  assert len(value)==item['bytes'] and SHA(value)==item['sha256'] and item['git_blob']==expected[name]
  obj=lambda raw:hashlib.sha1(b'blob '+str(len(raw)).encode()+b'\0'+raw).hexdigest()
  assert expected[name] in (obj(value),obj(value.replace(b'\r\n',b'\n')))
 z=stack.enter_context(zipfile.ZipFile(io.BytesIO(raw)));absent={name for name,item in q['members'].items() if item.get('checkout')=='ABSENT'}
 assert all(name.startswith('reference/swap-4.3.1/') for name in absent) and set(z.namelist())==set(q['members'])-absent
 for name,item in q['members'].items():
  if name in absent:assert item==dict(git_blob=expected[name],checkout='ABSENT')
  else:check(name,z.read(name),item)
 c=json.loads(store.get(controller+'.json'));raw=store.get(controller+'.tar');assert c['producer_head']==head and len(raw)==c['bytes'] and SHA(raw)==c['sha256'];tar=stack.enter_context(tarfile.open(fileobj=io.BytesIO(raw)))
 assert {member.name for member in tar.getmembers()}==set(c['members'])
 for name,item in c['members'].items():check(name,tar.extractfile(name).read(),item)
 return z

def frontend(store):
 import prescribed_head_flux_boundary as boundary
 select=types.FunctionType(boundary.selection.__code__,dict(vars(boundary),Path=lambda value:value));select.__kwdefaults__=boundary.selection.__kwdefaults__;q=json.loads(store.get('observations/EXPLICIT_BOTTOM9_ANALYTICAL_ACTUAL_FRONTEND_CONTROLS_V1.json'));assert q['status']=='TWELVE_ACTUAL_FRONTEND_HARD_REFUSALS_AND_TWO_SIGNED_INTEGER_EQUIVALENT_ACCEPTANCES_PASS' and q['compiler_executions']==q['model_executions']==0 and len(q['controls'])==14
 for index,item in enumerate(q['controls']):
  path=ReadView(store,'profiles/explicit-bottom9-analytical-actual-frontend-controls-v1/control-'+str(index));assert SHA((path/'swap.swp').read_bytes())==item['input_sha256'];selected=select(path,True);assert selected==item['bounded_selection'] and (selected is not None)==item['expected_frontend_acceptance']==item['actual_frontend_acceptance']
  if not item['expected_frontend_acceptance']:assert item['refusal']
 return q['controls']

def windows(proof):
 complete_inverse()
 with ExitStack() as stack:
  store=Archive(proof,'EXPLICIT_BOTTOM9_ANALYTICAL_WINDOWS_RAW_V1',stack);provider=Archive(proof,'HYDRAULIC_VAPOR_WINDOWS_WATER_RAW_V1',stack);originals=[]
  for suffix,head in [('9c3d','9c3dccc6f81eb1b82e04d1c4a465f18ba882ec80'),('5ba5','5ba56595b7f453981c0b407d4aeb58958bdb5be8'),('2a42','2a42311e6e5eed9a6a2a45cc9f4697a4b4eed584')]:
   source=capsule(store,'profiles/explicit-bottom9-analytical-actual-source-'+suffix+'-v1',head,stack,'observations/explicit-bottom9-analytical-controller-'+suffix+'-v1');originals.append(source.read('reference/swap-4.3.1/source-archives/SWAP.ZIP'))
  assert originals[0]==originals[1]==originals[2] and SHA(originals[0])=='1a2d798994c2990b397f9349317e3a26f40662fbcff55c9ea484dd638af45151';reference=Reference(provider,originals[0]);projection=json.loads(store.get('COMPILED_PROJECTION_V1.json'));results=[];assert len(store.record['roles'])==12
  for role in store.record['roles']:
   profile=ReadView(store,role['profile']);post=ReadView(store,role['postimage']);q=json.loads((profile/'RESULT.json').read_text());p=json.loads((post/'RESULT.json').read_text());assert q['source']==role['producer'] and q['case']==role['case'] and q['optimization']==role['optimization'] and q['layer_models']==[role['model']]*2
   locations=dict(inputs=ReadView(store,role['inputs']),counter_inputs=ReadView(store,role['counter_inputs']),build=built(store,projection,q['build_root']),counter=built(store,projection,p['build_root']),original_profile_path=role['original_profile_path'])
   samples=None
   if role['reference_samples'] is not None:samples=ReadView(store,role['reference_samples']);locations['reference_component']=ReadView(store,role['reference_component'])
   actual=audit(profile,reference,post,locations,reference_samples=samples);expected=json.loads(store.get(role['independent']))
   # The original V2 observer's field counted observation rows, each with
   # eight direct original function invocations. Correct only that descriptive
   # label; every original numerical/native/compiled result remains exact.
   receipt=expected['actual_original_pressure_samples']
   if receipt is not None:
    observations=receipt.pop('original_function_calls');receipt['original_constitutive_observation_rows']=observations;receipt['direct_constitutive_function_invocations']=8*observations
   assert actual==expected
   results.append(actual);print('ACTUAL_NONLINEAR_WINDOWS_CENTRAL_ORIGINAL_REFERENCE_ALL_NODE_NATIVE_COLD_COMPILED_PASS',q['case'],q['optimization'],flush=True)
  controls=frontend(store)
 return dict(status='ALL12_NONLINEAR_WINDOWS_CENTRAL_SAMPLED_ORIGINAL_REFERENCE_ALL_NODE_STOCK_DARCY_LEDGER_NATIVE_EOF_EXACT_COLD_WHOLE_COMPILED_AND_FRONTEND_PASS_NOT_ADMITTED',contexts=results,frontend=controls,compiler_executions=0,model_executions=0,canonical_admission=False)


def ubuntu(proof,opt):
 complete_inverse();name='EXPLICIT_BOTTOM9_ANALYTICAL_UBUNTU_'+opt+'_RAW_V1'
 with ExitStack() as stack:
  store=Archive(proof,name,stack);record=store.record;producer=record['actual_producer'];source=capsule(store,'source',producer,stack,'controller-source');original=source.read('reference/swap-4.3.1/source-archives/SWAP.ZIP');assert SHA(original)=='1a2d798994c2990b397f9349317e3a26f40662fbcff55c9ea484dd638af45151'
  workflow=git('show',producer+':.github/workflows/nomacro-explicit-bottom9-analytical.yml');assert store.get('actual-workflow.yml')==workflow and store.get('actual-workflow-git-blob.txt').decode().strip()==hashlib.sha1(b'blob '+str(len(workflow)).encode()+b'\0'+workflow).hexdigest()
  prepared=json.loads(store.get('provider-PREPARED.json'));assert prepared['source_archives']['SWAP.ZIP']==SHA(original)
  for path,digest in prepared['provider_files'].items():
   if path.startswith('build/'):assert SHA(store.get('original-provider-build/'+path[len('build/'):]))==digest
  reference=Reference(store,original);projection=json.loads(store.get('COMPILED_PROJECTION_V1.json'));batch=json.loads(store.get('ANALYTICAL-'+opt+'-BATCH.json'));assert batch['status']=='ALL6_REPRESENTATIVE_NONLINEAR_CONTEXTS_INDEPENDENT_PASS_NOT_ADMITTED' and batch['source']==producer and batch['optimization']==opt and len(batch['contexts'])==6
  prefix='/home/runner/work/_temp/proof/'
  def locate(path):
   assert path.startswith(prefix);return ReadView(store,path[len(prefix):])
  results=[]
  for item in batch['contexts']:
   profile=locate(item['profile']);post=locate(item['postimage']);samples=locate(item['original_samples']);q=json.loads((profile/'RESULT.json').read_text());p=json.loads((post/'RESULT.json').read_text());sample=json.loads((samples/'RESULT.json').read_text());assert q['source']==p['source']==sample['source']==producer and q['layer_models']==[item['model']]*2 and q['kind']==item['kind'] and q['optimization']==opt
   locations=dict(inputs=locate(q['input_root']),counter_inputs=locate(p['input_root']),build=built(store,projection,q['build_root']),counter=built(store,projection,p['build_root']),original_profile_path=p['initial1_profile'],reference_component=locate(sample['component_profile']))
   actual=audit(profile,reference,post,locations,reference_samples=samples);assert actual==json.loads(locate(item['independent']).read_text());results.append(actual);print('ACTUAL_NONLINEAR_UBUNTU_CENTRAL_ORIGINAL_REFERENCE_ALL_NODE_NATIVE_COLD_COMPILED_PASS',q['case'],opt,flush=True)
 return dict(status='ALL6_NONLINEAR_UBUNTU_CENTRAL_SAMPLED_ORIGINAL_REFERENCE_ALL_NODE_STOCK_DARCY_LEDGER_NATIVE_EOF_EXACT_COLD_WHOLE_COMPILED_PASS_NOT_ADMITTED',optimization=opt,producer=producer,actual_run=record['actual_run'],actual_artifact=record['actual_artifact'],raw_sha256=record['sha256'],contexts=results,compiler_executions=0,model_executions=0,canonical_admission=False)

if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--proof',type=Path,default=ROOT/'integration/f-ci/nomacro-complete01');p.add_argument('--output',type=Path,required=True);p.add_argument('--ubuntu',choices=('O0','O2'));a=p.parse_args();q=ubuntu(a.proof,a.ubuntu) if a.ubuntu else windows(a.proof)
 with a.output.open('x') as out:json.dump(q,out,indent=2);out.write('\n')
 print(q['status'])
