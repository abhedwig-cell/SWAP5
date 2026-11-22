"""Check the complete explicit9 inverse before every literal parent SOURCE view."""
import ast,json,os,sys,time
from functools import cache
from contextlib import contextmanager
from pathlib import Path
R=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(R/'tests/nomacro_drainage'),str(R/'tests/nomacro_scheduled_subsurface'),str(R/'app/hybrid_water')]
from explicit_bottom9_source_inverse import BASE,CORE,MODULE,complete_inverse,blob,git,norm
import initial_profile_age_groundwater_verify as joint
import initial_profile_groundwater_source_inverse as source
import initial_profile_groundwater_parent_projection as projection
PATHS={MODULE,*('app/hybrid_water/'+name for name in ('daily_coupling.py','daily_host.py','experimental_project.py','original_output.py'))}

@cache
def immutable_parent_source(path):return blob(BASE,path)

class SourceFile:
 def __init__(self,path):self.path=path
 def read_bytes(self):assert self.path!=MODULE;return immutable_parent_source(self.path)
 def read_text(self,encoding='utf8'):return self.read_bytes().decode(encoding)

class CheckedParentRoot:
 def __truediv__(self,path):return SourceFile(str(path)) if str(path) in PATHS-{MODULE} else R/path
 def __fspath__(self):return os.fspath(R)
 def __str__(self):return str(R)

def groundwater_inverse():
 complete_inverse();path='tests/nomacro_drainage/initial_profile_groundwater_source_inverse.py';raw=blob(BASE,path);assert norm((R/path).read_bytes())==raw
 nodes=[n for n in ast.parse(raw).body if isinstance(n,ast.FunctionDef) and n.name=='complete_inverse'];assert len(nodes)==1
 first=nodes[0].body[0];assert isinstance(first,ast.Assert) and ast.unparse(first.test)=="not git('diff', CORE, '--', *SURFACES)"
 nodes[0].body[0]=ast.parse('explicit9_inverse()').body[0]
 namespace=dict(vars(source),ROOT=CheckedParentRoot(),explicit9_inverse=complete_inverse)
 exec(compile(ast.fix_missing_locations(ast.Module(body=nodes,type_ignores=[])),path,'exec'),namespace)
 return namespace['complete_inverse']()

def parent_context():
 path='tests/nomacro_drainage/initial_profile_groundwater_parent_projection.py';raw=blob(BASE,path);assert norm((R/path).read_bytes())==raw
 function=next(n for n in ast.parse(raw).body if isinstance(n,ast.FunctionDef) and n.name=='prior_source_projection')
 text=ast.unparse(function)
 changes=[("source.CHANGED | {SELECTOR, AGE_SELECTOR, GW_SELECTOR}","source.CHANGED | {SELECTOR, AGE_SELECTOR, GW_SELECTOR} | BOT9_PATHS"),("node.keywords.append(ast.keyword(arg='GW_SELECTOR', value=ast.Name(id='GW_SELECTOR', ctx=ast.Load())))","node.keywords.append(ast.keyword(arg='GW_SELECTOR', value=ast.Name(id='GW_SELECTOR', ctx=ast.Load())))\n                node.keywords.append(ast.keyword(arg='BOT9_PATHS', value=ast.Name(id='BOT9_PATHS', ctx=ast.Load())))"),("GW_SELECTOR=SELECTOR)","GW_SELECTOR=SELECTOR, BOT9_PATHS=BOT9_PATHS)")]
 for old,new in changes:assert text.count(old)==1,(old,text.count(old));text=text.replace(old,new)
 namespace=dict(vars(projection),BOT9_PATHS=PATHS)
 exec(compile(text,path,'exec'),namespace)
 return namespace['prior_source_projection']

@contextmanager
def prior_source_projection():
 complete_inverse();context=parent_context();bindings=[]
 # Views affect only the four fully inverted SOURCE files. All native inputs,
 # archives, receipts, identities, Git calls and actual working directory stay.
 for module in list(sys.modules.values()):
  if module is None:continue
  filename=getattr(module,'__file__',None);root=getattr(module,'ROOT',None)
  if filename and not Path(filename).name.startswith('explicit_bottom9_') and Path(filename).is_relative_to(R/'tests') and isinstance(root,Path) and root==R:bindings.append((module,'ROOT',CheckedParentRoot()))
 for module in (source,projection,joint):bindings.append((module,'complete_inverse',groundwater_inverse))
 bindings.extend([(projection,'prior_source_projection',context),(joint,'prior_source_projection',context)])
 saved=[(module,name,getattr(module,name)) for module,name,value in bindings]
 for module,name,value in bindings:setattr(module,name,value)
 try:
  with context():yield
 finally:
  for module,name,value in reversed(saved):setattr(module,name,value)

if __name__=='__main__':
 started=time.perf_counter();before=git('rev-parse','HEAD').decode().strip()
 with prior_source_projection():assert joint.guard_previous_source()
 assert git('rev-parse','HEAD').decode().strip()==before
 q=dict(status='EXPLICIT9_WHOLE_SOURCE_INVERSE_AND_LITERAL_JOINT156_PARENT_SOURCE_GUARDS_PASS',actual_head=before,physical_core=CORE,parent_candidate=BASE,checked_new_source_paths=sorted(PATHS),seconds=time.perf_counter()-started,compiler_executions=0,model_executions=0,canonical_admission=False)
 out=Path(sys.argv[1])
 with out.open('x') as stream:json.dump(q,stream,indent=2);stream.write('\n')
 print(q['status'],q['seconds'],flush=True)
