"""Compile the STRIP01 authority guard against repository sources, locally."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shlex
import subprocess


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--profile', choices=['C0','C1','C2'], default='C0')
    ap.add_argument('--root', type=Path, default=Path(__file__).resolve().parents[1])
    ap.add_argument('--build', type=Path, required=True)
    ap.add_argument('--context-override', type=Path, help='Use an isolated research fixture instead of the tests-tree context.')
    ap.add_argument('--source-override', action='append', default=[], metavar='REPO_PATH=FILE',
                    help='Compile an isolated source replacement for instrumentation; never edits src/.')
    args = ap.parse_args()
    root, build = args.root.resolve(), args.build.resolve()
    build.mkdir(parents=True, exist_ok=True)
    source_overrides = {}
    for item in args.source_override:
        if '=' not in item:
            ap.error('--source-override must be REPO_PATH=FILE')
        relative, replacement = item.split('=', 1)
        relative = Path(relative)
        original = (root / relative).resolve()
        if not original.is_relative_to(root) or not original.is_file():
            ap.error(f'invalid source override target: {relative}')
        source_overrides[original] = Path(replacement).resolve()
        if not source_overrides[original].is_file():
            ap.error(f'source override file does not exist: {replacement}')
    stub = root / ('tests/fgc/strip01/research_grid_stubs.f90' if args.profile == 'C0' else 'tests/fgc/strip01/research_grid_stubs_c1.f90')
    source_files = list((root / 'src').rglob('*.f90'))
    files = [source_overrides.get(p.resolve(), p) for p in source_files] + [stub]
    modules = {}
    for p in files:
        for n in re.findall(r'^\s*module\s+(\w+)\s*$', p.read_text(), re.M | re.I):
            modules[n.lower()] = p
    ordered, seen, visiting = [], set(), set()

    def visit(p):
        if p in seen:
            return
        if p in visiting:
            raise RuntimeError('module cycle: ' + str(p))
        visiting.add(p)
        for n in re.findall(r'^\s*use\s+(?:,\s*non_intrinsic\s*::\s*)?(\w+)', p.read_text(), re.M | re.I):
            q = modules.get(n.lower())
            if q and q != p:
                visit(q)
            elif not q and n.lower() not in ('iso_fortran_env', 'iso_c_binding', 'ieee_arithmetic', 'omp_lib'):
                raise RuntimeError('missing module: ' + n)
        visiting.remove(p)
        seen.add(p)
        ordered.append(p)

    def selected_source(relative):
        original = (root / relative).resolve()
        return source_overrides.get(original, original)

    visit(root / 'src/legacy/b1_10_port/headcalc.f90')
    context = args.context_override.resolve() if args.context_override else root / (
        'tests/fgc/strip01/research_context.f90' if args.profile == 'C0' else 'tests/fgc/strip01/research_context_c1.f90' if args.profile == 'C1' else 'tests/fgc/strip01/research_context_c2.f90')
    visit(context)
    visit(selected_source(Path('src/adapter/mod_fmr_groundwater_application_c_api.f90')))
    visit(root / 'src/adapter/mod_modflow6_fgc34_c_bridge.f90')
    fc = shlex.split(os.environ.get('FC', 'gfortran'))
    flags = ['-fPIC', '-O2', '-std=f2008', '-ffree-line-length-none', '-fopenmp', '-fcheck=all',
             '-fbacktrace', '-ffpe-trap=invalid,zero,overflow', '-J' + str(build), '-I' + str(build)]
    flags += shlex.split(os.environ.get('FFLAGS', ''))
    objects, manifest = [], {}
    for p in ordered:
        b = p.read_bytes()
        try:
            manifest_path = str(p.relative_to(root))
        except ValueError:
            manifest_path = 'research_override/' + p.name
        manifest[manifest_path] = hashlib.sha1(b'blob ' + str(len(b)).encode() + b'\0' + b).hexdigest()
        obj = build / (p.stem + '.o')
        subprocess.run(fc + flags + ['-c', str(p), '-o', str(obj)], check=True)
        objects.append(str(obj))
    exe = build / 'libstrip01_research.so'
    subprocess.run(fc + flags + objects + ['-shared', '-o', str(exe)], check=True)
    (build / 'source_git_blobs.json').write_text(json.dumps(manifest, indent=2))
    override_record = {}
    for original, replacement in source_overrides.items():
        original_bytes, replacement_bytes = original.read_bytes(), replacement.read_bytes()
        override_record[str(original.relative_to(root))] = {
            'canonical_source_git_blob': hashlib.sha1(
                b'blob ' + str(len(original_bytes)).encode() + b'\0' + original_bytes
            ).hexdigest(),
            'research_override_sha256': hashlib.sha256(replacement_bytes).hexdigest(),
            'research_override_path': str(replacement),
        }
    (build / 'research_source_overrides.json').write_text(json.dumps(override_record, indent=2))
    return


if __name__ == '__main__':
    main()
