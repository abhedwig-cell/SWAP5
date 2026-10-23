"""Unused-demand exhaustion: current physical proof and frozen Boesten assertions."""
from pathlib import Path
import base64,hashlib,io,json,re,subprocess,tarfile
ROOT=Path(__file__).resolve().parents[2]
BASE='3461a520fd2858782058cacb56f3cde606f2a188'
STATUS='integration/mc-nut01/demand_candidate/STATUS.json'
PARENT='integration/audits/verify_native_boesten.py'
SELF='integration/audits/verify_nut_demand_candidate.py'
CHANGED='src/process/mod_b111_soil_n_daily_exchange.f90'
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
 r=record(reader);assert r['baseline']==BASE
 git('merge-base','--is-ancestor',BASE,'HEAD')
 delta={s.split('\t')[1]:s.split('\t')[0]for s in git('diff','--name-status',BASE,'HEAD','--',*SCIENCE).splitlines()}
 assert delta==r['scientific_delta'],'foreign demand candidate source delta'
 assert not git('status','--porcelain','--',*SCIENCE),'dirty demand science'
 assert {p for p in delta if p.startswith('src/')}=={CHANGED},'foreign production change'
 assert reader(PARENT)==projection(),'predecessor assertion body changed'
 for p,h in {**r['incumbent_inputs'],**r['postimages']}.items():assert sha(reader(p))==h,('demand candidate source',p)
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
 ns=dict(__file__=str(ROOT/PARENT),__name__='frozen_boesten_assertions')
 exec(compile(before(PARENT),PARENT,'exec'),ns)
 class ArchivedPath:
  def read_bytes(self):return before(CHANGED)
 class HistoricalRoot:
  def __fspath__(self):return str(ROOT)
  def __truediv__(self,p):return ArchivedPath()if p==CHANGED else ROOT/p
 # The Boesten capsule's old NUT builds are historical for one source. Its
 # original assertions stay exact, with only this archived identity projected.
 # New current source/physics/restart evidence is validated independently below.
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
 assert d['status']=='UNUSED_DEMAND_EXHAUSTION_O0_O2_ODE_AND_ORIGINAL_PASS'and d['cases']==288 and d['incumbent_cases']==144 and d['newly_accepted']==144 and d['invalid']==8 and d['default_byte_exact']
 assert d['original_sha256']=='b343fa9e485e60d76e2bd49067a20cd5ec328264af5d99d7cf1e4ddf07278722'
 cs=js('direct/checks.json');assert len(cs)==288 and max(c['ode_error']for c in cs)<2e-12 and max(c['original_error']for c in cs)<2e-12 and max(abs(c['residual'])for c in cs)<1e-12
 current=[f['direct/'+e['stdout']]for e in es if e['category']=='native'];previous=[f['direct/'+e['stdout']]for e in es if e['category']=='previous_native']
 assert len(current)==len(previous)==2 and current[0]==current[1]and previous[0]==previous[1]
 for out,old in zip(current,previous):
  assert out.splitlines()[:144]==old.splitlines()[:144]
  assert sum(int(n.split()[0])==0 and int(o.split()[0])!=0 for n,o in zip(out.splitlines(),old.splitlines()))==144
 h=js('hist/result.json');inputs(h);es=events('hist/')
 assert h['status']=='HIST_BOUNDED_PHYSICAL_PASS_NOT_FULL_MIGRATION'and h['results']==js('prior-hist-result.json')['results']
 assert sum(e['category']=='compile'for e in es)==654 and sum(e['category']in ['native','restart_native','trace_native']for e in es)==78 and sum(e['category']=='restart_native'for e in es)==56
 for opt in ['O0','O2']:
  row=h['results'][opt];assert sha(f['hist/'+opt+'/default.endpoint'])==row['default_endpoint']
  for case,digest in row['endpoint'].items():assert sha(f['hist/'+opt+'/'+case+'.endpoint'])==digest
 n=js('joint/result.json');inputs(n);es=events('joint/')
 assert n['status']=='UNUSED_DEMAND_ACTUAL_LIMITED_CROP_O0_O2_PASS'and n['actual_runs']==6 and n['separate_process_restarts']==12 and n['days_per_run']==8
 assert sum(e['category']=='native'for e in es)==6 and sum(e['category']=='restart_native'for e in es)==12
 assert sum(e['category']=='previous_native'for e in es)==2
 import struct
 for opt in ['O0','O2']:
  build=n['builds'][opt];assert build['provider_result_sha256']==sha(f['hist/result.json'])and build['previous_source_sha256']==sha(before(CHANGED))
  assert '-'+opt in build['flags']and'-fcheck=all'in build['flags']
  probe='joint/'+opt+'/preimage/limited'
  assert f[probe+'.probe-before']==f[probe+'.probe-after']
  for case in ['compete','immobilise','limited']:
   stem='joint/'+opt+'/'+case;row=n['results'][opt+'/'+case]
   assert sha(f[stem+'.endpoint'])==row['endpoint_sha256']and sha(f[stem+'.endpoint.ledger'])==row['ledger_sha256']
   ledger=struct.unpack('14d',f[stem+'.endpoint.ledger']);assert list(ledger)==row['ledger']
   assert abs(ledger[0]+ledger[1]-ledger[2]-ledger[13])<1e-12 and ledger[3]>0 and ledger[11]<1e-12 and ledger[12]<1e-10
   assert ledger[9:11]==(0.,0.)and max(ledger[7:9])<0
   if case=='immobilise':assert ledger[4]<0
   if case!='limited':
    old=js('prior-joint-result.json')['results'][opt+'/'+case];assert row['endpoint_sha256']==old['endpoint_sha256']and row['ledger_sha256']==old['ledger_sha256']
   for day in [1,4]:
    for suffix in ['','.ledger']:assert f[stem+'.endpoint'+suffix]==f[stem+'.fresh-'+str(day)+suffix]
   for day in [2,5]:
    for kind in ['exhaust','stale','water']:assert f[stem+'.restart.before-'+str(day)]==f[stem+'.restart.'+kind+'-reject-'+str(day)]
   if opt=='O2':
    for suffix in ['','.ledger']:assert f[stem+'.endpoint'+suffix]==f['joint/O0/'+case+'.endpoint'+suffix]
 return dict(qualified=True,status='UNUSED_DEMAND_EXHAUSTION_SUPPLY_LIMITED_CROP_O0_O2_QUALIFIED',direct_cases=288,newly_accepted=144,actual_coupled_runs=6,process_restarts=12,hist_native_processes=78,full_mc_nut01_closed=False,exhausting_selected_solution='OPEN_FAIL_CLOSED',canonically_admitted=False)
def verify():
 source();prior=predecessor()['verify']();current=validate(capsule())
 return {**prior,**current,'current_NUT_coupled_runs':6,'current_NUT_process_restarts':12,'predecessor_controls':36,'predecessor_scope':'Exact Boesten assertions, one explicitly historical NUT input; fresh current HIST/crop proof separately validated'}
def self_test():
 source();old=predecessor()['self_test']();assert len(old)==36
 passed=['predecessor:'+p for p in old];f=capsule();validate(f)
 def reject(label,fn):
  try:fn()
  except(AssertionError,KeyError,ValueError):passed.append(label);return
  raise AssertionError('accepted demand corruption '+label)
 for p in record()['postimages']:reject('source '+p,lambda p=p:source(lambda q:(ROOT/q).read_bytes()+(b'!'if p==q else b'')))
 reject('foreign caller',lambda:source(changed={'src/foreign_demand.f90':'A'}))
 for p in ['direct/checks.json','hist/result.json','joint/result.json','joint/O0/limited.endpoint','joint/O2/limited.fresh-4.ledger','joint/O0/limited.restart.exhaust-reject-2']:
  bad=dict(f);bad[p]+=b'!';reject('raw '+p,lambda bad=bad:validate(bad))
 return passed
if __name__=='__main__':
 import sys
 print(json.dumps(self_test()if'--self-test'in sys.argv else verify(),indent=2))
