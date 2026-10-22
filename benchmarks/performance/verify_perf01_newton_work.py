"""Replay actual original physical screening and bound the generated experiment."""
import hashlib
import io
import json
from pathlib import Path
import runpy
import sys
import tarfile

ROOT = Path(__file__).resolve().parents[2]
STEM = ROOT / 'benchmarks/performance/PERF01_NEWTON_WORK_20261022_EVIDENCE'
sha = lambda b: hashlib.sha256(b).hexdigest()
def require(ok, why):
    if not ok:
        raise ValueError(why)
class VirtualPath:
    def __init__(self, files, path):
        self.files, self.path = files, path
    def __truediv__(self, name):
        return VirtualPath(self.files, self.path + '/' + name)
    def read_bytes(self):
        return self.files[self.path]
    def read_text(self):
        return self.read_bytes().decode()
    def open(self):
        return io.StringIO(self.read_text())
    def __str__(self):
        return self.path
def capsule():
    index = json.loads(STEM.with_suffix('.index.json').read_text())
    raw = STEM.with_suffix('.tar.xz').read_bytes()
    require(sha(raw)==index['sha256'] and len(raw)==index['bytes'], 'capsule identity')
    with tarfile.open(fileobj=io.BytesIO(raw), mode='r:xz') as t:
        ms=t.getmembers()
        require(len(ms)==index['members']==len({m.name for m in ms}), 'capsule census')
        require(all(m.isfile() and not Path(m.name).is_absolute() and '..' not in Path(m.name).parts for m in ms), 'unsafe member')
        return {m.name:t.extractfile(m).read() for m in ms}
def verify(files, reader=lambda p:(ROOT/p).read_bytes()):
    js=lambda p:json.loads(files[p])
    inventory=js('MANIFEST.json')
    require(set(inventory)==set(files)-{'MANIFEST.json'} and
            all(sha(files[p])==h for p,h in inventory.items()), 'raw inventory')
    summary=js('SUMMARY.json')
    for p,h in summary['input_sha256'].items():
        require(sha(reader(p))==h, 'current research input '+p)
    baseline=files['paired-build-baseline/headcalc_experiment.f90'].decode()
    candidate=files['paired-build-candidate/headcalc_experiment.f90'].decode()
    anchor=' 1    continue\n\n!     check on convergence of solution'
    expected=baseline.replace(anchor,' 1    continue\n'+
        '      if (itry > MaxBackTr .and. sump >= sumold .and. Fmax >= CritDevBalCp) exit\n'+
        '\n!     check on convergence of solution',1)
    require(baseline.count(anchor)==1 and candidate==expected, 'unbounded generated solver change')
    require(files['paired-build-baseline/driver.f90']==files['paired-build-candidate/driver.f90'], 'different physical driver')
    oldargv=sys.argv
    try:
        sys.argv=['assess_perf01_weather.py','/unused']
        assess=runpy.run_path(str(ROOT/'benchmarks/performance/assess_perf01_weather.py'))
    finally:
        sys.argv=oldargv
    read, diff=assess['read'],assess['differences']
    screen=js('screen/RESULT.json')
    require(screen['status']=='CONTROLLED_SCREEN_COMPLETE' and len(screen['cases'])==8, 'screen incomplete')
    for case, receipt in screen['cases'].items():
        require(receipt['complete'] and receipt['screen_pass'] and receipt['returncode']==0, 'failed screening arm')
        metrics, rows=read(VirtualPath(files,'screen/'+case+'/native'))
        require(metrics['work']==receipt['work'], 'screen work receipt')
    paired=js('paired/RESULT.json')
    require(paired['status']=='SERIAL_PAIRED_NEWTON_WORK_PHYSICAL_SCREEN_PASS' and
            len(paired['events'])==12 and all(e['returncode']==0 for e in paired['events']), 'paired incomplete')
    for rain in [4,1]:
        reference={}
        for repeat in range(3):
            current={}
            for arm in ['baseline','candidate']:
                prefix=f'paired/{rain}x-{repeat}-{arm}/native'
                metrics, rows=read(VirtualPath(files,prefix))
                current[arm]=rows
                require(metrics['user_seconds']==paired['cases'][str(rain)]['arms'][arm]['cpu_seconds'][repeat], 'paired CPU receipt')
                physical=[{k:v for k,v in r.items()if k!='core_cpu_s'}for r in rows]
                if repeat:
                    require(physical==reference[arm], 'repeat drift')
                reference[arm]=physical
                work=[list(map(int,l.split()[1:]))for l in files[prefix+'/stdout'].decode().splitlines()if l.startswith('NEWTON_WORK')]
                require(len(work)==97 and [w[0]for w in work]==list(range(1,98)), 'missing Newton work')
                require([sum(w[i]for w in work)for i in [1,2,3]]==list(paired['cases'][str(rain)]['arms'][arm]['observed_work'].values()), 'Newton receipt')
            d=diff(current['candidate'],current['baseline'])
            require(d==paired['cases'][str(rain)]['differences'], 'paired physical receipt')
            require(d['storage_mm']['max_daily_abs']<=.01 and all(abs(d[k]['total_difference'])<=.05 for k in ['runoff_mm','bottom_mm']) and
                    all(d[k]['max_daily_abs']<=1e-10 for k in ['biomass','lai','transpiration_mm']), 'physical screen')
        _,checked=read(VirtualPath(files,f'checked-{rain}x/native'))
        _,opt=read(VirtualPath(files,f'screen/{rain}x-linefail/native'))
        require([{k:v for k,v in r.items()if k!='core_cpu_s'}for r in checked]==
                [{k:v for k,v in r.items()if k!='core_cpu_s'}for r in opt], 'O0/O2 drift')
    require(files['wet-restart/native/stdout']==files['screen/4x-linefail/native/stdout'], 'wet35 restart drift')
    require(b'WEATHER_SURFACE_ROLLBACK_PASS' in files['rollback/stdout'] and not files['rollback/stderr'], 'rollback')
    for opt in ['O0','O2']:
        direct=js('direct-'+opt+'/RESULT.json')
        require(direct['status']=='ORIGINAL_DIRECT_CONTRACTS_PASS' and len(direct['events'])==8 and
                all(e['returncode']==0 for e in direct['events']), 'original direct controls')
    return dict(status='BOUNDED_GENERATED_NEWTON_RESEARCH_QUALIFIED', production_changed=False,
                paired_cases=paired['cases'], current_source_bound=True, canonically_admitted_numerical_policy=False)
def self_test(files):
    controls=[]
    for p in ['paired/4x-0-candidate/native/stdout','screen/4x-cap8/native/RESULT.json',
              'wet-restart/native/stdout','paired-build-candidate/headcalc_experiment.f90']:
        bad=dict(files);bad.pop(p)
        try:
            verify(bad)
        except (ValueError,KeyError,AssertionError):
            controls.append('missing:'+p)
        else:
            raise AssertionError('accepted incomplete '+p)
    path='src/legacy/b1_10_port/headcalc.f90'
    try:
        verify(files,lambda p:(ROOT/p).read_bytes()+(b'!' if p==path else b''))
    except ValueError:
        controls.append('changed production source')
    else:
        raise AssertionError('accepted changed production source')
    return controls
if __name__=='__main__':
    f=capsule()
    print(json.dumps(self_test(f) if '--self-test' in sys.argv else verify(f),indent=2))
