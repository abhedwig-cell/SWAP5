"""Representative fresh35 boundary period; genuine prior compiles may be reused."""
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
from ria12_boundary_source import complete_inverse, git, CORE
from original_ria12_boundary import selection


def main():
    p = argparse.ArgumentParser()
    for key in ('input', 'reference-work', 'output'):
        p.add_argument('--' + key, type=Path, required=True)
    group = p.add_mutually_exclusive_group(required=True)
    group.add_argument('--build-root', type=Path)
    group.add_argument('--reuse-profile', type=Path)
    p.add_argument('--optimization', choices=('O0', 'O2'), required=True)
    a = p.parse_args()
    complete_inverse()
    head = git('rev-parse', 'HEAD').decode().strip()
    project = m.e.load(a.input, original_output=True, time_step_policy='original-adaptive-day-seed-v1')
    selected = selection(a.input, True)
    assert selected and selected['models'] == [12, 12]
    a.output.mkdir()
    bundle = a.build_root / 'bundle' if a.build_root else None
    q = dict(status='RUNNING_RIA12_BOUNDARY_FULL35_NOT_QUALIFIED', source=head, observer_source=head, composition_core=CORE,
             days=35, optimization=a.optimization, kind=selected['kind'], layer_models=selected['models'],
             bottom=selected['bottom'], drainage=selected['drainage'], input_root=str(a.input), input_inventory=m.e.inventory(a.input),
             actual_compiler_source=head, canonical_admission=False)
    def save():
        (a.output / 'RESULT.json').write_text(json.dumps(q, indent=2) + '\n')
    started = time.perf_counter()
    save()
    try:
        if a.reuse_profile:
            raw = (a.reuse_profile / 'RESULT.json').read_bytes()
            prior = json.loads(raw)
            assert prior['status'] == 'ACTUAL_RIA12_BOUNDARY_TWO_DAY_PHYSICAL_NATIVE_COLD_USER_OUTPUT_PASS_NOT_ADMITTED'
            assert prior['optimization'] == a.optimization and prior['input_inventory'] == q['input_inventory']
            assert not git('diff', prior['source'], head, '--', 'app', 'src', 'tools', 'reference')
            bundle = Path(prior['build_root'])
            assert SHA((bundle / 'BUILD.json').read_bytes()) == prior['actual_BUILD_sha256']
            q['actual_compiler_source'] = prior['source']
            q['build'] = prior['build']  # Original compiler receipt remains verbatim.
            q['compiler_reuse'] = dict(actual_profile=str(a.reuse_profile), actual_RESULT_sha256=SHA(raw), compiler_executions=0,
                                       execution_source_delta='NONE_APP_SRC_TOOLS_REFERENCE', original_metadata_rewritten=False)
        else:
            command = [sys.executable, '-B', 'tools/solute/run_water.py', '--model', project.model, '--experimental-project', str(a.input),
                       '--original-output', '--experimental-time-step-policy', project.time_step_policy, '--reference-work', str(a.reference_work),
                       '--build-only', '--donor-opt', a.optimization, '--kernel-opt', a.optimization, '--output', str(bundle)]
            with (a.output / 'build.stdout').open('xb') as out, (a.output / 'build.stderr').open('xb') as err:
                result = subprocess.run(command, cwd=R, stdout=out, stderr=err, timeout=240)
            q['build'] = dict(command=command, returncode=result.returncode, actual_completion_head=git('rev-parse', 'HEAD').decode().strip())
            save()
            result.check_returncode()
            assert q['build']['actual_completion_head'] == head
        q['build_root'] = str(bundle)
        q['actual_BUILD_sha256'] = SHA((bundle / 'BUILD.json').read_bytes())
        m.validate_bundle(bundle, a.reference_work, project)
        save()
        q['trajectory'], data = m.trajectory(bundle, a.reference_work, project, a.output / 'trajectory', 35, {2, 4, 7, 9, 30, 34, 35}, 600)
        q['cold'] = []
        save()
        for low, high in ((2, 4), (7, 9), (30, 34)):
            q['cold'].append(own(bundle, a.reference_work, project, a.output / 'trajectory', data, low, high, a.output / ('own-' + str(low))))
            save()
        assert any(abs(row['bottom_outward_cm']) > 1e-8 for row in data), 'No meaningful active bottom exchange'
        if selected['kind'] == 'cde':
            assert any(row['solute_ledger_mg_cm2'][3] > 0 for row in data), 'Incoming tracer source never active'
        if selected['bottom'] == 8:
            assert any(row['bottom_outward_cm'] > 1 for row in data), 'Wet8 open branch never active'
            if selected['drainage'] == 1:
                assert any(row['drainage_outward_cm'] > 0 for row in data), 'Drainage never active'
        complete_inverse()
        q['status'] = 'ACTUAL_RIA12_BOUNDARY_FULL35_PHYSICAL_NATIVE_COLD_USER_OUTPUT_PASS_NOT_ADMITTED'
    except Exception as error:
        q.update(status='FAILED_RIA12_BOUNDARY_FULL35_NOT_QUALIFIED', error=repr(error))
        raise
    finally:
        q['actual_completion_head'] = git('rev-parse', 'HEAD').decode().strip()
        q['seconds'] = time.perf_counter() - started
        save()
    assert q['actual_completion_head'] == head
    print(q['status'], selected['kind'], a.optimization, q['seconds'])


if __name__ == '__main__':
    main()
