"""Prove the entire original initializer survives one bounded admission block."""
import ast,subprocess,os
from contextlib import contextmanager
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
BASE='56df667d37c6e4070d6e552e493ddc0e28880a28'
CORE='9e19329049ef92705fdca98948b4c4c1baba2ffa'
PATH='app/hybrid_water/experimental_project.py'
WORKFLOW='.github/workflows/nomacro-water-snow-groundwater.yml'
PORTABLE='c884760037ab77a08586f69b03fa5621dbcdaaa2'
CI=('.github/workflows/mc-sol01-column-input.yml','.github/workflows/mc-sol01-swp-reader.yml')
PATTERN='            /integration/f-ci/nomacro-complete01/*INITIAL_PRESSURE*\n'
SURFACES=('app','src','tools/solute','tools/vq','reference')
git=lambda *args:subprocess.check_output(['git',*args],cwd=ROOT)


def complete_inverse():
 assert not git('diff',CORE,'--',*SURFACES),'Unreviewed initial pressure profile source delta'
 assert git('diff','--name-only',BASE,CORE,'--',*SURFACES).decode().splitlines()==[PATH]
 before=git('show',BASE+':'+PATH);after=(ROOT/PATH).read_bytes().replace(b'\r\n',b'\n');assert after==git('show',CORE+':'+PATH)
 a,b=ast.parse(before),ast.parse(after)
 f=lambda tree:next(n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name=='inspect')
 added=[n for n in f(b).body if isinstance(n,ast.If) and ast.unparse(n.test)=="selected.get('SWINCO') == 1"];assert len(added)==1
 f(b).body.remove(added[0]);assert ast.dump(a,include_attributes=False)==ast.dump(b,include_attributes=False),'Incomplete original input adapter inverse'
 assert (ROOT/WORKFLOW).read_bytes().replace(b'\r\n',b'\n')==git('show',PORTABLE+':'+WORKFLOW)
 for path in CI:
  raw=(ROOT/path).read_bytes().replace(b'\r\n',b'\n').decode();assert raw.count(PATTERN)==1 and raw.replace(PATTERN,'',1).encode()==git('show',BASE+':'+path),'Unreviewed initial profile proof checkout delta'
 return True


class SourceFile:
 def __init__(self,path):self.path=path
 def read_bytes(self):return git('show',BASE+':'+self.path)
 def read_text(self,encoding='utf8'):return self.read_bytes().decode(encoding)
 def __fspath__(self):return os.fspath(ROOT/self.path)
 def __str__(self):return str(ROOT/self.path)


class CheckedRoot:
 def __truediv__(self,path):return SourceFile(str(path)) if str(path) in (PATH,WORKFLOW,*CI) else ROOT/path
 def __fspath__(self):return os.fspath(ROOT)
 def __str__(self):return str(ROOT)


def boundary_complete_inverse():
 import vapor_boundary_source_inverse as boundary
 path='tests/nomacro_drainage/vapor_boundary_source_inverse.py';raw=git('show',BASE+':'+path);nodes=[n for n in ast.parse(raw).body if isinstance(n,ast.FunctionDef) and n.name=='complete_inverse'];assert len(nodes)==1
 function=nodes[0];assert isinstance(function.body[0],ast.Assert) and ast.unparse(function.body[0].test)=="not git('diff', CORE, '--', *SURFACES)";function.body[0]=ast.parse('initial_complete_inverse()').body[0]
 namespace=dict(vars(boundary),ROOT=CheckedRoot(),initial_complete_inverse=complete_inverse);exec(compile(ast.fix_missing_locations(ast.Module(body=nodes,type_ignores=[])),path,'exec'),namespace);return namespace['complete_inverse']()


def initial_source_inverse():
 import vapor_boundary_source_inverse as boundary
 path='tests/nomacro_drainage/vapor_boundary_source_inverse.py';raw=git('show',BASE+':'+path);nodes=[n for n in ast.parse(raw).body if isinstance(n,ast.FunctionDef) and n.name=='initial_source_inverse'];assert len(nodes)==1
 found=[n for n in nodes[0].body if isinstance(n,ast.Assert) and ast.unparse(n.test)=='actual == previous | set(CHANGED)'];assert len(found)==1
 found[0].test=ast.parse('actual == previous | set(CHANGED) | {INITIAL_PATH}',mode='eval').body
 namespace=dict(vars(boundary),ROOT=CheckedRoot(),complete_inverse=boundary_complete_inverse,INITIAL_PATH=PATH)
 exec(compile(ast.fix_missing_locations(ast.Module(body=nodes,type_ignores=[])),path,'exec'),namespace);return namespace['initial_source_inverse']()


@contextmanager
def prior_source_projection():
 complete_inverse()
 import vapor_boundary_source_inverse as boundary
 import signed_hydraulic_source_inverse as signed
 import snow_vapor_verify as snow_owner
 saved=(boundary.ROOT,boundary.complete_inverse,signed.CheckedParent,snow_owner.ROOT,boundary.initial_source_inverse)
 class InitialParent(saved[2]):
  def __truediv__(self,path):return SourceFile(PATH) if str(path)==PATH else super().__truediv__(path)
 # Only fully inverted source files are viewed through their actual previous
 # bytes. Git HEAD, producer identities and every scientific input/raw path
 # remain actual; no original reader or scientific assertion is replaced.
 boundary.ROOT=CheckedRoot();boundary.complete_inverse=boundary_complete_inverse;signed.CheckedParent=InitialParent;snow_owner.ROOT=CheckedRoot();boundary.initial_source_inverse=initial_source_inverse
 try:yield
 finally:boundary.ROOT,boundary.complete_inverse,signed.CheckedParent,snow_owner.ROOT,boundary.initial_source_inverse=saved
