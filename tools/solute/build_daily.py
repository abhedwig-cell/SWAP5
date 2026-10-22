#!/usr/bin/env python3
"""Build the independent native daily MET adapter with original TTUTIL."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shlex
import subprocess
import time
from legacy_reader_sources import materialize

ROOT = Path(__file__).resolve().parents[2]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--optimization', choices=['O0', 'O2'], required=True)
    args = parser.parse_args()
    out = args.output.resolve()
    out.mkdir(parents=True, exist_ok=False)
    fc = shlex.split(os.environ.get('FC', 'gfortran'))
    _, providers = materialize(ROOT, out)
    driver = ROOT / 'app/solute_column/read_swp_daily.f90'
    inputs = [driver, Path(__file__), ROOT / 'tools/solute/legacy_reader_sources.py',
              ROOT / 'integration/audits/evidence/SWAP431_B111_AUTHORITY.tar.gz.b64',
              ROOT / 'integration/audits/evidence/SWAP431_TTUTIL_AUTHORITY.zip.b64']
    flags = ['-' + args.optimization, '-fcheck=all', '-fbacktrace',
             '-ffpe-trap=invalid,zero,overflow', '-ffree-line-length-none',
             '-J' + str(out), '-I' + str(out)]
    report = {'status': 'BUILDING', 'candidate': subprocess.check_output(
        ['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
        'compiler_command': fc, 'flags': flags, 'compiler': subprocess.check_output(
            fc + ['--version'], text=True).splitlines()[0],
        'input_sha256': {str(p.relative_to(ROOT)): sha(p) for p in inputs},
        'generated_input_sha256': {str(p.relative_to(out)): sha(p)
                                   for p in sorted(providers[0].parent.rglob('*')) if p.is_file()},
        'events': [], 'application_providers': 1, 'original_input_providers': len(providers)}

    def run(command, category):
        start = time.perf_counter()
        result = subprocess.run(list(map(str, command)), cwd=out, capture_output=True)
        index = len(report['events'])
        for stream in ['stdout', 'stderr']:
            (out / f'{index:04d}.{stream}').write_bytes(getattr(result, stream))
        report['events'].append({'command': list(map(str, command)), 'category': category,
                                 'returncode': result.returncode, 'seconds': time.perf_counter() - start})
        (out / 'build.json').write_text(json.dumps(report, indent=2) + '\n')
        result.check_returncode()

    objects = []
    for index, provider in enumerate(providers):
        obj = out / f'tt{index:04d}.o'
        run(fc + flags + ['-std=legacy', '-ffixed-line-length-none', '-fallow-argument-mismatch',
                         '-c', provider, '-o', obj], 'compile-original-input')
        objects.append(obj)
    library = out / 'libttutil.a'
    run(['ar', 'rcs', library] + objects, 'archive')
    exe = out / 'swap5_read_daily'
    run(fc + flags + ['-std=f2008', driver, library, '-o', exe], 'compile-link-adapter')
    assert all(sha(ROOT / p) == h for p, h in report['input_sha256'].items())
    assert all(sha(out / p) == h for p, h in report['generated_input_sha256'].items())
    report.update(status='BUILT', executable_sha256=sha(exe))
    (out / 'build-complete.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps({'status': 'BUILT', 'executable_sha256': sha(exe)}))


if __name__ == '__main__':
    main()
