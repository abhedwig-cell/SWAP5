"""Freeze bounded input observations, provenance and any failed setup."""
import argparse
import hashlib
import io
import json
from pathlib import Path
import shutil
import tarfile
import tempfile
import time
from verify_perf01_retry_tolerance import verify

ROOT = Path(__file__).resolve().parents[2]
ap = argparse.ArgumentParser(description=__doc__)
ap.add_argument('--study',type=Path,required=True)
ap.add_argument('--initial',type=Path)
ap.add_argument('--build-prefix',type=Path,required=True)
ap.add_argument('--name',choices=['PERF01_RETRY_TOLERANCE_20261023','PERF01_RETRY_ROOT_STRESS_20261023'],default='PERF01_RETRY_TOLERANCE_20261023')
ap.add_argument('--controller-prefix',type=Path)
args = ap.parse_args()
study = args.study.resolve()
for opt in ['O0','O2']:
    dest = study/'builds'/opt
    dest.mkdir(parents=True,exist_ok=True)
    source = Path(str(args.build_prefix)+'-'+opt)
    for name in ['BUILD.json','driver.f90','grid_stubs.f90','observed_bootstrap.f90','observed_serial_runtime.f90']:
        shutil.copy2(source/name,dest/name)
start = time.monotonic()
assessment = verify(study)
assessment['raw_replay_seconds'] = time.monotonic()-start
# Meaningful rejection controls on a private copy, retaining the original raw files.
controls = []
with tempfile.TemporaryDirectory() as temp:
    copy = Path(temp)/'study'
    shutil.copytree(study,copy,ignore=shutil.ignore_patterns('weather'))
    selected_controls = [
        ('missing native stdout','4x-0.001-r0/native/stdout','missing'),
        ('changed physical bytes','4x-0.01-r0/native/daily.csv','bytes'),
        ('changed observer','builds/O2/observed_bootstrap.f90','bytes'),
        ('missing native event','RESULT.json','event'),
        ('changed median','RESULT.json','median')]
    if assessment['profile'] == 'sensitive':
        selected_controls.append(('changed input profile','RESULT.json','profile'))
    for label,path,kind in selected_controls:
        target = copy/path
        raw = target.read_bytes()
        if kind == 'missing': target.unlink()
        elif kind == 'bytes': target.write_bytes(raw+b'!corruption\n')
        else:
            data = json.loads(raw)
            if kind == 'event': data['events'].pop()
            elif kind == 'median': data['cases']['4']['0.01']['median_cpu_seconds'] += 1
            else: data['profile'] = 'original'
            target.write_text(json.dumps(data))
        try:
            verify(copy)
        except (AssertionError,KeyError,FileNotFoundError,ValueError):
            controls.append(label)
        else:
            raise AssertionError('accepted '+label)
        finally:
            target.write_bytes(raw)
assert len(controls) == (6 if assessment['profile'] == 'sensitive' else 5)
files = {}
def collect(base,prefix):
    for path in base.rglob('*'):
        if path.is_file() and path.name != 'weather':
            files[prefix+path.relative_to(base).as_posix()] = path.read_bytes()
collect(study,'')
if args.initial:
    collect(args.initial.resolve(),'initial-failed-setup/')
    collect(Path('/tmp/perf01-retry-accuracy-initial-builds'),'initial-builds/')
    for opt in ['O0','O2']:
        collect(Path('/tmp/perf01-retry-accuracy-'+opt),'build-log-'+opt+'/')
        # Native compiler artifacts are reproducible, not part of the raw text proof.
        for name in list(files):
            if name.startswith('build-log-'+opt+'/') and name.endswith(('.o','.mod')):
                del files[name]
for name in ['build_perf01_weather_surface.py','select_perf01_line_search_retry.py',
             'study_perf01_retry_tolerance.py','verify_perf01_retry_tolerance.py','seal_perf01_retry_tolerance.py',
             'assess_perf01_weather.py','run_perf01_weather.py','run_perf01_weather_bound.py','run_perf01_warm_weather.py']:
    files['recipes/'+name] = (ROOT/'benchmarks/performance'/name).read_bytes()
if args.controller_prefix:
    controller_paths = [Path(str(args.controller_prefix)+'.'+s) for s in ['stdout','stderr']]
else:
    controller_paths = [Path('/tmp')/name for name in ['perf01-retry-accuracy-study.stdout','perf01-retry-accuracy-study.stderr',
        'perf01-retry-accuracy-final-study.stdout','perf01-retry-accuracy-final-study.stderr']]
for path in controller_paths:
    files['controller/'+path.name] = path.read_bytes()
files['ASSESSMENT.json'] = (json.dumps(assessment,indent=2)+'\n').encode()
files['CONTROLS.json'] = (json.dumps(controls,indent=2)+'\n').encode()
files['MANIFEST.json'] = (json.dumps({p:hashlib.sha256(raw).hexdigest() for p,raw in sorted(files.items())},indent=2)+'\n').encode()
archive = ROOT/('benchmarks/performance/'+args.name+'_EVIDENCE.tar.xz')
with tarfile.open(archive,'w:xz') as tar:
    for name,raw in sorted(files.items()):
        info = tarfile.TarInfo(name); info.size = len(raw)
        tar.addfile(info,io.BytesIO(raw))
raw = archive.read_bytes()
index = dict(sha256=hashlib.sha256(raw).hexdigest(),bytes=len(raw),members=len(files))
archive.with_name(archive.name.removesuffix('.tar.xz')+'.index.json').write_text(json.dumps(index,indent=2)+'\n')
summary = dict(assessment=assessment,controls=controls,evidence=dict(path=str(archive.relative_to(ROOT)),**index))
(ROOT/('benchmarks/performance/'+args.name+'_EVIDENCE.json')).write_text(json.dumps(summary,indent=2)+'\n')
print(json.dumps(summary,indent=2))
