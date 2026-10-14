"""Adapters for existing independent oracles; no production formulas here."""
import hashlib
import importlib.util
import math
import random

FVQ38 = 'tests/modularity/oracles/fvq38_dramet2_scientific.py'
CROP = 'tests/fwof/pp02/check_wofost81_assimilation_oracle.py'


def load(root, path):
    spec = importlib.util.spec_from_file_location('owning_oracle', root / path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def prepare(root, name):
    if name == 'assimilation':
        oracle = load(root, CROP)
        rows = oracle.cases()
        expected = [oracle.totass8(row) for row in rows]

        def validate(output):
            actual = [float(x) for x in output.split()]
            if len(actual) != len(expected):
                raise RuntimeError('assimilation oracle output count')
            for i, (got, want) in enumerate(zip(actual, expected)):
                if not math.isfinite(got) or abs(got-want) > 2e-11 + 2e-12*abs(want):
                    raise RuntimeError(f'assimilation oracle mismatch {i}: {got} != {want}')
            if actual[1] != 0 or actual[2] != 0 or not actual[4] < actual[0]:
                raise RuntimeError('assimilation edge contract')
        paths = [CROP]
    elif name == 'drainage':
        oracle = load(root, FVQ38)
        # Exact immutable F-VQ38 donor, not an adapted production implementation.
        data = (root / FVQ38).read_bytes()
        if hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest() != FVQ38_BLOB:
            raise RuntimeError('independent F-VQ38 oracle identity drift')
        rows = []
        for x in [0., 0.5e-6, 1e-6*(1-1e-10), 1e-6, 1e-6*(1+1e-10),
                  0.5*(1-1e-10), 0.5, 0.5*(1+1e-10), 1., 2.]:
            rows.append((100., 0., -x*100./(2*math.pi), 1.))
        rng = random.Random(3814)
        for _ in range(240):
            spacing = rng.uniform(10., 1000.)
            rows.append((spacing, 0., -rng.uniform(0., 0.5)*spacing, spacing/100.))
        expected = [(0, *oracle.eqdepth_oracle(*row)[:2]) for row in rows]
        # Invalid geometry and a finite geometry with a nonpositive logarithmic denominator.
        rows.extend([(0., 0., -1., 1.), (100., 0., 1., 1.), (100., 0., -1., 0.),
                     (100., 0., -25., 10000.)])
        expected.extend([(1, 0., 0)]*3+[(2, 0., 3)])

        def validate(output):
            lines = output.decode().splitlines()
            if len(lines) != len(expected):
                raise RuntimeError('drainage oracle output count')
            for i, (line, want) in enumerate(zip(lines, expected)):
                status, branch, depth = line.split()
                status, branch, depth = int(status), int(branch), float(depth)
                ws, wd, wb = want
                if status != ws or branch != wb or not math.isfinite(depth) or not oracle.close(depth,wd,rtol=5e-12,atol=2e-13):
                    raise RuntimeError(f'drainage oracle mismatch {i}: {line} != {want}')
        paths = [FVQ38]
    else:
        raise ValueError('unknown oracle '+name)
    payload = (str(len(rows))+'\n'+'\n'.join(' '.join(f'{x:.17g}' for x in row) for row in rows)+'\n').encode()
    return payload, validate, paths


# Populated from git at the pinned donor in the same implementation batch.
FVQ38_BLOB = 'ee8773388e15b164b049aea297bdd78b7b701eaa'
