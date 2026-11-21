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
