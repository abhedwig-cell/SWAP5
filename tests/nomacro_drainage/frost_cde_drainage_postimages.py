"""Rebuild only affected wrappers; compare unchanged accepted Fortran and states."""
import argparse
import json
from pathlib import Path
import subprocess
import sys
import time
import zipfile

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tests/nomacro_scheduled_subsurface'))
import output_thermal_runtime as thermal
from calendar_evidence import differences
from calendar_publisher import publisher_equivalence
from implicit_conductivity_forensics import output_records


def main():
    p = argparse.ArgumentParser(description=__doc__)
    for key in ('reference-work', 'baseline', 'build-root', 'output'):
        p.add_argument('--' + key, type=Path, required=True)
    p.add_argument('--optimization', choices=('O0', 'O2'), required=True)
    a = p.parse_args(); a.output.mkdir(); a.build_root.mkdir(exist_ok=True)
    m = thermal.m; manifest = json.loads(a.baseline.read_text()); baseline_hash = m.sha(a.baseline)
    assert len(manifest['profiles']) == 6
    q = dict(status='RUNNING', source=subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
        optimization=a.optimization, baseline=str(a.baseline), baseline_sha256=baseline_hash,
        profiles={}, fresh_unaffected_full_periods=0)
    def save(): (a.output / 'RESULT.json').write_text(json.dumps(q, indent=2) + '\n', encoding='utf-8')
    save()
    try:
        for name, base in manifest['profiles'].items():
            receipt = Path(base['receipt']); assert m.sha(receipt) == base['receipt_sha256']
            parent = Path(base['build_root']); old = json.loads((parent / 'BUILD.json').read_text())
            inputs = Path(base['input_root']); warm_parent = Path(base['trajectory_root'])
            project = m.e.load(inputs, original_output=True, time_step_policy=base['time_policy'])
            import frost_drainage_composition
            assert not frost_drainage_composition.enabled(project)
            out = a.output / name; out.mkdir(); build = a.build_root / name / 'bundle'
            item = q['profiles'][name] = dict(baseline=base, input_root=str(inputs), build_root=str(build), status='RUNNING')
            command = [sys.executable, '-B', str(ROOT / 'tools/solute/run_water.py'), '--model', project.model,
                '--experimental-project', str(inputs), '--original-output', '--experimental-time-step-policy', base['time_policy'],
                '--reference-work', str(a.reference_work), '--build-only', '--donor-opt', a.optimization,
                '--kernel-opt', a.optimization, '--output', str(build)]
            start = time.perf_counter()
            with (out / 'build.stdout').open('x') as stdout, (out / 'build.stderr').open('x') as stderr:
                result = subprocess.run(command, cwd=ROOT, stdout=stdout, stderr=stderr, timeout=180)
            item['build'] = dict(command=command, returncode=result.returncode, seconds=time.perf_counter()-start)
            save(); result.check_returncode()
            meta, _ = m.validate_bundle(build, a.reference_work, project)
            before = {p.name: p.read_bytes() for p in parent.glob('*.f90')}
            after = {p.name: p.read_bytes() for p in build.glob('*.f90')}
            assert before == after, 'Unselected complete compiled Fortran changed: ' + name
            assert old['inputs'] == meta['inputs'] and old['project'] == meta['project']
            delta = differences(old['identity'], meta['identity'])
            allowed = {'host', 'experimental_input_adapter', 'original_output.source_sha256', 'restart_publisher.library_sha256'}
            assert set(delta) <= allowed, (name, delta)
            if 'restart_publisher.library_sha256' in delta:
                item['publisher_equivalence'] = publisher_equivalence(parent / 'restart_publish.dll', build / 'restart_publish.dll')
            item['identity_changes'] = delta
            item['unchanged_complete_Fortran'] = {p.name: m.sha(p) for p in build.glob('*.f90')}
            trajectory = out / 'trajectory'; data_parent = m.rows(warm_parent)
            item['trajectory'], data = m.trajectory(build, a.reference_work, project, trajectory, 35, {2, 4, 30, 34, 35}, 180)
            assert m.physical(data) == m.physical(data_parent[:35]), 'Unselected physical postimage changed'
            for day in (2, 4, 30, 34, 35):
                with zipfile.ZipFile(warm_parent / f'accepted-column-1-day-{day}.zip') as x, \
                     zipfile.ZipFile(trajectory / f'accepted-column-1-day-{day}.zip') as y:
                    assert all(x.read(n) == y.read(n) for n in ('macro.bin', 'result.end'))
            for filename in ('result_output.csv', 'result_output.bin'):
                original = warm_parent / 'original' / filename; current = trajectory / 'original' / filename
                assert original.exists() == current.exists()
                if original.exists():
                    old_rows = output_records(original.read_bytes(), filename)
                    new_rows = output_records(current.read_bytes(), filename)
                    # Accepted full-period parents are projected only to this
                    # exact completed 35-day prefix; no period is rerun.
                    assert new_rows == old_rows[:len(new_rows)]
            item['cold'] = thermal.own(build, a.reference_work, project, trajectory, data, 30, 34, out / 'own-30')
            item['status'] = 'EXACT_UNSELECTED_FORTRAN_PHYSICAL_NATIVE_USER_OUTPUT_POSTIMAGE_PASS'
            save(); print(name, item['status'], flush=True)
        assert m.sha(a.baseline) == baseline_hash
        q['status'] = 'ACTUAL_SIX_UNSELECTED_FROST_COMPOSITION_DEPENDENCY_POSTIMAGES_PASS'
    except Exception as error:
        q.update(status='FAILED', error=repr(error)); raise
    finally: save()


if __name__ == '__main__': main()
