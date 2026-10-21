"""Generated-only one-ULP counterfactual for the exact dry32 diagnostic input.

This does not admit a solver algorithm. Every original convergence, mass,
transaction and surface-publication check stays in the executed path.
"""
import argparse
import hashlib
import json
from pathlib import Path
import runpy
import resource
import subprocess
import time

ROOT = Path(__file__).resolve().parents[2]
HELPER = runpy.run_path(str(ROOT/'integration/diagnostics/capture_perf01_precision.py'))
once, sha = HELPER['once'], HELPER['sha']

MODULE = '''module mod_perf01_rounding_trial
 use iso_fortran_env, only: int64
 implicit none
 integer(int64) :: attempted=0,local_pass=0,local_fail=0
contains
 subroutine dump_rounding(window)
  integer,intent(in)::window
  integer::u
  open(newunit=u,file='rounding.csv',status='replace')
  write(u,'(A)')'window,attempted,local_pass,local_fail'
  write(u,'(I0,3(",",I0))')window,attempted,local_pass,local_fail
  close(u)
 end subroutine
 subroutine record_progress(t0,cursor,dt,terr,count,solver,temporal)
  real(8),intent(in)::t0,cursor,dt,terr
  integer,intent(in)::count,solver,temporal
  integer::u
  if(count/=1.and.mod(count,256)/=0)return
  if(count==1)then
   open(newunit=u,file='progress.csv',status='replace')
   write(u,'(A)')'t0,cursor,dt,temporal_error,accepted,solver_rejections,temporal_rejections'
  else
   open(newunit=u,file='progress.csv',position='append',status='old')
  endif
  write(u,'(ES25.17E3,3(",",ES25.17E3),3(",",I0))')t0,cursor,dt,terr,count,solver,temporal
  close(u)
 end subroutine
end module
'''

BLOCK = '''
         ! Generated diagnostic only: one adjacent representable interior head.
         ! Each original check still executes after the full residual refresh.
         if(canonical_trial.and.provider_constitutive_active.and.NN==32.and.swkimpl==0.and.swbotb==2.and.swmacro==0)then
          if(all(state%h(1:NN)==fsi_ws%old_head(1:NN)).and.all(state%h(1:NN)<-0.01d0).and. &
             maxval(abs(fsi_ws%residual(1:NN)))<=CritDevBalCp.and.abs(sum1)>CritDevBalTot)then
           rounding_node=0
           rounding_best=abs(sum1)
           do rounding_i=2,NN-1
            rounding_head=nearest(state%h(rounding_i),sign(1d0,-sum1))
            rounding_shift=(rounding_head-state%h(rounding_i))*state%dimoca(rounding_i)* &
              matrix_fraction(rounding_i)*grid_dz(rounding_i)/dt
            if(abs(sum1+rounding_shift)<rounding_best)then
             rounding_node=rounding_i
             rounding_best=abs(sum1+rounding_shift)
            endif
           enddo
           if(rounding_node>0)then
            attempted=attempted+1
            state%h(rounding_node)=nearest(state%h(rounding_node),sign(1d0,-sum1))
            provider_tuple_valid=.false.
            provider_tuple_from_candidate=.true.
            ctx%diagnostics%constitutive_evaluations=ctx%diagnostics%constitutive_evaluations+1
            ctx%diagnostics%constitutive_candidate_demand_evaluations=ctx%diagnostics%constitutive_candidate_demand_evaluations+1
            call evaluation_context%constitutive%evaluate_demand(state%h(1:NN),CONSTITUTIVE_DEMAND_WATER_CONTENT, &
              fsi_ws%provider_theta,fsi_ws%provider_k,fsi_ws%provider_capacity,fsi_ws%provider_dkdh)
            state%theta(1:NN)=fsi_ws%provider_theta(1:NN)
            do rounding_i=2,NN
             fsi_ws%head_gradient(rounding_i)=(state%h(rounding_i-1)-state%h(rounding_i))/grid_disnod(rounding_i)+1d0
            enddo
            call vector_F(2)
            sump=0.5d0*dot_product(fsi_ws%residual(1:NN),fsi_ws%residual(1:NN))
            sum1=sum(fsi_ws%residual(1:NN))
            if(maxval(abs(fsi_ws%residual(1:NN)))<=CritDevBalCp.and.abs(sum1)<=CritDevBalTot)then
             local_pass=local_pass+1
            else
             local_fail=local_fail+1
            endif
           endif
          endif
         endif
'''


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    for arg in ['build', 'input', 'output']:
        ap.add_argument('--'+arg, type=Path, required=True)
    ap.add_argument('--full-day', action='store_true')
    ap.add_argument('--windows', type=int, nargs='+')
    ap.add_argument('--timeout', type=float, default=30)
    ap.add_argument('--address-space-mib', type=int, default=512)
    ap.add_argument('--restart', type=Path)
    ap.add_argument('--progress', action='store_true')
    args = ap.parse_args()
    base, out = args.build.resolve(), args.output.resolve()
    out.mkdir(parents=True, exist_ok=False)
    build = json.loads((base/'build-complete.json').read_text())
    assert all(sha(ROOT/p) == h for p, h in build['input_sha256'].items())
    # Closed input domain: the original failed namelist, not arbitrary32-node physics.
    prior = runpy.run_path(str(ROOT/'integration/diagnostics/verify_perf01_dry.py'))['capsule']()
    assert args.input.read_bytes() == prior['oracle/input.nml'], 'counterfactual input scope'
    observed = runpy.run_path(str(ROOT/'tools/performance/study_perf01_temporal.py'))['build_main'](
        base, build, out/'observer', False, False)
    observer = out/'observer'
    module = observer/'rounding.f90';module.write_text(MODULE)
    head = observer/'headcalc.f90'
    text = (ROOT/'src/legacy/b1_10_port/headcalc.f90').read_text()
    text = once(text,'   implicit none\n\n   type(a23bu_worker_context_t)',
        '   use mod_perf01_rounding_trial, only: attempted,local_pass,local_fail\n   implicit none\n'
        '   integer :: rounding_node,rounding_i\n   real(8) :: rounding_head,rounding_best,rounding_shift\n\n'
        '   type(a23bu_worker_context_t)')
    needle='         sum1 = sum(fsi_ws%residual(1:NN))'
    text = once(text,needle,needle+BLOCK)
    head.write_text(text)
    source = observer/'main.f90'
    text = once(source.read_text(),'  implicit none','  use mod_perf01_rounding_trial, only: dump_rounding\n  implicit none')
    text = once(text,'    call cpu_time(perf_end)','    call cpu_time(perf_end)\n    call dump_rounding(j)')
    text = once(text,'    clock=t1','    flush(u)\n    clock=t1')
    source.write_text(text)
    fc=build['compiler_command']
    flags=[f for f in build['flags'] if not f.startswith(('-I','-J'))]+['-J'+str(observer),'-I'+str(observer),'-I'+str(base)]
    commands=[fc+flags+['-c',str(p),'-o',str(p.with_suffix('.o'))] for p in [module,head,source]]
    runtime=None
    if args.progress:
        runtime=observer/'mod_canonical_interval_runtime.f90'
        text=(ROOT/'src/runtime/mod_canonical_interval_runtime.f90').read_text()
        text=once(text,'  implicit none','  use mod_perf01_rounding_trial, only: record_progress\n  implicit none')
        needle='      result%diagnostics%committed_substeps = result%diagnostics%committed_substeps + 1'
        text=once(text,needle,needle+'''\n      call record_progress(interval%t0,cursor,tx%accepted_dt,tx%temporal_error, &
        result%diagnostics%committed_substeps,result%diagnostics%solver_rejections, &
        result%diagnostics%temporal_rejections)''')
        runtime.write_text(text)
        commands.append(fc+flags+['-c',str(runtime),'-o',str(runtime.with_suffix('.o'))])
    objects=[]
    for e in build['events']:
        if e['category']!='compile':continue
        cmd=e['command'];p=cmd[cmd.index('-c')+1];obj=cmd[cmd.index('-o')+1]
        if p.endswith('/app/solute_column/main.f90'):continue
        assert sha(Path(obj))==observed['object_sha256'][obj]
        replacement=str(head.with_suffix('.o')) if p.endswith('/headcalc.f90') else obj
        if runtime and p.endswith('/src/runtime/mod_canonical_interval_runtime.f90'):replacement=str(runtime.with_suffix('.o'))
        objects.append(replacement)
    exe=observer/'trial_column'
    commands.append(fc+flags+objects+[str(module.with_suffix('.o')),str(source.with_suffix('.o')),'-o',str(exe)])
    with (out/'build.log').open('w') as log:
        for command in commands:subprocess.run(command,stdout=log,stderr=log,check=True)
    report=dict(status='EXPERIMENT_NOT_PRODUCTION_QUALIFIED',build=build,observing_build=observed,commands=commands,
        generated_sha256={p.name:sha(p) for p in observer.glob('*.f90')},executable_sha256=sha(exe),
        linked_objects_sha256={p:sha(Path(p)) for p in objects},runs=[])
    (out/'TRIAL.json').write_text(json.dumps(report,indent=2)+'\n')
    for windows in (args.windows or ([6,64] if args.full_day else [6])):
        run=out/str(windows);run.mkdir()
        inp=run/'input.nml';inp.write_bytes(args.input.read_bytes())
        command=[str(exe),str(inp),str(args.restart.resolve()) if args.restart else '-',str(windows)]
        def bounded():
            limit=args.address_space_mib*1024*1024
            resource.setrlimit(resource.RLIMIT_AS,(limit,limit))
        start=time.monotonic()
        with (run/'stdout').open('w') as so,(run/'stderr').open('w') as se:
            try:result=subprocess.run(command,cwd=run,stdout=so,stderr=se,timeout=args.timeout,preexec_fn=bounded);code=result.returncode
            except subprocess.TimeoutExpired:code='TIMEOUT'
        record=dict(windows=windows,command=command,cwd=str(run),returncode=code,seconds=time.monotonic()-start,
            timeout_seconds=args.timeout,address_space_mib=args.address_space_mib,
            raw_sha256={p.name:sha(p) for p in run.iterdir() if p.is_file()})
        report['runs'].append(record)
        (out/'TRIAL.json').write_text(json.dumps(report,indent=2)+'\n')
        print(json.dumps(record),flush=True)
        if code!=0:break


if __name__=='__main__':main()
