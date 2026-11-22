"""Prove the complete paired-boundary source through both literal predecessor inverses."""
import ast,os,re,subprocess
from functools import cache
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
BASE='8ae1661391ed35125421290de3fb5d95ec8cd5b5'
PRE_CLOCK='c0952e394647179d591a855fcaf1a7270871fb2b'
CLOCK_ONLY='4d4fb1b8e059f9137ec217e52f262222ead6ce1c'
CORE='7979888d70950b27c2fc30c92320ff5bb62d9a53'
FROZEN_CLOCK_HELPER='d905cad376b42e709c3bf7949dbc8faebf119f24'
MODULE='app/hybrid_water/prescribed_head_flux_boundary.py'
HOST='app/hybrid_water/daily_host.py'
SURFACES=('app','src','tools/solute','tools/vq','reference')
git=lambda *args:subprocess.check_output(['git',*args],cwd=ROOT)
norm=lambda raw:raw.replace(b'\r\n',b'\n')

@cache
def blob(ref,path):
 # Cache only immutable fully named Git objects. Current source reads, diffs,
 # heads, receipts and scientific data remain fresh on every assertion.
 assert re.fullmatch('[0-9a-f]{40}',ref)
 return git('show',ref+':'+path)

TRIAL_FUNCTION='\n\ndef render_output_trial(source,original,watstor):\n from age_output_clock import trial_receipt_source\n previous=trial_receipt_source(original,watstor)\n old="if(swmacro/=0.or.swsnow/=0.or.swdra/=1)error stop \'Foreign original trial receipt domain\'"\n new="if(swmacro/=0.or.swsnow/=0.or.swbotb/=9.or.swdra<0.or.swdra>1)error stop \'Foreign original trial receipt domain\'"\n if previous.count(old)!=1 or previous.count(\'implicit none\\n\')!=1 or source.count(previous)!=1:raise ValueError(\'Changed whole original paired-boundary output trial seam\')\n current=previous.replace(\'implicit none\\n\',\'use variables,only:swbotb\\nimplicit none\\n\',1).replace(old,new,1)\n return source.replace(previous,current,1)\n'
CLOCK_LATE="    if lower_boundary==9 and age_calendar and (age_calendar['nprintday']>1 or age_calendar['flprintdt']):\n        from prescribed_head_flux_boundary import render_timecontrol\n        path=output/'timecontrol.f90'\n        if 'timecontrol' not in patched or not path.is_file():raise ValueError('Missing actual original paired-boundary output clock owner')\n        path.write_text(render_timecontrol(path.read_text(encoding='cp1252')),encoding='cp1252')\n"
FINAL_LATE="    if lower_boundary==9 and age_calendar and (age_calendar['nprintday']>1 or age_calendar['flprintdt']):\n        from prescribed_head_flux_boundary import render_timecontrol,render_output_trial\n        integral=output/'integral.f90'\n        integral.write_text(render_output_trial(integral.read_text(encoding='cp1252'),\n            (donor_build/'swap-selected/integral.f90').read_text(encoding='cp1252'),\n            (donor_build/'swap-selected/watstor.f90').read_text(encoding='cp1252')),encoding='cp1252')\n        path=output/'timecontrol.f90'\n        if 'timecontrol' not in patched or not path.is_file():raise ValueError('Missing actual original paired-boundary output clock owner')\n        path.write_text(render_timecontrol(path.read_text(encoding='cp1252')),encoding='cp1252')\n"

def checked_final_delta():
 assert not git('diff',CORE,'--',*SURFACES),'Unreviewed final paired-boundary physical source'
 assert git('diff','--name-only',CLOCK_ONLY,CORE,'--',*SURFACES).decode().splitlines()==[HOST,MODULE]
 for path in (HOST,MODULE):assert norm((ROOT/path).read_bytes())==blob(CORE,path)
 assert blob(CORE,MODULE)==blob(CLOCK_ONLY,MODULE)+TRIAL_FUNCTION.encode(),'Foreign whole literal trial renderer append'
 text=blob(CORE,HOST).decode();assert text.count(FINAL_LATE)==1 and text.replace(FINAL_LATE,CLOCK_LATE,1).encode()==blob(CLOCK_ONLY,HOST),'Foreign output-clock-only builder composition'
 return True

class IntermediateFile:
 def __init__(self,path):self.path=path
 def read_bytes(self):return blob(CLOCK_ONLY,self.path)
 def read_text(self,encoding='utf8'):return self.read_bytes().decode(encoding)

class CheckedIntermediateRoot:
 def __truediv__(self,path):return IntermediateFile(str(path)) if str(path) in (HOST,MODULE) else ROOT/path
 def __fspath__(self):return os.fspath(ROOT)
 def __str__(self):return str(ROOT)

@cache
def frozen_clock_inverse():
 path='tests/nomacro_drainage/explicit_bottom9_source_inverse.py';raw=blob(FROZEN_CLOCK_HELPER,path)
 frozen=dict(__file__=str(ROOT/path));exec(compile(raw,path,'exec'),frozen)
 assert frozen['CORE']==CLOCK_ONLY and frozen['PRE_CLOCK']==PRE_CLOCK and frozen['BASE']==BASE
 nodes=[n for n in ast.parse(raw).body if isinstance(n,ast.FunctionDef) and n.name=='complete_inverse'];assert len(nodes)==1
 assertions=[(i,n) for i,n in enumerate(nodes[0].body) if isinstance(n,ast.Assert) and ast.unparse(n.test)=="not git('diff', CORE, '--', *SURFACES)"];assert len(assertions)==1
 # Replace only the predecessor's current-tree assertion with the complete
 # exact final inverse. Execute every remaining literal predecessor guard.
 i,_=assertions[0];nodes[0].body[i]=ast.parse('checked_final_delta()').body[0]
 namespace=dict(frozen,ROOT=CheckedIntermediateRoot(),git=git,blob=blob,checked_final_delta=checked_final_delta)
 exec(compile(ast.fix_missing_locations(ast.Module(body=nodes,type_ignores=[])),path,'exec'),namespace)
 return namespace['complete_inverse']

def complete_inverse():
 checked_final_delta()
 return frozen_clock_inverse()()

def producer_epoch(sha):
 for label,epoch in (('pre-clock',PRE_CLOCK),('clock-only',CLOCK_ONLY),('composed-clock',CORE)):
  if not git('diff',epoch,sha,'--',*SURFACES):return label
 raise AssertionError('Unreviewed actual explicit9 producer source')
