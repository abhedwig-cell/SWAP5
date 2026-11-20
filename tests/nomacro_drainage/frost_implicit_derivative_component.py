"""Actual original Frost conductivity derivative seam; no boundary promotion."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[2]


def main():
    p = argparse.ArgumentParser(description=__doc__)
    for key in ('reference-work', 'build-root', 'output'): p.add_argument('--' + key, type=Path, required=True)
    p.add_argument('--optimization', choices=('O0', 'O2'), required=True)
    a = p.parse_args(); a.output.mkdir(); a.build_root.mkdir(exist_ok=True)
    sys.path.insert(0, str(ROOT / 'app/hybrid_water'))
    import user_prepare
    from daily_host import NO_MACRO_FP_FLAGS, no_macro_fp_profile
    sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
    q = dict(status='RUNNING', source=subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
        optimization=a.optimization, floating_point_profile=no_macro_fp_profile(), compiler=[], model_periods=0,
        boundary_jacobian_qualified=False, implicit_frost_public_admitted=False)
    def save(): (a.output / 'RESULT.json').write_text(json.dumps(q, indent=2) + '\n', encoding='utf-8')
    def run(cmd): return subprocess.run(cmd, cwd=a.build_root, capture_output=True, text=True, timeout=60)
    save()
    try:
        user_prepare.validate(a.reference_work); ref = a.reference_work / 'build'; objects = ref / 'swap-obj'
        files = sorted(p for p in objects.glob('*.o') if p.name != 'swap_main.o')
        def symbols(flag):
            result = run(['nm', '-g', flag, '--format=posix', *map(str, files)])
            result.check_returncode(); table = {}; current = None
            for line in result.stdout.splitlines():
                if line.endswith(':'): current = Path(line[:-1]); table[current] = set(); continue
                if current is not None and line.strip(): table[current].add(line.split()[0])
            assert set(table) == set(files)
            return table
        defined, undefined = symbols('--defined-only'), symbols('--undefined-only'); lookup = {}
        for path, values in defined.items():
            for value in values: lookup.setdefault(value, path)
        selected = {objects / 'MOD_MvG_functions.o'}
        while True:
            before = set(selected)
            for path in before: selected.update(lookup[s] for s in undefined[path] if s in lookup)
            if before == selected: break
        path = a.build_root / 'actual-original-MOD_MvG_functions.f90'
        path.write_bytes((ref / 'swap-selected/MOD_MvG_functions.f90').read_bytes())
        driver = Path(__file__).with_name('frost_implicit_derivative_driver.f90')
        q.update(actual_original_source_sha256=sha(path), driver_sha256=sha(driver),
            actual_original_object_closure=[dict(name=p.name, sha256=sha(p)) for p in sorted(selected)])
        flags = ['gfortran', '-' + a.optimization, '-ffree-line-length-none', '-fcheck=all', '-fimplicit-none',
            '-finit-local-zero', '-ffpe-trap=invalid,zero,overflow', *NO_MACRO_FP_FLAGS,
            '-I' + str(a.build_root), '-I' + str(objects), '-I' + str(ref / 'ttutil-obj'), '-J' + str(a.build_root)]
        obj = a.build_root / 'actual_mvg.o'; exe = a.build_root / ('actual-frost-derivative' + ('.exe' if os.name == 'nt' else ''))
        for command in [[*flags, '-c', str(path), '-o', str(obj)],
                        [*flags, str(driver), str(obj), *map(str, sorted(selected-{objects/'MOD_MvG_functions.o'})),
                         str(ref / 'ttutil-obj/libttutil.a'), '-o', str(exe)]]:
            start = time.perf_counter(); result = run(command)
            q['compiler'].append(dict(command=command, returncode=result.returncode, seconds=time.perf_counter()-start,
                stdout=result.stdout, stderr=result.stderr)); save(); result.check_returncode()
        for source in (path, driver, exe): (a.output / source.name).write_bytes(source.read_bytes())
        start = time.perf_counter(); result = run([str(exe)])
        q['native'] = dict(returncode=result.returncode, seconds=time.perf_counter()-start,
            stdout=result.stdout, stderr=result.stderr, executable_sha256=sha(exe)); save(); result.check_returncode()
        assert not result.stderr and result.stdout.count('ACTUAL_ORIGINAL_FROST_DKDH ') == 48
        q['status'] = 'ACTUAL_ORIGINAL_FROST_CONSTITUTIVE_48_DERIVATIVES_PASS_NOT_BOUNDARY_JACOBIAN_QUALIFIED'
        print(q['status'], len(selected), flush=True)
    except Exception as error:
        q.update(status='FAILED', error=repr(error)); raise
    finally: save()


if __name__ == '__main__': main()
