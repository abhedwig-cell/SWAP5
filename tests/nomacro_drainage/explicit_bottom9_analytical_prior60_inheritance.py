"""Prove exact old paired9 dispatch for every qualified prior60 actual input."""
import argparse,ast,hashlib,io,json,math,re,subprocess,sys,zipfile
from contextlib import ExitStack
from datetime import date
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
OLD='a2039fa529adb74bec571f493bc4c541dddf2a9a';NEW='9c9e35ca34c5831505425ed7546f58c311ecb8c0';MODULE='app/hybrid_water/prescribed_head_flux_boundary.py'
SHA=lambda value:hashlib.sha256(value).hexdigest()

def audit(root,proof):
 def git(*args):return subprocess.check_output(['git',*args],cwd=root)
 def blob(sha,path):return git('show',sha+':'+path)
 old,new=blob(OLD,MODULE),blob(NEW,MODULE)
 assert git('diff','--name-only',OLD,NEW,'--','app','src','tools/solute','tools/vq','reference').decode().splitlines()==[MODULE]
 functions=lambda raw:{node.name:ast.dump(node,include_attributes=False) for node in ast.parse(raw).body if isinstance(node,ast.FunctionDef)}
 before,after=functions(old),functions(new);assert before.keys()==after.keys() and {key for key in before if before[key]!=after[key]}=={'selection'}
 assert old.split(b' active=',1)[0]==new.split(b' active=',1)[0] and b"if s.get('SWBOTB')!=9:return None" in old.split(b' active=',1)[0]
 parser='app/hybrid_water/experimental_project.py';assert blob(OLD,parser)==blob(NEW,parser)==(root/parser).read_bytes().replace(b'\r\n',b'\n')
 sys.path.insert(0,str(root/'app/hybrid_water'))
 class Input:
  def __init__(self,store,path):self.store,self.path=store,path
  def __truediv__(self,name):return Input(self.store,self.path+'/'+name)
  def read_text(self,encoding='utf8'):return self.store.get(self.path).decode(encoding)
 def select(raw):
  node=next(n for n in ast.parse(raw).body if isinstance(n,ast.FunctionDef) and n.name=='selection');namespace=dict(Path=lambda value:value,re=re,math=math,date=date,POLICY='original-explicit-prescribed-head-flux-all-node-trial-v1');exec(compile(ast.Module(body=[node],type_ignores=[]),MODULE,'exec'),namespace);return namespace['selection']
 previous,current=select(old),select(new);stores={};observed=[]
 with ExitStack() as stack:
  class Store:
   def __init__(self,name):
    self.name=name;self.q=json.loads((proof/(name+'.json')).read_text());parts=self.q.get('parts',[dict(file=self.q['archive'],bytes=self.q['bytes'],sha256=self.q['sha256'])]);chunks=[]
    for part in parts:
     raw=(proof/part['file']).read_bytes();assert len(raw)==part['bytes'] and SHA(raw)==part['sha256'];chunks.append(raw)
    raw=b''.join(chunks);assert len(raw)==self.q['bytes'] and SHA(raw)==self.q['sha256'];self.z=stack.enter_context(zipfile.ZipFile(io.BytesIO(raw)));assert len(self.z.namelist())==len(set(self.z.namelist()))
   def get(self,name):
    raw=self.z.read(name);item=self.q['members'][name];assert len(raw)==item['bytes'] and SHA(raw)==item['sha256'];return raw
  def store(name):
   if name not in stores:stores[name]=Store(name)
   return stores[name]
  def observe(name,profile,inputs,input_archive=None):
   archive=store(name);source=store(input_archive or name);raw=source.get(inputs+'/swap.swp');text=raw.decode('cp1252');models=re.findall(r'(?mi)^[ \t]*IHWCKMODEL[ \t]*=[ \t]*([^!\r\n]*)',text);assert len(models)<=1 and (not models or all(int(value)==1 for value in models[0].split()))
   a,b=previous(Input(source,inputs),True),current(Input(source,inputs),True);assert a==b and a is not None
   result=archive.get(profile+'/RESULT.json');q=json.loads(result)
   if 'input_inventory' in q:assert dict(q['input_inventory'])['swap.swp']==SHA(raw)
   observed.append(dict(archive=name,archive_sha256=archive.q['sha256'],profile=profile,actual_prior_RESULT_sha256=SHA(result),actual_input_archive=input_archive or name,actual_swap_swp_sha256=SHA(raw),actual_original_model1_or_implicit_default=True,old_bounded_selection=a,new_bounded_selection=b,semantics_exact=True))
  name='EXPLICIT_BOTTOM9_WINDOWS_RAW_V1';q=store(name).q
  for role in q['roles']+q['water_controls']:observe(name,role['profile'],role['inputs'])
  for opt in ('O0','O2'):
   name='EXPLICIT_BOTTOM9_UBUNTU_'+opt+'_RAW_V1'
   for case in store(name).q['cases']:
    profile='explicit-bottom9-'+case+'-'+opt+'-short';q=json.loads(store(name).get(profile+'/RESULT.json'));assert q['input_root'].startswith('/home/runner/work/_temp/proof/');observe(name,profile,q['input_root'].split('/proof/',1)[1])
  name='EXPLICIT_BOTTOM9_LAST_NODE_WINDOWS_RAW_V1'
  for role in store(name).q['roles']:observe(name,role['profile'],role['inputs'],role['inputs_archive'])
  for opt in ('O0','O2'):
   name='EXPLICIT_BOTTOM9_LAST_NODE_UBUNTU_'+opt+'_RAW_V1';observe(name,'explicit-bottom9-water-last-node-drainage-'+opt+'-short','inputs/water-last-node-drainage-initial1')
  name='EXPLICIT_BOTTOM9_CDE_WINDOWS_RAW_V1'
  for role in store(name).q['roles']:observe(name,role['profile'],role['inputs'])
  for category,case in [('MONTHLY','cde-monthly'),('DRAIN','cde-distributed-subdaily')]:
   for opt in ('O0','O2'):
    name='EXPLICIT_BOTTOM9_CDE_UBUNTU_'+category+'_'+opt+'_RAW_V1';profile='explicit-bottom9-'+case+'-'+opt+'-short';q=json.loads(store(name).get(profile+'/RESULT.json'));assert q['input_root'].startswith('/home/runner/work/_temp/proof/');observe(name,profile,q['input_root'].split('/proof/',1)[1])
 assert len(observed)==60 and len({(q['archive'],q['profile']) for q in observed})==60
 return dict(status='ALL60_QUALIFIED_PRIOR_PAIRED9_ACTUAL_INPUTS_HAVE_EXACT_UNCHANGED_SELECTION_UNDER_ANALYTICAL_EXTENSION',old_selection_source=OLD,new_selection_source=NEW,whole_old_module_sha256=SHA(old),whole_new_module_sha256=SHA(new),only_changed_APP_SRC_function='selection',all_other_APP_SRC_TOOL_REFERENCE_bytes_exact=True,all_non9_routes_return_before_modified_guard=True,observations=observed,actual_prior_native_bindings_or_producers_rewritten=False,compiler_executions=0,model_executions=0,canonical_admission=False)

if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--root',type=Path,default=ROOT);p.add_argument('--proof',type=Path);p.add_argument('--output',type=Path,required=True);a=p.parse_args();q=audit(a.root,a.proof or a.root/'integration/f-ci/nomacro-complete01')
 with a.output.open('x') as out:json.dump(q,out,indent=2);out.write('\n')
 print(q['status'],len(q['observations']))
