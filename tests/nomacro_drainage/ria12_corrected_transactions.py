"""Representative real external transactions, preserving original checkpoint binding."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import zipfile

R = Path(__file__).resolve().parents[2]
sys.path[:0] = [str(R / 'tests/nomacro_drainage'), str(R / 'tests/nomacro_scheduled_subsurface'), str(R / 'app/hybrid_water')]
from ria12_corrected_source import complete_inverse
import original_output_controls as inherited
from daily_coupling import CoupledDailyColumn
from original_output_controls import physical


def main():
    p = argparse.ArgumentParser()
    for key in ('profile', 'reference-work', 'output'):
        p.add_argument('--' + key, type=Path, required=True)
    p.add_argument('--current-controls', type=Path)
    a = p.parse_args()
    complete_inverse()
    a.output.mkdir()
    profile = json.loads((a.profile / 'RESULT.json').read_text())
    build = Path(profile['build_root'])
    compiler = profile.get('actual_compiler_source', profile['source'])
    if a.current_controls:
        control = json.loads((a.current_controls / 'RESULT.json').read_text())
        assert control['own_positive_ready']
        if not control['actual_compiled_postimage']:
            # A native control on the original genuine compile needs no
            # additional compiler image. Require exact original identity.
            assert Path(control['actual_current_build_root']) == build
            assert control['actual_compiler_source'] == compiler
            assert control['actual_BUILD_sha256'] == hashlib.sha256((build / 'BUILD.json').read_bytes()).hexdigest()
        build = Path(control['actual_current_build_root'])
        compiler = control['actual_compiler_source']
    project = inherited.m.e.load(profile['input_root'], original_output=True, time_step_policy='original-adaptive-day-seed-v1')
    meta, _ = inherited.m.validate_bundle(build, a.reference_work, project)
    data = inherited.m.rows(a.profile / 'trajectory')
    source = a.profile / 'trajectory/accepted-column-1-day-4.zip'
    with zipfile.ZipFile(source) as z:
        original_binding = json.loads(z.read('checkpoint.json'))['binding']
    prefix_days = 0
    if original_binding != meta['binding']:
        # A current adapter identity requires a genuine current checkpoint.
        # Keep the original 35-day model and its metadata untouched.
        _, prefix = inherited.m.trajectory(build, a.reference_work, project, a.output / 'current-prefix4', 4, {4}, 120)
        assert inherited.m.physical(prefix) == inherited.m.physical(data[:4])
        current = a.output / 'current-prefix4/accepted-column-1-day-4.zip'
        with zipfile.ZipFile(source) as old, zipfile.ZipFile(current) as new:
            assert all(old.read(n) == new.read(n) for n in ('macro.bin', 'result.end'))
        source = current
        prefix_days = 4
    digest = inherited.m.sha(source)
    column = CoupledDailyColumn(build, a.reference_work, a.output / 'external', project, 'original-output', origin=source, day=4, adopt_native=True)
    trial = column.prepare()
    assert physical(trial) == inherited.m.physical([data[4]])
    if project.solute:
        assert any(row['solute_ledger_mg_cm2'][3] > 0 for row in data), 'Representative full period has no incoming tracer'
    column.discard(trial)
    assert column.day == 4
    replay = column.prepare()
    assert replay.budget == trial.budget
    column.accept(replay)
    recovered = CoupledDailyColumn(build, a.reference_work, a.output / 'recovered', project, 'original-output', origin=column.checkpoint, day=5)
    endpoint = recovered.prepare()
    assert physical(endpoint) == inherited.m.physical([data[5]])
    recovered.discard(endpoint)
    assert inherited.m.sha(source) == digest
    record = dict(status='RIA12_CORRECTED_ACTUAL_EXTERNAL_DISCARD_REPLAY_ACCEPT_RECOVER_EXACT_PASS_NOT_ADMITTED',
                  actual_observer_source=subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=R).decode().strip(),
                  actual_compiler_producer=compiler, full35_producer=profile['source'],
                  kind=profile['kind'], optimization=profile['optimization'], actual_build_root=str(build),
                  actual_BUILD_sha256=hashlib.sha256((build / 'BUILD.json').read_bytes()).hexdigest(),
                  actual_origin=str(source), original_checkpoint_metadata_or_binding_rewritten=False,
                  targeted_current_prefix_days=prefix_days, prefix_physical_and_complete_native_exact=True,
                  external_worker_prepares=3, external_commits=1, compiler_executions=0, full35_periods_replayed=0,
                  discard_no_day_advance=True, replay_exact=True, accept_exact=True, recovered_next_day_exact=True, origin_unchanged=True,
                  canonical_admission=False)
    (a.output / 'RESULT.json').write_text(json.dumps(record, indent=2) + '\n')
    print(record['status'], profile['kind'], profile['optimization'], prefix_days)


if __name__ == '__main__':
    main()
