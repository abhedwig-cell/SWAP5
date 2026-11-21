"""Bound original pressure initialization to the existing dense Frost owners."""
import re
from pathlib import Path


def selection(directory,original_output=True):
 if not directory or original_output is False:return None
 from experimental_project import switches,one
 folder=Path(directory);text=(folder/'swap.swp').read_text(encoding='cp1252');selected=switches(text)
 fixed=dict(SWINCO=1,SWMACRO=0,SWFROST=1,SWSNOW=1,SWHYST=2,SWHEA=1,SWCALT=2,SWSOPHY=0,SWDRA=1,SWBOTB=6,SWBR=0,SWBBCFILE=0,SWMETDETAIL=0)
 if any(selected.get(key)!=value for key,value in fixed.items()) or selected.get('SWSOLU') not in (0,1) or selected.get('SWKIMPL') not in (0,1):return None
 active='\n'.join(line.split('!',1)[0] for line in text.splitlines() if not line.lstrip().startswith('*'))
 def integer(key):
  rows=re.findall(r'(?mi)^[ \t]*'+key+r'[ \t]*=[ \t]*([^\r\n]*)',active)
  if len(rows)!=1 or re.fullmatch(r'[+-]?[0-9]+[ \t]*',rows[0]) is None:return None
  return int(rows[0])
 if any(integer(key)!=value for key,value in {**fixed,**dict(NPRINTDAY=1,PERIOD=1,SWMONTH=0,SWODAT=0,SWRES=1)}.items()):return None
 if integer('SWSOLU') not in (0,1) or integer('SWKIMPL') not in (0,1):return None
 flags=re.findall(r'(?mi)^[ \t]*FLPRINTDT[ \t]*=[ \t]*([^\r\n]*)',active)
 if len(flags)>1 or flags and flags[0].strip().upper() not in ('.FALSE.','FALSE','.F.','F'):return None
 if re.search(r'(?i)\bSWAP_SOILS_DB\b',active):return None
 models=re.findall(r'(?mi)^[ \t]*IHWCKMODEL[ \t]*=[ \t]*([^\r\n]*)',active)
 remainder=re.sub(r'(?mi)^[ \t]*IHWCKMODEL[ \t]*=[^\r\n]*','',active)
 if re.search(r'(?i)\bIHWCKMODEL\b',remainder) or len(models)>1 or models and re.fullmatch(r'\+?0*1(?:[ \t]+\+?0*1)*[ \t]*',models[0]) is None:return None
 name=one(text,'DRFIL',r"'[^']+'").strip("'");prefix=one(text,'PATHDRAIN',r"'[^']*'").strip("'").strip()
 drain=folder/(prefix+name+'.dra')
 if not drain.is_file() or switches(drain.read_text(encoding='cp1252')).get('SWDIVD')!=1:return None
 return dict(policy='original-pressure-profile-qualified-dense-frost-state-composition-v1',kind='cde' if selected['SWSOLU'] else 'water',implicit=selected['SWKIMPL'],new_native_codec=False,physical_equations_changed=False)

# Actual committed pressure Frost negative control; never merge.
