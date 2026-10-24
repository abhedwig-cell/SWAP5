"""Small real-provider predecessor discrimination and unchanged FSI35 native body."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[2]
BASE = '367c11e394e3f166f861d9f1502aaeeda01215d7'
HEAD = 'src/legacy/b1_10_port/headcalc.f90'
DRIVER = 'tests/fsi/test_picard_corner_restart.f90'
FIXTURES = {
    'tests/fsi/data/picard_corner_1x.dat': '5c7b83dd13218b24a5cdde6f347f3acff20736332b1bad5d7523b1a482411b21',
    'tests/fsi/data/picard_corner_4x.dat': '05e9558ccc00aa2d73dca69128a3bd6b9a4f2662b28deae475670ceb44470a75',
}
CASES = [('picard_corner_1x', 1, 1), ('picard_corner_4x', 1, 2),
         ('picard_corner_4x', 8, 1), ('picard_corner_4x', 16, 1)]


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--output', type=Path, required=True)
    a = ap.parse_args()
    out = a.output.resolve()
    out.mkdir(parents=True, exist_ok=False)
    fc = os.environ.get('FC', 'gfortran')
    events, outputs = [], {}
    sha = lambda b: hashlib.sha256(b).hexdigest()

    def run(cmd, label, cwd=out):
        cmd = list(map(str, cmd))
        t = time.perf_counter()
        p = subprocess.run(cmd, cwd=cwd, capture_output=True, timeout=120)
        (out / (label + '.stdout')).write_bytes(p.stdout)
        (out / (label + '.stderr')).write_bytes(p.stderr)
        events.append(dict(label=label, command=cmd, returncode=p.returncode, seconds=time.perf_counter() - t))
        (out / 'events.json').write_text(json.dumps(events, indent=2) + '\n')
        assert p.returncode == 0, p.stdout.decode() + p.stderr.decode()
        return p.stdout.decode()

    for p, h in FIXTURES.items():
        assert sha((ROOT / p).read_bytes()) == h
    sources = subprocess.check_output([sys.executable, '-B', str(ROOT / 'tests/support/augment_bartholomeus_backend_sources.py'),
        '--all', 'tests/fsi/fsi04_real_headcalc_stubs.f90', 'src/adapter/mod_reference_richards_legacy_binding.f90',
        'src/adapter/mod_b110_dynamic_top_boundary_solver_adapter.f90', HEAD], cwd=ROOT, text=True).splitlines()
    old = out / 'old_headcalc.f90'
    old.write_bytes(subprocess.check_output(['git', 'show', BASE + ':' + HEAD], cwd=ROOT))
    for opt in ['O0', 'O2']:
        b = out / opt
        b.mkdir()
        flags = ['-' + opt, '-std=f2008', '-ffree-line-length-none', '-fopenmp', '-fcheck=all',
                 '-fbacktrace', '-ffpe-trap=invalid,zero,overflow', '-J' + str(b), '-I' + str(b)]
        objects = []
        for i, source in enumerate(sources):
            if source == HEAD:
                continue
            obj = b / (str(i) + '.o')
            run([fc, *flags, '-c', ROOT / source, '-o', obj], opt + '-compile-' + str(i))
            objects.append(obj)
        for arm, head in [('old', old), ('current', ROOT / HEAD)]:
            exe = b / arm
            run([fc, *flags, head, ROOT / DRIVER, *objects, '-o', exe], opt + '-' + arm + '-link')
            for fixture, divisor, expected in CASES:
                tag = opt + '-' + arm + '-' + fixture + '-div' + str(divisor)
                outputs[tag] = run([exe, ROOT / ('tests/fsi/data/' + fixture + '.dat'),
                                   '2' if arm == 'old' else str(expected), divisor], tag)
        for fixture, divisor, expected in CASES:
            tail = lambda s: s[s.index(' CORNER_CASE           2'):]
            # Excluded plain-K, frozen-K and Cauchy cases retain the exact old body.
            suffix = fixture + '-div' + str(divisor)
            assert tail(outputs[opt + '-old-' + suffix]) == tail(outputs[opt + '-current-' + suffix])
    for arm in ['old', 'current']:
        for fixture, divisor, expected in CASES:
            suffix = fixture + '-div' + str(divisor)
            assert outputs['O0-' + arm + '-' + suffix] == outputs['O2-' + arm + '-' + suffix]
    runner = 'tests/fci/run_fci93_non_m1_fixed_k_qualification.sh'
    text = (ROOT / runner).read_text()
    start = text.index('\nFKT15_DONOR=48336', text.index("echo 'FCI93_SUCCESSOR_LINEAGE=PASS'"))
    native = text[start:].replace('trap \'rm -rf "$BUILD"\' EXIT', '', 1)
    preamble = '#!/bin/bash\nset -euo pipefail\ncd ' + str(ROOT) + '\nfail(){ echo "$*" >&2; exit 93; }\nBASE=d8414c1ba11bee9f061622fd2495f631a57d2383\nOWNER_SOURCE=5898e6616dbb6871a9f52d489038235ba1172cae\n'
    script = out / 'fsi35-native.sh'
    script.write_text(preamble + native)
    result = run(['/bin/bash', script], 'fsi35-native', ROOT)
    assert 'FCI93_FIXED_K_NATIVE_IMMUTABLE_ORACLE_O0_O2=PASS' in result
    inputs = set(sources) | set(FIXTURES) | {DRIVER, runner, str(Path(__file__).relative_to(ROOT))}
    r = dict(status='PICARD_CORNER_REAL_PREDECESSOR_O0_O2_FSI35_NATIVE_PASS', baseline=BASE,
             provider_closure=len(sources), events=events, outputs=outputs,
             input_sha256={p: sha((ROOT / p).read_bytes()) for p in sorted(inputs)},
             fsi35_scope='Original native body; moving-source owning admission requires the current successor record')
    (out / 'RESULT.json').write_text(json.dumps(r, indent=2) + '\n')
    print(r['status'])


if __name__ == '__main__':
    main()
