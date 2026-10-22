#!/usr/bin/env python3
"""Build the opt-in native crop column from real production providers."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shlex
import subprocess
import time

ROOT = Path(__file__).resolve().parents[2]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    global ROOT
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source-tree', type=Path, default=ROOT,
                        help='Explicit immutable comparator checkout; uses the same builder and compiler policy')
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--optimization', choices=['O0', 'O2'], default='O2')
    parser.add_argument('--build-profile', choices=['checked', 'production'], default='checked',
                        help='Production omits compiler bounds/shape checks; physical and numerical guards remain active')
    parser.add_argument('--gprof', action='store_true', help='Diagnostic instrumentation; excluded from speed comparisons')
    args = parser.parse_args()
    ROOT = args.source_tree.resolve()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    fc = shlex.split(os.environ.get('FC', 'gfortran'))
    context = ROOT / 'app/solute_column/link_context.f90'
    driver = ROOT / 'app/solute_crop/main.f90'
    headcalc = ROOT / 'src/legacy/b1_10_port/headcalc.f90'
    # Original input providers are isolated in an archive: only referenced
    # TTUTIL objects are linked, avoiding unrelated legacy physics providers.
    from legacy_reader_sources import materialize
    original, ttutil = materialize(ROOT, output)
    generated_inputs = [original] + sorted(p for p in ttutil[0].parent.rglob('*') if p.is_file())
    sources = list((ROOT / 'src').rglob('*.f90')) + list((ROOT / 'app/solute_column').glob('*.f90')) + [original]
    mapping = {}
    for source in sources:
        for name in re.findall(r'^\s*module\s+(\w+)\s*$', source.read_text(), re.M | re.I):
            key = name.lower()
            if key in mapping:
                raise ValueError(f'duplicate module {key}: {source} / {mapping[key]}')
            mapping[key] = source
    ordered, seen, active = [], set(), set()

    def visit(source):
        if source in seen:
            return
        if source in active:
            raise ValueError(f'provider cycle at {source}')
        active.add(source)
        for name in re.findall(r'^\s*use\s*(?:,\s*(?:non_)?intrinsic\s*::\s*|::\s*)?(\w+)',
                               source.read_text(), re.M | re.I):
            name = name.lower()
            if name in {'iso_fortran_env', 'iso_c_binding', 'ieee_arithmetic', 'ieee_exceptions', 'omp_lib'}:
                continue
            provider = mapping[name]
            if provider != source:
                visit(provider)
        active.remove(source)
        seen.add(source)
        ordered.append(source)

    visit(driver)
    ordered.remove(driver)
    visit(headcalc)
    ordered.append(driver)
    flags = ['-' + args.optimization, '-std=f2008', '-ffree-line-length-none', '-fopenmp',
             '-fbacktrace', '-ffpe-trap=invalid,zero,overflow',
             '-J' + str(output), '-I' + str(output)]
    if args.gprof:
        flags.append('-pg')
    if args.build_profile == 'checked':
        flags.append('-fcheck=all')
    report = {'build_profile': args.build_profile, 'schema': 1, 'candidate': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
              'compiler': subprocess.check_output(fc + ['--version'], text=True).splitlines()[0],
              'compiler_command': fc, 'flags': flags, 'input_sha256': {str(p.relative_to(ROOT)): sha(p) for p in ordered if p.is_relative_to(ROOT)},
              'generated_input_sha256': {str(p.relative_to(output)): sha(p) for p in generated_inputs},
              'events': [], 'status': 'BUILDING'}

    def run(command, category):
        start = time.perf_counter()
        result = subprocess.run(list(map(str, command)), cwd=output, capture_output=True)
        event = {'command': list(map(str, command)), 'category': category,
                 'seconds': time.perf_counter() - start, 'returncode': result.returncode}
        index = len(report['events'])
        for stream in ['stdout', 'stderr']:
            name = f'{index:04d}.{stream}'
            (output / name).write_bytes(getattr(result, stream))
            event[stream] = name
        report['events'].append(event)
        (output / 'build.json').write_text(json.dumps(report, indent=2) + '\n')
        result.check_returncode()

    for path in [ROOT / 'tools/solute/legacy_reader_sources.py',
                 ROOT / 'tools/solute/build_crop_column.py',
                 ROOT / 'integration/audits/evidence/SWAP431_B111_AUTHORITY.tar.gz.b64',
                 ROOT / 'integration/audits/evidence/SWAP431_TTUTIL_AUTHORITY.zip.b64']:
        report['input_sha256'][str(path.relative_to(ROOT))] = sha(path)
    legacy_flags = [f for f in flags if f != '-std=f2008'] + [
        '-std=legacy', '-fallow-argument-mismatch', '-ffixed-line-length-none']
    ttobjects = []
    for index, source in enumerate(ttutil):
        obj = output / f'tt{index:04d}.o'
        run(fc + legacy_flags + ['-c', source, '-o', obj], 'compile-original-input')
        ttobjects.append(obj)
    archive = output / 'libttutil.a'
    run(['ar', 'rcs', archive] + ttobjects, 'archive-original-input')
    objects = []
    for index, source in enumerate(ordered):
        obj = output / f'{index:04d}.o'
        run(fc + (legacy_flags if source == original else flags) + ['-c', source, '-o', obj], 'compile')
        objects.append(obj)
    exe = output / 'swap5_solute_column'
    run(fc + flags + objects + [archive, '-o', exe], 'link')
    if any(sha(ROOT / p) != h for p, h in report['input_sha256'].items()):
        raise RuntimeError('build input changed during compilation')
    if any(sha(output / p) != h for p, h in report['generated_input_sha256'].items()):
        raise RuntimeError('generated original source changed during compilation')
    report.update(original_input_provider_count=len(ttutil), status='BUILT', executable_sha256=sha(exe), provider_count=len(ordered))
    (output / 'build-complete.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps({k: report[k] for k in ['status', 'provider_count', 'executable_sha256']}))


if __name__ == '__main__':
    main()
