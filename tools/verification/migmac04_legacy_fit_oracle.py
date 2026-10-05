#!/usr/bin/env python3
"""Execute exact pinned legacy SHRINKPAR with process timeouts and compare equations."""
import argparse,hashlib,pathlib,subprocess,tempfile,resource
p=argparse.ArgumentParser();p.add_argument('--source',required=True,type=pathlib.Path);a=p.parse_args()
raw=a.source.read_bytes()
assert hashlib.sha256(raw).hexdigest()=='f44049c551b5206ada58f1bb150bc250c5502171e49568a7ad8f01eed7bf106f'
s=raw.decode().replace('\r\n','\n');start=s.index('      SUBROUTINE SHRINKPAR (itask, il)');end=s.index('      end subroutine ShrinkPar',start)+len('      end subroutine ShrinkPar');authority=s[start:end]
wrapper='''module variables
implicit none
real(8)::thetsl(1)
end module
module legacy_fit
implicit none
real(8)::ShrParA(1),ShrParB(1),ShrParC(1),ShrParD(1),ShrParE(1)
contains
'''+authority+'''\nend module
program oracle
use variables
use legacy_fit
use mod_macropore_dynamic_shrinkage
implicit none
type(clay_kim_shrinkage_t)::clay
type(peat_shrinkage_t)::peat
real(8)::delta,f,c1,c2,c3,p,maximum
integer::j
logical::ok
character(16)::mode
call get_command_argument(1,mode)
thetsl=0.5d0
if(mode=='boundary')then
  ShrParA=0.3d0;ShrParB=0.3d0
  call SHRINKPAR(2,1)
  error stop 'legacy derivative-zero case unexpectedly survived IEEE traps'
end if
ShrParA=0.2d0;ShrParB=0.3d0
call SHRINKPAR(2,1)
call prepare_clay_kim_option2(0.5d0,0.2d0,0.3d0,clay,ok)
if(.not.ok)error stop 'typed clay failure'
delta=abs(clay%beta_k-ShrParB(1))
if(delta>1d-4)error stop 'legacy clay mismatch outside historical stopping accuracy'
print '(a,es24.16)','PPA_WU05_MIGMAC04_LEGACY_CLAY_BETA_DELTA=',delta
maximum=0d0
do j=1,2
  p=0.1d0
  if(j==2)p=-0.3d0
  ShrParA=0.2d0;ShrParB=0.6d0;ShrParC=0.1d0;ShrParD=0.3d0;ShrParE=p
  call SHRINKPAR(4,1)
  call prepare_peat_characteristic_points(0.5d0,0.2d0,0.6d0,0.1d0,0.3d0,p,peat,ok)
  if(.not.ok)error stop 'typed peat failure'
  delta=abs(peat%alpha-ShrParC(1));maximum=max(maximum,delta)
  if(delta>1d-3)error stop 'legacy peat mismatch outside historical stopping accuracy'
  c1=2d0;c2=1d0/3d0;c3=(0.3d0/0.28d0-1d0)/p
  if(j==2)c3=(0.2d0/0.28d0-1d0)/p
  f=c2**peat%alpha*(exp(-peat%alpha*c2)-exp(-peat%alpha*c1))/(exp(-peat%alpha)-exp(-peat%alpha*c1))-c3
  if(abs(f)>2d-12)error stop 'typed source equation residual'
end do
print '(a,es24.16)','PPA_WU05_MIGMAC04_LEGACY_PEAT_ALPHA_DELTA_MAX=',maximum
print '(a)','PPA_WU05_MIGMAC04_EXACT_SOURCE_FIT_EQUATIONS=PASS'
end program
subroutine swap_error(where,message)
implicit none
character(*),intent(in)::where,message
print *,where,message
error stop 2
end subroutine
'''
resource.setrlimit(resource.RLIMIT_CORE,(0,0))
with tempfile.TemporaryDirectory(prefix='migmac04-source-') as tmp:
 d=pathlib.Path(tmp);(d/'oracle.f90').write_text(wrapper);outputs=[]
 for opt in (0,2):
  subprocess.run(['gfortran','-std=f2008','-ffree-line-length-none','-ffpe-trap=invalid,zero,overflow',f'-O{opt}',f'-J{d}',f'-I{d}',
                  'src/process/macropore/mod_macropore_dynamic_shrinkage.f90',str(d/'oracle.f90'),'-o',str(d/'test')],check=True)
  output=subprocess.check_output([str(d/'test')],text=True,timeout=5);print(output,end='');outputs.append(output)
  negative=subprocess.run([str(d/'test'),'boundary'],capture_output=True,text=True,timeout=5)
  assert negative.returncode == -8,(negative.returncode,negative.stderr)
  print(f'PPA_WU05_MIGMAC04_LEGACY_A_EQ_V_SIGFPE_O{opt}=CONFIRMED')
 assert outputs[0]==outputs[1]
 print('PPA_WU05_MIGMAC04_EXACT_SOURCE_FIT_O0_O2=PASS')
