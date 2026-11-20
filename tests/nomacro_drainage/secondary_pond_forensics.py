"""Independent secondary implicit pond-switch observations; no model imports."""
import argparse
import hashlib
import json
from pathlib import Path
from decimal import Decimal, localcontext

import implicit_forensics as prior
from extended_evidence import lines, physical

require = prior.require
ORIGINAL_TOP = '24b28637fc841a8094902b84fc081f90939d3c0c7fd1b2869a2c20ee913a11ca'
ORIGINAL_HISTORY_TOP = '77e72bb23b300e2f880b72bb0b1b0d4955c928b3b9188a2a3f6d075c35206da5'
OLD = '      if (h0 <= 1.0d-6) then'
NEW = '      if (h0 <= 0.0d0) then'


def boundtop(raw, history=False):
    text = raw.decode('cp1252').replace('\r\n', '\n')
    require(text.count(NEW) == 1 and OLD not in text,
            'Actual secondary implicit positive-pond switch differs')
    original = text.replace(NEW, OLD, 1).encode('cp1252')
    require(hashlib.sha256(original).hexdigest() == (ORIGINAL_HISTORY_TOP if history else ORIGINAL_TOP),
            'Actual complete original top provider changed beyond zero switch')
    return hashlib.sha256(text.encode('cp1252')).hexdigest()


def component(root):
    root = Path(root)
    q = json.loads((root/'RESULT.json').read_text())
    require(q['status'] == 'ACTUAL_COMPLETE_ORIGINAL_SECONDARY_POND_SWITCH_COMPONENTS',
            'Incomplete actual original top components')
    reports = {}
    drivers = []
    for variant in ('original', 'zero'):
        directory = root/variant
        record = q['variants'][variant]
        for name, key in [('boundtop.f90', 'actual_source_sha256'),
                          ('test_secondary_pond_switch.f90', 'driver_sha256'),
                          ('component.exe', 'executable_sha256')]:
            require(hashlib.sha256((directory/name).read_bytes()).hexdigest() == record[key],
                    'Actual complete component source/driver/executable differs')
        drivers.append((directory/'test_secondary_pond_switch.f90').read_bytes())
        source = (directory/'boundtop.f90').read_bytes()
        if variant == 'zero':
            boundtop(source)
        else:
            require(hashlib.sha256(source.replace(b'\r\n', b'\n')).hexdigest() == ORIGINAL_TOP,
                    'Actual original complete top component differs')
        points = [line.split() for line in (directory/'actual.stdout').read_text().splitlines()]
        require(len(points) == record['actual_cases'] == 18 and
                [(int(p[1]), int(p[2])) for p in points] ==
                [(j, i) for j in (1, 2) for i in range(1, 10)],
                'Actual component point denominator differs')
        errors = []
        with localcontext() as ctx:
            ctx.prec = 80
            rain = Decimal('0.264667099721356325')
            conductance = Decimal('83.24164')/Decimal('.5')
            for p in points:
                require(p[0] == 'ACTUAL_ORIGINAL_POND_SWITCH', 'Foreign component observations')
                step, head, pond, flux = map(Decimal, p[4:8])
                expected_pond = max(Decimal(0), conductance*step*head/(1+conductance*step))
                expected_flux = -rain+expected_pond/step
                active = head > (Decimal('1e-6') if variant == 'original' else 0)
                require(p[3] == ('T' if active else 'F'), 'Actual original boundary dispatch differs')
                require(abs(pond-(expected_pond if active else 0)) < Decimal('1e-16'),
                        'Actual complete original pond equation differs')
                require(abs(flux-(expected_flux if active else -rain)) < Decimal('1e-12'),
                        'Actual complete original Darcy boundary differs')
                errors.append(float(abs(flux-expected_flux)))
        reports[variant] = dict(actual_cases=len(points),
                                maximum_closed_form_flux_difference_cm_day=max(errors))
    require(drivers[0] == drivers[1], 'Actual paired component drivers differ')
    require(reports['original']['maximum_closed_form_flux_difference_cm_day'] > 1e-4 and
            reports['zero']['maximum_closed_form_flux_difference_cm_day'] < 1e-12,
            'Original boundary jump or continuous correction not independently observed')
    return dict(status='INDEPENDENT_COMPLETE_ORIGINAL_POND_SWITCH_REFERENCE_DEFECT_PASS',
                independent_decimal_digits=80, variants=reports)


def audit_root(root, compiled_root=None):
    root = Path(root)
    q = json.loads((root/'RESULT.json').read_text())
    require(q['status'] == 'ACTUAL_EXTENDED_DRAINAGE_ORIGINAL_OUTPUT_NATIVE_PASS',
            'Incomplete actual secondary implicit period')
    days = q['parameters']['days']
    require(days in (35, 1096) and q['parameters']['implicit'] is True,
            'Unqualified secondary implicit period')
    windows = [(2, 4), (14, 17), (30, 35)]
    if days == 1096:
        require(q['parameters']['switch_window'] is True,
                'Missing actual secondary failure crossing window')
        windows += [(363, 367), (530, 532), (1094, 1096), (288, 290)]
    require([(v['start'], v['end']) for v in q['cold']] == windows,
            'Required secondary native windows differ')
    build_root = Path(compiled_root or q['build_root'])
    raw_build = (build_root/'BUILD.json').read_bytes()
    build = json.loads(raw_build)
    require(json.loads((root/'trajectory/BUILD.json').read_bytes()) == build and
            q['trajectory']['build_sha256'] == hashlib.sha256(raw_build).hexdigest(),
            'Actual secondary trajectory/compiler bundle differs')
    extended = build['identity']['extended_drainage']
    domain = extended['domain']
    require(domain[0:2] == [1, 34] and domain[3] == 2 and domain[5] == 0 and
            domain[4] in (1, 2) and domain[6] == domain[2],
            'Foreign actual secondary-only drain domain')
    require(extended['original_positive_head_deadband_preserved'] is False and
            extended['strict_trial_water_guard_cm'] == 1e-10 and
            extended['strict_retry_clock_floor_ulps'] == 8,
            'Secondary source authority or scientific limits changed')
    selected = prior.selected_input(root/'input/swap.swp')
    top_sha = boundtop((build_root/'boundtop.f90').read_bytes(), bool(selected['swhyst']))
    require(q['parameters']['hysteresis'] == selected['swhyst'] and
            q['output_selection'] == {k: v for k, v in selected.items() if k != 'swhyst'},
            'Actual selected original secondary output/history differs')
    for name, digest in build['inputs'].items():
        require(Path(name).name == name and
                hashlib.sha256((root/'input'/name).read_bytes()).hexdigest() == digest,
                'Actual secondary input/compiler identity differs')
    data = lines((root/'trajectory/daily.jsonl').read_bytes())
    require(len(data) == days and data[0]['day'] == 1 and data[-1]['day'] == days,
            'Censored actual secondary period')
    dz = prior.geometry((root/'input/swap.swp').read_text(encoding='cp1252'))

    def observed(directory, rows):
        result = prior.inventory(rows)
        stdout = (directory/'original/donor.stdout').read_bytes()
        prior.observed(stdout, rows, build)
        frames = [list(map(float, line.split()[1:])) for line in stdout.decode().splitlines()
                  if line.startswith('HYBRID_HYDRAULIC ')]
        require(len(frames) == len(rows)+1 and all(v[1] == 0 for v in frames),
                'Actual original secondary bottom6 hydraulic frames differ')
        result['actual_original_drain_counters'] = prior.audit(directory, domain[2])
        return result

    warm = observed(root/'trajectory', data)
    cuts = {days, *(v for pair in windows for v in pair)}
    packages = {int(p.stem.rsplit('-', 1)[1]): p for p in
                (root/'trajectory').glob('accepted-column-1-day-*.zip')}
    require(set(packages) == cuts, 'Actual complete secondary checkpoint inventory differs')
    native = {day: prior.checkpoint(path, build, data[day-1], selected, dz)
              for day, path in packages.items()}
    cold = []
    for low, high in windows:
        directory = root/f'cold-{low}'
        rows = lines((directory/'daily.jsonl').read_bytes())
        require(physical(rows) == physical(data[low:high]),
                'Actual secondary cold physical continuation differs')
        report = observed(directory, rows)
        actual = prior.checkpoint(directory/f'accepted-column-1-day-{high}.zip',
                                  build, rows[-1], selected, dz)
        require(actual == native[high], 'Actual complete secondary cold native differs')
        report['output'] = prior.compare(root/'trajectory/original', directory/'original',
                                         selected, low, high, build['project']['start_date'])
        cold.append(dict(start=low, end=high, observations=report))
    return dict(status='INDEPENDENT_SECONDARY_IMPLICIT_POND_WATER_CDE_NATIVE_PASS',
                actual_days=days, warm=warm, cold=cold, boundtop_lf_sha256=top_sha,
                original_positive_head_deadband_preserved=False,
                functional_completion='PARTIAL', whole_scientific_equivalence='NOT_QUALIFIED')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('directory', type=Path)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    result = audit_root(args.directory)
    with args.output.open('x', encoding='utf-8') as stream:
        json.dump(result, stream, indent=2)
    print(result['status'], result['actual_days'])
