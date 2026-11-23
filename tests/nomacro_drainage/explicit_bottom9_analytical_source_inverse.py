"""Exact analytical admission inverse followed by every frozen explicit216 source guard."""
import ast,os,re,sys
from contextlib import contextmanager
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(ROOT/'tests/nomacro_drainage'),str(ROOT/'tests/nomacro_scheduled_subsurface'),str(ROOT/'app/hybrid_water')]
import explicit_bottom9_source_inverse as previous
import explicit_bottom9_parent_projection as workflow_parent
from explicit_bottom9_source_inverse import CDE_POLICY_CORE,BASE,CORE,HOST,MODULE,SURFACES,blob,norm,git
ANALYTICAL_CORE='9c9e35ca34c5831505425ed7546f58c311ecb8c0'
PARENT_CANDIDATE='02813169713f103b846ab95657e5c5f830bc77d4'
PARENT_PUBLIC='67d2636672921505ecb47f1c9f4c6ea27a451889'
ANALYTICAL_WORKFLOW='.github/workflows/nomacro-explicit-bottom9-analytical.yml'
ANALYTICAL_WORKFLOW_SOURCE='35e64e7da1a9ad0085fd6df2b3e32a3a8de18f8a'
ADDITION=" if models:\n  analytical=tuple(map(int,models[0].split()))\n  if not all(value in (1,3,4,5,6,7,8,9,10,11) for value in analytical):return None\n  if any(value!=1 for value in analytical):\n   if integer('SWSOLU') not in (0,1):return None\n   vapor=re.findall(r'(?mi)^[ \\t]*SWVAPOR[ \\t]*=[ \\t]*([^\\r\\n]+)',active)\n   if len(vapor)>1:return None\n   if vapor:\n    if re.fullmatch(r'[+-]?[0-9]+(?:[ \\t]+[+-]?[0-9]+)*[ \\t]*',vapor[0]) is None:return None\n    if any(int(token)!=0 for token in vapor[0].split()):return None\n"
OLD_MODEL_TEST="re.fullmatch(r'\\+?0*1(?:[ \\t]+\\+?0*1)*[ \\t]*',models[0]) is None"
NEW_MODEL_TEST="re.fullmatch(r'[+]?[0-9]+(?:[ \\t]+[+]?[0-9]+)*[ \\t]*',models[0]) is None"


def checked_analytical_delta():
 assert not git('diff',ANALYTICAL_CORE,'--',*SURFACES),'Unreviewed actual analytical paired9 execution source'
 assert git('diff','--name-only',CDE_POLICY_CORE,ANALYTICAL_CORE,'--',*SURFACES).decode().splitlines()==[MODULE]
 raw=norm((ROOT/MODULE).read_bytes());assert raw==blob(ANALYTICAL_CORE,MODULE)
 assert raw.count(ADDITION.encode())==1 and raw.count(NEW_MODEL_TEST.encode())==1
 restored=raw.replace(ADDITION.encode(),b'',1).replace(NEW_MODEL_TEST.encode(),OLD_MODEL_TEST.encode(),1)
 assert restored==blob(CDE_POLICY_CORE,MODULE),'Incomplete whole analytical selection inverse'
 functions=lambda value:{n.name:ast.dump(n,include_attributes=False) for n in ast.parse(value).body if isinstance(n,ast.FunctionDef)}
 before,after=functions(restored),functions(raw)
 assert before.keys()==after.keys() and {name for name in before if before[name]!=after[name]}=={'selection'}
 assert 'value in (1,3,4,5,6,7,8,9,10,11)'in ADDITION and "integer('SWSOLU') not in (0,1)"in ADDITION
 assert 'if any(int(token)!=0 for token in vapor[0].split()):return None'in ADDITION
 return True


def checked_workflow_extension():
 assert not git('ls-tree','--name-only',PARENT_PUBLIC,'--',ANALYTICAL_WORKFLOW),'The new workflow must be absent from actual parent216'
 assert norm((ROOT/ANALYTICAL_WORKFLOW).read_bytes())==blob(ANALYTICAL_WORKFLOW_SOURCE,ANALYTICAL_WORKFLOW),'Unreviewed whole analytical workflow'
 assert git('diff','--name-only',PARENT_PUBLIC,'--','.github/workflows').decode().splitlines()==[ANALYTICAL_WORKFLOW],'Extra workflow change beyond one complete checked addition'
 assert set(git('diff','--name-only',BASE,'--','.github/workflows').decode().splitlines())=={workflow_parent.WORKFLOW,*workflow_parent.CI,ANALYTICAL_WORKFLOW},'Foreign old/new workflow composition delta'
 return True


def workflow_inverse():
 path='tests/nomacro_drainage/explicit_bottom9_parent_projection.py';raw=blob(PARENT_PUBLIC,path);assert norm((ROOT/path).read_bytes())==raw
 node=next(n for n in ast.parse(raw).body if isinstance(n,ast.FunctionDef) and n.name=='workflow_metadata_inverse')
 matches=[i for i,n in enumerate(node.body) if isinstance(n,ast.Assert) and isinstance(n.msg,ast.Constant) and n.msg.value=='Foreign workflow delta beyond the complete declared addition and sparse entries'];assert len(matches)==1
 node.body[matches[0]]=ast.parse('assert checked_workflow_extension()').body[0]
 namespace=dict(vars(workflow_parent),checked_workflow_extension=checked_workflow_extension);exec(compile(ast.fix_missing_locations(ast.Module(body=[node],type_ignores=[])),path,'exec'),namespace)
 return namespace['workflow_metadata_inverse']


class SourceFile:
 def read_bytes(self):return blob(CDE_POLICY_CORE,MODULE)
 def read_text(self,encoding='utf8'):return self.read_bytes().decode(encoding)


class CheckedParentRoot:
 def __truediv__(self,path):return SourceFile() if str(path)==MODULE else ROOT/path
 def __fspath__(self):return os.fspath(ROOT)
 def __str__(self):return str(ROOT)


@contextmanager
def parent_source_context():
 checked_analytical_delta();path='tests/nomacro_drainage/explicit_bottom9_source_inverse.py';raw=blob(PARENT_CANDIDATE,path);assert norm((ROOT/path).read_bytes())==raw
 nodes=[n for n in ast.parse(raw).body if isinstance(n,ast.FunctionDef) and n.name=='checked_cde_delta'];assert len(nodes)==1
 first=nodes[0].body[0];assert isinstance(first,ast.Assert) and ast.unparse(first.test)=="not git('diff', CDE_POLICY_CORE, '--', *SURFACES)"
 # Replace only the predecessor's whole current-surface assertion with the
 # stricter full analytical inverse. Its every other literal guard executes.
 nodes[0].body[0]=ast.parse('checked_analytical_delta()').body[0]
 namespace=dict(vars(previous),ROOT=CheckedParentRoot(),checked_analytical_delta=checked_analytical_delta)
 exec(compile(ast.fix_missing_locations(ast.Module(body=nodes,type_ignores=[])),path,'exec'),namespace)
 saved=(previous.ROOT,previous.checked_cde_delta)
 inherited=workflow_parent.workflow_metadata_inverse;replacement=workflow_inverse();aliases=[]
 for module in list(sys.modules.values()):
  filename=getattr(module,'__file__',None) if module is not None else None
  if filename and Path(filename).is_relative_to(ROOT/'tests') and getattr(module,'workflow_metadata_inverse',None) is inherited:aliases.append((module,inherited))
 try:
  previous.ROOT=CheckedParentRoot();previous.checked_cde_delta=namespace['checked_cde_delta']
  for module,original in aliases:module.workflow_metadata_inverse=replacement
  yield
 finally:
  for module,original in reversed(aliases):module.workflow_metadata_inverse=original
  previous.ROOT,previous.checked_cde_delta=saved


def complete_inverse():
 with parent_source_context():return previous.complete_inverse()


def producer_epoch(sha):
 assert re.fullmatch('[0-9a-f]{40}',sha)
 if not git('diff',ANALYTICAL_CORE,sha,'--',*SURFACES):return 'analytical-paired'
 return previous.producer_epoch(sha)
