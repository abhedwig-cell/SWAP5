"""Read-only joint-profile diagnostics; never substitutes for qualification.

Usage: python analyze_fpe_a28_joint_surface.py /tmp output.json
Requires a28-{joint,joint-final,joint-temporal,head-policy}-live.{json,log}.
"""
import json
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
names = ('joint', 'joint-final', 'joint-temporal', 'head-policy')
data = {n: json.loads((root / f'a28-{n}-live.json').read_text()) for n in names}
logs = {n: (root / f'a28-{n}-live.log').read_text() for n in names}
number = r'[+-]?(?:\d+\.?\d*|\.\d+)(?:[EeDd][+-]?\d+)?'
pattern = re.compile(r'(\w+)=\s*(' + number + r')')

def records(log, tag):
    return [{k: float(v.replace('D', 'E')) for k, v in pattern.findall(line)}
            for line in log.splitlines() if tag in line]

def common(row):
    return {k: v for k, v in row.items() if k not in ('pond', 'soil_matrix')}

reference = data['joint']['rows']
assert len(reference) == 19
for name in ('joint-final', 'joint-temporal'):
    assert [common(r) for r in data[name]['rows']] == reference
    assert data[name]['failed_window'] == 20
receipts = records(logs['joint-final'], 'A28_JOINT_POND_RECEIPT')
assert receipts
max_closure = max(abs((10. - r['pref']) * r['dt'] + r['qtop'] * r['dt']
                      + r['old'] - r['new'] - r['runoff']) for r in receipts)
assert max_closure <= 1e-12
joint_pond = [r for r in receipts if r['old'] > 0. and r['pref'] > 0.]
assert joint_pond, 'must exercise ponded second-half plus nonzero preferential input'
components = records(logs['joint-temporal'], 'A28_TEMPORAL_COMPONENTS')
assert components
last = components[-1]
last.pop('full_heads', None)  # Vector, not the scalar captured by generic parser.
last.pop('half_heads', None)  # Complete vectors remain in the archived raw log.
assert last['head'] > 1e-5 and last['matrix'] < 1e-5
assert max(last[k] for k in ('pond', 'groundwater', 'mb', 'endpoint')) < 1e-5
failures = records(logs['head-policy'], 'A28_FD_STABILITY_FAIL')
assert len(data['head-policy']['rows']) == 15 and failures
assert failures[-1]['relative_spread'] > .001

# Descriptive shorter overlap only: deliberately not the prospective >=19 gate.
prefix = data['head-policy']['rows']
metrics = {'head_difference_cm': 0., 'matrix_pond_difference_cm': 0.,
           'flux_floored_relative_difference': 0.}
for a, b in zip(reference, prefix):
    metrics['head_difference_cm'] = max(metrics['head_difference_cm'],
                                       abs(a['head_m'] - b['head_m']) * 100.)
    for i in range(2):
        metrics['matrix_pond_difference_cm'] = max(metrics['matrix_pond_difference_cm'],
                                                  abs(a['matrix'][i] - b['matrix'][i]))
        qa, qb = a[f'q{i+1}'], b[f'q{i+1}']
        metrics['flux_floored_relative_difference'] = max(metrics['flux_floored_relative_difference'],
                                                          abs(qa - qb) / max(abs(qa), 1e-9))
result = {
    'decision': 'COUPLED_RFM_BLOCKED', 'physical_profile_admitted': False,
    'strict_native_completed_windows': 19, 'required_windows': 24,
    'final_and_temporal_replay_common_rows_bitwise': True,
    'positive_pond_candidate_receipts': len(receipts),
    'positive_old_pond_and_preferential_receipts': len(joint_pond),
    'max_independent_surface_closure_cm': max_closure,
    'last_temporal_components': last,
    'head_excursion_cm': abs(reference[-1]['head_m'] - .5) * 100.,
    'required_head_excursion_cm': .1,
    'max_accepted_rfm_storage_cm': max(max(r['rfm']) for r in reference),
    'required_rfm_storage_floor_cm': 1e-10,
    'accepted_endpoint_pond_cm': max(max(r['pond']) for r in data['joint-final']['rows']),
    'head_policy_pilot': {'status': 'REJECTED_FD_STABILITY_WINDOW16',
                          'failure': failures[-1], 'overlap_windows': len(prefix),
                          'descriptive_prefix_only': metrics,
                          'prospective_19_window_gate_completed': False},
    'production_speedup_claim': False,
}
Path(sys.argv[2]).write_text(json.dumps(result, indent=2) + '\n')
print(json.dumps(result, indent=2))
