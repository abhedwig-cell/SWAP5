#!/usr/bin/env python3
"""Fresh diagnostic accuracy/work/restart study; no production-policy admission.

Rebuilt after loss of the original unpushed workspace. Full source/executable
hashes are checked before linking generated mains against real production
objects. --snap-proposal-endpoint changes only a generated diagnostic runtime.
"""
import argparse
import csv
import hashlib
import json
import os
from pathlib import Path
import re
import statistics
import subprocess
import time

ROOT = Path(__file__).resolve().parents[2]
FILES = ['budget.csv', 'state.csv', 'endpoint.csv', 'restart.bin']
FIELDS = ['attempts', 'accepted_substeps', 'temporal_rejections', 'solver_rejections',
          'mass_rejections', 'headcalc_calls', 'nonlinear_iterations']


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def rows(path):
    with path.open() as f:
        return list(csv.DictReader(f))


def replace_once(text, old, new):
    if text.count(old) != 1:
        raise ValueError('diagnostic source preimage: ' + old)
    return text.replace(old, new, 1)


def cases():
    result = {}
    for n in [4, 32, 256]:
        text = (ROOT / 'examples/solute_column' /
                ('positive_pond.nml' if n == 4 else 'deep_grid.nml')).read_text()
        if n == 256:
            text = text.replace('nodes=32', 'nodes=256').replace(
                'cell_thickness_cm=0.5,0.5,1,1,2,3,26*5', 'cell_thickness_cm=256*1')
            text = text.replace('32*0.2', '256*0.2').replace('32*0.0000125', '256*0.0000015625')
        text = text.replace('windows=2', 'windows=8').replace(
            'ends_day=0.001,0.002', 'ends_day=' + ','.join(str(.001*(i+1)) for i in range(8)))
        for field, value in [('rain_cm_day', '.25'), ('irrigation_cm_day', '.25'),
                             ('runon_cm_day', '.5'), ('evaporation_cm_day', '.05')]:
            text = re.sub(r'(?m)^ ' + field + r'=.*$', ' '+field+'=8*'+value, text)
        result['pond'+str(n)] = text
    result['dry32'] = result['pond32'].replace('initial_head=-10', 'initial_head=-1000').replace(
        'initial_pond_cm=0.5', 'initial_pond_cm=0').replace('initial_pond_mass_mg_cm2=0.25',
        'initial_pond_mass_mg_cm2=0').replace('bottom_up_cm_day=-0.1', 'bottom_up_cm_day=0')
    result['pulse4'] = result['pond4'].replace('rain_cm_day=8*.25', 'rain_cm_day=0,0,5,0,0,2,0,0').replace(
        'irrigation_cm_day=8*.25', 'irrigation_cm_day=8*0').replace('runon_cm_day=8*.5', 'runon_cm_day=8*0')
    return result


def build_main(base, build, out, proposal, snap_endpoint):
    out.mkdir()
    text = (ROOT/'app/solute_column/main.f90').read_text()
    text = replace_once(text, '  implicit none', '  implicit none\n  integer :: perf_u,perf_v,perf_n\n'
                        '  real(real64) :: perf_start,perf_end')
    if proposal:
        needle = '  numerical%transaction%temporal_tolerance=temporal_tolerance'
        text = replace_once(text, needle, needle+'\n  numerical%retain_accepted_step_proposal=.true.')
    text = replace_once(text, '  do j=first,stop_after',
                        "  open(newunit=perf_u,file='work.csv',status='new')\n"
                        "  open(newunit=perf_v,file='trajectory.csv',status='new')\n"
                        "  write(perf_u,'(A)') 'window,cpu,"+','.join(FIELDS)+"'\n"
                        "  write(perf_v,'(A)') 'window,node,head,theta,concentration'\n  do j=first,stop_after")
    call = '    call run_pond_joint_interval(backend,column_id,template,p,water,forcing,numerical,solute,supply,t0,t1,result)'
    text = replace_once(text, call, '    call cpu_time(perf_start)\n'+call+'\n    call cpu_time(perf_end)\n'
                        "    write(perf_u,'(I0,\",\",ES25.17E3,7(\",\",I0))') j,perf_end-perf_start, &\n      "
                        + ', &\n      '.join('result%diagnostics%'+f for f in FIELDS))
    text = replace_once(text, "    call require(result%status==JOINT_OK,'joint interval rejected')", '''    if(result%status/=JOINT_OK)then
      observation=backend%observation()
      call water%current_time(clock,ok)
      write(*,*) 'FAILED_REQUEST',t0,t1,'COMMITTED_WATER_CLOCK',clock,ok
      call solute%snapshot(clock,theta,mobile,companion,revision)
      write(*,*) 'COMMITTED_CHEMICAL_CLOCK',clock,'CHEMICAL_STEPS',result%chemical%completed_substeps
      if(allocated(observation%accepted_water_flux_substeps))then
        k=size(observation%accepted_water_flux_substeps)
        if(k>0)write(*,*) 'TRACE_RANGE',observation%accepted_water_flux_substeps(1)%t0, &
          observation%accepted_water_flux_substeps(k)%t1,'ENDPOINT_GAP', &
          t1-observation%accepted_water_flux_substeps(k)%t1
      end if
    end if
    call require(result%status==JOINT_OK,'joint interval rejected')''')
    text = replace_once(text, '    clock=t1', '''    call water%snapshot(physical,ok)
    call require(ok,'diagnostic water snapshot failed')
    call solute%snapshot(clock,theta,mobile,companion,revision)
    select type(q=>physical)
    type is(fmr_b110_physical_state_t)
      do perf_n=1,numnod
        write(perf_v,'(I0,",",I0,3(",",ES25.17E3))') j,perf_n,q%pressure_head(perf_n), &
          theta(perf_n),mobile%concentration_mg_cm3(perf_n)
      end do
    class default
      error stop 'diagnostic state type'
    end select
    clock=t1''')
    source = out/'main.f90'
    source.write_text(text)
    fc = build['compiler_command']
    flags = [f for f in build['flags'] if not f.startswith(('-I', '-J'))]
    flags += ['-J'+str(out), '-I'+str(out), '-I'+str(base)]
    objects, commands = [], []
    shadow_runtime = None
    for event in build['events']:
        if event['category'] != 'compile':
            continue
        cmd = event['command']
        provider = cmd[cmd.index('-c')+1]
        if provider.endswith('/src/runtime/mod_canonical_interval_runtime.f90') and snap_endpoint:
            shadow_runtime = out/'mod_canonical_interval_runtime.f90'
            original = (ROOT/'src/runtime/mod_canonical_interval_runtime.f90').read_text()
            needle = '      tol = progress_tolerance(config%progress_tolerance, cursor, interval%t1)'
            shadow_runtime.write_text(replace_once(original, needle, needle+'''
      ! Diagnostic only: solve the exact endpoint before declaring completion.
      if (config%retain_accepted_step_proposal .and. proposal_active) then
        if (transaction_t1 < interval%t1 .and. interval%t1-transaction_t1 <= tol) transaction_t1 = interval%t1
      end if'''))
            objects.append(str(out/'runtime.o'))
        elif not provider.endswith('/app/solute_column/main.f90'):
            objects.append(cmd[cmd.index('-o')+1])
    if shadow_runtime:
        commands.append(fc+flags+['-c', str(shadow_runtime), '-o', str(out/'runtime.o')])
    commands += [fc+flags+['-c', str(source), '-o', str(out/'main.o')],
                 fc+flags+objects+[str(out/'main.o'), '-o', str(out/'column')]]
    with (out/'build.log').open('w') as log:
        for command in commands:
            subprocess.run(command, stdout=log, stderr=log, check=True)
    return dict(main_sha256=sha(source), runtime_sha256=sha(shadow_runtime) if shadow_runtime else None,
                executable_sha256=sha(out/'column'), object_sha256={p: sha(Path(p)) for p in objects}, commands=commands)


def errors(run, reference):
    a, b = rows(run/'trajectory.csv'), rows(reference/'trajectory.csv')
    if [(r['window'], r['node']) for r in a] != [(r['window'], r['node']) for r in b]:
        raise ValueError('trajectory alignment')
    result = {k: max(abs(float(x[k])-float(y[k])) for x, y in zip(a, b))
              for k in ['head', 'theta', 'concentration']}
    a, b = rows(run/'budget.csv'), rows(reference/'budget.csv')
    for key in ['water_in_cm', 'water_out_cm', 'solute_in_mg_cm2', 'solute_out_mg_cm2',
                'infiltration_cm', 'runon_cm', 'runoff_cm', 'pond_evaporation_cm']:
        result['cumulative_'+key] = abs(sum(float(r[key]) for r in a)-sum(float(r[key]) for r in b))
    a, b = rows(run/'endpoint.csv')[0], rows(reference/'endpoint.csv')[0]
    result.update({'endpoint_'+k: abs(float(a[k])-float(b[k])) for k in a})
    return result


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--build', type=Path, required=True)
    ap.add_argument('--output', type=Path, required=True)
    ap.add_argument('--repeat', type=int, default=3)
    ap.add_argument('--timeout', type=float, default=120)
    ap.add_argument('--tolerances', type=float, nargs='+', default=[1e-6, 2.5e-7, 6.25e-8, 1e-9])
    ap.add_argument('--cases', nargs='+', choices=list(cases()), default=list(cases()))
    ap.add_argument('--snap-proposal-endpoint', action='store_true')
    args = ap.parse_args()
    if args.repeat < 1 or len(args.tolerances) < 2 or args.tolerances[0] != 1e-6 or not all(
            a > b > 0 for a, b in zip(args.tolerances, args.tolerances[1:])):
        ap.error('positive repeats and decreasing tolerances starting at 1e-6 required')
    base, out = args.build.resolve(), args.output.resolve()
    out.mkdir(parents=True, exist_ok=False)
    (out/'driver.py').write_bytes(Path(__file__).read_bytes())
    build = json.loads((base/'build-complete.json').read_text())
    for f, h in build['input_sha256'].items():
        if sha(ROOT/f) != h:
            raise ValueError('production provider drift: '+f)
    if sha(base/'swap5_solute_column') != build['executable_sha256']:
        raise ValueError('original executable drift')
    report = dict(baseline=subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
                  fresh_reexecution=True, lost_prior_evidence_not_reconstructed=True,
                  scope='DIAGNOSTIC_ONLY_NO_PRODUCTION_ADMISSION', tolerances=args.tolerances,
                  driver_sha256=sha(out/'driver.py'), snap_proposal_endpoint=args.snap_proposal_endpoint,
                  build=build, generated={}, runs=[], summary=[])

    def save():
        (out/'CONTROL.json').write_text(json.dumps(report, indent=2)+'\n')

    for policy in ['off', 'on']:
        report['generated'][policy] = build_main(base, build, out/policy, policy == 'on', args.snap_proposal_endpoint)
    save()

    def execute(exe, source, directory, stop=8, restart=None):
        directory.mkdir()
        command = [str(exe), str(source), str(restart) if restart else '-', str(stop)]
        record = dict(directory=str(directory.relative_to(out)), command=command)
        start = time.monotonic()
        with (directory/'stdout').open('wb') as so, (directory/'stderr').open('wb') as se:
            try:
                process = subprocess.run(command, cwd=directory, stdout=so, stderr=se, timeout=args.timeout,
                                         preexec_fn=lambda: os.sched_setaffinity(0, {max(os.sched_getaffinity(0))}))
                record['exit'] = process.returncode
            except subprocess.TimeoutExpired:
                record['exit'] = 'TIMEOUT'
        record['wall'] = time.monotonic()-start
        report['runs'].append(record)
        if record['exit'] != 0:
            report['status'] = 'NATIVE_FAILED_OR_CENSORED_NOT_QUALIFIED'
            report['failure'] = record['directory']
            save()
            raise RuntimeError('failed/censored native run: '+str(directory))
        record['files'] = {f: sha(directory/f) for f in FILES}
        if (directory/'work.csv').exists():
            work = rows(directory/'work.csv')
            record['core_cpu'] = sum(float(r['cpu']) for r in work)
            record['work'] = {f: sum(int(r[f]) for r in work) for f in FIELDS}
        budget = rows(directory/'budget.csv')
        record['max_water_residual'] = max(abs(float(r['water_residual_cm'])) for r in budget)
        record['max_solute_residual'] = max(abs(float(r['solute_residual_mg_cm2'])) for r in budget)
        save()
        return record

    for name in args.cases:
        text, case = cases()[name], out/name
        case.mkdir()
        for tol in args.tolerances:
            source = case/(str(tol)+'.nml')
            source.write_text(text.replace('&column\n', '&column\n temporal_tolerance='+str(tol)+'\n'))
            for repeat in range(args.repeat if tol == args.tolerances[0] else 1):
                for policy in (['off', 'on'] if repeat % 2 == 0 else ['on', 'off']):
                    execute(out/policy/'column', source, case/f'{tol}-{policy}-{repeat}')
        original = execute(base/'swap5_solute_column', case/'1e-06.nml', case/'original')
        off = next(r for r in report['runs'] if r['directory'] == f'{name}/1e-06-off-0')
        if original['files'] != off['files']:
            raise ValueError('default observer changes physical output')
        for policy in ['off', 'on']:
            execute(out/policy/'column', case/'1e-06.nml', case/(policy+'-prefix'), stop=4)
            execute(out/policy/'column', case/'1e-06.nml', case/(policy+'-restart'),
                    restart=case/(policy+'-prefix')/'restart.bin')
            continuous, resumed = case/('1e-06-'+policy+'-0'), case/(policy+'-restart')
            for f in ['state.csv', 'endpoint.csv', 'restart.bin']:
                if sha(continuous/f) != sha(resumed/f):
                    raise ValueError('restart mismatch: '+str(resumed/f))
            for f in ['budget.csv', 'trajectory.csv']:
                if [r for r in rows(continuous/f) if int(r['window']) > 4] != rows(resumed/f):
                    raise ValueError('restart trajectory mismatch: '+str(resumed/f))
        summary = dict(case=name, observer_exact=True, both_restarts_exact=True,
                       reference_tolerance=args.tolerances[-1], errors_to_on_reference={}, errors_to_off_reference={})
        for policy in ['off', 'on']:
            observations = [r for r in report['runs'] if re.fullmatch(name+r'/1e-06-'+policy+r'-\d+', r['directory'])]
            if any(r['files'] != observations[0]['files'] or r['work'] != observations[0]['work'] for r in observations):
                raise ValueError('nondeterministic replay')
            summary[policy] = dict(cpu_median=statistics.median(r['core_cpu'] for r in observations),
                                   cpu_min=min(r['core_cpu'] for r in observations),
                                   cpu_max=max(r['core_cpu'] for r in observations), work=observations[0]['work'])
            for tol in args.tolerances:
                for refpolicy in ['on', 'off']:
                    summary['errors_to_'+refpolicy+'_reference'][f'{tol}-{policy}'] = errors(
                        case/f'{tol}-{policy}-0', case/f'{args.tolerances[-1]}-{refpolicy}-0')
        summary['default_policy_difference'] = errors(case/'1e-06-on-0', case/'1e-06-off-0')
        summary['speedup'] = summary['off']['cpu_median']/summary['on']['cpu_median']
        report['summary'].append(summary)
        save()
        print(json.dumps(summary), flush=True)
    report['status'] = 'DIAGNOSTIC_COMPLETE_NO_PRODUCTION_ADMISSION'
    save()


if __name__ == '__main__':
    main()
