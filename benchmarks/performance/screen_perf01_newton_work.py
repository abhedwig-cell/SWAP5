"""Retain every controlled Newton-policy arm and independently screen its water."""
import argparse
import json
from pathlib import Path
import subprocess
import sys
import time
from assess_perf01_weather import read, differences

ROOT = Path(__file__).resolve().parents[2]
ap = argparse.ArgumentParser(description=__doc__)
ap.add_argument('--parent', type=Path, required=True)
ap.add_argument('--baseline', type=Path, required=True)
ap.add_argument('--output', type=Path, required=True)
a = ap.parse_args()
out = a.output.resolve()
out.mkdir(parents=True, exist_ok=False)
report = dict(status='RUNNING', production_changed=False, events=[], builds={}, cases={})
def save():
    (out / 'RESULT.json').write_text(json.dumps(report, indent=2) + '\n')
def run(label, command):
    start = time.monotonic()
    try:
        r = subprocess.run(list(map(str, command)), capture_output=True, timeout=180)
        rc, stdout, stderr = r.returncode, r.stdout, r.stderr
    except subprocess.TimeoutExpired as e:
        rc, stdout, stderr = 124, e.stdout or b'', e.stderr or b''
    for name, raw in [('stdout', stdout), ('stderr', stderr)]:
        (out / (label + '.' + name)).write_bytes(raw)
    report['events'].append(dict(label=label, command=list(map(str, command)), returncode=rc, seconds=time.monotonic()-start))
    save()
    return rc
builds = {'baseline': a.baseline.resolve()}
for variant in ['cap12', 'cap8', 'linefail']:
    builds[variant] = out / ('build-' + variant)
    assert run('build-' + variant, [sys.executable, ROOT / 'benchmarks/performance/relink_perf01_newton_work.py',
        '--build', a.parent, '--output', builds[variant], '--variant', variant]) == 0
report['builds'] = {k: str(p) for k, p in builds.items()}
for rain in [4, 1]:
    baseline_rows = None
    for variant, build in builds.items():
        label = f'{rain}x-{variant}'
        folder = out / label
        rc = run(label, [sys.executable, ROOT / 'benchmarks/performance/run_perf01_warm_weather.py',
            '--build', build, '--output', folder, '--rain', rain])
        entry = dict(returncode=rc, complete=False, screen_pass=False)
        if rc == 0:
            metrics, rows = read(folder / 'native')
            if variant == 'baseline':
                baseline_rows = rows
            delta = differences(rows, baseline_rows)
            passed = (metrics['max_gross_daily_closure_mm'] < 1e-8 and
                delta['storage_mm']['max_daily_abs'] <= .01 and
                all(abs(delta[k]['total_difference']) <= .05 for k in ['runoff_mm', 'bottom_mm']) and
                all(delta[k]['max_daily_abs'] <= 1e-10 for k in ['biomass', 'lai', 'transpiration_mm']))
            entry.update(complete=True, screen_pass=passed, differences=delta, user_seconds=metrics['user_seconds'],
                work=metrics['work'], max_gross_daily_closure_mm=metrics['max_gross_daily_closure_mm'],
                totals=metrics['totals'], day84=rows[83])
        report['cases'][label] = entry
        save()
        print(json.dumps(dict(case=label, **{k:v for k,v in entry.items() if k not in ['totals', 'differences', 'day84']})), flush=True)
report['status'] = 'CONTROLLED_SCREEN_COMPLETE'
report['promising'] = [v for v in ['cap12', 'cap8', 'linefail'] if all(
    report['cases'][f'{rain}x-{v}']['screen_pass'] and
    report['cases'][f'{rain}x-{v}'].get('user_seconds', float('inf')) < report['cases'][f'{rain}x-baseline']['user_seconds']
    for rain in [4, 1])]
save()
print(json.dumps(dict(status=report['status'], promising=report['promising'])))
