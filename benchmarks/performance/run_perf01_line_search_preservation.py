"""Execute unchanged current application assertions after complete fresh builds."""
import argparse
import json
from pathlib import Path
import subprocess
import sys
import time

ROOT=Path(__file__).resolve().parents[2]
ap=argparse.ArgumentParser(description=__doc__)
ap.add_argument('--stage',choices=['column','weather','nut'],required=True)
ap.add_argument('--optimization',choices=['O0','O2'])
ap.add_argument('--resume',action='store_true')
a=ap.parse_args();prefix=Path('/tmp/perf01-lsr-')
events=[];ledger=Path('/tmp/perf01-lsr-controller-'+a.stage+(('-'+a.optimization)if a.optimization else '')+'.json')
if a.resume and ledger.exists():events=json.loads(ledger.read_text())['events']
def path(label):return Path(str(prefix)+label)
def wait_ready(p,seconds=1200):
    start=time.monotonic()
    while not p.exists():
        if time.monotonic()-start>seconds:raise TimeoutError(str(p))
        time.sleep(2)
def run(script,args,label):
    if a.resume and any(e['label']==label and e['returncode']==0 for e in events):return
    if a.resume and '--output'in args:
        target=Path(args[args.index('--output')+1])
        if target.exists():target.rename(target.with_name(target.name+'-retained-incomplete'))
    command=[sys.executable,'-B',str(ROOT/script),*map(str,args)]
    started=time.monotonic();r=subprocess.run(command,cwd=ROOT,capture_output=True)
    for stream in ['stdout','stderr']:path('controller-'+label+'.'+stream).write_bytes(getattr(r,stream))
    events.append(dict(command=command,returncode=r.returncode,seconds=time.monotonic()-started,label=label))
    ledger.write_text(json.dumps(dict(stage=a.stage,events=events),indent=2)+'\n')
    r.check_returncode()
if a.stage=='column':
    for kind in ['column','crop_column']:
        for opt in ['O0','O2']:wait_ready(path(kind+'-'+opt)/'build-complete.json')
    build_args=[x for opt in ['O0','O2']for x in ['--build-'+opt,path('column-'+opt)]]
    for script,label in [('tests/nut-sol/test_column_input.py','incumbent-final'),
                         ('tests/nut-sol/qualify_swp_reader.py','chemistry'),('tests/nut-sol/qualify_swp_water.py','water')]:
        run(script,[*build_args,'--output',path(label)],label)
    daily_args=[x for opt in ['O0','O2']for x in ['--reader-'+opt,Path('/tmp/perf01-compose-daily-'+opt+'/swap5_read_daily'),
        '--column-'+opt,path('column-'+opt)/'swap5_solute_column']]
    for script,label in [('qualify_swp_daily','daily-proof'),('qualify_swp_etref','etref-final')]:
        run('tests/nut-sol/'+script+'.py',[*daily_args,'--output',path(label)],label)
    crop_args=[x for opt in ['O0','O2']for x in ['--crop-reader-'+opt,Path('/tmp/perf01-compose-crop-'+opt+'/swap5_read_crop'),
        '--root-reader-'+opt,Path('/tmp/perf01-compose-root-'+opt+'/swap5_read_root'),'--column-'+opt,path('crop_column-'+opt)/'swap5_solute_column']]
    baseline=[x for opt in ['O0','O2']for x in ['--baseline-column-'+opt,path('column-'+opt)/'swap5_solute_column']]
    run('tests/nut-sol/qualify_crop_root_joint.py',[*crop_args,*baseline,'--output',path('crop-joint-final')],'crop-joint-final')
    run('tests/nut-sol/qualify_root_substep_daily.py',[*crop_args,'--output',path('root-substep-daily')],'root-substep-daily')
    args=[x for opt in ['O0','O2']for x in ['--column-'+opt,path('crop_column-'+opt)/'swap5_solute_column']]
    for script,label in [('qualify_crop_root_transaction','crop-transaction'),('qualify_root_substep_transaction','root-substep-transaction')]:
        run('tests/nut-sol/'+script+'.py',[*args,'--output',path(label)],label)
    run('tests/fmig431/qualify_weather_canonical_trace.py',
        ['--column-O0',path('crop_column-O0'),'--column-O2',path('crop_column-O2'),'--output',path('trace')],'trace')
elif a.stage=='weather':
    assert a.optimization
    opt=a.optimization;base=path('weather-'+opt);wait_ready(base/'BUILD.json')
    while json.loads((base/'BUILD.json').read_text())['status']!='BUILT':time.sleep(2)
    for script,label in [('qualify_weather_warm_start','focused'),('qualify_weather_surface_repair','original-weather'),('preserve_weather_surface_default','default')]:
        run('tests/fmig431/'+script+'.py',['--build',base,'--output',path(label+'-'+opt)],label+'-'+opt)
    run('benchmarks/performance/select_perf01_line_search_retry.py',['--build',base,'--output',path('on-build-'+opt)],'on-build-'+opt)
    run('benchmarks/performance/relink_perf01_warm_weather.py',['--build',base,'--output',path('warm-build-'+opt)],'warm-build-'+opt)
    for mode,build in [('off',base),('on',path('on-build-'+opt)),('warm',path('warm-build-'+opt))]:
        for rain in [4,1]:
            target=path(('season'if mode=='off'else mode+'-season')+'-'+opt+'-'+str(rain)+'x')
            run('benchmarks/performance/run_perf01_warm_weather.py',['--build',build,'--output',target,'--rain',rain],mode+'-'+opt+'-'+str(rain)+'x')
elif a.stage=='nut':
    wait_ready(path('nut-cold')/'result.json')
    for name in ['thermal','calendar']:
        run('tests/nut-output/run_'+name+'_output.py',['--cold',path('nut-cold'),'--output',path('nut-'+name)],'nut-'+name)
    run('tests/nut-output/run_harvest_output.py',['--cold',path('nut-cold'),'--thermal',path('nut-thermal'),'--output',path('nut-harvest')],'nut-harvest')
    run('tests/nut-output/run_saved_residue.py',['--output',path('saved-component')],'saved-component')
    run('tests/nut-output/run_saved_output.py',['--cold',path('nut-cold'),'--output',path('saved-physical')],'saved-physical')
print('CURRENT_'+a.stage.upper()+'_PRESERVATION_COMPLETE')
