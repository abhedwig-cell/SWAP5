"""Preserve actual AGE/Frost science after the whole new groundwater inverse."""
import ast,os
from contextlib import contextmanager
from initial_profile_groundwater_source_inverse import ROOT,BASE,CORE,ADAPTER,SELECTOR,complete_inverse,git,blob,norm
AGE_SEALED='354b6c9b792bed3a5cb0d10de96393d2568163f8'
FROST='06e980f4bb17e43e4cc61cf4fc2d6ea17204526d'
AGE_PORTABLE='86f3cdc1c87ee731676967f10a491ee801942238'
PORTABLE=AGE_PORTABLE
WORKFLOW='.github/workflows/nomacro-water-snow-groundwater.yml'
CI=('.github/workflows/mc-sol01-column-input.yml','.github/workflows/mc-sol01-swp-reader.yml')
PATTERN='            /integration/f-ci/nomacro-complete01/INITIAL_PROFILE_*\n'


class SourceFile:
 def __init__(self,ref,path):self.ref,self.path=ref,path
 def read_bytes(self):return blob(self.ref,self.path)
 def read_text(self,encoding='utf8'):return self.read_bytes().decode(encoding)


class AgePhysicalRoot:
 def __truediv__(self,path):return SourceFile(BASE,str(path)) if str(path)==ADAPTER else ROOT/path
 def __fspath__(self):return os.fspath(ROOT)
 def __str__(self):return str(ROOT)


class AgeMetadataRoot:
 def __truediv__(self,path):
  if str(path)==WORKFLOW:return SourceFile(AGE_PORTABLE,str(path))
  if str(path) in CI:return SourceFile(FROST,str(path))
  return ROOT/path
 def __fspath__(self):return os.fspath(ROOT)
 def __str__(self):return str(ROOT)


def age_complete_inverse():
 complete_inverse()
 import initial_profile_age_source_inverse as previous
 path='tests/nomacro_drainage/initial_profile_age_source_inverse.py';raw=blob(AGE_SEALED,path);assert norm((ROOT/path).read_bytes())==raw
 functions=[node for node in ast.parse(raw).body if isinstance(node,ast.FunctionDef) and node.name=='complete_inverse'];assert len(functions)==1
 first=functions[0].body[0];assert isinstance(first,ast.Assert) and ast.unparse(first.test)=="not git('diff', CORE, '--', *SURFACES)"
 functions[0].body[0]=ast.parse('groundwater_complete_inverse()').body[0]
 namespace=dict(vars(previous),ROOT=AgePhysicalRoot(),groundwater_complete_inverse=complete_inverse)
 exec(compile(ast.fix_missing_locations(ast.Module(body=functions,type_ignores=[])),path,'exec'),namespace);return namespace['complete_inverse']()


def source_metadata_inverse():
 complete_inverse();assert norm((ROOT/WORKFLOW).read_bytes())==blob(PORTABLE,WORKFLOW)
 for path in CI:
  actual=norm((ROOT/path).read_bytes());assert actual.count(PATTERN.encode()) in (0,1) and actual.replace(PATTERN.encode(),b'')==blob(FROST,path)
 return True


@contextmanager
def prior_source_projection():
 source_metadata_inverse()
 import initial_profile_age_source_inverse as source
 import initial_profile_age_parent_projection as projection
 import initial_profile_age_science as science
 import initial_profile_age_central_science as central
 import initial_profile_age_preserve as preserve
 path='tests/nomacro_drainage/initial_profile_age_parent_projection.py';raw=blob(AGE_SEALED,path);assert norm((ROOT/path).read_bytes())==raw
 functions=[node for node in ast.parse(raw).body if isinstance(node,ast.FunctionDef) and node.name=='prior_source_projection'];assert len(functions)==1
 class AddGroundwater(ast.NodeTransformer):
  expressions=0;namespaces=0
  def visit_Constant(self,node):
   if node.value=='source.CHANGED | {SELECTOR, AGE_SELECTOR}':self.expressions+=1;return ast.copy_location(ast.Constant('source.CHANGED | {SELECTOR, AGE_SELECTOR, GW_SELECTOR}'),node)
   return node
  def visit_Call(self,node):
   node=self.generic_visit(node)
   if isinstance(node.func,ast.Name) and node.func.id=='dict' and any(key.arg=='AGE_SELECTOR' for key in node.keywords):
    assert {key.arg for key in node.keywords}=={'ROOT','complete_inverse','AGE_SELECTOR'};self.namespaces+=1;node.keywords.append(ast.keyword(arg='GW_SELECTOR',value=ast.Name(id='GW_SELECTOR',ctx=ast.Load())))
   return node
 changes=AddGroundwater();functions[0]=changes.visit(functions[0]);assert changes.expressions==changes.namespaces==1
 namespace=dict(vars(projection),ROOT=AgeMetadataRoot(),complete_inverse=age_complete_inverse,GW_SELECTOR=SELECTOR)
 exec(compile(ast.fix_missing_locations(ast.Module(body=functions,type_ignores=[])),path,'exec'),namespace)
 context=namespace['prior_source_projection']
 bindings=[(module,'complete_inverse',age_complete_inverse) for module in (source,projection,science,central,preserve)]
 bindings.extend([(projection,'ROOT',AgeMetadataRoot()),(central,'ROOT',AgePhysicalRoot())])
 saved=[(module,name,getattr(module,name)) for module,name,value in bindings]
 for module,name,value in bindings:setattr(module,name,value)
 try:
  with context():yield
 finally:
  for module,name,value in reversed(saved):setattr(module,name,value)


def guard_parent_source():
 import initial_profile_frost_verify as frost
 with prior_source_projection():return frost.guard_previous_source()
