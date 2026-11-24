"""One real bounded RIA12 period and exact native cold windows, actual sources."""
import argparse
import json
from pathlib import Path
import subprocess
import sys
import time

R = Path(__file__).resolve().parents[2]
sys.path[:0] = [str(R / 'tests/nomacro_drainage'), str(R / 'tests/nomacro_scheduled_subsurface'), str(R / 'app/hybrid_water')]
from explicit_bottom9_runtime import m, own
from analytical_hydraulic_archives import SHA
from ria12_corrected_source import complete_inverse, git, CORE


def main():
    parser = argparse.ArgumentParser()
    for name in ('input', 'reference-work', 'build-root', 'output'):
        parser.add_argument('--' + name, type=Path, required=True)
    parser.add_argument('--optimization', choices=('O0', 'O2'), required=True)
    args = parser.parse_args()
    complete_inverse()
    head = git('rev-parse', 'HEAD').decode().strip()
    project = m.e.load(args.input, original_output=True, time_step_policy='original-adaptive-day-seed-v1')
    from original_ria12_corrected import selection
    selected = selection(project.input_directory, project.original_output)
    assert selected and selected['models'] == [12, 12]
    args.output.mkdir()
    bundle = args.build_root / 'bundle'
    q = dict(status='RUNNING_RIA12_CORRECTED_TWO_DAY_NOT_QUALIFIED', source=head, observer_source=head, composition_core=CORE, days=2,
             optimization=args.optimization, kind=selected['kind'], layer_models=selected['models'], input_root=str(args.input),
             input_inventory=m.e.inventory(args.input), build_root=str(bundle), canonical_admission=False)
    save = lambda: (args.output / 'RESULT.json').write_text(json.dumps(q, indent=2) + '\n')
    started = time.perf_counter()
    save()
    try:
        command = [sys.executable, '-B', 'tools/solute/run_water.py', '--model', project.model, '--experimental-project', str(args.input),
                   '--original-output', '--experimental-time-step-policy', project.time_step_policy, '--reference-work', str(args.reference_work),
                   '--build-only', '--donor-opt', args.optimization, '--kernel-opt', args.optimization, '--output', str(bundle)]
        with (args.output / 'build.stdout').open('xb') as out, (args.output / 'build.stderr').open('xb') as err:
            result = subprocess.run(command, cwd=R, stdout=out, stderr=err, timeout=240)
        q['build'] = dict(command=command, returncode=result.returncode, actual_completion_head=git('rev-parse', 'HEAD').decode().strip())
        save()
        result.check_returncode()
        assert q['build']['actual_completion_head'] == head
        q['actual_BUILD_sha256'] = SHA((bundle / 'BUILD.json').read_bytes())
        m.validate_bundle(bundle, args.reference_work, project)
        q['trajectory'], data = m.trajectory(bundle, args.reference_work, project, args.output / 'trajectory', 2, {1, 2}, 120)
        q['cold'] = []
        save()
        for low, high in ((1, 2),):
            q['cold'].append(own(bundle, args.reference_work, project, args.output / 'trajectory', data, low, high, args.output / ('own-' + str(low))))
            save()
        complete_inverse()
        q['status'] = 'ACTUAL_RIA12_CORRECTED_TWO_DAY_PHYSICAL_NATIVE_COLD_USER_OUTPUT_PASS_NOT_ADMITTED'
    except Exception as error:
        q.update(status='FAILED_RIA12_CORRECTED_TWO_DAY_NOT_QUALIFIED', error=repr(error))
        raise
    finally:
        q['actual_completion_head'] = git('rev-parse', 'HEAD').decode().strip()
        q['seconds'] = time.perf_counter() - started
        save()
    assert q['actual_completion_head'] == head
    print(q['status'], q['kind'], q['optimization'], q['seconds'])


if __name__ == '__main__':
    main()
