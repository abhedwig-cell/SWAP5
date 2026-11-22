"""Bound original pressure initialization to existing groundwater state owners."""
import re
from pathlib import Path


def selection(directory,original_output=True):
 if not directory or original_output is False:return None
 from experimental_project import switches
 text=(Path(directory)/'swap.swp').read_text(encoding='cp1252');selected=switches(text)
 fixed=dict(SWINCO=1,SWMACRO=0,SWBOTB=1,SWFROST=0,SWHEA=1,SWCALT=2,SWSOPHY=0,SWBR=0,SWBBCFILE=0,SWMETDETAIL=0)
 if any(selected.get(key)!=value for key,value in fixed.items()):return None
 if selected.get('SWSOLU') not in (0,1,2) or selected.get('SWHYST') not in (0,1,2) or selected.get('SWSNOW') not in (0,1) or selected.get('SWKIMPL') not in (0,1) or selected.get('SWDRA') not in (0,1):return None
 if selected['SWSOLU']==2 and (selected['SWSNOW'] or selected['SWKIMPL']):return None
 if selected['SWSOLU']==1 and selected['SWSNOW'] and selected['SWKIMPL']:return None
 active='\n'.join(line.split('!',1)[0] for line in text.splitlines() if not line.lstrip().startswith('*'))
 def integer(key):
  rows=re.findall(r'(?mi)^[ \t]*'+key+r'[ \t]*=[ \t]*([^\r\n]*)',active)
  if len(rows)!=1 or re.fullmatch(r'[+-]?[0-9]+[ \t]*',rows[0]) is None:return None
  return int(rows[0])
 if any(integer(key)!=value for key,value in fixed.items()):return None
 for key in ('SWSOLU','SWHYST','SWSNOW','SWKIMPL','SWDRA'):
  if integer(key)!=selected[key]:return None
 npd,period,monthly,dates,reset,mean=(integer(key) for key in ('NPRINTDAY','PERIOD','SWMONTH','SWODAT','SWRES','SWKMEAN'))
 if npd is None or not 1<=npd<=1440 or period is None or not 0<=period<=366 or monthly not in (0,1) or dates not in (0,1) or reset not in (0,1) or mean not in range(1,7):return None
 flags=re.findall(r'(?mi)^[ \t]*FLPRINTDT[ \t]*=[ \t]*([^\r\n]*)',active)
 if len(flags)>1 or flags and flags[0].strip().upper() not in ('.FALSE.','FALSE','.F.','F','.TRUE.','TRUE','.T.','T'):return None
 if re.search(r'(?i)\bSWAP_SOILS_DB\b',active):return None
 models=re.findall(r'(?mi)^[ \t]*IHWCKMODEL[ \t]*=[ \t]*([^\r\n]*)',active)
 remainder=re.sub(r'(?mi)^[ \t]*IHWCKMODEL[ \t]*=[^\r\n]*','',active)
 if re.search(r'(?i)\bIHWCKMODEL\b',remainder) or len(models)>1 or models and re.fullmatch(r'\+?0*1(?:[ \t]+\+?0*1)*[ \t]*',models[0]) is None:return None
 return dict(policy='original-pressure-profile-existing-prescribed-groundwater-state-composition-v1',kind=('water','cde','age')[selected['SWSOLU']],history=selected['SWHYST'],snow=selected['SWSNOW'],implicit=selected['SWKIMPL'],drainage=selected['SWDRA'],new_native_codec=False,physical_equations_changed=False)

# Actual committed pressure AGE negative control; never merge.
