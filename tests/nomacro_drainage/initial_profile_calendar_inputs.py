"""Prepare original pressure initialization with existing qualified calendars."""
import argparse,re,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(ROOT/'tests/nomacro_scheduled_subsurface'),str(ROOT/'tests/nomacro_drainage')]
from original_output_baseline import assignment
from analytical_cde_calendar_inputs import prepare as analytical
import output_hysteresis as history
import implicit_conductivity_runtime as implicit
from cde_interval_runtime import fixture as interval
CASES={
 'analytic-clock6-cde':('analytic','model7-clock6'),
 'vapor-monthly6-cde':('analytic','vapor8-monthly6'),
 'vapor-dra0-clock8-cde':('analytic','mixed7-8-clock-undrained8'),
 'vapor-dra0-explicit5-cde':('analytic','vapor8-explicit-undrained5'),
 'hys1-clock-water':('history','np3'),
 'hys2-periodic-cde':('interval','periodic'),
 'hys2-monthly-water':('history','monthly'),
 'implicit-monthly-cde':('implicit','monthly'),
 'implicit-snow-clock-cde':('implicit','daily'),
 'implicit-perstep-water':('implicit','periodic'),
 'snow-monthly-cde':('interval','monthly'),
 'plain-periodic-water':('interval','periodic')}


def prepare(case,output,initial=1):
 family,mode=CASES[case]
 if family=='analytic':analytical(mode,output)
 elif family=='history':history.fixture(output,'water',1 if case.startswith('hys1') else 2,3,mode)
 elif family=='implicit':implicit.fixture(output,int(case!='implicit-perstep-water'),0,5,case=='implicit-perstep-water',1,mode,3,0 if mode!='daily' else 1,2 if mode=='daily' else 1)
 else:interval(output,mode,2 if case=='hys2-periodic-cde' else 0,3,reset=0 if mode=='monthly' else 1,snow=int(case=='snow-monthly-cde'))
 path=output/'swap.swp';text=path.read_text(encoding='cp1252');edits=dict(SWINCO=initial)
 if case=='implicit-snow-clock-cde':edits['SWSNOW']=1
 if case=='plain-periodic-water':edits['SWSOLU']=0
 for key,value in edits.items():text=assignment(text,key,value)
 table=('ZI = -0.5 -50.0 -195.0\nH = -20.0 -130.0 -210.0\n* End of table' if case=='plain-periodic-water' else 'HTB =\n -0.5 -20.0\n -50.0 -130.0\n -195.0 -210.0\n* End of table')
 text,count=re.subn(r'(?mi)^[ \t]*HTB[ \t]*=[ \t]*\n.*?^\* End of table',lambda _:table,text,count=1,flags=re.S);assert count==1
 path.write_text(text,encoding='cp1252')
 if case=='plain-periodic-water':
  for crop in output.glob('*.crp'):crop.write_text(assignment(crop.read_text(encoding='cp1252'),'SWSALINITY',0),encoding='cp1252')


if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--case',choices=CASES,required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--initial',type=int,choices=(1,2),default=1);a=p.parse_args();prepare(a.case,a.output,a.initial)
