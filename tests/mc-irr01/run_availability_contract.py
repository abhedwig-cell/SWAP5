"""Small real TASK4 owner versus authenticated B1.11, O0/O2 with raw evidence."""
from pathlib import Path
import argparse,base64,tarfile,io,hashlib,importlib.util,json,time,subprocess
ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('feedback',ROOT/'tests/modularity/run_modular_tests.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
def main():
 p=argparse.ArgumentParser();p.add_argument('--output',required=True);a=p.parse_args();out=Path(a.output).resolve();session=m.Session(out);start=time.perf_counter()
 archive=ROOT/'integration/audits/evidence/SWAP431_B111_AUTHORITY.tar.gz.b64'
 with tarfile.open(fileobj=io.BytesIO(base64.b64decode(archive.read_bytes())))as t:raw=t.extractfile(next(x for x in t.getmembers()if x.name.endswith('SWAP/irrigation.f90'))).read()
 assert hashlib.sha256(raw).hexdigest()=='65830c1e030be8030995547729d9298e6352778f132e5195af2962baa38a3bf1'
 body='\n'.join(raw.decode().split('      case(4)')[1].split('      case(9)')[0].splitlines()[1:]);assert 'gird = gird * f_irr_avail'in body and 'qssdi'not in body.lower()
 code='''program task4
use iso_fortran_env,only:real64
use mod_irrigation_availability_policy
implicit none
real(real64)::gird,dt_irr_event,irr_rate,f_irr_avail,qssdi,rate,duration
integer::i,j,k,status,n
logical::surface
n=0
do i=0,1
surface=i==0
do j=0,1
irr_rate=real(j,real64)*.48_real64
do k=0,100
f_irr_avail=real(k,real64)/100._real64
gird=.48_real64;qssdi=.48_real64;dt_irr_event=.25_real64
rate=qssdi;duration=dt_irr_event
'''+body+'''
call apply_irrigation_availability(.true.,f_irr_avail,irr_rate>0._real64,rate,duration,status,surface)
if(status/=IRR_AVAIL_OK)error stop 1
if(surface)then
if(transfer(rate,0_8)/=transfer(gird,0_8))error stop 2
else
if(transfer(rate,0_8)/=transfer(qssdi,0_8))error stop 3
endif
if(transfer(duration,0_8)/=transfer(dt_irr_event,0_8))error stop 4
n=n+1
enddo
enddo
enddo
print '(a,i0)','AVAIL_LITERAL_SOURCE_VECTORS=',n
end program
'''
 (out/'literal.f90').write_text(code);inputs={q:m.sha(ROOT/q)for q in ['src/process/mod_irrigation_availability_policy.f90','tests/mc-irr01/test_mc_irr01_availability_nonfinite.f90','tests/mc-irr01/run_availability_contract.py']};inputs[str(archive.relative_to(ROOT))]=m.sha(archive);rows=[]
 for opt in (0,2):
  build=out/f'o{opt}';build.mkdir();flags=['-std=f2008','-ffree-line-length-none','-fcheck=all','-ffpe-trap=invalid,zero,overflow',f'-O{opt}','-J',str(build),'-I',str(build)]
  for name,driver in [('literal',out/'literal.f90'),('nonfinite',ROOT/'tests/mc-irr01/test_mc_irr01_availability_nonfinite.f90')]:
   exe=build/name;session.command([session.compiler,*flags,str(ROOT/'src/process/mod_irrigation_availability_policy.f90'),str(driver),'-o',str(exe)],build,'compile-'+name)
   data,e=session.command([str(exe)],build,'native-'+name);rows.append(dict(opt=opt,name=name,stdout_sha256=hashlib.sha256(data).hexdigest(),returncode=e['returncode']))
 for r in rows:assert r['stdout_sha256']==next(x for x in rows if x['opt']==2-r['opt']and x['name']==r['name'])['stdout_sha256']
 assert all(m.sha(ROOT/q)==h for q,h in inputs.items())
 m.write(out/'RESULTS.json',dict(status='PASS',head=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),inputs=inputs,rows=rows,events=session.events,generated={'literal.f90':m.sha(out/'literal.f90')},wall_seconds=time.perf_counter()-start,vectors_per_optimization=404));print('AVAIL_DIRECT_TASK4_O0_O2=PASS',flush=True)
if __name__=='__main__':main()
