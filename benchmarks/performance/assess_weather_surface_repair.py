"""Validate completed production weather runs and retain failed refinements."""
import argparse,hashlib,importlib.util,json,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--root',type=Path,default=Path('/tmp'));ap.add_argument('--output',type=Path,required=True);a=ap.parse_args()
spec=importlib.util.spec_from_file_location('old_assessor',ROOT/'benchmarks/performance/assess_perf01_weather.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
base=a.root;prefix='perf01-weather-surface-';sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
builds={o:json.loads((base/(prefix+('final-O0' if o=='O0' else 'final-v2-O2'))/'BUILD.json').read_text()) for o in ('O0','O2')}
for o,b in builds.items():
 assert b['status']=='BUILT' and sha(base/(prefix+('final-O0' if o=='O0' else 'final-v2-O2'))/'weather')==b['executable_sha256']
 assert sha(ROOT/'src/legacy/b1_10_port/headcalc.f90')==b['headcalc_sha256']
files={};cases={}
for name,run,opt in [('ref','final-ref97','O2'),('default','final97','O2'),('coarse','final-coarse97','O2'),('middle','final-mid97','O2'),('loose','final-loose97','O2'),('O0','final-O0-97','O0'),('restart','final-restart97','O2')]:
 native={'ref':'ref97-native','default':'default97-native','coarse':'coarse97-native','middle':'middle97-native','loose':'loose97-native','O0':'O0-97','restart':'restart97'}[name]
 result,rows=m.read(base/('weather-physical-'+native))
 assert sha(Path(result['command'][4]))=='b69d91f8af402b4783a3b5bbd51026492b93b04de6be90717648e9b806db0fb8'
 if name!='restart':assert result['executable_sha256']==builds[opt]['executable_sha256']
 cases[name]=(result,rows)
m.same_physics(cases['default'][1],cases['O0'][1]);m.same_physics(cases['default'][1],cases['restart'][1])
assert sha(base/'weather-physical-default97-native'/'stdout')==sha(base/'weather-physical-O0-97'/'stdout')==sha(base/'weather-physical-restart97'/'stdout')
for name,(result,rows) in cases.items():files[name]={'metrics':result,'differences_vs_finite_ref':m.differences(rows,cases['ref'][1])}
controls={}
for opt in ('O0','O2'):
 for kind in ('preserve','default'):
  p=base/('weather-physical-'+('qualification' if kind=='preserve' else kind)+'-'+opt)/'RESULT.json';r=json.loads(p.read_text());assert r['status'] in ('WEATHER_SURFACE_NATIVE_PRESERVATION_PASS','DEFAULT_REAL_SOLVER_BEFORE_AFTER_BYTE_EXACT')
  if kind=='preserve':
   assert r['parent_build']==str(base/(prefix+('final-O0' if opt=='O0' else 'final-v2-O2'))) and r['analytic_top_contracts']==1
   for p,h in r['input_sha256'].items():assert sha(ROOT/p)==h,p
  else:
   for p,h in r['input_sha256'].items():
    if p.startswith('after:'):assert sha(ROOT/p.split(':',1)[1])==h,p
  controls[kind+'-'+opt]=r
p=base/'weather-physical-rollback';r=json.loads((p/'RESULT.json').read_text());assert r['returncode']==0 and not r['timed_out'];assert 'WEATHER_SURFACE_ROLLBACK_PASS           1' in (p/'stdout').read_text();controls['rollback']={'status':'EXACT_21_STATE_BITS_AFTER_ONE_PRIVATE_SUBSTEP','runner':r,'note':'Expected early success exit; not a completed one-day weather horizon.'}
strict=base/'weather-physical-strict97';r=json.loads((strict/'RESULT.json').read_text())
for name,h in r['raw_sha256'].items():assert sha(strict/name)==h
summary=dict(status='BOUNDED_WEATHER_SURFACE_NATIVE_RESULTS',cases=files,controls=controls,strict_refinement=r,claim_ceiling='Illustrative 30cm/four-cell live crop column, rain x4,97 days/64 windows; no field calibration, uniform saturated-head error guarantee or portable speed claim. Finite reference is a comparison, not truth.',temporal_norm='Maximum of unsaturated head, noncancelling storage, pond/gwl and endpoint Darcy displacement differences; cm',hard_transaction_mass_gate_cm=1e-14,optimization_exact=True,wet_reconstruction_exact=True)
a.output.write_text(json.dumps(summary,indent=2)+'\n')
for name,v in files.items():print(name,v['metrics']['user_seconds'],v['metrics']['max_gross_daily_closure_mm'],v['differences_vs_finite_ref']['runoff_mm']['total_difference'])
print('STRICT',r['status'],r.get('completed_days'))
