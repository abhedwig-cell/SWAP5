"""Compose checked source views while keeping actual heads, producers and raw bytes."""
import ast,os,types
from contextlib import contextmanager
from initial_profile_frost_source_inverse import ROOT,BASE,CORE,ADAPTER,SELECTOR,complete_inverse,git,blob,norm
PARENT='2de490869d688fd2eff0721b7d466d67956fc654'
PORTABLE='a755331a7444395d932f22b634520b64077e1a6d'
WORKFLOW='.github/workflows/nomacro-water-snow-groundwater.yml'
CI=('.github/workflows/mc-sol01-column-input.yml','.github/workflows/mc-sol01-swp-reader.yml')
PATTERN='            /integration/f-ci/nomacro-complete01/INITIAL_PROFILE_FROST*\n'


class SourceFile:
 def __init__(self,path):self.path=path
 def read_bytes(self):return blob(PARENT,self.path)
 def read_text(self,encoding='utf8'):return self.read_bytes().decode(encoding)


class CheckedParentRoot:
 def __truediv__(self,path):return SourceFile(str(path)) if str(path) in {ADAPTER,WORKFLOW,*CI} else ROOT/path
 def __fspath__(self):return os.fspath(ROOT)
 def __str__(self):return str(ROOT)


def profile_parent_complete_inverse():
 import initial_profile_calendar_source_inverse as previous
 complete_inverse();assert not git('diff',BASE,PARENT,'--',*previous.SURFACES),'Parent metadata repair changed physical source'
 assert norm((ROOT/WORKFLOW).read_bytes())==blob(PORTABLE,WORKFLOW),'Unreviewed original pressure/Frost portable workflow'
 for path in CI:
  actual=norm((ROOT/path).read_bytes());assert actual.count(PATTERN.encode()) in (0,1)
  assert actual.replace(PATTERN.encode(),b'')==blob(PARENT,path),'Unreviewed Frost proof checkout delta'
 path='tests/nomacro_drainage/initial_profile_calendar_source_inverse.py';raw=blob(PARENT,path);assert norm((ROOT/path).read_bytes())==raw
 nodes=[n for n in ast.parse(raw).body if isinstance(n,ast.FunctionDef) and n.name=='complete_inverse'];assert len(nodes)==1
 function=nodes[0];assert isinstance(function.body[0],ast.Assert) and ast.unparse(function.body[0].test)=="not git('diff', CORE, '--', *SURFACES)"
 function.body[0]=ast.parse('frost_complete_inverse()').body[0]
 namespace=dict(vars(previous),ROOT=CheckedParentRoot(),frost_complete_inverse=complete_inverse)
 exec(compile(ast.fix_missing_locations(ast.Module(body=nodes,type_ignores=[])),path,'exec'),namespace)
 return namespace['complete_inverse']()


@contextmanager
def prior_source_projection():
 profile_parent_complete_inverse()
 import initial_profile_calendar_source_inverse as source
 import initial_profile_calendar_verify as owner
 import initial_profile_calendar_records as records
 import initial_profile_calendar_central_science as central
 saved=(source.complete_inverse,source.calendar_parent_source_union,records.frontend,central.frontend,owner.complete_inverse)
 source.complete_inverse=owner.complete_inverse=profile_parent_complete_inverse
 # Only the complete checked new selector joins the older actual source-set
 # equality. No Git command, producer identity or scientific input is projected.
 source.calendar_parent_source_union=types.FunctionType(saved[1].__code__,dict(saved[1].__globals__,CHANGED=source.CHANGED|{SELECTOR}),argdefs=saved[1].__defaults__)
 records.frontend=central.frontend=types.FunctionType(saved[2].__code__,dict(saved[2].__globals__,ROOT=CheckedParentRoot()),argdefs=saved[2].__defaults__)
 try:yield
 finally:source.complete_inverse,source.calendar_parent_source_union,records.frontend,central.frontend,owner.complete_inverse=saved


def guard_parent_source():
 import initial_profile_calendar_verify as owner
 with prior_source_projection():return owner.guard_previous_source()
