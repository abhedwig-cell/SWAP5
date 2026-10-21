"""Seal exact source, native observations, controls and unsuccessful prototypes."""
import argparse,hashlib,io,json,tarfile,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--root',type=Path,default=Path('/tmp'));ap.add_argument('--output',type=Path,required=True);a=ap.parse_args();a.output=a.output.resolve();base=a.root;files={};sha=lambda raw:hashlib.sha256(raw).hexdigest()
def add(name,path):
 raw=path.read_bytes();assert not raw.startswith(b'\x7fELF'),path
 assert name not in files,name;files[name]=raw
# All production inputs, including inactive dependencies, are source-bound.
b=json.loads((base/'perf01-weather-surface-final-v2-O2/BUILD.json').read_text())
for path in b['sources']:add('source/'+path,ROOT/path)
for path in ['src/legacy/b1_10_port/headcalc.f90','tests/fmig431/test_crop_file_weather_production.f90']:
 if 'source/'+path not in files:add('source/'+path,ROOT/path)
for pattern in ['benchmarks/performance/*weather_surface*.py','benchmarks/performance/*weather_surface*.inc','tests/fmig431/*weather_surface*.py','tests/fsi/test_weather_surface*.f90']:
 for p in ROOT.glob(pattern):add('source/'+str(p.relative_to(ROOT)),p)
for path in ['benchmarks/performance/run_perf01_weather.py','benchmarks/performance/assess_perf01_weather.py','benchmarks/performance/perf01_weather_main.inc','docs/science/PERF01_WEATHER_SURFACE_REPAIR.md']:
 if 'source/'+path not in files:add('source/'+path,ROOT/path)
for name in ['final-O0','final-v2-O2','final-restart-build','final-rollback-build','final-production-wet4','final-O0-wet4']:
 folder=base/({'final-restart-build':'weather-physical-restart-build','final-rollback-build':'weather-physical-rollback-build','final-production-wet4':'weather-physical-build','final-O0-wet4':'weather-physical-O0-build'}.get(name,'perf01-weather-surface-'+name))
 for p in folder.iterdir():
  if p.is_file() and (p.suffix in ('.f90','.json','.stdout','.stderr','.999') or p.name=='BUILD.json'):add('build/'+name+'/'+p.name,p)
for name in ['final97','final-O0-97','final-ref97','final-coarse97','final-mid97','final-loose97','final-restart97','final-rollback','final-strict97']:
 folder={'final97':'default97-native','final-O0-97':'O0-97','final-ref97':'ref97-native','final-coarse97':'coarse97-native','final-mid97':'middle97-native','final-loose97':'loose97-native','final-restart97':'restart97','final-rollback':'rollback','final-strict97':'strict97'}[name]
 for p in (base/('weather-physical-'+folder)).iterdir():
  if p.is_file():add('native/'+name+'/'+p.name,p)
for name in ['final-proof-O0','final-proof-O2','final-default-O0','final-default-O2']:
 folder=base/('weather-physical-'+name.removeprefix('final-').replace('proof-','qualification-'))
 for p in folder.rglob('*'):
  if p.is_file() and (p.suffix in ('.f90','.json','.stdout','.stderr')):add('controls/'+name+'/'+str(p.relative_to(folder)),p)
# Prior failed or censored investigations are not silently discarded or PASS.
for name in ['mixed-strict97','strict-counter97','mixed-nonlinear-strict97','failure-dump97','cubic-strict97','cubic-mid97','mixed-rollback','mixed-rollback2','budget-strict97','budget-coarse97','budget-mid97','fast-failure-dump97','final97','final-O0-97','final-ref97','final-coarse97','final-mid97','final-loose97','final-restart97','final-strict97']:
 folder=base/('perf01-weather-surface-'+name)
 for p in folder.iterdir():
  if p.is_file() and (p.suffix in ('.json','.csv') or p.name in ('stdout','stderr')):add('prototypes/'+name+'/'+p.name,p)
for folder in ['weather-desaturation','perf01-weather-surface-failure-dump','weather-tight-balance']:
 for p in (base/folder).iterdir():
  if p.is_file() and p.suffix in ('.f90','.json','.stdout','.stderr'):add('prototype-source/'+folder+'/'+p.name,p)
for p in (base/'weather-new-diagnostic').glob('*prototype.f90'):add('prototype-source/'+p.name,p)
add('assessment.json',ROOT/'benchmarks/performance/PERF01_WEATHER_SURFACE_REPAIR_SUMMARY.json')
files['MANIFEST.json']=(json.dumps({p:sha(raw) for p,raw in sorted(files.items())},indent=2)+'\n').encode()
with tarfile.open(a.output,'w:xz',preset=6) as tar:
 for name,raw in sorted(files.items()):
  entry=tarfile.TarInfo(name);entry.size=len(raw);entry.mode=0o644;entry.mtime=0;tar.addfile(entry,io.BytesIO(raw))
record=dict(path=str(a.output.relative_to(ROOT)),sha256=sha(a.output.read_bytes()),bytes=a.output.stat().st_size,members=len(files),members_sha256=sha(files['MANIFEST.json']))
(a.output.with_suffix('.index.json')).write_text(json.dumps(record,indent=2)+'\n');print(json.dumps(record))
