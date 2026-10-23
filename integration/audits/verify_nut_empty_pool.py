"""Exact empty mineral equilibrium with unchanged predecessor assertions."""
from pathlib import Path
import base64,hashlib,io,json,re,struct,subprocess,tarfile
ROOT=Path(__file__).resolve().parents[2]
BASE='03c1c7a41d66924e2d974275cd14d4bdc4101047'
STATUS='integration/mc-nut01/empty_equilibrium/STATUS.json'
PARENT='integration/audits/verify_nut_singular_pool.py'
SELF='integration/audits/verify_nut_empty_pool.py'
CHANGED=['src/process/mod_b111_soil_n_daily_exchange.f90']
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
 if (ROOT/'integration/mc-sol01/drainage/DAY470_STATUS.json').is_file():return __import__('runpy').run_path(str(ROOT/'integration/audits/verify_saturated_picard.py'))['source'](reader,changed)
 r=record(reader);assert r['source_base']==BASE
 git('merge-base','--is-ancestor',BASE,'HEAD')
 delta={s.split('\t')[1]:s.split('\t')[0]for s in git('diff','--name-status',BASE,'HEAD','--',*SCIENCE).splitlines()}
 assert delta==r['scientific_delta'],'foreign zero-pool source delta'
 assert not git('status','--porcelain','--',*SCIENCE),'dirty zero-pool science'
 assert {p for p in delta if p.startswith('src/')}==set(CHANGED),'foreign production change'
 assert reader(PARENT)==projection(),'predecessor assertion body changed'
 assert reader(FIXTURE)==before(FIXTURE),'original fixture/assertions changed'
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
  def __truediv__(self,p):return ArchivedPath(p)if p in CHANGED else ROOT/p
 ns['ROOT']=HistoricalRoot();ns['source']=source
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
 assert d['status']=='EMPTY_POOL_O0_O2_ODE_ORIGINAL_PASS'and d['cases']==96 and d['incumbent_cases']==288 and d['invalid']==6 and d['default_byte_exact']
 cs=js('direct/checks.json');assert len(cs)==96 and max(c['ode_error']for c in cs)<2e-12 and max(abs(c['residual'])for c in cs)<1e-12
 assert d['original_sha256']=='b343fa9e485e60d76e2bd49067a20cd5ec328264af5d99d7cf1e4ddf07278722'
 def streams(cat):return [f['direct/'+e['stdout']]for e in es if e['category']==cat]
 for cat in ['common','default']:
  assert streams(cat+'_current')==streams(cat+'_previous')and len(streams(cat+'_current'))==2
 assert streams('zero_current')[0]==streams('zero_current')[1]
 for out in streams('zero_previous'):assert len(out.splitlines())==96 and all(int(line.split()[0])!=0 for line in out.splitlines())
 for out in streams('zero_current'):assert len(out.splitlines())==96 and all(int(line.split()[0])==0 for line in out.splitlines())
 for out in streams('invalid'):assert len(out.splitlines())==6 and all(int(line.split()[0])!=0 for line in out.splitlines())
 for out in streams('original_native'):assert len(out.splitlines())==96 and all(all(float(v)==0. for v in line.split())for line in out.splitlines())
 h=js('hist/result.json');inputs(h);es=events('hist/')
 assert h['status']=='HIST_BOUNDED_PHYSICAL_PASS_NOT_FULL_MIGRATION'and h['results']==js('prior-hist-result.json')['results']
 assert sum(e['category']=='compile'for e in es)==654 and sum(e['category']in ['native','restart_native','trace_native']for e in es)==78 and sum(e['category']=='restart_native'for e in es)==56
 reuse=js('hist/REUSE.json');assert reuse['fresh_compile_events']==44 and reuse['reused_compile_events']==610 and reuse['fresh_native_events']==78 and reuse['all_original_assertions_completed']
 assert reuse['original_recipe_sha256']==sha((ROOT/'tests/nut-crop/run_hist_complete.py').read_bytes())
 assert sum(e['category']=='compile'and e['receipt_scope']=='FRESH_CURRENT_EXECUTION'for e in es)==44
 excluded=js('excluded-build-artifacts.json')
 for e in es:
  if e['category']=='compile'and e['receipt_scope'].startswith('REUSED_'):
   obj=Path(e['command'][e['command'].index('-o')+1]);opt=next(v[1:]for v in e['command']if v in ['-O0','-O2']);assert e['object_sha256']==excluded['hist/'+opt+'/'+obj.name]['sha256']
  elif e['category']in ['native','restart_native','trace_native','link']:assert e['receipt_scope']=='FRESH_CURRENT_EXECUTION'
 for opt in ['O0','O2']:
  row=h['results'][opt];assert sha(f['hist/'+opt+'/default.endpoint'])==row['default_endpoint']
  for case,digest in row['endpoint'].items():assert sha(f['hist/'+opt+'/'+case+'.endpoint'])==digest
 n=js('joint/result.json');inputs(n);es=events('joint/')
 assert n['status']=='EMPTY_ACTUAL_CROP_IMMOBILISATION_O0_O2_PASS'and n['actual_runs']==26 and n['separate_process_restarts']==52 and n['days_per_run']==8
 assert sum(e['category']=='native'for e in es)==26 and sum(e['category']=='restart_native'for e in es)==52 and sum(e['category']=='previous_native'for e in es)==4
 for opt in ['O0','O2']:
  build=n['builds'][opt];assert build['provider_result_sha256']==sha(f['hist/result.json'])and build['previous_source_sha256']=={p:sha(before(p))for p in CHANGED}
  assert '-'+opt in build['flags']and'-fcheck=all'in build['flags']
  for case in ['empty_nh4','empty_both']:
   probe='joint/'+opt+'/preimage/'+case;assert f[probe+'.probe-before']==f[probe+'.probe-after']
  for case in ['compete','immobilise','limited','zero_pools','all_zero','bio_zero','hum_zero','resonant','repeated','singular','small_det','empty_nh4','empty_both']:
   stem='joint/'+opt+'/'+case;row=n['results'][opt+'/'+case]
   assert sha(f[stem+'.endpoint'])==row['endpoint_sha256']and sha(f[stem+'.endpoint.ledger'])==row['ledger_sha256']
   ledger=struct.unpack('14d',f[stem+'.endpoint.ledger']);assert list(ledger)==row['ledger']
   assert abs(ledger[0]+ledger[1]-ledger[2]-ledger[13])<1e-12 and(ledger[3]==0 if case=='empty_both'else ledger[3]>0)and ledger[11]<1e-12 and ledger[12]<1e-10
   assert ledger[9:11]==(0.,0.)and(ledger[7]==0 if case in ['empty_nh4','empty_both']else ledger[7]<0)and(ledger[8]==0 if case=='empty_both'else ledger[8]<0)
   if case in ['immobilise','zero_pools','bio_zero','hum_zero','resonant','repeated','singular','small_det']:assert ledger[4]<0
   if case in ['empty_nh4','empty_both']:assert ledger[4]==0.
   if case=='all_zero':assert ledger[4]==0.
   if case in ['compete','immobilise','limited','zero_pools','all_zero','bio_zero','hum_zero','resonant','repeated','singular','small_det']:
    old=js('prior-joint-result.json')['results'][opt+'/'+case];assert row['endpoint_sha256']==old['endpoint_sha256']and row['ledger_sha256']==old['ledger_sha256']
   for day in [1,4]:
    for suffix in ['','.ledger']:assert f[stem+'.endpoint'+suffix]==f[stem+'.fresh-'+str(day)+suffix]
   for day in [2,5]:
    for kind in ['exhaust','stale','water']:assert f[stem+'.restart.before-'+str(day)]==f[stem+'.restart.'+kind+'-reject-'+str(day)]
   if opt=='O2':
    for suffix in ['','.ledger']:assert f[stem+'.endpoint'+suffix]==f['joint/O0/'+case+'.endpoint'+suffix]
 return dict(qualified=True,status='EMPTY_MINERAL_POOL_O0_O2_QUALIFIED',direct_cases=96,newly_accepted=96,incumbent_byte_exact=288,actual_coupled_runs=26,process_restarts=52,hist_native_processes=78,hist_process_restarts=56,fresh_hist_compiles=44,reused_hist_compiles=610,full_mc_nut01_closed=False,exhausting_selected_solution='OPEN_FAIL_CLOSED',canonically_admitted=False)
def verify():
 if (ROOT/'integration/mc-sol01/drainage/DAY470_STATUS.json').is_file():return __import__('runpy').run_path(str(ROOT/'integration/audits/verify_saturated_picard.py'))['verify']()
 source();prior=predecessor()['verify']();current=validate(capsule())
 return {**prior,**current,'current_NUT_coupled_runs':26,'current_NUT_process_restarts':52,'predecessor_controls':179,'predecessor_scope':'All179 unchanged predecessor controls; one explicitly archived daily exchange provider; current direct/HIST/crop proof separate'}
def self_test():
 if (ROOT/'integration/mc-sol01/drainage/DAY470_STATUS.json').is_file():return __import__('runpy').run_path(str(ROOT/'integration/audits/verify_saturated_picard.py'))['self_test']()
 source();old=predecessor()['self_test']();assert len(old)==179
 passed=['predecessor:'+p for p in old];f=capsule();validate(f)
 def reject(label,fn):
  try:fn()
  except(AssertionError,KeyError,ValueError):passed.append(label);return
  raise AssertionError('accepted zero-pool corruption '+label)
 for p in record()['postimages']:reject('source '+p,lambda p=p:source(lambda q:(ROOT/q).read_bytes()+(b'!'if p==q else b'')))
 reject('foreign caller',lambda:source(changed={'src/foreign_zero_pool.f90':'A'}))
 for p in ['direct/checks.json','hist/result.json','hist/REUSE.json','joint/result.json','joint/O0/empty_nh4.endpoint','joint/O2/empty_both.fresh-4.ledger','joint/O0/empty_nh4.restart.exhaust-reject-2','joint/O2/preimage/empty_both.probe-after']:
  bad=dict(f);bad[p]+=b'!';reject('raw '+p,lambda bad=bad:validate(bad))
 return passed
if __name__=='__main__':
 import sys
 print(json.dumps(self_test()if'--self-test'in sys.argv else verify(),indent=2))
