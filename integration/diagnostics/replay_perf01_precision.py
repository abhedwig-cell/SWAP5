"""Exact rational primitives, high-precision MvG and actual native-provider replay."""
import argparse
import csv
from decimal import Decimal, localcontext
from fractions import Fraction
import hashlib
import importlib.util
import json
import math
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[2]


def rows(p):
    return list(csv.DictReader(p.open()))


def high_precision(native, digits):
    data = [{k: float(v) for k, v in r.items()} for r in rows(native/'iterate.csv')]
    meta = rows(native/'solve.csv')[0]
    c = {i: {} for i in range(1, 33)}
    for r in rows(native/'coefficients.csv'):
        c[int(r['node'])][int(r['index'])] = float(r['value'])
    D = Decimal.from_float
    F = Fraction.from_float
    dt = F(float(meta['dt']))

    def total_primitives(convert, step):
        result = []
        for i, x in enumerate(data):
            z = convert(x['increment'])*convert(x['fraction'])*convert(x['dz'])/step
            z += convert(x['sink'])-convert(x['source'])+convert(x['root'])
            z -= convert(x['k_left'])*convert(x['gradient_left'])
            if i < 31:
                z += convert(x['k_right'])*convert(x['gradient_right'])
            else:
                z -= convert(float(meta['qbot']))
            result.append(z)
        return sum(result)

    assert meta['top_head'] == 'T' and meta['swkimpl'] == '0' and meta['swbotb'] == '2'
    exact = total_primitives(F, dt)
    with localcontext() as context:
        context.prec = digits
        ddt = D(float(meta['dt']))

        def increments(head):
            values = []
            for i, (h, x) in enumerate(zip(head, data), 1):
                coefficients = {k: D(v) for k, v in c[i].items()}
                assert c[i][9] > -.01 and h <= D(-.01) and x['h_previous'] <= -.01
                a, n, m, delta = [coefficients[k] for k in [4, 6, 7, 25]]
                retention = lambda y: delta*(1+(abs(a*y))**n)**(-m)
                values.append(retention(h)-retention(D(x['h_previous'])))
            return values

        def evaluate(head):
            inc = increments(head)
            gradient = [(D(float(meta['hsurf']))-head[0])/D(data[0]['distance_left'])+1]
            gradient += [(head[i-1]-head[i])/D(data[i]['distance_left'])+1 for i in range(1, 32)]
            result = []
            for i, x in enumerate(data):
                z = inc[i]*D(x['fraction'])*D(x['dz'])/ddt+D(x['sink'])-D(x['source'])+D(x['root'])
                z -= D(x['k_left'])*gradient[i]
                if i < 31:
                    z += D(x['k_right'])*gradient[i+1]
                else:
                    z -= D(float(meta['qbot']))
                result.append(z)
            return dict(total=str(sum(result)), maximum=str(max(map(abs, result))))

        frozen = evaluate([D(x['h']) for x in data])
        ideal = evaluate([D(x['h'])-D(x['newton']) for x in data])
    native_sum = sum(x['residual'] for x in data)
    return dict(digits=digits, native_sum=native_sum, compensated_sum=math.fsum(x['residual'] for x in data),
        exact_rounded_primitive_sum=str(exact.numerator)+'/'+str(exact.denominator),
        exact_rounded_primitive_sum_float=float(exact), high_precision_retention_frozen_heads=frozen,
        high_precision_retention_unrounded_newton_heads=ideal,
        maximum_newton_to_head_ulp=max(abs(x['newton'])/math.ulp(x['h']) for x in data),
        unchanged_heads_after_native_subtraction=sum(x['h']-x['newton'] == x['h'] for x in data),
        total_tolerance=float(meta['total_tolerance']))


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--capture', required=True, type=Path)
    ap.add_argument('--build', required=True, type=Path)
    ap.add_argument('--output', required=True, type=Path)
    ap.add_argument('--standalone', action='store_true', help='Fresh three-provider closure, no column objects')
    args = ap.parse_args()
    out = args.output.resolve();out.mkdir(parents=True, exist_ok=False)
    build = json.loads((args.build/'build-complete.json').read_text())
    assert all(hashlib.sha256((ROOT/p).read_bytes()).hexdigest() == h for p, h in build['input_sha256'].items())
    source = ROOT/'integration/diagnostics/perf01_precision_replay.f90'
    fc = build['compiler_command']
    flags = [f for f in build['flags'] if not f.startswith(('-I', '-J'))]+['-J'+str(out), '-I'+str(out)]
    if not args.standalone:
        flags += ['-I'+str(args.build)]
    objects = [e['command'][e['command'].index('-o')+1] for e in build['events'] if e['category'] == 'compile'
        and not e['command'][e['command'].index('-c')+1].endswith('/app/solute_column/main.f90')]
    fresh_sources = []
    if args.standalone:
        spec = importlib.util.spec_from_file_location('closure',ROOT/'tests/support/augment_bartholomeus_backend_sources.py')
        closure = importlib.util.module_from_spec(spec);spec.loader.exec_module(closure)
        driver = str(source.relative_to(ROOT))
        fresh_sources,_ = closure.strict_closure(ROOT,[driver],extra_sources=[driver])
        objects = []
    command = fc+flags+([str(p) for p in fresh_sources] if fresh_sources else [str(source)])+objects+['-o', str(out/'replay')]
    with (out/'build.log').open('w') as log:
        subprocess.run(command, stdout=log, stderr=log, check=True)
    native = args.capture.resolve()/'native'
    with (out/'stdout').open('w') as so, (out/'stderr').open('w') as se:
        result = subprocess.run([str(out/'replay'), str(native)], cwd=out, stdout=so, stderr=se, timeout=10)
    report = dict(status='INCOMPLETE', source_sha256=hashlib.sha256(source.read_bytes()).hexdigest(),
        fresh_closure_sha256={str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest() for p in fresh_sources},
        compiler_command=command, returncode=result.returncode,
        input_sha256={p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in native.glob('*.csv')},
        linked_object_sha256={p: hashlib.sha256(Path(p).read_bytes()).hexdigest() for p in objects})
    (out/'REPLAY.json').write_text(json.dumps(report, indent=2)+'\n')
    result.check_returncode()
    report['arithmetic'] = [high_precision(native, d) for d in [80, 120]]
    report['status'] = 'ISOLATED_RESIDUAL_REPLAY_NOT_PRODUCTION_CORRECTION'
    (out/'REPLAY.json').write_text(json.dumps(report, indent=2)+'\n')
    print(json.dumps(report['arithmetic'], indent=2))


if __name__ == '__main__':
    main()
