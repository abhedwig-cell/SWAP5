"""Exact zero receiving-pool turnover limit and unchanged predecessor assertions."""
from pathlib import Path
import base64,hashlib,io,json,re,struct,subprocess,tarfile
ROOT=Path(__file__).resolve().parents[2]
BASE='c459429adb976f1d4b0c2a11f58d520909d2ba3c'
STATUS='integration/mc-nut01/single_zero_pool/STATUS.json'
PARENT='integration/audits/verify_native_drainage.py'
SELF='integration/audits/verify_nut_single_zero_pool.py'
CHANGED=['src/process/mod_b111_soil_organic_turnover.f90','src/process/mod_b111_soil_organic_dissimilation.f90']
FIXTURE='tests/nut-crop/test_b112_retained_joint.f90'
SCIENCE=['src','app','tools','tests','examples','reference','.github','integration/audits','integration/performance','integration/diagnostics']
sha=lambda b:hashlib.sha256(b).hexdigest()
def git(*a):return subprocess.check_output(['git',*a],cwd=ROOT,text=True).strip()
def before(p):return subprocess.check_output(['git','show',BASE+':'+p],cwd=ROOT)
def record(reader=lambda p:(ROOT/p).read_bytes()):return json.loads(reader(STATUS))
def projection():
 s=before(PARENT).decode().replace('def verify():source();return validate(capsule())\n','def verify():\n source();return validate(capsule())\n')
 for name,args in [('source','reader,changed'),('verify',''),('self_test','')]:
  at=s.index('\n',re.search(r'^def '+name+r'\(',s,re.M).start())+1
  s=s[:at]+" if (ROOT/'"+STATUS+"').is_file():return __import__('runpy').run_path(str(ROOT/'"+SELF+"'))['"+name+"']("+args+")\n"+s[at:]
 return s.encode()
def source(reader=lambda p:(ROOT/p).read_bytes(),changed=None):
 if (ROOT/'benchmarks/performance/PERF01_TYPED_WATER_FLUX_20261023_STATUS.json').is_file():return __import__('runpy').run_path(str(ROOT/'integration/audits/verify_perf01_typed_water_flux.py'))['source'](reader,changed)
 r=record(reader);assert r['source_base']==BASE
 git('merge-base','--is-ancestor',BASE,'HEAD')
 delta={s.split('\t')[1]:s.split('\t')[0]for s in git('diff','--name-status',BASE,'HEAD','--',*SCIENCE).splitlines()}
 assert delta==r['scientific_delta'],'foreign zero-pool source delta'
 assert not git('status','--porcelain','--',*SCIENCE),'dirty zero-pool science'
 assert {p for p in delta if p.startswith('src/')}==set(CHANGED),'foreign production change'
 assert reader(PARENT)==projection(),'predecessor assertion body changed'
 old=b'  bad_sp=sp;bad_sp%organic_reference%ratecon_bio=0d0'
 assert before(FIXTURE).count(old)==1
 assert reader(FIXTURE)==before(FIXTURE).replace(old,b' bad_sp=sp;bad_sp%organic_reference%asfa_bio=.5d0;bad_sp%organic_reference%asfa_hum=.5d0'),'rejection assertions changed'
 for p,h in {**r['incumbent_inputs'],**r['postimages']}.items():assert sha(reader(p))==h,('zero-pool source',p)
 if changed is not None:
  for p in changed:assert p in delta or subprocess.run(['git','cat-file','-e',BASE+':'+p],cwd=ROOT,capture_output=True).returncode==0,'foreign caller'
 return json.loads(reader('integration/audits/MC_SOL01_DYNAMIC_DECAY_STATUS.json'))['swp_water_successor']
def capsule():
 e=record()['evidence'];raw=base64.b64decode((ROOT/e['path']).read_bytes(),validate=True);assert sha(raw)==e['sha256']
 with tarfile.open(fileobj=io.BytesIO(raw),mode='r:xz')as t:
  ms=t.getmembers();assert len(ms)==len({m.name for m in ms})and all(m.isfile()and not Path(m.name).is_absolute()and'..'not in Path(m.name).parts for m in ms)
  f={m.name:t.extractfile(m).read()for m in ms}
 manifest=json.loads(f.pop('MANIFEST.json'));assert manifest=={p:sha(b)for p,b in f.items()}
 return f
def predecessor():
 ns=dict(__file__=str(ROOT/PARENT),__name__='frozen_demand_assertions');exec(compile(before(PARENT),PARENT,'exec'),ns)
 class ArchivedPath:
  def __init__(self,p):self.p=p
  def read_bytes(self):return before(self.p)
 class HistoricalRoot:
  def __str__(self):return str(ROOT)
  def __fspath__(self):return str(ROOT)
  def __truediv__(self,p):return ArchivedPath(p)if p in CHANGED+[FIXTURE]else ROOT/p
 ns['ROOT']=HistoricalRoot();ns['source']=source
 # The native SOL/drainage binaries may only be inherited if they do not
 # compile any changed NUT provider. Current NUT composition is separate below.
 old=ns['capsule']()
 for opt in ['O0','O2']:
  inputs=json.loads(old['build-'+opt+'/column/build-complete.json'])['input_sha256']
  assert set(CHANGED+[FIXTURE]).isdisjoint(inputs),'native drainage closure consumes changed NUT'
 return ns
def validate(f):
 def js(p):return json.loads(f[p])
 def inputs(r):
  for p,h in r['input_sha256'].items():assert sha((ROOT/p).read_bytes())==h,('executed current input',p)
 def events(prefix):
  es=js(prefix+'events.json');assert all(e['returncode']==0 for e in es)
  for e in es:
   for k in ['stdout','stderr']:assert prefix+e[k]in f
  return es
 d=js('direct/result.json');inputs(d);es=events('direct/')
 assert d['status']=='SINGLE_ZERO_POOL_O0_O2_ODE_MATRIX_AND_CARBON_PASS'and d['zero_cases']==d['formerly_rejected']==466 and d['incumbent_cases']==192 and d['invalid']==4 and d['incumbent_byte_exact']and d['fraction_cases_per_optimization']==13
 cs=js('direct/checks.json');assert len(cs)==466 and max(c['ode_error']for c in cs)<2e-11 and max(c['matrix_error']for c in cs)<2e-11 and max(abs(c['carbon_residual'])for c in cs)<1e-12
 fs=js('direct/fraction-checks.json');assert len(fs)==20 and max(c['loss_error']for c in fs)<5e-15 and max(c['average_error']for c in fs)<5e-15
 def streams(cat):return [f['direct/'+e['stdout']]for e in es if e['category']==cat]
 assert streams('common_current')==streams('common_previous')and len(streams('common_current'))==2
 assert streams('zero_current')[0]==streams('zero_current')[1]
 for out in streams('zero_previous'):assert len(out.splitlines())==466 and all(any(int(v)!=0 for v in line.split()[:2])for line in out.splitlines())
 for out in streams('zero_current'):assert len(out.splitlines())==466 and all(line.split()[:2]==[b'0',b'0']for line in out.splitlines())
 for out in streams('invalid'):assert len(out.splitlines())==4 and all(any(int(x)!=0 for x in line.split()[:2])for line in out.splitlines())
 for out in streams('fraction_native'):assert len(out.splitlines())==13 and all(int(line.split()[0])!=0 for line in out.splitlines()[-3:])
 h=js('hist/result.json');inputs(h);es=events('hist/')
 assert h['status']=='HIST_BOUNDED_PHYSICAL_PASS_NOT_FULL_MIGRATION'and h['results']==js('prior-hist-result.json')['results']
 assert sum(e['category']=='compile'for e in es)==654 and sum(e['category']in ['native','restart_native','trace_native']for e in es)==78 and sum(e['category']=='restart_native'for e in es)==56
 reuse=js('hist/REUSE.json');assert reuse['fresh_compile_events']==74 and reuse['reused_compile_events']==580 and reuse['fresh_native_events']==78 and reuse['all_original_assertions_completed']
 assert reuse['original_recipe_sha256']==sha((ROOT/'tests/nut-crop/run_hist_complete.py').read_bytes())
 assert sum(e['category']=='compile'and e['receipt_scope']=='FRESH_CURRENT_EXECUTION'for e in es)==74
 excluded=js('excluded-build-artifacts.json')
 for e in es:
  if e['category']=='compile'and e['receipt_scope'].startswith('REUSED_'):
   obj=Path(e['command'][e['command'].index('-o')+1]);opt=next(v[1:]for v in e['command']if v in ['-O0','-O2']);assert e['object_sha256']==excluded['hist/'+opt+'/'+obj.name]['sha256']
  elif e['category']in ['native','restart_native','trace_native','link']:assert e['receipt_scope']=='FRESH_CURRENT_EXECUTION'
 for opt in ['O0','O2']:
  row=h['results'][opt];assert sha(f['hist/'+opt+'/default.endpoint'])==row['default_endpoint']
  for case,digest in row['endpoint'].items():assert sha(f['hist/'+opt+'/'+case+'.endpoint'])==digest
 n=js('joint/result.json');inputs(n);es=events('joint/')
 assert n['status']=='SINGLE_ZERO_ACTUAL_CROP_IMMOBILISATION_O0_O2_PASS'and n['actual_runs']==14 and n['separate_process_restarts']==28 and n['days_per_run']==8
 assert sum(e['category']=='native'for e in es)==14 and sum(e['category']=='restart_native'for e in es)==28 and sum(e['category']=='previous_native'for e in es)==4
 for opt in ['O0','O2']:
  build=n['builds'][opt];assert build['provider_result_sha256']==sha(f['hist/result.json'])and build['previous_source_sha256']=={p:sha(before(p))for p in CHANGED}
  assert '-'+opt in build['flags']and'-fcheck=all'in build['flags']
  for case in ['bio_zero','hum_zero']:
   probe='joint/'+opt+'/preimage/'+case;assert f[probe+'.probe-before']==f[probe+'.probe-after']
  for case in ['compete','immobilise','limited','zero_pools','all_zero','bio_zero','hum_zero']:
   stem='joint/'+opt+'/'+case;row=n['results'][opt+'/'+case]
   assert sha(f[stem+'.endpoint'])==row['endpoint_sha256']and sha(f[stem+'.endpoint.ledger'])==row['ledger_sha256']
   ledger=struct.unpack('14d',f[stem+'.endpoint.ledger']);assert list(ledger)==row['ledger']
   assert abs(ledger[0]+ledger[1]-ledger[2]-ledger[13])<1e-12 and ledger[3]>0 and ledger[11]<1e-12 and ledger[12]<1e-10
   assert ledger[9:11]==(0.,0.)and max(ledger[7:9])<0
   if case in ['immobilise','zero_pools','bio_zero','hum_zero']:assert ledger[4]<0
   if case=='all_zero':assert ledger[4]==0.
   if case in ['compete','immobilise','limited','zero_pools','all_zero']:
    old=js('prior-joint-result.json')['results'][opt+'/'+case];assert row['endpoint_sha256']==old['endpoint_sha256']and row['ledger_sha256']==old['ledger_sha256']
   for day in [1,4]:
    for suffix in ['','.ledger']:assert f[stem+'.endpoint'+suffix]==f[stem+'.fresh-'+str(day)+suffix]
   for day in [2,5]:
    for kind in ['exhaust','stale','water']:assert f[stem+'.restart.before-'+str(day)]==f[stem+'.restart.'+kind+'-reject-'+str(day)]
   if opt=='O2':
    for suffix in ['','.ledger']:assert f[stem+'.endpoint'+suffix]==f['joint/O0/'+case+'.endpoint'+suffix]
 assert b'optimization drift'in f['failed/optimization-order/runner.log']
 return dict(qualified=True,status='SINGLE_ZERO_RECEIVING_POOL_O0_O2_QUALIFIED',direct_cases=466,newly_accepted=466,incumbent_byte_exact=192,actual_coupled_runs=14,process_restarts=28,hist_native_processes=78,hist_process_restarts=56,fresh_hist_compiles=74,reused_hist_compiles=580,full_mc_nut01_closed=False,exhausting_selected_solution='OPEN_FAIL_CLOSED',canonically_admitted=False)
def verify():
 if (ROOT/'benchmarks/performance/PERF01_TYPED_WATER_FLUX_20261023_STATUS.json').is_file():return __import__('runpy').run_path(str(ROOT/'integration/audits/verify_perf01_typed_water_flux.py'))['verify']()
 source();prior=predecessor()['verify']();current=validate(capsule())
 return {**prior,**current,'current_NUT_coupled_runs':14,'current_NUT_process_restarts':28,'predecessor_controls':111,'predecessor_scope':'All36 drainage and75 zero-pool predecessor controls; three explicitly archived NUT source identities; current direct/HIST/crop proof separate'}
def zero_pool_controls():
 path='integration/audits/verify_nut_zero_pools.py';base='57e1b3f2635559df0db0350a96f0e06b2e3b9cc7'
 ns=dict(__file__=str(ROOT/path),__name__='exact_zero_pool_controls')
 exec(compile(subprocess.check_output(['git','show',base+':'+path],cwd=ROOT),path,'exec'),ns)
 historical=set(CHANGED+[FIXTURE,'app/solute_crop/read_swp_project.f90','app/solute_project/main.f90','tools/solute/run_project.py','src/runtime/mod_fmr_serialized_reference_backend.f90'])
 class ArchivedPath:
  def __init__(self,p):self.p=p
  def read_bytes(self):return subprocess.check_output(['git','show',base+':'+self.p],cwd=ROOT)
 class HistoricalRoot:
  def __str__(self):return str(ROOT)
  def __fspath__(self):return str(ROOT)
  def __truediv__(self,p):return ArchivedPath(p)if p in historical else ROOT/p
 ns['ROOT']=HistoricalRoot();ns['source']=source
 result=ns['self_test']();assert len(result)==75;return result
def self_test():
 if (ROOT/'benchmarks/performance/PERF01_TYPED_WATER_FLUX_20261023_STATUS.json').is_file():return __import__('runpy').run_path(str(ROOT/'integration/audits/verify_perf01_typed_water_flux.py'))['self_test']()
 source();old=predecessor()['self_test']();assert len(old)==36
 passed=['drainage:'+p for p in old]+['zero-pool:'+p for p in zero_pool_controls()];f=capsule();validate(f)
 def reject(label,fn):
  try:fn()
  except(AssertionError,KeyError,ValueError):passed.append(label);return
  raise AssertionError('accepted zero-pool corruption '+label)
 for p in record()['postimages']:reject('source '+p,lambda p=p:source(lambda q:(ROOT/q).read_bytes()+(b'!'if p==q else b'')))
 reject('foreign caller',lambda:source(changed={'src/foreign_zero_pool.f90':'A'}))
 for p in ['direct/checks.json','direct/fraction-checks.json','hist/result.json','hist/REUSE.json','joint/result.json','joint/O0/bio_zero.endpoint','joint/O2/hum_zero.fresh-4.ledger','joint/O0/bio_zero.restart.exhaust-reject-2','joint/O2/preimage/hum_zero.probe-after']:
  bad=dict(f);bad[p]+=b'!';reject('raw '+p,lambda bad=bad:validate(bad))
 return passed
if __name__=='__main__':
 import sys
 print(json.dumps(self_test()if'--self-test'in sys.argv else verify(),indent=2))
