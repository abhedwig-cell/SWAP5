#!/usr/bin/env python3
"""Replay the unchanged F-VQ87 oracle on the current production closure.

The historical admission runner and its historical scope locks stay intact.
This route records current-source module evidence, not historical admission.
"""
from pathlib import Path
import argparse
import hashlib
import importlib.util
import json
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[2]
OWNER = '1da854e4dd2d45fe388ee2a1ef3bd67c76d3d73f'
DRIVER = 'tests/qualification/fvq87/test_fvq87_fgc25_multiswap_independent.f90'
DRIVER_BLOB = '338416575b1583152acc65cd606c4322a20dd94d'
ORACLE_SHA256 = 'de9a811ebb3a85bf14c440350fb730b0fab8f576c06683f1265757669542d9d8'
FLAGS = ['-std=f2008', '-ffree-line-length-none', '-Wall', '-Wextra', '-Werror',
         '-Wno-error=compare-reals', '-fcheck=all', '-fbacktrace',
         '-ffpe-trap=invalid,zero,overflow']


def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT, text=True).strip()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True,
                        help='new directory for commands, identities and raw logs')
    args = parser.parse_args()
    out = args.output.resolve()
    out.mkdir(parents=True, exist_ok=False)
    assert not git('status', '--porcelain', '--', 'src', DRIVER)
    assert git('hash-object', DRIVER) == DRIVER_BLOB
    spec = importlib.util.spec_from_file_location(
        'dependencies', ROOT / 'tests/support/augment_bartholomeus_backend_sources.py')
    dependencies = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(dependencies)
    # strict_closure requires generated module providers inside the repository.
    staging = ROOT / 'build'
    staging.mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='fvq87-current-', dir=staging) as temporary:
        fixture = Path(temporary) / 'fgc21_fixture.f90'
        original = subprocess.check_output(['git', 'show', OWNER +
            ':tests/fgc/test_fgc21_restricted_predictor_corrector_window.f90'], cwd=ROOT)
        marker = b'\nprogram test_fgc21_restricted_predictor_corrector_window\n'
        assert original.count(marker) == 1
        fixture.write_bytes(original.split(marker)[0] + b'\n')
        (out / 'fgc21_fixture.f90').write_bytes(fixture.read_bytes())
        sources, direct = dependencies.strict_closure(ROOT, [ROOT / DRIVER],
            [fixture, ROOT / 'tests/fgc/mod_fgc25_multiswap_fixture.f90'])
        record = {'head': git('rev-parse', 'HEAD'),
                  'source_tree': git('rev-parse', 'HEAD:src'),
                  'fixture_owner': OWNER, 'driver_blob': DRIVER_BLOB,
                  'dependency_blobs': {str(p.relative_to(ROOT)): git('hash-object', str(p))
                                       for p in sources if p != fixture},
                  'fixture_sha256': hashlib.sha256(fixture.read_bytes()).hexdigest(),
                  'direct_dependencies': direct, 'records': [], 'status': 'RUNNING'}
        for opt in (0, 2):
            build = out / f'o{opt}'
            build.mkdir()
            cmd = ['gfortran', *FLAGS, f'-O{opt}', '-J', str(build), '-I', str(build),
                   *map(str, sources), '-o', str(build / 'oracle')]
            start = time.monotonic()
            compile_result = subprocess.run(cmd, cwd=build, capture_output=True)
            compile_seconds = time.monotonic() - start
            (build / 'compiler.stdout').write_bytes(compile_result.stdout)
            (build / 'compiler.stderr').write_bytes(compile_result.stderr)
            assert compile_result.returncode == 0, compile_result.stderr[-2000:]
            warnings = [line for line in compile_result.stderr.splitlines()
                        if b'Warning:' in line and b'[-Wcompare-reals]' not in line]
            assert not warnings, warnings
            start = time.monotonic()
            result = subprocess.run([str(build / 'oracle')], cwd=build, capture_output=True)
            run_seconds = time.monotonic() - start
            (build / 'output.stdout').write_bytes(result.stdout)
            (build / 'output.stderr').write_bytes(result.stderr)
            digest = hashlib.sha256(result.stdout).hexdigest()
            assert result.returncode == 0, result.stderr
            assert digest == ORACLE_SHA256, 'independent oracle output drift'
            record['records'].append({'opt': opt, 'command': cmd,
                'compile_seconds': compile_seconds, 'run_seconds': run_seconds,
                'compile_exit': compile_result.returncode, 'run_exit': result.returncode,
                'exe_sha256': hashlib.sha256((build / 'oracle').read_bytes()).hexdigest(),
                'stdout_sha256': digest})
            (out / 'CONTROL.json').write_text(json.dumps(record, indent=2) + '\n')
            print(f'FVQ87_CURRENT_PRODUCTION_O{opt}=PASS', flush=True)
        assert git('rev-parse', 'HEAD:src') == record['source_tree']
        record['status'] = 'PASS'
        (out / 'CONTROL.json').write_text(json.dumps(record, indent=2) + '\n')
    print('FVQ87_UNCHANGED_CURRENT_ORACLE_O0_O2_IDENTITY=PASS')


if __name__ == '__main__':
    main()
