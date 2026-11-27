"""Bound existing explicit analytical Snow to original bottom5/8 state owners."""
from pathlib import Path
import re


def selection(directory,original_output=True):
 if not directory or original_output is False:return None
 from experimental_project import switches
 text=(Path(directory)/'swap.swp').read_text(encoding='cp1252')
 active='\n'.join(line.split('!',1)[0] for line in text.splitlines() if not line.lstrip().startswith('*'))
 s=switches(active)
 fixed=dict(SWMACRO=0,SWSNOW=1,SWFROST=0,SWHEA=1,SWCALT=2,SWKIMPL=0,SWHYST=0,SWDRA=0,SWSOPHY=0,SWBBCFILE=0,SWMETDETAIL=0,SWBR=0)
 if any(s.get(k)!=v for k,v in fixed.items()) or s.get('SWBOTB') not in (5,8) or s.get('SWSOLU') not in (0,1) or s.get('SWINCO') not in (1,2):return None
 rows=re.findall(r'(?mi)^[ \t]*IHWCKMODEL[ \t]*=[ \t]*([^\r\n]*)',active)
 if len(rows)!=1 or re.fullmatch(r'[+-]?[0-9]+(?:[ \t]+[+-]?[0-9]+)*[ \t]*',rows[0]) is None:return None
 models=list(map(int,rows[0].split()))
 if not models or all(x==1 for x in models) or any(x not in range(1,12) for x in models):return None
 rows=re.findall(r'(?mi)^[ \t]*SWVAPOR[ \t]*=[ \t]*([^\r\n]*)',active)
 if len(rows)>1 or any(x>=8 for x in models) and not rows:return None
 if rows and (re.fullmatch(r'[+-]?[0-9]+(?:[ \t]+[+-]?[0-9]+)*[ \t]*',rows[0]) is None or any(int(x) not in (0,1) for x in rows[0].split())):return None
 if 2 in models or any(x>=8 for x in models):
  from implicit_hydraulic_state import _models_from_grid
  # Pure original grid/scalar replication and effective vapor flags;
  # no implicit selector or physical state is assigned by this reader.
  if _models_from_grid(active,models) is None:return None
 from prescribed_snow_boundary import _validate_calendar
 try:_validate_calendar(text)
 except ValueError:return None
 return dict(policy='existing-explicit-analytical-snow-undrained-bottom5-8-state-composition-v1',models=models,bottom=s['SWBOTB'],kind='cde' if s['SWSOLU'] else 'water',initial=s['SWINCO'],physical_equations_changed=False,new_physical_state=False)
