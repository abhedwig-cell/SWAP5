"""Prepare only three existing targeted groundwater state-owner interfaces."""
import argparse,subprocess,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(ROOT/'tests/nomacro_drainage'),str(ROOT/'tests/nomacro_scheduled_subsurface')]
from initial_profile_groundwater_discovery import CASES,fixture
from original_output_baseline import assignment
SOURCE='4a4053c210ce5bdd8cb2506b79dcf9ad8b42a43f'
SELECTED=('water-h2-implicit-clock','cde-h1-snow-step','age-h2-monthly')


def prepare(case,output,initial):
 assert case in SELECTED and initial in (1,2)
 path='tests/nomacro_drainage/initial_profile_groundwater_discovery.py';assert (ROOT/path).read_bytes().replace(b'\r\n',b'\n')==subprocess.check_output(['git','show',SOURCE+':'+path],cwd=ROOT)
 fixture(output,next(spec for spec in CASES if spec[0]==case))
 if initial==1:
  path=output/'swap.swp';path.write_text(assignment(path.read_text(encoding='cp1252'),'SWINCO',1),encoding='cp1252')


if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--case',choices=SELECTED,required=True);p.add_argument('--initial',type=int,choices=(1,2),required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();prepare(a.case,a.output,a.initial)
