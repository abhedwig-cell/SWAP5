"""Candidate actual explicit Frost/SWDIVD1 daily composition and cold tests."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[2]
sys.path[:0] = [str(ROOT / 'tests/nomacro_scheduled_subsurface'), str(ROOT / 'tools/solute')]
import output_thermal_runtime as thermal
from original_output_baseline import assignment


def main():
    p = argparse.ArgumentParser(description=__doc__)
    for name in ('reference-work', 'build-root', 'output'):
        p.add_argument('--' + name, type=Path, required=True)
    p.add_argument('--kind', choices=('water', 'cde'), required=True)
    p.add_argument('--optimization', choices=('O0', 'O2'), required=True)
    p.add_argument('--phase', choices=('short', 'full'), default='short')
    p.add_argument('--reuse-build', type=Path)
    p.add_argument('--existing-input', type=Path)
    a = p.parse_args(); a.output.mkdir()
    inputs = a.existing_input or a.output / 'input'
    if a.existing_input is None:
        thermal.fixture(inputs, 'water-frost-drained', 3)
        path = inputs / 'swap.swp'; text = path.read_text(encoding='cp1252')
        text = assignment(text, 'SWSOLU', int(a.kind == 'cde'))
        if a.kind == 'cde': text = assignment(text, 'CPRE', '0.01')
        path.write_text(text, encoding='cp1252')
        path = inputs / 'swap.dra'
        path.write_text(assignment(path.read_text(encoding='cp1252'), 'SWDIVD', 1), encoding='cp1252')
    m = thermal.m; policy = 'original-adaptive-event-closure-v1'
    q = dict(status='RUNNING', source=subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
        kind=a.kind, optimization=a.optimization, phase=a.phase, input_root=str(inputs),
        build_root=str(a.reuse_build or a.build_root), canonical_admission=False,
        inventory={str(v.relative_to(inputs)): hashlib.sha256(v.read_bytes()).hexdigest()
                   for v in sorted(inputs.rglob('*')) if v.is_file()})
    def save(): (a.output / 'RESULT.json').write_text(json.dumps(q, indent=2) + '\n', encoding='utf-8')
    save()
    try:
        project = m.e.load(inputs, original_output=True, time_step_policy=policy)
        assert project.solute == (a.kind == 'cde')
        build = a.reuse_build or a.build_root
        if a.reuse_build is None:
            command = [sys.executable, '-B', str(ROOT / 'tools/solute/run_water.py'), '--model', project.model,
                '--experimental-project', str(inputs), '--original-output', '--experimental-time-step-policy', policy,
                '--reference-work', str(a.reference_work), '--build-only', '--donor-opt', a.optimization,
                '--kernel-opt', a.optimization, '--output', str(build)]
            start = time.perf_counter()
            result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, timeout=180)
            (a.output / 'build.stdout.txt').write_text(result.stdout, encoding='utf-8')
            (a.output / 'build.stderr.txt').write_text(result.stderr, encoding='utf-8')
            q['build'] = dict(returncode=result.returncode, seconds=time.perf_counter()-start, command=command)
            save(); result.check_returncode()
        m.validate_bundle(build, a.reference_work, project)
        days = 35 if a.phase == 'short' else 1096
        windows = [(2, 4), (19, 23), (30, 34)]
        if a.phase == 'full': windows += [(199, 201), (364, 367), (530, 532), (1094, 1096)]
        cuts = {days} | {d for pair in windows for d in pair}
        trajectory = a.output / 'trajectory'
        q['trajectory'], data = m.trajectory(build, a.reference_work, project, trajectory, days, cuts, 180)
        q['own'] = []
        for start, end in windows:
            q['own'].append(thermal.own(build, a.reference_work, project, trajectory, data, start, end,
                a.output / ('own-' + str(start))))
            save()
        q['status'] = 'CANDIDATE_ACTUAL_FROST_SWDIVD1_' + a.kind.upper() + '_' + a.phase.upper() + '_PASS_NOT_ADMITTED'
        print(q['status'], q['trajectory'], flush=True)
    except Exception as error:
        q.update(status='FAILED', error=repr(error)); raise
    finally:
        save()


if __name__ == '__main__': main()
