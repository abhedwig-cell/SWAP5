"""Fresh small production closure, predecessor discriminator and immutable FSI35 replay.

The FSI35 native body is extracted unchanged from its owning runner. Its separate
moving-source admission guards are not a scientific test and remain a separate
admission requirement; this script never reports that admission as PASS.
"""
import argparse,hashlib,json,os,subprocess,sys,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
BASE='710b41736214bcec80f0fe9bea6660cafa449024'
HEAD='src/legacy/b1_10_port/headcalc.f90'
RUNNER='tests/fci/run_fci93_non_m1_fixed_k_qualification.sh'
sha=lambda raw:hashlib.sha256(raw).hexdigest()
def main():
 ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--output',required=True,type=Path)
 a=ap.parse_args();out=a.output.resolve();out.mkdir(parents=True,exist_ok=False)
 fc=os.environ.get('FC','gfortran');events=[]
 def run(cmd,label,cwd=out,check=True):
  start=time.monotonic();r=subprocess.run(list(map(str,cmd)),cwd=cwd,capture_output=True,timeout=120)
  stem=f'{len(events):04d}-{label}'
  for stream in ['stdout','stderr']:(out/(stem+'.'+stream)).write_bytes(getattr(r,stream))
  events.append(dict(command=list(map(str,cmd)),returncode=r.returncode,seconds=time.monotonic()-start,stdout=stem+'.stdout',stderr=stem+'.stderr'))
  (out/'events.json').write_text(json.dumps(events,indent=2)+'\n')
  if check:r.check_returncode()
  return r
 text=(ROOT/'tests/fsi/test_weather_surface_warm_start.f90').read_text()
 prefix=text.split(' call prepare(.001d0)',1)[0]
 prefix=prefix.replace(' integer::i,hits,invalidations,fallbacks',' integer::i,hits,invalidations,fallbacks,icase\n real(8)::step')
 prefix=prefix.replace('hp%continuous_saturation_conductivity=.true.','hp%continuous_saturation_conductivity=.false.')
 prefix=prefix.replace('r%boundary%bottom_mode=7','r%boundary%bottom_mode=2;r%boundary%bottom_flux=-.001d0')
 prefix=prefix.replace('r%numerical%consistent_provider_conductivity=.true.;r%numerical%reuse_trial_head=.true.',
                       'r%numerical%consistent_provider_conductivity=.false.;r%numerical%reuse_trial_head=.false.')
 prefix=prefix.replace('r%numerical%max_iterations=20','r%numerical%max_iterations=8')
 prefix=prefix.replace('r%base_state%ponding_depth=.26877039212919984d0','r%base_state%ponding_depth=1.9413322351919804d-10')
 start=prefix.index(' r%base_state%pressure_head=[');end=prefix.index('\n',start)
 prefix=prefix[:start]+' r%base_state%pressure_head=[2.4120211830816394d0,7.2636354352625707d0,14.582414643142846d0,24.451074465940223d0]'+prefix[end:]
 body="""
 do icase=1,3
  step=10d0**(-3*icase)
  call bind_b110_default_mvg_provider(hyd,hp,step)
  call hyd%evaluate(r%base_state%pressure_head,r%base_state%water_content,kk,cc,dd)
  call bind_b110_dynamic_top_boundary_solver_provider(top,p,hp,1,r%base_state%ponding_depth,step, &
    0d0,0d0,0d0,0d0,.02d0,.02d0,0d0,1d0,1d0,implicit_conductivity=.true.)
  r%step_duration=step
  input_head=r%base_state%pressure_head;input_theta=r%base_state%water_content;input_pond=r%base_state%ponding_depth
  call solver%solve(r,cold,v)
  call require(all(r%base_state%pressure_head==input_head).and.all(r%base_state%water_content==input_theta).and. &
    r%base_state%ponding_depth==input_pond,'immutable trial origin')
  if(v%status==SW_SOLVE_CONVERGED)call require(abs(v%unrounded_mass_balance_residual)<1d-12,'unchanged hard mass')
  write(*,*) 'SATURATED_FLUX_CASE',icase,v%status,v%diagnostics%internal_retries,v%unrounded_mass_balance_residual
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
 driver=out/'driver.f90';driver.write_text(prefix+body)
 unsupported=out/'unsupported.f90';unsupported.write_text((prefix+body).replace('hp%continuous_saturation_conductivity=.false.','hp%continuous_saturation_conductivity=.true.',1))
 sources=run([sys.executable,'-B',ROOT/'tests/support/augment_bartholomeus_backend_sources.py','--all',
  'tests/fsi/fsi04_real_headcalc_stubs.f90','src/adapter/mod_reference_richards_legacy_binding.f90',
  'src/adapter/mod_b110_dynamic_top_boundary_solver_adapter.f90',HEAD],'closure',ROOT).stdout.decode().splitlines()
 grid=(ROOT/sources[0]).read_text()
 for before,after in {'[-0.25d0, -0.75d0, -1.50d0, -2.50d0]':'[-2.5d0, -7.5d0, -15.0d0, -25.0d0]',
  '[0.50d0, 0.50d0, 1.00d0, 1.00d0]':'[5.0d0, 5.0d0, 10.0d0, 10.0d0]',
  'disnod(numnod+1) = 1.0d0':'disnod(numnod+1) = [2.5d0, 5.0d0, 7.5d0, 10.0d0, 5.0d0]'}.items():
  assert grid.count(before)==1;grid=grid.replace(before,after)
 (out/'grid.f90').write_text(grid)
 old=subprocess.check_output(['git','show',BASE+':'+HEAD],cwd=ROOT);(out/'old_headcalc.f90').write_bytes(old)
 outputs={}
 for opt in ['O0','O2']:
  b=out/opt;b.mkdir();flags=['-std=f2008','-ffree-line-length-none','-w','-fopenmp','-fcheck=all','-fbacktrace','-ffpe-trap=invalid,zero,overflow','-'+opt,'-J'+str(b),'-I'+str(b)]
  objects=[]
  for i,p in enumerate(sources):
   if p==HEAD:continue
   obj=b/f'{i:04d}.o';run([fc,*flags,'-c',out/'grid.f90'if i==0 else ROOT/p,'-o',obj],opt+'-compile');objects.append(obj)
  for arm,source in [('old',out/'old_headcalc.f90'),('current',ROOT/HEAD)]:
   exe=b/arm;run([fc,*flags,source,driver,*objects,'-o',exe],opt+'-'+arm+'-link')
   outputs[opt+'-'+arm]=run([exe],opt+'-'+arm+'-native').stdout.decode()
   assert [int(line.split()[2])for line in outputs[opt+'-'+arm].splitlines()]==([2,2,1]if arm=='old'else[1,2,1]),'discriminating success/retry matrix'
   exe=b/(arm+'-unsupported');run([fc,*flags,source,unsupported,*objects,'-o',exe],opt+'-'+arm+'-unsupported-link')
   outputs[opt+'-'+arm+'-unsupported']=run([exe],opt+'-'+arm+'-unsupported-native').stdout.decode()
  assert outputs[opt+'-old-unsupported']==outputs[opt+'-current-unsupported'],'unsupported route changed'
  assert outputs[opt+'-old'].splitlines()[2]==outputs[opt+'-current'].splitlines()[2],'successful ordinary solve changed'
 assert outputs['O0-current']==outputs['O2-current']and outputs['O0-old']==outputs['O2-old'],'optimization drift'
 # Preserve the exact existing native replay without modifying its assertions.
 runner=(ROOT/RUNNER).read_text();at=runner.index('\nFKT15_DONOR=48336',runner.index("echo 'FCI93_SUCCESSOR_LINEAGE=PASS'"))
 native=runner[at:]
 preamble='#!/bin/bash\nset -euo pipefail\ncd '+str(ROOT)+'\nfail(){ echo "$*" >&2; exit 93; }\nBASE=d8414c1ba11bee9f061622fd2495f631a57d2383\nOWNER_SOURCE=5898e6616dbb6871a9f52d489038235ba1172cae\n'
 native=native.replace('trap \'rm -rf "$BUILD"\' EXIT','',1)
 # The only extraction modification retains temporary native providers/raw logs.
 (out/'fsi35-native.sh').write_text(preamble+native)
 fsi=run(['/bin/bash',out/'fsi35-native.sh'],'fsi35-native',ROOT)
 assert b'FCI93_FIXED_K_NATIVE_IMMUTABLE_ORACLE_O0_O2=PASS'in fsi.stdout
 result=dict(status='SATURATED_FLUX_CURRENT_PREDECESSOR_AND_FSI35_NATIVE_COMPLETE',baseline=BASE,
  outputs=outputs,events=events,input_sha256={p:sha((ROOT/p).read_bytes())for p in set(sources)|{RUNNER,str(Path(__file__).relative_to(ROOT)),'tests/fsi/test_weather_surface_warm_start.f90'}},
  driver_sha256=sha(driver.read_bytes()),original_headcalc_sha256=sha(old),
  fsi35_scope='Original native semantic replay only; separate source-owner admission pending')
 (out/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(outputs,indent=2));print(result['status'])
if __name__=='__main__':main()
