"""Original explicit prescribed head/flux boundary with an all-node receipt.

The original BoundBottom owns both prescribed tables. Its last node is outside
the Richards unknowns but remains inside the independent water balance.
"""
import math,re
from datetime import date
from pathlib import Path

POLICY='original-explicit-prescribed-head-flux-all-node-trial-v1'


def selection(directory,original_output=True,*,hysteresis=0,snow=False):
 if not directory or original_output is False:return None
 from experimental_project import switches
 text=(Path(directory)/'swap.swp').read_text(encoding='cp1252');s=switches(text)
 if s.get('SWBOTB')!=9:return None
 active='\n'.join(line.split('!',1)[0] for line in text.splitlines() if not line.lstrip().startswith('*'))
 def integer(key):
  rows=re.findall(r'(?mi)^[ \t]*'+key+r'[ \t]*=[ \t]*([^\r\n]*)',active)
  if len(rows)!=1 or re.fullmatch(r'[+-]?[0-9]+[ \t]*',rows[0]) is None:return None
  return int(rows[0])
 if hysteresis not in (0,1,2):return None
 fixed=dict(SWMACRO=0,SWBOTB=9,SWKIMPL=0,SWHYST=hysteresis,SWSNOW=int(snow),SWFROST=0,SWHEA=1,SWCALT=2,SWBR=0,SWMETDETAIL=0,SWSOPHY=0,SWBBCFILE=0)
 if any(integer(key)!=value for key,value in fixed.items()):return None
 if snow and (integer('SWSOLU') not in (0,1) or integer('SWDRA')!=0):return None
 if integer('SWINCO') not in (1,2) or integer('SWSOLU') not in (0,1,2) or integer('SWDRA') not in (0,1) or integer('SWKMEAN') not in range(1,7):return None
 if re.search(r'(?i)\bSWAP_SOILS_DB\b',active):return None
 models=re.findall(r'(?mi)^[ \t]*IHWCKMODEL[ \t]*=[ \t]*([^\r\n]*)',active)
 remainder=re.sub(r'(?mi)^[ \t]*IHWCKMODEL[ \t]*=[^\r\n]*','',active)
 if re.search(r'(?i)\bIHWCKMODEL\b',remainder) or len(models)>1 or models and re.fullmatch(r'[+]?[0-9]+(?:[ \t]+[+]?[0-9]+)*[ \t]*',models[0]) is None:return None
 if models:
  analytical=tuple(map(int,models[0].split()))
  if not all(value in (1,3,4,5,6,7,8,9,10,11) for value in analytical):return None
  if any(value!=1 for value in analytical):
   if integer('SWSOLU') not in (0,1):return None
   vapor=re.findall(r'(?mi)^[ \t]*SWVAPOR[ \t]*=[ \t]*([^\r\n]+)',active)
   if len(vapor)>1:return None
   if vapor:
    if re.fullmatch(r'[+-]?[0-9]+(?:[ \t]+[+-]?[0-9]+)*[ \t]*',vapor[0]) is None:return None
    if any(int(token)!=0 for token in vapor[0].split()):return None
 def civil(key):
  rows=re.findall(r'(?mi)^[ \t]*'+key+r'[ \t]*=[ \t]*([^\s]+)',active)
  if len(rows)!=1:raise ValueError('Ambiguous original paired-boundary interval')
  return date.fromisoformat(rows[0])
 try:
  start,end=civil('TSTART'),civil('TEND');tables={}
  if end<start:return None
  for axis,value,lower,upper in [('DATE9A','HBOT9',-1.e10,1000.),('DATE9B','QBOT9',-100.,100.)]:
   rows=re.findall(r'(?mis)^[ \t]*'+axis+r'[ \t]+'+value+r'[ \t]*(?:![^\r\n]*)?\r?\n(.*?)^[ \t]*\*[ \t]*End of table',text)
   if len(rows)!=1:return None
   values=[]
   for line in rows[0].splitlines():
    line=line.split('!',1)[0].strip()
    if not line or line.startswith('*'):continue
    fields=line.split()
    if len(fields)!=2:return None
    stamp=date.fromisoformat(fields[0]);number=float(fields[1].replace('D','E').replace('d','e'))
    if not math.isfinite(number) or not lower<=number<=upper:return None
    if values and stamp<=values[-1][0]:return None
    values.append((stamp,number))
   if not values or not (any(start<=stamp<=end for stamp,_ in values) or values[0][0]<=start and values[-1][0]>=end):return None
   tables[axis]=len(values)
 except (ValueError,OverflowError):return None
 return dict(policy=POLICY,kind=('water','cde','age')[s['SWSOLU']],drainage=s['SWDRA'],initial=s['SWINCO'],table_rows=tables,physical_equations_changed=False,new_native_codec=False)


def selected_boundary(project):
 if selection(project.input_directory,getattr(project,'original_output',False)) is not None:return 9
 from prescribed_history_boundary import enabled as history_enabled
 if history_enabled(project):return 9
 from prescribed_snow_boundary import enabled as snow_paired
 if snow_paired(project):return 9
 from implicit_groundwater_state import selected_boundary as previous
 return previous(project)


def boundary_metadata(project,sha,app,root):
 if selected_boundary(project)!=9:
  from implicit_groundwater_state import boundary_metadata as previous
  return previous(project,sha,app,root)
 result=dict(policy=POLICY,source_sha256=sha(app/'prescribed_head_flux_boundary.py'),template_sha256=sha(app/'hybrid_step_budget.f90'),effective_SWBOTB=9,prescribed_external_flux_unchanged=True,all_actual_node_storage_included=True,groundwater_reaction_substituted=False,new_native_codec=False,strict_retry_provider_sha256=sha(app/'implicit_conductivity_retry.py'),strict_retry_predicate='swmacro==0.and.swbotb==9',strict_retry_clock_floor_ulps=8)
 from prescribed_snow_boundary import enabled as snow_paired,POLICY as snow_policy
 if snow_paired(project):
  result.update(snow_composition_policy=snow_policy,snow_composition_source_sha256=sha(app/'prescribed_snow_boundary.py'),strict_retry_provider_sha256=sha(app/'groundwater_snow_retry.py'),strict_retry_predicate='swmacro==0.and.swkimpl==0')
 return result


def render_budget(source,boundary):
 if boundary!=9:
  from age_groundwater_output import render_budget as previous
  return previous(source,boundary)
 old='swbotb==6 .or. swbotb==7 .or.'
 if source.count(old)!=1:raise ValueError('Changed original independent trial-budget anchor')
 return source.replace(old,'swbotb==6 .or. swbotb==7 .or. swbotb==9 .or.',1)


def render_headcalc(source,boundary):
 if boundary!=9:
  from age_groundwater_output import render_headcalc as previous
  return previous(source,boundary)
 for anchor in ('         budget_step=projected_water_residual()', '            budget_step = projected_water_residual()'):
  if source.count(anchor)!=1:raise ValueError('Changed original independent convergence/final water receipt')
 # Reuse the admitted original rollback rule. The original DTMIN fallback
 # otherwise continues an unconverged overconstrained trial indefinitely.
 from implicit_conductivity_retry import headcalc_source
 result=headcalc_source(source);old='swmacro==0.and.swkimpl==1'
 if result.count(old)!=1:raise ValueError('Changed qualified original rollback predicate')
 return result.replace(old,'swmacro==0.and.swbotb==9',1)


def render_timecontrol(source):
 from implicit_conductivity_retry import time_source
 result=time_source(source)
 for old,new in [('use variables,only:swkimpl','use variables,only:swbotb'),('swmacro==0.and.swkimpl==1','swmacro==0.and.swbotb==9')]:
  if result.count(old)!=1:raise ValueError('Changed qualified original retry clock/predicate')
  result=result.replace(old,new,1)
 return result


def render_readswap(source,original_start_clock,boundary):
 if boundary!=9:
  from age_groundwater_output import render_readswap as previous
  return previous(source,original_start_clock,boundary)
 if not math.isfinite(original_start_clock):raise ValueError('Invalid original paired-boundary epoch')
 for key in ('date9a','date9b'):
  old=f"call checkdate(ifnd,dates,tend,tstart,'{key}','readswap//swbotb=9      ')"
  if source.count(old)!=1:raise ValueError('Changed original paired-table validation clock')
  source=source.replace(old,f"call checkdate(ifnd,dates,tend,{original_start_clock:.17g}d0,'{key}','readswap//swbotb=9      ')",1)
 return source


def render_output_trial(source,original,watstor):
 from age_output_clock import trial_receipt_source
 previous=trial_receipt_source(original,watstor)
 old="if(swmacro/=0.or.swsnow/=0.or.swdra/=1)error stop 'Foreign original trial receipt domain'"
 new="if(swmacro/=0.or.swsnow/=0.or.swbotb/=9.or.swdra<0.or.swdra>1)error stop 'Foreign original trial receipt domain'"
 if previous.count(old)!=1 or previous.count('implicit none\n')!=1 or source.count(previous)!=1:raise ValueError('Changed whole original paired-boundary output trial seam')
 current=previous.replace('implicit none\n','use variables,only:swbotb\nimplicit none\n',1).replace(old,new,1)
 return source.replace(previous,current,1)


CDE_CLOCK_IMPORT='   use MOD_integral,only:hybrid_ordinary_trial_residual\n'
CDE_CLOCK_DECL='   real(8)::hybrid_cde_clock_trial_guard,hybrid_cde_clock_candidate_bottom\n'
CDE_CLOCK_GUARD='\n         if(swbotb==8.and..not.flboth)then\n            hybrid_cde_clock_candidate_bottom=0d0\n         else\n            hybrid_cde_clock_candidate_bottom=-kmean(NN+1)*hgrad(NN+1)\n         end if\n         hybrid_cde_clock_trial_guard=hybrid_ordinary_trial_residual(hybrid_cde_clock_candidate_bottom)\n         if(abs(hybrid_cde_clock_trial_guard)>1d-10)flnonconv=.true.'

def render_cde_clock_headcalc(source):
 for old,new in ((CDE_CLOCK_IMPORT,'   use MOD_integral,only:hybrid_output_trial_residual\n'),(CDE_CLOCK_DECL,''),(CDE_CLOCK_GUARD,'\n         if(abs(hybrid_output_trial_residual())>1d-10)flnonconv=.true.')):
  if source.count(old)!=1:raise ValueError('Changed whole original CDE clock trial seam')
  source=source.replace(old,new,1)
 return source
