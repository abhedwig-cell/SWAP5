"""Serial paired observations of the actual typed default-OFF production option."""
import argparse
import json
from pathlib import Path
import statistics
import subprocess
import sys
import time
from assess_perf01_weather import read, differences

ROOT = Path(__file__).resolve().parents[2]
ap = argparse.ArgumentParser(description=__doc__)
ap.add_argument('--baseline', type=Path, required=True)
ap.add_argument('--candidate', type=Path, required=True)
ap.add_argument('--output', type=Path, required=True)
a = ap.parse_args()
out = a.output.resolve()
out.mkdir(parents=True, exist_ok=False)
builds = {'baseline': a.baseline.resolve(), 'candidate': a.candidate.resolve()}
meta = {k: json.loads((p/'BUILD.json').read_text()) for k,p in builds.items()}
assert meta['baseline']['sources'] == meta['candidate']['sources']
assert meta['baseline']['headcalc_sha256'] == meta['candidate']['headcalc_sha256']
assert all(m['observe_work'] for m in meta.values())
report = dict(status='RUNNING', events=[], cases={}, builds=meta, production_changed=True, typed_line_search_option=True)
def save():
    (out/'RESULT.json').write_text(json.dumps(report, indent=2)+'\n')
for rain in [4,1]:
    records, daily = {}, {}
    for repeat in range(3):
        for arm in (['baseline','candidate'] if repeat%2==0 else ['candidate','baseline']):
            label = f'{rain}x-{repeat}-{arm}'
            command = [sys.executable, str(ROOT/'benchmarks/performance/run_perf01_warm_weather.py'),
                       '--build', str(builds[arm]), '--output', str(out/label), '--rain', str(rain)]
            start = time.monotonic()
            r = subprocess.run(command, capture_output=True, timeout=150)
            for stream in ['stdout','stderr']:
                (out/(label+'.'+stream)).write_bytes(getattr(r,stream))
            report['events'].append(dict(command=command, returncode=r.returncode, seconds=time.monotonic()-start))
            save()
            r.check_returncode()
            metrics, rows = read(out/label/'native')
            work = [list(map(int,line.split()[1:])) for line in (out/label/'native/stdout').read_text().splitlines()
                    if line.startswith('NEWTON_WORK')]
            assert len(work)==97 and [w[0]for w in work]==list(range(1,98))
            metrics['observed_work'] = dict(zip(['jacobians','backtracks','solver_rejections'],
                                               [sum(w[i]for w in work)for i in [1,2,3]]))
            metrics['observed_day84'] = work[83]
            records[arm,repeat], daily[arm,repeat] = metrics, rows
            if repeat:
                assert [{k:v for k,v in row.items()if k!='core_cpu_s'}for row in rows] == [
                    {k:v for k,v in row.items()if k!='core_cpu_s'}for row in daily[arm,0]]
                assert metrics['observed_work']==records[arm,0]['observed_work']
        delta = differences(daily['candidate',repeat], daily['baseline',repeat])
        assert delta['storage_mm']['max_daily_abs']<=.01
        assert all(abs(delta[k]['total_difference'])<=.05 for k in ['runoff_mm','bottom_mm'])
        assert all(delta[k]['max_daily_abs']<=1e-10 for k in ['biomass','lai','transpiration_mm'])
    case = dict(differences=delta, arms={})
    for arm in builds:
        native = [records[arm,i] for i in range(3)]
        case['arms'][arm] = dict(cpu_seconds=[r['user_seconds']for r in native],
            median_cpu_seconds=statistics.median(r['user_seconds']for r in native),
            work=native[0]['work'], observed_work=native[0]['observed_work'], observed_day84=native[0]['observed_day84'],
            max_gross_daily_closure_mm=max(r['max_gross_daily_closure_mm']for r in native),
            day84_core_cpu_seconds=[daily[arm,i][83]['core_cpu_s']for i in range(3)])
    case['candidate_over_baseline_cpu'] = case['arms']['candidate']['median_cpu_seconds']/case['arms']['baseline']['median_cpu_seconds']
    report['cases'][str(rain)] = case
    save()
    print(json.dumps(dict(rain=rain, **case)), flush=True)
report['status'] = 'SERIAL_PAIRED_NEWTON_WORK_PHYSICAL_SCREEN_PASS'
save()
