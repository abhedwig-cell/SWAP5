"""Fresh execution of the incumbent four-driver runtime preservation gate.

Replay its measured ordered build/driver commands against current source with
the selected compiler and fresh O0/O2 directories. Retain original assertions.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import runpy
import shlex
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[2]


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--output', type=Path, required=True)
    ap.add_argument('--compiler-manifest', type=Path, required=True)
    args = ap.parse_args()
    out = args.output.resolve()
    out.mkdir(parents=True, exist_ok=False)
    old = json.loads(runpy.run_path(str(ROOT/'integration/performance/authority.py'))['capsule']()['arena-preservation/CONTROL.json'])
    fc = json.loads(args.compiler_manifest.read_text())['compiler_command']
    report = {'inputs': {}, 'events': [], 'runs': [], 'status': 'RUNNING',
              'candidate': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()}
    for path in old['source_sha256']:
        report['inputs'][path] = hashlib.sha256((ROOT/path).read_bytes()).hexdigest()
    prefix = str(Path(old['events'][0]['command'][-1]).parent.parent)
    for opt in ['O0', 'O2']:
        (out/opt).mkdir()
    count = 0
    for event in old['events']:
        command = [str(v).replace(prefix, str(out)) for v in event['command']]
        if command[0] == 'gfortran':
            command = fc+command[1:]
        start = time.monotonic()
        p = subprocess.run(command, cwd=out, capture_output=True)
        i = len(report['events'])
        for stream in ['stdout', 'stderr']:
            (out/f'{i:04d}.{stream}').write_bytes(getattr(p, stream))
        category = 'compile' if '-c' in command else ('link' if '-o' in command else 'native')
        report['events'].append(dict(command=command, category=category, seconds=time.monotonic()-start,
                                     returncode=p.returncode))
        (out/'PRESERVATION.json').write_text(json.dumps(report, indent=2)+'\n')
        if p.returncode:
            print(p.stderr.decode(), p.stdout.decode(), flush=True)
            p.check_returncode()
        if category == 'native':
            expected = old['runs'][count]
            assert p.stdout.decode() == expected['stdout'], 'incumbent physical/runtime stdout changed'
            report['runs'].append({**expected, 'stdout': p.stdout.decode()})
            count += 1
    assert count == 8
    report['status'] = 'INCUMBENT_EIGHT_RUNTIME_OBSERVATIONS_EXACT_PASS'
    (out/'PRESERVATION.json').write_text(json.dumps(report, indent=2)+'\n')
    # Independently rebuild and run current thermal shared-runtime composition.
    env = {**os.environ, 'FC': shlex.join(fc), 'PYTHONDONTWRITEBYTECODE': '1'}
    for command, log in [
        (['python', '-B', ROOT/'tests/nut-sol/run_matrix_thermal.py', '--output', out/'thermal-physical'], 'thermal-physical.log'),
        (['python', '-B', ROOT/'integration/audits/qualify_matrix_thermal.py', '--physical', out/'thermal-physical',
          '--output', out/'thermal-qualified'], 'thermal-qualified.log')]:
        with (out/log).open('wb') as stream:
            subprocess.run(list(map(str, command)), cwd=ROOT, env=env, stdout=stream, stderr=subprocess.STDOUT, check=True)
    baseline = '9c16572a57ada1c4b7e619bae8c1bdfb3c6f5e9c'
    with tempfile.TemporaryDirectory(prefix='perf01-proposal-predecessor-') as temp:
        base = Path(temp)/'base'
        subprocess.run(['git', 'worktree', 'add', '--detach', base, baseline], cwd=ROOT, capture_output=True, check=True)
        try:
            proof = {'baseline': baseline, 'source_tree': subprocess.check_output(['git', 'rev-parse', 'HEAD:src'], cwd=base, text=True).strip()}
            for name, script, options in [('owner', 'integration/performance/authority.py', []),
                                           ('gash-controls', 'integration/performance/authority.py', ['--self-test']),
                                           ('thermal-controls', 'integration/audits/verify_matrix_thermal.py', ['--self-test'])]:
                command = ['python', '-B', script, *options]
                p = subprocess.run(command, cwd=base, env=env, capture_output=True)
                (out/('predecessor-'+name+'.stdout')).write_bytes(p.stdout)
                (out/('predecessor-'+name+'.stderr')).write_bytes(p.stderr)
                p.check_returncode()
                proof[name] = json.loads(p.stdout)
            (out/'PREDECESSOR.json').write_text(json.dumps(proof, indent=2)+'\n')
        finally:
            subprocess.run(['git', 'worktree', 'remove', '--force', base], cwd=ROOT, capture_output=True, check=True)
    print(report['status'], 'THERMAL_PHYSICAL_REFINEMENT_CRASH_PASS', flush=True)


if __name__ == '__main__':
    main()
