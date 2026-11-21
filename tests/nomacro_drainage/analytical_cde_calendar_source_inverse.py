"""Bind calendar composition and retain the actual prior source succession."""
import ast,os,subprocess
from contextlib import contextmanager
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
BASE='5c0cba9fbbd93ffb482199016f392e53e371e095'
CORE='379673548d90b13421b5b1e2db6e928c676b11ed'
PORTABLE='cbced0e1de4eb354dca0a2eecf4e1c9044259b18'
WORKFLOW='.github/workflows/nomacro-water-snow-groundwater.yml'
SURFACES=('app','src','tools/solute','tools/vq','reference')
CHANGED={
 'app/hybrid_water/analytical_cde_calendar.py':None,
 'app/hybrid_water/cde_clock_output.py':{'active_selection','magic','render_integral','apply_build'},
 'app/hybrid_water/cde_interval_output.py':{'active_selection','magic'},
 'app/hybrid_water/cde_native_receipt.py':{'metadata','decode'},
 'app/hybrid_water/hydraulic_vapor.py':{'selection','metadata','native_magic','native_provider'},
 'app/hybrid_water/model7_terminal_water.py':{'clock_selection','head_parent_inverse','metadata'}}
CI=('.github/workflows/mc-sol01-column-input.yml','.github/workflows/mc-sol01-swp-reader.yml')
PATTERN='            /integration/f-ci/nomacro-complete01/ANALYTICAL_CDE_CALENDAR*\n'
git=lambda *a:subprocess.check_output(['git',*a],cwd=ROOT)
blob=lambda sha,path:git('show',sha+':'+path)
norm=lambda raw:raw.replace(b'\r\n',b'\n')


def complete_inverse(check_ci=True):
 assert not git('diff',CORE,'--',*SURFACES),'Unreviewed analytical CDE calendar composition source delta'
 assert set(git('diff','--name-status',BASE,CORE,'--',*SURFACES).decode().splitlines())=={('A' if names is None else 'M')+'\t'+path for path,names in CHANGED.items()}
 for path,names in CHANGED.items():
  after=norm((ROOT/path).read_bytes());assert after==blob(CORE,path)
  if names is None:continue
  before=blob(BASE,path)
  functions=lambda raw:{n.name:ast.dump(n,include_attributes=False) for n in ast.parse(raw).body if isinstance(n,ast.FunctionDef)}
  a,b=functions(before),functions(after);assert {k for k in a.keys()|b.keys() if a.get(k)!=b.get(k)}==names
  outside=lambda raw:ast.dump(ast.Module(body=[n for n in ast.parse(raw).body if not isinstance(n,ast.FunctionDef)],type_ignores=[]),include_attributes=False)
  assert outside(before)==outside(after),'Old native constants, guards or numerical search changed'
 # Removing the one typed new-prefix branch must restore the entire old CDE
 # receipt function, including every existing shape and stock rejection.
 path='app/hybrid_water/cde_native_receipt.py'
 function=lambda raw:next(n for n in ast.parse(raw).body if isinstance(n,ast.FunctionDef) and n.name=='decode')
 current=function(blob(CORE,path));before=function(blob(BASE,path))
 branches=[n for n in current.body if isinstance(n,ast.If) and ast.unparse(n.test)=="aux[:8] == b'S5HCC006'"];assert len(branches)==1
 current.body.remove(branches[0]);assert ast.dump(current,include_attributes=False)==ast.dump(before,include_attributes=False)
 # These complete process/state sources are outside the changed surface.
 for name in ('hydraulic_vapor_native.f90','cde_interval_output_state.f90','vapor_boundary_composition.py','terminal_water_receipt.f90'):
  path='app/hybrid_water/'+name;assert norm((ROOT/path).read_bytes())==blob(BASE,path)
 assert norm((ROOT/WORKFLOW).read_bytes())==blob(PORTABLE,WORKFLOW)
 if check_ci:
  for path in CI:
   raw=norm((ROOT/path).read_bytes()).decode();assert raw.count(PATTERN)==1 and raw.replace(PATTERN,'',1).encode()==blob(BASE,path),'Unreviewed CDE calendar proof checkout delta'
 return True


class SourceFile:
 def __init__(self,path):self.path=path
 def read_bytes(self):return blob(BASE,self.path)
 def read_text(self,encoding='utf8'):return self.read_bytes().decode(encoding)
 def __fspath__(self):return os.fspath(ROOT/self.path)
 def __str__(self):return str(ROOT/self.path)


class CheckedSourceRoot:
 def __truediv__(self,path):return SourceFile(str(path)) if str(path) in (set(CHANGED)|{WORKFLOW,*CI}) else ROOT/path
 def __fspath__(self):return os.fspath(ROOT)
 def __str__(self):return str(ROOT)


def state_parent_complete_inverse():
 import initial_state_composition_source_inverse as state
 path='tests/nomacro_drainage/initial_state_composition_source_inverse.py'
 raw=blob(BASE,path);assert norm((ROOT/path).read_bytes())==raw
 nodes=[n for n in ast.parse(raw).body if isinstance(n,ast.FunctionDef) and n.name=='complete_inverse'];assert len(nodes)==1
 function=nodes[0];assert isinstance(function.body[0],ast.Assert) and ast.unparse(function.body[0].test)=="not git('diff', CORE, '--', *SURFACES)"
 function.body[0]=ast.parse('calendar_complete_inverse()').body[0]
 namespace=dict(vars(state),ROOT=CheckedSourceRoot(),calendar_complete_inverse=complete_inverse)
 exec(compile(ast.fix_missing_locations(ast.Module(body=nodes,type_ignores=[])),path,'exec'),namespace)
 return namespace['complete_inverse']()


def state_parent_source_union():
 import initial_state_composition_source_inverse as state
 path='tests/nomacro_drainage/initial_state_composition_source_inverse.py'
 nodes=[n for n in ast.parse(blob(BASE,path)).body if isinstance(n,ast.FunctionDef) and n.name=='initial_parent_source_union'];assert len(nodes)==1
 found=[n for n in ast.walk(nodes[0]) if isinstance(n,ast.Constant) and n.value=='actual == previous | set(CHANGED) | STATE_PATHS'];assert len(found)==1
 found[0].value+=' | CALENDAR_PATHS'
 namespaces=[n for n in ast.walk(nodes[0]) if isinstance(n,ast.Assign) and any(isinstance(t,ast.Name) and t.id=='namespace' for t in n.targets)];assert len(namespaces)==1
 namespaces[0].value.keywords.append(ast.keyword(arg='CALENDAR_PATHS',value=ast.Name(id='CALENDAR_PATHS',ctx=ast.Load())))
 namespace=dict(vars(state),CALENDAR_PATHS=set(CHANGED))
 exec(compile(ast.fix_missing_locations(ast.Module(body=nodes,type_ignores=[])),path,'exec'),namespace)
 return namespace['initial_parent_source_union']()


def guard_parent_source():
 import initial_state_composition_verify as previous
 path='tests/nomacro_drainage/initial_state_composition_verify.py'
 nodes=[n for n in ast.parse(blob(BASE,path)).body if isinstance(n,ast.FunctionDef) and n.name=='guard_previous_source'];assert len(nodes)==1
 namespace=dict(vars(previous),complete_inverse=state_parent_complete_inverse)
 exec(compile(ast.Module(body=nodes,type_ignores=[]),path,'exec'),namespace)
 with prior_source_projection():return namespace['guard_previous_source']()


@contextmanager
def prior_source_projection():
 complete_inverse()
 import initial_state_composition_source_inverse as state
 saved=(state.ROOT,state.complete_inverse,state.CheckedParentRoot,state.initial_parent_source_union)
 class CheckedParentRoot(saved[2]):
  def __truediv__(self,path):return SourceFile(str(path)) if str(path) in CHANGED else super().__truediv__(path)
 state.ROOT=CheckedSourceRoot();state.complete_inverse=state_parent_complete_inverse;state.CheckedParentRoot=CheckedParentRoot;state.initial_parent_source_union=state_parent_source_union
 # Only checked Python/workflow source reads are projected. Real HEAD, raw
 # paths, producer identities, native payloads and original inputs stay actual.
 try:
  with state.prior_source_projection():yield
 finally:state.ROOT,state.complete_inverse,state.CheckedParentRoot,state.initial_parent_source_union=saved
