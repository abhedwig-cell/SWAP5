"""Assemble unchanged reconstructed B1.11 VOLUNDR with independent capacities."""
from pathlib import Path
import argparse,hashlib,subprocess,tempfile
p=argparse.ArgumentParser();p.add_argument('--source',required=True);a=p.parse_args();source=Path(a.source)
assert hashlib.sha256(source.read_bytes()).hexdigest()=='537a84861fb256be67298064177b3e578305c1d036fe7376471d5bd3f7d4dcc7'
s=source.read_text();start=s.index('      real(8) function VOLUNDR');end=s.index('      end function VolUndr',start)+len('      end function VolUndr');f=s[start:end]
code='''module MOD_arrays
integer,parameter::macp=3
end module
module MOD_grid
real(8)::dz(3)=[10d0,20d0,30d0]
end module
program oracle
implicit none
real(8),external::VOLUNDR
real(8)::vol(3)=[.1d0,.4d0,.9d0],levels(5)=[-35d0,-30d0,-10d0,0d0,-60d0]
real(8)::expected(5)=[.75d0,.9d0,1.3d0,1.4d0,0d0],v
integer::i
do i=1,5
 v=VOLUNDR(levels(i),-60d0,3,vol)
 if(abs(v-expected(i))>1d-14)error stop 'source partial oracle'
 print '(es24.16)',v
end do
end program
'''+f
with tempfile.TemporaryDirectory(prefix='migmac07-source-') as t:
 f=Path(t)/'source.f90';f.write_text(code);outs=[]
 for opt in (0,2):
  exe=Path(t)/('o'+str(opt));subprocess.run(['gfortran','-ffree-line-length-none','-fcheck=all','-ffpe-trap=invalid,zero,overflow','-O'+str(opt),'-J',t,'-I',t,str(f),'-o',str(exe)],check=True,cwd=t)
  outs.append(subprocess.check_output([str(exe)],text=True))
 assert outs[0]==outs[1]
 print(outs[0],end='')
print('PPA_WU05_MIGMAC07_EXACT_VOLUNDR_O0_O2=PASS')
