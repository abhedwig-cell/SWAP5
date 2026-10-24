"""Current proportional N partition proof, with explicit historical preservation."""
from pathlib import Path
import base64,hashlib,io,json,re,runpy,struct,subprocess,tarfile
import numpy as np
from scipy.integrate import solve_ivp
ROOT=Path(__file__).resolve().parents[2]
BASE='5ff1486125ec7f5e3433963f49d733f1045e5eac'
UNIT='integration/mc-nut01/competing_sinks/'
SELF='integration/audits/verify_nut_partition.py'
PARENT='integration/audits/verify_saturated_picard_current.py'
STATUS=UNIT+'QUALIFIED_INPUTS.json'
SCIENCE=['src','app','tools','tests','examples','reference','.github','integration/audits','integration/performance','integration/diagnostics']
CHANGED=['src/process/mod_n_constant_sink_partition.f90','src/process/mod_b111_soil_n_daily_exchange.f90','src/process/mod_b111_soil_n_reactive_owner.f90','src/crop/mod_crop_soil_n_day.f90','src/runtime/mod_fmr_crop_soil_n_joint_application.f90']
sha=lambda b:hashlib.sha256(b).hexdigest()
def git(*a):return subprocess.check_output(['git',*a],cwd=ROOT,text=True).strip()
def before(p):return subprocess.check_output(['git','show',BASE+':'+p],cwd=ROOT)
def record():return json.loads((ROOT/STATUS).read_bytes())
def projection():
 s=before(PARENT).decode()
 for name,args in [('source','reader,changed'),('verify',''),('self_test',''),('fsi35_successors','')]:
  s=re.sub(r'^def '+name+r'\(\):(?=\S)','def '+name+'():\n ',s,flags=re.M)
  at=s.index('\n',re.search(r'^def '+name+r'\(',s,re.M).start())+1
  s=s[:at]+" if (ROOT/'"+STATUS+"').is_file():return __import__('runpy').run_path(str(ROOT/'"+SELF+"'))['"+name+"']("+args+")\n"+s[at:]
 return s.encode()
def source(reader=lambda p:(ROOT/p).read_bytes(),changed=None):
 if (ROOT/'integration/mc-nut01/competing_sinks/NONJUVENILE_INPUTS.json').is_file():return __import__('runpy').run_path(str(ROOT/'integration/audits/verify_nut_nonjuvenile.py'))['source'](reader,changed)
 r=record();assert r['base']==BASE;git('merge-base','--is-ancestor',BASE,'HEAD')
 delta={l.split('\t')[1]:l.split('\t')[0]for l in git('diff','--name-status',BASE,'HEAD','--',*SCIENCE).splitlines()}
 assert delta==r['scientific_delta']and not git('status','--porcelain','--',*SCIENCE)
 assert {p for p in delta if p.startswith('src/')}==set(CHANGED)
 assert reader(PARENT)==projection(),'historical assertion body changed'
 for p,h in r['postimages'].items():assert sha(reader(p))==h,('partition postimage',p)
 if changed is not None:
  for p in changed:assert p in delta or subprocess.run(['git','cat-file','-e',BASE+':'+p],cwd=ROOT,capture_output=True).returncode==0,'foreign caller'
 return json.loads(reader('integration/audits/MC_SOL01_DYNAMIC_DECAY_STATUS.json'))['swp_water_successor']
def unpack(e):
 raw=base64.b64decode((ROOT/e['path']).read_bytes(),validate=True);assert sha(raw)==e['sha256']and len(raw)==e['bytes']
 with tarfile.open(fileobj=io.BytesIO(raw),mode='r:xz')as t:
  ms=t.getmembers();assert len(ms)==e['members']==len({m.name for m in ms})and all(m.isfile()and not Path(m.name).is_absolute()and'..'not in Path(m.name).parts for m in ms)
  f={m.name:t.extractfile(m).read()for m in ms}
 assert json.loads(f.pop('MANIFEST.json'))=={p:sha(b)for p,b in f.items()};return f
def files():return {k:unpack(e)for k,e in record()['evidence'].items()}
def prior_namespace():
 n=dict(__file__=str(ROOT/PARENT),__name__='exact_historical_partition_predecessor');exec(compile(before(PARENT),PARENT,'exec'),n)
 class Archived:
  def __init__(self,p):self.p=p
  def read_bytes(self):return before(self.p)
 class HistoricalRoot:
  def __str__(self):return str(ROOT)
  def __fspath__(self):return str(ROOT)
  def __truediv__(self,p):return Archived(p)if p in CHANGED[1:] else ROOT/p
 n['ROOT']=HistoricalRoot()
 def projected(reader=None,changed=None):
  if reader is None:return source(changed=changed)
  def mapped(p):
   b=reader(p)
   if p in CHANGED[1:]:
    old=before(p)
    if b in [old,old+b'!']:return (ROOT/p).read_bytes()+b[len(old):]
   return b
  return source(mapped,changed)
 projected(lambda p:(n['ROOT']/p).read_bytes())
 n['source']=projected;return n
def validate(allfiles):
 def js(f,p):return json.loads(f[p])
 def inputs(r):
  for p,h in r['input_sha256'].items():assert sha((ROOT/p).read_bytes())==h,('current executed input',p)
 f=allfiles['component'];es=js(f,'events.json');assert all(e['returncode']==0 for e in es)
 for e in es:
  if e['kind']=='contract_native':assert f[e['stdout']].split()==[b'PARTITION_CONTRACT_PASS',b'56',b'9']
 component=json.loads((ROOT/(UNIT+'CANDIDATE_STATUS.json')).read_bytes())
 for p,h in component['source_sha256'].items():assert sha((ROOT/p).read_bytes())==h,('unchanged component input',p)
 f=allfiles['daily'];r=js(f,'current/result.json');inputs(r);assert r['cases_per_optimization']==1152 and r['incumbent_byte_exact']==1344
 es=js(f,'current/events.json');assert all(e['returncode']==0 for e in es)
 outputs=dict(zip(['O0','O2'],[np.array([list(map(float,l.split()))for l in f['current/'+e['stdout']].splitlines()])for e in es if e['category']=='opt_in']))
 # Execute the original independent event/individual-receipt assertion body.
 script=(ROOT/(UNIT+'run_daily.py')).read_text();body=script[script.index("assert np.max(abs(outputs['O0']"):script.index('\nr=dict(status=')]
 ns=dict(np=np,solve_ivp=solve_ivp,outputs=outputs,cases=js(f,'current/input.json'));exec(compile(body,'current_daily_oracle','exec'),ns)
 for cat in ['incumbent_current','incumbent_baseline']:
  streams=[f['current/'+e['stdout']]for e in es if e['category']==cat]
  if cat=='incumbent_current':old=streams
  else:assert streams==old and len(streams)==2
 for e in es:
  if e['category']=='invalid_opt_in':assert len(f['current/'+e['stdout']].splitlines())==5 and all(int(l.split()[0])!=0 for l in f['current/'+e['stdout']].splitlines())
 for label,prefix,count in [('runtime','current/',4),('default','',30)]:
  f=allfiles[label];r=js(f,prefix+'result.json');inputs(r if label=='runtime'else {'input_sha256':r['provider_source_sha256']});assert len(r['results'])==count
  for key,row in r['results'].items():
   stem=prefix+key;assert sha(f[stem+'.endpoint'])==row['endpoint_sha256']
   ledger=struct.unpack('14d',f[stem+'.endpoint.ledger']);assert abs(ledger[0]+ledger[1]-ledger[2]-ledger[13])<1e-12
   if label=='runtime':assert ledger[3]>0 and sum(ledger[7:9])<0 and sum(ledger[9:11])>0 and list(ledger)==row['ledger']
   else:assert sha(f[stem+'.endpoint.ledger'])==row['ledger_sha256']
   for day in [1,4]:
    for suffix in ['', '.ledger']:assert f[stem+'.endpoint'+suffix]==f[stem+'.fresh-'+str(day)+suffix]
   for day in [2,5]:
    for kind in ['exhaust','stale','water']:assert f[stem+'.restart.before-'+str(day)]==f[stem+'.restart.'+kind+'-reject-'+str(day)]
 f=allfiles['hist'];h=js(f,'result.json');inputs(h);assert h['status']=='HIST_BOUNDED_PHYSICAL_PASS_NOT_FULL_MIGRATION'
 old=js(prior_namespace()['capsule'](),'hist/result.json')['results']
 for opt in ['O0','O2']:
  assert h['results'][opt]['providers']==old[opt]['providers']+1
  assert {k:v for k,v in h['results'][opt].items()if k!='providers'}=={k:v for k,v in old[opt].items()if k!='providers'}
  assert sha(f[opt+'/default.endpoint'])==h['results'][opt]['default_endpoint']
  for case,digest in h['results'][opt]['endpoint'].items():assert sha(f[opt+'/'+case+'.endpoint'])==digest
 es=js(f,'events.json');assert all(e['returncode']==0 for e in es)
 assert sum(e['category']=='compile'for e in es)==656 and sum(e['category']in ['native','trace_native','restart_native']for e in es)==78
 prior=prior_namespace();p=prior['validate'](prior['capsule']());assert p['qualified']
 return dict(qualified=True,status='PARTITION_CURRENT_DAILY_HIST_RUNTIME_DEFAULT_QUALIFIED',daily_cases=1152,incumbent_byte_exact=1344,HIST_processes=78,coupled_runs=4,coupled_restarts=8,default_coupled_runs=30,default_coupled_restarts=60,historical_predecessor_assertions='Original bodies with four explicitly archived NUT sources; separate fresh current HIST/runtime/default proof',canonically_admitted=False,full_mc_nut01_closed=False)
def verify():
 if (ROOT/'integration/mc-nut01/competing_sinks/NONJUVENILE_INPUTS.json').is_file():return __import__('runpy').run_path(str(ROOT/'integration/audits/verify_nut_nonjuvenile.py'))['verify']()
 source();return validate(files())
def self_test():
 if (ROOT/'integration/mc-nut01/competing_sinks/NONJUVENILE_INPUTS.json').is_file():return __import__('runpy').run_path(str(ROOT/'integration/audits/verify_nut_nonjuvenile.py'))['self_test']()
 source();f=files();validate(f);passed=['predecessor-preserved:'+p for p in prior_namespace()['self_test']()]
 def reject(label,fn):
  try:fn()
  except(AssertionError,KeyError,ValueError,TypeError):passed.append(label);return
  raise AssertionError('accepted partition corruption '+label)
 for p in record()['postimages']:reject('source '+p,lambda p=p:source(lambda q:(ROOT/q).read_bytes()+(b'!'if q==p else b'')))
 reject('foreign caller',lambda:source(changed={'src/foreign_partition.f90':'A'}))
 for label,p in [('daily','current/input.json'),('runtime','current/O0/crop_both.endpoint'),('runtime','current/O2/crop_nh4.fresh-4.ledger'),('default','O0/empty_both.endpoint'),('hist','result.json'),('hist','O0/default.endpoint'),('component','003.stdout')]:
  bad={k:dict(v)for k,v in f.items()};bad[label][p]+=b'!';reject('raw '+label+'/'+p,lambda bad=bad:validate(bad))
 return passed
def fsi35_successors():
 if (ROOT/'integration/mc-nut01/competing_sinks/NONJUVENILE_INPUTS.json').is_file():return __import__('runpy').run_path(str(ROOT/'integration/audits/verify_nut_nonjuvenile.py'))['fsi35_successors']()
 source();return prior_namespace()['fsi35_successors']()
if __name__=='__main__':
 import sys
 print(json.dumps(self_test()if'--self-test'in sys.argv else verify(),indent=2))
