"""Bounded, serial, generated-source diagnosis; never edits production providers.

Reuse requires exact source, executable and object identities from a real column
build. The ring stores only failed nonlinear solves, before their state reset.
It is diagnostic process-local state and must never become a production module.
"""
import argparse
import csv
import hashlib
import json
from pathlib import Path
import runpy
import subprocess

ROOT = Path(__file__).resolve().parents[2]


def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()


def once(text, old, new):
    if text.count(old) != 1:
        raise ValueError('source preimage: '+old)
    return text.replace(old, new, 1)


MODULE = '''module mod_perf01_failure_ring
 use iso_fortran_env, only: real64, int64
 implicit none
 integer, parameter :: capacity=64
 integer(int64) :: calls=0, failures=0, sequence(capacity)=0
 real(real64) :: data(12,capacity)=0
 integer :: worst(capacity)=0
 logical :: pond_failure(capacity)=.false., at_min(capacity)=.false.
contains
 subroutine begin_solve()
  calls=calls+1
 end subroutine
 subroutine record_failure(dt,residual,theta,h,old_h,dz,pond,qtop,cp,ct,total,head_abs,head_rel,pf,minimum)
  real(real64), intent(in) :: dt,residual(:),theta(:),h(:),old_h(:),dz(:),pond,qtop,cp,ct,total,head_abs,head_rel
  logical, intent(in) :: pf,minimum
  integer :: slot,node,i
  real(real64) :: increment,scaled
  failures=failures+1
  slot=int(modulo(failures-1,int(capacity,int64)))+1
  node=maxloc(abs(residual),dim=1)
  scaled=0
  do i=1,size(h)
   increment=abs(h(i)-old_h(i))
   if(abs(old_h(i))<1)then
    scaled=max(scaled,increment/head_abs)
   else
    scaled=max(scaled,increment/abs(old_h(i))/head_rel)
   endif
  enddo
  data(:,slot)=[dt,maxval(abs(residual)),total,cp,ct,scaled,spacing(theta(node))*dz(node)/dt, &
    h(node),theta(node),pond,qtop,real(size(h),real64)]
  sequence(slot)=calls
  worst(slot)=node
  pond_failure(slot)=pf
  at_min(slot)=minimum
 end subroutine
 subroutine dump_failure(t0,t1,dt,retries,solver,temporal,mass)
  real(real64), intent(in) :: t0,t1,dt
  integer, intent(in) :: retries,solver,temporal,mass
  integer :: u,slot
  integer(int64) :: j
  open(newunit=u,file='solver_failure.csv',status='replace')
  write(u,'(A)') 'call,node,pond_failure,at_min,dt,max_residual,total_residual,compartment_tolerance,total_tolerance,head_increment_ratio,theta_storage_ulp_rate,head,theta,pond,qtop,nodes'
  do j=max(1_int64,failures-capacity+1),failures
   slot=int(modulo(j-1,int(capacity,int64)))+1
   write(u,'(I0,",",I0,2(",",L1),12(",",ES25.17E3))') sequence(slot),worst(slot),pond_failure(slot),at_min(slot),data(:,slot)
  enddo
  close(u)
  open(newunit=u,file='transaction_failure.csv',status='replace')
  write(u,'(A)') 'calls,failed_solves,retry_index,solver_rejections,temporal_rejections,mass_rejections,t0,t1,dt'
  write(u,'(2(I0,","),4(I0,","),ES25.17E3,2(",",ES25.17E3))') calls,failures,retries,solver,temporal,mass,t0,t1,dt
  close(u)
 end subroutine
end module
'''


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--build', required=True, type=Path)
    ap.add_argument('--input', required=True, type=Path)
    ap.add_argument('--oracle', required=True, type=Path)
    ap.add_argument('--output', required=True, type=Path)
    args = ap.parse_args()
    base, out = args.build.resolve(), args.output.resolve()
    out.mkdir(parents=True, exist_ok=False)
    build = json.loads((base/'build-complete.json').read_text())
    for path, digest in build['input_sha256'].items():
        if sha(ROOT/path) != digest:
            raise ValueError('stale build input '+path)
    link = next(e['command'] for e in build['events'] if e['category'] == 'link')
    if sha(Path(link[link.index('-o')+1])) != build['executable_sha256']:
        raise ValueError('stale base executable')
    helper = runpy.run_path(str(ROOT/'tools/performance/study_perf01_temporal.py'))
    observer = out/'observer'
    observed = helper['build_main'](base, build, observer, False, False)
    module = observer/'mod_perf01_failure_ring.f90'
    module.write_text(MODULE)
    head = 'src/legacy/b1_10_port/headcalc.f90'
    generated = {}
    text = (ROOT/head).read_text()
    text = once(text, '   implicit none\n\n   type(a23bu_worker_context_t)',
        '   use mod_perf01_failure_ring, only: begin_solve, record_failure\n   implicit none\n\n   type(a23bu_worker_context_t)')
    text = once(text, '   canonical_trial = present(worker)', '   call begin_solve()\n   canonical_trial = present(worker)')
    text = once(text, '!  Convergence could not been reached', '''   call record_failure(dt,fsi_ws%residual(1:NN),state%theta(1:NN),state%h(1:NN), &
      fsi_ws%old_head(1:NN),[(grid_dz(i),i=1,NN)],state%pond,state%qtop,CritDevBalCp,CritDevBalTot,sum1, &
      CritDevh2Cp,CritDevh1Cp,flnonconv3,fldtmin)
!  Convergence could not been reached''')
    generated[head] = text
    main_source = observer/'main.f90'
    text = main_source.read_text()
    text = once(text, '  implicit none', '  use mod_perf01_failure_ring, only: dump_failure\n  implicit none')
    text = once(text, '    if(result%status/=JOINT_OK)then', '''    if(result%status/=JOINT_OK)then
      call dump_failure(t0,t1,-1.0_real64,-1,result%diagnostics%solver_rejections, &
        result%diagnostics%temporal_rejections,result%diagnostics%mass_rejections)''')
    main_source.write_text(text)
    fc = build['compiler_command']
    flags = [f for f in build['flags'] if not f.startswith(('-I', '-J'))]
    flags += ['-J'+str(observer), '-I'+str(observer), '-I'+str(base)]
    commands = [fc+flags+['-c', str(module), '-o', str(observer/'ring.o')]]
    shadows = {}
    for path, text in generated.items():
        p = observer/Path(path).name
        p.write_text(text)
        obj = p.with_suffix('.o')
        shadows[path] = str(obj)
        commands.append(fc+flags+['-c', str(p), '-o', str(obj)])
    objects = []
    for event in build['events']:
        if event['category'] != 'compile':
            continue
        cmd = event['command']
        path = str(Path(cmd[cmd.index('-c')+1]).relative_to(ROOT))
        if path == 'app/solute_column/main.f90':
            continue
        obj = cmd[cmd.index('-o')+1]
        if sha(Path(obj)) != observed['object_sha256'][obj]:
            raise ValueError('object drift '+obj)
        objects.append(shadows.get(path, obj))
    exe = observer/'diagnostic_column'
    commands.append(fc+flags+['-c', str(main_source), '-o', str(observer/'main.o')])
    commands.append(fc+flags+objects+[str(observer/'ring.o'), str(observer/'main.o'), '-o', str(exe)])
    with (observer/'diagnostic-build.log').open('w') as log:
        for command in commands:
            subprocess.run(command, check=True, stdout=log, stderr=log)
    report = dict(status='BUILT_NOT_EXECUTED', source_commit=subprocess.check_output(
        ['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(), build=build, observer=observed,
        diagnostic_commands=commands, generated_sha256={p.name: sha(p) for p in observer.glob('*.f90')},
        linked_objects_sha256={p: sha(Path(p)) for p in objects}, executable_sha256=sha(exe))
    (out/'BUILD.json').write_text(json.dumps(report, indent=2)+'\n')
    observations = []
    for policy in ['off', 'on']:
        run = out/policy
        run.mkdir()
        text = args.input.read_text()
        if 'retain_accepted_step_proposal' in text:
            raise ValueError('unexpected input policy')
        text = once(text, '&column', '&column\n retain_accepted_step_proposal=.'+('true' if policy == 'on' else 'false')+'.')
        inp = run/'input.nml'
        inp.write_text(text)
        with (run/'stdout').open('w') as stdout, (run/'stderr').open('w') as stderr:
            command = [str(exe), str(inp), '-', '128']
            result = subprocess.run(command, cwd=run, stdout=stdout, stderr=stderr, timeout=120)
        counters = lambda p: [{k: v for k, v in r.items() if k != 'cpu'} for r in csv.DictReader(p.open())]
        same_budget = (run/'budget.csv').read_bytes() == (args.oracle/'budget.csv').read_bytes()
        same_work = counters(run/'work.csv') == counters(args.oracle/'work.csv')
        same_stdout = (run/'stdout').read_bytes() == (args.oracle/'stdout').read_bytes()
        observation = dict(policy=policy, command=command, cwd=str(run), returncode=result.returncode,
            partial_budget_exact=same_budget, deterministic_work_exact=same_work, failed_clocks_stdout_exact=same_stdout,
            input_sha256=sha(inp), raw_sha256={p.name: sha(p) for p in run.iterdir() if p.is_file()})
        observations.append(observation)
        (out/'RESULT.json').write_text(json.dumps(dict(status='INCOMPLETE', observations=observations), indent=2)+'\n')
        if result.returncode == 0 or not (same_budget and same_work and same_stdout):
            raise ValueError('failure reproduction differs '+policy)
    (out/'RESULT.json').write_text(json.dumps(dict(status='DIAGNOSTIC_FAILURE_REPRODUCED_NOT_PRODUCTION_QUALIFIED',
        observations=observations), indent=2)+'\n')
    print(json.dumps(observations, indent=2))


if __name__ == '__main__':
    main()
