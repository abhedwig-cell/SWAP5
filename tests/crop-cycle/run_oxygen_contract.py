"""Small real process closure, literal historical oracle and existing negatives."""
from pathlib import Path
import argparse, sys, json, subprocess
ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(ROOT/'tests/modularity'),str(Path(__file__).parent)]
from run_modular_tests import Session, DEP, COMMON, sha, write
from oxygen_source_oracle import prepare
p=argparse.ArgumentParser();p.add_argument('--output',required=True);a=p.parse_args()
out=Path(a.output).resolve();session=Session(out)
oracle=out/'source_oracle.f90';authority=prepare(ROOT,oracle)
driver=ROOT/'tests/crop-cycle/test_oxygen_source_contract.f90'
ordered,_=DEP.strict_closure(ROOT,[str(driver.relative_to(ROOT))],[])
results=[];stdout=[]
for opt in (0,2):
 b=out/f'O{opt}';b.mkdir();objects=[];times={'compile_seconds':0.,'link_seconds':0.,'native_seconds':0.}
 for i,source in enumerate([*ordered,oracle]):
  obj=b/f'{i}.o';_,e=session.command([session.compiler,*COMMON,f'-O{opt}','-J',str(b),'-I',str(b),'-c',str(source),'-o',str(obj)],b,'compile')
  times['compile_seconds']+=e['wall_seconds'];objects.append(obj)
 exe=b/'test';_,e=session.command([session.compiler,*COMMON,f'-O{opt}',*map(str,objects),'-o',str(exe)],b,'link');times['link_seconds']=e['wall_seconds']
 raw,e=session.command([str(exe)],b,'native');times['native_seconds']=e['wall_seconds']
 assert b'CROP_CYCLE_OXYGEN_LITERAL_CONTRACT=PASS' in raw;stdout.append(raw)
 results.append({'opt':opt,'providers':len(ordered)-1,**times})
assert stdout[0]==stdout[1]
for opt in (0,2):
 session.execute('root_oxygen',opt);session.execute('root_contract',opt)
write(out/'RESULTS.json',{'status':'PASS','head':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(), 'authority':authority,'results':results,'inputs':{str(p.relative_to(ROOT)):sha(p) for p in ordered},'events':session.events,'compiler':session.identity})
print('CROP_CYCLE_OXYGEN_SMALL_O0_O2=PASS')
