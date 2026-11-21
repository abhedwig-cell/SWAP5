"""Target original CDE output calendars with admitted analytical/vapor hydraulics."""
import argparse,re,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(ROOT/'tests/nomacro_scheduled_subsurface'),str(ROOT/'tests/nomacro_drainage')]
from cde_interval_runtime import fixture
from original_output_baseline import assignment
CASES={
 'model7-periodic6':('7',False,1,6,'periodic'),
 'model7-clock6':('7',False,1,6,'clock'),
 'model7-perstep6':('7',False,1,6,'perstep'),
 'vapor8-periodic6':('8',True,1,6,'periodic'),
 'vapor8-monthly6':('8',True,1,6,'monthly'),
 'mixed7-8-clock6':('7 8',True,1,6,'clock'),
 'mixed7-8-perstep6':('7 8',True,1,6,'perstep'),
 'vapor8-periodic5':('8',True,1,5,'periodic'),
 'vapor8-monthly5':('8',True,1,5,'monthly'),
 'mixed7-8-clock8':('7 8',True,1,8,'clock'),
 'mixed7-8-perstep8':('7 8',True,1,8,'perstep'),
 'vapor8-explicit-undrained5':('8',True,0,5,'explicit')}


def prepare(case,output,dense=False):
 models,vapor,drain,bottom,mode=CASES[case]
 fixture(output,'periodic' if mode in ('clock','perstep') or dense else mode,0,3,reset=0 if mode in ('monthly','explicit','perstep') and not dense else 1,snow=0)
 path=output/'swap.swp';text=path.read_text(encoding='cp1252')
 edits=dict(SWINCO=2,SWKIMPL=0,SWHYST=0,SWSNOW=0,SWFROST=0,SWDRA=drain,SWBOTB=bottom,SWBBCFILE=0,SWHEA=1,SWCALT=2,SWBR=0,SWMETDETAIL=0,SWSOLU=1,SWCSV=3,NUM_DECIMALS=12,iHWCKmodel=models,SWVAPOR='1 1' if vapor else '0 0',INLIST_CSV=repr('WATBAL,ETTERMS,SOLBAL,GWL,CROP,WOFOST,GRASS'))
 if dense:edits.update(NPRINTDAY=1,PERIOD=1,SWMONTH=0,SWODAT=0,SWRES=1,FLPRINTDT='.FALSE.')
 elif mode=='clock':edits.update(NPRINTDAY=2,PERIOD=1,SWMONTH=0,SWODAT=0,SWRES=1,FLPRINTDT='.FALSE.')
 elif mode=='perstep':edits.update(NPRINTDAY=1,PERIOD=1,SWMONTH=0,SWODAT=0,SWRES=0,FLPRINTDT='.TRUE.')
 for key,value in edits.items():text=assignment(text,key,value) if re.search(r'(?mi)^[ \t]*'+key+r'[ \t]*=',text) else text+'\n'+key+' = '+str(value)+'\n'
 for key,value in dict(ALFA_2='.005 .003',NPAR_2='1.5 1.6',OMEGA_1='.8 .8',H0='-1e6 -1e6',HA='-10.0 -10.0',APAR='-1.5 -1.5',OMEGA_K='.01 .01').items():
  text=assignment(text,key,value) if re.search(r'(?mi)^[ \t]*'+key+r'[ \t]*=',text) else text+'\n'+key+' = '+value+'\n'
 path.write_text(text,encoding='cp1252')
 for crop in output.glob('*.crp'):crop.write_text(assignment(crop.read_text(encoding='cp1252'),'SWSALINITY',0),encoding='cp1252')


if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--case',choices=CASES,required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--dense',action='store_true');a=p.parse_args();prepare(a.case,a.output,a.dense)
