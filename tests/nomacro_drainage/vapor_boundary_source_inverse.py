"""Bind native5 composition and extend source-only predicates of literal owners."""
import ast,os
from contextlib import contextmanager
from ordinary_pond_verify import ROOT,blob,norm,git,SURFACES
import analytical_calendar_source_inverse as calendar
import snow_vapor_source_inverse as snow
import snow_vapor_inherited_owner as initial
BASE='70bae8871ec71b3c0969a6628cae596354f9c2e8'
CORE='9cde60cff60e1a0b2d4a21019e69eefb1007bd8b'
PORTABLE='69710a9453365da25015d28b79ceaaeb0a50c152'
WORKFLOW='.github/workflows/nomacro-water-snow-groundwater.yml'
CHANGED={'app/hybrid_water/cde_native_receipt.py':{'metadata','decode'},'app/hybrid_water/hydraulic_vapor.py':{'selection','metadata','native_magic','native_provider'},'app/hybrid_water/model7_terminal_water.py':{'enabled','source','head_parent_inverse','metadata','apply_build','validate'},'app/hybrid_water/original_output.py':{'selection'},'app/hybrid_water/vapor_boundary_composition.py':None}


def complete_inverse():
 assert not git('diff',CORE,'--',*SURFACES),'Unreviewed vapor boundary source delta'
 changes=git('diff','--name-status',BASE,CORE,'--',*SURFACES).decode().splitlines();assert set(changes)=={('A' if names is None else 'M')+'\t'+path for path,names in CHANGED.items()}
 for path,names in CHANGED.items():
  after=norm((ROOT/path).read_bytes());assert after==blob(CORE,path)
  if names is None:continue
  before=blob(BASE,path)
  functions=lambda raw:{n.name:ast.dump(n,include_attributes=False) for n in ast.parse(raw).body if isinstance(n,ast.FunctionDef)}
  a,b=functions(before),functions(after);assert {k for k in a.keys()|b.keys() if a.get(k)!=b.get(k)}==names
  outside=lambda raw:ast.dump(ast.Module(body=[n for n in ast.parse(raw).body if not isinstance(n,ast.FunctionDef)],type_ignores=[]),include_attributes=False)
  assert outside(before)==outside(after)
 # The new prefix alone reaches the new CDE offset reader. All old3/4 stock
 # decoding remains literally identical, including every old rejection.
 path='app/hybrid_water/cde_native_receipt.py';function=lambda raw:next(n for n in ast.parse(raw).body if isinstance(n,ast.FunctionDef) and n.name=='decode');current=function(blob(CORE,path));old=function(blob(BASE,path));branch=[n for n in current.body if isinstance(n,ast.If) and ast.unparse(n.test)=="aux[:8] == b'S5HBC005'"];assert len(branch)==1;current.body.remove(branch[0]);assert ast.dump(current,include_attributes=False)==ast.dump(old,include_attributes=False)
 assert norm((ROOT/WORKFLOW).read_bytes())==blob(PORTABLE,WORKFLOW)
 return True


class SourceFile:
 def __init__(self,path):self.path=path
 def read_bytes(self):return blob(BASE,self.path)
 def read_text(self,encoding='utf8'):return self.read_bytes().decode(encoding)
 def __fspath__(self):return os.fspath(ROOT/self.path)
 def __str__(self):return str(ROOT/self.path)


class CheckedSourceRoot:
 def __truediv__(self,path):
  return SourceFile(str(path)) if str(path) in ({p for p in CHANGED if CHANGED[p] is not None}|{WORKFLOW}) else ROOT/path
 def __fspath__(self):return os.fspath(ROOT)
 def __str__(self):return str(ROOT)


def calendar_complete_inverse():
 raw=blob(BASE,'tests/nomacro_drainage/analytical_calendar_source_inverse.py');nodes=[n for n in ast.parse(raw).body if isinstance(n,ast.FunctionDef) and n.name=='complete_inverse'];assert len(nodes)==1
 function=nodes[0];assert isinstance(function.body[0],ast.Assert) and ast.unparse(function.body[0].test)=="not git('diff', CORE, '--', *SURFACES)";function.body[0]=ast.parse('boundary_complete_inverse()').body[0]
 namespace=dict(vars(calendar),ROOT=CheckedSourceRoot(),boundary_complete_inverse=complete_inverse)
 exec(compile(ast.fix_missing_locations(ast.Module(body=nodes,type_ignores=[])),'qualified-calendar-source-inverse','exec'),namespace);return namespace['complete_inverse']()


def initial_source_inverse():
 complete_inverse();calendar.snow_complete_inverse()
 import signed_hydraulic_inherited_owner as original
 start=original.original.INITIAL
 previous=set(git('diff','--name-only',start,BASE,'--',*SURFACES).decode().splitlines());actual=set(git('diff','--name-only',start,'HEAD','--',*SURFACES).decode().splitlines())
 assert actual==previous|set(CHANGED),(actual,previous)
 assert norm((ROOT/original.PATH).read_bytes())==blob(BASE,original.PATH)
 return True


@contextmanager
def prior_source_projection():
 complete_inverse()
 # Views affect only four changed Python source files and the workflow.
 # Scientific data, actual current decoder calls, producer identity and Git
 # HEAD/tree are never rebound. The old initial-source union is checked against
 # the true actual HEAD after proving the complete new dependency surface.
 saved=(calendar.ROOT,calendar.complete_inverse,calendar.initial_source_inverse,snow.ROOT,initial.ROOT)
 calendar.ROOT=CheckedSourceRoot();calendar.complete_inverse=calendar_complete_inverse;calendar.initial_source_inverse=initial_source_inverse;snow.ROOT=CheckedSourceRoot();initial.ROOT=CheckedSourceRoot()
 try:
  with calendar.prior_source_projection():yield
 finally:calendar.ROOT,calendar.complete_inverse,calendar.initial_source_inverse,snow.ROOT,initial.ROOT=saved
