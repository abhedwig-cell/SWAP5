"""Extend exact prior source predicates for one unchanged-process composition."""
import ast,types
from contextlib import contextmanager
from ordinary_pond_verify import ROOT,blob,norm,git,SURFACES
import snow_vapor_source_inverse as old
import snow_vapor_inherited_owner as inherited

BASE='bd9426711347a1bd7694d39e5c65345db0e25406'
CORE='102e95eb6d33107b81ab06576707fe0be9b215e2'
PATH='app/hybrid_water/model7_terminal_water.py'
WORKFLOW='.github/workflows/nomacro-water-snow-groundwater.yml'
PORTABLE='77874100b21f2db832d03adb4031a2da0ec3d9c6'


def complete_inverse():
 assert not git('diff',CORE,'--',*SURFACES),'Unreviewed analytical calendar source delta'
 assert git('diff','--name-only',BASE,CORE,'--',*SURFACES).decode().splitlines()==[PATH]
 before=blob(BASE,PATH);after=norm((ROOT/PATH).read_bytes());assert after==blob(CORE,PATH)
 a=ast.parse(before);b=ast.parse(after)
 functions=lambda tree:{n.name:ast.dump(n,include_attributes=False) for n in tree.body if isinstance(n,ast.FunctionDef)}
 x,y=functions(a),functions(b)
 assert {k for k in x.keys()|y.keys() if x.get(k)!=y.get(k)}=={'clock_selection','head_parent_inverse','metadata','apply_build','validate'}
 assert all(x[k]==y[k] for k in ('enabled','source'))
 # All old module literals, including both guards and the complete numerical
 # search operator, remain exact. The only additions describe the old clock.
 additions={'CLOCK_IMPORT','CLOCK_GUARD','CLOCK_PARENT_SHA'}
 outside=lambda tree:ast.dump(ast.Module(body=[n for n in tree.body if not isinstance(n,ast.FunctionDef) and not(isinstance(n,ast.Assign) and any(isinstance(t,ast.Name) and t.id in additions for t in n.targets))],type_ignores=[]),include_attributes=False)
 assert outside(a)==outside(b)
 assert norm((ROOT/WORKFLOW).read_bytes())==blob(PORTABLE,WORKFLOW)
 return True


def clone(name,namespace,replace=None):
 raw=blob(BASE,'tests/nomacro_drainage/snow_vapor_source_inverse.py');nodes=[n for n in ast.parse(raw).body if isinstance(n,ast.FunctionDef) and n.name==name];assert len(nodes)==1
 if replace:replace(nodes[0])
 exec(compile(ast.fix_missing_locations(ast.Module(body=nodes,type_ignores=[])),name,'exec'),namespace);return namespace[name]


def snow_complete_inverse():
 def replace(function):
  assert isinstance(function.body[0],ast.Assert) and ast.unparse(function.body[0].test)=="not git('diff', RUNTIME, '--', *SURFACES)"
  function.body[0]=ast.parse('calendar_complete_inverse()').body[0]
 namespace=dict(vars(old),calendar_complete_inverse=complete_inverse)
 return clone('complete_inverse',namespace,replace)()


def initial_source_inverse():
 def replace(function):
  found=[n for n in function.body if isinstance(n,ast.Assert) and ast.unparse(n.test)=='actual == sorted(previous | set(CHANGED))'];assert len(found)==1
  found[0].test=ast.parse('actual == sorted(previous | set(CHANGED) | {CALENDAR_PATH})',mode='eval').body
 namespace=dict(vars(old),complete_inverse=snow_complete_inverse,CALENDAR_PATH=PATH)
 return clone('initial_source_inverse',namespace,replace)()


class FrozenWorkflow:
 def read_bytes(self):return blob(BASE,WORKFLOW)


class CheckedRoot:
 def __truediv__(self,path):return FrozenWorkflow() if str(path)==WORKFLOW else ROOT/path


@contextmanager
def prior_source_projection():
 complete_inverse()
 # Clone the literal previous projection with its workflow-only source view.
 # Actual Git HEAD, producer fields and all scientific paths stay actual.
 namespace=dict(vars(old),ROOT=CheckedRoot(),complete_inverse=snow_complete_inverse,initial_source_inverse=initial_source_inverse)
 projection=clone('prior_source_projection',namespace)
 saved=inherited.initial_source_inverse;inherited.initial_source_inverse=initial_source_inverse
 try:
  with projection():yield
 finally:inherited.initial_source_inverse=saved
