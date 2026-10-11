#!/usr/bin/env python3
"""Compare typed peat laws with exact authority-pinned B1.11 SHRINK bytes."""
import argparse, hashlib, pathlib, subprocess, tempfile
p=argparse.ArgumentParser()
p.add_argument('--source', required=True, type=pathlib.Path)
a=p.parse_args()
raw=a.source.read_bytes()
assert hashlib.sha256(raw).hexdigest() == 'f44049c551b5206ada58f1bb150bc250c5502171e49568a7ad8f01eed7bf106f'
s=raw.decode().replace('\r\n','\n')
start=s.index('      real(8) FUNCTION SHRINK (il, theta)')
end=s.index('      end function Shrink',start)+len('      end function Shrink')
authority=s[start:end]
wrapper='''module variables
implicit none
real(8)::thetsl(1)
end module
module legacy_peat
implicit none
integer::SwSoilShr(1),SwShrInp(1)
real(8)::ShrParA(1),ShrParB(1),ShrParC(1),ShrParD(1),ShrParE(1)
contains
'''+authority+'''\nend module
program oracle
use variables
use legacy_peat
use mod_macropore_dynamic_shrinkage
implicit none
type(peat_shrinkage_t)::p
real(8)::theta,actual,legacy,maxerr
integer::i,law
logical::ok
maxerr=0d0
thetsl=0.5d0;SwSoilShr=2
p%void_ratio_zero=0.2d0;p%transition_moisture_ratio=0.6d0
p%alpha=1.2d0;p%beta=3d0;p%p=0.1d0
p%intermediate_moisture_ratio=0.2d0;p%intermediate_void_ratio=0.4d0
ShrParA=p%void_ratio_zero;ShrParB=p%transition_moisture_ratio;ShrParE=p%p
do law=SHRINK_PEAT_DIRECT,SHRINK_PEAT_SEGMENTS
  if(law==SHRINK_PEAT_DIRECT)then
    SwShrInp=1;ShrParC=p%alpha;ShrParD=p%beta
  else
    SwShrInp=3;ShrParC=p%intermediate_moisture_ratio;ShrParD=p%intermediate_void_ratio
  end if
  do i=0,1000
    theta=0.5d0*i/1000d0
    legacy=SHRINK(1,theta)
    call evaluate_peat_shrinkage_fraction(theta,thetsl(1),p,law,actual,ok)
    if(.not.ok)error stop 'typed law unexpectedly rejected source profile'
    maxerr=max(maxerr,abs(legacy-actual))
    if(abs(legacy-actual)>2d-14)error stop 'source-bound parity mismatch'
  end do
end do
print '(a,es24.16)','PPA_WU05_MIGMAC03_LEGACY_MAX_ERROR=',maxerr
print '(a)','PPA_WU05_MIGMAC03_EXACT_B111_ORACLE=PASS'
end program
'''
with tempfile.TemporaryDirectory(prefix='migmac03-source-') as tmp:
    d=pathlib.Path(tmp);(d/'oracle.f90').write_text(wrapper)
    outputs=[]
    for opt in (0,2):
        subprocess.run(['gfortran','-std=f2008','-ffree-line-length-none',f'-O{opt}',f'-J{d}',f'-I{d}',
                        'src/process/macropore/mod_macropore_dynamic_shrinkage.f90',str(d/'oracle.f90'),'-o',str(d/'test')],check=True)
        output=subprocess.check_output([str(d/'test')],text=True);print(output,end='');outputs.append(output)
    assert outputs[0]==outputs[1]
    print('PPA_WU05_MIGMAC03_EXACT_B111_O0_O2=PASS')
