"""Repeat the prior generated-only correction on current trace-scoped providers."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import resource
import runpy
import subprocess
import time

ROOT = Path(__file__).resolve().parents[2]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--build', type=Path, required=True)
    ap.add_argument('--input', type=Path, required=True)
    ap.add_argument('--output', type=Path, required=True)
    ap.add_argument('--windows', type=int, default=6)
    ap.add_argument('--restart', type=Path)
    ap.add_argument('--timeout', type=float, default=90)
    ap.add_argument('--address-space-mib', type=int, default=512)
    ap.add_argument('--control', action='store_true', help='Observe unchanged original HeadCalc, without the numerical block')
    ap.add_argument('--temporal-capture', action='store_true', help='Stop after64 late full/half temporal disagreements, preserving their native states')
    ap.add_argument('--surface-complementarity', action='store_true', help='Generated-only empty-pond evaporation constraint; original HeadCalc can remain unchanged with --control')
    ap.add_argument('--chemical-capture', action='store_true', help='Observe the actual carrier rejection without changing its guards')
    ap.add_argument('--solute-empty-limit', action='store_true', help='Generated-only exact zero-pond/no-runoff/no-macro solute limit, without clipping')
    ap.add_argument('--temporal-tolerance',type=float,help='Explicit tighter-only temporal refinement of the closed input')
    a = ap.parse_args()
    base, out = a.build.resolve(), a.output.resolve()
    out.mkdir(parents=True, exist_ok=False)
    build = json.loads((base / 'build-complete.json').read_text())
    assert all(sha(ROOT / p) == h for p, h in build['input_sha256'].items())
    assert all(sha(base / p) == h for p, h in build['generated_input_sha256'].items())
    prior = runpy.run_path(str(ROOT / 'integration/diagnostics/verify_perf01_dry.py'))['capsule']()
    assert a.input.read_bytes() == prior['oracle/input.nml']
    old = runpy.run_path(str(ROOT / 'integration/diagnostics/trial_perf01_rounding.py'))
    once = old['once']
    projected = runpy.run_path(str(ROOT / 'integration/diagnostics/qualify_trace_scope.py'))['observer_source']
    target = out / 'generated'
    target.mkdir()
    module = target / 'rounding.f90'
    text = old['MODULE']
    text = once(text, '  close(u)\n end subroutine\nend module',
                '  close(u)\n  call dump_rounding(0)\n end subroutine\nend module')
    if a.temporal_capture:
        text = once(text, ' integer(int64) :: attempted=0,local_pass=0,local_fail=0',
            ' integer(int64) :: attempted=0,local_pass=0,local_fail=0\n'
            ' real(8)::diag_t0=0d0,diag_dt=0d0\n integer::diag_samples=0')
        text = once(text, '\nend module', '''
 subroutine temporal_context(t0,dt)
  real(8),intent(in)::t0,dt
  diag_t0=t0;diag_dt=dt
 end subroutine
 subroutine temporal_sample(hf,hh,wf,wh,pf,ph,gf,gh,value)
  real(8),intent(in)::hf(:),hh(:),wf(:),wh(:),pf,ph,gf,gh,value
  integer::u,i
  if(diag_t0<0.0865d0.or.value<=1d-6)return
  diag_samples=diag_samples+1
  if(diag_samples==1)then
   open(newunit=u,file='temporal.csv',status='new')
   write(u,'(A)')'sample,t0,dt,error,node,full_h,half_h,full_theta,half_theta,full_pond,half_pond,full_gwl,half_gwl'
  else
   open(newunit=u,file='temporal.csv',position='append',status='old')
  endif
  do i=1,size(hf)
   write(u,'(I0,3(",",ES25.17E3),",",I0,8(",",ES25.17E3))') &
     diag_samples,diag_t0,diag_dt,value,i,hf(i),hh(i),wf(i),wh(i),pf,ph,gf,gh
  enddo
  close(u)
  if(diag_samples==64) error stop 'DIAGNOSTIC_TEMPORAL_CAPTURE_COMPLETE_NOT_MODEL_COMPLETION'
 end subroutine
end module
subroutine perf01_temporal_context(t0,dt)
 use mod_perf01_rounding_trial,only:temporal_context
 implicit none
 real(8),intent(in)::t0,dt
 call temporal_context(t0,dt)
end subroutine''')
    module.write_text(text)
    head = target / 'headcalc.f90'
    text = (ROOT / 'src/legacy/b1_10_port/headcalc.f90').read_text()
    text = once(text, '   implicit none\n\n   type(a23bu_worker_context_t)',
        '   use mod_perf01_rounding_trial, only: attempted,local_pass,local_fail\n   implicit none\n'
        '   integer :: rounding_node,rounding_i\n   real(8) :: rounding_head,rounding_best,rounding_shift\n\n'
        '   type(a23bu_worker_context_t)')
    needle = '         sum1 = sum(fsi_ws%residual(1:NN))'
    head.write_text(once(text, needle, needle + ('' if a.control else old['BLOCK'])))
    source = target / 'main.f90'
    text = projected((ROOT / 'app/solute_column/main.f90').read_text())
    text = once(text, '  implicit none', '  use mod_perf01_rounding_trial, only: dump_rounding\n  implicit none')
    text = once(text, '    call cpu_time(perf_end)', '    call cpu_time(perf_end)\n    call dump_rounding(j)')
    source.write_text(text)
    runtime = target / 'mod_canonical_interval_runtime.f90'
    text = (ROOT / 'src/runtime/mod_canonical_interval_runtime.f90').read_text()
    text = once(text, '  implicit none', '  use mod_perf01_rounding_trial, only: record_progress\n  implicit none')
    needle = '      result%diagnostics%committed_substeps = result%diagnostics%committed_substeps + 1'
    runtime.write_text(once(text, needle, needle + '''
      call record_progress(interval%t0,cursor,tx%accepted_dt,tx%temporal_error, &
        result%diagnostics%committed_substeps,result%diagnostics%solver_rejections, &
        result%diagnostics%temporal_rejections)'''))
    extra = []
    if a.temporal_capture:
        tx = target / 'mod_transaction_reference.f90'
        text = (ROOT / 'src/transaction/mod_transaction_reference.f90').read_text()
        text = once(text, '      terr = model%temporal_error(full_state, half_state)',
                    '      call perf01_temporal_context(t0,attempt_dt)\n      terr = model%temporal_error(full_state, half_state)')
        tx.write_text(text)
        indicator = target / 'mod_pond_water_temporal_difference.f90'
        text = (ROOT / 'src/process/mod_pond_water_temporal_difference.f90').read_text()
        text = once(text, '  implicit none', '  use mod_perf01_rounding_trial, only: temporal_sample\n  implicit none')
        text = once(text, '    available=.true.', '    available=.true.\n    call temporal_sample(hf,hh,wf,wh,pf,ph,gf,gh,value)')
        indicator.write_text(text)
        extra = [tx,indicator]
    if a.surface_complementarity:
        surface = target / 'mod_b110_dynamic_top_boundary_provider.f90'
        text = (ROOT / 'src/solver/mod_b110_dynamic_top_boundary_provider.f90').read_text()
        text = once(text, '    real(real64) :: top_dz, top_distance',
                    '    real(real64) :: top_dz, top_distance\n    real(real64)::diag_supply,diag_capacity,diag_evap')
        needle = '    q1 = -q0 - request%previous_ponding_depth_cm/request%step_duration_day'
        block = '''    ! GENERATED COUNTERFACTUAL ONLY: implicit endpoint wet/dry constraint.
    ! Closed experiment: no bare-soil demand, no macro donor/partition, explicit K.
    if(request%potential_bare_soil_evaporation_cm_per_day==0d0.and. &
       request%potential_pond_evaporation_cm_per_day>0d0.and. &
       .not.request%macropore_pond_donor_active.and..not.request%matrix_source_area_partition.and. &
       request%fixed_top_node_conductivity_cm_per_day>=0d0)then
      diag_supply=request%precipitation_rate_cm_per_day+request%irrigation_rate_cm_per_day+ &
        request%snowmelt_rate_cm_per_day+request%runon_rate_cm_per_day
      diag_capacity=k1_max*(1d0-request%pressure_head_top_cm/top_distance)
      if(diag_capacity>0d0)then
        diag_evap=min(request%potential_pond_evaporation_cm_per_day,max(0d0, &
          diag_supply+request%previous_ponding_depth_cm/request%step_duration_day-diag_capacity))
        result%bare_soil_evaporation_cm_per_day=0d0
        result%ponded_water_evaporation_cm_per_day=diag_evap
        q0=diag_supply-diag_evap
        if(diag_evap>0d0.and.diag_evap<request%potential_pond_evaporation_cm_per_day)then
          result%regime=B110_DYN_TOP_REGIME_HEAD
          result%surface_head_cm=0d0
          result%surface_face_conductivity_cm_per_day=k1_max
          result%surface_head_derivative_available=.true.
          result%surface_head_dpressure_head_top=0d0
          result%candidate_ponding_depth_cm=0d0
          result%runoff_depth_cm=0d0
          result%runoff_potential=.false.
          result%actual_top_flux_cm_per_day=-diag_capacity
          result%net_potential_surface_flux_cm_per_day=q0
          result%status=B110_DYN_TOP_AVAILABLE
          result%route='generated-empty-pond-constraint'
          return
        endif
      endif
    endif
'''
        surface.write_text(once(text,needle,block+needle))
        extra.append(surface)
    if a.chemical_capture:
        chemical = target / 'mod_fmr_b111_pond_solute_route.f90'
        text = (ROOT / 'src/runtime/mod_fmr_b111_pond_solute_route.f90').read_text()
        def marker(stage,code):
            return "\n    if(k>=5210.and.k<=5220)write(*,*)'CHEMICAL_CARRIER_CAPTURE',k," + str(stage) + ',' + code + ''', &
      t%t0,t%t1,t%pond_start_cm,t%pond_end_cm,t%top_flux,t%converged_pond_evaporation_cm_day
'''
        needle = '   associate(t=>steps(k))'
        text = once(text,needle,needle+marker(0,'0'))
        for needle,stage,code in [
            ('    receipt%max_water_residual=max(receipt%max_water_residual,abs(closure)*dt)',10,'code'),
            ('    call advance_persistent_pond(pond_trial,pond_step,pond_next,pond_receipt)',20,'pond_receipt%status'),
            ('    call advance_b111_reactive_solute_substep(mobile,amount,f,next_mobile,next_amount,r)',30,'r%status')]:
            text = once(text,needle,needle+marker(stage,code))
        needle = '    if(pond_receipt%status/=POND_OK)return'
        text = once(text,needle,"    if(k==5219)write(*,*)'ACTUAL_EMPTY_POND_MASS_BEFORE',pond_receipt%mass_before,pond_receipt%dry_input\n"+needle)
        chemical.write_text(text)
        extra.append(chemical)
    if a.solute_empty_limit:
        mixing = target / 'mod_b111_pond_solute_exchange.f90'
        text = (ROOT / 'src/process/mod_b111_pond_solute_exchange.f90').read_text()
        needle = '  if(result%mass_after<0d0.or..not.all(ieee_is_finite([ &'
        block = '''  ! GENERATED ONLY: analytical empty-pond limit, not a negative-mass clamp.
  if(qtop < -1d-6.and.macropore_area==0d0.and.pond_end==0d0.and.ro==0d0)then
    result%soil_transfer=available
    result%mass_after=0d0
  endif
'''
        mixing.write_text(once(text,needle,block+needle))
        extra.insert(0,mixing)
    fc = build['compiler_command']
    flags = [f for f in build['flags'] if not f.startswith(('-I', '-J'))] + ['-J' + str(target), '-I' + str(target), '-I' + str(base)]
    report = dict(status='BUILDING_EXPERIMENT',control=a.control,temporal_capture=a.temporal_capture,
        surface_complementarity=a.surface_complementarity,chemical_capture=a.chemical_capture,
        solute_empty_limit=a.solute_empty_limit,build=build,events=[],
        inputs={p:sha(ROOT / p) for p in ['integration/diagnostics/trial_perf01_rounding.py',
                'integration/diagnostics/trial_perf01_scoped_rounding.py', 'integration/diagnostics/qualify_trace_scope.py']},
        generated_sha256={p.name:sha(p) for p in [module,head,source,runtime]+extra})
    def save():
        (out / 'TRIAL.json').write_text(json.dumps(report,indent=2) + '\n')
    save()
    replacements = {'src/legacy/b1_10_port/headcalc.f90':head.with_suffix('.o'),
                    'src/runtime/mod_canonical_interval_runtime.f90':runtime.with_suffix('.o')}
    if a.temporal_capture:
        replacements.update({'src/transaction/mod_transaction_reference.f90':tx.with_suffix('.o'),
                             'src/process/mod_pond_water_temporal_difference.f90':indicator.with_suffix('.o')})
    if a.surface_complementarity:
        replacements['src/solver/mod_b110_dynamic_top_boundary_provider.f90']=surface.with_suffix('.o')
    if a.chemical_capture:
        replacements['src/runtime/mod_fmr_b111_pond_solute_route.f90']=chemical.with_suffix('.o')
    if a.solute_empty_limit:
        replacements['src/process/mod_b111_pond_solute_exchange.f90']=mixing.with_suffix('.o')
    objects = []
    for event in build['events']:
        if event['category'] != 'compile':
            continue
        command = event['command']
        path = Path(command[command.index('-c') + 1])
        if path == ROOT / 'app/solute_column/main.f90':
            continue
        relative = str(path.relative_to(ROOT)) if path.is_relative_to(ROOT) else ''
        objects.append(str(replacements.get(relative, command[command.index('-o') + 1])))
    archive = base / 'libttutil.a'
    original_objects = [p for p in objects if str(target) not in p]
    report['linked_incumbent_sha256'] = {p:sha(Path(p)) for p in original_objects + [str(archive)]}
    commands = [fc + flags + ['-c',str(p),'-o',str(p.with_suffix('.o'))] for p in [module]+extra+[head,source,runtime]]
    exe = target / 'trial_column'
    commands.append(fc + flags + objects + [str(module.with_suffix('.o')),str(source.with_suffix('.o')),str(archive),'-o',str(exe)])
    for i, command in enumerate(commands):
        start = time.monotonic()
        p = subprocess.run(command,cwd=target,capture_output=True)
        for stream in ['stdout','stderr']:
            (out / f'{i:04d}.{stream}').write_bytes(getattr(p,stream))
        report['events'].append(dict(command=command,returncode=p.returncode,seconds=time.monotonic()-start))
        save()
        p.check_returncode()
    assert all(sha(ROOT / p) == h for p,h in build['input_sha256'].items())
    assert all(sha(Path(p)) == h for p,h in report['linked_incumbent_sha256'].items())
    run = out / 'native'
    run.mkdir()
    input_text = a.input.read_text()
    if a.temporal_tolerance is not None:
        assert 0 < a.temporal_tolerance < 1e-6
        input_text = once(input_text,' temporal_tolerance=1e-06',
                          ' temporal_tolerance='+format(a.temporal_tolerance,'.17g'))
    (run / 'input.nml').write_text(input_text)
    command = [str(exe),str(run / 'input.nml'),str(a.restart.resolve()) if a.restart else '-',str(a.windows)]
    report.update(status='EXPERIMENT_RUNNING_NOT_PRODUCTION_QUALIFIED',executable_sha256=sha(exe),
                  native_command=command,timeout_seconds=a.timeout,address_space_mib=a.address_space_mib,
                  temporal_tolerance=a.temporal_tolerance or 1e-6,native_input_sha256=sha(run/'input.nml'))
    save()
    def limit():
        memory = a.address_space_mib * 1024 ** 2
        resource.setrlimit(resource.RLIMIT_AS,(memory,memory))
    start = time.monotonic()
    with (run / 'stdout').open('wb') as so, (run / 'stderr').open('wb') as se:
        p = subprocess.Popen(command,cwd=run,stdout=so,stderr=se,preexec_fn=limit)
        timed_out = False
        while True:
            pid,status,usage = os.wait4(p.pid,os.WNOHANG)
            if pid:
                break
            if time.monotonic() - start >= a.timeout:
                timed_out = True
                p.kill()
                pid,status,usage = os.wait4(p.pid,0)
                break
            time.sleep(.02)
        p.returncode = os.waitstatus_to_exitcode(status)
    result = dict(returncode=p.returncode,timed_out=timed_out,max_rss_kib=usage.ru_maxrss,seconds=time.monotonic()-start)
    (run / 'RESOURCE.json').write_text(json.dumps(result,indent=2) + '\n')
    report.update(status='EXPERIMENT_COMPLETE_NOT_PRODUCTION_QUALIFIED' if p.returncode == 0 else 'EXPERIMENT_FAILED_OR_CENSORED_NOT_QUALIFIED',
                  resource=result,raw_sha256={p.name:sha(p) for p in run.iterdir() if p.is_file()})
    save()
    print(json.dumps(report['resource']))


if __name__ == '__main__':
    main()
