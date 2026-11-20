"""Independent high precision check of actual original pond chain-rule probes.

No production renderer or executable is imported or run. The complete component
source must equal the actual model source except its declared test visibility.
The pinned executed driver supplies state nonmutation/A-B-A assertions; raw rows
are checked independently against the original runoff equation at 80 digits.
"""
import argparse
from decimal import Decimal, localcontext
import hashlib
import json
from pathlib import Path
import subprocess

from ordinary_pond_evidence import read, digest, require

ROOT = Path(__file__).resolve().parents[2]
DRIVER_SOURCE = '8b40b2243dc2d5a267702de06a7f727795c94e13'


def component(root, bundle):
    root, bundle = Path(root), Path(bundle)
    q = read(root/'RESULT.json')
    require(q['status'] == 'ACTUAL_COMPLETE_ORIGINAL_ORDINARY_POND_TANGENT_COMPONENT', 'Failed component')
    limits = q.get('limits', False)
    count = 64 if limits else 40
    driver = 'test_ordinary_implicit_pond_limits.f90' if limits else 'test_ordinary_implicit_pond.f90'
    actual = q['variants']['tangent']
    path = root/'tangent'
    for name, key in [('boundtop.f90', 'actual_source_sha256'), (driver, 'driver_sha256'),
                      ('component.exe', 'executable_sha256')]:
        require(digest(path/name) == actual[key], 'Changed actual component '+name)
    normalize = lambda b: b.replace(b'\r\n', b'\n')
    pinned = subprocess.check_output(['git', 'show', DRIVER_SOURCE+':tests/nomacro_drainage/'+driver], cwd=ROOT)
    require(normalize((path/driver).read_bytes()) == normalize(pinned), 'Changed executed assertion driver')
    source = normalize((path/'boundtop.f90').read_bytes())
    anchor = b'public :: pondrunoff, q0, FlRunoff, ftoph, hsurf'
    require(source.count(anchor+b', h0max, k1max') == 1, 'Unexpected component visibility')
    require(source.replace(anchor+b', h0max, k1max', anchor, 1) ==
            normalize((bundle/'boundtop.f90').read_bytes()), 'Component differs from actual full model source')
    require(actual['original_BUILD_sha256'] == digest(bundle/'BUILD.json') and
            actual['actual_returncode'] == 0, 'Component build/original return code differs')
    lines = (path/'actual.stdout').read_text().splitlines()
    require(len(lines) == count+1 and lines[-1] == 'ACTUAL_ORIGINAL_ORDINARY_POND_CHAIN_RULE_PASS '+str(count),
            'Incomplete actual component assertion execution')
    require(not (path/'actual.stderr').read_bytes(), 'Unexpected actual component stderr')
    observed = []
    errors = []
    with localcontext() as c:
        c.prec = 80
        D = Decimal
        def flux(head, base, prime, dt, previous, rsro, exponent):
            k = 1+prime*(head-base)
            constant = previous+D('.5')*dt-k*dt+k*dt*head
            upper = constant/(1+k*dt)
            def runoff(pond):
                excess = max(D(0), pond-D('.2'))
                return excess if rsro < D('.001') else dt/rsro*excess**exponent
            lo, hi = D(0), upper
            for _ in range(280):
                mid = (lo+hi)/2
                if (1+k*dt)*mid+runoff(mid) < constant:
                    lo = mid
                else:
                    hi = mid
            pond = (lo+hi)/2
            slope = D(0) if pond <= D('.2') else (D(1) if rsro < D('.001') else
                    dt/rsro*exponent*(pond-D('.2'))**(exponent-1))
            return -k*(pond-head+1), pond, slope
        for line in lines[:-1]:
            p = line.split()
            require(len(p) == 9 and p[0] == 'ACTUAL_IMPLICIT_POND_TANGENT', 'Foreign component row')
            trial, branch, mode = map(int, p[1:4])
            observed.append((trial, branch, mode))
            partial, tangent, finite_difference, gap, fixed = map(D, p[4:])
            require(all(v.is_finite() for v in (partial, tangent, finite_difference, gap, fixed)), 'Nonfinite component')
            dt = D('.01')*(2*trial-1)
            prime = [D(0), D('.02'), D('.5'), D(2)][mode-1]
            previous, rsro, exponent, base = D('.21'), D('.02'), D(1), D(1)
            if limits:
                if branch == 2: previous, base = D('.01'), D('.5')
                if branch in (3, 4, 5, 6, 8): base = D(10)
                if branch == 3: exponent = D('1.5')
                if branch == 4: exponent = D(2)
                if branch == 5: rsro = D('.0005')
                if branch == 6: rsro = D('.001')
                if branch == 7: exponent = D('1.00000001')
                if branch == 8: exponent = D('.5')
            else:
                if branch in (2, 3): base = D('.71')
                if branch == 4: exponent, base = D('1.5'), D(10)
                if branch == 5: base = D(50)
            _, pond, slope = flux(base, base, prime, dt, previous, rsro, exponent)
            expected_partial = 1-prime*(pond-base+1)
            expected_fixed = (1+slope)/(1+dt+slope)
            expected = expected_partial*expected_fixed
            error = abs(tangent-expected)
            require(abs(partial-expected_partial) < D('1e-12') and error < D('1e-12') and
                    abs(fixed-expected_fixed) < D('1e-12'), 'Original equation derivative differs')
            require(abs(finite_difference-tangent) <= D('1e-8') and
                    float(gap) == float(finite_difference)-float(tangent), 'Actual finite difference criterion differs')
            if prime == 0: require(fixed == tangent, 'Actual exact fixed-K limit changed')
            errors.append(float(error))
    require(observed == [(t,b,m) for t in (1,2) for b in range(1,9 if limits else 6) for m in range(1,5)],
            'Component denominator/ordering differs')
    return dict(status='INDEPENDENT_ORIGINAL_POND_CHAIN_EQUATION_PASS', actual_points=count,
                decimal_digits=80, maximum_derivative_gap=max(errors),
                exact_executed_driver_source=DRIVER_SOURCE, complete_model_source_equivalent=True,
                executed_nonmutation_ABA_and_fixed_limit_assertions=True)


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('root', type=Path)
    p.add_argument('--bundle', type=Path, required=True)
    p.add_argument('--output', type=Path, required=True)
    a = p.parse_args()
    result = component(a.root, a.bundle)
    require(not a.output.exists(), 'Refuse overwriting independent component result')
    a.output.write_text(json.dumps(result, indent=2)+'\n', encoding='utf-8')
    print(json.dumps(result))
