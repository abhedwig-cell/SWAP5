"""Replay the source-bound warm-start evidence without granting admission."""
import hashlib
import io
import json
from pathlib import Path
import runpy
import sys
import tarfile
import tempfile
ROOT=Path(__file__).resolve().parents[2]
STEM=ROOT/'benchmarks/performance/PERF01_WARM_START_20261022_EVIDENCE'
sha=lambda raw:hashlib.sha256(raw).hexdigest()
args=sys.argv;sys.argv=['assessor','/tmp']
helper=runpy.run_path(str(ROOT/'benchmarks/performance/assess_perf01_weather.py'))
sys.argv=args

def verify(files,reader=lambda p:(ROOT/p).read_bytes()):
 manifest=json.loads(files['MANIFEST.json'])
 assert set(files)==set(manifest)|{'MANIFEST.json'}
 for path,expected in manifest.items():
  assert sha(files[path])==expected,path
  if path.startswith('source/'):assert reader(path[7:])==files[path],path
 result=json.loads(files['ASSESSMENT.json'])
 assert result['default_off'] and not result['canonically_admitted']
 for path,expected in result['current_input_sha256'].items():assert sha(reader(path))==expected,path
 for opt in ['O0','O2']:
  focused=json.loads(files[f'focused-{opt}/RESULT.json'])
  assert focused['status']=='WARM_START_AND_ORIGINAL_CORNER_CONTROLS_PASS'
  for path,expected in focused['input_sha256'].items():assert sha(reader(path))==expected
  old=json.loads(files[f'original-{opt}/RESULT.json'])
  assert old['status']=='WEATHER_SURFACE_NATIVE_PRESERVATION_PASS' and old['native_original_profiles']==6
  for path,expected in old['input_sha256'].items():assert sha(reader(path))==expected
  default=json.loads(files[f'default-{opt}/RESULT.json'])
  assert default['status']=='DEFAULT_REAL_SOLVER_BEFORE_AFTER_BYTE_EXACT' and default['contracts']==2
  for path,expected in default['input_sha256'].items():
   if path.startswith('after:'):assert sha(reader(path[6:]))==expected
 paired=json.loads(files['paired/RESULT.json'])
 assert paired['status']=='PAIRED_SAME_SOURCE_WARM_COLD_PHYSICAL_SCREEN_PASS' and len(paired['events'])==12
 with tempfile.TemporaryDirectory(prefix='swap5-warm-proof-') as directory:
  root=Path(directory)
  for path,raw in files.items():
   if path.startswith('paired/') and '/native/' in path:
    target=root/path;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(raw)
  import statistics
  for rain in [1,4]:
   cpu={arm:[] for arm in ['cold','warm']}
   first={}
   for repeat in range(3):
    for arm in ['cold','warm']:
     metrics,rows=helper['read'](root/f'paired/{rain}x-{repeat}-{arm}/native')
     assert metrics['expected_rain_mm']==metrics['totals']['rain_mm']==227*rain
     assert metrics['head_budget_cm']==.001 and metrics['max_gross_daily_closure_mm']<1e-8
     cpu[arm].append(metrics['user_seconds'])
     if repeat:
      helper['same_physics'](rows,first[arm])
     else:first[arm]=rows
   delta=helper['differences'](first['warm'],first['cold'])
   assert delta==paired['cases'][str(rain)]['warm_minus_cold']
   assert delta['storage_mm']['max_daily_abs']<=.01
   assert abs(delta['runoff_mm']['total_difference'])<=.05
   assert abs(delta['bottom_mm']['total_difference'])<=.05
   ratio=statistics.median(cpu['warm'])/statistics.median(cpu['cold'])
   assert ratio==paired['cases'][str(rain)]['warm_over_cold_cpu']
 assert files['checked-O0/native/stdout']==files['restart/stdout']==files['paired/4x-0-warm/native/stdout']
 assert json.loads(files['restart/RESULT.json'])['command'][8]=='restart'
 assert b'WEATHER_SURFACE_ROLLBACK_PASS           1' in files['rollback/native.stdout']
 assert files['old-cold/native/stdout']==files['paired/4x-0-cold/native/stdout']
 return {'status':'WARM_START_SOURCE_AND_NATIVE_EVIDENCE_PASS','canonically_admitted':False,'default_off':True}

archive=STEM.with_suffix('.tar.xz');index=json.loads(STEM.with_suffix('.index.json').read_text())
assert sha(archive.read_bytes())==index['sha256']
with tarfile.open(archive,'r:xz') as tar:
 members=tar.getmembers()
 assert len(members)==index['members']==len({m.name for m in members})
 assert all(m.isfile() and not Path(m.name).is_absolute() and '..' not in Path(m.name).parts for m in members)
 files={m.name:tar.extractfile(m).read() for m in members}
result=verify(files)
if '--self-test' in sys.argv:
 controls=[]
 for path in ['paired/4x-0-warm/native/stdout','focused-O2/RESULT.json','rollback/native.stdout']:
  bad=dict(files);bad.pop(path)
  try:verify(bad)
  except(AssertionError,KeyError):controls.append('missing '+path)
  else:raise AssertionError('accepted missing evidence')
 try:verify(files,lambda p:(ROOT/p).read_bytes()+b'!')
 except AssertionError:controls.append('current source drift')
 else:raise AssertionError('accepted foreign source')
 result['negative_controls']=controls
print(json.dumps(result))
