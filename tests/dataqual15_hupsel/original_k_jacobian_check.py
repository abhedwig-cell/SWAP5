"""Independent finite differences of actual original K(h) on the initialized real soil."""
import argparse,json,subprocess,hashlib
from pathlib import Path
import original_oxygen_chronology as prior
USE='use MOD_MvG,only:check_w=>watcon,check_k=>hconduc,check_c=>moiscap,check_d=>dhconduc\n'
BLOCK='''
   block
    integer::i,j,u
    real(8)::points(5)=[-.1d0,-.02d0,-.005d0,-.001d0,1d0],hh,dd,analytic,numeric,th,cp
    open(newunit=u,file='derivative.dat',status='replace')
    do i=1,numnod
     do j=1,5
      hh=points(j);dd=1d-3*abs(hh)
      th=check_w(i,hh);cp=check_c(i,hh)
      analytic=check_d(i,hh,th,cp,1d0)
      numeric=(check_k(i,hh+dd,check_w(i,hh+dd),1d0)-check_k(i,hh-dd,check_w(i,hh-dd),1d0))/(2d0*dd)
      write(u,'(2(i0,1x),3(es25.17e3,1x))')i,j,hh,analytic,numeric
     end do
    end do
    close(u)
    stop 0
   end block
'''

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--provider',type=Path,required=True)
 p.add_argument('--control',type=Path,required=True);p.add_argument('--parent',type=Path,required=True)
 p.add_argument('--output',type=Path,required=True);a=p.parse_args()
 provider=a.provider.resolve();control=a.control.resolve();parent=a.parent.resolve();out=a.output.resolve();out.mkdir()
 original=(provider/'selected/swap.f90').read_text()
 pos=original.index('subroutine SWAP(iCaller, iTask, tstart_in, tend_in, swp_file, outfile, toswap, fromswap) ')
 prefix,s=original[:pos],original[pos:]
 anchor='use swap_exchange\n';assert s.count(anchor)==1;s=prefix+s.replace(anchor,anchor+USE)
 anchor='   if (swhea == 0) tsoil = dble(DefaultTemperature)\n';assert s.count(anchor)==1;s=s.replace(anchor,anchor+BLOCK)
 assert s.replace(USE,'').replace(BLOCK,'')==(provider/'selected/swap.f90').read_text()
 src=out/'swap.f90';src.write_text(s,encoding='utf-8',newline='\n')
 fc='C:/msys64/ucrt64/bin/gfortran.exe';flags=['-O2','-cpp','-Dlinux','-finit-local-zero','-fallow-argument-mismatch','-ffree-line-length-none','-I'+str(provider/'swobj'),'-I'+str(provider/'ttobj'),'-J'+str(out)]
 r=subprocess.run([fc,*flags,'-c',str(src),'-o',str(out/'swap.o')],capture_output=True);(out/'compile.stderr').write_bytes(r.stderr);assert r.returncode==0,r.stderr
 exe=out/'check.exe';objects=[parent/'main.o',parent/'output.o',*[x for x in sorted((provider/'swobj').glob('*.o')) if x.name not in ('swap.o','swapoutput.o','MOD_MvG_functions.o')],out/'swap.o',control/'MOD_MvG_functions.o',provider/'ttobj/libttutil.a','-o',exe]
 response=out/'link.args';response.write_text('\n'.join('"'+str(x).replace('\\','/')+'"' for x in objects)+'\n')
 r=subprocess.run([fc,'@'+str(response)],capture_output=True);(out/'link.stderr').write_bytes(r.stderr);assert r.returncode==0,r.stderr
 for n in ('swap.swp','maize.crp','potato.crp','grass.crp','283.met','swap.dra'):(out/n).write_bytes((control/'case'/n).read_bytes())
 r=subprocess.run([str(exe)],cwd=out,capture_output=True);(out/'stdout').write_bytes(r.stdout);(out/'stderr').write_bytes(r.stderr);assert r.returncode==0
 rows=[list(map(float,l.split())) for l in (out/'derivative.dat').read_text().splitlines()]
 assert len(rows)==170 and {(int(x[0]),int(x[1])) for x in rows}=={(i,j) for i in range(1,35) for j in range(1,6)}
 err=max(abs(x[3]-x[4])/max(1e-8,abs(x[3]),abs(x[4])) for x in rows)
 assert err<1e-4,err
 (out/'RESULT.json').write_text(json.dumps(dict(actual_soil_cases=len(rows),maximum_scaled_difference=err,source_sha256=prior.sha(src),executable_sha256=prior.sha(exe),production_admission=False),indent=2)+'\n')

if __name__=='__main__':main()
