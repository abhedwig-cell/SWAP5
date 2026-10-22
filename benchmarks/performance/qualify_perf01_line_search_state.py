"""Actual OFF/ON wet reconstruction and original complete-state rollback."""
import json
from pathlib import Path
import subprocess
import sys
import time

ROOT=Path(__file__).resolve().parents[2]
P='/tmp/perf01-lsr-';events=[]
def run(command,label,cwd=ROOT):
    start=time.monotonic();r=subprocess.run(list(map(str,command)),cwd=cwd,capture_output=True,timeout=180)
    for stream in ['stdout','stderr']:Path(P+'state-'+label+'.'+stream).write_bytes(getattr(r,stream))
    events.append(dict(command=list(map(str,command)),returncode=r.returncode,seconds=time.monotonic()-start,label=label))
    Path(P+'state-controls.json').write_text(json.dumps(events,indent=2)+'\n')
    r.check_returncode();return r
weather=Path(P+'on-season-O2-4x/input/weather.999')
for enabled in [False,True]:
    base=Path(P+('on-build-O2'if enabled else'weather-O2'))
    prefix='on-'if enabled else''
    build=Path(P+prefix+'restart-build');target=Path(P+prefix+'restart-case')
    run([sys.executable,'-B',ROOT/'tests/fmig431/build_weather_surface_controls.py','--build',base,'--output',build,'--weather',weather,'--kind','wet-restart'],prefix+'restart-link')
    run([sys.executable,'-B',ROOT/'benchmarks/performance/run_perf01_warm_weather.py','--build',build,'--output',target,'--rain','4','--restart'],prefix+'restart-native')
    # Keep the standard native prefix used by the physical evidence checker.
    (target/'native').rename(Path(P+prefix+'restart-native'))
    expected=Path(P+('on-season'if enabled else'season')+'-O2-4x/native/stdout').read_bytes()
    assert Path(P+prefix+'restart-native/stdout').read_bytes()==expected
for enabled in [False,True]:
    base=Path(P+('on-build-O2'if enabled else'weather-O2'))
    prefix=''if enabled else'off-'
    build=Path(P+prefix+'rollback-build');target=Path(P+prefix+'rollback-native');target.mkdir()
    run([sys.executable,'-B',ROOT/'tests/fmig431/build_weather_surface_controls.py','--build',base,'--output',build,'--weather',weather,'--kind','rollback'],prefix+'rollback-link')
    r=run([build/'weather',weather,'.001','1','64','continuous','original'],prefix+'rollback-native',target)
    (target/'stdout').write_bytes(r.stdout);(target/'stderr').write_bytes(r.stderr)
    assert b'WEATHER_SURFACE_ROLLBACK_PASS'in r.stdout and not r.stderr
    (target/'RESULT.json').write_text(json.dumps(dict(status='PASS',returncode=r.returncode,option_enabled=enabled,control='Original21-word rollback, crop revision, private progress and absent receipt assertions'))+'\n')
Path(P+'warm-screen').mkdir()
for opt in ['O0','O2']:
    for rain in [1,4]:
        run([sys.executable,'-B',ROOT/'benchmarks/performance/assess_perf01_warm_start.py',
            '--cold',Path(P+f'season-{opt}-{rain}x/native'),'--warm',Path(P+f'warm-season-{opt}-{rain}x/native'),
            '--output',Path(P+f'warm-screen/{opt}-{rain}x.json')],f'warm-screen-{opt}-{rain}x')
print('CURRENT_TYPED_OFF_ON_WET_RESTART_ROLLBACK_AND_WARM_PRESERVATION_PASS')
