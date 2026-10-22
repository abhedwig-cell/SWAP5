"""Additive real-backend test of the two accepted evaporation API names.

The original crop/root chemical rejection test remains byte unchanged. Generate
only a separate driver, adding positive soil demand and exact trace assertions.
"""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import time

ROOT = Path(__file__).resolve().parents[2]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for opt in ['O0', 'O2']:
        parser.add_argument('--column-' + opt, type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    out = args.output.resolve()
    out.mkdir(parents=True, exist_ok=False)
    original = ROOT / 'tests/nut-sol/test_crop_root_transaction.f90'
    text = original.read_text()
    changes = {
        ' integer::s\n': ' integer::s,i\n type(fmr_serialized_physical_observation_t)::obs\n real(real64)::evap\n',
        ' allocate(forcing%pond_input);forcing%pond_input%ponding_max_cm=1d6':
        ' allocate(forcing%pond_input);forcing%pond_input%ponding_max_cm=1d6\n'
        ' forcing%pond_input%potential_bare_soil_evaporation_cm_day=.02d0',
        ' supply=pond_step_t();supply%t0=0d0;supply%t1=.001d0':
        ' supply=pond_step_t();supply%t0=0d0;supply%t1=.001d0\n'
        ' supply%exact_empty_pool_chemistry=.true.',
        " call check(result%status==JOINT_OK,'retry accepts')":
        " call check(result%status==JOINT_OK,'retry accepts')\n"
        ' obs=backend%observation()\n'
        " call check(obs%accepted_water_flux_trace_available,'accepted trace available')\n"
        ' evap=0d0\n do i=1,size(obs%accepted_water_flux_substeps)\n'
        '  associate(t=>obs%accepted_water_flux_substeps(i))\n'
        "   call check(t%converged_surface_available,'converged trace available')\n"
        '   call check(t%converged_soil_evaporation_cm_day==t%converged_bare_soil_evaporation_cm_day, &\n'
        "     'canonical and weather evaporation aliases differ')\n"
        '   evap=evap+t%converged_soil_evaporation_cm_day*(t%t1-t%t0)\n'
        '  end associate\n end do\n'
        " call check(abs(evap-.02d0*.001d0)<1d-14,'positive accepted evaporation integrated once')\n"
        " print '(A)','WEATHER_CANONICAL_ACCEPTED_EVAPORATION_ALIASES_PASS'",
    }
    for before, after in changes.items():
        assert text.count(before) == 1, before
        text = text.replace(before, after, 1)
    driver = out / 'driver.f90'
    driver.write_text(text)
    report = {'status': 'RUNNING', 'events': [], 'builds': {},
              'input_sha256': {str(p.relative_to(ROOT)): sha(p) for p in [Path(__file__), original]},
              'generated_driver_sha256': sha(driver)}
    for opt in ['O0', 'O2']:
        build_dir = getattr(args, 'column_' + opt).resolve()
        build = json.loads((build_dir / 'build-complete.json').read_text())
        assert build['status'] == 'BUILT'
        assert all(sha(ROOT / p) == h for p, h in build['input_sha256'].items())
        assert all(sha(build_dir / p) == h for p, h in build['generated_input_sha256'].items())
        objects = [Path(e['command'][-1]) for e in build['events'] if e['category'] == 'compile'
                   and e['command'][-3] != str(ROOT / 'app/solute_crop/main.f90')]
        assert len(objects) == build['provider_count'] - 1
        artifacts = objects + [build_dir / 'libttutil.a']
        pinned = {str(p): sha(p) for p in artifacts}
        folder = out / opt
        folder.mkdir()
        exe = folder / 'trace'
        flags = [f for f in build['flags'] if not f.startswith('-J')] + ['-J' + str(folder)]
        for category, command in [('link', build['compiler_command'] + flags +
                                   [driver, *artifacts, '-o', exe]), ('native', [exe])]:
            command = list(map(str, command))
            start = time.monotonic()
            result = subprocess.run(command, cwd=folder, capture_output=True, timeout=120)
            for stream in ['stdout', 'stderr']:
                (folder / (category + '.' + stream)).write_bytes(getattr(result, stream))
            report['events'].append({'category': category, 'optimization': opt, 'command': command,
                                     'returncode': result.returncode, 'seconds': time.monotonic() - start})
            (out / 'RESULT.json').write_text(json.dumps(report, indent=2) + '\n')
            result.check_returncode()
            if category == 'native':
                assert b'WEATHER_CANONICAL_ACCEPTED_EVAPORATION_ALIASES_PASS' in result.stdout
                assert b'CROP_ROOT_COMMITTED_NONMUTATION_CHEMICAL_REJECT_RETRY_PASS' in result.stdout
        assert all(sha(Path(p)) == h for p, h in pinned.items())
        for a, b in [('original.bin', 'rejected.bin'), ('retry.bin', 'fresh.bin')]:
            assert (folder / a).read_bytes() == (folder / b).read_bytes()
        report['builds'][opt] = build
    report['status'] = 'CANONICAL_WEATHER_TRACE_AND_REJECT_RETRY_O0_O2_PASS'
    (out / 'RESULT.json').write_text(json.dumps(report, indent=2) + '\n')
    print(report['status'])


if __name__ == '__main__':
    main()
