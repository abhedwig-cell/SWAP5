"""Original explicit prescribed head/flux boundary with an all-node receipt.

The original BoundBottom owns both prescribed tables. Its last node is outside
the Richards unknowns but remains inside the independent water balance.
"""
import math,re
from datetime import date
from pathlib import Path

POLICY='original-explicit-prescribed-head-flux-all-node-trial-v1'


def selection(directory,original_output=True):
 if not directory or original_output is False:return None
 from experimental_project import switches
 text=(Path(directory)/'swap.swp').read_text(encoding='cp1252');s=switches(text)
 if s.get('SWBOTB')!=9:return None
 active='\n'.join(line.split('!',1)[0] for line in text.splitlines() if not line.lstrip().startswith('*'))
 def integer(key):
  rows=re.findall(r'(?mi)^[ \t]*'+key+r'[ \t]*=[ \t]*([^\r\n]*)',active)
  if len(rows)!=1 or re.fullmatch(r'[+-]?[0-9]+[ \t]*',rows[0]) is None:return None
  return int(rows[0])
 fixed=dict(SWMACRO=0,SWBOTB=9,SWKIMPL=0,SWHYST=0,SWSNOW=0,SWFROST=0,SWHEA=1,SWCALT=2,SWBR=0,SWMETDETAIL=0,SWSOPHY=0,SWBBCFILE=0)
 if any(integer(key)!=value for key,value in fixed.items()):return None
 if integer('SWINCO') not in (1,2) or integer('SWSOLU') not in (0,1,2) or integer('SWDRA') not in (0,1) or integer('SWKMEAN') not in range(1,7):return None
 if re.search(r'(?i)\bSWAP_SOILS_DB\b',active):return None
 models=re.findall(r'(?mi)^[ \t]*IHWCKMODEL[ \t]*=[ \t]*([^\r\n]*)',active)
 remainder=re.sub(r'(?mi)^[ \t]*IHWCKMODEL[ \t]*=[^\r\n]*','',active)
 if re.search(r'(?i)\bIHWCKMODEL\b',remainder) or len(models)>1 or models and re.fullmatch(r'\+?0*1(?:[ \t]+\+?0*1)*[ \t]*',models[0]) is None:return None
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
   if len(values)<2 or values[0][0]>start or values[-1][0]<end:return None
   tables[axis]=len(values)
 except (ValueError,OverflowError):return None
 return dict(policy=POLICY,kind=('water','cde','age')[s['SWSOLU']],drainage=s['SWDRA'],initial=s['SWINCO'],table_rows=tables,physical_equations_changed=False,new_native_codec=False)


def selected_boundary(project):
 if selection(project.input_directory,getattr(project,'original_output',False)) is not None:return 9
 from implicit_groundwater_state import selected_boundary as previous
 return previous(project)


def boundary_metadata(project,sha,app,root):
 if selected_boundary(project)!=9:
  from implicit_groundwater_state import boundary_metadata as previous
  return previous(project,sha,app,root)
 return dict(policy=POLICY,source_sha256=sha(app/'prescribed_head_flux_boundary.py'),template_sha256=sha(app/'hybrid_step_budget.f90'),effective_SWBOTB=9,prescribed_external_flux_unchanged=True,all_actual_node_storage_included=True,groundwater_reaction_substituted=False,new_native_codec=False)


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
 # Both original equations and the two mandatory trial guards are unchanged.
 return source


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
