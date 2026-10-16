"""Exact authenticated source AFGEN+TCS2/3/4+DCS1 against real policy O0/O2."""
from pathlib import Path
import sys,importlib.util,json,time,hashlib,subprocess,argparse,base64,tarfile,io
ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('feedback',ROOT/'tests/modularity/run_modular_tests.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
def literal():
 archive=ROOT/'integration/audits/evidence/SWAP431_B111_AUTHORITY.tar.gz.b64'
 with tarfile.open(fileobj=io.BytesIO(base64.b64decode(archive.read_bytes())))as t:
  irrigation=t.extractfile('SWAP/irrigation.f90').read();functions=t.extractfile('SWAP/functions.f90').read()
 assert hashlib.sha256(irrigation).hexdigest()=='65830c1e030be8030995547729d9298e6352778f132e5195af2962baa38a3bf1'
 s=irrigation.decode().replace('\r\n','\n');f=functions.decode().replace('\r\n','\n')
 body=s.split('            ! timing - depletion of readily available water (fraction)')[1].split('            ! timing - fixed irrigation time')[0]
 depth=s.split('               ! depth - back to field capacity [cm]')[1].split('               ! depth - fixed depth [cm]')[0]
 af=f[f.index('   real(8) function afgen ('):f.index('   end function afgen')+len('   end function afgen')]
 code='''subroutine b111_root(tcs,dvs,rawtab,tawtab,dwatab,ditab,awlh,awmh,awah,cdef,grai,raithreshold,irrigevent,irr_depth)
implicit none
integer,intent(in)::tcs
real(8),intent(in)::dvs,rawtab(14),tawtab(14),dwatab(14),ditab(14),awlh,awmh,awah,cdef,grai,raithreshold
integer,intent(out)::irrigevent
real(8),intent(out)::irr_depth
integer,parameter::dcs=1
real(8)::tps2,tps3,tps4,depl,dps1,grai_red,afgen
irrigevent=0;irr_depth=0
'''+body+'\nif(irrigevent==2)then\n'+depth+'\nend if\nend subroutine\n'+af+'\n'
 return code

def main():
 p=argparse.ArgumentParser();p.add_argument('--output',required=True);a=p.parse_args();out=Path(a.output).resolve();session=m.Session(out);start=time.perf_counter()
 oracle=out/'literal.f90';oracle.write_text(literal());driver='tests/mc-irr01/test_batch_root_envelope.f90';sources,_=m.DEP.strict_closure(ROOT,[driver]);flags=m.COMMON
 inputs={str(q.relative_to(ROOT)):m.sha(q)for q in sources};inputs['tests/mc-irr01/run_batch_root_envelope.py']=m.sha(Path(__file__));rows=[]
 for opt in(0,2):
  build=out/f'o{opt}';build.mkdir();objects=[];opts=[*flags,f'-O{opt}','-J',str(build),'-I',str(build)]
  for i,q in enumerate([*sources,oracle]):
   obj=build/f'{i}.o';session.command([session.compiler,*opts,'-c',str(q),'-o',str(obj)],build,'compile');objects.append(obj)
  exe=build/'contract';session.command([session.compiler,*opts,*map(str,objects),'-o',str(exe)],build,'link');raw,e=session.command([str(exe)],build,'native');assert b'BATCH_ROOT_LITERAL_AFGEN_TCS234_DCS1_FULL_DOMAIN=PASS'in raw
  rows.append(dict(opt=opt,returncode=e['returncode'],stdout_sha256=hashlib.sha256(raw).hexdigest()))
 assert rows[0]['stdout_sha256']==rows[1]['stdout_sha256'];assert all(m.sha(ROOT/q)==h for q,h in inputs.items())
 m.write(out/'RESULTS.json',dict(status='PASS',head=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),inputs=inputs,generated={'literal.f90':m.sha(oracle)},rows=rows,flags=flags,compiler=session.identity,events=session.events,wall_seconds=time.perf_counter()-start));print('BATCH_ROOT_ENVELOPE_O0_O2=PASS')
if __name__=='__main__':main()
