"""Prepare named original-deck boundary compositions without a model execution."""
import argparse,re,shutil,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tests/nomacro_scheduled_subsurface'))
from original_output_baseline import assignment
CASES={'undrained-water11':('11',0,0,6),'head5-active-cde8-11':('8 11',1,1,5),'unit8-active-cde7-8':('7 8',1,1,8)}


def prepare(case,output):
 models,solute,drain,bottom=CASES[case];shutil.copytree(ROOT/'reference/swap-4.3.1/projects/1.hupselbrook',output);path=output/'swap.swp';text=path.read_text(encoding='cp1252')
 for key,value in dict(SWSOLU=solute,SWSNOW=0,SWDRA=drain,SWBOTB=bottom,SWCSV=3,NPRINTDAY=1,SWMONTH=0,PERIOD=1,SWODAT=0,SWRES=1,FLPRINTDT='.FALSE.').items():text=assignment(text,key,value) if re.search(r'(?mi)^[ \t]*'+key+r'[ \t]*=',text) else text+'\n'+key+' = '+str(value)+'\n'
 text+='\niHWCKmodel = '+models+'\nALFA_2 = .005 .003\nNPAR_2 = 1.5 1.6\nOMEGA_1 = .8 .8\nH0 = -1e6 -1e6\nHA = -10.0 -10.0\nAPAR = -1.5 -1.5\nOMEGA_K = .01 .01\nSWVAPOR = 1 1\n'
 if solute:
  for key,value in dict(CPRE=.02,CDRAIN=.1,SWBOTBC=1,CSEEP=.15).items():text=assignment(text,key,value)
  pattern=r'(?mi)^([ \t]*CMLTB[ \t]*=[ \t]*\n)((?:[ \t]*[-+]?\d[^\n]*\n)+)';found=list(re.finditer(pattern,text));assert len(found)==1;rows=[line.split() for line in found[0][2].splitlines()];assert len(rows)==2 and all(len(row)==2 for row in rows)
  text=text[:found[0].start()]+found[0][1]+''.join(' '+row[0]+' 0.25\n' for row in rows)+text[found[0].end():]
 path.write_text(text,encoding='cp1252')
 for crop in output.glob('*.crp'):crop.write_text(assignment(crop.read_text(encoding='cp1252'),'SWSALINITY',0),encoding='cp1252')


if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--case',choices=CASES,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();prepare(a.case,a.output)
