"""Small real TCS6 production closure and byte-verified literal B1.11 branch."""
from pathlib import Path
import sys,importlib.util,json,time,hashlib,subprocess,argparse,base64,tarfile,io
ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('feedback',ROOT/'tests/modularity/run_modular_tests.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
def main():
 p=argparse.ArgumentParser();p.add_argument('--output',required=True);a=p.parse_args();out=Path(a.output).resolve();session=m.Session(out);start=time.perf_counter()
 archive=ROOT/'integration/audits/evidence/SWAP431_B111_AUTHORITY.tar.gz.b64'
 with tarfile.open(fileobj=io.BytesIO(base64.b64decode(archive.read_bytes())))as donor:raw=donor.extractfile('SWAP/irrigation.f90').read()
 assert hashlib.sha256(raw).hexdigest()=='65830c1e030be8030995547729d9298e6352778f132e5195af2962baa38a3bf1'
 source=raw.decode().replace('\r\n','\n');body=source.split('            ! timing - fixed irrigation time (weekly during crop growth)',1)[1].split('            ! timing - critical pressure head',1)[0]
 # Retain the complete exact tcs6 if-block, including source comparator/order.
 body=body.strip()
 assert body.startswith('if (tcs == 6) then')and body.endswith('end if')
 oracle=out/'literal_tcs6.f90';oracle.write_text('subroutine b111_tcs6(dayfix,cdef,irgthreshold,irrigevent)\nuse iso_fortran_env,only:real64\nimplicit none\ninteger,intent(inout)::dayfix\nreal(real64),intent(in)::cdef,irgthreshold\ninteger,intent(out)::irrigevent\ninteger,parameter::tcs=6\nirrigevent=0\n'+body+'\nend subroutine\n')
 driver='tests/mc-irr01/test_tcs6_progression.f90';sources,_=m.DEP.strict_closure(ROOT,[driver]);flags=m.COMMON
 inputs={str(s.relative_to(ROOT)):m.sha(s)for s in sources};inputs[str(archive.relative_to(ROOT))]=m.sha(archive);inputs['tests/mc-irr01/run_tcs6_contract.py']=m.sha(Path(__file__));results=[]
 for opt in (0,2):
  build=out/f'o{opt}';build.mkdir();objects=[]
  for i,source in enumerate([*sources,oracle]):
   obj=build/f'{i}.o';session.command([session.compiler,*flags,f'-O{opt}','-J',str(build),'-I',str(build),'-c',str(source),'-o',str(obj)],build,'compile');objects.append(obj)
  exe=build/'contract';session.command([session.compiler,*flags,f'-O{opt}',*map(str,objects),'-o',str(exe)],build,'link')
  raw,e=session.command([str(exe)],build,'native');assert b'TCS6_PRODUCTION_WEEK_THRESHOLD_INELIGIBLE_REPLAY_RESTART=PASS'in raw;results.append({'opt':opt,'stdout_sha256':hashlib.sha256(raw).hexdigest(),'returncode':e['returncode']})
 assert results[0]['stdout_sha256']==results[1]['stdout_sha256'];assert all(m.sha(ROOT/p)==h for p,h in inputs.items())
 r={'status':'PASS','head':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),'providers':len(sources)-1,'inputs':inputs,'oracle_sha256':m.sha(oracle),'compiler':session.identity,'flags':flags,'results':results,'events':session.events,'wall_seconds':time.perf_counter()-start};(out/'RESULTS.json').write_text(json.dumps(r,indent=2)+'\n');print(json.dumps({'status':'PASS','providers':len(sources)-1,'wall_seconds':r['wall_seconds']}))
if __name__=='__main__':main()
