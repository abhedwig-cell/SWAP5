"""Bounded nondepleting crop/signed-top owner with unchanged predecessor assertions."""
from pathlib import Path
import base64,hashlib,io,json,subprocess,tarfile
ROOT=Path(__file__).resolve().parents[2]
BASE='67a21309490a4e5398e619bb28f0414d6d774757'
STATUS='integration/mc-nut01/nondepleting_top/STATUS.json'
PARENT='integration/audits/verify_native_detailed_rain.py'
SELF='integration/audits/verify_nut_nondepleting.py'
SCIENCE=['src','app','tools','tests','examples','reference','.github','integration/audits','integration/performance','integration/diagnostics']
sha=lambda b:hashlib.sha256(b).hexdigest()
def git(*a):return subprocess.check_output(['git',*a],cwd=ROOT,text=True).strip()
def before(p):return subprocess.check_output(['git','show',BASE+':'+p],cwd=ROOT)
def record(reader=lambda p:(ROOT/p).read_bytes()):return json.loads(reader(STATUS))
def projection():
 s=before(PARENT).decode().replace('def verify():source();return validate(capsule())\n','def verify():\n source();return validate(capsule())\n')
 for name,args in [('source','reader,changed'),('verify',''),('self_test','')]:
  at=s.index('\n',s.index('\ndef '+name+'(')+1)+1
  s=s[:at]+" if (ROOT/'"+STATUS+"').is_file():return __import__('runpy').run_path(str(ROOT/'"+SELF+"'))['"+name+"']("+args+")\n"+s[at:]
 return s.encode()
def source(reader=lambda p:(ROOT/p).read_bytes(),changed=None):
 r=record(reader);assert r['baseline']==BASE
 git('merge-base','--is-ancestor',BASE,'HEAD')
 delta={s.split('\t')[1]:s.split('\t')[0]for s in git('diff','--name-status',BASE,'HEAD','--',*SCIENCE).splitlines()}
 assert delta==r['scientific_delta'],'unregistered nondepleting source delta'
 assert not git('status','--porcelain','--',*SCIENCE),'dirty nondepleting science'
 assert {p for p in delta if p.startswith('src/')}==set(r['production_changes']),'foreign production change'
 assert reader(PARENT)==projection(),'predecessor assertion body changed'
 for p,h in {**r['incumbent_inputs'],**r['postimages']}.items():assert sha(reader(p))==h,('nondepleting source',p)
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
 ns=dict(__file__=str(ROOT/PARENT),__name__='frozen_nondepleting_predecessor')
 exec(compile(before(PARENT),PARENT,'exec'),ns);ns['source']=source
 return ns
def historical_nut():
 # The previous numerical/coupled capsule is historical for these four source
 # providers. Only its archived input-identity reads use the exact old bytes.
 # Current behavior is proved by new direct, HIST and actual crop composition.
 p='integration/audits/verify_nut_regular_limits.py'
 ns=dict(__file__=str(ROOT/p),__name__='frozen_regular_limit_validation')
 exec(compile(before(p),p,'exec'),ns)
 class ArchivedPath:
  def __init__(self,p):self.p=p
  def read_bytes(self):return before(self.p)
 class ArchiveRoot:
  def __truediv__(self,p):return ArchivedPath(p)if p in record()['production_changes']else ROOT/p
 ns['ROOT']=ArchiveRoot()
 return ns['validate'](ns['capsule']())
def validate(f):
 def js(p):return json.loads(f[p])
 def inputs(r):
  for p,h in r['input_sha256'].items():assert sha((ROOT/p).read_bytes())==h,('executed nondepleting input',p)
 def events(prefix):
  es=js(prefix+'events.json');assert all(e['returncode']==0 for e in es)
  for e in es:
   for k in ['stdout','stderr']:assert prefix+e[k]in f
  return es
 d=js('direct/result.json');inputs(d);es=events('direct/')
 assert d['status']=='NONDEPLETING_EXCHANGE_O0_O2_ODE_AND_ORIGINAL_PASS'and d['cases']==144 and d['invalid']==8 and d['default_byte_exact']
 assert d['original_sha256']=='b343fa9e485e60d76e2bd49067a20cd5ec328264af5d99d7cf1e4ddf07278722'
 cs=js('direct/checks.json');assert len(cs)==144 and max(c['ode_error']for c in cs)<2e-12 and max(c['original_error']for c in cs)<2e-12 and max(abs(c['residual'])for c in cs)<1e-12
 native=[f['direct/'+e['stdout']]for e in es if e['category']=='native'];assert len(native)==2 and native[0]==native[1]
 h=js('hist/result.json');inputs(h);es=events('hist/');reuse=js('hist/REUSE.json')
 assert h['status']=='HIST_BOUNDED_PHYSICAL_PASS_NOT_FULL_MIGRATION'and h['results']==js('prior-hist-result.json')['results']
 assert reuse['all_original_assertions_completed']and reuse['complete_incumbent_results_exact']and reuse['fresh_compile_events']==46 and reuse['reused_compile_events']==608 and reuse['fresh_native_events']==78
 assert sum(e['category']=='restart_native'for e in es)==56
 for e in es:
  if e['category']in ['native','restart_native','trace_native','link']:assert e['receipt_scope']=='FRESH_CURRENT_EXECUTION'
 for opt in ['O0','O2']:
  row=h['results'][opt];assert sha(f['hist/'+opt+'/default.endpoint'])==row['default_endpoint']
  for case,digest in row['endpoint'].items():assert sha(f['hist/'+opt+'/'+case+'.endpoint'])==digest
 n=js('joint/result.json');inputs(n);es=events('joint/')
 assert n['status']=='NONDEPLETING_ACTUAL_CROP_RICHARDS_IMMOBILISATION_O0_O2_PASS'and n['actual_runs']==4 and n['separate_process_restarts']==8 and n['days_per_run']==8
 assert sum(e['category']=='native'for e in es)==4 and sum(e['category']=='restart_native'for e in es)==8
 import struct
 for opt in ['O0','O2']:
  for case in ['compete','immobilise']:
   stem='joint/'+opt+'/'+case;row=n['results'][opt+'/'+case]
   assert sha(f[stem+'.endpoint'])==row['endpoint_sha256']and sha(f[stem+'.endpoint.ledger'])==row['ledger_sha256']
   ledger=struct.unpack('14d',f[stem+'.endpoint.ledger']);assert list(ledger)==row['ledger']
   assert abs(ledger[0]+ledger[1]-ledger[2]-ledger[13])<1e-12 and ledger[3]>0 and ledger[11]<1e-12 and ledger[12]<1e-10
   assert ledger[9:11]==(0.,0.)and max(ledger[7:9])<0
   if case=='immobilise':assert ledger[4]<0
   for day in [1,4]:
    for suffix in ['','.ledger']:assert f[stem+'.endpoint'+suffix]==f[stem+'.fresh-'+str(day)+suffix]
   for day in [2,5]:
    for kind in ['exhaust','stale','water']:assert f[stem+'.restart.before-'+str(day)]==f[stem+'.restart.'+kind+'-reject-'+str(day)]
   if opt=='O2':
    for suffix in ['','.ledger']:assert f[stem+'.endpoint'+suffix]==f['joint/O0/'+case+'.endpoint'+suffix]
 old=js('original-parent.json');assert old['owner']['qualified']and len(old['controls'])==17
 return dict(qualified=True,status='NONDEPLETING_TOP_ACTIVE_CROP_IMMOBILISATION_O0_O2_QUALIFIED',direct_cases=144,actual_coupled_runs=4,process_restarts=8,hist_native_processes=78,full_mc_nut01_closed=False,exhausting_competing_sinks='OPEN_FAIL_CLOSED',canonically_admitted=False)
def verify():
 source();prior=predecessor()['verify']();historical_nut();current=validate(capsule())
 return {**prior,**current,'predecessor_controls':17,'predecessor_scope':'Original detailed-rain assertions unchanged; current changed NUT providers freshly qualified and default HIST output byte-exact'}
def self_test():
 source();old=predecessor()['self_test']();assert len(old)==17
 passed=['predecessor:'+p for p in old];f=capsule();validate(f);historical_nut()
 def reject(label,fn):
  try:fn()
  except(AssertionError,KeyError,ValueError):passed.append(label);return
  raise AssertionError('accepted nondepleting corruption '+label)
 for p in record()['postimages']:reject('source '+p,lambda p=p:source(lambda q:(ROOT/q).read_bytes()+(b'!'if p==q else b'')))
 reject('foreign caller',lambda:source(changed={'src/foreign_nondepleting.f90':'A'}))
 for p in ['direct/checks.json','hist/result.json','hist/REUSE.json','joint/result.json','original-parent.json','joint/O0/immobilise.endpoint','joint/O2/compete.fresh-4.ledger','joint/O0/compete.restart.exhaust-reject-2']:
  bad=dict(f);bad[p]+=b'!';reject('raw '+p,lambda bad=bad:validate(bad))
 return passed
if __name__=='__main__':
 import sys
 print(json.dumps(self_test()if'--self-test'in sys.argv else verify(),indent=2))
