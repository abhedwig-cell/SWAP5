"""Serial input-accuracy experiment on the admitted explicit retry route."""
import argparse
import atexit
import hashlib
import json
from pathlib import Path
import statistics
import subprocess
import sys
import time
from assess_perf01_weather import read, differences, same_physics

ROOT = Path(__file__).resolve().parents[2]
ap = argparse.ArgumentParser(description=__doc__)
ap.add_argument('--build', type=Path, required=True)
ap.add_argument('--checked-build', type=Path, required=True)
ap.add_argument('--output', type=Path, required=True)
a = ap.parse_args()
out = a.output.resolve()
out.mkdir(parents=True, exist_ok=False)
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
builds = {'O2': a.build.resolve(), 'O0': a.checked_build.resolve()}
metadata = {}
for opt, folder in builds.items():
    meta = json.loads((folder/'BUILD.json').read_text())
    assert meta['status'] == 'BUILT' and meta['weather_line_search_retry'] and meta['observe_work']
    assert sha(folder/'weather') == meta['executable_sha256']
    overrides = {'tests/fsi/fsi04_real_headcalc_stubs.f90': 'grid_stubs.f90',
        'src/runtime/mod_fmr_serialized_multiswap_runtime.f90': 'observed_serial_runtime.f90',
        'src/runtime/mod_fmr_production_application_bootstrap.f90': 'observed_bootstrap.f90'}
    for path, digest in meta['sources'].items():
        assert sha(folder/overrides[path] if path in overrides else ROOT/path) == digest, path
    assert sha(ROOT/'src/legacy/b1_10_port/headcalc.f90') == meta['headcalc_sha256']
    metadata[opt] = meta
assert metadata['O0']['sources'] == metadata['O2']['sources']
report = dict(status='RUNNING', events=[], cases={}, builds=metadata,
    production_changed=False, retry_option=True, warm_start=False,
    source_tree=subprocess.check_output(['git', 'rev-parse', 'HEAD:src'], cwd=ROOT, text=True).strip(),
    accuracy_comparison='Existing local model-certificate head budgets, not equivalent-accuracy speedup')
def save():
    (out/'RESULT.json').write_text(json.dumps(report, indent=2)+'\n')
def retain_incomplete():
    if report['status'] == 'RUNNING':
        report['status'] = 'FAILED_OR_INTERRUPTED_STUDY_SEE_RAW_EVENTS'
        save()
atexit.register(retain_incomplete)
def run(opt, rain, budget, label, restart=False):
    command = [sys.executable, str(ROOT/'benchmarks/performance/run_perf01_warm_weather.py'),
        '--build', str(builds[opt]), '--output', str(out/label), '--rain', str(rain), '--budget', str(budget)]
    if restart:
        command.append('--restart')
    start = time.monotonic()
    result = subprocess.run(command, capture_output=True, timeout=150)
    for stream in ['stdout', 'stderr']:
        (out/(label+'.'+stream)).write_bytes(getattr(result, stream))
    report['events'].append(dict(label=label, command=command, returncode=result.returncode,
        seconds=time.monotonic()-start))
    save()
    result.check_returncode()
    metrics, rows = read(out/label/'native')
    work = [list(map(int, line.split()[1:])) for line in (out/label/'native/stdout').read_text().splitlines()
        if line.startswith('NEWTON_WORK')]
    assert len(work) == 97 and [r[0] for r in work] == list(range(1,98))
    metrics['newton_work'] = dict(zip(['jacobians','backtracks','solver_rejections'],
        [sum(r[i] for r in work) for i in [1,2,3]]))
    return metrics, rows, work
for rain in [4,1]:
    samples = {}
    for repeat in range(3):
        budgets = [.001, .003, .01]
        if repeat == 1:
            budgets.reverse()
        for budget in budgets:
            label = f'{rain}x-{budget:g}-r{repeat}'
            metrics, rows, work = run('O2', rain, budget, label)
            samples[budget,repeat] = metrics, rows, work
            if repeat:
                same_physics(rows, samples[budget,0][1])
                assert work == samples[budget,0][2]
            print(label, metrics['user_seconds'], flush=True)
    case = {}
    for budget in [.001,.003,.01]:
        m, rows, work = samples[budget,0]
        cpu = [samples[budget,i][0]['user_seconds'] for i in range(3)]
        case[str(budget)] = dict(cpu_seconds=cpu, median_cpu_seconds=statistics.median(cpu),
            work=m['work'], newton_work=m['newton_work'], totals=m['totals'],
            max_gross_daily_closure_mm=max(samples[budget,i][0]['max_gross_daily_closure_mm'] for i in range(3)),
            differences_vs_1e3=differences(rows,samples[.001,0][1]),
            day84_cpu_seconds=[samples[budget,i][1][83]['core_cpu_s'] for i in range(3)])
    # Checked optimization parity and actual close/reconstruct, outside timed pairs.
    for budget in [.001,.01]:
        _, checked, work = run('O0',rain,budget,f'{rain}x-{budget:g}-checked')
        same_physics(checked,samples[budget,0][1])
        assert work == samples[budget,0][2]
    _, restarted, work = run('O2',rain,.01,f'{rain}x-0.01-restart',True)
    same_physics(restarted,samples[.01,0][1])
    assert work == samples[.01,0][2]
    case['on_1e2_over_on_1e3_cpu'] = case['0.01']['median_cpu_seconds']/case['0.001']['median_cpu_seconds']
    report['cases'][str(rain)] = case
    save()
report['status'] = 'COMPLETE_BOUNDED_RETRY_ACCURACY_STUDY_O0_O2_RESTART_PASS'
save()
print(report['status'], flush=True)
