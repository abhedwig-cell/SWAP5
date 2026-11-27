"""Read the genuine portable producer, controller and SDK bytes; no execution."""
import hashlib,io,json,subprocess,tarfile,zipfile
from pathlib import Path
from analytical_hydraulic_archives import SHA
R=Path(__file__).resolve().parents[2]
PRODUCER='c40ca084d8e5eb638e0b4ac5c471463d9aad01c3'
git=lambda *args:subprocess.check_output(['git',*args],cwd=R)
blob=lambda raw:hashlib.sha1(b'blob '+str(len(raw)).encode()+b'\0'+raw).hexdigest()

def source(store,platform):
 tree={row.split(b'\t',1)[1].decode():row.split()[2].decode() for row in git('ls-tree','-r',PRODUCER).splitlines()}
 def check(name,raw,item):
  assert len(raw)==item['bytes'] and SHA(raw)==item['sha256'] and item['git_blob']==tree[name]
  assert tree[name] in (blob(raw),blob(raw.replace(b'\r\n',b'\n')))
 q=json.loads(store.get('source/RESULT.json'));assert q['producer_head']==PRODUCER;raw=store.get('source/actual-producer-source.zip');assert len(raw)==q['bytes'] and SHA(raw)==q['sha256'];count=0
 with zipfile.ZipFile(io.BytesIO(raw)) as z:
  absent={n for n,item in q['members'].items() if item.get('checkout')=='ABSENT'};assert all(n.startswith('reference/swap-4.3.1/') for n in absent)
  assert len(z.namelist())==len(set(z.namelist()))==len(q['members'])-len(absent) and set(z.namelist())==set(q['members'])-absent
  for n,item in q['members'].items():
   if n in absent:assert item==dict(git_blob=tree[n],checkout='ABSENT')
   else:check(n,z.read(n),item);count+=1
 controller=json.loads(store.get('controller-source.json'));assert controller['producer_head']==PRODUCER;raw=store.get('controller-source.tar');assert len(raw)==controller['bytes'] and SHA(raw)==controller['sha256']
 with tarfile.open(fileobj=io.BytesIO(raw)) as t:
  assert len(t.getmembers())==len({v.name for v in t.getmembers()})==len(controller['members']) and {v.name for v in t.getmembers()}==set(controller['members'])
  for n,item in controller['members'].items():check(n,t.extractfile(n).read(),item)
 workflow='.github/workflows/nomacro-implicit-hydraulic-state11-'+platform.lower()+'.yml';assert store.get('actual-workflow.yml')==git('show',PRODUCER+':'+workflow)
 assert store.get('actual-workflow-git-blob.txt').decode().strip()==tree[workflow]
 contract=json.loads(store.get('actual-source-contract.json'));assert contract['actual_source']==PRODUCER and contract['parent']=='22520105f5a3ccac2bd2ae1b726f27b7b0d67b1e' and contract['files']==14 and contract['model_executions']==contract['compiler_executions']==0
 return dict(status='ACTUAL_PORTABLE_PRODUCER_CONTROLLER_WORKFLOW_AND_PARENT_LITERAL_CONTRACT_BYTES_MATCH_GENUINE_GIT',actual_producer=PRODUCER,actual_source_members=count,actual_controller_members=len(controller['members']),actual_workflow_blob=tree[workflow],compiler_executions=0,model_executions=0)

def sdk(store,identity):
 result={}
 for field,prefix in [('donor_objects','swap-obj'),('donor_modules','swap-obj'),('ttutil_modules','ttutil-obj')]:
  values=identity[field];assert isinstance(values,dict) and values
  for name,digest in values.items():assert SHA(store.get('original-provider-build/'+prefix+'/'+name))==digest,(field,name)
  result[field]=len(values)
 assert SHA(store.get('original-provider-build/ttutil-obj/libttutil.a'))==identity['ttutil_library']
 result['actual_compiler_sha256']=identity['compiler_sha256'];result['actual_donor_flags']=identity['donor_flags'];result['actual_kernel_flags']=identity['kernel_flags'];return result
