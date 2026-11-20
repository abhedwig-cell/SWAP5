"""Targeted secondary implicit history and prescribed-level interactions."""
import argparse
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]


def main():
    p = argparse.ArgumentParser(description=__doc__)
    for key in ('reference-work', 'build-root', 'output', 'water-full', 'cde-full'):
        p.add_argument('--'+key, type=Path, required=True)
    p.add_argument('--optimization', choices=('O0', 'O2'), required=True)
    a = p.parse_args()
    a.output.mkdir()
    contexts = [('automatic', case, h) for case in ('water', 'fixed') for h in (0, 1, 2)]
    contexts += [('prescribed', 'water', 0), ('prescribed', 'fixed', 0), ('prescribed', 'fixed', 2)]
    q = dict(status='RUNNING', source=subprocess.check_output(
        ['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(), contexts=[], failures=[])
    for secondary, case, h in contexts:
        label = f'{secondary}-{case}-h{h}'
        out = a.output/label
        command = [sys.executable, '-B', 'tests/nomacro_drainage/calendar_runtime.py',
                   '--case', case, '--mode', 'monthly' if case == 'water' else 'daily',
                   '--format', '2' if case == 'water' else '3', '--hysteresis', str(h),
                   '--implicit', '--days', '35', '--optimization', a.optimization,
                   '--reference-work', str(a.reference_work), '--build-root', str(a.build_root/label),
                   '--output', str(out)]
        if secondary == 'prescribed':
            command.append('--secondary-prescribed')
        elif (case, h) in (('water', 0), ('fixed', 2)):
            full = a.water_full if case == 'water' else a.cde_full
            command += ['--reuse-build', json.loads((full/'RESULT.json').read_text())['build_root']]
        failed = False
        for phase, cmd in [('producer', command), ('independent', [sys.executable, '-B',
                'tests/nomacro_drainage/secondary_pond_forensics.py', str(out),
                '--output', str(out/'FORENSICS_V1.json')])]:
            run = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True, timeout=180)
            (a.output/(label+'-'+phase+'.stdout')).write_text(run.stdout)
            (a.output/(label+'-'+phase+'.stderr')).write_text(run.stderr)
            if run.returncode:
                q['failures'].append(dict(label=label, phase=phase, returncode=run.returncode))
                failed = True
                break
        if failed:
            (a.output/'RESULT.json').write_text(json.dumps(q, indent=2))
            continue
        q['contexts'].append(dict(secondary=secondary, case=case, hysteresis=h, root=str(out)))
        (a.output/'RESULT.json').write_text(json.dumps(q, indent=2))
        print(label, a.optimization, 'PASS', flush=True)
    q['status'] = ('FAILED' if q['failures'] else
                   'ACTUAL_NINE_SECONDARY35DAY_INTERACTIONS_AND27EXACT_NATIVE_WINDOWS_PASS')
    (a.output/'RESULT.json').write_text(json.dumps(q, indent=2))
    if q['failures']:
        raise SystemExit(1)


if __name__ == '__main__':
    main()
