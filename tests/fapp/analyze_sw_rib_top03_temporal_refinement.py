"""Analyze the research log; no production accuracy budget is selected."""
import csv
import hashlib
import json
import sys
from pathlib import Path

log = Path(sys.argv[1])
out = Path(sys.argv[2])
out.mkdir(parents=True, exist_ok=True)
lines = log.read_text().splitlines()
headers = [line for line in lines if line.startswith('profile,')]
assert len(headers) == 2 and headers[0] == headers[1]
assert 'TOP03_REFINEMENT_O0=COMPLETED' in lines
assert 'TOP03_REFINEMENT_O2=COMPLETED' in lines
fields = headers[0].split(',')
rows = [dict(zip(fields, row)) for row in csv.reader(lines)
        if len(row) == len(fields) and row[0].isdigit()]
assert len(rows) == 160
for a, b in zip(rows[:80], rows[80:]):
    assert {k: v for k, v in a.items() if k != 'cpu_seconds'} == {
        k: v for k, v in b.items() if k != 'cpu_seconds'}
stops = [line for line in lines if line.startswith('STOP,')]
assert len(stops) == 68 and stops[:34] == stops[34:]
assert max(abs(float(row['ledger_residual_cm'])) for row in rows) < 1e-10
profiles = []
differences = []
for profile in range(1, 5):
    rr = [row for row in rows[:80] if int(row['profile']) == profile]
    short = [row for row in rr if row['window'] == '2']
    assert all(row['steps'] == row['completed'] and row['stop_code'] == '0' for row in short)
    errors = []
    for prev, cur in zip(short, short[1:]):
        item = {
            'profile': profile,
            'steps': int(cur['steps']),
            'transfer_difference_cm': abs(float(cur['transfer_cm']) - float(prev['transfer_cm'])),
            'water_profile_l1_cm': sum(abs(float(cur[f'theta{k}']) - float(prev[f'theta{k}'])) * d
                                      for k, d in enumerate([0.5, 0.5, 1.0, 1.0], 1)),
            'head_inf_cm': max(abs(float(cur[f'h{k}']) - float(prev[f'h{k}'])) for k in range(1, 5)),
        }
        errors.append(item)
        differences.append(item)
    for metric in ['transfer_difference_cm', 'water_profile_l1_cm', 'head_inf_cm']:
        assert all(b[metric] < a[metric] for a, b in zip(errors[-4:], errors[-3:]))
    profiles.append({
        'profile': profile,
        'initial_head_cm': -123.0 if profile <= 2 else -10.0,
        'initial_pond_cm': 0.0 if profile % 2 else 0.02,
        'short_grid_1_transfer_cm': float(short[0]['transfer_cm']),
        'short_grid_512_transfer_cm': float(short[-1]['transfer_cm']),
        'one_step_relative_difference_from_finest_percent':
            100 * abs(float(short[0]['transfer_cm']) - float(short[-1]['transfer_cm'])) /
            abs(float(short[-1]['transfer_cm'])),
        'last_transfer_difference_ratio': errors[-2]['transfer_difference_cm'] / errors[-1]['transfer_difference_cm'],
        'last_differences': errors[-1],
        'long_incomplete_grids': [{k: row[k] for k in ['steps', 'completed', 'stop_code', 'solver_status', 'solver_route']}
                                  for row in rr if row['window'] == '1' and row['steps'] != row['completed']],
    })
for opt, rr in [('O0', rows[:80]), ('O2', rows[80:])]:
    with (out / f'temporal_refinement_{opt}.csv').open('w') as stream:
        writer = csv.DictWriter(stream, fieldnames=fields)
        writer.writeheader()
        writer.writerows(rr)
(out / 'temporal_refinement_stops.csv').write_text(
    'marker,profile,window,steps,failed_step,failed_iterations,residual_inf_cm_per_day,head_update_inf_cm,capacity_min,capacity_max\n' +
    '\n'.join(stops[:34]) + '\n')
result = {
    'schema': 'swap5.top03.temporal_research.v1',
    'decision': 'SHORT_ONSET_REFINEMENT_OBSERVED__LONG_INTERVAL_NONLINEAR_RETRY_BLOCKER',
    'production_admission': False,
    'o0_o2_exact_identity_excluding_cpu': True,
    'profiles': profiles,
    'successive_short_grid_differences': differences,
    'maximum_reported_interval_ledger_residual_cm': max(abs(float(row['ledger_residual_cm'])) for row in rows),
    'scope': 'Four-node synthetic 3 cm column, fixed external head. Finest grid is a comparator, not ground truth.',
    'timing_scope': 'Local descriptive CPU only; no portable performance claim.',
    'raw_log_sha256': hashlib.sha256(log.read_bytes()).hexdigest(),
}
(out / 'TOP03_TEMPORAL_RESEARCH_RESULT.json').write_text(json.dumps(result, indent=2) + '\n')
print('TOP03_RESEARCH_ANALYSIS=PASS')
print(json.dumps(profiles, indent=2))
