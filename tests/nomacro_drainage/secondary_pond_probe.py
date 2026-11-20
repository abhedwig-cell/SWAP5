"""Exercise complete original MOD_top on each side of the pond switch."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess

from secondary_pond_forensics import boundtop, NEW, OLD


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for key in ('profile', 'provider', 'build-root', 'output'):
        parser.add_argument('--'+key, type=Path, required=True)
    args = parser.parse_args()
    q = json.loads((args.profile/'RESULT.json').read_text())
    original = Path(q['build_root'])
    meta = json.loads((original/'BUILD.json').read_text())
    boundtop((original/'boundtop.f90').read_bytes())
    objects = args.provider/'build/swap-obj'
    ttutil = args.provider/'build/ttutil-obj'
    driver = Path(__file__).with_name('test_secondary_pond_switch.f90')
    args.output.mkdir()
    results = {}
    for variant in ('original', 'zero'):
        build = args.build_root/variant
        build.mkdir(parents=True)
        out = args.output/variant
        out.mkdir()
        for path in original.iterdir():
            if path.suffix.lower() in ('.o', '.mod', '.smod', '.f90', '.dll', '.so'):
                shutil.copyfile(path, build/path.name)
        top = build/'boundtop.f90'
        if variant == 'original':
            text = top.read_text(encoding='cp1252')
            top.write_text(text.replace(NEW, OLD, 1), encoding='cp1252')
        known = {p.name for p in objects.glob('*.o')}
        actual = [build/p.name if (build/p.name).exists() else p
                  for p in sorted(objects.glob('*.o')) if p.name != 'swap_main.o']
        actual += [p for p in sorted(build.glob('*.o')) if p.name not in known]
        flags = ['gfortran', *meta['identity']['donor_flags'], '-I', str(build),
                 '-I', str(objects), '-I', str(ttutil)]
        exe = build/'component.exe'
        commands = [flags+['-c', 'boundtop.f90'],
                    flags+[str(driver), *map(str, actual), str(ttutil/'libttutil.a'),
                           '-o', str(exe)]]
        logs = []
        for command in commands:
            run = subprocess.run(command, cwd=build, capture_output=True, text=True, timeout=60)
            logs.append(dict(command=command, returncode=run.returncode,
                             stdout=run.stdout, stderr=run.stderr))
            (out/'COMPILATION.json').write_text(json.dumps(logs, indent=2))
            run.check_returncode()
        run = subprocess.run([str(exe)], cwd=build, capture_output=True, text=True, timeout=30)
        (out/'actual.stdout').write_text(run.stdout)
        (out/'actual.stderr').write_text(run.stderr)
        run.check_returncode()
        for path in (top, driver, exe):
            shutil.copyfile(path, out/path.name)
        results[variant] = dict(actual_source_sha256=sha(top), driver_sha256=sha(driver),
                                executable_sha256=sha(exe), actual_cases=len(run.stdout.splitlines()),
                                original_BUILD_sha256=sha(original/'BUILD.json'),
                                compiled_objects={p.name: sha(p) for p in actual},
                                ttutil_sha256=sha(ttutil/'libttutil.a'))
    (args.output/'RESULT.json').write_text(json.dumps(dict(
        status='ACTUAL_COMPLETE_ORIGINAL_SECONDARY_POND_SWITCH_COMPONENTS',
        qualification=False, variants=results), indent=2))
    print('ACTUAL_COMPLETE_ORIGINAL_SECONDARY_POND_SWITCH_COMPONENTS')


if __name__ == '__main__':
    main()
