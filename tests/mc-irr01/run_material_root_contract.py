"""Minimal actual material/root contract; controlled measured O0/O2 builds."""
from pathlib import Path
import sys,importlib.util,json,time,hashlib,subprocess,argparse
ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('feedback',ROOT/'tests/modularity/run_modular_tests.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
def main():
 p=argparse.ArgumentParser();p.add_argument('--output',required=True);a=p.parse_args();out=Path(a.output).resolve();session=m.Session(out);start=time.perf_counter()
 driver='tests/mc-irr01/test_material_root_binding.f90';sources,_=m.DEP.strict_closure(ROOT,[driver]);flags=m.COMMON
 inputs={str(s.relative_to(ROOT)):m.sha(s)for s in sources};results=[]
 for opt in (0,2):
  build=out/f'o{opt}';build.mkdir();objects=[]
  for i,source in enumerate(sources):
   obj=build/f'{i}.o';session.command([session.compiler,*flags,f'-O{opt}','-J',str(build),'-I',str(build),'-c',str(source),'-o',str(obj)],build,'compile');objects.append(obj)
  exe=build/'contract';session.command([session.compiler,*flags,f'-O{opt}',*map(str,objects),'-o',str(exe)],build,'link')
  raw,e=session.command([str(exe)],build,'native');assert b'MC_IRR01_MATERIAL_ROOT_LITERAL_NONMUTATION_INVALID_ABA=PASS'in raw;results.append({'opt':opt,'stdout_sha256':hashlib.sha256(raw).hexdigest(),'returncode':e['returncode']})
 assert results[0]['stdout_sha256']==results[1]['stdout_sha256'];assert all(m.sha(ROOT/p)==h for p,h in inputs.items())
 r={'status':'PASS','head':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),'providers':len(sources)-1,'inputs':inputs,'compiler':session.identity,'flags':flags,'results':results,'events':session.events,'wall_seconds':time.perf_counter()-start};(out/'RESULTS.json').write_text(json.dumps(r,indent=2)+'\n');print(json.dumps({'status':'PASS','providers':len(sources)-1,'wall_seconds':r['wall_seconds']}))
if __name__=='__main__':main()
