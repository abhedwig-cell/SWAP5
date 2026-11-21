"""Prepare original initialization with existing hysteresis/Snow/implicit owners."""
import argparse,re,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(ROOT/'tests/nomacro_scheduled_subsurface'),str(ROOT/'tests/nomacro_drainage')]
import output_hysteresis as hysteresis
import implicit_conductivity_runtime as implicit
from vapor_boundary_inputs import prepare as vapor
from original_output_baseline import assignment
CASES={**{f'hys{mode}-{kind}':('hysteresis',kind,mode) for mode in (1,2) for kind in ('water','cde')},**{f'{family}-{kind}':(family,kind,0) for family in ('implicit','snow-vapor','implicit-snow') for kind in ('water','cde')}}


def prepare(case,output,initial=1):
 family,kind,mode=CASES[case]
 if family=='hysteresis':hysteresis.fixture(output,kind,mode,3,'daily')
 elif family in ('implicit','implicit-snow'):implicit.fixture(output,int(kind=='cde'),0,5,False,1,'daily',3,1,1)
 else:vapor('head5-active-cde8-11',output)
 path=output/'swap.swp';text=path.read_text(encoding='cp1252')
 edits=dict(SWINCO=initial,NPRINTDAY=1,PERIOD=1,SWMONTH=0,SWODAT=0,SWRES=1,FLPRINTDT='.FALSE.')
 if family=='snow-vapor':edits.update(SWSNOW=1,SWBOTB=6,SWDRA=1,SWSOLU=int(kind=='cde'))
 if family=='implicit-snow':edits['SWSNOW']=1
 for key,value in edits.items():text=assignment(text,key,value) if re.search(r'(?mi)^[ \t]*'+key+r'[ \t]*=',text) else text+'\n'+key+' = '+str(value)+'\n'
 # Same independent nonhydrostatic original profile on all state owners.
 table='HTB =\n -0.5 -20.0\n -50.0 -130.0\n -195.0 -210.0\n* End of table'
 text,count=re.subn(r'(?mi)^[ \t]*HTB[ \t]*=[ \t]*\n.*?^\* End of table',lambda m:table,text,count=1,flags=re.S);assert count==1
 path.write_text(text,encoding='cp1252')


if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--case',choices=CASES,required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--initial',type=int,choices=(1,2),default=1);a=p.parse_args();prepare(a.case,a.output,a.initial)
