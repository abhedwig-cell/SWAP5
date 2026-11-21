"""Bound existing ordinary CDE calendars to the admitted explicit bottom6 state."""
from pathlib import Path
import re


def bottom6_selected(project):
 if (not project.input_directory or project.macro or project.age or not project.solute or
     not project.original_output or project.time_step_policy!='original-adaptive-day-seed-v1'):return False
 from experimental_project import switches
 from model7_capacity import analytical_models
 text=(Path(project.input_directory)/'swap.swp').read_text(encoding='cp1252');selected=switches(text)
 domain=dict(SWMACRO=0,SWSOLU=1,SWKIMPL=0,SWHYST=0,SWSNOW=0,SWFROST=0,SWDRA=1,SWBOTB=6,SWBBCFILE=0,SWHEA=1,SWCALT=2,SWBR=0,SWMETDETAIL=0)
 if any(selected.get(k)!=v for k,v in domain.items()):return False
 models=analytical_models(project)
 if not models:return False
 active='\n'.join(line.split('!',1)[0] for line in text.splitlines() if not line.lstrip().startswith('*'))
 flags=re.findall(r'(?mi)^[ \t]*SWVAPOR[ \t]*=[ \t]*([^\r\n]*)',active)
 if len(flags)>1:return False
 if flags:
  if re.fullmatch(r'[01](?:[ \t]+[01])*[ \t]*',flags[0]) is None:return False
  values=tuple(map(int,flags[0].split()))
  # Vapor calendars need their separate explicit native-domain composition.
  if any(values) and any(m>=8 for m in models):return False
 return True
