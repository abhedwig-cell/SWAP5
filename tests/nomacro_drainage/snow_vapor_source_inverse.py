"""Bind the complete Snow composition and expose checked prior source predicates."""
import ast,os
from contextlib import contextmanager
from ordinary_pond_verify import ROOT,git,blob,norm,SURFACES

PARENT='8e27dd9eb0f633050d2d82d00d28992435c313cb'
RUNTIME='6e77aeb829a45e1f1781a429f60e632ecaa316ea'
SEALED='8ef63dbd71678385d7681db5e18ed48cd1752a36'
CHANGED={
 'app/hybrid_water/cde_native_receipt.py':{'metadata','decode'},
 'app/hybrid_water/daily_host.py':{'build'},
 'app/hybrid_water/hydraulic_vapor.py':{'selection','metadata','native_magic','native_provider','apply_build','validate'},
 'app/hybrid_water/original_output_thermal.py':{'magic','metadata'},
 'app/hybrid_water/snow_vapor_composition.py':None}
CI=('.github/workflows/mc-sol01-column-input.yml','.github/workflows/mc-sol01-swp-reader.yml')
WORKFLOW='.github/workflows/nomacro-water-snow-groundwater.yml'
PATTERN='            /integration/f-ci/nomacro-complete01/*SNOW_VAPOR*\n'


def complete_inverse():
 assert not git('diff',RUNTIME,'--',*SURFACES),'Unreviewed Snow vapor source delta'
 changed=git('diff','--name-status',PARENT,RUNTIME,'--',*SURFACES).decode().splitlines()
 assert set(changed)=={('A' if functions is None else 'M')+'\t'+path for path,functions in CHANGED.items()}
 for path,allowed in CHANGED.items():
  after=norm((ROOT/path).read_bytes());assert after==blob(RUNTIME,path)
  if allowed is None:continue
  before=blob(PARENT,path)
  def functions(raw):return {n.name:ast.dump(n,include_attributes=False) for n in ast.parse(raw).body if isinstance(n,ast.FunctionDef)}
  a,b=functions(before),functions(after)
  assert {key for key in a.keys()|b.keys() if a.get(key)!=b.get(key)}==allowed,(path,allowed)
  outside=lambda raw:ast.dump(ast.Module(body=[n for n in ast.parse(raw).body if not isinstance(n,ast.FunctionDef)],type_ignores=[]),include_attributes=False)
  assert outside(before)==outside(after),'Unreviewed module-level Snow composition change'
 return True


class FrozenFile:
 def __init__(self,path):self.path=path
 def read_bytes(self):return blob(PARENT,self.path)
 def read_text(self,encoding='utf8'):return self.read_bytes().decode(encoding)
 def __fspath__(self):return os.fspath(ROOT/self.path)
 def __str__(self):return str(ROOT/self.path)


class CheckedParent:
 def __truediv__(self,path):return FrozenFile(str(path)) if str(path) in {*CHANGED,*CI,WORKFLOW} else ROOT/path
 def __fspath__(self):return os.fspath(ROOT)
 def __str__(self):return str(ROOT)


def initial_source_inverse():
 complete_inverse()
 import default_model_grammar_source_inverse as grammar
 import signed_hydraulic_inherited_owner as original
 initial=original.original.INITIAL
 previous={original.DECODER,original.PATH,*grammar.CHANGED}
 actual=git('diff','--name-only',initial,'HEAD','--',*SURFACES).decode().splitlines()
 assert actual==sorted(previous|set(CHANGED)),actual
 assert git('diff','--name-only',initial,PARENT,'--',*SURFACES).decode().splitlines()==sorted(previous)
 assert blob(PARENT,original.DECODER)==blob('daba94800',original.DECODER)
 assert norm((ROOT/original.PATH).read_bytes())==blob(PARENT,original.PATH)
 return True


@contextmanager
def prior_source_projection():
 complete_inverse()
 import default_model_grammar_source_inverse as previous
 old_root,old_git,old_initial=previous.ROOT,previous.git,previous.initial_source_inverse
 for path in CI:
  raw=norm((ROOT/path).read_bytes()).decode();assert raw.count(PATTERN)<=1 and raw.replace(PATTERN,'').encode()==blob(PARENT,path)
 assert norm((ROOT/WORKFLOW).read_bytes())==blob('1a1f2bc339403e4202df8decc7b22d0f8adc573e',WORKFLOW)
 assert not git('diff',previous.RUNTIME,PARENT,'--',*SURFACES)
 def checked_git(*args):
  if args==('diff',previous.RUNTIME,'--',*SURFACES):complete_inverse();return b''
  return git(*args)
 previous.ROOT=CheckedParent();previous.git=checked_git;previous.initial_source_inverse=initial_source_inverse
 try:yield
 finally:previous.ROOT=old_root;previous.git=old_git;previous.initial_source_inverse=old_initial
