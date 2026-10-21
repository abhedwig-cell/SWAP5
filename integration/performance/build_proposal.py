"""Fresh direct policy tests and real column builds, with retained execution costs."""
import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import shlex
import subprocess
import time

ROOT = Path(__file__).resolve().parents[2]


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--output', type=Path, required=True)
    ap.add_argument('--compiler-manifest', type=Path, required=True)
    args = ap.parse_args()
    out = args.output.resolve()
    out.mkdir(parents=True, exist_ok=False)
    fc = json.loads(args.compiler_manifest.read_text())['compiler_command']
    env = {**os.environ, 'FC': shlex.join(fc), 'PYTHONDONTWRITEBYTECODE': '1'}
    spec = importlib.util.spec_from_file_location('dep', ROOT/'tests/support/augment_bartholomeus_backend_sources.py')
    dep = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(dep)
    report = {'candidate': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
              'inputs': {}, 'events': [], 'status': 'RUNNING', 'direct': {}}

    def run(command, cwd, category):
        start = time.monotonic()
        process = subprocess.run(list(map(str, command)), cwd=cwd, env=env, capture_output=True)
        i = len(report['events'])
        for stream in ['stdout', 'stderr']:
            (out/f'{i:04d}.{stream}').write_bytes(getattr(process, stream))
        report['events'].append(dict(command=list(map(str, command)), category=category,
                                     seconds=time.monotonic()-start, returncode=process.returncode))
        (out/'BUILD.json').write_text(json.dumps(report, indent=2)+'\n')
        if process.returncode:
            print(process.stderr.decode(errors='replace'), process.stdout.decode(errors='replace'), flush=True)
            process.check_returncode()
        return process.stdout.decode()

    fixtures = ['tests/modularity/mod_low_air_policy_oracle.f90']
    for name, driver, marker in [
        ('incumbent-policy', 'tests/modularity/test_low_air_step_policy.f90', 'LOW_AIR_STEP_POLICY_CONTRACT=PASS'),
        ('proposal-contract', 'tests/performance/test_perf01_proposal.f90', 'PROPOSAL_EXACT_FALLBACK_ATOMIC_RESET=PASS')]:
        sources, _ = dep.strict_closure(ROOT, [driver], extra_sources=fixtures+[driver])
        for source in sources:
            report['inputs'][str(source.relative_to(ROOT))] = hashlib.sha256(source.read_bytes()).hexdigest()
        for opt in ['O0', 'O2']:
            build = out/(name+'-'+opt)
            build.mkdir()
            flags = ['-'+opt, '-std=f2008', '-ffree-line-length-none', '-fopenmp', '-fcheck=all',
                     '-fbacktrace', '-ffpe-trap=invalid,zero,overflow', '-J'+str(build), '-I'+str(build)]
            run(fc+flags+sources+['-o', build/'test'], build, 'direct_compile_link')
            stdout = run([build/'test'], build, 'direct_native')
            assert marker in stdout
            report['direct'][name+'-'+opt] = {'provider_count': len(sources), 'stdout': stdout, 'marker': marker}
    for opt, profile in [('O0', 'checked'), ('O2', 'production')]:
        run(['python', '-B', ROOT/'tools/solute/build_column.py', '--optimization', opt,
             '--build-profile', profile, '--output', out/('build-'+opt)], ROOT, 'column_build')
    report['status'] = 'DIRECT_O0_O2_AND_COLUMN_BUILDS_PASS'
    (out/'BUILD.json').write_text(json.dumps(report, indent=2)+'\n')
    print(json.dumps({'status': report['status'], 'direct': report['direct']}), flush=True)


if __name__ == '__main__':
    main()
