"""Prepare the two exact portable original initialization input contexts."""
import argparse,re
from pathlib import Path
from vapor_boundary_inputs import prepare as base,assignment
CASES=('legacy-zih-water','saturated-vapor-cde')


def prepare(case,output):
 assert case in CASES;base('head5-active-cde8-11',output);path=output/'swap.swp';text=path.read_text(encoding='cp1252')
 for key,value in dict(SWINCO=1,SWBOTB=6,SWDRA=1,SWSOLU=int(case=='saturated-vapor-cde')).items():text=assignment(text,key,value)
 if case=='legacy-zih-water':
  for key,value in dict(iHWCKmodel='1 1',SWVAPOR='0 0').items():text=assignment(text,key,value)
  table='ZI = -0.5 -50.0 -195.0\nH = -20.0 -130.0 -210.0\n* End of table'
 else:table='HTB =\n -0.5 -70.0\n -70.0 -20.0\n -195.0 100.0\n* End of table'
 text,count=re.subn(r'(?mi)^[ \t]*HTB[ \t]*=[ \t]*\n.*?^\* End of table',lambda m:table,text,count=1,flags=re.S);assert count==1
 path.write_text(text,encoding='cp1252')


if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--case',choices=CASES,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();prepare(a.case,a.output)
