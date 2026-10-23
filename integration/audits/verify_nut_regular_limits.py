"""Bounded finite-donor limits: current composition plus frozen predecessor controls.

The predecessor's assertion bodies stay byte-exact. Its recorded native builds
are explicitly checked against their historical transport source. Current direct
and coupled evidence separately qualifies the sole changed numerical branch.
"""
from pathlib import Path
import base64,hashlib,io,json,math,subprocess,tarfile
ROOT=Path(__file__).resolve().parents[2]
BASE='f729f0b058434c89009646f2d86bb19027c348fe'
STATUS='integration/mc-nut01/MC-NUT01-HIST-COMPLETE_STATUS.json'
SELF='integration/audits/verify_nut_regular_limits.py'
PARENT='integration/audits/verify_native_seasonal_bottom.py'
TRANSPORT='src/process/mod_b111_soil_n_transport.f90'
SCIENCE=['src','app','tools','tests','examples','reference','.github','integration/audits','integration/performance','integration/diagnostics']
sha=lambda b:hashlib.sha256(b).hexdigest()
def require(ok,why):
 if not ok:raise AssertionError(why)
def git(*args):return subprocess.check_output(['git',*args],cwd=ROOT,text=True).strip()
def before(p):return subprocess.check_output(['git','show',BASE+':'+p],cwd=ROOT)
def record(reader=lambda p:(ROOT/p).read_bytes()):
 return json.loads(reader(STATUS))['negative_reference_candidate_20261021']['regular_limits_successor_20261023']
def enabled():return 'admission_candidate'in record()
def projection():
 text=before(PARENT).decode()
 for name in ['source','verify','self_test']:
  offset=text.index('\n',text.index('def '+name+'('))+1
  args='reader,changed'if name=='source'else''
  hook=" successor=ROOT/'"+SELF+"'\n if successor.is_file():\n  owner=__import__('runpy').run_path(str(successor))\n  if owner['enabled']():return owner['"+name+"']("+args+")\n"
  text=text[:offset]+hook+text[offset:]
 return text.encode()
def procedure(text,name):
 start=text.index(' subroutine '+name+'(')
 return text[start:text.index(' end subroutine',start)+len(' end subroutine')]
def source(reader=lambda p:(ROOT/p).read_bytes(),changed=None):
 r=record(reader)['admission_candidate'];require(r['baseline']==BASE,'regular limit baseline')
 git('merge-base','--is-ancestor',BASE,'HEAD')
 require(not git('status','--porcelain','--',*SCIENCE),'dirty regular limit science')
 delta={row.split('\t')[1]:row.split('\t')[0]for row in git('diff','--name-status',BASE,'HEAD','--',*SCIENCE).splitlines()}
 require(delta==r['scientific_delta'],'foreign regular limit scientific delta')
 require({p for p in delta if p.startswith('src/')}=={TRANSPORT},'foreign production change')
 for p,h in {**r['incumbent_inputs'],**r['postimages']}.items():require(sha(reader(p))==h,'regular limit source '+p)
 require(reader(PARENT)==projection(),'predecessor assertion bodies changed')
 current=json.loads(reader(STATUS));current['negative_reference_candidate_20261021'].pop('regular_limits_successor_20261023')
 require(current==json.loads(before(STATUS)),'unrelated NUT authority changed')
 old=before(TRANSPORT).decode();new=reader(TRANSPORT).decode()
 require(procedure(old,'evaluate_b111_soil_n_transport')==procedure(new,'evaluate_b111_soil_n_transport'),'default transport procedure changed')
 branch='  case(6)\n    call regular_limit_coefficients(mto+rhbd*avs,hv,hv1,t,a1,a2,b1,b2,status)\n    return\n'
 require(procedure(new,'detcoef').replace(branch,'',1)==procedure(old,'detcoef'),'old coefficient branches changed')
 if changed is not None:
  for p in changed:
   if p not in delta:require(subprocess.run(['git','cat-file','-e',BASE+':'+p],cwd=ROOT,capture_output=True).returncode==0,'foreign regular limit caller '+p)
 return json.loads(reader('integration/audits/MC_SOL01_DYNAMIC_DECAY_STATUS.json'))['swp_water_successor']
def predecessor():
 ns=dict(__file__=str(ROOT/PARENT),__name__='immutable_saturated_flux_owner')
 exec(compile(before(PARENT),PARENT,'exec'),ns)
 original_validate=ns['validate']
 class HistoricalTransportPath:
  def read_bytes(self):return before(TRANSPORT)
 class HistoricalRoot:
  def __fspath__(self):return str(ROOT)
  def __truediv__(self,p):return HistoricalTransportPath()if p==TRANSPORT else ROOT/p
 def validate_historical(f):
  # The exact archived compiler sources remain historical. Only this one
  # provider differs; default/classes1..5 and current NUT are proved separately.
  actual=ns['ROOT'];ns['ROOT']=HistoricalRoot()
  try:return original_validate(f)
  finally:ns['ROOT']=actual
 ns['source']=source;ns['validate']=validate_historical
 return ns
def capsule():
 e=record()['admission_candidate']['evidence'];p=ROOT/e['index'];index=json.loads(p.read_text())
 require(sha(p.read_bytes())==e['index_sha256'],'regular limit index')
 raw=base64.b64decode(b''.join((p.parent/q).read_bytes()for q in index['parts']),validate=True)
 require(sha(raw)==index['decoded_sha256'],'regular limit capsule identity')
 with tarfile.open(fileobj=io.BytesIO(raw),mode='r:xz')as a:
  ms=a.getmembers();require(len(ms)==len({m.name for m in ms})and all(m.isfile()and not Path(m.name).is_absolute()and'..'not in Path(m.name).parts for m in ms),'unsafe regular limit members')
  f={m.name:a.extractfile(m).read()for m in ms}
 manifest=f.pop('MEMBERS.json');require(sha(manifest)==index['members_sha256'],'regular limit member manifest')
 require(json.loads(manifest)=={p:sha(b)for p,b in f.items()}and len(f)==index['members'],'regular limit member bytes')
 return f
def validate(f):
 def js(p):return json.loads(f[p])
 def inputs(r):
  for p,h in r['input_sha256'].items():require(sha((ROOT/p).read_bytes())==h,'executed current input '+p)
 def executions(prefix):
  es=js(prefix+'events.json');require(all(e['returncode']==0 for e in es),'failed regular limit execution '+prefix)
  for e in es:
   for stream in ['stdout','stderr']:require(prefix+e[stream]in f,'missing regular limit stream')
  return es
 d=js('direct/result.json');inputs(d)
 require(d['status']=='FINITE_DONOR_LIMITS_DIRECT_O0_O2_PASS'and d['cases']==516 and d['newly_accepted']==461 and d['corrected_accepted_limit_cases']==39,'direct numerical scope')
 checks=js('direct/checks.json');require(len(checks)==516,'missing numerical matrix')
 require(max(abs(c['residual'])for c in checks)<1e-12 and max(c['oracle_error']for c in checks)<2e-11,'independent ODE or mass failure')
 es=executions('direct/')
 for category in ['native','incumbent_current','incumbent_preimage','default_current','default_preimage','owner_native']:
  rows=[f['direct/'+e['stdout']]for e in es if e['category']==category]
  require(len(rows)==2 and rows[0]==rows[1],'direct optimization drift '+category)
 for opt in ['O0','O2']:
  def output(category):return next(f['direct/'+e['stdout']]for e in es if e['category']==category and ('/'+opt+'/'in e['command'][0]or '/'+opt+'-'in e['command'][0]))
  require(output('incumbent_current')==output('incumbent_preimage'),'original84 results drift')
  require(output('default_current')==output('default_preimage'),'default trajectory drift')
 cases=js('direct/input.json')['cases'];require(len(cases)==516,'direct input matrix missing')
 actual=next(f['direct/'+e['stdout']]for e in es if e['category']=='native').decode().splitlines()
 require(len(actual)==516,'direct actual output missing')
 for x,line in zip(cases,actual):
  status,kind,ce,ca,top,unmet,tau=map(float,line.split());require(status==0 and kind in [5,6],'direct case failed')
  dz,dt,wt,w0,qo,qb,qt,ql,k,prod,rho,K,cb,ct,cl,c0=x
  require(all(math.isfinite(v)for v in [ce,ca,top,unmet,tau])and min(ce,ca,unmet,tau)>=0 and tau<=dt,'invalid direct observation')
  res=dz*(w0+rho*K)*c0+(qb*cb+ql*cl+dz*prod)*dt+top*dt-(qo+k*.5*(wt+w0)*dz)*ca*dt-dz*(wt+rho*K)*ce
  require(abs(res)<1e-12 and abs(top*dt-qt*ct*dt-unmet)<1e-14,'actual direct mass/request balance')
 h=js('hist/result.json');inputs(h);es=executions('hist/');reuse=js('hist/REUSE.json')
 require(h['status']=='HIST_BOUNDED_PHYSICAL_PASS_NOT_FULL_MIGRATION'and h['results']==js('prior-hist-result.json')['results'],'current HIST endpoint drift')
 require(reuse['all_original_assertions_completed']and reuse['complete_incumbent_results_exact']and reuse['fresh_compile_events']==2 and reuse['reused_compile_events']==652 and reuse['fresh_native_events']==78,'current composition scope')
 require(sum(e['category']=='restart_native'for e in es)==56,'current HIST restart census')
 require(all(e.get('receipt_scope')=='FRESH_CURRENT_EXECUTION'for e in es if e['category']in ['native','restart_native','trace_native','link']),'inherited native process mislabelled fresh')
 for opt in ['O0','O2']:
  row=h['results'][opt];require(sha(f['hist/'+opt+'/default.endpoint'])==row['default_endpoint'],'default actual HIST bytes')
  for profile,digest in row['endpoint'].items():require(sha(f['hist/'+opt+'/'+profile+'.endpoint'])==digest,'actual HIST endpoint '+profile)
 n=js('coupled/result.json');inputs(n);es=executions('coupled/')
 require(n['status']=='FINITE_DONOR_PRODUCTION_LOCAL_PASS_NOT_ADMITTED'and n['joint']==js('prior-coupled-result.json')['joint'],'coupled incumbent drift')
 require(sum(e['category']=='joint_native'for e in es)==4 and sum(e['category']=='restart_native'for e in es)==8,'current negative coupled census')
 for opt in ['O0','O2']:
  for label in ['negative-low','negative-high']:
   prefix='coupled/joint-'+opt+'/'+label;row=n['joint'][opt+'/'+label]
   require(sha(f[prefix+'.endpoint'])==row['endpoint_sha256']and sha(f[prefix+'.endpoint.ledger'])==row['ledger_sha256'],'coupled actual endpoint/journal')
   for day in ['1','6']:require(f[prefix+'.endpoint']==f[prefix+'.fresh-'+day]and f[prefix+'.endpoint.ledger']==f[prefix+'.fresh-'+day+'.ledger'],'coupled process restart drift')
   for day in ['3','7']:require(f[prefix+'.restart.before-'+day]==f[prefix+'.restart.water-reject-'+day]==f[prefix+'.restart.chemical-reject-'+day],'rejected coupled trial leaked state')
 original=js('incumbent163.json')
 require(original['baseline']=='188f75ef04cd64a5a78ace0aa4b8977e7a130537'and original['owner']['qualified']and len(original['controls'])==163 and len(set(original['controls']))==163,'complete original163 assertion controls')
 require(original['scope']=='FROZEN_ORIGINAL_SOURCE_AND_ASSERTIONS_NOT_CURRENT_NATIVE','historical assertion scope mislabelled')
 return dict(qualified=True,status='FINITE_DONOR_REGULAR_LIMITS_CURRENT_HEADCALC_O0_O2_QUALIFIED',direct_cases_per_optimization=516,original_cases=84,hist_fresh_native_processes=78,hist_process_restarts=56,coupled_runs=4,coupled_fresh_restarts=8,predecessor163_scope='Re-executed on exact original188f source; current composition separately qualified',full_mc_nut01_closed=False)
def verify():
 source();old=predecessor()['verify']();current=validate(capsule())
 return {**old,**current,'qualification_scope':'BOUNDED_FINITE_DONOR_NUMERICAL_LIMITS_WITH_CURRENT_COMPOSITION_AND_FROZEN_PREDECESSOR_ASSERTIONS','canonically_admitted':False}
def nut_verify():return verify()
def fsi35_successors():return __import__('runpy').run_path(str(ROOT/'integration/performance/verify_saturated_flux_successor.py'))['fsi35_successors']()
def self_test():
 source();old=predecessor()['self_test']();require(len(old)==30,'incumbent30 seasonal assertion controls lost')
 passed=['predecessor:'+p for p in old];f=capsule();validate(f)
 def reject(label,fn):
  try:fn()
  except(AssertionError,KeyError,ValueError):passed.append(label);return
  raise AssertionError('accepted regular limit corruption '+label)
 for p in [TRANSPORT,SELF,PARENT,'integration/audits/run_nut_limits_composition.py','tests/nut-mineral/run_negative_limits.py']:
  reject('source '+p,lambda p=p:source(lambda q:(ROOT/q).read_bytes()+(b'!'if q==p else b'')))
 reject('foreign source',lambda:source(changed={'src/foreign_nut_limits.f90':'A'}))
 for p in ['direct/result.json','direct/checks.json','hist/REUSE.json','hist/result.json','coupled/result.json','incumbent163.json']:
  bad=dict(f);bad.pop(p);reject('missing '+p,lambda bad=bad:validate(bad))
 for p in ['hist/O0/default.endpoint','coupled/joint-O0/negative-low.endpoint','coupled/joint-O2/negative-high.fresh-6.ledger']:
  bad=dict(f);bad[p]+=b'!';reject('changed '+p,lambda bad=bad:validate(bad))
 return passed
if __name__=='__main__':
 import sys
 print(json.dumps(self_test()if'--self-test'in sys.argv else verify(),indent=2))
