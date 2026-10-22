"""Persist raw Newton research, exact source identity and bounded replay."""
import hashlib
import io
import json
from pathlib import Path
import runpy
import subprocess
import tarfile

ROOT=Path(__file__).resolve().parents[2]
STEM=ROOT/'benchmarks/performance/PERF01_NEWTON_WORK_20261022_EVIDENCE'
sha=lambda b:hashlib.sha256(b).hexdigest()
roots={
    'screen':'/tmp/perf01-newton-screen', 'paired':'/tmp/perf01-newton-paired',
    'screen-build-baseline':'/tmp/perf01-newton-baseline-O2',
    'paired-build-baseline':'/tmp/perf01-newton-paired-baseline',
    'paired-build-candidate':'/tmp/perf01-newton-paired-linefail',
    'checked-build':'/tmp/perf01-newton-linefail-O0',
    'checked-1x':'/tmp/perf01-newton-O0-1x','checked-4x':'/tmp/perf01-newton-O0-4x',
    'wet-restart':'/tmp/perf01-newton-restart-4x','wet-restart-build':'/tmp/perf01-newton-restart',
    'rollback':'/tmp/perf01-newton-rollback-native','rollback-build':'/tmp/perf01-newton-rollback',
    'direct-O0':'/tmp/perf01-newton-direct-O0','direct-O2':'/tmp/perf01-newton-direct-O2',
}
files={}
for prefix,directory in roots.items():
    for p in sorted(Path(directory).rglob('*')):
        if not p.is_file() or p.suffix in ['.o','.mod','.a','.so']:
            continue
        raw=p.read_bytes()
        if not raw.startswith(b'\x7fELF'):
            files[prefix+'/'+str(p.relative_to(directory))]=raw
inputs={}
for opt in ['O0','O2']:
    parent=Path('/tmp/perf01-compose2-weather-'+opt)
    b=json.loads((parent/'BUILD.json').read_text())
    files['parent-'+opt+'/BUILD.json']=(parent/'BUILD.json').read_bytes()
    for p in b['sources']:
        inputs[p]=sha((ROOT/p).read_bytes())
        files['source/'+p]=(ROOT/p).read_bytes()
    for name in ['grid_stubs.f90','observed_serial_runtime.f90','observed_bootstrap.f90','driver.f90']:
        files['parent-'+opt+'/'+name]=(parent/name).read_bytes()
for p in ['src/legacy/b1_10_port/headcalc.f90','benchmarks/performance/assess_perf01_weather.py',
          'benchmarks/performance/verify_perf01_newton_work.py','benchmarks/performance/seal_perf01_newton_work.py',
          'benchmarks/performance/relink_perf01_newton_work.py','benchmarks/performance/screen_perf01_newton_work.py',
          'benchmarks/performance/qualify_perf01_newton_work.py','benchmarks/performance/benchmark_perf01_newton_work.py',
          'benchmarks/performance/run_perf01_weather.py','benchmarks/performance/run_perf01_weather_bound.py',
          'benchmarks/performance/run_perf01_warm_weather.py',
          'tests/fsi/test_weather_surface_retry.f90','tests/fsi/test_weather_surface_desaturation.f90',
          'tests/fsi/test_weather_surface_top_derivative.f90','tests/fsi/test_weather_surface_warm_start.f90']:
    inputs[p]=sha((ROOT/p).read_bytes())
    files['source/'+p]=(ROOT/p).read_bytes()
assert not subprocess.check_output(['git','diff','--name-only','f4ef44cb20cfb73ae7a582487790a4eb0292b144','HEAD','--','src'],cwd=ROOT)
paired=json.loads(files['paired/RESULT.json'])
assert paired['status']=='SERIAL_PAIRED_NEWTON_WORK_PHYSICAL_SCREEN_PASS'
screen=json.loads(files['screen/RESULT.json'])
costs=dict(screen_build_link_seconds=sum(e['seconds']for e in screen['events']if e['label'].startswith('build-')),
    screening_native_controller_seconds=sum(e['seconds']for e in screen['events']if not e['label'].startswith('build-')),
    serial_paired_controller_seconds=sum(e['seconds']for e in paired['events']),
    checked_native_wall_seconds=sum(json.loads(files[f'checked-{r}x/native/RESULT.json'])['wall_seconds']for r in [1,4]),
    direct_link_seconds=sum(e['seconds']for opt in ['O0','O2']for e in json.loads(files['direct-'+opt+'/RESULT.json'])['events']if e['category']=='link'),
    direct_native_seconds=sum(e['seconds']for opt in ['O0','O2']for e in json.loads(files['direct-'+opt+'/RESULT.json'])['events']if e['category']=='native'))
summary=dict(status='BOUNDED_GENERATED_NEWTON_RESEARCH_QUALIFIED',
    baseline='f4ef44cb20cfb73ae7a582487790a4eb0292b144',
    source_checkpoint=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
    production_changed=False, input_sha256=inputs, paired_cases=paired['cases'],
    measured_cost_categories=costs,
    full_fci='NOT_SELECTED_GENERATED_RESEARCH_ONLY',numerical_policy_admitted=False,
    limitation='Bounded generated research; no universal convergence, field accuracy or portable speed guarantee.')
files['SUMMARY.json']=(json.dumps(summary,indent=2)+'\n').encode()
files['MANIFEST.json']=(json.dumps({p:sha(v)for p,v in sorted(files.items())},indent=2)+'\n').encode()
checker=runpy.run_path(str(ROOT/'benchmarks/performance/verify_perf01_newton_work.py'))
result=checker['verify'](files)
controls=checker['self_test'](files)
target=STEM.with_suffix('.tar.xz')
with tarfile.open(target,'w:xz',preset=3)as t:
    for p,raw in sorted(files.items()):
        member=tarfile.TarInfo(p);member.size=len(raw);t.addfile(member,io.BytesIO(raw))
with tarfile.open(target)as t:
    assert {m.name:t.extractfile(m).read()for m in t.getmembers()}==files
index=dict(sha256=sha(target.read_bytes()),bytes=target.stat().st_size,members=len(files))
STEM.with_suffix('.index.json').write_text(json.dumps(index,indent=2)+'\n')
summary.update(evidence=dict(path=str(target.relative_to(ROOT)),**index),rejection_controls=controls)
STEM.with_suffix('.json').write_text(json.dumps(summary,indent=2)+'\n')
print(json.dumps(dict(status=result['status'],evidence=summary['evidence'],controls=controls)))
