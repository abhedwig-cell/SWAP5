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
    ap.add_argument('--root', type=Path, default=Path(__file__).resolve().parents[1])
    ap.add_argument('--build', type=Path, required=True)
    args = ap.parse_args()
    root, build = args.root.resolve(), args.build.resolve()
    build.mkdir(parents=True, exist_ok=True)
    stub = root / 'tests/fsi/fsi04_real_headcalc_stubs.f90'
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
    visit(root / 'tests/fgc/strip01/test_production_domain_guard.f90')
    fc = shlex.split(os.environ.get('FC', 'gfortran'))
    flags = ['-O2', '-std=f2008', '-ffree-line-length-none', '-fopenmp', '-fcheck=all',
             '-fbacktrace', '-ffpe-trap=invalid,zero,overflow', '-J' + str(build), '-I' + str(build)]
    flags += shlex.split(os.environ.get('FFLAGS', ''))
    objects, manifest = [], {}
    for p in ordered:
        b = p.read_bytes()
        manifest[str(p.relative_to(root))] = hashlib.sha1(b'blob ' + str(len(b)).encode() + b'\0' + b).hexdigest()
        obj = build / (p.stem + '.o')
        subprocess.run(fc + flags + ['-c', str(p), '-o', str(obj)], check=True)
        objects.append(str(obj))
    exe = build / 'domain_guard'
    subprocess.run(fc + flags + objects + ['-o', str(exe)], check=True)
    result = subprocess.run([str(exe)], capture_output=True, text=True, check=True)
    (build / 'execution.log').write_text(result.stdout + result.stderr)
    required = ['STRIP01_MODFLOW_DRAIN_TOPOLOGY=PASS', 'STRIP01_PRODUCTION_DRAIN_GUARD=PASS',
                'STRIP01_PRODUCTION_STORAGE_GUARD=PASS', 'PPA-WU01 PRODUCTION APPLICATION BOOTSTRAP GATE PASS']
    assert all(marker in result.stdout for marker in required)
    (build / 'result.json').write_text(json.dumps(dict(state='AUTHORITY_GUARD_PASS',
        optimization='O2', required_markers=required, source_git_blobs=manifest,
        real_coupled_run=False, canonical_admission=False), indent=2) + '\n')
    print(result.stdout)


if __name__ == '__main__':
    main()
