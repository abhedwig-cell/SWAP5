"""Invert the complete explicit9 coupling back to the actual joint candidate."""
import ast,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
BASE='8ae1661391ed35125421290de3fb5d95ec8cd5b5'
PRE_CLOCK='c0952e394647179d591a855fcaf1a7270871fb2b'
CORE='4d4fb1b8e059f9137ec217e52f262222ead6ce1c'
MODULE='app/hybrid_water/prescribed_head_flux_boundary.py'
SURFACES=('app','src','tools/solute','tools/vq','reference')
git=lambda *args:subprocess.check_output(['git',*args],cwd=ROOT)
blob=lambda ref,path:git('show',ref+':'+path)
norm=lambda raw:raw.replace(b'\r\n',b'\n')
PAIRED='''    from prescribed_head_flux_boundary import selection as paired_boundary_selection
    paired_boundary=paired_boundary_selection(directory,original_output)
    if paired_boundary is not None:allowed['SWBOTB'].add(9)
'''
TIME='''            if lower_boundary==9 and not (age_calendar and (age_calendar['nprintday']>1 or age_calendar['flprintdt'])):
                from prescribed_head_flux_boundary import render_timecontrol
                path=output/'timecontrol.f90'
                source=(path if path.exists() else donor_build/'swap-selected/timecontrol.f90').read_text(encoding='cp1252')
                path.write_text(render_timecontrol(source),encoding='cp1252')
                if 'timecontrol' not in patched:patched.append('timecontrol')
'''
LATE="    if lower_boundary==9 and age_calendar and (age_calendar['nprintday']>1 or age_calendar['flprintdt']):\n        from prescribed_head_flux_boundary import render_timecontrol\n        path=output/'timecontrol.f90'\n        if 'timecontrol' not in patched or not path.is_file():raise ValueError('Missing actual original paired-boundary output clock owner')\n        path.write_text(render_timecontrol(path.read_text(encoding='cp1252')),encoding='cp1252')\n"
OUTPUT='''            from prescribed_head_flux_boundary import selection as paired_boundary_selection
            if paired_boundary_selection(project.input_directory,project.original_output) is not None:continue
'''


def complete_inverse():
 path='app/hybrid_water/daily_host.py';current=blob(CORE,path).decode()
 early="if lower_boundary==9 and not (age_calendar and (age_calendar['nprintday']>1 or age_calendar['flprintdt'])):"
 assert current.count(early)==current.count(LATE)==1
 assert current.replace(early,'if lower_boundary==9:',1).replace(LATE,'',1).encode()==blob(PRE_CLOCK,path),'Unreviewed complete clock composition builder delta'
 module=blob(CORE,MODULE).decode()
 new_date='   if not values or not (any(start<=stamp<=end for stamp,_ in values) or values[0][0]<=start and values[-1][0]>=end):return None'
 old_date='   if len(values)<2 or values[0][0]>start or values[-1][0]<end:return None'
 assert module.count(new_date)==1 and module.replace(new_date,old_date,1).encode()==blob(PRE_CLOCK,MODULE),'Unreviewed whole historical date-guard inverse'
 assert git('diff','--name-only',PRE_CLOCK,CORE,'--',*SURFACES).decode().splitlines()==[path,MODULE]
 assert not git('diff',CORE,'--',*SURFACES),'Unreviewed explicit9 physical source delta'
 files={'app/hybrid_water/'+name for name in ('daily_coupling.py','daily_host.py','experimental_project.py','original_output.py')}
 assert set(git('diff','--name-status',BASE,CORE,'--',*SURFACES).decode().splitlines())=={'A\t'+MODULE}|{'M\t'+path for path in files}
 for path in files|{MODULE}:assert norm((ROOT/path).read_bytes())==blob(CORE,path),path
 for path in files:
  text=blob(CORE,path).decode()
  def replace(new,old):
   nonlocal text
   assert text.count(new)==1,(path,new);text=text.replace(new,old,1)
  if path.endswith('/daily_coupling.py'):
   replace('from prescribed_head_flux_boundary import selected_boundary,boundary_metadata as lower_metadata','from implicit_groundwater_state import selected_boundary,boundary_metadata as lower_metadata')
   replace('from prescribed_head_flux_boundary import render_budget','from age_groundwater_output import render_budget')
  elif path.endswith('/daily_host.py'):
   replace(TIME,'');replace(LATE,'')
   for new,old in [('from prescribed_head_flux_boundary import selected_boundary','from implicit_groundwater_state import selected_boundary'),('from prescribed_head_flux_boundary import render_budget,render_headcalc','from age_groundwater_output import render_budget,render_headcalc'),('from prescribed_head_flux_boundary import render_readswap','from age_groundwater_output import render_readswap'),('from prescribed_head_flux_boundary import boundary_metadata as lower_metadata','from implicit_groundwater_state import boundary_metadata as lower_metadata'),('if lower_boundary in (1,5,9):','if lower_boundary in (1,5):')]:replace(new,old)
  elif path.endswith('/experimental_project.py'):
   replace(PAIRED,'')
   for old in ('and initial_frost is None and initial_age is None and initial_groundwater is None:','and initial_calendar is None and initial_frost is None and initial_groundwater is None:','and initial_calendar is None and initial_age is None and initial_groundwater is None:'):replace(old[:-1]+' and paired_boundary is None:',old)
   replace("if boundary.get('SWBOTB') not in range(1, 9) and paired_boundary is None:","if boundary.get('SWBOTB') not in range(1, 9):")
  else:replace(OUTPUT,'')
  assert text.encode()==blob(BASE,path),'Incomplete whole explicit9 source inverse: '+path
  functions=lambda raw:{n.name:ast.dump(n,include_attributes=False) for n in ast.parse(raw).body if isinstance(n,ast.FunctionDef)}
  before,after=functions(blob(BASE,path)),functions(blob(CORE,path));expected={'daily_coupling.py':'validate_bundle','daily_host.py':'build','experimental_project.py':'inspect','original_output.py':'selection'}[Path(path).name]
  assert {name for name in before if before[name]!=after[name]}=={expected}
 retry='app/hybrid_water/implicit_conductivity_retry.py';assert norm((ROOT/retry).read_bytes())==blob(BASE,retry)
 return True


def producer_epoch(sha):
 for label,epoch in (('pre-clock',PRE_CLOCK),('composed-clock',CORE)):
  if not git('diff',epoch,sha,'--',*SURFACES):return label
 raise AssertionError('Unreviewed actual explicit9 producer source')
