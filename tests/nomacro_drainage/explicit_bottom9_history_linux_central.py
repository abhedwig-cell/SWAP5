"""Independently reread original GitHub history artifacts without extraction."""
import argparse,hashlib,io,json,re,tarfile,zipfile
from pathlib import Path
from explicit_bottom9_history_central import Provider,native_controls
from explicit_bottom9_archive_science import ReadView
from explicit_bottom9_history_science import audit
from explicit_bottom9_compiled_postimage import compare as all_compiled
from initial_profile_calendar_postimage import compare as generated
from explicit_bottom9_source_inverse import git
from analytical_hydraulic_archives import SHA

HEAD='b3fc2405f83ee6e0df53f7448fb087c9388b370d'
IDENTITIES={
 'O0':(14837217702,57311539,'311ac535bf210b8067497406ffef80e63935e2c3a890def941a37388d702a4a8'),
 'O2':(14836584474,57681405,'cc413425796b4ac7ca8423fe5a60429b9163ef3b8a9f979dea228ad92bc5464d')}

class Original:
 def __init__(self,z):
  self.z=z;names=z.namelist();assert len(names)==len(set(names))
  assert all(not Path(n).is_absolute() and '..' not in Path(n).parts for n in names)
  self.names={n:None for n in names if not n.endswith('/')}
 def get(self,name):return self.z.read(name)

def source(store,head=HEAD,workflow_path='.github/workflows/nomacro-explicit-bottom9-history.yml'):
 def tree(paths):return {line.split('\t')[1]:line.split('\t')[0].split()[2] for line in git('ls-tree','-r',head,'--',*paths).decode().splitlines()}
 def verify(name,raw,item,expected):
  assert len(raw)==item['bytes'] and SHA(raw)==item['sha256'] and item['git_blob']==expected[name]
  assert hashlib.sha1(b'blob '+str(len(raw)).encode()+b'\0'+raw).hexdigest()==expected[name]
 q=json.loads(store.get('source/RESULT.json'));assert q['producer_head']==head
 expected=tree(q['surfaces']);assert set(q['members'])==set(expected)
 raw=store.get('source/'+q['archive']);assert len(raw)==q['bytes'] and SHA(raw)==q['sha256']
 absent={n for n,item in q['members'].items() if item.get('checkout')=='ABSENT'}
 assert all(n.startswith('reference/swap-4.3.1/') for n in absent)
 with zipfile.ZipFile(io.BytesIO(raw)) as archive:
  assert len(archive.namelist())==len(set(archive.namelist())) and set(archive.namelist())==set(expected)-absent
  for name,item in q['members'].items():
   if name in absent:assert item==dict(git_blob=expected[name],checkout='ABSENT')
   else:verify(name,archive.read(name),item,expected)
 c=json.loads(store.get('controller-source.json'));assert c['producer_head']==head
 expected=tree(('tests/nomacro_drainage','tests/nomacro_scheduled_subsurface','tests/nomacro_mixtures','.github/workflows/nomacro-extended-implicit.yml'));assert set(c['members'])==set(expected)
 raw=store.get('controller-source.tar');assert len(raw)==c['bytes'] and SHA(raw)==c['sha256']
 with tarfile.open(fileobj=io.BytesIO(raw)) as archive:
  members=archive.getmembers();assert len(members)==len({m.name for m in members}) and {m.name for m in members}==set(expected)
  for member in members:assert member.isfile();verify(member.name,archive.extractfile(member).read(),c['members'][member.name],expected)
 workflow=store.get('actual-workflow.yml');digest=hashlib.sha1(b'blob '+str(len(workflow)).encode()+b'\0'+workflow).hexdigest()
 assert digest==store.get('actual-workflow-git-blob.txt').decode().strip()==tree((workflow_path,))[workflow_path]
 return dict(actual_head=HEAD,source_sha256=q['sha256'],controller_sha256=c['sha256'],workflow_blob=digest,source_inventory=len(q['members']),absent_reference_paths=len(absent))

def linux(path,opt):
 artifact,size,digest=IDENTITIES[opt];assert path.stat().st_size==size and SHA(path.read_bytes())==digest
 results=[]
 with zipfile.ZipFile(path) as z:
  store=Original(z)
  for name in store.names:store.get(name) # Read CRC and every actual raw member.
  sources=source(store);q=json.loads(store.get('RESULT.json'))
  assert q['actual_source']==HEAD and q['optimization']==opt and q['status']=='ALL8_OPT_CONTEXTS_ORIGINAL_HISTORY9_LEDGER_NATIVE_COLD_COMPILED_AND224_NATIVE_REFUSALS_PASS_NOT_ADMITTED'
  assert len(q['profiles'])==q['contexts']==8 and q['native_checkpoints']==56 and q['exact_cold_windows']==24 and q['compiled_initialization_counterparts']==8 and q['native_refusals']==q['identical_payload_independent_refusals']==224
  assert q['canonical_admission'] is False and q['model_periods_repeated']==0
  projection=json.loads(store.get('COMPILED_PROJECTION_V1.json'));assert len(projection)==16
  def build(path):
   item=projection[path];view=ReadView(store,item['archive_prefix']);assert SHA((view/'BUILD.json').read_bytes())==item['actual_BUILD_sha256'];return view
  seen=set()
  for role in q['profiles']:
   key=(role['kind'],role['hysteresis'],role['drainage']);assert key not in seen;seen.add(key)
   assert role['optimization']==opt and role['primary_initial']==(2 if key[0]=='cde' and key[2] else 1) and role['counterpart_initial']==3-role['primary_initial']
   profile=ReadView(store,role['profile']);counter=ReadView(store,role['initialization_postimage']);p=json.loads((profile/'RESULT.json').read_text());c=json.loads((counter/'RESULT.json').read_text());assert p['source']==c['source']==HEAD
   assert p['build']['actual_completion_head']==c['build']['actual_completion_head']==HEAD
   first,second=build(p['build_root']),build(c['build_root']);assert SHA((profile/'RESULT.json').read_bytes())==c['primary_RESULT_sha256']
   assert generated(first,second)==c['postimage'] and all_compiled(first,second)==c['all_compiled']
   inputs=ReadView(store,role['primary_input']);opposite=ReadView(store,role['counterpart_input']);a=(inputs/'swap.swp').read_bytes();b=(opposite/'swap.swp').read_bytes();pattern=rb'(?mi)^([ \t]*SWINCO[ \t]*=[ \t]*)[12](?=[ \t!\r\n])'
   assert a!=b and re.sub(pattern,rb'\g<1>INITIALIZATION_SELECTOR',a)==re.sub(pattern,rb'\g<1>INITIALIZATION_SELECTOR',b)
   for name,_ in p['input_inventory']:
    if name!='swap.swp':assert (inputs/name).read_bytes()==(opposite/name).read_bytes()
   actual=audit(profile,Provider(store),dict(inputs=inputs,build=first));assert actual==json.loads(store.get(role['science'])) and actual['initialization']==role['primary_initial']
   text=a.decode('cp1252');table=re.search(r'(?mi)^[ \t]*ISUBLAY[ \t]+ISOILLAY[ \t]+HSUBLAY[ \t]+NCOMP[^\n]*\n((?:[ \t]*\d+[^\n]*\n)+)',text);assert table;dz=[]
   for line in table[1].splitlines():
    _,_,height,count=line.split();dz.extend([float(height)/int(count)]*int(count))
   selected=dict(json.loads((first/'BUILD.json').read_text())['identity']['original_output'],swdra=role['drainage'])
   controls=native_controls(store,dict(role,producer=HEAD),profile,first,inputs,selected,dz)
   results.append(dict(kind=key[0],hysteresis=key[1],drainage=key[2],optimization=opt,science=actual,native_controls=controls))
   print('CENTRAL_ORIGINAL_UBUNTU_HISTORY9_SOURCE_LEDGER_NATIVE_COLD_COMPILED_REFUSALS_PASS',*key,opt,flush=True)
  assert seen=={(kind,hys,dra) for kind in ('water','cde') for hys in (1,2) for dra in (0,1)}
 return dict(status='ALL8_UBUNTU_HISTORY9_ORIGINAL_ARCHIVE_SOURCE_SCIENCE_COMPILED_AND224_NATIVE_REFUSALS_INDEPENDENT_PASS_NOT_ADMITTED',artifact_id=artifact,archive_sha256=digest,archive_bytes=size,source=sources,contexts=results,compiler_executions=0,model_executions=0,archive_members_extracted=0,canonical_admission=False)

if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--archive',type=Path,required=True);p.add_argument('--optimization',choices=IDENTITIES,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();q=linux(a.archive,a.optimization)
 with a.output.open('x') as f:json.dump(q,f,indent=2)
 print(q['status'])
