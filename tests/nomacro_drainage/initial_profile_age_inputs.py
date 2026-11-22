"""Prepare only the two targeted portable original pressure/AGE fixtures."""
import argparse,subprocess,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(ROOT/'tests/nomacro_drainage'),str(ROOT/'tests/nomacro_scheduled_subsurface')]
import age_calendar,age_schedule
from original_output_baseline import assignment
BASE='06e980f4bb17e43e4cc61cf4fc2d6ea17204526d'
CASES=('monthly-subsurface','dense-mean6-plain')


def prepare(case,output,initial):
 assert case in CASES and initial in (1,2)
 for name in ('age_calendar','age_schedule','age_clock','age_fixed','age_reference'):
  path='tests/nomacro_scheduled_subsurface/'+name+'.py';assert (ROOT/path).read_bytes().replace(b'\r\n',b'\n')==subprocess.check_output(['git','show',BASE+':'+path],cwd=ROOT)
 if case=='monthly-subsurface':age_schedule.fixture(output,'subsurface-interval','monthly')
 else:
  age_calendar.fixture(output,'plain',1,0);path=output/'swap.swp';path.write_text(assignment(path.read_text(encoding='cp1252'),'SWKMEAN',6),encoding='cp1252')
 if initial==1:
  path=output/'swap.swp';path.write_text(assignment(path.read_text(encoding='cp1252'),'SWINCO',1),encoding='cp1252')


if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--case',choices=CASES,required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--initial',type=int,choices=(1,2),default=1);a=p.parse_args();prepare(a.case,a.output,a.initial)
