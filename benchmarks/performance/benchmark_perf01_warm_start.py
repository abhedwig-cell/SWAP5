"""Alternating serial same-source warm/cold observations after physical screening."""
import argparse
import csv
import hashlib
import json
from pathlib import Path
import statistics
import subprocess
import sys
import time
from assess_perf01_weather import read,differences

ROOT=Path(__file__).resolve().parents[2]
ap=argparse.ArgumentParser(description=__doc__)
ap.add_argument('--cold-build',type=Path,required=True)
ap.add_argument('--warm-build',type=Path,required=True)
ap.add_argument('--output',type=Path,required=True)
args=ap.parse_args()
out=args.output.resolve();out.mkdir(parents=True,exist_ok=False)
builds={arm:json.loads((path/'BUILD.json').read_text()) for arm,path in [('cold',args.cold_build),('warm',args.warm_build)]}
assert builds['cold']['sources']==builds['warm']['sources']
assert builds['cold']['headcalc_sha256']==builds['warm']['headcalc_sha256']
assert builds['warm']['warm_start_option']
report={'status':'RUNNING','events':[],'cases':{},'source_commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
        'builds':builds,'budget_cm':.001,'rainfall_mm':{'1':227,'4':908}}
def save():(out/'RESULT.json').write_text(json.dumps(report,indent=2)+'\n')
save()
for rain in [4,1]:
    records={};daily={}
    for repeat in range(3):
        for arm in (['cold','warm'] if repeat%2==0 else ['warm','cold']):
            target=out/f'{rain}x-{repeat}-{arm}'
            build=args.cold_build if arm=='cold' else args.warm_build
            command=[sys.executable,str(ROOT/'benchmarks/performance/run_perf01_warm_weather.py'),
                     '--build',str(build),'--output',str(target),'--rain',str(rain)]
            start=time.monotonic();result=subprocess.run(command,capture_output=True,timeout=150)
            label=f'{rain}x-{repeat}-{arm}'
            for stream in ['stdout','stderr']:(out/(label+'.'+stream)).write_bytes(getattr(result,stream))
            report['events'].append({'command':command,'returncode':result.returncode,'seconds':time.monotonic()-start})
            save();result.check_returncode()
            metrics,rows=read(target/'native');records[arm,repeat]=metrics;daily[arm,repeat]=rows
            assert metrics['max_gross_daily_closure_mm']<1e-8
            if repeat:
                assert [{k:v for k,v in r.items() if k!='core_cpu_s'} for r in rows]==[
                  {k:v for k,v in r.items() if k!='core_cpu_s'} for r in daily[arm,0]],'repeat physical/work drift'
        delta=differences(daily['warm',repeat],daily['cold',repeat])
        assert delta['storage_mm']['max_daily_abs']<=.01
        assert abs(delta['runoff_mm']['total_difference'])<=.05
        assert abs(delta['bottom_mm']['total_difference'])<=.05
        assert all(delta[k]['max_daily_abs']<1e-10 for k in ['transpiration_mm','biomass','lai'])
    case={'warm_minus_cold':delta,'arms':{}}
    for arm in ['cold','warm']:
        native=[records[arm,i] for i in range(3)]
        case['arms'][arm]={'cpu_seconds':[r['user_seconds'] for r in native],
          'median_cpu_seconds':statistics.median(r['user_seconds'] for r in native),
          'work':native[0]['work'],'max_gross_daily_closure_mm':max(r['max_gross_daily_closure_mm'] for r in native),
          'day84_core_cpu_seconds':[daily[arm,i][83]['core_cpu_s'] for i in range(3)],
          'day84_headcalc_calls':daily[arm,0][83]['headcalc_calls'],
          'totals':native[0]['totals']}
    case['warm_over_cold_cpu']=case['arms']['warm']['median_cpu_seconds']/case['arms']['cold']['median_cpu_seconds']
    report['cases'][str(rain)]=case;save()
report.update(status='PAIRED_SAME_SOURCE_WARM_COLD_PHYSICAL_SCREEN_PASS',
              performance_claim='Three alternating serial pairs per rainfall on this host; not portable timings or canonical admission.')
save()
print(json.dumps({'status':report['status'],'cases':{rain:{'cold_cpu':case['arms']['cold']['median_cpu_seconds'],
 'warm_cpu':case['arms']['warm']['median_cpu_seconds'],'warm_over_cold':case['warm_over_cold_cpu']} for rain,case in report['cases'].items()}}))
