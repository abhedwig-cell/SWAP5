#!/usr/bin/env python3
"""Current-source preservation; historical admission guards remain unchanged."""
import hashlib, json, os, pathlib, re, shlex, subprocess, tempfile
ROOT = pathlib.Path(__file__).resolve().parents[2]
TESTS = [
    'tests/fapp/test_ppa_wu04a_black_process.f90',
    'tests/fapp/test_ppa_wu04a_black_runtime.f90',
    'tests/fapp/test_ppa_wu04b_boesten_process.f90',
    'tests/fapp/test_ppa_wu04b_boesten_runtime.f90',
    'tests/physics/test_c3a_eb_i25_current_successor.f90',
]
FC = shlex.split(os.environ.get('FC', 'gfortran'))
modules = {}
for path in sorted((ROOT / 'src').rglob('*.f90')) + [ROOT / 'tests/fsi/fsi04_real_headcalc_stubs.f90'] + [ROOT / test for test in TESTS]:
    for name in re.findall(r'^\s*module\s+(\w+)\s*$', path.read_text(), re.M | re.I):
        modules[name.lower()] = path
ordered, seen, visiting = [], set(), set()
def visit(path):
    if path in seen:
        return
    if path in visiting:
        raise RuntimeError('dependency cycle: ' + str(path))
    visiting.add(path)
    for name in re.findall(r'^\s*use\s+(?:,\s*non_intrinsic\s*::\s*)?(\w+)', path.read_text(), re.M | re.I):
        dependency = modules.get(name.lower())
        if dependency and dependency != path:
            visit(dependency)
        elif not dependency and name.lower() not in ('iso_fortran_env', 'iso_c_binding', 'ieee_arithmetic', 'omp_lib'):
            raise RuntimeError('unresolved module: ' + name)
    visiting.remove(path)
    seen.add(path)
    ordered.append(path)
visit(ROOT / 'src/legacy/b1_10_port/headcalc.f90')
for test in TESTS:
    visit(ROOT / test)
if os.environ.get('C3A_LIST_SOURCES'):
    print('\n'.join(str(path.relative_to(ROOT)) for path in ordered))
    raise SystemExit()
sources = [path for path in ordered if str(path.relative_to(ROOT)) not in TESTS]
result = {
    'work_unit': 'PPA-WU05-C3A',
    'tested_postimage': os.environ.get('C3A_TESTED_SHA', 'not-specified'),
    'compiler': subprocess.check_output(FC + ['--version'], text=True).splitlines()[0],
    'source_sha256': {str(path.relative_to(ROOT)): hashlib.sha256(path.read_bytes()).hexdigest() for path in ordered},
    'runner_sha256': hashlib.sha256(pathlib.Path(__file__).read_bytes()).hexdigest(),
    'scope': 'Existing Black/Boesten assertions and separately registered current-canonical EB-I25 successor; not historical-gate success',
    'runs': {},
}
with tempfile.TemporaryDirectory(prefix='c3a-shared-preservation-') as folder:
    for opt in ('O0', 'O2'):
        build = pathlib.Path(folder) / opt
        build.mkdir()
        flags = ['-' + opt, '-std=f2008', '-ffree-line-length-none', '-fopenmp', '-fcheck=all', '-fbacktrace',
                 '-ffpe-trap=invalid,zero,overflow', '-J' + str(build), '-I' + str(build)]
        objects = []
        for path in sources:
            obj = build / (path.stem + '.o')
            subprocess.run(FC + flags + ['-c', str(path), '-o', str(obj)], check=True)
            objects.append(str(obj))
        result['runs'][opt] = {}
        for test in TESTS:
            path = ROOT / test
            obj, exe = build / (path.stem + '.o'), build / path.stem
            subprocess.run(FC + flags + ['-c', str(path), '-o', str(obj)], check=True)
            subprocess.run(FC + flags + objects + [str(obj), '-o', str(exe)], check=True)
            completed = subprocess.run([str(exe)], text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
            print(completed.stdout, flush=True)
            completed.check_returncode()
            markers = [line for line in completed.stdout.splitlines() if '=PASS' in line or 'C3A_EBI25_OUTFLOW_OBSERVABLES' in line]
            if not markers:
                raise RuntimeError('missing preservation assertions: ' + test)
            result['runs'][opt][test] = markers
            print(opt + ' ' + test + ' PASS', flush=True)
if result['runs']['O0'] != result['runs']['O2']:
    raise RuntimeError('O0/O2 preservation outputs differ')
result['status'] = 'CURRENT_SOURCE_PRESERVATION_PASS'
pathlib.Path(os.environ.get('C3A_SHARED_RESULT', 'c3a_shared_preservation_result.json')).write_text(json.dumps(result, indent=2) + '\n')
print('C3A_SHARED_CURRENT_PRESERVATION=PASS')
