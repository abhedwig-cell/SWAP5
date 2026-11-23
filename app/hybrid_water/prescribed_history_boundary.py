"""Bounded existing hydraulic history coupled to original paired boundary9.

The original hysteresis routines own every scanning state. This module narrows
the new configuration and binds its existing native witness to the boundary.
Scientific admission is owned by the workstream qualification record.
"""
import hashlib,re
from pathlib import Path

POLICY='existing-original-hysteresis-explicit-paired9-daily-v1'
DOMAIN_PARENT_SHA='a76680e1b7101b9f75240ce2000f78ba07dfb15384b106372b43fcad2fe0fa39'


def selection(directory,original_output=True):
 if not directory or original_output is False:return None
 from experimental_project import switches
 text=(Path(directory)/'swap.swp').read_text(encoding='cp1252');s=switches(text)
 if s.get('SWBOTB')!=9 or s.get('SWHYST') not in (1,2):return None
 from prescribed_head_flux_boundary import selection as paired
 selected=paired(directory,original_output,hysteresis=s['SWHYST'])
 if selected is None or s.get('SWSOLU') not in (0,1):return None
 active='\n'.join(line.split('!',1)[0] for line in text.splitlines() if not line.lstrip().startswith('*'))
 for key,allowed in [('IHWCKMODEL',{1}),('SWVAPOR',{0})]:
  rows=re.findall(r'(?mi)^[ \t]*'+key+r'[ \t]*=[ \t]*([^\r\n]*)',active)
  if len(rows)>1:return None
  if rows and (re.fullmatch(r'[+]?[0-9]+(?:[ \t]+[+]?[0-9]+)*[ \t]*',rows[0]) is None or any(int(v) not in allowed for v in rows[0].split())):return None
 for key,value in dict(NPRINTDAY=1,PERIOD=1,SWMONTH=0,SWODAT=0,SWRES=1).items():
  rows=re.findall(r'(?mi)^[ \t]*'+key+r'[ \t]*=[ \t]*([^\r\n]*)',active)
  if len(rows)!=1 or re.fullmatch(r'[+]?[0-9]+[ \t]*',rows[0]) is None or int(rows[0])!=value:return None
 flags=re.findall(r'(?mi)^[ \t]*FLPRINTDT[ \t]*=[ \t]*([^\r\n]*)',active)
 if len(flags)>1 or flags and flags[0].strip().upper() not in ('.FALSE.','FALSE','.F.','F'):return None
 return dict(selected,policy=POLICY,hysteresis=s['SWHYST'],native_domain_version=2,native_domain_bytes=56,physical_equations_changed=False)


def enabled(project):
 return selection(project.input_directory,getattr(project,'original_output',False)) is not None


def domain_source(original,project):
 if not enabled(project):return original
 text=original.decode('cp1252').replace('\r\n','\n')
 if hashlib.sha256(text.encode('cp1252')).hexdigest()!=DOMAIN_PARENT_SHA:raise ValueError('Changed complete original hysteresis domain provider')
 edits=[('only:swmacro,swhyst,swsolu','only:swmacro,swhyst,swsolu,swdra\n  use variables,only:swbotb'),
        ('expected(5),header(5),witness(5)','expected(7),header(7),witness(7)'),
        ('swsolu<0.or.swsolu>2)','swsolu<0.or.swsolu>1.or.swbotb/=9.or.swdra<0.or.swdra>1)'),
        ('expected=[1,numnod,swmacro,swhyst,swsolu]','expected=[2,numnod,swmacro,swhyst,swsolu,swdra,swbotb]')]
 for old,new in edits:
  if text.count(old)!=1:raise ValueError('Changed complete original hysteresis domain seam')
  text=text.replace(old,new,1)
 return text.encode('cp1252')
