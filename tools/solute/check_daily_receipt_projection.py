"""Compile the actual receipt helper against original modules and replay raw receipts."""
from pathlib import Path
import argparse,json,math,subprocess,hashlib,random
ROOT=Path(__file__).resolve().parents[2]
DRIVER='''program receipt_probe
 use hybrid_step_budget, only: projected_daily_receipt_error
 use MOD_grid, only: numnod,dz
 use MOD_swap_base, only: swmacro,swsnow,swdra
 use MOD_irrigation, only: gird,nird,qssdi,qssdisum
 use MOD_meteo, only: graidt,nraidt,aintcdt
 use MOD_snow, only: ssnow
 use plant_interface, only: sicact,siccap,crsflx_in,crsflx_out,sw_inter
 use MOD_integral, only: igrai,isnrai,igsnow,igird,irunon,iqssdi,iqbup,iintc,iruno,iqrot,iepd,ievap,isubl,iqdra,iqbdo
 use MOD_drain, only: qdrtot
 use MOD_re_global, only: qrosum
 use variables, only: dt,theta,pond,qbot,epd,reva,runon,runots,swbotb,ivolbeg,ipondbeg,issnowbeg,isicbeg
 implicit none
 real(8) :: stocks(4),origin(4),flow(16)
 integer :: status,macro
 numnod=1;dz(1)=1d0;dt=0d0;swsnow=0;swdra=1;swbotb=6;sw_inter=1
 qssdi=0d0;qssdisum=0d0;gird=0d0;nird=0d0;graidt=0d0;nraidt=0d0;aintcdt=0d0
 crsflx_in=0d0;crsflx_out=0d0;qdrtot=0d0;qrosum=0d0;qbot=0d0;epd=0d0;reva=0d0;runon=0d0;runots=0d0
 do
   read(*,*,iostat=status) macro,stocks,origin,flow
   if(status/=0) exit
   swmacro=macro
   theta(1)=stocks(1);pond=stocks(2);ssnow=stocks(3);sicact=stocks(4);siccap=max(1d0,sicact)
   ivolbeg=origin(1);ipondbeg=origin(2);issnowbeg=origin(3);isicbeg=origin(4)
   igrai=flow(1);isnrai=flow(2);igsnow=flow(3);igird=flow(4);irunon=flow(5);iqssdi=flow(6);iqbup=flow(7)
   iintc=flow(8);iruno=flow(9);iqrot=flow(10);iepd=flow(11);ievap=flow(12);isubl=flow(13);iqdra=flow(14);iqbdo=flow(16)
   write(*,'(es25.17e3)') projected_daily_receipt_error()
 end do
end program
'''
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--reference-work',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
 a.output.mkdir(parents=True,exist_ok=False);objects=a.reference_work/'build/swap-obj';library=a.reference_work/'build/ttutil-obj/libttutil.a'
 fixture=ROOT/'integration/f-ci/hupsel51-water-balance/RECEIPT_FIXTURES.json';cases=json.loads(fixture.read_text());results={}
 # Arithmetic discriminators do not claim additional physical model cases.
 cases.append(dict(name='half-even',stocks=[1e16,1.0,1e-16,0.0],origin=[0.0]*4,flow=[0.0]*16))
 cases.append(dict(name='zero',stocks=[0.0]*4,origin=[0.0]*4,flow=[0.0]*16))
 rng=random.Random(51)
 for index in range(256):
  draw=lambda:math.ldexp(rng.random(),rng.randrange(-60,10))
  flow=[draw() for _ in range(16)];flow[14]=0.0
  cases.append(dict(name='finite-receipt-'+str(index),stocks=[draw() for _ in range(4)],origin=[draw() for _ in range(4)],flow=flow))
 for opt in ('O0','O2'):
  work=a.output/opt;work.mkdir();(work/'probe.f90').write_text(DRIVER)
  flags=['gfortran','-'+opt,'-ffree-line-length-none','-ffp-contract=off','-march=x86-64','-mtune=generic','-I'+str(objects)]
  subprocess.run(flags+['-c',str(ROOT/'app/hybrid_water/hybrid_step_budget.f90')],cwd=work,check=True,capture_output=True)
  subprocess.run(flags+['-o','probe.exe','probe.f90','hybrid_step_budget.o',*[str(q) for q in sorted(objects.glob('*.o')) if q.name!='swap_main.o'],str(library)],cwd=work,check=True,capture_output=True)
  text='\n'.join(' '.join(map(str,[macro,*c['stocks'],*c['origin'],*c['flow']])) for macro in (0,1) for c in cases)+'\n'
  run=subprocess.run([str(work/'probe.exe')],input=text,text=True,capture_output=True,check=True,timeout=10);(work/'stdout').write_text(run.stdout)
  actual=list(map(float,run.stdout.split()));assert len(actual)==2*len(cases)
  expected=[]
  for c in cases:
   end,origin=math.fsum(c['stocks']),math.fsum(c['origin']);i,o=math.fsum(c['flow'][:7]),math.fsum(c['flow'][7:])
   independent=math.fsum([*c['flow'][:7],*(-x for x in c['flow'][7:]),*c['origin'],*(-x for x in c['stocks'])])
   expected.append(max(abs(independent),abs(end-origin-i+o),abs(end-origin-(i-o))))
  assert actual==expected+[0.0]*len(cases),(actual,expected)
  assert actual[0]>1e-10 and all(x<=1e-10 for x in actual[1:3])
  results[opt]=dict(receipts=len(cases),actual_errors_cm=actual,exact_host_and_kernel_projection=True,old_refusal_detected=True,repaired_receipts_pass_unchanged_guard=True,macro_excluded=True)
 (a.output/'RESULT.json').write_text(json.dumps(dict(status='ACTUAL_RECEIPT_PROJECTION_O0_O2_PASS',profiles=results,fixture_sha256=hashlib.sha256(fixture.read_bytes()).hexdigest()),indent=2))
 print(json.dumps(results))
if __name__=='__main__':main()
