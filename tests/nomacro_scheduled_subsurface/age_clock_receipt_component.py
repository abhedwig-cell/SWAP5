"""Call real generated Integral/Watstor against its read-only trial projection."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import time

DRIVER='''program receipt_contract
use iso_fortran_env,only:real128,int64
use MOD_integral,only:integral,hybrid_output_trial_residual
use hybrid_age_output_state
use MOD_grid,only:numnod,dz
use MOD_swap_base,only:swmacro,swsnow,swdra
use MOD_drain,only:nrlevs,qdrtot
use MOD_meteo,only:graidt,nraidt,aintcdt,peva,ptra
use MOD_irrigation,only:gird,nird,qssdi,qssdisum
use MOD_re_global,only:qrosum
use variables,only:theta,pond,volact,dt,epd,reva,qbot,runots,runon,swbotb
use plant_interface,only:sw_inter,sicact,siccap,crsflx_in,crsflx_out,noddrz
implicit none
type(output_receipt_frame_t)::saved
real(8)::trial,actual,stock(12),flow(16),terms(28),saved_sicact
integer::status,scenario,step,count
count=0
swmacro=0;swsnow=0;swdra=1;swbotb=6
numnod=2;nrlevs=1;noddrz=0
dz(1:2)=[2d0,3d0];theta(1:2)=[0.25d0,0.3d0]
do scenario=1,6
 sw_inter=1
 if(scenario>3)sw_inter=3
 sicact=0.05d0;siccap=0.12d0
 pond=0.01d0;call watstor()
 call begin_output_receipt(hybrid_output_frame,[volact,pond,0d0,sicact,0d0,0d0],status)
 if(status/=0)error stop 'begin'
 do step=1,7
  dt=0.03125d0;graidt=0.03d0;nraidt=0.025d0;aintcdt=0.005d0
  gird=0.012d0;nird=0.012d0;qssdi(1:2)=[0.001d0,-0.0002d0];qssdisum=sum(qssdi(1:2))
  qrosum=0.002d0;qdrtot=0.004d0;epd=0.0001d0;reva=0.0004d0
  runon=0.002d0;runots=0.00003d0;peva=0d0;ptra=0d0
  qbot=real(scenario-2,8)*0.001d0
  crsflx_in=0.0006d0;crsflx_out=0.0002d0
  if(step==6)crsflx_in=20d0
  if(step==7)crsflx_out=30d0
  theta(1)=theta(1)+0.00001d0;pond=pond+0.00002d0
  saved=hybrid_output_frame;saved_sicact=sicact
  trial=hybrid_output_trial_residual()
  if(any(saved%start_stock_cm/=hybrid_output_frame%start_stock_cm))error stop 'mutated stock'
  if(any(saved%flow_cm/=hybrid_output_frame%flow_cm))error stop 'mutated flow'
  if(saved%active.neqv.hybrid_output_frame%active)error stop 'mutated activity'
  if(sicact/=saved_sicact)error stop 'mutated canopy'
  ! Execute the real original Integral(3), not a duplicate receipt formula.
  call integral(3)
  call watstor()
  saved=hybrid_output_frame
  call finish_output_receipt(hybrid_output_frame,[volact,pond,0d0,sicact,0d0,0d0],stock,flow,status)
  if(status/=0)error stop 'finish'
  terms=[flow(1:7),-flow(8:16),stock(7:12),-stock(1:6)]
  actual=real(sum(real(terms,real128)),8)
  if(transfer(trial,0_int64)/=transfer(actual,0_int64))error stop 'different actual Integral receipt'
  hybrid_output_frame=saved
  count=count+1
 end do
 hybrid_output_frame%active=.false.
end do
if(count/=42)error stop 'count'
write(*,'(a,i0)')'ACTUAL_ORIGINAL_TRIAL_RECEIPT_EXACT_NONMUTATION_CASES ',count
end program
'''


def main():
    p=argparse.ArgumentParser()
    for name in ('build','reference-work','output'):p.add_argument('--'+name,type=Path,required=True)
    p.add_argument('--optimization',choices=('O0','O2'),required=True)
    a=p.parse_args();a.output.mkdir();build=a.build.resolve();provider=a.reference_work.resolve()/'build'
    (a.output/'receipt_contract.f90').write_text(DRIVER)
    sha=lambda path:hashlib.sha256(path.read_bytes()).hexdigest()
    result=dict(status='RUNNING',build_sha256=sha(build/'BUILD.json'),optimization=a.optimization,events=[])
    start=time.monotonic()
    def call(cmd,label):
        r=subprocess.run(list(map(str,cmd)),cwd=a.output,capture_output=True,text=True,timeout=60)
        (a.output/(label+'.log')).write_text(r.stdout+r.stderr)
        result['events'].append(dict(label=label,returncode=r.returncode));assert r.returncode==0,r.stderr
        return r
    try:
        call(['gfortran','-'+a.optimization,'-ffree-line-length-none','-ffp-contract=off','-fcheck=bounds','-I'+str(build),'-I'+str(provider/'swap-obj'),'-I'+str(provider/'ttutil-obj'),'-c',a.output.resolve()/'receipt_contract.f90','-o',a.output.resolve()/'driver.o'],'compile')
        replacements={path.name.lower():path for path in build.glob('*.o') if path.name.lower()!='swap_main.o'}
        linked=[]
        for path in sorted((provider/'swap-obj').glob('*.o')):
            if path.name.lower()=='swap_main.o':continue
            linked.append(replacements.pop(path.name.lower(),path))
        linked+=list(replacements.values())
        exe=a.output.resolve()/'receipt_contract.exe'
        call(['gfortran','-o',exe,a.output.resolve()/'driver.o',*linked,provider/'ttutil-obj/libttutil.a'],'link')
        r=call([exe],'run');assert r.stdout.strip()=='ACTUAL_ORIGINAL_TRIAL_RECEIPT_EXACT_NONMUTATION_CASES 42'
        result.update(status='ACTUAL_ORIGINAL_TRIAL_RECEIPT_EXACT_NONMUTATION_42_PASS',executable_sha256=sha(exe),linked_objects={str(path):sha(path) for path in linked},cases=42,source_sha256=sha(a.output/'receipt_contract.f90'))
    finally:
        result['seconds']=time.monotonic()-start;(a.output/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n')


if __name__=='__main__':main()
