"""Independent Decimal reference for complete ordinary MOD_top observations."""
from decimal import Decimal, localcontext
import hashlib
import json
from pathlib import Path

from implicit_conductivity_forensics import require

ORIGINAL_HISTORY_TOP = 'e82dbca07c8676b7b2a1f29d57ddb320dbdf5187baeb7c3a0254431e57315664'
OLD = b'      if (h0 <= 1.0d-6) then'
NEW = b'      if (h0 <= 0.0d0) then'


def component(root):
    root = Path(root)
    record = json.loads((root/'RESULT.json').read_text())
    require(record['status'] == 'ACTUAL_COMPLETE_ORIGINAL_ORDINARY_POND_SWITCH_COMPONENTS',
            'Incomplete actual ordinary MOD_top components')
    results = {}
    drivers = []
    for variant in ('original', 'zero'):
        path = root/variant
        q = record['variants'][variant]
        for name, key in [('boundtop.f90', 'actual_source_sha256'),
                          ('test_ordinary_pond_switch.f90', 'driver_sha256'),
                          ('component.exe', 'executable_sha256')]:
            require(hashlib.sha256((path/name).read_bytes()).hexdigest() == q[key],
                    'Changed actual ordinary component bytes')
        drivers.append((path/'test_ordinary_pond_switch.f90').read_bytes())
        source = (path/'boundtop.f90').read_bytes().replace(b'\r\n', b'\n')
        if variant == 'zero':
            require(source.count(NEW) == 1 and OLD not in source, 'Foreign corrected ordinary switch')
            source = source.replace(NEW, OLD, 1)
        require(hashlib.sha256(source).hexdigest() == ORIGINAL_HISTORY_TOP,
                'Actual ordinary top differs beyond one reference correction')
        points = [line.split() for line in (path/'actual.stdout').read_text().splitlines()]
        require(len(points) == q['actual_cases'] == 108 and
                [tuple(map(int, p[1:4])) for p in points] ==
                [(m, t, h) for m in range(1, 7) for t in (1, 2) for h in range(1, 10)],
                'Missing actual ordinary mean/clock/head component case')
        errors = []
        with localcontext() as context:
            context.prec = 80
            D = Decimal
            upper, lower = D('83.24164')*D('.4'), D('83.24164')
            rain = D('0.264667099721356325')
            for p in points:
                require(p[0] == 'ACTUAL_ORDINARY_POND_SWITCH', 'Foreign actual component row')
                mean = int(p[1])
                conductivity = ((upper+lower)/2 if mean in (1, 2) else
                                (upper*lower).sqrt() if mean in (3, 4) else
                                2*upper*lower/(upper+lower))
                conductance = conductivity/D('.5')
                step, head, pond, flux = map(D, p[5:9])
                positive = head > (D('1e-6') if variant == 'original' else 0)
                expected_pond = max(D(0), conductance*step*head/(1+conductance*step))
                expected_flux = -rain+expected_pond/step
                require(p[4] == ('T' if positive else 'F'), 'Wrong actual boundary dispatch')
                require(abs(pond-(expected_pond if positive else 0)) < D('1e-16'),
                        'Actual original ordinary pond equation differs')
                require(abs(flux-(expected_flux if positive else -rain)) < D('1e-12'),
                        'Actual original ordinary Darcy flux differs')
                errors.append(float(abs(flux-expected_flux)))
        results[variant] = dict(actual_cases=108, maximum_flux_gap_cm_day=max(errors))
    require(drivers[0] == drivers[1], 'Paired actual component drivers differ')
    require(results['original']['maximum_flux_gap_cm_day'] > 1e-5 and
            results['zero']['maximum_flux_gap_cm_day'] < 1e-12,
            'Original ordinary defect or corrected continuity not independently observed')
    return dict(status='INDEPENDENT_ORDINARY_COMPLETE_TOP_REFERENCE_PASS',
                decimal_digits=80, variants=results)
