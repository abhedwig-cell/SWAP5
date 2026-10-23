"""Seal/replay current nonlinear and changed-accuracy research, including failures."""
import argparse,csv,hashlib,io,json,re,statistics,subprocess,tarfile,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
PREFIX='benchmarks/performance/PERF01_SOLVER_FAILURE_20261023'
FILES=['budget.csv','state.csv','endpoint.csv','restart.bin']
sha=lambda b:hashlib.sha256(b).hexdigest()
CAPTURES={'solver':'/tmp/perf01-solver-failure-current-v4','temporal':'/tmp/perf01-temporal-component-current','water':'/tmp/perf01-water-metric-current','root':'/tmp/perf01-water-metric-supplement-v3','rate-all':'/tmp/perf01-water-flux-rate-base-v2','separate-base':'/tmp/perf01-water-flux-separated-base','separate-stress':'/tmp/perf01-water-flux-separated-stress','final-root':'/tmp/perf01-water-flux-separated-supplement'}
def unpack(raw):
 with tarfile.open(fileobj=io.BytesIO(raw),mode='r:xz')as t:
  ms=t.getmembers();assert len(ms)==len({m.name for m in ms})
  assert all(m.isfile()and not Path(m.name).is_absolute()and'..'not in Path(m.name).parts for m in ms)
  f={m.name:t.extractfile(m).read()for m in ms}
 assert json.loads(f.pop('MANIFEST.json'))=={p:sha(b)for p,b in f.items()}
 return f
def validate(f):
 def js(p):return json.loads(f[p])
 def rows(p):return list(csv.DictReader(io.StringIO(f[p].decode())))
 source_hashes={sha(b)for p,b in f.items()if p.startswith('sources/')}
 reports={k:js(k+'/RESULT.json')for k in CAPTURES}
 for k,r in reports.items():
  assert r.get('script_sha256',r.get('source_sha256'))in source_hashes,('executed research script',k)
  for b in r.get('builds',{}).values():
   for p,h in b.get('input_sha256',{}).items():assert sha((ROOT/p).read_bytes())==h,('executed provider',p)
  for e in r['events']:
   assert k+'/'+e['label']+'.stdout'in f and k+'/'+e['label']+'.stderr'in f
   assert e['seconds']>=0
  if r.get('flux_rate_guard',False):
   for opt in ['O0','O2']:
    path='src/runtime/mod_fmr_serialized_reference_backend.f90'
    expected=(ROOT/path).read_bytes().replace(b'    if(self%root_extraction_active.and.publish_root_result) then',b'    if(associated(self%qrot)) then')
    assert f[k+'/'+opt+'/backend.f90']==expected,'generated uptake metadata source changed'
    source=(ROOT/'src/transaction/mod_transaction_reference.f90').read_bytes();generated=f[k+'/'+opt+'/transaction.f90']
    anchor=b'      terr = model%temporal_error(full_state, half_state)';ending=b'\n\n      result%full_mass_residual = full_mass_residual'
    left=generated.index(anchor)+len(anchor);right=generated.index(ending,left)
    assert generated[:left]+generated[right:]==source,'generated transaction changed outside declared error'
    assert b'actual_transpiration_available'in generated[left:right]and b'terr=huge'in generated[left:right]
 assert reports['solver']['status']=='EARLY_REJECTION_REJECTED_CURRENT_NONLINEAR_OBSERVER_O0_O2_EXACT'
 assert len(reports['solver']['failures'])==4
 assert reports['temporal']['status']=='CURRENT_TEMPORAL_COMPONENT_OBSERVER_O0_O2_PHYSICAL_BYTES_EXACT'
 assert reports['root']['status']=='DAILY_STATE_AND_ACTIVE_ROOT_STRESS_DISCRIMINATOR_COMPLETE'
 result=dict(production_changed=False,changed_accuracy=True,stages={},nonlinear={},temporal={},water={},root={},independent_daily_water_mm=0.)
 for k,r in reports.items():
  result['stages'][k]=dict(status=r['status'],events=len(r['events']),failed_events=sum(e['returncode']!=0 for e in r['events']),event_seconds=sum(e['seconds']for e in r['events']))
 for opt in ['O0','O2']:
  for rain in [1,4]:
   label=f'{opt}-{rain}x';base='solver/'+label+'-ordinary-0/'
   for n in FILES:
    assert f['solver/'+label+'-observer-0/'+n]==f[base+n]
    assert f['temporal/'+label+'/'+n]==f[base+n]
   failure=next(x for x in reports['solver']['failures']if x['label']==label+'-early-0')
   assert failure['returncode']==1
   stream=f['solver/'+label+'-early-0.stdout'];day=18 if rain==1 else 7
   assert f'rejected window/process/completed:'.encode()in stream and b'joint interval rejected'in stream
   assert len(rows('solver/'+label+'-early-0/budget.csv'))==day-1
   for k in ['water','rate-all','separate-base','separate-stress']:
    r=reports[k];assert r['status']=='WATER_METRIC_CHANGED_ACCURACY_O0_O2_RESTART_COMPLETE'
    c=r['cases'][label]
    assert all(e['returncode']==0 for e in r['events'])
    for arm in ['ordinary','water']:
     samples=[s for s in c['samples']if s['kind']==arm]
     assert c['native_median'][arm]==statistics.median(s['seconds']for s in samples)
     for s in samples:
      name=f"{label}-{arm}-{s['repeat']}"
      assert s['seconds']==next(e['seconds']for e in r['events']if e['label']==name)
      for n in FILES:assert f[k+'/'+name+'/'+n]==f[k+'/'+label+'-'+arm+'-0/'+n]
    p=k+'/'+label+'-water-0/';data=rows(p+'budget.csv');reference=rows(k+'/'+label+'-ordinary-0/budget.csv');assert len(data)==len(reference)==97
    assert c['accepted_halfsteps']==sum(int(d['accepted_substeps'])for d in data)
    for field,observed in c['differences'].items():
     assert observed==dict(max_mm=10*max(abs(float(d[field])-float(s[field]))for d,s in zip(data,reference)),sum_mm=10*sum(float(d[field])-float(s[field])for d,s in zip(data,reference)))
    diff=c['differences'];stress=k=='separate-stress'
    expected=dict(internal_water=max(abs(float(d['water_residual_cm']))for d in data)<1e-10,runoff_daily=diff['runoff_cm']['max_mm']<.01,runoff_season=abs(diff['runoff_cm']['sum_mm'])<(.05 if stress else .01),storage=diff['water_end_cm']['max_mm']<.01,transpiration=diff['actual_transpiration_cm']['max_mm']<(.01 if stress else 1e-8),total_evaporation=10*max(abs(float(d['soil_evaporation_cm'])+float(d['pond_evaporation_cm'])-float(s['soil_evaporation_cm'])-float(s['pond_evaporation_cm']))for d,s in zip(data,reference))<(.01 if stress else 1e-8))
    if stress:expected['season_transpiration']=abs(diff['actual_transpiration_cm']['sum_mm'])<.05
    assert c['criteria']==expected and all(expected.values())
    for n in FILES[1:]:assert f[k+'/'+label+'-resume/'+n]==f[p+n]
    assert rows(k+'/'+label+'-resume/budget.csv')==data[48:]
    for n in FILES:assert f[k+f'/O0-{rain}x-water-0/'+n]==f[k+f'/O2-{rain}x-water-0/'+n]
    result['water'][k+'-'+label]=c
   nonlinear=rows('solver/'+label+'-observer-0/nonlinear_summary.csv')
   result['nonlinear'][label]={str(kind):{field:sum(float(d[field])for d in nonlinear if int(d['result'])==kind)for field in ['calls','iterations','backtracks','failed_lines','phases_with_failed_lines','seconds']}for kind in [1,2]}
   detail=rows('solver/'+label+'-observer-0/nonlinear.csv')
   for kind in [1,2]:
    selected=[d for d in detail if int(d['result'])==kind]
    expected=result['nonlinear'][label][str(kind)]['phases_with_failed_lines'if kind==1 else'calls']
    assert len(selected)==int(expected)
   tc=rows('temporal/'+label+'/temporal_components.csv')
   result['temporal'][label]={field:sum(int(d[field])for d in tc)for field in list(tc[0])[2:12]}
   assert result['temporal'][label]['rejects']==result['temporal'][label]['head_max']==(13459 if rain==1 else 16460)
   for fixture in ['base','stress']:
    prefix='root/'+label+'-'+fixture
    a=rows(prefix+'-ordinary/daily_physical.csv');b=rows(prefix+'-water/daily_physical.csv');assert len(a)==len(b)==388
    c=reports['root']['cases'][label+'-'+fixture]
    assert c['max_daily_head_cm']==max(abs(float(d['head_cm'])-float(s['head_cm']))for d,s in zip(a,b))
    assert c['max_daily_theta']==max(abs(float(d['theta'])-float(s['theta']))for d,s in zip(a,b))
    if fixture=='base':assert all(c['criteria'].values())
    else:
     assert not c['criteria']['daily_runoff']and not c['criteria']['daily_transpiration']
     for arm in ['ordinary','water']:
      text=f[prefix+'-'+arm+'/input.nml'];assert b'substep_root_stress=.true.'in text and b'HLIM3L= -25d0'in text
      rc=reports['root']['cases'][label+'-stress-'+arm];assert rc['drought_days']>0 and rc['oxygen_days']>0
      for n in FILES[1:]:assert f[prefix+'-'+arm+'-resume/'+n]==f[prefix+'-'+arm+'/'+n]
      assert rows(prefix+'-'+arm+'-resume/budget.csv')==rows(prefix+'-'+arm+'/budget.csv')[48:]
    result['root'][label+'-'+fixture]=c
    # Final flux-aware supplement must bind the actual selected prototype,
    # including generated uptake metadata and transaction rate checks.
    final='final-root/'+label+'-'+fixture
    fc=reports['final-root']['cases'][label+'-'+fixture];assert all(fc['criteria'].values())
    selected='separate-base'if fixture=='base'else'separate-stress'
    for arm in ['ordinary','water']:
     for n in FILES:assert f[final+'-'+arm+'/'+n]==f[selected+'/'+label+'-'+arm+'-0/'+n]
     if fixture=='stress':
      for n in FILES[1:]:assert f[final+'-'+arm+'-resume/'+n]==f[final+'-'+arm+'/'+n]
      assert rows(final+'-'+arm+'-resume/budget.csv')==rows(final+'-'+arm+'/budget.csv')[48:]
    a=rows(final+'-ordinary/daily_physical.csv');b=rows(final+'-water/daily_physical.csv');assert len(a)==len(b)==388
    assert fc['max_daily_head_cm']==max(abs(float(d['head_cm'])-float(s['head_cm']))for d,s in zip(a,b))
    assert fc['max_daily_theta']==max(abs(float(d['theta'])-float(s['theta']))for d,s in zip(a,b))
    result['root']['final-'+label+'-'+fixture]=fc
   assert f[f'rollback/{label}/restart.bin']==f['solver/'+label+'-early-0/diagnostic-rejected.bin'],('failed early policy leaked committed state',label)
 # Independent gross forcing closure for every completed/partial daily record,
 # using authenticated original rainfall/bottom rather than internal in/out.
 for path,raw in f.items():
  if not path.endswith('/budget.csv')or not any(path.startswith(k+'/')for k in CAPTURES):continue
  match=re.search(r'/O[02]-([14])x(?:-|/)',path)
  if not match:continue
  rain=int(match[1]);lines=f[f'original/{rain}x.csv'].decode().splitlines()
  original=list(csv.DictReader(l for l in lines if not l.startswith('*')))[1:];assert len(original)==97
  for d in rows(path):
   o=original[int(d['window'])-1]
   residual=10*abs(float(d['water_end_cm'])-float(d['water_start_cm'])-float(o['RAIN'])+float(d['runoff_cm'])+float(d['soil_evaporation_cm'])+float(d['pond_evaporation_cm'])+float(d['actual_transpiration_cm'])-float(o['BOT']))
   assert residual<1e-9 and abs(float(d['water_residual_cm']))<1e-10,(path,residual)
   result['independent_daily_water_mm']=max(result['independent_daily_water_mm'],residual)
   assert float(d['solute_start_mg_cm2'])==float(d['solute_end_mg_cm2'])==0
 result['status']='NONLINEAR_TEMPORAL_AND_CHANGED_ACCURACY_RESEARCH_REPLAY_PASS'
 result['water_only_active_stress_qualified']=False
 result['separate_budget_active_stress_criteria_pass']=all(all(c['criteria'].values())for c in reports['separate-stress']['cases'].values())
 assert result['separate_budget_active_stress_criteria_pass']
 proof=js('rollback/PROOF.json');assert len(proof)==4 and all(p['complete_joint_bytes_exact']for p in proof)
 return result
def controls(f):
 validate(f);passed=[]
 for p in ['solver/O2-1x-observer-0/state.csv','solver/O0-4x-early-0/budget.csv','temporal/O2-1x/temporal_components.csv','water/O2-4x-resume/restart.bin','root/O0-1x-stress-water/daily_physical.csv','rate-all/O2-1x-water-0/budget.csv','separate-stress/O2-4x-resume/restart.bin','original/4x.csv','rollback/O0-1x/restart.bin','final-root/O2-4x-stress-water/state.csv']:
  bad=dict(f);bad[p]+=b'!'
  try:validate(bad)
  except(AssertionError,ValueError,KeyError,TypeError):passed.append(p);continue
  raise AssertionError('accepted corrupt evidence '+p)
 return passed
def main():
 ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--seal',action='store_true');ap.add_argument('--self-test',action='store_true');a=ap.parse_args()
 if a.seal:
  rollback=Path('/tmp/perf01-solver-failure-rollback');rollback.mkdir(exist_ok=True);proof=[]
  for opt in ['O0','O2']:
   for rain in [1,4]:
    label=f'{opt}-{rain}x';case=rollback/label;source=Path(CAPTURES['solver'])/(label+'-early-0')
    binary=Path(CAPTURES['solver'])/opt/'early'
    if not case.exists():
     case.mkdir()
     for n in ['input.nml','input.swp']:(case/n).write_bytes((source/n).read_bytes())
     cmd=list(map(str,[binary,'input.nml','-','17'if rain==1 else'6','input.swp']))
     started=time.perf_counter();x=subprocess.run(cmd,cwd=case,capture_output=True,timeout=60)
     (case/'EVENT.json').write_text(json.dumps(dict(command=cmd,seconds=time.perf_counter()-started,returncode=x.returncode),indent=2)+'\n')
     for s in ['stdout','stderr']:(case/s).write_bytes(getattr(x,s))
     x.check_returncode()
    assert (case/'restart.bin').read_bytes()==(source/'diagnostic-rejected.bin').read_bytes()
    event=json.loads((case/'EVENT.json').read_text());assert event['returncode']==0
    proof.append(dict(case=label,event=event,executable_sha256=sha(binary.read_bytes()),last_completed_day=17 if rain==1 else 6,complete_joint_bytes_exact=True))
  (rollback/'PROOF.json').write_text(json.dumps(proof,indent=2)+'\n')
  f={}
  for label,path in {**CAPTURES,'rollback':str(rollback)}.items():
   root=Path(path)
   for p in root.rglob('*'):
    if p.is_file()and(p.suffix in ['.json','.f90','.csv','.bin','.nml','.swp','.stdout','.stderr']or p.name in ['stdout','stderr']):f[label+'/'+str(p.relative_to(root))]=p.read_bytes()
  for name in ['study_perf01_solver_failure.py','observe_perf01_temporal_components.py','study_perf01_water_metric.py','supplement_perf01_water_metric.py',Path(__file__).name]:f['sources/'+name]=(ROOT/'benchmarks/performance'/name).read_bytes()
  for ref in ['99f87903','136bda30']:
   f['sources/water-'+ref+'.py']=subprocess.check_output(['git','show',ref+':benchmarks/performance/study_perf01_water_metric.py'],cwd=ROOT)
  f['sources/supplement-initial.py']=subprocess.check_output(['git','show','94994ed7:benchmarks/performance/supplement_perf01_water_metric.py'],cwd=ROOT)
  compiler=ROOT.parent/'compiler'
  f['toolchain.json']=(json.dumps(dict(wrapper=(compiler/'bin/gfortran').read_text(),packages={p.name:hashlib.sha512(p.read_bytes()).hexdigest()for p in (compiler/'packages').glob('*.deb')},origin='Ubuntu snapshot20260828 GNU13.3.0-6ubuntu2~24.04.1; SHA512 checked against apt metadata'),indent=2)+'\n').encode()
  for rain in [1,4]:f[f'original/{rain}x.csv']=Path(f'/tmp/perf01-native-fixed-study/{rain}x-0-legacy/result_output.csv').read_bytes()
  result=validate(f);result['negative_controls']=controls(f)
  f['VALIDATION.json']=(json.dumps(result,indent=2)+'\n').encode();f['MANIFEST.json']=(json.dumps({p:sha(b)for p,b in sorted(f.items())},indent=2)+'\n').encode()
  dest=ROOT/(PREFIX+'_EVIDENCE.tar.xz')
  with tarfile.open(dest,'w:xz')as t:
   for p,b in sorted(f.items()):
    m=tarfile.TarInfo(p);m.size=len(b);m.mode=0o644;t.addfile(m,io.BytesIO(b))
  report=dict(result,evidence=dict(path=str(dest.relative_to(ROOT)),sha256=sha(dest.read_bytes()),bytes=dest.stat().st_size,members=len(f)))
  (ROOT/(PREFIX+'_RESULT.json')).write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report['evidence']))
 else:
  r=json.loads((ROOT/(PREFIX+'_RESULT.json')).read_text());raw=(ROOT/r['evidence']['path']).read_bytes();assert sha(raw)==r['evidence']['sha256']and len(raw)==r['evidence']['bytes'];f=unpack(raw);assert len(f)+1==r['evidence']['members']
  print(json.dumps(controls(f)if a.self_test else validate(f)['status'],indent=2))
if __name__=='__main__':main()
