"""Declared analytical paired-boundary controls from frozen original fixtures."""
import argparse,re,subprocess,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(ROOT/'tests/nomacro_drainage'),str(ROOT/'tests/nomacro_scheduled_subsurface'),str(ROOT/'app/hybrid_water')]
from initial_profile_groundwater_discovery import fixture
from original_output_baseline import assignment
BASE='8ae1661391ed35125421290de3fb5d95ec8cd5b5'
CASES=(
 ('water-pressure-daily',0,'daily',1),
 ('water-pressure-periodic',0,'periodic',1),
 ('water-pressure-monthly',0,'monthly',1),
 ('water-pressure-subdaily',0,'subdaily',1),
 ('water-pressure-step',0,'step',1),
 ('water-pressure-mean6',0,'daily',6),
 ('cde-pressure-daily',1,'daily',1),
 ('cde-pressure-mean6',1,'daily',6),
 ('age-pressure-daily',2,'daily',1),
 ('age-pressure-monthly',2,'monthly',1),
 ('age-pressure-subdaily',2,'subdaily',1),
 ('age-pressure-step',2,'step',1),
 ('age-pressure-mean6',2,'daily',6),
)


def prepare(case,output,initial=1):
 assert initial in (1,2);label,solute,mode,mean=next(spec for spec in CASES if spec[0]==case)
 source='tests/nomacro_drainage/initial_profile_groundwater_discovery.py';assert (ROOT/source).read_bytes().replace(b'\r\n',b'\n')==subprocess.check_output(['git','show',BASE+':'+source],cwd=ROOT)
 fixture(output,(label,solute,0,0,0,False,'daily',1,1,1))
 path=output/'swap.swp';text=path.read_bytes().decode('cp1252')
 controls=dict(TEND='2002-02-04',SWINCO=initial,GWLI=0.0,SWBOTB=9,SWDRA=0,SWCROP=0,SWIRFIX=0,SWETR=1,SWDIVIDE=0,SWKIMPL=0,SWKMEAN=mean,SWHYST=0,SWSNOW=0,SWFROST=0,SWCSV=3,NPRINTDAY=3 if mode=='subdaily' else 1,SWMONTH=int(mode=='monthly'),SWODAT=0,PERIOD=1 if mode=='daily' else 0 if mode=='step' else 3,SWRES=int(mode=='daily'),FLPRINTDT='.TRUE.' if mode=='step' else '.FALSE.')
 for key,value in controls.items():text=assignment(text,key,value)
 def table(pattern,transform):
  nonlocal text
  matches=list(re.finditer(pattern,text,re.M|re.I|re.S));assert len(matches)==1;m=matches[0];text=text[:m.start()]+m[1]+transform(m[2])+m[3]+text[m.end():]
 table(r'(^[ \t]*HTB[ \t]*=[ \t]*\r?\n)(.*?)(^[ \t]*\* End of table)',lambda _: ' -0.5 0.5\n -195.0 195.0\n')
 def hydraulic(raw):
  rows=[]
  for line in raw.splitlines():
   if not line.strip():continue
   values=line.split();assert len(values)==10;values[6]=values[7]='1.0';rows.append(' '.join(values))
  assert len(rows)==2;return '\n'.join(rows)+'\n'
 table(r'(^[ \t]*ORES[ \t]+OSAT[^\r\n]*\r?\n)(.*?)(^[ \t]*\* End of table)',hydraulic)
 if solute==1:table(r'(^[ \t]*CMLTB[ \t]*=[ \t]*\r?\n)(.*?)(^[ \t]*\* End of table)',lambda _: ' -10.0 0.01\n -195.0 0.01\n')
 if solute==2:table(r'(^[ \t]*AGEMLTB[ \t]*=[ \t]*\r?\n)(.*?)(^[ \t]*\* End of table)',lambda _: ' -10.0 100.0\n -195.0 100.0\n')
 assert not re.search(r'(?mi)^[ \t]*DATE9[AB]\b',text)
 text+='\n* Declared saturated unit-gradient explicit9 control.\nDATE9A HBOT9\n2002-01-01 0.0\n2004-01-01 0.0\n* End of table\nDATE9B QBOT9\n2002-01-01 -1.0\n2004-01-01 -1.0\n* End of table\n';path.write_bytes(text.encode('cp1252'))
 meteo=output/'283.met';lines=meteo.read_bytes().decode('cp1252').splitlines(keepends=True);count=0
 for i,line in enumerate(lines):
  if not line.startswith("'283',"):continue
  values=line.rstrip('\r\n').split(',');assert len(values)==12;values[9]='10.0';values[10]='0.0';values[11]='1.0';lines[i]=','.join(values)+('\r\n' if line.endswith('\r\n') else '\n');count+=1
 assert count>=35;meteo.write_bytes(''.join(lines).encode('cp1252'))


if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--case',choices=[spec[0] for spec in CASES],required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--initial',type=int,choices=(1,2),default=1);a=p.parse_args();prepare(a.case,a.output,a.initial)
