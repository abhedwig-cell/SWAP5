"""Exact authenticated source AFGEN+TCS2/3/4+DCS1 against real policy O0/O2."""
from pathlib import Path
import sys,importlib.util,json,time,hashlib,subprocess,argparse,base64,tarfile,io
ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('feedback',ROOT/'tests/modularity/run_modular_tests.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
def literal():
 archive=ROOT/'integration/audits/evidence/SWAP431_B111_AUTHORITY.tar.gz.b64'
 with tarfile.open(fileobj=io.BytesIO(base64.b64decode(archive.read_bytes())))as t:raw=t.extractfile('SWAP/irrigation.f90').read()
 assert hashlib.sha256(raw).hexdigest()=='65830c1e030be8030995547729d9298e6352778f132e5195af2962baa38a3bf1'
 body=raw.decode().replace('\r\n','\n').rsplit('! in case of solutes: allow overirrigation when conc exceeds concthreshold',1)[1].split('! Rates')[0]
 return 'subroutine historical_salt(swsolu,swcirrthres,nodsen,cml,cirrthres,perirrsurp,irr_depth)\nimplicit none\ninteger::swsolu,swcirrthres,nodsen\nreal(8)::cml(1),cirrthres,perirrsurp,irr_depth\n'+body+'\nend subroutine\n'

def main():
 p=argparse.ArgumentParser();p.add_argument('--output',required=True);a=p.parse_args();out=Path(a.output).resolve();session=m.Session(out);start=time.perf_counter()
 oracle=out/'literal.f90';oracle.write_text(literal());driver='tests/mc-irr01/test_salt_completion_contract.f90';sources,_=m.DEP.strict_closure(ROOT,[driver]);flags=m.COMMON
 inputs={str(q.relative_to(ROOT)):m.sha(q)for q in sources};inputs['tests/mc-irr01/run_salt_completion_contract.py']=m.sha(Path(__file__));rows=[]
 for opt in(0,2):
  build=out/f'o{opt}';build.mkdir();objects=[];opts=[*flags,f'-O{opt}','-J',str(build),'-I',str(build)]
  for i,q in enumerate([*sources,oracle]):
   obj=build/f'{i}.o';session.command([session.compiler,*opts,'-c',str(q),'-o',str(obj)],build,'compile');objects.append(obj)
  exe=build/'contract';session.command([session.compiler,*opts,*map(str,objects),'-o',str(exe)],build,'link');raw,e=session.command([str(exe)],build,'native');assert b'SALT_COMPLETION_LITERAL360_INVALID6=PASS'in raw
  rows.append(dict(opt=opt,returncode=e['returncode'],stdout_sha256=hashlib.sha256(raw).hexdigest()))
 assert rows[0]['stdout_sha256']==rows[1]['stdout_sha256'];assert all(m.sha(ROOT/q)==h for q,h in inputs.items())
 m.write(out/'RESULTS.json',dict(status='PASS',head=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),inputs=inputs,generated={'literal.f90':m.sha(oracle)},rows=rows,flags=flags,compiler=session.identity,events=session.events,wall_seconds=time.perf_counter()-start));print('SALT_COMPLETION_CONTRACT_O0_O2=PASS')
if __name__=='__main__':main()
