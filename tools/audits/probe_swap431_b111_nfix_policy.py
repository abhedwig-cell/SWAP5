#!/usr/bin/env python3
"""Exact complete B1.11 demand outputs, independent input corpus and O0/O2."""
import base64,hashlib,io,json,math,os,random,subprocess,tarfile,tempfile,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
PROVIDER='src/crop/mod_b111_nfixation_policy.f90'
AUTHORITY='integration/audits/evidence/SWAP431_B111_AUTHORITY.tar.gz.b64'
SOURCE_SHA='071e65763be9e771b32b417252584d50874715d9ff11d3482c131826cc80bbb2'
def sha(b):return hashlib.sha256(b).hexdigest()
def corpus():
 rows=[]
 # Original six cases retained; storage demand is deliberately varied.
 for dvs,reltr,wso in [(0.5,1.,0.),(1.,1.,0.),(0.5,1.,200.),(0.5,1.,0.),(0.5,0.01,0.),(0.5,0.0100001,0.)]:
  rows.append([dvs,1.,reltr,.2,.03,.015,.015,1000.,800.,600.,0.,0.,0.,wso,.0176,0.,10.])
 for dvs in [0.,math.nextafter(1.,0.),1.,math.nextafter(1.,2.),2.]:
  for reltr in [0.,math.nextafter(.01,0.),.01,math.nextafter(.01,1.),1.]:
   for nfix in [0.,.2,1.]:rows.append([dvs,1.,reltr,nfix,.0317,.0123,.0089,1037.,819.,613.,3.,2.,1.,10000.,.0176,0.,10.])
 rng=random.Random(4311098)
 for i in range(512):
  rows.append([rng.random()*2.,rng.random()*2.,rng.random(),rng.random(),
    *[rng.random()*.08 for _ in range(3)],*[rng.random()*12000. for _ in range(3)],
    *[rng.random()*150. for _ in range(3)],rng.random()*20000.,.0176,rng.random()*100.,.1+rng.random()*20.])
 return rows

def main():
 with tarfile.open(fileobj=io.BytesIO(base64.b64decode((ROOT/AUTHORITY).read_bytes()))) as t:raw=t.extractfile('SWAP/wofostnut.f90').read()
 assert sha(raw)==SOURCE_SHA,'unknown complete B1.11 authority'
 source=raw.decode('latin1');start=source.index('      ndeml =',source.index('   subroutine demand_wofost_nut'));end=source.index('      return',start);literal=source[start:end]
 program="""module literal_nfix
implicit none
contains
subroutine reference(dvs,dvsnlt,reltr,nfixf,nmaxlv,nmaxst,nmaxrt,wlv,wst,wrt,anlv,anst,anrt,wso,nmaxso,anso,tcnt,values)
real(8),intent(in)::dvs,dvsnlt,reltr,nfixf,nmaxlv,nmaxst,nmaxrt,wlv,wst,wrt,anlv,anst,anrt,wso,nmaxso,anso,tcnt
real(8),intent(out)::values(3)
real(8)::ndeml,ndems,ndemr,ndemso,ndemto,nlimit,NdemandSoil,NdemandBioFix
"""+literal+"""
values=[ndemto,NdemandBioFix,NdemandSoil]
end subroutine
end module
program probe
use iso_fortran_env,only:int64
use literal_nfix
use mod_b111_nfixation_policy
implicit none
type(b111_nfixation_result_t)::r
real(8)::v(17),old(3),actual(3),maxerr(3)
integer::i,j,n,ios,mismatches
character(500)::path
call get_command_argument(1,path)
open(10,file=trim(path),status='old')
read(10,*)n
mismatches=0;maxerr=0d0
do i=1,n
 read(10,*,iostat=ios)v
 if(ios/=0)error stop 'incomplete independent corpus'
 call reference(v(1),v(2),v(3),v(4),v(5),v(6),v(7),v(8),v(9),v(10),v(11),v(12),v(13),v(14),v(15),v(16),v(17),old)
 call evaluate_b111_nfixation(v(1),v(2),v(3),v(4),v(5),v(6),v(7),v(8),v(9),v(10),v(11),v(12),v(13),r)
 if(r%status/=B111_NFIX_OK)error stop 'policy invalid'
 actual=[r%vegetative_demand,r%fixation,r%soil_demand]
 maxerr=max(maxerr,abs(actual-old))
 do j=1,3
  if(transfer(old(j),0_int64)/=transfer(actual(j),0_int64))mismatches=mismatches+1
 end do
 write(*,'(A,I0,6ES25.16)')'NFIX_LITERAL_CASE=',i,old,actual
end do
write(*,'(A,I0,A,I0,3ES25.16)')'B111_NFIX_LITERAL_CASES=',n,'|MISMATCHES=',mismatches,maxerr
if(mismatches/=0)error stop 'literal bit-identity mismatch'
print '(A)','B111_NFIXATION_SOURCE_ORACLE_PASS'
end program
"""
 target=os.environ.get('NFIX_LITERAL_EVIDENCE');temporary=None
 if target:work=Path(target);work.mkdir(parents=True,exist_ok=False)
 else:temporary=tempfile.TemporaryDirectory(prefix='swap431-b111-nfix-');work=Path(temporary.name)
 (work/'literal.f90').write_text(program);(work/'wofostnut.f90').write_bytes(raw)
 rows=corpus();(work/'inputs.txt').write_text(str(len(rows))+'\n'+'\n'.join(' '.join(format(v,'.17e') for v in row)for row in rows)+'\n')
 result={'cases':len(rows),'quantities_per_case':3,'source_sha256':{p:sha((ROOT/p).read_bytes())for p in [PROVIDER,AUTHORITY,'tools/audits/probe_swap431_b111_nfix_policy.py']},'complete_literal_sha256':SOURCE_SHA,'extracted_body_sha256':sha(literal.encode('latin1')),'optimizations':{},'compiler':subprocess.check_output(['gfortran','--version'],text=True)}
 outputs=[]
 for opt in ['O0','O2']:
  cmd=['gfortran','-'+opt,'-std=f2008','-ffree-line-length-none','-fcheck=all','-ffpe-trap=invalid,zero,overflow',str(ROOT/PROVIDER),'literal.f90','-o','probe'];t=time.monotonic()
  cp=subprocess.run(cmd,cwd=work,capture_output=True);compile_time=time.monotonic()-t;(work/(opt+'-compile.log')).write_bytes(cp.stdout+cp.stderr);cp.check_returncode()
  t=time.monotonic();cp=subprocess.run([str(work/'probe'),str(work/'inputs.txt')],cwd=work,capture_output=True);elapsed=time.monotonic()-t
  (work/(opt+'.stdout')).write_bytes(cp.stdout);(work/(opt+'.stderr')).write_bytes(cp.stderr);outputs.append(cp.stdout)
  result['optimizations'][opt]={'exit':cp.returncode,'compile_link_seconds':compile_time,'native_seconds':elapsed,'stdout_sha256':sha(cp.stdout),'command':cmd}
 result['byte_identity']=outputs[0]==outputs[1];result['pass']=result['byte_identity'] and all(v['exit']==0 for v in result['optimizations'].values());(work/'result.json').write_text(json.dumps(result,indent=2)+'\n')
 print(outputs[0].decode().splitlines()[-1]);print('B111_NFIX_CORPUS='+str(len(rows))+'|PASS='+str(result['pass']))
 if not result['pass']:raise SystemExit(1)
 if temporary:temporary.cleanup()
if __name__=='__main__':main()
