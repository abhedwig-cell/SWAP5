"""Seal the successful, failed and observer-exact PERF01 interval experiments."""
import argparse
import csv
import hashlib
import io
import itertools
import json
from pathlib import Path
import tarfile

ROOT = Path(__file__).resolve().parents[2]
HERE = ROOT / 'benchmarks/performance'
sha = lambda b: hashlib.sha256(b).hexdigest()


def rows(p):
    return list(csv.DictReader(p.open()))


def compare(a, b):
    assert len(a) == len(b)
    result = {}
    for key in ['runoff_cm', 'actual_transpiration_cm', 'soil_evaporation_cm', 'pond_evaporation_cm']:
        differences = [10 * (float(y[key]) - float(x[key])) for x, y in zip(a, b)]
        result[key] = dict(max_daily_mm=max(map(abs, differences)), total_mm=sum(differences),
                           max_cumulative_mm=max(map(abs, itertools.accumulate(differences))))
    result['max_storage_mm'] = 10 * max(abs(float(x['water_end_cm']) - float(y['water_end_cm'])) for x, y in zip(a, b))
    result['max_total_evaporation_daily_mm'] = 10 * max(abs(
        float(y['soil_evaporation_cm']) + float(y['pond_evaporation_cm']) -
        float(x['soil_evaporation_cm']) - float(x['pond_evaporation_cm'])) for x, y in zip(a, b))
    result['rain_integral_difference_cm'] = max(abs(float(x['rain_supplied_cm']) - float(y['rain_supplied_cm'])) for x, y in zip(a, b))
    assert result['rain_integral_difference_cm'] < 1e-9
    result['runoff_occurrence_changes'] = [int(x['window']) for x, y in zip(a, b)
        if (float(x['runoff_cm']) > 0) != (float(y['runoff_cm']) > 0)]
    return result


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--runs', type=Path, required=True)
    a = ap.parse_args()
    run = a.runs.resolve()
    r = dict(status='RESEARCH_DISCRIMINATORS_COMPLETE_CAPPED_POLICY_NOT_SELECTED',
             production_changed=False, production_qualified=False,
             reconciled_canonical='d04a8c3cca1ac9246e66dc913ba588472a5fb78c',
             common_restart_day=145, guards={}, interval_refinement={}, full_runs={},
             failed_observers={}, O0_O2_physical_identity={})
    files = {}
    names = ['common-head', 'exchange-O2', 'dry-O2', 'incumbent-O2', 'incumbent-O0',
             'cap004-O2', 'cap002-O2', 'cap001-O2',
             'cap004-v2-O2', 'cap002-v2-O2', 'cap001-v2-O2', 'cap001-v2-O0',
             'full1x-cap001-O2', 'full4x-cap001-O2', 'full4x-cap001-restart',
             'failure1x-observed', 'failure4x-observed', 'bundle-O0', 'bundle-O2']
    reference = rows(run / 'common-head/budget.csv')
    for guard in ['exchange', 'dry', 'incumbent']:
        r['guards'][guard] = compare(reference, rows(run / (guard + '-O2') / 'case/budget.csv'))
    for label in ['cap004-v2-O2', 'cap002-v2-O2', 'cap001-v2-O2']:
        head, flux = [rows(run / label / arm / 'budget.csv') for arm in ['head', 'flux']]
        record = json.loads((run / label / 'RESULT.json').read_text())
        assert record['status'] == 'RESEARCH_COMPLETED'
        r['interval_refinement'][label] = dict(cap_day=record['cap_day'], head_vs_flux=compare(head, flux),
            day152_runoff_mm={arm: 10 * float(next(v for v in data if v['window'] == '152')['runoff_cm'])
                             for arm, data in [('head', head), ('flux', flux)]},
            ordinary_change_vs_uncapped=compare(reference, head))
    for rain in [1, 4]:
        p = run / ('full' + str(rain) + 'x-cap001-O2')
        record = json.loads((p / 'RESULT.json').read_text())
        r['full_runs'][str(rain)] = record
        for arm in ['head', 'flux']:
            data = rows(p / arm / 'budget.csv')
            assert max(abs(float(v['water_residual_cm'])) for v in data) < 1e-10
            record['cases'][arm]['last_published_day'] = int(data[-1]['window'])
    for rain in [1, 4]:
        record = json.loads((run / ('failure' + str(rain) + 'x-observed') / 'RESULT.json').read_text())
        assert record['status'] == 'OBSERVED_REJECTION_PHYSICAL_BYTES_EXACT'
        r['failed_observers'][str(rain)] = record
    restart = json.loads((run / 'full4x-cap001-restart/RESULT.json').read_text())
    assert restart['status'] == 'ACTUAL_DAY240_RESTART_EXACT'
    r['completed4x_restart'] = restart
    for label in ['incumbent', 'cap001-v2']:
        for arm in (['case'] if label == 'incumbent' else ['head', 'flux']):
            for name in ['budget.csv', 'state.csv', 'endpoint.csv', 'restart.bin']:
                x = (run / (label + '-O0') / arm / name).read_bytes()
                y = (run / (label + '-O2') / arm / name).read_bytes()
                assert x == y
                r['O0_O2_physical_identity']['/'.join([label, arm, name])] = sha(x)
    for name in names:
        for p in (run / name).rglob('*'):
            if not p.is_file() or p.suffix in ['.o', '.mod', '.a', '.pyc']:
                continue
            b = p.read_bytes()
            if b.startswith(b'\x7fELF'):
                continue
            files['raw/' + name + '/' + str(p.relative_to(run / name))] = b
    for optimization in ['O0', 'O2']:
        base = Path('/tmp/perf01-historical-exchange-base-' + optimization)
        for name in ['main.f90', 'mod_fmr_serialized_reference_backend.f90',
                     'mod_fmr_b111_pond_joint_application.f90', 'RESULT.json']:
            files['generated-base/' + optimization + '/' + name] = (base / name).read_bytes()
    # Freeze exact original inputs/restart used by new CLI reproduction paths.
    files['inputs/day145.bin'] = Path('/tmp/perf01-historical-4x-v1/head-stop145/restart.bin').read_bytes()
    for rain, folder in [('1', Path('/tmp/perf01-endpoint-1x-v1')), ('4', Path('/tmp/perf01-historical-4x-v1'))]:
        for arm in ['head', 'flux']:
            source = folder / ('full481-' + arm) if rain == '1' else folder / arm
            for name in ['input.nml', 'input.swp']:
                files['inputs/' + rain + 'x/' + arm + '/' + name] = (source / name).read_bytes()
    for name in ['study_perf01_exchange_guard.py', 'study_perf01_segment_refinement.py',
                 'observe_perf01_segment_failure.py', 'seal_perf01_exchange_research.py',
                 'screen_perf01_geometry.py', 'check_perf01_historical_restart.py',
                 'PERF01_HISTORICAL_RESEARCH_20261024.md']:
        files['reproduce/' + name] = (HERE / name).read_bytes()
    files['RESULT.json'] = (json.dumps(r, indent=2) + '\n').encode()
    files['MANIFEST.json'] = (json.dumps({n: sha(b) for n, b in sorted(files.items())}, indent=2) + '\n').encode()
    target = HERE / 'PERF01_EXCHANGE_20261024_EVIDENCE.tar.xz'
    with tarfile.open(target, 'w:xz') as t:
        for n, b in sorted(files.items()):
            m = tarfile.TarInfo(n)
            m.size = len(b)
            t.addfile(m, io.BytesIO(b))
    with tarfile.open(target) as t:
        for n, h in json.load(t.extractfile('MANIFEST.json')).items():
            assert sha(t.extractfile(n).read()) == h, n
    r['evidence'] = dict(path=str(target.relative_to(ROOT)), sha256=sha(target.read_bytes()), members=len(files))
    (HERE / 'PERF01_EXCHANGE_20261024_RESULT.json').write_text(json.dumps(r, indent=2) + '\n')
    print(json.dumps(r['evidence']))


if __name__ == '__main__':
    main()
