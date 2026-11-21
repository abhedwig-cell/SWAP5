"""Bound existing ordinary CDE calendars to the admitted explicit bottom6 state."""
from pathlib import Path
import re


def bottom6_selected(project):
 selected=calendar_context(project)
 return selected is not None and selected['bottom']==6


HEAD_IMPORT='   use MOD_integral,only:hybrid_ordinary_trial_residual\n'
HEAD_DECL='   real(8)::hybrid_cde_clock_trial_guard,hybrid_cde_clock_candidate_bottom\n'
HEAD_GUARD="""
         if(swbotb==8.and..not.flboth)then
            hybrid_cde_clock_candidate_bottom=0d0
         else
            hybrid_cde_clock_candidate_bottom=-kmean(NN+1)*hgrad(NN+1)
         end if
         hybrid_cde_clock_trial_guard=hybrid_ordinary_trial_residual(hybrid_cde_clock_candidate_bottom)
         if(abs(hybrid_cde_clock_trial_guard)>1d-10)flnonconv=.true."""
CLOCK6_PARENT_SHA='dba1ff1fdc5422308eaa1ff4488c178a2c108d8366781f9627fd42d1a74e0686'


def head_guard(bottom):
 if bottom!=6:return HEAD_GUARD
 return HEAD_GUARD.replace('         if(swbotb==8.and..not.flboth)then',
     '         if(swbotb==6)then\n            hybrid_cde_clock_candidate_bottom=0d0\n         else if(swbotb==8.and..not.flboth)then',1)


def render_clock_parent(source,bottom):
 anchor='   use hybrid_step_budget, only: projected_water_residual'
 assert source.count(anchor)==1;source=source.replace(anchor,HEAD_IMPORT+anchor,1)
 anchor='\n   implicit none\n';assert source.count(anchor)==1;source=source.replace(anchor,anchor+HEAD_DECL,1)
 anchor='         if (abs(budget_total+budget_step)>1d-10*(t1900-budget_start+dt)) flnonconv=.true.'
 assert source.count(anchor)==1;return source.replace(anchor,anchor+head_guard(bottom),1)


def clock_selected(project):
 if not bottom6_selected(project):return False
 from cde_clock_output import active_selection
 return active_selection(project) is not None


def clock_parent_inverse(source,project,parent_sha):
 if not clock_selected(project):return None
 import hashlib
 actual=source
 for part in (HEAD_IMPORT,HEAD_DECL,head_guard(6)):
  if source.count(part)!=1:raise ValueError('Foreign analytical CDE bottom6 trial source')
  source=source.replace(part,'',1)
 if (hashlib.sha256(source.encode('cp1252')).hexdigest()!=parent_sha or
     hashlib.sha256(actual.encode('cp1252')).hexdigest()!=CLOCK6_PARENT_SHA or
     render_clock_parent(source,6)!=actual):
  raise ValueError('Foreign complete qualified analytical CDE bottom6 HeadCalc parent')
 return True


MAGIC=b'S5HCC006'


def calendar_context(project):
 if (not project.input_directory or project.macro or project.age or not project.solute or
     not project.original_output or project.time_step_policy!='original-adaptive-day-seed-v1'):return None
 return input_context(project.input_directory,project.original_output)


def input_context(directory,original_output=True):
 if not directory or original_output is False:return None
 from experimental_project import switches
 text=(Path(directory)/'swap.swp').read_text(encoding='cp1252');selected=switches(text)
 domain=dict(SWMACRO=0,SWSOLU=1,SWKIMPL=0,SWSOPHY=0,SWHYST=0,SWSNOW=0,SWFROST=0,SWBBCFILE=0,SWHEA=1,SWCALT=2,SWBR=0,SWMETDETAIL=0)
 if any(selected.get(k)!=v for k,v in domain.items()) or selected.get('SWINCO') not in (2,3):return None
 drain,bottom=selected.get('SWDRA'),selected.get('SWBOTB')
 if drain not in (0,1) or bottom not in (5,6,8):return None
 active='\n'.join(line.split('!',1)[0] for line in text.splitlines() if not line.lstrip().startswith('*'))
 def integer(key,default=None):
  rows=re.findall(r'(?mi)^[ \t]*'+key+r'[ \t]*=[ \t]*([^\r\n]*)',active)
  if not rows:return default
  if len(rows)!=1 or re.fullmatch(r'[+-]?[0-9]+[ \t]*',rows[0]) is None:return None
  return int(rows[0])
 npd,period,monthly,dates,reset=(integer(k) for k in ('NPRINTDAY','PERIOD','SWMONTH','SWODAT','SWRES'))
 if (npd is None or not 1<=npd<=1440 or period is None or not 0<=period<=366 or
     monthly not in (0,1) or dates not in (0,1) or reset not in (0,1)):return None
 flags=re.findall(r'(?mi)^[ \t]*FLPRINTDT[ \t]*=[ \t]*([^\r\n]*)',active)
 if len(flags)>1:return None
 token=flags[0].strip().upper() if flags else '.FALSE.'
 if token not in ('.FALSE.','FALSE','.F.','F','.TRUE.','TRUE','.T.','T'):return None
 perstep=token in ('.TRUE.','TRUE','.T.','T');clock=perstep or npd>1
 if clock and (monthly or dates or perstep and reset):return None
 if not clock and not monthly and not dates and period==1:return None
 rows=re.findall(r'(?mi)^[ \t]*IHWCKMODEL[ \t]*=[ \t]*([^\r\n]*)',active)
 if len(rows)>1:return None
 if rows and re.fullmatch(r'[+-]?[0-9]+(?:[ \t]+[+-]?[0-9]+)*[ \t]*',rows[0]) is None:return None
 models=tuple(map(int,rows[0].split())) if rows else (1,)
 if not models or any(m not in range(1,12) for m in models):return None
 table=re.search(r'(?mi)^[ \t]*ISUBLAY[ \t]+ISOILLAY[ \t]+HSUBLAY[ \t]+NCOMP[^\n]*\n((?:[ \t]*\d+[^\n]*\n)+)',active)
 if table is None:return None
 layers=max(int(row.split()[1]) for row in table[1].splitlines())
 if len(models)==1:models=models*layers
 if len(models)!=layers:return None
 rows=re.findall(r'(?mi)^[ \t]*SWVAPOR[ \t]*=[ \t]*([^\r\n]*)',active)
 if len(rows)>1:return None
 if rows and re.fullmatch(r'[01](?:[ \t]+[01])*[ \t]*',rows[0]) is None:return None
 vapor_flags=tuple(map(int,rows[0].split())) if rows else (0,)*layers
 if len(vapor_flags)!=layers:return None
 vapor_flags=tuple(f if m>=8 else 0 for m,f in zip(models,vapor_flags));vapor=any(vapor_flags)
 if not vapor and (drain,bottom)!=(1,6):return None
 return dict(drainage=drain,bottom=bottom,models=models,vapor_flags=vapor_flags,layers=layers,vapor=vapor,clock=clock)


def vapor_selected(project):
 selected=calendar_context(project);return selected is not None and selected['vapor']


def native_magic(project):return MAGIC if vapor_selected(project) else None


def native_provider(original):
 import hashlib
 text=original.decode('cp1252').replace('\r\n','\n')
 if hashlib.sha256(text.encode('cp1252')).hexdigest()!='a181df32399d64a4052f4e8d3d11133bb7388fd890c8f0e9139594bbc29877b0':raise ValueError('Changed complete original vapor native3 parent')
 edits=[('swsolu<0.or.swsolu>1','swsolu/=1'),('.or.swdra/=1.or.swbotb/=6)','.or.(swdra/=0.and.swdra/=1).or.(swbotb/=5.and.swbotb/=6.and.swbotb/=8))'),('expected(1:14)=[3,','expected(1:14)=[6,')]
 for old,new in edits:
  if text.count(old)!=1:raise ValueError('Changed exact CDE calendar vapor native seam')
  text=text.replace(old,new,1)
 return text.encode('cp1252')


def cde_offset(aux,nodes,project=None):
 import struct
 if aux[:8]!=MAGIC or len(aux)<104:raise ValueError('Incomplete CDE calendar vapor domain')
 domain=struct.unpack_from('<14i',aux,48);layers=domain[2];drain,bottom=domain[12:]
 if not 1<=layers<=1000 or drain not in (0,1) or bottom not in (5,6,8) or domain!=(6,nodes,layers,0,1,0,0,0,0,0,1,2,drain,bottom):raise ValueError('Foreign CDE calendar vapor domain')
 count=14+2*layers;size=4*count
 if len(aux)<48+2*size:raise ValueError('Incomplete CDE calendar vapor witness')
 header=struct.unpack_from('<'+str(count)+'i',aux,48)
 if header!=struct.unpack_from('<'+str(count)+'i',aux,48+size):raise ValueError('Foreign CDE calendar vapor witness')
 models,flags=header[14:14+layers],header[14+layers:]
 if any(m not in range(1,12) for m in models) or any(f not in (0,1) for f in flags) or not any(flags) or any(f and m<8 for m,f in zip(models,flags)):raise ValueError('Foreign CDE calendar vapor layers')
 if project is not None:
  selected=calendar_context(project)
  if selected is None or not selected['vapor'] or (drain,bottom)!=(selected['drainage'],selected['bottom']) or models!=selected['models'] or flags!=selected['vapor_flags']:raise ValueError('CDE calendar vapor payload differs from actual project')
 return 48+2*size


def metadata(project):
 if not vapor_selected(project):return None
 import hashlib
 source=Path(__file__).read_bytes().replace(b'\r\n',b'\n');provider=native_provider(Path(__file__).with_name('hydraulic_vapor_native.f90').read_bytes())
 return dict(policy='original-analytical-vapor-CDE-calendar-composition-v1',native_domain_version=6,native_codec=MAGIC.decode(),source_sha256=hashlib.sha256(source).hexdigest(),native_provider_sha256=hashlib.sha256(provider).hexdigest(),CDE_private_state_version=2,CDE_private_fields=['sampro0','rounderr'],physical_equations_changed=False,new_physical_state=False,fixed_absolute_water_and_CDE_limits=1e-10)
