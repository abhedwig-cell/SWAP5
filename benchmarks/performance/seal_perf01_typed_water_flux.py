"""Seal/replay the typed candidate's bounded tests; does not grant owner admission."""
import argparse,csv,hashlib,io,json,statistics,tarfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
PREFIX='benchmarks/performance/PERF01_TYPED_WATER_FLUX_20261023'
CAPTURES={'contracts':'/tmp/perf01-typed-contract-final','native':'/tmp/perf01-typed-composed-qualification',
 'boesten-O0':'/tmp/perf01-typed-boesten-joint-O0','boesten-O2':'/tmp/perf01-typed-boesten-joint-O2',
 'build-O0':'/tmp/perf01-typed-composed-O0','build-O2':'/tmp/perf01-typed-composed-O2'}
sha=lambda b:hashlib.sha256(b).hexdigest()
def unpack(raw):
 with tarfile.open(fileobj=io.BytesIO(raw),mode='r:xz')as t:
  ms=t.getmembers();assert len(ms)==len({m.name for m in ms})
  assert all(m.isfile()and not Path(m.name).is_absolute()and'..'not in Path(m.name).parts for m in ms)
  f={m.name:t.extractfile(m).read()for m in ms}
 assert json.loads(f.pop('MANIFEST.json'))=={p:sha(b)for p,b in f.items()}
 return f
def validate(f):
 js=lambda p:json.loads(f[p])
 def rows(p):return list(csv.DictReader(io.StringIO(f[p].decode())))
 old=ROOT/'benchmarks/performance/PERF01_SOLVER_FAILURE_20261023_EVIDENCE.tar.xz'
 prior=unpack(old.read_bytes());proposal=unpack((ROOT/'benchmarks/performance/PERF01_NATIVE_PROPOSAL_20261023_EVIDENCE.tar.xz').read_bytes())
 r=js('native/RESULT.json');assert r['capsule_sha256']==sha(old.read_bytes())and r['default_capsule_sha256']==sha((ROOT/'benchmarks/performance/PERF01_NATIVE_PROPOSAL_20261023_EVIDENCE.tar.xz').read_bytes())
 assert r['status']=='TYPED_NATIVE_BASE_ROOT_O0_O2_DEFAULT_RESTART_CRITERIA_PASS'
 c=js('contracts/RESULT.json');assert c['status']=='TYPED_WATER_FLUX_AND_INCUMBENT_TRANSACTION_CONTEXT_O0_O2_PASS'
 assert len(c['events'])==24 and sum(e['category']=='native'for e in c['events'])==12
 assert sum(e['returncode']!=0 for e in c['events'])==2
 for e in c['events']:assert(e['returncode']==0)==e['expected_success']
 for name in ['water_flux','incumbent_pond','transaction','context']:assert f['contracts/'+name+'.oracle']
 assert len(r['events'])==62 and sum(e['returncode']!=0 for e in r['events'])==10
 worst=0.;medians={}
 for opt in ['O0','O2']:
  meta=js('build-'+opt+'/column/build-complete.json');assert meta['status']=='BUILT'
  assert meta==r['builds'][opt]
  assert '-'+opt in meta['flags']and'-fcheck=all'in meta['flags']
  for p,h in meta['input_sha256'].items():assert sha((ROOT/p).read_bytes())==h and sha(f['source/'+p])==h,('current compiled input',p)
  for p,h in c['inputs'].items():assert sha((ROOT/p).read_bytes())==h and sha(f['source/'+p])==h
  for rain in [1,4]:
   for n in ['budget.csv','state.csv','endpoint.csv','restart.bin']:assert f[f'native/{opt}-{rain}x-incumbent-no-proposal/'+n]==proposal[f'qualified/{opt}-{rain}x-off-0/'+n]
  for fixture in ['base','stress']:
   for rain in [1,4]:
    key=f'{opt}-{fixture}-{rain}x';prefix='native/'+key
    oracle=f'separate-{fixture}/{opt}-{rain}x-ordinary-0/'
    for repeat in range(3 if opt=='O2'else 1):
     for arm in ['default','typed']:
      for name in ['budget.csv','state.csv','endpoint.csv','restart.bin']:
       expected=prior[oracle+name]if arm=='default'else prior[f'separate-{fixture}/{opt}-{rain}x-water-0/'+name]
       assert f[f'{prefix}-{arm}-{repeat}/'+name]==expected,(key,arm,repeat,name)
    for name in ['state.csv','endpoint.csv','restart.bin']:assert f[prefix+'-resume/'+name]==f[prefix+'-typed-0/'+name]
    data=rows(prefix+'-typed-0/budget.csv');base=rows(prefix+'-default-0/budget.csv');assert len(data)==len(base)==97
    assert rows(prefix+'-resume/budget.csv')==data[48:]
    if opt=='O2':
     for n in ['budget.csv','state.csv','endpoint.csv','restart.bin']:assert f[prefix+'-typed-0/'+n]==f['native/O0-'+fixture+'-'+str(rain)+'x-typed-0/'+n]
    lines=prior[f'original/{rain}x.csv'].decode().splitlines();forcing=list(csv.DictReader(l for l in lines if not l.startswith('*')))[1:]
    for d,o in zip(data,forcing):
     residual=10*abs(float(d['water_end_cm'])-float(d['water_start_cm'])-float(o['RAIN'])+float(d['runoff_cm'])+float(d['soil_evaporation_cm'])+float(d['pond_evaporation_cm'])+float(d['actual_transpiration_cm'])-float(o['BOT']))
     assert residual<1e-9 and abs(float(d['water_residual_cm']))<1e-10
     assert float(d['solute_start_mg_cm2'])==float(d['solute_end_mg_cm2'])==0.
     worst=max(worst,residual)
    for field,limit in [('runoff_cm',.01),('water_end_cm',.01),('actual_transpiration_cm',.01 if fixture=='stress'else 1e-8)]:
     assert 10*max(abs(float(d[field])-float(o[field]))for d,o in zip(data,base))<limit
    assert abs(10*sum(float(d['runoff_cm'])-float(o['runoff_cm'])for d,o in zip(data,base)))<(.05 if fixture=='stress'else .01)
    assert 10*max(abs(float(d['soil_evaporation_cm'])+float(d['pond_evaporation_cm'])-float(o['soil_evaporation_cm'])-float(o['pond_evaporation_cm']))for d,o in zip(data,base))<(.01 if fixture=='stress'else 1e-8)
    if fixture=='stress':assert abs(10*sum(float(d['actual_transpiration_cm'])-float(o['actual_transpiration_cm'])for d,o in zip(data,base)))<.05
    medians[key]={arm:statistics.median(e['seconds']for e in r['events']if e['label'].startswith(key+'-'+arm+'-'))for arm in ['default','typed']}
    assert medians[key]==r['cases'][key]['medians']
  for e in r['events']:
   if e['label'].startswith(opt+'-negative-'):
    assert e['returncode']!=0 and 'native/'+e['label']+'/restart.bin'not in f
  b=js('boesten-'+opt+'/result.json');assert b['status']=='BOESTEN_ROOT_POND_SOLUTE_REJECTION_RETRY_ABA_V3_FRESH_DECODE_PASS'
  assert all(e['returncode']==0 for e in b['events'])
  for p,h in b['inputs'].items():assert sha((ROOT/p).read_bytes())==h
  for x,y in [('original.bin','rejected.bin'),('original.bin','unsupported.bin'),('retry.bin','fresh.bin'),('retry.bin','again.bin'),('original.bin','invalid.bin'),('retry.bin','decoded.bin')]:assert f['boesten-'+opt+'/'+x]==f['boesten-'+opt+'/'+y]
 return dict(status='TYPED_BOUNDED_NATIVE_AND_BOESTEN_COMPOSITION_REPLAY_PASS_OWNER_ADMISSION_PENDING',qualified=False,canonically_admitted=False,
  native_option_processes=62,expected_native_rejections=10,actual_day48_restart_cases=8,contract_native_processes=12,expected_stale_fixture_rejections=2,
  medians=medians,independent_water_max_mm=worst,current_drainage_nut_owner='PENDING_CHANGED_SHARED_INTERFACE_SUCCESSOR')
def controls(f):
 validate(f);passed=[]
 for p in ['native/O2-base-1x-typed-0/budget.csv','native/O0-stress-4x-resume/restart.bin',
  'native/O2-1x-incumbent-no-proposal/state.csv','boesten-O0/rejected.bin',
  'source/src/transaction/mod_transaction_reference.f90','contracts/RESULT.json']:
  bad=dict(f);bad[p]+=b'!'
  try:validate(bad)
  except(AssertionError,ValueError,KeyError,TypeError):passed.append(p);continue
  raise AssertionError('accepted corrupt evidence '+p)
 return passed
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--seal',action='store_true');p.add_argument('--self-test',action='store_true');a=p.parse_args()
 if a.seal:
  f={}
  for group,folder in CAPTURES.items():
   folder=Path(folder)
   for path in folder.rglob('*'):
    if path.is_file()and(path.suffix in ['.csv','.json','.nml','.swp','.bin','.stdout','.stderr','.f90','.f','.inc','.oracle']):f[group+'/'+str(path.relative_to(folder))]=path.read_bytes()
  for opt in ['O0','O2']:
   m=json.loads(f['build-'+opt+'/column/build-complete.json'])
   for path,h in m['reused_artifact_sha256'].items():assert sha(Path(path).read_bytes())==h,('compiled artifact',path)
   for path,h in m['input_sha256'].items():
    raw=(ROOT/path).read_bytes();assert sha(raw)==h;f['source/'+path]=raw
  c=json.loads(f['contracts/RESULT.json'])
  for path,h in c['inputs'].items():raw=(ROOT/path).read_bytes();assert sha(raw)==h;f['source/'+path]=raw
  for name in ['check_perf01_typed_water_flux.py','qualify_perf01_typed_water_flux.py',Path(__file__).name]:f['controller/'+name]=(ROOT/'benchmarks/performance'/name).read_bytes()
  r=validate(f);r['corruption_controls']=controls(f)
  f['VALIDATION.json']=(json.dumps(r,indent=2)+'\n').encode();f['MANIFEST.json']=(json.dumps({p:sha(b)for p,b in sorted(f.items())},indent=2)+'\n').encode()
  path=ROOT/(PREFIX+'_EVIDENCE.tar.xz')
  with tarfile.open(path,'w:xz')as t:
   for name,raw in sorted(f.items()):m=tarfile.TarInfo(name);m.size=len(raw);m.mode=0o644;t.addfile(m,io.BytesIO(raw))
  r['evidence']=dict(path=str(path.relative_to(ROOT)),sha256=sha(path.read_bytes()),bytes=path.stat().st_size,members=len(f))
  (ROOT/(PREFIX+'_RESULT.json')).write_text(json.dumps(r,indent=2)+'\n');print(json.dumps(r['evidence']))
 else:
  r=json.loads((ROOT/(PREFIX+'_RESULT.json')).read_text());raw=(ROOT/r['evidence']['path']).read_bytes();assert sha(raw)==r['evidence']['sha256']
  f=unpack(raw);print(json.dumps(controls(f)if a.self_test else validate(f),indent=2))
if __name__=='__main__':main()
