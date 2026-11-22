"""Prove the complete paired-boundary source through both literal predecessor inverses."""
import ast,os,re,subprocess
from functools import cache
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
BASE='8ae1661391ed35125421290de3fb5d95ec8cd5b5'
PRE_CLOCK='c0952e394647179d591a855fcaf1a7270871fb2b'
CLOCK_ONLY='4d4fb1b8e059f9137ec217e52f262222ead6ce1c'
CORE='7979888d70950b27c2fc30c92320ff5bb62d9a53'
LAST_NODE_CORE='57bd7fecbbb6c3944b4f28cfc29cb368d371398a'
CDE_CORE='dcf509f80e77866b24ca06a021df3e3e53fd3ec0'
ADAPTER='app/hybrid_water/experimental_project.py'
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

OLD_DRAIN_GUARD="            if (path.resolve()!=frost_drain_file or sig.get('SWDIVD') not in (0,1)\n"
NEW_DRAIN_GUARD='''            paired_last_node_water=(paired_boundary is not None and selected['SWSOLU']==0
                and selected['SWDRA']==1 and sig.get('SWDIVD')==0
                and path.resolve()==(directory/(one(text,'PATHDRAIN',r"'[^']*'").strip("'").strip()
                    +one(text,'DRFIL',r"'[^']+'").strip("'")+'.dra')).resolve())
            if ((path.resolve()!=frost_drain_file and not paired_last_node_water) or sig.get('SWDIVD') not in (0,1)
'''

CDE_PATHS={HOST,MODULE,'app/hybrid_water/cde_clock_output.py','app/hybrid_water/cde_interval_output.py'}
CDE_APPEND="\n\nCDE_CLOCK_IMPORT='   use MOD_integral,only:hybrid_ordinary_trial_residual\\n'\nCDE_CLOCK_DECL='   real(8)::hybrid_cde_clock_trial_guard,hybrid_cde_clock_candidate_bottom\\n'\nCDE_CLOCK_GUARD='\\n         if(swbotb==8.and..not.flboth)then\\n            hybrid_cde_clock_candidate_bottom=0d0\\n         else\\n            hybrid_cde_clock_candidate_bottom=-kmean(NN+1)*hgrad(NN+1)\\n         end if\\n         hybrid_cde_clock_trial_guard=hybrid_ordinary_trial_residual(hybrid_cde_clock_candidate_bottom)\\n         if(abs(hybrid_cde_clock_trial_guard)>1d-10)flnonconv=.true.'\n\ndef render_cde_clock_headcalc(source):\n for old,new in ((CDE_CLOCK_IMPORT,'   use MOD_integral,only:hybrid_output_trial_residual\\n'),(CDE_CLOCK_DECL,''),(CDE_CLOCK_GUARD,'\\n         if(abs(hybrid_output_trial_residual())>1d-10)flnonconv=.true.')):\n  if source.count(old)!=1:raise ValueError('Changed whole original CDE clock trial seam')\n  source=source.replace(old,new,1)\n return source\n"
CDE_LATE="        if age_calendar.get('cde_clock_output'):\n            from prescribed_head_flux_boundary import render_cde_clock_headcalc\n            head=output/'headcalc.f90'\n            head.write_text(render_cde_clock_headcalc(head.read_text(encoding='cp1252')),encoding='cp1252')\n"
CDE_SELECT='    from prescribed_head_flux_boundary import selection as paired_selection\n    paired_bottom=bottom==9 and paired_selection(project.input_directory,project.original_output) is not None\n'
CDE_DICT="        **({'paired_head_flux_cde_calendar':True} if paired_bottom else {}),\n"

def source_before_cde(path,raw):
 if path==MODULE:
  assert raw.count(CDE_APPEND.encode())==1;return raw.replace(CDE_APPEND.encode(),b'',1)
 if path==HOST:
  assert raw.count(CDE_LATE.encode())==1;return raw.replace(CDE_LATE.encode(),b'',1)
 assert path in CDE_PATHS
 for new,old in ((CDE_SELECT,''),(CDE_DICT,''),('    if bottom not in (1,5,8) and not paired_bottom:','    if bottom not in (1,5,8):'),('    if bottom!=1 and drainage!=1 and not paired_bottom:','    if bottom!=1 and drainage!=1:')):
  assert raw.count(new.encode())==1;raw=raw.replace(new.encode(),old.encode(),1)
 return raw


def checked_cde_delta():
 assert not git('diff',CDE_CORE,'--',*SURFACES),'Unreviewed actual CDE paired-calendar composition source'
 assert set(git('diff','--name-only',LAST_NODE_CORE,CDE_CORE,'--',*SURFACES).decode().splitlines())==CDE_PATHS
 functions=lambda value:{n.name:ast.dump(n,include_attributes=False) for n in ast.parse(value).body if isinstance(n,ast.FunctionDef)}
 for path in CDE_PATHS:
  raw=norm((ROOT/path).read_bytes());assert raw==blob(CDE_CORE,path)
  assert source_before_cde(path,raw)==blob(LAST_NODE_CORE,path),'Incomplete whole CDE calendar source inverse: '+path
  before,after=functions(blob(LAST_NODE_CORE,path)),functions(raw)
  if path==MODULE:
   assert set(after)==set(before)|{'render_cde_clock_headcalc'} and all(before[name]==after[name] for name in before)
  else:
   expected='build' if path==HOST else 'active_selection'
   assert before.keys()==after.keys() and {name for name in before if before[name]!=after[name]}=={expected}
   if path!=HOST:assert blob(LAST_NODE_CORE,path)==blob(BASE,path),'CDE predecessor SOURCE metadata view is not exact'
 return True


def checked_last_node_delta():
 checked_cde_delta()
 assert git('diff','--name-only',CORE,LAST_NODE_CORE,'--',*SURFACES).decode().splitlines()==[ADAPTER]
 raw=norm((ROOT/ADAPTER).read_bytes());assert raw==blob(LAST_NODE_CORE,ADAPTER)
 assert raw.count(NEW_DRAIN_GUARD.encode())==1 and raw.replace(NEW_DRAIN_GUARD.encode(),OLD_DRAIN_GUARD.encode(),1)==blob(CORE,ADAPTER),'Incomplete whole last-node water admission inverse'
 functions=lambda value:{n.name:ast.dump(n,include_attributes=False) for n in ast.parse(value).body if isinstance(n,ast.FunctionDef)}
 before,after=functions(blob(CORE,ADAPTER)),functions(raw)
 assert before.keys()==after.keys() and {name for name in before if before[name]!=after[name]}=={'inspect'}
 return True

def checked_final_delta():
 checked_last_node_delta()
 assert git('diff','--name-only',CLOCK_ONLY,CORE,'--',*SURFACES).decode().splitlines()==[HOST,MODULE]
 for path in (HOST,MODULE):assert source_before_cde(path,norm((ROOT/path).read_bytes()))==blob(CORE,path)
 assert blob(CORE,MODULE)==blob(CLOCK_ONLY,MODULE)+TRIAL_FUNCTION.encode(),'Foreign whole literal trial renderer append'
 text=blob(CORE,HOST).decode();assert text.count(FINAL_LATE)==1 and text.replace(FINAL_LATE,CLOCK_LATE,1).encode()==blob(CLOCK_ONLY,HOST),'Foreign output-clock-only builder composition'
 return True

class IntermediateFile:
 def __init__(self,path):self.path=path
 def read_bytes(self):return blob(CLOCK_ONLY,self.path)
 def read_text(self,encoding='utf8'):return self.read_bytes().decode(encoding)

class CheckedIntermediateRoot:
 def __truediv__(self,path):return IntermediateFile(str(path)) if str(path) in (HOST,MODULE,ADAPTER) else ROOT/path
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
 if not git('diff',CDE_CORE,sha,'--',*SURFACES):return 'cde-calendar'
 if not git('diff',LAST_NODE_CORE,sha,'--',*SURFACES):return 'last-node-admission'
 for label,epoch in (('pre-clock',PRE_CLOCK),('clock-only',CLOCK_ONLY),('composed-clock',CORE)):
  if not git('diff',epoch,sha,'--',*SURFACES):return label
 raise AssertionError('Unreviewed actual explicit9 producer source')
