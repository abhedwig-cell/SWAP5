#!/usr/bin/env python3
import csv, json, math, sys
from pathlib import Path

if len(sys.argv) != 5:
    raise SystemExit('usage: compare replay.csv reference.csv precision.csv summary.json')

replay_p, ref_p, prec_p, out_p = map(Path, sys.argv[1:])
variables = ['DVS','LAI','NamountLV','NamountRT','NamountSO','NamountST','NuptakeTotal',
             'TAGP','TWLV','TWRT','TWSO','TWST']
precision = {r['VARIABLE']: float(r['ABS_TOL']) for r in csv.DictReader(prec_p.open())}
replay = {(int(r['CASE']), int(r['DAY'])): r for r in csv.DictReader(replay_p.open())}
ref_rows = list(csv.DictReader(ref_p.open()))
expected = {(int(r['CASE']), int(r['DAY'])): r for r in ref_rows}

if set(replay) != set(expected):
    missing = sorted(set(expected) - set(replay))[:20]
    extra = sorted(set(replay) - set(expected))[:20]
    raise SystemExit(f'key mismatch missing={missing} extra={extra}')

present_cases = sorted({case for case, _ in expected})
summary = {'status': 'PASS', 'rows': len(ref_rows), 'present_cases': present_cases,
           'variables': {}, 'cases': {}}
failures = []
for variable in variables:
    tolerance = precision[variable]
    max_abs = -1.0
    max_key = None
    first = None
    for key in sorted(expected):
        actual = float(replay[key][variable])
        reference = float(expected[key][variable])
        delta = abs(actual - reference)
        if not (math.isfinite(actual) and math.isfinite(reference) and math.isfinite(delta)):
            delta = float('inf')
        if delta > max_abs:
            max_abs, max_key = delta, key
        if first is None and delta > tolerance:
            first = key
    summary['variables'][variable] = {
        'tolerance': tolerance,
        'max_abs': max_abs,
        'max_case': max_key[0],
        'max_day': max_key[1],
        'first_divergence': None if first is None else {'case': first[0], 'day': first[1]}
    }
    if first is not None:
        failures.append((variable, first, max_abs, max_key, tolerance))

for case in present_cases:
    keys = [key for key in expected if key[0] == case]
    case_failures = [item for item in failures if item[1][0] == case]
    summary['cases'][str(case)] = {'days': len(keys), 'pass': not case_failures}

if failures:
    summary['status'] = 'FAIL'
    summary['failures'] = [
        {'variable': variable, 'first_case': first[0], 'first_day': first[1],
         'max_abs': max_abs, 'max_case': max_key[0], 'max_day': max_key[1],
         'tolerance': tolerance}
        for variable, first, max_abs, max_key, tolerance in failures
    ]

out_p.write_text(json.dumps(summary, indent=2, sort_keys=True) + '\n')
print(json.dumps(summary, indent=2, sort_keys=True))
if failures:
    raise SystemExit(1)
print('F_WOF_PP02_CASE_SET_PRESERVATION_PASS')
