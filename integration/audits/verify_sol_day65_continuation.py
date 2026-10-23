"""Source-bound research proof; not a full MC-SOL01/canonical admission gate."""
import argparse,base64,csv,hashlib,io,json,math,tarfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
def sha(raw):return hashlib.sha256(raw).hexdigest()
def scope_successor(old,new):
 needle=b"    assert sum(d['runoff_cm']for d in budget)>0"
 return old.count(needle)==1 and old.replace(needle,b"    if simulated_days==days:assert sum(d['runoff_cm']for d in budget)>0")==new
def capsule(path):
 raw=base64.b64decode(path.read_bytes())
 with tarfile.open(fileobj=io.BytesIO(raw),mode='r:xz')as archive:
  members=archive.getmembers()
  assert all(m.isfile()and not m.name.startswith('/')and'..'not in Path(m.name).parts for m in members)
  assert len({m.name for m in members})==len(members)
  files={m.name:archive.extractfile(m).read()for m in members}
 assert json.loads(files['MANIFEST.json'])=={p:sha(v)for p,v in files.items()if p!='MANIFEST.json'}
 return raw,files
def validate(f,reader=lambda p:(ROOT/p).read_bytes()):
 c=json.loads(f['CURRENT.json'])
 assert c['status']=='BOUNDED_COMPOSITE_RESEARCH_CHECKPOINT'
 assert not c['canonically_admitted']and not c['full_historical_migration']and not c['full_refined_year_qualified']
 for p,h in c['postimages'].items():assert sha(reader(p))==h,('current postimage',p)
 def js(p):return json.loads(f['proof/'+p])
 def report(n):return js(n+'/result.json')
 def raw(n,p):return f['proof/'+n+'/'+p]
 def rows(n,p):return [{k:float(v)for k,v in r.items()}for r in csv.DictReader(io.StringIO(raw(n,p).decode()))]
 def mass(data):
  for d in data:
   assert all(math.isfinite(v)for v in d.values())
   for s,u in [('water','cm'),('solute','mg_cm2')]:
    e=d[s+'_end_'+u]-d[s+'_start_'+u]-d[s+'_in_'+u]+d[s+'_out_'+u]
    assert abs(e)<1e-10 and abs(d[s+'_residual_'+u])<1e-10
 def executed(n):
  r=report(n)
  for p,h in {**r.get('inputs',{}),**r.get('input_sha256',{}),**r.get('cold_input_sha256',{})}.items():
   if sha(reader(p))!=h:
    assert p=='tests/nut-sol/qualify_native_project.py',(n,p)
    old=f['execution-sources/'+h];assert sha(old)==h and scope_successor(old,reader(p)),(n,'unreviewed validator delta')
  events=r.get('events')
  if events is None:events=js(n+'/events.json')
  for i,e in enumerate(events or []):
   assert (e['returncode']==0)==e.get('expected_success',True),(n,i)
   # Do not accept a green JSON after losing its actual native output.
   for stream in ['stdout','stderr']:
    path=e.get(stream,f'{i:04d}.{stream}')
    assert 'proof/'+n+'/'+path in f,(n,'missing raw event',path)
  return r
 leaf=report('curve');assert leaf['status']=='REAL_CONDUCTIVITY_DISCONTINUITY_O0_O2_CONFIRMED'
 for p,h in leaf['source_sha256'].items():assert sha(reader(p))==h
 assert raw('curve','O0-native.stdout')==raw('curve','O2-native.stdout')
 assert b'SOL_DAY65_REAL_CONDUCTIVITY_CUTOFF_AND_CONTINUOUS_CURVE_PASS'in raw('curve','O0-native.stdout')
 assert leaf['swp_sha256']==sha(raw('cutoff-O0','input.swp'))
 for n in ['cutoff-O0','day257-reject']:
  assert report(n)['status']=='ACTUAL_WATER_REJECTION_DIAGNOSTIC_REPLAY_OWNERS_EXACT'
  assert raw(n,'before.bin')==raw(n,'diagnostic-rejected.bin')
  output=raw(n,f"{len(report(n)['events'])-1:04d}.stdout").decode()
  counters=next(line for line in output.splitlines()if'solver/temporal/mass rejects:'in line)
  assert int(counters.split(':')[1].split()[-1])==0
 assert report('curve-only-O2')['status']=='ACTUAL_WATER_DAY_PASS'
 assert report('curve-only-O2')['curve_only_provider_sha256'] is not None
 assert sha(raw('curve-only-O2','curve_only.f90'))==report('curve-only-O2')['curve_only_provider_sha256']
 assert any(b'CURVE_ONLY_PROBE'in v for p,v in f.items()if p.startswith('proof/curve-only-O2/')and p.endswith('.stdout'))
 for n in ['composite-day65-O0','composite-day65-O2','composite-day257-O2']:
  r=executed(n);assert r['status']=='ACTUAL_WATER_DAY_PASS'and r['temporal_tolerance']is None
  for key in ['diagnostic_provider_sha256','picard_provider_sha256','chemical_provider_sha256',
              'historical_exfiltration_provider_sha256','saturation_temporal_provider_sha256',
              'continuous_mvg_provider_sha256','curve_only_provider_sha256']:
   assert r[key]is None,(n,'copied provider',key)
  assert sha(raw(n,'driver.f90'))==r['driver_sha256']
  assert len(rows(n,'budget.csv'))==1;mass(rows(n,'budget.csv'))
 for p in ['budget.csv','state.csv','endpoint.csv','restart.bin']:
  assert raw('composite-day65-O0',p)==raw('composite-day65-O2',p)
 assert raw('cutoff-O0','before.bin')==raw('composite-day65-O0','before.bin')
 assert raw('day257-reject','before.bin')==raw('composite-day257-O2','before.bin')
 for opt in ['O0','O2']:
  b=js('composite-'+opt+'/shared/build-complete.json')
  assert b['status']=='BUILT'and '-'+opt in b['flags']and '-fcheck=all'in b['flags']
  for p,h in b['input_sha256'].items():assert sha(reader(p))==h,('current build',p)
  cache=[json.loads(l)for l in raw('composite-'+opt,'shared/day65-cache-events.jsonl').splitlines()]
  assert cache and all(e['returncode']==0 for e in cache)
  backend=[e for e in cache if e['source'].endswith('/src/runtime/mod_fmr_serialized_reference_backend.f90')]
  assert len(backend)==1 and not backend[0]['reused'],'changed backend must compile'
  manifest=js('cache-manifest.json')
  for e in cache:
   if e['reused']:
    assert any(old['object']==e['from_object']and old['source_sha256']==e['source_sha256']and old['object_sha256']==e['object_sha256']for old in manifest['entries'])
 daily=executed('composite-default-daily')
 assert daily['status']=='ROOT_SUBSTEP_DAILY_O0_O2_MASS_RESTART_DEFAULT_EXACT_PASS'
 assert(daily['exact_default_files'],daily['fresh_restarts'],daily['mode_restart_rejections'])==(64,16,2)
 # Check the retained admitted bytes independently of the runner's green label.
 status=json.loads(reader('integration/audits/MC_SOL01_DYNAMIC_DECAY_STATUS.json'))
 parent=status['swp_water_successor']['daily_meteo_successor']['etref_successor']['simple_crop_preparation_successor']['root_joint_successor']
 oldraw=base64.b64decode(reader(parent['evidence']['path']));assert sha(oldraw)==daily['baseline_capsule_sha256']
 with tarfile.open(fileobj=io.BytesIO(oldraw),mode='r:xz')as archive:
  for name,case in daily['cases'].items():
   opt,label=name.split('-',1);prefix=opt+'/'+label+'/'
   for p in ['state.csv','endpoint.csv','restart.bin','budget.csv']:
    assert raw('composite-default-daily',prefix+'daily/'+p)==archive.extractfile('qualified/'+prefix+'full/'+p).read()
   for p in ['state.csv','endpoint.csv','restart.bin']:
    assert raw('composite-default-daily',prefix+'full/'+p)==raw('composite-default-daily',prefix+'resumed/'+p)
   data=rows('composite-default-daily',prefix+'full/budget.csv');assert len(data)==8;mass(data)
   assert rows('composite-default-daily',prefix+'resumed/budget.csv')==data[3:]
 for n,continuous in [('composite-default-transaction',False),('composite-transaction',True)]:
  r=executed(n);assert r['status'].endswith('ROOT_SUBSTEP_REAL_TRACE_REJECT_RETRY_ABA_O0_O2_PASS')
  assert r['continuous_mvg']==continuous
  for opt in ['O0','O2']:
   for p in ['rejected.bin','invalid.bin']+(['policy-rejected.bin','curve-rejected.bin']if continuous else[]):
    assert raw(n,opt+'/original.bin')==raw(n,opt+'/'+p)
   assert raw(n,opt+'/retry.bin')==raw(n,opt+'/fresh.bin')==raw(n,opt+'/again.bin')
 r=executed('composite-restart')
 assert(r['exact_restart_files'],r['invalids'],r['curve_mode_rejections'],r['surface_mode_rejections'])==(12,8,6,2)
 assert r['water_conductivity']=='picard_continuous'and r['status'].endswith('_PASS')
 for opt in ['O0','O2']:
  for mode in ['reference','implicit_upwind']:
   for p in ['state.csv','endpoint.csv','restart.bin']:
    assert raw('composite-restart',opt+'/'+mode+'-full/'+p)==raw('composite-restart',opt+'/'+mode+'-resumed/'+p)
 short=executed('composite-short')
 assert short['status']=='NATIVE_PROJECT_SHORT_PASS_REFERENCE'
 assert(short['exact_single_files'],short['fresh_restarts'],short['invalid_inputs'])==(8,2,14)
 annual=executed('composite-coarse');executed('composite-refined98')
 refined=js('composite-refined98/prefix-validation.json')
 assert refined['numerical_processes_rerun']is False
 assert refined['execution_recipe_sha256']==report('composite-refined98')['inputs']['tests/nut-sol/qualify_native_project.py']
 assert refined['disposition']=='ANNUAL_RUNOFF_COVERAGE_ASSERTION_DOES_NOT_APPLY_TO_98_DAY_PREFIX'
 assert refined['full_refined_year_qualified']is False
 for p,h in refined['inputs'].items():assert sha(reader(p))==h
 for p,h in refined['observations'].items():assert sha(raw('composite-refined98',p))==h
 assert annual['status']=='NATIVE_PROJECT_HISTORICAL_WEATHER_ANNUAL_PASS_IMPLICIT_UPWIND'
 assert refined['status']=='NATIVE_PROJECT_BOUNDED_PREFIX_98_DAYS_PASS'
 for n,r,expected in [('composite-coarse',annual,{'O2-single':8,'O2-annual1998':365,'O2-cross_year':481}),
                      ('composite-refined98',refined,{'O2-single':8,'O2-annual1998':98})]:
  assert set(r['cases'])==set(expected)
  for name,days in expected.items():
   case=r['cases'][name];assert case['days']==days
   assert case['full_period_simulated']==(n=='composite-coarse'or name=='O2-single')
   prefix=name.replace('-','/',1)+'/'
   document=raw(n,prefix+'full/input.nml').decode()
   encoded=''.join(line.split('=',1)[1]for line in document.splitlines()if line.startswith('! native_project_audit_base64='))
   audit=json.loads(base64.b64decode(encoded));assert audit['days']==case['declared_days']
   for period in audit['prepared_periods']:
    oracle=rows(n,prefix+'oracle/original-'+str(period['index'])+'.csv')
    assert oracle==[{k:float(v)for k,v in d.items()}for d in period['plan']]
   for key,h in audit['original_sources'].items():
    original=base64.b64decode(''.join(line.split('=',1)[1]for line in document.splitlines()if line.startswith('! '+key+'_base64=')))
    assert sha(original)==h
   data=rows(n,prefix+'full/budget.csv');assert len(data)==days;mass(data)
   assert data==case['budget']
   split=len(rows(n,prefix+'split/budget.csv'))
   assert rows(n,prefix+'resumed/budget.csv')==data[split:]
   for p in ['state.csv','endpoint.csv','restart.bin']:assert raw(n,prefix+'full/'+p)==raw(n,prefix+'resumed/'+p)
   for i,d in enumerate(data):
    gross=d['water_end_cm']-d['water_start_cm']-case['rain_cm'][i]+d['soil_evaporation_cm']+d['pond_evaporation_cm']+d['runoff_cm']+d['actual_transpiration_cm']+(.01 if 'single'not in name else 0.)
    assert abs(gross)<1e-10
 assert report('annual-coarse-O2')['status']=='FAILED'
 hits=[p for p in f if p.startswith('proof/annual-coarse-O2/O2/annual1998/full.pending-')and p.endswith('/budget.csv')]
 assert len(hits)==1 and len(list(csv.DictReader(io.StringIO(f[hits[0]].decode()))))==256
 assert c['historical_dispositions']['annual-refined-O2']=='CENSORED_SUPERSEDED_CURVE_ONLY_NOT_PHYSICAL_FAILURE'
 coarse=annual['cases']['O2-annual1998']['budget'][:98];fine=refined['cases']['O2-annual1998']['budget']
 assert len(coarse)==len(fine)==98 and c['grid_comparison_is_convergence_proof']is False
 assert c['grid_comparison_first98_days']=={key:max(abs(x[key]-y[key])for x,y in zip(coarse,fine))
  for key in ['water_end_cm','solute_end_mg_cm2','actual_transpiration_cm']}
 for n,expected in [('composite-nut-final','NATIVE_TRUE_OUTPUT_PROJECT_O0_O2_FRESH_PASS'),
                    ('composite-nut-thermal','THERMAL_OUTPUT_ACTUAL_O0_O2_RESTART_ATOMIC_PASS'),
                    ('composite-nut-calendar','NATIVE_CALENDAR_OUTPUT_ACTUAL_O0_O2_FRESH_PASS'),
                    ('composite-nut-saved','SAVED_HARVEST_FALLOW_OUTPUT_O0_O2_ATOMIC_FRESH_PASS'),
                    ('composite-nut-harvest','HARVEST_OUTPUT_PHASE_O0_O2_ATOMIC_FRESH_PASS')]:
  assert executed(n)['status']==expected
 assert report('composite-nut-final')['results']==report('nut-cold')['results']
 for n in ['thermal','calendar','saved']:
  assert report('composite-nut-'+n)['results']==report('nut-'+n)['results']
 return dict(status=c['status'],day65_O0_O2_exact=True,day257_repaired=True,
  default_exact_files=64,fresh_daily_restarts=16,native_curve_mode_rejections=6,
  coarse_days=[365,481],refined_prefix_days=98,full_refined_year_qualified=False,
  full_historical_migration=False,canonically_admitted=False)
def main():
 ap=argparse.ArgumentParser();ap.add_argument('evidence',type=Path);ap.add_argument('--self-test',action='store_true');a=ap.parse_args()
 raw,f=capsule(a.evidence);r=validate(f);controls=[]
 owner=json.loads((ROOT/'integration/audits/MC_SOL01_DYNAMIC_DECAY_STATUS.json').read_text())
 for key in ['swp_water_successor','daily_meteo_successor','etref_successor','simple_crop_preparation_successor',
             'root_joint_successor','substep_feedback_work','native_project_successor','positive_transport_successor',
             'saturation_surface_continuation_20261022','day65_continuation_20261023']:owner=owner[key]
 assert owner['evidence']['decoded_sha256']==sha(raw),'owning evidence identity'
 if a.self_test:
  for p in ['proof/composite-day65-O2/budget.csv','proof/composite-day257-O2/0001.stdout',
            'proof/composite-default-daily/O0/dry/daily/restart.bin','proof/composite-restart/O2/implicit_upwind-resumed/restart.bin',
            'proof/composite-coarse/O2/cross_year/full/budget.csv','proof/composite-nut-thermal/events.json']:
   damaged=dict(f);damaged.pop(p)
   try:validate(damaged)
   except(AssertionError,KeyError):controls.append('missing:'+p)
   else:raise AssertionError('missing raw evidence accepted: '+p)
  for key in ['canonically_admitted','full_historical_migration','full_refined_year_qualified']:
   damaged=dict(f);c=json.loads(f['CURRENT.json']);c[key]=True;damaged['CURRENT.json']=json.dumps(c).encode()
   try:validate(damaged)
   except AssertionError:controls.append('false:'+key)
   else:raise AssertionError('false scope accepted: '+key)
  p='src/runtime/mod_fmr_serialized_reference_backend.f90'
  try:validate(f,lambda q:(ROOT/q).read_bytes()+(b'corrupt'if p==q else b''))
  except AssertionError:controls.append('foreign:'+p)
  else:raise AssertionError('foreign backend accepted')
 r.update(decoded_sha256=sha(raw),controls=controls);print(json.dumps(r,indent=2))
if __name__=='__main__':main()
