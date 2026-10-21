"""Capture a final failed iterate for independent residual replay, serial only."""
import argparse
import csv
import hashlib
import json
from pathlib import Path
import runpy
import subprocess

ROOT = Path(__file__).resolve().parents[2]
FIELDS = ['h', 'h_previous', 'theta', 'theta_previous', 'increment', 'dz', 'fraction',
          'sink', 'source', 'root', 'k_left', 'k_right', 'gradient_left', 'gradient_right',
          'distance_left', 'distance_right', 'old_head', 'newton', 'capacity', 'upper', 'main', 'lower', 'residual']


def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()


def once(text, old, new):
    if text.count(old) != 1:
        raise ValueError('source preimage '+old)
    return text.replace(old, new, 1)


MODULE = '''module mod_perf01_precision_capture
 use iso_fortran_env, only: real64
 implicit none
 integer :: active=0, configuration(3)=0
 logical :: top_head=.false.
 real(real64) :: nodes(23,256)=0, coefficients(42,256)=0, meta(9)=0
contains
 subroutine capture_failed(dt,h,previous,theta,previous_theta,increment,dz,fraction,sink,source,root, &
     k,gradient,distance,old_head,newton,capacity,upper,main,lower,residual,cofgen, &
     qtop,qbot,hsurf,cp,ct,factor,maxit,ftoph,swkimpl,swbotb)
  real(real64), intent(in) :: dt,h(:),previous(:),theta(:),previous_theta(:),increment(:),dz(:),fraction(:)
  real(real64), intent(in) :: sink(:),source(:),root(:),k(:),gradient(:),distance(:),old_head(:),newton(:),capacity(:)
  real(real64), intent(in) :: upper(:),main(:),lower(:),residual(:),cofgen(:,:),qtop,qbot,hsurf,cp,ct,factor
  integer, intent(in) :: maxit,swkimpl,swbotb
  logical, intent(in) :: ftoph
  integer :: i
  active=size(h)
  if(active>256.or.size(cofgen,1)/=42)error stop 'precision capture scope'
  do i=1,active
   nodes(:,i)=[h(i),previous(i),theta(i),previous_theta(i),increment(i),dz(i),fraction(i),sink(i),source(i),root(i), &
     k(i),k(i+1),gradient(i),gradient(i+1),distance(i),distance(i+1),old_head(i),newton(i),capacity(i), &
     upper(i),main(i),lower(i),residual(i)]
  enddo
  coefficients(:,1:active)=cofgen
  meta=[dt,qtop,qbot,hsurf,cp,ct,factor,real(maxit,real64),real(active,real64)]
  configuration=[maxit,swkimpl,swbotb]
  top_head=ftoph
 end subroutine
 subroutine dump_capture()
  integer :: u,i,j
  if(active==0)error stop 'no failed solve captured'
  open(newunit=u,file='iterate.csv',status='new')
  write(u,'(A)') 'node,''' + ','.join(FIELDS) + ''''
  do i=1,active
   write(u,'(I0,23(",",ES25.17E3))') i,nodes(:,i)
  enddo
  close(u)
  open(newunit=u,file='coefficients.csv',status='new')
  write(u,'(A)') 'node,index,value'
  do i=1,active
   do j=1,42
    write(u,'(I0,",",I0,",",ES25.17E3)') i,j,coefficients(j,i)
   enddo
  enddo
  close(u)
  open(newunit=u,file='solve.csv',status='new')
  write(u,'(A)') 'dt,qtop,qbot,hsurf,compartment_tolerance,total_tolerance,factor,maxit,nodes,top_head,swkimpl,swbotb'
  write(u,'(ES25.17E3,8(",",ES25.17E3),",",L1,2(",",I0))') meta,top_head,configuration(2:3)
  close(u)
 end subroutine
end module
'''

CALL = '''   select type (capture_provider=>evaluation_context%constitutive)
   type is(b110_default_mvg_provider_t)
      call capture_failed(dt,state%h(1:NN),state%hm1(1:NN),state%theta(1:NN),state%thetm1(1:NN), &
        fsi_ws%provider_water_content_increment(1:NN),[(grid_dz(i),i=1,NN)],[(matrix_fraction(i),i=1,NN)], &
        fsi_ws%sink(1:NN),fsi_ws%source(1:NN),[(root_sink_term(i),i=1,NN)],state%kmean(1:NN+1), &
        fsi_ws%head_gradient(1:NN+1),[(grid_disnod(i),i=1,NN+1)],fsi_ws%old_head(1:NN), &
        fsi_ws%delta_head(1:NN),state%dimoca(1:NN),fsi_ws%dfdh_upper(1:NN),fsi_ws%dfdh_main(1:NN), &
        fsi_ws%dfdh_lower(1:NN),fsi_ws%residual(1:NN),capture_provider%parameters%cofgen, &
        state%qtop,state%qbot,state%hsurf,CritDevBalCp,CritDevBalTot,factor,MaxIt1,state%ftoph,swkimpl,swbotb)
   class default
      error stop 'capture requires default MvG provider'
   end select
'''


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    for arg in ['build', 'input', 'oracle', 'output']:
        ap.add_argument('--'+arg, type=Path, required=True)
    args = ap.parse_args()
    base, out = args.build.resolve(), args.output.resolve()
    out.mkdir(parents=True, exist_ok=False)
    build = json.loads((base/'build-complete.json').read_text())
    assert all(sha(ROOT/p) == h for p, h in build['input_sha256'].items()), 'stale build input'
    link = next(e['command'] for e in build['events'] if e['category'] == 'link')
    assert sha(Path(link[link.index('-o')+1])) == build['executable_sha256']
    helper = runpy.run_path(str(ROOT/'tools/performance/study_perf01_temporal.py'))
    observer = out/'observer'
    observed = helper['build_main'](base, build, observer, False, False)
    module = observer/'capture.f90'
    module.write_text(MODULE)
    text = (ROOT/'src/legacy/b1_10_port/headcalc.f90').read_text()
    text = once(text, '   implicit none\n\n   type(a23bu_worker_context_t)',
        '   use mod_perf01_precision_capture, only: capture_failed\n'
        '   use mod_b110_default_mvg_provider, only: b110_default_mvg_provider_t\n'
        '   implicit none\n\n   type(a23bu_worker_context_t)')
    text = once(text, '!  Convergence could not been reached', CALL+'!  Convergence could not been reached')
    head = observer/'headcalc.f90'
    head.write_text(text)
    main_source = observer/'main.f90'
    text = once(main_source.read_text(), '  implicit none',
        '  use mod_perf01_precision_capture, only: dump_capture\n  implicit none')
    text = once(text, '    if(result%status/=JOINT_OK)then', '    if(result%status/=JOINT_OK)then\n      call dump_capture()')
    main_source.write_text(text)
    fc = build['compiler_command']
    flags = [f for f in build['flags'] if not f.startswith(('-I', '-J'))]
    flags += ['-J'+str(observer), '-I'+str(observer), '-I'+str(base)]
    commands = [fc+flags+['-c', str(p), '-o', str(p.with_suffix('.o'))] for p in [module, head, main_source]]
    objects = []
    for e in build['events']:
        if e['category'] != 'compile':
            continue
        cmd = e['command']
        path, obj = cmd[cmd.index('-c')+1], cmd[cmd.index('-o')+1]
        if path.endswith('/app/solute_column/main.f90'):
            continue
        assert sha(Path(obj)) == observed['object_sha256'][obj]
        objects.append(str(head.with_suffix('.o')) if path.endswith('/headcalc.f90') else obj)
    exe = observer/'precision_column'
    commands.append(fc+flags+objects+[str(module.with_suffix('.o')), str(main_source.with_suffix('.o')), '-o', str(exe)])
    with (out/'build.log').open('w') as log:
        for command in commands:
            subprocess.run(command, check=True, stdout=log, stderr=log)
    report = dict(status='BUILT', build=build, observing_build=observed, commands=commands,
        generated_sha256={p.name: sha(p) for p in observer.glob('*.f90')}, executable_sha256=sha(exe),
        linked_objects_sha256={p: sha(Path(p)) for p in objects})
    (out/'BUILD.json').write_text(json.dumps(report, indent=2)+'\n')
    run = out/'native'
    run.mkdir()
    inp = run/'input.nml'
    inp.write_bytes(args.input.read_bytes())
    command = [str(exe), str(inp), '-', '128']
    with (run/'stdout').open('w') as so, (run/'stderr').open('w') as se:
        result = subprocess.run(command, cwd=run, stdout=so, stderr=se, timeout=120)
    counters = lambda p: [{k: v for k, v in r.items() if k != 'cpu'} for r in csv.DictReader(p.open())]
    same = {p: (run/p).read_bytes() == (args.oracle/p).read_bytes() for p in ['budget.csv', 'trajectory.csv', 'stdout']}
    same['work'] = counters(run/'work.csv') == counters(args.oracle/'work.csv')
    result = dict(returncode=result.returncode, command=command, cwd=str(run), exact_original=same,
        raw_sha256={p.name: sha(p) for p in run.iterdir() if p.is_file()})
    (out/'RESULT.json').write_text(json.dumps(result, indent=2)+'\n')
    assert result['returncode'] == 1 and all(same.values()), 'capture changed native failure'
    print(json.dumps(result, indent=2))


if __name__ == '__main__':
    main()
