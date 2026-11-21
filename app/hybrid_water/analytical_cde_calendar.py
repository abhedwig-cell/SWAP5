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
