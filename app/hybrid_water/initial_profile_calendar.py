"""Bound original pressure initialization to existing non-daily state owners."""
import re
from pathlib import Path


def selection(directory,original_output=True):
 if original_output is False:return None
 from experimental_project import switches
 text=(Path(directory)/'swap.swp').read_text(encoding='cp1252');s=switches(text)
 fixed=dict(SWINCO=1,SWMACRO=0,SWFROST=0,SWHEA=1,SWCALT=2,SWSOPHY=0,SWBBCFILE=0,SWMETDETAIL=0,SWBR=0)
 if any(s.get(key)!=value for key,value in fixed.items()) or s.get('SWSOLU') not in (0,1):return None
 active='\n'.join(line.split('!',1)[0] for line in text.splitlines() if not line.lstrip().startswith('*'))
 def integer(key):
  rows=re.findall(r'(?mi)^[ \t]*'+key+r'[ \t]*=[ \t]*([^\r\n]*)',active)
  if len(rows)!=1 or re.fullmatch(r'[+-]?[0-9]+[ \t]*',rows[0]) is None:return None
  return int(rows[0])
 npd,period,monthly,dates,reset=(integer(key) for key in ('NPRINTDAY','PERIOD','SWMONTH','SWODAT','SWRES'))
 if (npd is None or not 1<=npd<=1440 or period is None or not 0<=period<=366 or monthly not in (0,1) or dates not in (0,1) or reset not in (0,1)):return None
 rows=re.findall(r'(?mi)^[ \t]*FLPRINTDT[ \t]*=[ \t]*([^\r\n]*)',active)
 if len(rows)>1:return None
 token=rows[0].strip().upper() if rows else '.FALSE.'
 if token not in ('.FALSE.','FALSE','.F.','F','.TRUE.','TRUE','.T.','T'):return None
 perstep=token in ('.TRUE.','TRUE','.T.','T');clock=perstep or npd>1
 if monthly and dates or clock and (monthly or dates) or perstep and reset:return None
 if not clock and not monthly and not dates and period==1:return None
 history,snow,implicit=(s.get(key) for key in ('SWHYST','SWSNOW','SWKIMPL'));drain,bottom=s.get('SWDRA'),s.get('SWBOTB')
 if history not in (0,1,2) or snow not in (0,1) or implicit not in (0,1) or drain not in (0,1) or bottom not in (5,6,8):return None
 if history:
  if snow or implicit or drain!=1 or bottom not in ((5,8) if s['SWSOLU'] else (6,)):return None
 elif snow or implicit:
  if (drain,bottom)!=(1,5):return None
 elif s['SWSOLU'] and drain==0:
  from analytical_cde_calendar import input_context
  vapor=input_context(directory,original_output)
  if vapor is None or not vapor['vapor']:return None
 return dict(policy='original-pressure-profile-qualified-calendar-state-composition-v1',kind='cde' if s['SWSOLU'] else 'water',drainage=drain,bottom=bottom,history=history,snow=snow,implicit=implicit,clock=clock,new_native_codec=False,physical_equations_changed=False)


def perstep_water_parent_inverse(source):
 """Remove only the literal qualified ordinary per-step trial receipt."""
 import ast,hashlib
 raw=Path(__file__).with_name('perstep_output_domain.py').read_bytes().replace(b'\r\n',b'\n')
 if hashlib.sha256(raw).hexdigest()!='beb7bdf88a36ec32d66464ddc36da042a2ee7bbf623a1623ca46a92789ea0bda':raise ValueError('Changed complete qualified per-step source owner')
 function=next(n for n in ast.parse(raw).body if isinstance(n,ast.FunctionDef) and n.name=='apply_build')
 first=next(i for i,n in enumerate(function.body) if isinstance(n,ast.Assign) and ast.unparse(n.value)=="output / 'headcalc.f90'");body=[]
 for node in function.body[first:]:
  if isinstance(node,ast.Assign) and any(isinstance(t,ast.Name) and t.id in ('function','imports','guard') for t in node.targets):body.append(node)
  elif isinstance(node,ast.AugAssign) and isinstance(node.target,ast.Name) and node.target.id in ('imports','guard'):body.append(node)
  elif isinstance(node,ast.If) and ast.unparse(node.test)=='not is_snow':
   if node.orelse or not all(isinstance(v,ast.AugAssign) and isinstance(v.target,ast.Name) and v.target.id in ('imports','guard') for v in node.body):raise ValueError('Changed literal qualified per-step receipt strings')
   body.append(node)
 namespace=dict(is_snow=False);exec(compile(ast.Module(body=body,type_ignores=[]),'qualified-perstep-source-receipt-literals','exec'),namespace)
 declaration='   real(8)::hybrid_perstep_trial_guard,hybrid_perstep_candidate_bottom\n'
 if declaration not in [n.value for n in ast.walk(function) if isinstance(n,ast.Constant)]:raise ValueError('Changed original per-step trial declaration')
 actual=source
 for part in (namespace['imports']+'\n',declaration,namespace['guard']):
  if source.count(part)!=1:raise ValueError('Foreign complete ordinary per-step trial source')
  source=source.replace(part,'',1)
 anchors=['   use hybrid_implicit_pond_event_state,only:request_implicit_pond_event,assert_no_implicit_pond_event','\n   implicit none\n','         if (abs(budget_total+budget_step)>1d-10*(t1900-budget_start+dt)) flnonconv=.true.']
 if any(source.count(anchor)!=1 for anchor in anchors):raise ValueError('Changed qualified pond/per-step source assembly')
 replay=source.replace(anchors[0],namespace['imports']+'\n'+anchors[0],1).replace(anchors[1],anchors[1]+declaration,1).replace(anchors[2],anchors[2]+namespace['guard'],1)
 if replay!=actual:raise ValueError('Incomplete literal qualified per-step source inverse')
 return source
