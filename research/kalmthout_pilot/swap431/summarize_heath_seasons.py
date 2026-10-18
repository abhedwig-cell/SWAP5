#!/usr/bin/env python3
"""Audit archived native heath runs and compare paired scenario responses.

Monthly/annual aggregates retain every reservoir and the native EIC convention.
Factor contrasts are sensitivities, never probabilistic uncertainty intervals.
No model execution, parameter fitting or assignment to current map cells.
"""
import argparse
import csv
import datetime as dt
import hashlib
import itertools
import json
import math
from pathlib import Path

from run_wet_heath_scenarios import balance

FACTORS = ('a1_variant', 'root_depth_cm', 'capacity_cm_per_lai', 'bottom_mode')
FLUXES = ('RAIN', 'IRRIG', 'RUNON', 'SSDI', 'BOT', 'RUNOFF', 'EACT', 'EPD', 'TACT', 'EIC', 'DRN', 'TPOT')
METRICS = ('TACT_mm', 'transpiration_shortfall_mm', 'EACT_mm', 'EIC_mm', 'EPD_mm', 'RUNOFF_mm', 'BOT_mm', 'storage_change_mm')


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write_csv(path, rows):
    with path.open('w', newline='') as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)


def audit_case(case):
    receipt = json.loads((case / 'run_receipt.json').read_text())
    assert receipt['native_success'] and receipt['returncode'] == 100, case
    verified = {}
    for name, digest in {**receipt['input_sha256'], **receipt['output_sha256']}.items():
        path = case / name
        if not path.exists() and name in ('hourly.met', 'kalmthout.rain'):
            path = case.parent / 'forcing' / name
        assert sha(path) == digest, f'Changed native postimage: {case.name}/{name}'
        verified[name] = digest
    assert 'Swap simulation okay!' in (case / 'swap.log').read_text()
    checked = balance(case)
    contract = json.loads((case / 'case_manifest.json').read_text())
    assert receipt['executable_sha256'] == contract['executable_sha256']
    factors = dict(zip(FACTORS, (int(contract['layers'][0]['retention_fit']['row_variant']),
                               contract['root_depth_cm'], contract['canopy_capacity_cm_per_lai'],
                               contract['bottom_mode'])))
    with (case / 'result_output.csv').open() as handle:
        rows = list(csv.DictReader(line for line in handle if not line.startswith('*')))
    assert 'TPOT' in rows[0], 'Potential transpiration required for deficit'
    return factors, rows, {'case': case.name, 'verified_sha256': verified,
                          'manifest_sha256': sha(case / 'case_manifest.json'),
                          'executable_sha256': receipt['executable_sha256'], 'balance': checked}


def aggregate(case, factors, rows, indices, kind, period):
    selected = [rows[i] for i in indices]
    def value(row, key):
        if key not in row:
            assert key in ('RUNON', 'DRN') or (key == 'BOT' and factors['bottom_mode'] == 6), key
            return 0.
        answer = float(row[key])
        assert math.isfinite(answer)
        return answer
    def storage(row):
        return sum(value(row, key) for key in ('WTOT', 'PD_VOL', 'IC_VOL'))
    result = {'case': case, **factors, 'period_kind': kind, 'period': period,
              'start': selected[0]['DATE'], 'end': selected[-1]['DATE'], 'days': len(selected)}
    result.update({key + '_mm': 10 * math.fsum(value(row, key) for row in selected) for key in FLUXES})
    change = 10 * (storage(selected[-1]) - storage(rows[indices[0] - 1]))
    result['storage_change_mm'] = change
    result['closure_mm'] = sum(result[key + '_mm'] for key in FLUXES[:5]) - sum(result[key + '_mm'] for key in FLUXES[5:11]) - change
    result['transpiration_shortfall_mm'] = result['TPOT_mm'] - result['TACT_mm']
    result['transpiration_fraction'] = result['TACT_mm'] / result['TPOT_mm'] if result['TPOT_mm'] > 0 else ''
    result['ponded_days'] = sum(value(row, 'PD_VOL') > 0 for row in selected)
    result['max_native_baldev_mm'] = 10 * max(abs(value(row, 'BALDEV')) for row in selected)
    # Each monthly partition carries the previous end state: no lost boundary storage.
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('scenario_root', type=Path)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    cases = sorted(args.scenario_root.glob('wetheath_*/run_receipt.json'))
    assert len(cases) == 16, f'Expected complete 2x2x2x2 design, got {len(cases)}'
    output, evidence, design = [], [], set()
    for receipt_path in cases:
        case = receipt_path.parent
        factors, rows, audit = audit_case(case)
        design.add(tuple(factors[key] for key in FACTORS))
        evidence.append(audit)
        groups = {('whole', '2024-01-01_2026-10-01'): list(range(1, len(rows)))}
        for i, row in enumerate(rows[1:], 1):
            date = dt.date.fromisoformat(row['DATE'])
            groups.setdefault(('month', date.strftime('%Y-%m')), []).append(i)
            groups.setdefault(('year', str(date.year)), []).append(i)
            # April-September, identical window in each available year.
            if 4 <= date.month <= 9:
                groups.setdefault(('apr_sep', str(date.year)), []).append(i)
        summaries = [aggregate(case.name, factors, rows, indices, *key) for key, indices in groups.items()]
        whole = next(r for r in summaries if r['period_kind'] == 'whole')
        months = [r for r in summaries if r['period_kind'] == 'month']
        for key in [f + '_mm' for f in FLUXES] + ['storage_change_mm', 'closure_mm']:
            assert abs(math.fsum(r[key] for r in months) - whole[key]) < 1e-8, key
        output.extend(summaries)
    assert design == set(itertools.product((1, 2), (35., 50.), (.05, .1), (6, 7)))
    assert len({e['executable_sha256'] for e in evidence}) == 1
    contrasts = []
    for factor in FACTORS:
        paired = {}
        for row in output:
            identity = tuple(row[f] for f in FACTORS if f != factor) + (row['period_kind'], row['period'])
            paired.setdefault(identity, {})[row[factor]] = row
        for pair in paired.values():
            assert len(pair) == 2
            low, high = (pair[k] for k in sorted(pair))
            for metric in METRICS:
                contrasts.append({'factor': factor, 'low_level': low[factor], 'high_level': high[factor],
                                  'low_case': low['case'], 'high_case': high['case'],
                                  'period_kind': low['period_kind'], 'period': low['period'],
                                  'metric': metric, 'high_minus_low_mm': high[metric] - low[metric]})
    write_csv(args.output / 'heath_period_balances.csv', output)
    write_csv(args.output / 'heath_paired_sensitivities.csv', contrasts)
    summary = {'cases': 16, 'daily_states': 16080, 'new_native_runs': 0,
               'period_rows': len(output), 'paired_contrast_rows': len(contrasts),
               'scope': 'Historical profile sensitivities; no current cell predictions or probability intervals.',
               'eic_contract': 'Native EIC includes annual canopy capacity loss; not pure evaporation.',
               'season_definition': 'April 1 through September 30; complete in 2024, 2025, 2026.',
               'factor_contrasts': 'High minus low; all other factors fixed; 8 matched pairs per factor and period.',
               'whole_period_contrasts_mm': {}, 'verified_cases': evidence}
    for factor in FACTORS:
        summary['whole_period_contrasts_mm'][factor] = {}
        for metric in METRICS:
            values = [r['high_minus_low_mm'] for r in contrasts if r['factor'] == factor and r['metric'] == metric and r['period_kind'] == 'whole']
            assert len(values) == 8
            summary['whole_period_contrasts_mm'][factor][metric] = {'min': min(values), 'max': max(values), 'mean': math.fsum(values) / len(values)}
    summary['output_sha256'] = {name: sha(args.output / name) for name in ('heath_period_balances.csv', 'heath_paired_sensitivities.csv')}
    (args.output / 'heath_analysis_receipt.json').write_text(json.dumps(summary, indent=2) + '\n')
    print(json.dumps({k: v for k, v in summary.items() if k != 'verified_cases'}, indent=2))


if __name__ == '__main__':
    main()
