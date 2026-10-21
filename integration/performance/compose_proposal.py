"""Requalify concurrent nonlinear thermal admission on the optional runtime.

Retain the earlier linear run as its own pinned observation. Reuse only the
unchanged, freshly executed eight-driver runtime proof after all input hashes
match the composed source. Build the new six-exponent thermal route separately.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shlex
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
BASE = 'e61d8e107121bc31fa1d9b0eac73439af29eb76f'


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--output', type=Path, required=True)
    ap.add_argument('--runtime', type=Path, required=True)
    ap.add_argument('--compiler-manifest', type=Path, required=True)
    args = ap.parse_args()
    out = args.output.resolve()
    out.mkdir(parents=True, exist_ok=False)
    prior = json.loads((args.runtime/'PRESERVATION.json').read_text())
    assert prior['status'] == 'INCUMBENT_EIGHT_RUNTIME_OBSERVATIONS_EXACT_PASS'
    assert all(hashlib.sha256((ROOT/p).read_bytes()).hexdigest() == h for p, h in prior['inputs'].items())
    fc = json.loads(args.compiler_manifest.read_text())['compiler_command']
    env = {**os.environ, 'FC': shlex.join(fc), 'PYTHONDONTWRITEBYTECODE': '1'}
    for name in ['1', '0.5', '0.8', '1.0005', '1.5', '2']:
        case = out/'thermal'/name
        case.mkdir(parents=True)
        p = ['python', '-B', ROOT/'tests/nut-sol/run_matrix_thermal.py', '--output', case/'physical', '--exponent', name]
        q = ['python', '-B', ROOT/'integration/audits/qualify_matrix_thermal.py', '--physical', case/'physical',
             '--output', case/'qualification']
        if name != '1':
            p += ['--reuse-build', out/'thermal/1/physical']
            q += ['--build', out/'thermal/1/physical', '--nonlinear-refinement']
        for command, log in [(p, 'physical.log'), (q, 'qualification.log')]:
            with (case/log).open('wb') as stream:
                subprocess.run(list(map(str, command)), cwd=ROOT, env=env, stdout=stream, stderr=subprocess.STDOUT, check=True)
        print('CURRENT_THERMAL_EXPONENT_PASS', name, flush=True)
    with tempfile.TemporaryDirectory(prefix='perf01-composed-predecessor-') as temp:
        base = Path(temp)/'base'
        subprocess.run(['git', 'worktree', 'add', '--detach', base, BASE], cwd=ROOT, capture_output=True, check=True)
        try:
            proof = {'baseline': BASE, 'source_tree': subprocess.check_output(['git', 'rev-parse', 'HEAD:src'], cwd=base, text=True).strip()}
            for name, script, flags in [('owner', 'integration/performance/authority.py', []),
                                        ('gash-controls', 'integration/performance/authority.py', ['--self-test']),
                                        ('thermal-controls', 'integration/audits/verify_matrix_thermal.py', ['--self-test'])]:
                p = subprocess.run(['python', '-B', script, *flags], cwd=base, env=env, capture_output=True)
                (out/('predecessor-'+name+'.stdout')).write_bytes(p.stdout)
                (out/('predecessor-'+name+'.stderr')).write_bytes(p.stderr)
                p.check_returncode()
                proof[name] = json.loads(p.stdout)
            (out/'PREDECESSOR.json').write_text(json.dumps(proof, indent=2)+'\n')
        finally:
            subprocess.run(['git', 'worktree', 'remove', '--force', base], cwd=ROOT, capture_output=True, check=True)
    print('COMPOSED_CURRENT_THERMAL_PREDECESSOR_PASS', flush=True)


if __name__ == '__main__':
    main()
