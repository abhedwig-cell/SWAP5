"""Declared saturated steady Darcy control with active original distributed drainage."""
import argparse,math,re
from pathlib import Path
from explicit_bottom9_inputs import prepare as base
from original_output_baseline import assignment

def prepare(kind,output,initial=2):
 assert kind in ('water','cde','age') and initial in (1,2)
 base(kind+'-pressure-daily',output,2)
 path=output/'swap.swp';text=path.read_text(encoding='cp1252')
 grid=re.search(r'(?mi)^[ \t]*ISUBLAY[ \t]+ISOILLAY[ \t]+HSUBLAY[ \t]+NCOMP[^\n]*\n((?:[ \t]*\d+[^\n]*\n)+)',text);assert grid;dz=[]
 for line in grid[1].splitlines():
  _,_,height,count=line.split();dz.extend([float(height)/int(count)]*int(count))
 assert len(dz)==34 and sum(dz)==200.
 lateral=[.01*height/200 for height in dz];heads=[0.]*34
 for i in range(33,0,-1):heads[i-1]=heads[i]+math.fsum(lateral[i:])*.5*(dz[i-1]+dz[i])
 pond=heads[0]+.01*.5*dz[0];assert .5<pond<10
 for key,value in dict(SWINCO=initial,GWLI=pond,SWDRA=1,PONDMX=10.).items():text=assignment(text,key,value)
 path.write_bytes(text.encode('cp1252'))
 path=output/'swap.dra';text=path.read_text(encoding='cp1252')
 for key,value in dict(DRAMET=1,SWDIVD=1).items():text=assignment(text,key,value)
 text,count=re.subn(r'(?mis)(^[ \t]*GWL[ \t]+QDRAIN[^\r\n]*\r?\n).*?(^[ \t]*\* End of table)',r'\g<1> 0.0 0.01\n -1000.0 0.01\n\g<2>',text);assert count==1;path.write_bytes(text.encode('cp1252'))
 path=output/'283.met';lines=path.read_text(encoding='cp1252').splitlines(keepends=True)
 for i,line in enumerate(lines):
  if line.startswith("'283',"):
   fields=line.rstrip('\r\n').split(',');assert len(fields)==12;fields[9]='10.1';lines[i]=','.join(fields)+'\n'
 path.write_bytes(''.join(lines).encode('cp1252'))
 return dict(initial_GWLI_pond_cm=pond,steady_pressure_cm=heads,original_uniform_saturated_Darcy_lateral_cm_day=lateral)

if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--kind',choices=('water','cde','age'),required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--initial',choices=(1,2),type=int,required=True);a=p.parse_args();prepare(a.kind,a.output,a.initial)
