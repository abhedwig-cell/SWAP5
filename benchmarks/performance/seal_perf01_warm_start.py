"""Seal executed warm-start implementation, failed prototypes and current proof."""
import argparse
import hashlib
import io
import json
from pathlib import Path
import subprocess
import tarfile

ROOT=Path(__file__).resolve().parents[2]
ap=argparse.ArgumentParser(description=__doc__)
ap.add_argument('--runs-root',type=Path,default=Path('/tmp'))
ap.add_argument('--output',type=Path,required=True)
args=ap.parse_args();runs=args.runs_root.resolve();output=args.output.resolve()
sha=lambda raw:hashlib.sha256(raw).hexdigest()
files={}
folders={
 'paired':'perf01-warm-paired',
 'checked-O0':'perf01-warm-checked-O0-4x',
 'restart':'perf01-warm-wet-restart-native',
 'restart-build':'perf01-warm-wet-restart-build',
 'rollback':'perf01-warm-rollback-build',
 'prototype1':'perf01-warm-hot-4x-r0',
 'prototype2':'perf01-warm-v2-hot-4x-r0',
 'old-cold':'perf01-warm-cold-4x-r0',
}
for opt in ['O0','O2']:
 for key,folder in [('build','perf01-warm-final-'),('selected','perf01-warm-selected-'),
                    ('focused','perf01-warm-qualified-'),('original','perf01-warm-original-'),
                    ('default','perf01-warm-default-')]:folders[key+'-'+opt]=folder+opt
for label,folder in folders.items():
 for path in sorted((runs/folder).rglob('*')):
  if path.is_file() and (path.suffix in {'.json','.stdout','.stderr','.f90','.csv','.999','.log'}
                        or path.name in ['stdout','stderr']):
   files[label+'/'+str(path.relative_to(runs/folder))]=path.read_bytes()
def js(path):return json.loads(files[path])
paired=js('paired/RESULT.json')
assert paired['status']=='PAIRED_SAME_SOURCE_WARM_COLD_PHYSICAL_SCREEN_PASS'
assert len(paired['events'])==12 and all(e['returncode']==0 for e in paired['events'])
inputs={}
for opt in ['O0','O2']:
 build=js('build-'+opt+'/BUILD.json')
 assert build['status']=='BUILT' and build['provider_count']==256
 assert all(e['returncode']==0 for e in build['events'])
 overrides={'tests/fsi/fsi04_real_headcalc_stubs.f90':'grid_stubs.f90',
            'src/runtime/mod_fmr_serialized_multiswap_runtime.f90':'observed_serial_runtime.f90',
            'src/runtime/mod_fmr_production_application_bootstrap.f90':'observed_bootstrap.f90'}
 for path,expected in build['sources'].items():
  raw=files['build-'+opt+'/'+overrides[path]] if path in overrides else (ROOT/path).read_bytes()
  assert sha(raw)==expected,path
  if path not in overrides:inputs[path]=expected
 for path,key in [('src/runtime/mod_fmr_serialized_multiswap_runtime.f90','observer_original_sha256'),
                  ('src/runtime/mod_fmr_production_application_bootstrap.f90','surface_observer_original_sha256'),
                  ('src/legacy/b1_10_port/headcalc.f90','headcalc_sha256')]:
  assert sha((ROOT/path).read_bytes())==build[key];inputs[path]=build[key]
 for role,status in [('focused','WARM_START_AND_ORIGINAL_CORNER_CONTROLS_PASS'),
                     ('original','WEATHER_SURFACE_NATIVE_PRESERVATION_PASS'),
                     ('default','DEFAULT_REAL_SOLVER_BEFORE_AFTER_BYTE_EXACT')]:
  assert js(role+'-'+opt+'/RESULT.json')['status']==status
 assert b'WEATHER_WARM_START_PRODUCTION_CONTRACT_PASS' in files['focused-'+opt+'/test_weather_surface_warm_start.native.stdout']
 selected=js('selected-'+opt+'/BUILD.json')
 assert selected['sources']==build['sources'] and selected['warm_start_option']
 old=files['build-'+opt+'/driver.f90'].decode()
 anchor="  call ta%initialize(tc,st);call require(st==FMR_APP_BOOT_OK,'live weather crop bootstrap')"
 assert files['selected-'+opt+'/driver.f90'].decode()==old.replace(anchor,'  tc%tiles(1)%parameters%weather_trial_warm_start=.true.\n'+anchor,1)
assert files['checked-O0/native/stdout']==files['paired/4x-0-warm/native/stdout'],'O0/O2 physical receipt drift'
assert files['restart/stdout']==files['paired/4x-0-warm/native/stdout'],'wetday35 reconstruction drift'
assert js('restart/RESULT.json')['command'][8]=='restart'
assert b'WEATHER_SURFACE_ROLLBACK_PASS           1' in files['rollback/native.stdout']
assert files['paired/4x-0-cold/native/stdout']==files['old-cold/native/stdout'],'default-off original receipt drift'
for path in subprocess.check_output(['git','diff','--name-only','3e23aa83de6637a8460e080e023abde89bca8127','HEAD'],cwd=ROOT,text=True).splitlines():
 if path.startswith(('src/','tests/','docs/science/')) or path.endswith('.py'):
  files['source/'+path]=(ROOT/path).read_bytes()
for path in ['benchmarks/performance/seal_perf01_warm_start.py','benchmarks/performance/assess_perf01_weather.py']:
 files['source/'+path]=(ROOT/path).read_bytes()
result={
 'status':'WARM_START_IMPLEMENTED_LOCAL_PHYSICAL_PASS_NO_4X_SPEEDUP_DEFAULT_OFF',
 'baseline':'3e23aa83de6637a8460e080e023abde89bca8127',
 'source_commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
 'current_input_sha256':inputs,
 'same_source_comparison':paired['cases'],
 'checked_O0_vs_O2_full97day_physical_receipts_exact':True,
 'wetday35_same_process_reconstruction_exact':True,
 'rollback_21bits_crop_revision_and_absent_receipts':True,
 'original_weather_profiles_per_optimization':6,
 'default_solver_contracts_per_optimization':2,
 'prototype_policy':'Retain both complete but slower earlier policy observations; pre-final headcalc_calls counted requests and omitted cold fallback calls. Final counter includes both phases.',
 'default_off':True,'canonically_admitted':False,
 'claim_limit':'Bounded illustrative97day227/908mm1e-3cm Reference/MvG/freebottom profile. Three serial alternating pairs on this host; no portable speed claim, no1e-6selection, no RossFast expansion.'}
assert result['same_source_comparison']['4']['warm_over_cold_cpu']>1,'update disposition if the measured decision changes'
files['ASSESSMENT.json']=(json.dumps(result,indent=2)+'\n').encode()
files['MANIFEST.json']=(json.dumps({p:sha(raw) for p,raw in sorted(files.items())},indent=2)+'\n').encode()
output.parent.mkdir(parents=True,exist_ok=True)
output.with_suffix('.json').write_bytes(files['ASSESSMENT.json'])
with tarfile.open(output.with_suffix('.tar.xz'),'w:xz') as archive:
 for path,raw in sorted(files.items()):
  item=tarfile.TarInfo(path);item.size=len(raw);item.mode=0o644
  archive.addfile(item,io.BytesIO(raw))
archive_path=output.with_suffix('.tar.xz')
with tarfile.open(archive_path,'r:xz') as archive:
 assert len(archive.getmembers())==len(files)
 for member in archive.getmembers():assert archive.extractfile(member).read()==files[member.name]
index={'path':str(archive_path.relative_to(ROOT)),'bytes':archive_path.stat().st_size,
       'sha256':sha(archive_path.read_bytes()),'members':len(files)}
output.with_suffix('.index.json').write_text(json.dumps(index,indent=2)+'\n')
print(json.dumps({'status':result['status'],'evidence':index,
                  'timings':{rain:{arm:row['arms'][arm]['median_cpu_seconds'] for arm in ['cold','warm']}
                             for rain,row in paired['cases'].items()}}))
