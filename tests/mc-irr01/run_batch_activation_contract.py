"""Minimal actual material/root contract; controlled measured O0/O2 builds."""
from pathlib import Path
import sys,importlib.util,json,time,hashlib,subprocess,argparse,base64,tarfile,io
ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('feedback',ROOT/'tests/modularity/run_modular_tests.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
def literal():
 with tarfile.open(fileobj=io.BytesIO(base64.b64decode((ROOT/'integration/audits/evidence/SWAP431_B111_AUTHORITY.tar.gz.b64').read_bytes())))as t:raw=t.extractfile('SWAP/irrigation.f90').read()
 assert hashlib.sha256(raw).hexdigest()=='65830c1e030be8030995547729d9298e6352778f132e5195af2962baa38a3bf1'
 s=raw.decode().replace('\r\n','\n');body=s.split('         ! scheduled timing within desired period?')[1].split('         if (sw_irrig == 1')[0]
 return 'subroutine b111_window(yearstacrp,yearendcrp,t,t1900,tstairrig,tendirrig,tstairryrx,tendirryrx,flIrriTime)\nimplicit none\ninteger,intent(in)::yearstacrp,yearendcrp\nreal(8),intent(in)::t,t1900,tstairrig,tendirrig,tstairryrx,tendirryrx\nlogical,intent(out)::flIrriTime\ninteger,parameter::schedule=1\nflIrriTime=.false.\n'+body+'\nend subroutine\n'
def main():
 p=argparse.ArgumentParser();p.add_argument('--output',required=True);a=p.parse_args();out=Path(a.output).resolve();session=m.Session(out);start=time.perf_counter()
 driver='tests/mc-irr01/test_batch_activation.f90';sources,_=m.DEP.strict_closure(ROOT,[driver]);flags=m.COMMON
 oracle=out/'literal.f90';oracle.write_text(literal());inputs={str(s.relative_to(ROOT)):m.sha(s)for s in sources};inputs['tests/mc-irr01/run_batch_activation_contract.py']=m.sha(Path(__file__));results=[]
 for opt in (0,2):
  build=out/f'o{opt}';build.mkdir();objects=[]
  for i,source in enumerate([*sources,oracle]):
   obj=build/f'{i}.o';session.command([session.compiler,*flags,f'-O{opt}','-J',str(build),'-I',str(build),'-c',str(source),'-o',str(obj)],build,'compile');objects.append(obj)
  exe=build/'contract';session.command([session.compiler,*flags,f'-O{opt}',*map(str,objects),'-o',str(exe)],build,'link')
  raw,e=session.command([str(exe)],build,'native');assert b'BATCH_ACTIVATION_EXISTING_CALENDAR_SOURCE_LEAP_INVALID=PASS'in raw;results.append({'opt':opt,'stdout_sha256':hashlib.sha256(raw).hexdigest(),'returncode':e['returncode']})
 assert results[0]['stdout_sha256']==results[1]['stdout_sha256'];assert all(m.sha(ROOT/p)==h for p,h in inputs.items())
 r={'status':'PASS','head':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),'providers':len(sources)-1,'generated':{'literal.f90':m.sha(oracle)},'inputs':inputs,'compiler':session.identity,'flags':flags,'results':results,'events':session.events,'wall_seconds':time.perf_counter()-start};(out/'RESULTS.json').write_text(json.dumps(r,indent=2)+'\n');print(json.dumps({'status':'PASS','providers':len(sources)-1,'generated':{'literal.f90':m.sha(oracle)},'wall_seconds':r['wall_seconds']}))
if __name__=='__main__':main()
