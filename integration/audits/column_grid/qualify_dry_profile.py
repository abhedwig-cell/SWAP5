#!/usr/bin/env python3
"""Qualify existing Reference input at the same dry-profile final time.

No solver, tolerance, forcing or production owner changes. Build receipts bind
every reused compiled provider to current canonical source. This audit extends
scenario evidence; it does not select new physical functionality or full F-CI.
"""
import argparse
import base64
import csv
import hashlib
import io
import json
from pathlib import Path
import subprocess
import sys
import tarfile
import time

ROOT = Path(__file__).resolve().parents[3]
FIXTURE = Path(__file__).with_name('dry_profile_100_windows.nml')
RUNNER = ROOT / 'tools/solute/run_column.py'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def require(condition, label):
    if not condition:
        raise AssertionError(label)


def rows(path):
    with path.open() as stream:
        return [{k: float(v) for k, v in r.items()} for r in csv.DictReader(stream)]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--build-O0', required=True, type=Path)
    parser.add_argument('--build-O2', required=True, type=Path)
    parser.add_argument('--output', required=True, type=Path)
    args = parser.parse_args()
    out = args.output.resolve()
    out.mkdir(exist_ok=False, parents=True)
    record = json.loads((ROOT / 'integration/audits/MC_NUT_SOL_TRAJECTORY3_STATUS.json').read_text())
    e = record['column_input_20261020']['variable_grid_successor']['evidence']
    raw = base64.b64decode((ROOT / e['path']).read_bytes())
    require(hashlib.sha256(raw).hexdigest() == e['decoded_sha256'], 'original grid evidence identity')
    with tarfile.open(fileobj=io.BytesIO(raw)) as archive:
        coarse = archive.extractfile('qualification/O0/deep_dry_rejected.nml').read().decode()
    expected = coarse.replace('windows=2', 'windows=100')
    expected = expected.replace('ends_day=0.001,0.002',
                                'ends_day=' + ','.join(format(i * 0.00002, '.17g') for i in range(1, 101)))
    for key, value in [('rain_cm_day', '0.25'), ('irrigation_cm_day', '0.25'),
                       ('runon_cm_day', '0.5'), ('evaporation_cm_day', '0.05')]:
        expected = expected.replace(key + '=' + value + ',' + value, key + '=100*' + value)
    require(FIXTURE.read_text() == expected, 'only window partition changes from original failed physical input')
    coarse_path = out / 'original_coarse.nml'
    coarse_path.write_text(coarse)
    events, results, inputs = [], {}, {}
    for path in [Path(__file__), FIXTURE, RUNNER, ROOT / 'tools/solute/build_column.py']:
        inputs[str(path.relative_to(ROOT))] = sha(path)

    def execute(command, label, accepted=True):
        start = time.perf_counter()
        p = subprocess.run(list(map(str, command)), capture_output=True)
        index = str(len(events)).zfill(3)
        (out / (index + '.stdout')).write_bytes(p.stdout)
        (out / (index + '.stderr')).write_bytes(p.stderr)
        events.append({'label': label, 'command': list(map(str, command)), 'returncode': p.returncode,
                       'seconds': time.perf_counter() - start, 'stdout': index + '.stdout', 'stderr': index + '.stderr'})
        (out / 'events.json').write_text(json.dumps(events, indent=2) + '\n')
        require((p.returncode == 0) == accepted, label)

    for opt, build in [('O0', args.build_O0.resolve()), ('O2', args.build_O2.resolve())]:
        directory = out / opt
        directory.mkdir()
        report = json.loads((build / 'build-complete.json').read_text())
        require(report['status'] == 'BUILT' and report['provider_count'] == 178, 'complete real provider closure')
        require('-' + opt in report['flags'] and '-fcheck=all' in report['flags'] and
                '-ffpe-trap=invalid,zero,overflow' in report['flags'], 'original strict compiler policy')
        require(all(sha(ROOT / p) == h for p, h in report['input_sha256'].items()), 'reused build current source identity')
        require(not any(p.startswith('tests/') for p in report['input_sha256']), 'no test providers in physical executable')
        exe = build / 'swap5_solute_column'
        require(sha(exe) == report['executable_sha256'], 'reused physical executable identity')
        common = [sys.executable, RUNNER, '--exe', exe, '--input', FIXTURE]
        full, split, resumed = [directory / q for q in ['full', 'split', 'resumed']]
        execute(common + ['--output', full], opt + ' full same final time')
        execute(common + ['--output', split, '--stop-after', 37], opt + ' accepted prefix37')
        old = {p.name: sha(p) for p in split.iterdir()}
        execute(common + ['--output', resumed, '--restart', split], opt + ' independent process continuation')
        require(old == {p.name: sha(p) for p in split.iterdir()}, 'restart does not mutate old generation')
        for filename in ['state.csv', 'endpoint.csv', 'restart.bin']:
            require((full / filename).read_bytes() == (resumed / filename).read_bytes(), 'exact fresh process ' + filename)
        budget, endpoint, state = rows(full / 'budget.csv'), rows(full / 'endpoint.csv')[0], rows(full / 'state.csv')
        require(len(budget) == 100 and len(state) == 32 and endpoint['time_day'] == 0.002, 'same original final horizon')
        require(rows(split / 'budget.csv') + rows(resumed / 'budget.csv') == budget, 'all restarted window budgets exact')
        require(endpoint['pond_cm'] > 0 and endpoint['pond_solute_mg_cm2'] > 0, 'wet endpoint')
        require(sum(b['runoff_cm'] for b in budget) > 0, 'actual accepted runoff')
        for b in budget:
            dt = b['t1_day'] - b['t0_day']
            water = b['water_end_cm'] - b['water_start_cm'] - dt + dt * 0.1008 + b['runoff_cm'] + b['pond_evaporation_cm']
            solute = b['solute_end_mg_cm2'] - b['solute_start_mg_cm2'] - dt * 1.625 + b['solute_out_mg_cm2']
            require(abs(water) < 1e-10 and abs(solute) < 1e-10, 'independent window budgets')
            require(abs(b['water_residual_cm']) < 1e-10 and abs(b['solute_residual_mg_cm2']) < 1e-10, 'native strict balances')
            require(abs(b['solute_in_mg_cm2'] - dt * 1.625) < 1e-14, 'unchanged gross chemical source')
            require(min(b['infiltration_cm'], b['runon_cm'], b['pond_evaporation_cm']) > 0, 'actual positive accepted fluxes')
            require(b['accepted_substeps'] > 1, 'actual accepted refinement')
        whole_water = budget[-1]['water_end_cm'] - budget[0]['water_start_cm'] - 0.002 + 0.002 * 0.1008 + sum(
            b['runoff_cm'] + b['pond_evaporation_cm'] for b in budget)
        whole_solute = budget[-1]['solute_end_mg_cm2'] - budget[0]['solute_start_mg_cm2'] - 0.002 * 1.625 + sum(
            b['solute_out_mg_cm2'] for b in budget)
        require(abs(whole_water) < 1e-10 and abs(whole_solute) < 1e-10, 'independent complete horizon balance')
        require(abs(sum(r['theta'] * r['dz_cm'] for r in state) + endpoint['pond_cm'] - endpoint['total_water_cm']) < 1e-10,
                'independent final water inventory')
        require(abs(sum(r['dissolved_mg_cm2'] + r['sorbed_mg_cm2'] for r in state) + endpoint['pond_solute_mg_cm2'] -
                    endpoint['total_solute_mg_cm2']) < 1e-10, 'independent final chemical inventory')
        target = directory / 'coarse_rejected'
        execute([sys.executable, RUNNER, '--exe', exe, '--input', coarse_path, '--output', target],
                opt + ' original coarse partition rejected', False)
        require(not target.exists(), 'invalid coarse trial publishes no complete generation')
        pending = list(directory.glob('coarse_rejected.pending-*'))
        require(len(pending) == 1 and 'joint interval rejected' in (pending[0] / 'stdout').read_text(), 'actual hydraulic rejection')
        results[opt] = {'endpoint': endpoint, 'windows': len(budget), 'accepted_substeps': sum(int(b['accepted_substeps']) for b in budget),
                        'restart_sha256': sha(full / 'restart.bin'), 'whole_water_residual_cm': whole_water,
                        'whole_solute_residual_mg_cm2': whole_solute,
                        'max_native_water_residual_cm': max(abs(b['water_residual_cm']) for b in budget),
                        'max_native_solute_residual_mg_cm2': max(abs(b['solute_residual_mg_cm2']) for b in budget),
                        'reused_executable_sha256': sha(exe), 'build_candidate': report['candidate'],
                        'provider_sha256': report['input_sha256']}
    for filename in ['budget.csv', 'state.csv', 'endpoint.csv', 'restart.bin']:
        require((out / 'O0/full' / filename).read_bytes() == (out / 'O2/full' / filename).read_bytes(), 'exact O0/O2 ' + filename)
    require(all(sha(ROOT / p) == h for p, h in inputs.items()), 'audit input did not change during execution')
    result = {'status': 'SAME_HORIZON_DRY_REFERENCE_PROFILE_QUALIFIED', 'candidate': subprocess.check_output(
        ['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(), 'results': results, 'events': events,
        'input_sha256': inputs, 'original_evidence_sha256': e['decoded_sha256'],
        'unchanged_physical_forcing': True, 'production_changed': False,
        'compiler_link_seconds': 'REUSED_EXACT_CURRENT_BUILD', 'physics_only_seconds': 'UNKNOWN'}
    (out / 'result.json').write_text(json.dumps(result, indent=2) + '\n')
    print('MC_SOL01_DRY_138CM_SAME_HORIZON_O0_O2_BALANCE_FRESH_RESTART=PASS')


if __name__ == '__main__':
    main()
