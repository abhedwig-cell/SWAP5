"""Original linear PondRunoff equation: complex-step versus actual Fortran tangent."""
from pathlib import Path
import argparse,json,subprocess,sys,math
ROOT=Path(__file__).resolve().parents[2]
DRIVER='''program tangent_probe
 use hybrid_step_budget, only: linear_pond_top_jacobian
 implicit none
 real(8) :: c,step,pond,threshold,resistance
 integer :: status
 do
  read(*,*,iostat=status) c,step,pond,threshold,resistance
  if(status/=0) exit
  write(*,'(es25.17e3)') linear_pond_top_jacobian(c,step,pond,threshold,resistance)
 end do
end program
'''
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--reference-work',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();a.output.mkdir(parents=True,exist_ok=False)
 objects=a.reference_work/'build/swap-obj';library=a.reference_work/'build/ttutil-obj/libttutil.a';cases=[]
 for c in (.01,1.0,1000.0):
  for step in (1e-4,.04):
   for resistance in (.01,.5,1.0):
    for pond in (.1,.4):
     threshold=.2;half_dz=.5;conductivity=c*half_dz
     q0=max(0.0,pond-threshold)/resistance
     # Literal original scalar water equation from BoundTop/PondRunoff.
     # Perturb only h1, holding original lagged conductivity and rates fixed.
     h1=complex(pond+half_dz,1e-20)
     numerator=pond+q0*step-conductivity*step+step*c*h1
     denominator=1.0+step*c
     if pond>threshold:
      numerator+=step/resistance*threshold;denominator+=step/resistance
     original_pond=numerator/denominator
     original_top_residual=-conductivity*((original_pond-h1)/half_dz+1.0)
     expected=original_top_residual.imag/1e-20
     cases.append(dict(c=c,step=step,pond=pond,threshold=threshold,resistance=resistance,expected=expected))
 results={}
 for opt in ('O0','O2'):
  work=a.output/opt;work.mkdir();(work/'probe.f90').write_text(DRIVER)
  flags=['gfortran','-'+opt,'-ffree-line-length-none','-ffp-contract=off','-march=x86-64','-mtune=generic','-I'+str(objects)]
  for command in [flags+['-c',str(ROOT/'app/hybrid_water/hybrid_step_budget.f90')],flags+['-o','probe.exe','probe.f90','hybrid_step_budget.o',*[str(q) for q in sorted(objects.glob('*.o')) if q.name!='swap_main.o'],str(library)]]:
   run=subprocess.run(command,cwd=work,capture_output=True,text=True);assert run.returncode==0,run.stderr
  text='\n'.join(' '.join(str(c[k]) for k in ('c','step','pond','threshold','resistance')) for c in cases)+'\n'
  r=subprocess.run([str(work/'probe.exe')],input=text,capture_output=True,text=True,check=True,timeout=10);actual=list(map(float,r.stdout.split()));assert len(actual)==len(cases)
  errors=[abs(x-c['expected'])/max(abs(x),abs(c['expected'])) for x,c in zip(actual,cases)]
  assert max(errors)<1e-13
  old_errors=[abs(c['c']-c['expected'])/abs(c['expected']) for c in cases];assert max(old_errors)>10.0
  results[opt]=dict(cases=len(cases),maximum_relative_complex_step_error=max(errors),maximum_old_fixed_pond_relative_error=max(old_errors),actual=actual)
 (a.output/'RESULT.json').write_text(json.dumps(dict(status='ORIGINAL_LINEAR_POND_TANGENT_O0_O2_PASS',profiles=results,cases=cases,finite_difference_tolerance_is_not_a_physical_balance_tolerance=True),indent=2));print({k:{n:v for n,v in x.items() if n!='actual'} for k,x in results.items()})
if __name__=='__main__':main()
