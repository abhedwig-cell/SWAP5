"""Bounded existing Snow/paired9 composition; independent admission is required."""
from pathlib import Path
import re

POLICY='existing-original-snow-explicit-paired9-all-node-soil-receipt-v1'


def selection(directory,original_output=True):
 if not directory or original_output is False:return None
 from experimental_project import switches
 text=(Path(directory)/'swap.swp').read_text(encoding='cp1252');s=switches(text)
 if s.get('SWBOTB')!=9 or s.get('SWSNOW')!=1:return None
 from prescribed_head_flux_boundary import selection as paired
 selected=paired(directory,original_output,snow=True)
 if selected is None:return None
 active='\n'.join(line.split('!',1)[0] for line in text.splitlines() if not line.lstrip().startswith('*'))
 models=re.findall(r'(?mi)^[ \t]*IHWCKMODEL[ \t]*=[ \t]*([^\r\n]*)',active)
 if models and any(int(value)!=1 for value in models[0].split()):return None
 vapor=re.findall(r'(?mi)^[ \t]*SWVAPOR[ \t]*=[ \t]*([^\r\n]*)',active)
 if len(vapor)>1:return None
 if vapor and (re.fullmatch(r'[+-]?[0-9]+(?:[ \t]+[+-]?[0-9]+)*[ \t]*',vapor[0]) is None or any(int(value)!=0 for value in vapor[0].split())):return None
 daily={'NPRINTDAY':1,'PERIOD':1,'SWMONTH':0,'SWODAT':0,'SWRES':1}
 for key,value in daily.items():
  values=re.findall(r'(?mi)^[ \t]*'+key+r'[ \t]*=[ \t]*([^\r\n]*)',active)
  if len(values)!=1 or re.fullmatch(r'[+-]?[0-9]+[ \t]*',values[0]) is None or int(values[0])!=value:return None
 flags=re.findall(r'(?mi)^[ \t]*FLPRINTDT[ \t]*=[ \t]*([^\r\n]*)',active)
 if len(flags)>1 or flags and flags[0].strip().upper() not in ('.FALSE.','FALSE','.F.','F'):return None
 return dict(selected,policy=POLICY,snow_state='actual original seven-scalar Snow carry',soil_receipt='actual net rainfall/irrigation and melt; all nodes; actual prescribed qbot',physical_equations_changed=False)


def enabled(project):
 return selection(project.input_directory,getattr(project,'original_output',False)) is not None
