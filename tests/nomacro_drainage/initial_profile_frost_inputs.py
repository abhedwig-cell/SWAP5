"""Prepare the literal qualified Frost fixture with original pressure initialization."""
import argparse,ast,re,subprocess,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(ROOT/'tests/nomacro_drainage'),str(ROOT/'tests/nomacro_scheduled_subsurface')]
import frost_cde_drainage_runtime as explicit
import frost_implicit_runtime as implicit
from original_output_baseline import assignment
BASE='b6b4959fb1301cedc95ddf551c11d6699a41e3ed'
CASES=('explicit-water','explicit-cde','implicit-water','implicit-cde')


def prepare(case,output,initial):
 assert case in CASES and initial in (1,2)
 if case.startswith('implicit-'):
  path='tests/nomacro_drainage/frost_implicit_runtime.py';raw=subprocess.check_output(['git','show',BASE+':'+path],cwd=ROOT)
  assert (ROOT/path).read_bytes().replace(b'\r\n',b'\n')==raw
  main=next(n for n in ast.parse(raw).body if isinstance(n,ast.FunctionDef) and n.name=='main');nodes=[n for n in main.body if isinstance(n,ast.FunctionDef) and n.name=='fixture'];assert len(nodes)==1
  namespace=dict(vars(implicit),original_fixture=explicit.thermal.fixture)
  exec(compile(ast.Module(body=nodes,type_ignores=[]),path,'exec'),namespace)
  namespace['fixture'](output,'water-frost-drained',3)
 else:explicit.thermal.fixture(output,'water-frost-drained',3)
 path=output/'swap.swp';text=path.read_text(encoding='cp1252')
 for key,value in dict(SWSOLU=int(case.endswith('-cde')),SWINCO=initial).items():text=assignment(text,key,value)
 if case.endswith('-cde'):text=assignment(text,'CPRE','0.01')
 path.write_text(text,encoding='cp1252');path=output/'swap.dra';path.write_text(assignment(path.read_text(encoding='cp1252'),'SWDIVD',1),encoding='cp1252')


if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--case',choices=CASES,required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--initial',type=int,choices=(1,2),default=1);a=p.parse_args();prepare(a.case,a.output,a.initial)
