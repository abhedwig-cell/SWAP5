"""Check the complete explicit9 inverse before every literal parent SOURCE view."""
import ast,hashlib,json,os,re,subprocess,sys,time
from functools import cache
from contextlib import contextmanager
from pathlib import Path
R=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(R/'tests/nomacro_drainage'),str(R/'tests/nomacro_scheduled_subsurface'),str(R/'app/hybrid_water')]
from explicit_bottom9_source_inverse import BASE,CORE,MODULE,CDE_PATHS,complete_inverse,blob,git,norm
import initial_profile_age_groundwater_verify as joint
import initial_profile_groundwater_source_inverse as source
import initial_profile_groundwater_parent_projection as projection
PATHS={MODULE,*('app/hybrid_water/'+name for name in ('daily_coupling.py','daily_host.py','experimental_project.py','original_output.py'))}|CDE_PATHS
WORKFLOW='.github/workflows/nomacro-explicit-bottom9.yml'
WORKFLOW_SOURCE='edbd9ab51b7a87a896aa7b89ff1e2452304a11a4'
CI=projection.CI
PATTERN='            /integration/f-ci/nomacro-complete01/EXPLICIT_BOTTOM9*\n'

@cache
def immutable_parent_source(path):return blob(BASE,path)

class SourceFile:
 def __init__(self,path):self.path=path
 def read_bytes(self):assert self.path!=MODULE;return immutable_parent_source(self.path)
 def read_text(self,encoding='utf8'):return self.read_bytes().decode(encoding)

class CheckedParentRoot:
 def __truediv__(self,path):return SourceFile(str(path)) if str(path) in (PATHS-{MODULE})|set(CI) else R/path
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

def workflow_metadata_inverse():
 assert not git('ls-tree','--name-only',BASE,'--',WORKFLOW),'The added workflow must be absent from the actual predecessor'
 assert norm((R/WORKFLOW).read_bytes())==blob(WORKFLOW_SOURCE,WORKFLOW),'Unreviewed complete targeted workflow'
 for path in CI:
  raw=norm((R/path).read_bytes());assert raw.count(PATTERN.encode())==1 and raw.replace(PATTERN.encode(),b'',1)==blob(BASE,path),'Foreign whole CI workflow beyond the one declared sparse entry'
 assert set(git('diff','--name-only',BASE,'--','.github/workflows').decode().splitlines())=={WORKFLOW,*CI},'Foreign workflow delta beyond the complete declared addition and sparse entries'
 return True

def snow_workflow_literal(original,name,namespace):
 if name!='guard_previous_source':return original(name,namespace)
 import analytical_calendar_verify as calendar
 raw=blob(calendar.BASE,calendar.OLD)
 functions=[n for n in ast.parse(raw).body if isinstance(n,ast.FunctionDef) and n.name==name];assert len(functions)==1
 expected="set(git('diff', '--name-only', PARENT, '--', '.github/workflows').decode().splitlines()) == {*CI, WORKFLOW}"
 assertions=[n for n in ast.walk(functions[0]) if isinstance(n,ast.Assert) and ast.unparse(n.test)==expected];assert len(assertions)==1
 target=assertions[0].test.comparators[0];assert isinstance(target,ast.Set) and len(target.elts)==2
 before=ast.dump(functions[0],include_attributes=False)
 # Extend only this metadata domain after checking the complete new file.
 # The real Git delta and every remaining literal old SOURCE assertion run.
 target.elts.append(ast.Constant(WORKFLOW))
 added=target.elts.pop();assert ast.dump(functions[0],include_attributes=False)==before;target.elts.append(added)
 exec(compile(ast.fix_missing_locations(ast.Module(body=functions,type_ignores=[])),calendar.OLD,'exec'),namespace)
 return namespace[name]

@contextmanager
def immutable_source_reads():
 """Memoize byte-verified full-SHA source blobs during this proof only."""
 real=subprocess.check_output;values={}
 refs=['git','for-each-ref','--format=%(refname):%(objectname)','refs/replace']
 assert real(refs,cwd=R)==b'','Replacement refs cannot qualify immutable source caching'
 suffixes={'.py','.f90','.f','.for','.inc','.sh','.yml','.yaml'}
 def checked(args,*positional,**kwargs):
  eligible=(not positional and isinstance(args,(list,tuple)) and len(args)==3
   and list(args[:2])==['git','show'] and isinstance(args[2],str)
   and re.fullmatch('[0-9a-f]{40}:[^\r\n\x00]+',args[2]) is not None
   and Path(args[2].split(':',1)[1]).suffix.lower() in suffixes
   and set(kwargs)=={'cwd'} and os.path.normcase(os.path.abspath(os.fspath(kwargs['cwd'])))==os.path.normcase(str(R)))
  if not eligible:return real(args,*positional,**kwargs)
  target=args[2]
  if target not in values:
   raw=real(args,**kwargs)
   if len(raw)>2*1024*1024:return raw
   expected=real(['git','rev-parse',target],cwd=R).strip().decode('ascii')
   assert hashlib.sha1(b'blob '+str(len(raw)).encode()+b'\0'+raw).hexdigest()==expected,'Actual immutable Git source blob differs'
   values[target]=raw
  return values[target]
 subprocess.check_output=checked
 try:yield
 finally:
  subprocess.check_output=real
  assert real(refs,cwd=R)==b'','Replacement refs changed during immutable source reads'

@contextmanager
def prior_source_projection():
 complete_inverse();workflow_metadata_inverse();context=parent_context();bindings=[]
 import analytical_calendar_verify as calendar
 original_literal=calendar.literal
 # Views cover the fully inverted SOURCE files and the two exactly inverted
 # CI sparse entries. Native data, receipts, identities and Git queries stay.
 for module in list(sys.modules.values()):
  if module is None:continue
  filename=getattr(module,'__file__',None);root=getattr(module,'ROOT',None)
  if filename and not Path(filename).name.startswith('explicit_bottom9_') and Path(filename).is_relative_to(R/'tests') and isinstance(root,Path) and root==R:bindings.append((module,'ROOT',CheckedParentRoot()))
 for module in (source,projection,joint):bindings.append((module,'complete_inverse',groundwater_inverse))
 bindings.extend([(projection,'prior_source_projection',context),(joint,'prior_source_projection',context)])
 bindings.append((calendar,'literal',lambda name,namespace:snow_workflow_literal(original_literal,name,namespace)))
 saved=[(module,name,getattr(module,name)) for module,name,value in bindings]
 for module,name,value in bindings:setattr(module,name,value)
 try:
  with immutable_source_reads(),context():yield
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
