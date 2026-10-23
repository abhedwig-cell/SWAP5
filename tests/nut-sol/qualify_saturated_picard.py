"""Small real solver domain/nonmutation controls; day470 supplies the failure discriminator."""
import argparse,hashlib,json,os,re,subprocess,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
HEAD='src/legacy/b1_10_port/headcalc.f90'
BASE='ef2110c6b0f1aa315eabb00c3672705b6d51a3bf'
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--output',type=Path,required=True);a=ap.parse_args()
 out=a.output.resolve();out.mkdir();events=[];fc=os.environ.get('FC','gfortran')
 def run(cmd,label,cwd=out):
  cmd=list(map(str,cmd));t=time.perf_counter();r=subprocess.run(cmd,cwd=cwd,capture_output=True,timeout=120);i=len(events)
  for k in ['stdout','stderr']:(out/f'{i:04d}.{k}').write_bytes(getattr(r,k))
  events.append(dict(command=cmd,label=label,returncode=r.returncode,seconds=time.perf_counter()-t,stdout=f'{i:04d}.stdout',stderr=f'{i:04d}.stderr'))
  (out/'events.json').write_text(json.dumps(events,indent=2)+'\n');assert r.returncode==0,r.stderr.decode()+r.stdout.decode();return r.stdout.decode()
 s=(ROOT/'tests/fsi/test_weather_surface_warm_start.f90').read_text().split(' call prepare(.001d0)',1)[0]
 s=s.replace(' integer::i,hits,invalidations,fallbacks',' integer::i,hits,invalidations,fallbacks,icase,variant\n real(8)::step,reference_head(4),reference_top')
 s=s.replace('drain=0d0;irrigation=0d0;','drain=.01d0;irrigation=0d0;')
 s=s.replace('(24,4)','(24,12)').replace('(1,4)','(1,12)')
 s=re.sub(r'\(4\)', '(12)', s).replace('active_nodes=4','active_nodes=12')
 at=s.index('drain=.01d0;irrigation=0d0;qroot=');end=s.index('\n',at)
 s=s[:at]+'drain=.1496903585052477d0/12d0;irrigation=0d0;qroot=.001d0'+s[end:]
 s=s.replace('cof(22,i)=-1d6;', '''if(i<=4)then
   cof(3,i)=10d0
  else
   cof(1,i)=.04d0;cof(2,i)=.45d0;cof(3,i)=2d0;cof(4,i)=.02d0;cof(5,i)=.4d0;cof(6,i)=1.6d0
  end if
  cof(7,i)=1d0-1d0/cof(6,i);cof(8,i)=cof(4,i);cof(10,i)=cof(3,i);cof(12,i)=.99d0*cof(3,i)
  cof(22,i)=-1d6;''')
 s=s.replace('r%boundary%bottom_mode=7','r%boundary%bottom_mode=2;r%boundary%bottom_flux=-.001d0')
 s=s.replace('r%numerical%consistent_provider_conductivity=.true.;r%numerical%reuse_trial_head=.true.',
             'r%numerical%consistent_provider_conductivity=.false.;r%numerical%reuse_trial_head=.false.;r%numerical%picard_conductivity_iteration=.true.')
 s=s.replace('r%numerical%max_iterations=20','r%numerical%max_iterations=64')
 s=s.replace('r%base_state%ponding_depth=.26877039212919984d0','r%base_state%ponding_depth=0d0')
 start=s.index(' r%base_state%pressure_head=[');end=s.index('\n',start)
 s=s[:start]+' r%base_state%pressure_head=[5.05876838108946458d0,14.8392381324302054d0,24.6701763411312029d0,34.5480861103484429d0,44.4170601651642016d0,54.1134994683966255d0,63.8819714261940845d0,73.7049915543364875d0,83.5650753686037433d0,93.4520235865341391d0,103.365836208127661d0,113.306513233384322d0]'+s[end:]
 body="""
 do variant=1,3
  hp%continuous_saturation_conductivity=variant/=3
  r%numerical%picard_conductivity_iteration=variant/=2
  do icase=1,3
   step=.03471875d0/real(icase,8)
   call bind_b110_default_mvg_provider(hyd,hp,step)
   call hyd%evaluate(r%base_state%pressure_head,r%base_state%water_content,kk,cc,dd)
   call bind_b110_dynamic_top_boundary_solver_provider(top,p,hp,1,r%base_state%ponding_depth,step, &
     0d0,0d0,0d0,0d0,.071167d0,.071167d0,0d0,1d0,1d0,implicit_conductivity=.true.)
   r%step_duration=step
   input_head=r%base_state%pressure_head;input_theta=r%base_state%water_content;input_pond=r%base_state%ponding_depth
   call solver%solve(r,cold,v)
   call require(all(r%base_state%pressure_head==input_head).and.all(r%base_state%water_content==input_theta).and. &
     r%base_state%ponding_depth==input_pond,'immutable trial origin')
   if(v%status==SW_SOLVE_CONVERGED)then
    call require(abs(v%unrounded_mass_balance_residual)<1d-12,'unchanged hard mass')
    reference_head=v%candidate_state%pressure_head;reference_top=v%top_flux
    r%step_duration=0d0
    call solver%solve(r,cold,c)
    call require(c%status/=SW_SOLVE_CONVERGED,'invalid duration rejected')
    call require(all(r%base_state%pressure_head==input_head).and.all(r%base_state%water_content==input_theta),'rejection origin')
    r%step_duration=step
    call solver%solve(r,cold,c)
    call require(c%status==SW_SOLVE_CONVERGED,'retry convergence')
    call require(all(c%candidate_state%pressure_head==reference_head).and.c%top_flux==reference_top,'ABA exact')
   end if
   write(*,*) 'PICARD_CASE',variant,icase,v%status,v%diagnostics%internal_retries,v%unrounded_mass_balance_residual
  end do
 end do
contains
 subroutine require(condition,label)
  logical,intent(in)::condition
  character(*),intent(in)::label
  if(.not.condition)then
   print *,label
   error stop 1
  end if
 end subroutine
end program
"""
 (out/'driver.f90').write_text(s+body)
 sources=run([os.sys.executable,'-B',ROOT/'tests/support/augment_bartholomeus_backend_sources.py','--all',
  'tests/fsi/fsi04_real_headcalc_stubs.f90','src/adapter/mod_reference_richards_legacy_binding.f90',
  'src/adapter/mod_b110_dynamic_top_boundary_solver_adapter.f90',HEAD],'closure',ROOT).splitlines()
 grid=(ROOT/sources[0]).read_text()
 for old,new in {'numnod = 4':'numnod = 12',
  '[-0.25d0, -0.75d0, -1.50d0, -2.50d0]':'[-5d0,-15d0,-25d0,-35d0,-45d0,-55d0,-65d0,-75d0,-85d0,-95d0,-105d0,-115d0]',
  '[0.50d0, 0.50d0, 1.00d0, 1.00d0]':'10d0',
  'disnod(numnod+1) = 1.0d0':'disnod(numnod+1) = [5d0,10d0,10d0,10d0,10d0,10d0,10d0,10d0,10d0,10d0,10d0,10d0,5d0]'}.items():
  assert grid.count(old)==1;grid=grid.replace(old,new)
 (out/'grid.f90').write_text(grid)
 (out/'old_headcalc.f90').write_bytes(subprocess.check_output(['git','show',BASE+':'+HEAD],cwd=ROOT))
 outputs={}
 for opt in ['O0','O2']:
  b=out/opt;b.mkdir();flags=['-std=f2008','-ffree-line-length-none','-w','-fopenmp','-fcheck=all','-fbacktrace','-ffpe-trap=invalid,zero,overflow','-'+opt,'-J'+str(b),'-I'+str(b)];objects=[]
  for i,p in enumerate(sources):
   if p==HEAD:continue
   obj=b/f'{i:04d}.o';run([fc,*flags,'-c',out/'grid.f90'if i==0 else ROOT/p,'-o',obj],opt+'-compile');objects.append(obj)
  for arm,source in [('old',out/'old_headcalc.f90'),('current',ROOT/HEAD)]:
   exe=b/arm;run([fc,*flags,source,out/'driver.f90',*objects,'-o',exe],opt+'-'+arm+'-link')
   outputs[opt+'-'+arm]=run([exe],opt+'-'+arm+'-native')
  old=outputs[opt+'-old'].splitlines();new=outputs[opt+'-current'].splitlines()
  assert old[3:]==new[3:],'unmatched route changed'
  assert all(int(x.split()[3])==SW_CONVERGED for x in new[:3])
  assert old==new,'successful ordinary solver cases must remain exact'
 assert outputs['O0-current']==outputs['O2-current']and outputs['O0-old']==outputs['O2-old'],'optimization drift'
 result=dict(status='SATURATED_PICARD_MATCHED_UNMATCHED_MASS_NONMUTATION_ABA_PASS',outputs=outputs,provider_count=len(objects),events=events,
  input_sha256={p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest()for p in sources+[str(Path(__file__).relative_to(ROOT)),'tests/fsi/test_weather_surface_warm_start.f90']})
 (out/'result.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(outputs,indent=2));print(result['status'])
SW_CONVERGED=1
if __name__=='__main__':main()
