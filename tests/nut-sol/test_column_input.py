#!/usr/bin/env python3
"""Qualify the real file-driven executable, budgets and complete generations."""
import argparse
import csv
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[2]
RUNNER = ROOT / 'tools/solute/run_column.py'
EXAMPLE = ROOT / 'examples/solute_column/positive_pond.nml'


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def rows(path):
    with path.open() as stream:
        return [{key: float(value) for key, value in row.items()} for row in csv.DictReader(stream)]


def require(condition, label):
    if not condition:
        raise AssertionError(label)


def qualify_grids(execute, directory, exe):
    """Geometry adapter qualification using unchanged production physics."""
    cases = {
        'minimum': [0.25, 0.75],
        'refined': [0.25] * 4 + [0.5] * 4,
        'deep': [0.5, 0.5, 1, 1, 2, 3] + [5] * 26,
        'maximum': [1] * 256,
    }
    results = {}
    for name, thickness in cases.items():
        n = len(thickness)
        case = directory / name
        case.mkdir()
        source = case / 'input.nml'
        # Concentration gradients exercise internal dispersion/advection;
        # source arrays retain fixed column totals as the grid changes.
        concentrations = [0.2 + 0.3 * i / (n - 1) for i in range(n)]
        text = EXAMPLE.read_text().replace('schema=1', 'schema=2, nodes=' + str(n) +
                                          ', cell_thickness_cm=' + ','.join(map(str, thickness)))
        text = text.replace('concentration_mg_cm3=0.2,0.3,0.4,0.5',
                            'concentration_mg_cm3=' + ','.join(map(str, concentrations)))
        text = text.replace('4*0.0001', str(n) + '*' + str(0.0004 / n))
        if name == 'maximum':
            text = text.replace('ends_day=0.001,0.002', 'ends_day=0.00001,0.00002')
        source.write_text(text)
        common = [sys.executable, RUNNER, '--exe', exe, '--input', source]
        full, split, resumed = [case / p for p in ['full', 'split', 'resumed']]
        execute(common + ['--output', full], name + ' full')
        execute(common + ['--output', split, '--stop-after', 1], name + ' split')
        execute(common + ['--output', resumed, '--restart', split], name + ' independent restart')
        for filename in ['state.csv', 'endpoint.csv', 'restart.bin']:
            require((full / filename).read_bytes() == (resumed / filename).read_bytes(), name + ' exact restart ' + filename)
        state, endpoint, budget = rows(full / 'state.csv'), rows(full / 'endpoint.csv')[0], rows(full / 'budget.csv')
        require(len(state) == n, name + ' actual active node count')
        depth = 0.0
        for row, width in zip(state, thickness):
            require(abs(row['dz_cm'] - width) < 1e-14, name + ' thickness')
            require(abs(row['z_cm'] + depth + 0.5 * width) < 1e-12, name + ' cell centre')
            require(abs(row['sorbed_mg_cm2'] - 1.3 * 0.2 * row['concentration_mg_cm3'] * width) < 1e-12,
                    name + ' linear sorption inventory')
            depth += width
        require(rows(resumed / 'budget.csv') == budget[1:], name + ' restart budget')
        require(abs(sum(r['theta'] * r['dz_cm'] for r in state) + endpoint['pond_cm'] - endpoint['total_water_cm']) < 1e-10,
                name + ' endpoint water inventory')
        require(abs(sum(r['dissolved_mg_cm2'] + r['sorbed_mg_cm2'] for r in state) + endpoint['pond_solute_mg_cm2'] -
                    endpoint['total_solute_mg_cm2']) < 1e-10, name + ' endpoint solute inventory')
        for b in budget:
            dt = b['t1_day'] - b['t0_day']
            require(abs(b['water_end_cm'] - b['water_start_cm'] - dt + dt * (0.0008 + 0.1) +
                        b['runoff_cm'] + b['pond_evaporation_cm']) < 1e-10, name + ' independent gross water budget')
            cin = dt * (0.25 * 0.125 + 0.25 * 0.375 + 0.5 * 3)
            require(abs(b['solute_in_mg_cm2'] - cin) < 1e-14, name + ' chemical source budget')
            require(abs(b['solute_end_mg_cm2'] - b['solute_start_mg_cm2'] - cin + b['solute_out_mg_cm2']) < 1e-10,
                    name + ' independent chemical budget')
            require(abs(b['water_residual_cm']) < 1e-10 and abs(b['solute_residual_mg_cm2']) < 1e-10, name + ' native balances')
            require(min(b['infiltration_cm'], b['runon_cm'], b['pond_evaporation_cm']) > 0, name + ' positive gross fluxes')
            require(b['accepted_substeps'] > 1, name + ' actual substeps')
        require(sum(b['runoff_cm'] for b in budget) > 0 and endpoint['pond_cm'] > 0, name + ' wet pond and runoff')
        results[name] = {'nodes': n, 'depth_cm': depth, 'budget': budget, 'endpoint': endpoint,
                         'input_sha256': digest(source), 'restart_sha256': digest(full / 'restart.bin')}
    bad = {
        'too_few': 'schema=2, nodes=1, cell_thickness_cm=1',
        'too_many': 'schema=2, nodes=257, cell_thickness_cm=256*1',
        'zero_cell': 'schema=2, nodes=4, cell_thickness_cm=0.5,0,1,1',
        'negative_cell': 'schema=2, nodes=4, cell_thickness_cm=0.5,-0.5,1,1',
        'nonfinite_cell': 'schema=2, nodes=4, cell_thickness_cm=NaN,0.5,1,1',
        'thin_cell': 'schema=2, nodes=4, cell_thickness_cm=0.00001,0.5,1,1',
        'wide_cell': 'schema=2, nodes=4, cell_thickness_cm=10001,0.5,1,1',
        'deep_column': 'schema=2, nodes=256, cell_thickness_cm=256*10000',
        'missing_cell': 'schema=2, nodes=5, cell_thickness_cm=0.5,0.5,1,1',
        'inactive_cell': 'schema=2, nodes=4, cell_thickness_cm=5*1',
        'inactive_concentration': 'schema=2, nodes=4, cell_thickness_cm=4*1, concentration_mg_cm3(5)=1',
        'inactive_root': 'schema=2, nodes=4, cell_thickness_cm=4*1, root_cm_day(5)=1',
        'inactive_drain': 'schema=2, nodes=4, cell_thickness_cm=4*1, drain_cm_day(5)=1',
        'schema1_grid': 'schema=1, cell_thickness_cm=4*1',
    }
    for name, replacement in bad.items():
        source = directory / (name + '.nml')
        source.write_text(EXAMPLE.read_text().replace('schema=1', replacement))
        target = directory / ('invalid-' + name)
        execute([sys.executable, RUNNER, '--exe', exe, '--input', source, '--output', target], name + ' invalid grid', None)
        require(not target.exists(), name + ' invalid grid does not publish')
    return results


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--build-O0', type=Path, required=True)
    parser.add_argument('--build-O2', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    events, results = [], {}

    def execute(command, label, expected=0):
        start = time.perf_counter()
        process = subprocess.run(list(map(str, command)), capture_output=True)
        prefix = str(len(events)).zfill(3)
        (output / (prefix + '.stdout')).write_bytes(process.stdout)
        (output / (prefix + '.stderr')).write_bytes(process.stderr)
        events.append({'label': label, 'command': list(map(str, command)), 'returncode': process.returncode,
                       'seconds': time.perf_counter() - start, 'stdout': prefix + '.stdout', 'stderr': prefix + '.stderr'})
        (output / 'events.json').write_text(json.dumps(events, indent=2) + '\n')
        require(process.returncode == expected if expected is not None else process.returncode != 0, label)
        return process

    for optimization, build in [('O0', args.build_O0.resolve()), ('O2', args.build_O2.resolve())]:
        directory = output / optimization
        directory.mkdir()
        exe = build / 'swap5_solute_column'
        report = json.loads((build / 'build-complete.json').read_text())
        require(report['executable_sha256'] == digest(exe), 'build/executable identity')
        require(not any(p.startswith('tests/') for p in report['input_sha256']), 'production build has no test providers')
        require(all(digest(ROOT / p) == h for p, h in report['input_sha256'].items()), 'current source binding')
        common = [sys.executable, RUNNER, '--exe', exe, '--input', EXAMPLE]
        full, split, resumed = [directory / p for p in ['full', 'split', 'resumed']]
        execute(common + ['--output', full], optimization + ' full')
        execute(common + ['--output', split, '--stop-after', 1], optimization + ' split')
        execute(common + ['--output', resumed, '--restart', split], optimization + ' independent restart')
        for name in ['restart.bin', 'state.csv', 'endpoint.csv']:
            require((full / name).read_bytes() == (resumed / name).read_bytes(), 'fresh process exact ' + name)
        budget = rows(full / 'budget.csv')
        require(len(budget) == 2, 'two reporting windows')
        require(rows(resumed / 'budget.csv') == budget[1:], 'restart window budget identity')
        for b in budget:
            dt = b['t1_day'] - b['t0_day']
            # Independent gross water accounting, including prescribed root,
            # drain and lower-face outflow. Rates come from this input case.
            gross_in = dt * (0.25 + 0.25 + 0.5)
            subsurface_out = dt * (4 * 0.0001 + 4 * 0.0001 + 0.1)
            residual = b['water_end_cm'] - b['water_start_cm'] - gross_in + subsurface_out + b['runoff_cm'] + b['pond_evaporation_cm']
            require(abs(residual) < 1e-10, 'independent gross water balance')
            require(abs(b['water_residual_cm']) < 1e-10, 'native water balance')
            chemical_in = dt * (0.25 * 0.125 + 0.25 * 0.375 + 0.5 * 3)
            require(abs(b['solute_in_mg_cm2'] - chemical_in) < 1e-14, 'source chemical input')
            require(abs(b['solute_end_mg_cm2'] - b['solute_start_mg_cm2'] - chemical_in + b['solute_out_mg_cm2']) < 1e-11,
                    'independent whole solute balance')
            require(abs(b['solute_residual_mg_cm2']) < 1e-11, 'native solute balance')
            require(min(b['infiltration_cm'], b['runon_cm'], b['runoff_cm'], b['pond_evaporation_cm']) > 0, 'positive accepted gross fluxes')
            require(b['accepted_substeps'] > 1, 'multiple accepted substeps')
        state, endpoint = rows(full / 'state.csv'), rows(full / 'endpoint.csv')[0]
        require(endpoint['pond_cm'] > 0 and endpoint['pond_solute_mg_cm2'] > 0, 'wet pond endpoint')
        require(abs(sum(r['theta'] * r['dz_cm'] for r in state) + endpoint['pond_cm'] - endpoint['total_water_cm']) < 1e-14,
                'independent endpoint water inventory')
        require(abs(sum(r['dissolved_mg_cm2'] + r['sorbed_mg_cm2'] for r in state) + endpoint['pond_solute_mg_cm2'] -
                    endpoint['total_solute_mg_cm2']) < 1e-14, 'independent endpoint chemical inventory')
        before = {p.name: digest(p) for p in split.iterdir()}
        execute(common + ['--output', full], optimization + ' existing output rejected', None)
        for label, change in [
            ('schema', ('schema=1', 'schema=999')),
            ('negative_concentration', ('concentration_mg_cm3=0.2', 'concentration_mg_cm3=-0.2')),
            ('nonfinite', ('rain_c=0.125', 'rain_c=NaN')),
            ('backward_clock', ('ends_day=0.001,0.002', 'ends_day=0.001,0.0005')),
            ('unsupported_keyword', ('schema=1', 'schema=1, snow_active=.true.')),
        ]:
            source = directory / (label + '.nml')
            source.write_text(EXAMPLE.read_text().replace(*change))
            target = directory / label
            execute([sys.executable, RUNNER, '--exe', exe, '--input', source, '--output', target], optimization + ' ' + label, None)
            require(not target.exists(), 'invalid input does not publish a generation')
        changed = directory / 'changed_hydraulic.nml'
        changed.write_text(EXAMPLE.read_text().replace('ksat_cm_day=0.00475', 'ksat_cm_day=0.0048'))
        process = execute([sys.executable, RUNNER, '--exe', exe, '--input', changed, '--output', directory / 'changed', '--restart', split],
                          optimization + ' changed hydraulic restart rejected', None)
        require(b'restart input or executable identity mismatch' in process.stderr, 'identity-specific rejection')
        corrupt = directory / 'corrupt'
        corrupt.mkdir()
        for path in split.iterdir():
            (corrupt / path.name).write_bytes(path.read_bytes())
        data = bytearray((corrupt / 'restart.bin').read_bytes())
        data[-1] ^= 1
        (corrupt / 'restart.bin').write_bytes(data)
        process = execute(common + ['--output', directory / 'bad-restart', '--restart', corrupt], optimization + ' corrupt generation rejected', None)
        require(b'restart generation hash mismatch: restart.bin' in process.stderr, 'specific corrupt generation rejection')
        # Kill the launcher immediately before or after the sole generation
        # rename. Native executable and scientific inputs remain unchanged.
        for when, exitcode in [('before', 77), ('after', 78)]:
            target = directory / ('crash-' + when)
            code = "import os,runpy,sys\nrename=os.rename\ndef inject(a,b):\n"
            if when == 'after':
                code += " rename(a,b)\n"
            code += f" os._exit({exitcode})\nos.rename=inject\nsys.argv=sys.argv[1:]\nrunpy.run_path(sys.argv[0],run_name='__main__')\n"
            execute([sys.executable, '-c', code, RUNNER, '--exe', exe, '--input', EXAMPLE, '--output', target, '--restart', split],
                    optimization + ' crash ' + when, exitcode)
            require(target.exists() == (when == 'after'), 'atomic generation visibility')
            if when == 'after':
                manifest = json.loads((target / 'manifest.json').read_text())
                require(all(digest(target / p) == h for p, h in manifest['files'].items()), 'published generation complete')
                require((target / 'restart.bin').read_bytes() == (full / 'restart.bin').read_bytes(), 'published generation exact endpoint')
        require(before == {p.name: digest(p) for p in split.iterdir()}, 'old generation remains unchanged')
        results[optimization] = {'executable_sha256': digest(exe), 'build_candidate': report['candidate'],
                                 'budget': budget, 'endpoint': endpoint, 'restart_sha256': digest(full / 'restart.bin'),
                                 'source_sha256': report['input_sha256'],
                                 'build_seconds': {category: sum(e['seconds'] for e in report['events'] if e['category'] == category)
                                                   for category in ['compile', 'link']}}
        require(digest(full / 'restart.bin') == '42d92009baeb4e7a90ef2e2ebbd22c79df69cb05bc7cf0e01e7cea39bf192e4f',
                'canonical schema1 endpoint preserved')
        results[optimization]['grids'] = qualify_grids(execute, directory, exe)
    for name in ['budget.csv', 'state.csv', 'endpoint.csv', 'restart.bin']:
        require((output / 'O0/full' / name).read_bytes() == (output / 'O2/full' / name).read_bytes(), 'O0/O2 identity ' + name)
    require(results['O0']['grids'] == results['O2']['grids'], 'all grid O0/O2 physical identities')
    result = {'status': 'PASS', 'results': results, 'events': events,
              'test_sha256': digest(Path(__file__)), 'runner_sha256': digest(RUNNER), 'input_sha256': digest(EXAMPLE)}
    (output / 'result.json').write_text(json.dumps(result, indent=2) + '\n')
    print('MC_SOL01_FILE_COLUMN_O0_O2_BALANCE_RESTART_GENERATIONS=PASS')


if __name__ == '__main__':
    main()
