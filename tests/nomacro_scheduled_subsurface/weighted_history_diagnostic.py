"""Source-bound private weighted-history isolation; never admission evidence.

Reuse the validated historical bundle without changing BUILD or its binding.
The read-only instrumented executable has a separate identity and remains research.
"""
import argparse
import json
import shutil
import subprocess
import sys
import time
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ('source-root', 'short-profile', 'failed-profile', 'reference-work', 'output'):
        parser.add_argument('--'+name, type=Path, required=True)
    parser.add_argument('--phase', choices=('prefix', 'nodes'), required=True)
    parser.add_argument('--prefix', type=Path)
    parser.add_argument('--build-root', type=Path)
    parser.add_argument('--variant', choices=('original', 'zero-pond', 'exact-saturated-jacobian'), default='original')
    parser.add_argument('--end', type=int, default=164)
    parser.add_argument('--start', type=int, default=160)
    parser.add_argument('--original-build', type=Path)
    args = parser.parse_args()
    sys.path[:0] = [str(args.source_root/'tests/nomacro_scheduled_subsurface'),
                   str(args.source_root/'tests/nomacro_mixtures')]
    import implicit_conductivity_runtime as original
    m = original.m
    assert m.h.APP.resolve() == (args.source_root/'app/hybrid_water').resolve()
    build = args.original_build or args.short_profile/'build'
    build_sha = m.sha(build/'BUILD.json')
    project = m.e.load(args.short_profile/'input', original_output=True)
    meta, case = m.validate_bundle(build, args.reference_work, project)
    args.output.mkdir()
    trajectory = args.output/'trajectory'
    trajectory.mkdir()
    donor = m.h.executable(build, 'day_donor')
    if args.phase == 'prefix':
        start, end, cap, parent = 34, 160, 60, args.short_profile/'trajectory'
    else:
        assert args.prefix and args.build_root
        start, end, cap, parent = args.start, args.end, 45, args.prefix/'trajectory'
        args.build_root.mkdir()
        for path in build.iterdir():
            if path.suffix.lower() in ('.o', '.mod', '.smod', '.f90', '.dll', '.so'):
                shutil.copyfile(path, args.build_root/path.name)
        path = args.build_root/'headcalc.f90'
        source = path.read_text(encoding='cp1252')
        declaration = '   integer                          :: i, j, itry,  MaxIt1, NN, iBackTr, ierror, mass_polish_at'
        anchor = '!     reset soil state variables'
        assert source.count(anchor) == source.count(declaration) == 1
        source = source.replace(declaration, declaration+'\n   integer,save::observed_failures=0,observed_entries=0', 1)
        entry = '!  reset some variables at the start of a new day'
        assert source.count(entry) == 1
        source = source.replace(entry, '''
   if(t1900>=37458d0)then
      observed_entries=observed_entries+1
      if(mod(observed_entries,1000)==1)then
         write(*,'(a,2(1x,i0),6(1x,es25.17e3))') 'WEIGHTED_ENTRY', &
            observed_entries,numbit,t1900,dt,pond,minval(h(1:numnod)),maxval(h(1:numnod)),minval(k(1:numnod))
         flush(6)
      end if
   end if
'''+entry, 1)
        observation = '''
      if(t1900>=37458d0.and.observed_failures<24)then
         observed_failures=observed_failures+1
         write(*,'(a,3(1x,i0),4(1x,es25.17e3))') 'WEIGHTED_FAILED_TRIAL', &
            observed_failures,numbit,iBackTr,t1900,dt,pond,sum1
         do i=1,NN
            write(*,'(a,1x,i0,13(1x,es25.17e3))') 'WEIGHTED_FAILED_NODE', &
               i,F(i),h(i),hold(i),theta(i),thetm1(i),dimoca(i),difh(i),k(i),dkdh(i),qrot(i),hgrad(i),dFdhM(i),dz(i)
         end do
         flush(6)
      end if
'''
        source = source.replace(anchor, observation+anchor, 1)
        if args.variant == 'exact-saturated-jacobian':
            capacity = '         dimoca(i) = moiscap(i, h(i))'
            imported = '   use MOD_MvG,            only: watcon, hconduc, moiscap, dhconduc, cofgen'
            assert source.count(capacity) == source.count(imported) == 1
            source = source.replace(imported, imported+'\n   use MOD_MvG,only:sw_use_elas', 1)
            source = source.replace(capacity, capacity+'\n         if(sw_use_elas==0.and.h(i)>=0d0)dimoca(i)=0d0', 1)
        path.write_text(source, encoding='cp1252')
        if args.variant == 'zero-pond':
            top = args.build_root/'boundtop.f90'
            body = top.read_text(encoding='cp1252')
            old = '      if (h0 <= 1.0d-6) then'
            assert body.count(old) == 1
            top.write_text(body.replace(old, '      if (h0 <= 0.0d0) then', 1), encoding='cp1252')
            shutil.copyfile(top, args.output/top.name)
        provider = args.reference_work/'build/swap-obj'
        ttutil = args.reference_work/'build/ttutil-obj'
        original_objects = sorted(provider.glob('*.o'))
        known = {p.name for p in original_objects}
        objects = [args.build_root/p.name if (args.build_root/p.name).exists() else p for p in original_objects]
        objects += [p for p in sorted(args.build_root.glob('*.o')) if p.name not in known]
        donor = args.build_root/'diagnostic_donor.exe'
        commands = ([['gfortran', *meta['identity']['donor_flags'], '-I', str(args.build_root),
                     '-I', str(provider), '-I', str(ttutil), '-c', 'boundtop.f90']]
                    if args.variant == 'zero-pond' else []) + [
            ['gfortran', *meta['identity']['donor_flags'], '-I', str(args.build_root),
             '-I', str(provider), '-I', str(ttutil), '-c', 'headcalc.f90'],
            ['gfortran', '-o', str(donor), *map(str, objects), str(ttutil/'libttutil.a')]]
        logs = []
        for command in commands:
            result = subprocess.run(command, cwd=args.build_root, capture_output=True, text=True, timeout=60)
            logs.append(dict(command=command, returncode=result.returncode, stdout=result.stdout, stderr=result.stderr))
            (args.output/'COMPILATION.json').write_text(json.dumps(logs, indent=2))
            result.check_returncode()
        shutil.copyfile(path, args.output/path.name)
        shutil.copyfile(donor, args.output/donor.name)
    checkpoint = parent/f'accepted-column-1-day-{start}.zip'
    checkpoint_sha = m.sha(checkpoint)
    origin = args.output/'origin'
    receipt = m.h.verify_checkpoint(checkpoint, start, meta['binding'], origin)
    status = dict(status='RUNNING', qualification=False, phase=args.phase, variant=args.variant,
                  original_BUILD_sha256=build_sha, actual_donor_sha256=m.sha(donor),
                  original_checkpoint_sha256=checkpoint_sha, start=start, end=end, wall_cap_seconds=cap,
                  historical_source_capsule=str(args.source_root), original_binding_unchanged=True)
    def save():
        (args.output/'RESULT.json').write_text(json.dumps(status, indent=2)+'\n')
    save()
    clock = time.monotonic()
    try:
        result, _ = m.bounded(cap, lambda: m.h.run(donor, m.h.executable(build, 'day_kernel'),
            case, trajectory, end, checkpoint_day=start, origin=origin, origin_receipt=receipt,
            runtime=True, publish_day=end, checkpoint_binding=meta['binding'], model=project.model, project=project))
        assert result['first_refusal'] is None, result
        status['status'] = 'RESEARCH_CONTINUATION_COMPLETE'
    except Exception as error:
        status.update(status='RESEARCH_FAILED_OR_CENSORED', error=repr(error))
        if args.phase == 'prefix':
            raise
    finally:
        actual = m.rows(trajectory)
        prior = m.rows(args.failed_profile/'trajectory')
        m.check(actual)
        prior_by_day = {row['day']: row for row in prior}
        shared = [row for row in actual if row['day'] in prior_by_day]
        overlap = len(shared)
        exact = m.physical(shared) == m.physical([prior_by_day[row['day']] for row in shared])
        if args.variant != 'exact-saturated-jacobian':
            assert exact
        assert m.sha(build/'BUILD.json') == build_sha and m.sha(checkpoint) == checkpoint_sha
        status.update(actual_days=len(actual), compared_previously_accepted_days=overlap,
                      compared_physical_rows_exact=exact, exact_previously_accepted_days=overlap if exact else 0,
                      seconds=time.monotonic()-clock)
        save()
    if args.phase == 'prefix':
        assert len(actual) == end-start and (trajectory/f'accepted-column-1-day-{end}.zip').is_file()
    print(json.dumps(status))


if __name__ == '__main__':
    main()
