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
    ap.add_argument('--profile', choices=['C0','C1'], default='C0')
    ap.add_argument('--root', type=Path, default=Path(__file__).resolve().parents[1])
    ap.add_argument('--build', type=Path, required=True)
    ap.add_argument('--context-override', type=Path, help='Use an isolated research fixture instead of the tests-tree context.')
    args = ap.parse_args()
    root, build = args.root.resolve(), args.build.resolve()
    build.mkdir(parents=True, exist_ok=True)
    stub = root / ('tests/fgc/strip01/research_grid_stubs.f90' if args.profile == 'C0' else 'tests/fgc/strip01/research_grid_stubs_c1.f90')
    files = list((root / 'src').rglob('*.f90')) + [stub]
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

    visit(root / 'src/legacy/b1_10_port/headcalc.f90')
    context = args.context_override.resolve() if args.context_override else root / (
        'tests/fgc/strip01/research_context.f90' if args.profile == 'C0' else 'tests/fgc/strip01/research_context_c1.f90')
    visit(context)
    visit(root / 'src/adapter/mod_fmr_groundwater_application_c_api.f90')
    visit(root / 'src/adapter/mod_modflow6_fgc34_c_bridge.f90')
    fc = shlex.split(os.environ.get('FC', 'gfortran'))
    flags = ['-fPIC', '-O2', '-std=f2008', '-ffree-line-length-none', '-fopenmp', '-fcheck=all',
             '-fbacktrace', '-ffpe-trap=invalid,zero,overflow', '-J' + str(build), '-I' + str(build)]
    flags += shlex.split(os.environ.get('FFLAGS', ''))
    objects, manifest = [], {}
    for p in ordered:
        b = p.read_bytes()
        manifest[str(p.relative_to(root))] = hashlib.sha1(b'blob ' + str(len(b)).encode() + b'\0' + b).hexdigest()
        obj = build / (p.stem + '.o')
        subprocess.run(fc + flags + ['-c', str(p), '-o', str(obj)], check=True)
        objects.append(str(obj))
    exe = build / 'libstrip01_research.so'
    subprocess.run(fc + flags + objects + ['-shared', '-o', str(exe)], check=True)
    (build / 'source_git_blobs.json').write_text(json.dumps(manifest, indent=2))
    return


if __name__ == '__main__':
    main()
