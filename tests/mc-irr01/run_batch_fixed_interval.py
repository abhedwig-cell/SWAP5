"""Issue1271 measured real policy/management restart source contract, no new framework."""
from pathlib import Path
import argparse,sys,importlib.util,time,subprocess,json,base64,tarfile,io,hashlib
ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('feedback',ROOT/'tests/modularity/run_modular_tests.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
def main():
 p=argparse.ArgumentParser();p.add_argument('--output',required=True);a=p.parse_args();out=Path(a.output).resolve();session=m.Session(out);start=time.perf_counter()
 with tarfile.open(fileobj=io.BytesIO(base64.b64decode((ROOT/'integration/audits/evidence/SWAP431_B111_AUTHORITY.tar.gz.b64').read_bytes())))as t:
  raw=t.extractfile(next(x for x in t if x.name.endswith('SWAP/irrigation.f90'))).read()
 assert hashlib.sha256(raw).hexdigest()=='65830c1e030be8030995547729d9298e6352778f132e5195af2962baa38a3bf1'
 s=raw.decode().replace('\r\n','\n');a=s.index('               if (irrigevent == 2 .AND. (dayfix >= irgdayfix)) then');b=s.index('            \n            end if',a)
 literal=ROOT/'tests/mc-irr01/batch_fixed_interval_literal.inc';assert s[a:b]in literal.read_text()
 driver='tests/mc-irr01/test_batch_fixed_interval.f90';sources,_=m.DEP.strict_closure(ROOT,['src/runtime/mod_fmr_irrigation_management_restart.f90']);sources.append(ROOT/driver);flags=['-std=f2008','-ffree-line-length-none','-fcheck=all','-ffpe-trap=invalid,zero,overflow','-fbacktrace']
 inputs={str(q.relative_to(ROOT)):m.sha(q)for q in sources};inputs[str(literal.relative_to(ROOT))]=m.sha(literal);rows=[]
 for opt in(0,2):
  build=out/f'o{opt}';build.mkdir();opts=[*flags,f'-O{opt}','-J',str(build),'-I',str(build),'-I',str(literal.parent)];objects=[]
  for i,q in enumerate(sources):
   obj=build/f'{i}.o';session.command([session.compiler,*opts,'-c',str(q),'-o',str(obj)],build,'compile');objects.append(obj)
  exe=build/'contract';session.command([session.compiler,*opts,*map(str,objects),'-o',str(exe)],build,'link');raw,e=session.command([str(exe)],build,'native');assert b'BATCH_FIXED_INTERVAL_LITERAL_RESTART_NONMUTATION=PASS'in raw
  rows.append(dict(opt=opt,stdout_sha256=hashlib.sha256(raw).hexdigest(),returncode=e['returncode']))
 assert rows[0]['stdout_sha256']==rows[1]['stdout_sha256'];assert all(m.sha(ROOT/q)==h for q,h in inputs.items())
 m.write(out/'RESULTS.json',dict(status='PASS',head=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),providers=len(sources)-1,inputs=inputs,compiler=session.identity,flags=flags,rows=rows,events=session.events,wall_seconds=time.perf_counter()-start))
 print('BATCH_FIXED_INTERVAL_O0_O2=PASS')
if __name__=='__main__':main()
