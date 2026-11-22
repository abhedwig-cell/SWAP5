"""Replay literal admitted Frost/source observers after the complete AGE inverse."""
import ast,os,types
from contextlib import contextmanager
from initial_profile_age_source_inverse import ROOT,BASE,CORE,ADAPTER,SELECTOR,complete_inverse,git,blob,norm
WORKFLOW='.github/workflows/nomacro-water-snow-groundwater.yml'
CI=('.github/workflows/mc-sol01-column-input.yml','.github/workflows/mc-sol01-swp-reader.yml')
PATTERN='            /integration/f-ci/nomacro-complete01/INITIAL_PROFILE_AGE*\n'
PORTABLE='86f3cdc1c87ee731676967f10a491ee801942238'


class SourceFile:
 def __init__(self,path):self.path=path
 def read_bytes(self):return blob(BASE,self.path)
 def read_text(self,encoding='utf8'):return self.read_bytes().decode(encoding)


class CheckedParentRoot:
 def __truediv__(self,path):return SourceFile(str(path)) if str(path) in {ADAPTER,WORKFLOW,*CI} else ROOT/path
 def __fspath__(self):return os.fspath(ROOT)
 def __str__(self):return str(ROOT)


def frost_parent_complete_inverse():
 complete_inverse()
 import initial_profile_frost_source_inverse as previous
 path='tests/nomacro_drainage/initial_profile_frost_source_inverse.py';raw=blob(BASE,path);assert norm((ROOT/path).read_bytes())==raw
 functions=[node for node in ast.parse(raw).body if isinstance(node,ast.FunctionDef) and node.name=='complete_inverse'];assert len(functions)==1
 function=functions[0];assert isinstance(function.body[0],ast.Assert) and ast.unparse(function.body[0].test)=="not git('diff', CORE, '--', *SURFACES)"
 function.body[0]=ast.parse('age_complete_inverse()').body[0];namespace=dict(vars(previous),ROOT=CheckedParentRoot(),age_complete_inverse=complete_inverse)
 exec(compile(ast.fix_missing_locations(ast.Module(body=functions,type_ignores=[])),path,'exec'),namespace);return namespace['complete_inverse']()


def source_metadata_inverse():
 complete_inverse()
 assert norm((ROOT/WORKFLOW).read_bytes())==blob(PORTABLE,WORKFLOW)
 for path in CI:
  actual=norm((ROOT/path).read_bytes());assert actual.count(PATTERN.encode()) in (0,1) and actual.replace(PATTERN.encode(),b'')==blob(BASE,path)
 return True


@contextmanager
def prior_source_projection():
 source_metadata_inverse()
 import initial_profile_frost_source_inverse as source
 import initial_profile_frost_parent_projection as projection
 import initial_profile_frost_science as science
 import initial_profile_frost_central_science as central
 import initial_profile_frost_records as records
 import initial_profile_frost_verify as owner
 bindings=[(module,'complete_inverse',frost_parent_complete_inverse) for module in (source,projection,science,central,owner)]
 bindings.append((projection,'ROOT',CheckedParentRoot()))
 bindings += [(module,'frontend',types.FunctionType(records.frontend.__code__,dict(records.frontend.__globals__,ROOT=CheckedParentRoot()),argdefs=records.frontend.__defaults__)) for module in (records,central)]
 # Every nested predecessor context must add the fully checked AGE selector
 # to its actual source-set equality. Only this one source-union expression
 # changes; every literal older scientific body and all Git identities stay.
 path='tests/nomacro_drainage/initial_profile_frost_parent_projection.py';raw=blob(BASE,path);assert norm((ROOT/path).read_bytes())==raw
 functions=[node for node in ast.parse(raw).body if isinstance(node,ast.FunctionDef) and node.name=='prior_source_projection'];assert len(functions)==1
 class AddAGE(ast.NodeTransformer):
  count=0
  def visit_BinOp(self,node):
   if ast.unparse(node)=='source.CHANGED | {SELECTOR}':self.count+=1;return ast.copy_location(ast.parse('source.CHANGED | {SELECTOR, AGE_SELECTOR}',mode='eval').body,node)
   return self.generic_visit(node)
 change=AddAGE();functions[0]=change.visit(functions[0]);assert change.count==1
 namespace=dict(vars(projection),ROOT=CheckedParentRoot(),complete_inverse=frost_parent_complete_inverse,AGE_SELECTOR=SELECTOR)
 exec(compile(ast.fix_missing_locations(ast.Module(body=functions,type_ignores=[])),path,'exec'),namespace);context=namespace['prior_source_projection']
 bindings += [(module,'prior_source_projection',context) for module in (projection,owner)]
 saved=[(module,name,getattr(module,name)) for module,name,value in bindings]
 for module,name,value in bindings:setattr(module,name,value)
 try:yield
 finally:
  for module,name,value in reversed(saved):setattr(module,name,value)


def guard_parent_source():
 import initial_profile_frost_verify as owner
 with prior_source_projection():return owner.guard_previous_source()
