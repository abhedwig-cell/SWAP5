"""Bounded opt-in application successor; all shared providers stay immutable."""
import csv,hashlib,io,json,runpy,subprocess,tarfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
BASE='9d86cdf8f'
STATUS='benchmarks/performance/PERF01_NATIVE_PROPOSAL_20261023_STATUS.json'
PARENT='integration/audits/verify_nut_regular_limits.py'
SEASONAL_PARENT='integration/audits/verify_native_seasonal_bottom.py'
SAT_PARENT='integration/performance/verify_saturated_flux_successor.py'
SELF='integration/performance/verify_native_proposal_successor.py'
APP='app/solute_project/main.f90';FRONT='tools/solute/run_project.py'
SCIENCE=['src','app','tools','tests','examples','reference','.github','integration/audits','integration/performance','integration/diagnostics']
sha=lambda b:hashlib.sha256(b).hexdigest()
def require(ok,why):
 if not ok:raise AssertionError(why)
def git(*args):return subprocess.check_output(['git',*args],cwd=ROOT,text=True).strip()
def before(p):return subprocess.check_output(['git','show',BASE+':'+p],cwd=ROOT)
def record(reader=lambda p:(ROOT/p).read_bytes()):return json.loads(reader(STATUS))
def projection():
 s=before(PARENT).decode()
 for name,args in [('source','reader,changed'),('verify',''),('self_test','')]:
  offset=s.index('\n',s.index('def '+name+'('))+1
  hook=" if (ROOT/'"+STATUS+"').is_file() and 'source_admission' in json.loads((ROOT/'"+STATUS+"').read_text()):return __import__('runpy').run_path(str(ROOT/'"+SELF+"'))['"+name+"']("+args+")\n"
  s=s[:offset]+hook+s[offset:]
 return s.encode()
def source(reader=lambda p:(ROOT/p).read_bytes(),changed=None):
 r=record(reader)['source_admission'];git('merge-base','--is-ancestor',BASE,'HEAD')
 delta={line.split('\t')[1]:line.split('\t')[0]for line in git('diff','--name-status',BASE,'HEAD','--',*SCIENCE).splitlines()}
 require(delta=={APP:'M',FRONT:'M',PARENT:'M',SELF:'A'},'foreign native proposal scientific delta')
 require(not git('status','--porcelain','--',*SCIENCE),'dirty native proposal science')
 require(git('rev-parse','HEAD:src')==git('rev-parse',BASE+':src'),'shared production provider changed')
 require(reader(PARENT)==projection(),'predecessor assertion body changed')
 for p,h in r['postimages'].items():require(sha(reader(p))==h,'native proposal postimage '+p)
 if changed is not None:
  for p in changed:
   if p not in delta:require(subprocess.run(['git','cat-file','-e',BASE+':'+p],cwd=ROOT,capture_output=True).returncode==0,'foreign native proposal caller '+p)
 return json.loads(reader('integration/audits/MC_SOL01_DYNAMIC_DECAY_STATUS.json'))['swp_water_successor']
def capsule():
 e=record()['evidence'];raw=(ROOT/e['path']).read_bytes();require(sha(raw)==e['sha256']and len(raw)==e['bytes'],'native proposal capsule identity')
 with tarfile.open(fileobj=io.BytesIO(raw),mode='r:xz')as tf:
  ms=tf.getmembers();require(len(ms)==e['members']==len({m.name for m in ms}),'native proposal archive census')
  require(all(m.isfile()and not Path(m.name).is_absolute()and'..'not in Path(m.name).parts for m in ms),'unsafe native proposal archive')
  f={m.name:tf.extractfile(m).read()for m in ms}
 require(json.loads(f['MANIFEST.json'])=={p:sha(b)for p,b in f.items()if p!='MANIFEST.json'},'native proposal manifest')
 return f
def validate(f,reader=lambda p:(ROOT/p).read_bytes()):
 def js(p):return json.loads(f[p])
 def rows(p):return list(csv.DictReader(io.StringIO(f[p].decode())))
 q=js('qualified/RESULT.json');require(q['status']=='NATIVE_PROPOSAL_O0_O2_DEFAULT_RESTART_FALLBACK_AND_NEGATIVES_PASS','native proposal execution incomplete')
 require(len(q['events'])==50 and sum(e['returncode']!=0 for e in q['events'])==6,'native proposal event census')
 for p,h in q['inputs'].items():require(sha(reader(p))==h,'native proposal executed source '+p)
 for opt,b in q['builds'].items():
  for p,h in b['input_sha256'].items():require(sha(reader(p))==h,'native proposal provider '+p)
 old=runpy.run_path(str(ROOT/SAT_PARENT));oldfiles=old['capsule']()
 # Keep the original assertions and historical identities, with explicit
 # unchanged-default inheritance for the two changed application files.
 old['validate'](oldfiles,lambda p:subprocess.check_output(['git','show','21871ca2b:'+p],cwd=ROOT)if p in [APP,FRONT,'tools/solute/build_project.py','app/solute_crop/read_swp_project.f90']else reader(p))
 seasonal=runpy.run_path(str(ROOT/SEASONAL_PARENT));prior_seasonal=seasonal['capsule']();current_seasonal=dict(prior_seasonal)
 nut=runpy.run_path(str(ROOT/PARENT));nut_result=nut['validate'](nut['capsule']())
 for opt in ['O0','O2']:
  required=[f'build-{opt}/column/build-complete.json',f'{opt}/result.json']
  required += [f'{opt}/{i:03}.{stream}'for i in range(11)for stream in ['stdout','stderr']]
  required += [f'{opt}/{case}/{generation}/{name}'for case in ['default','seasonal','cross_year']for generation in ['full','split','resumed']for name in ['budget.csv','state.csv','endpoint.csv','restart.bin','input.nml','input.swp','manifest.json','stdout','stderr']]
  require(all('seasonal-current/'+p in f for p in required),'fresh seasonal execution member absent')
 for path,raw in f.items():
  if path.startswith('seasonal-current/'):
   current_seasonal[path[len('seasonal-current/'):]]=raw
 seasonal_result=seasonal['validate'](current_seasonal)
 for opt in ['O0','O2']:
  for case in ['default','seasonal','cross_year']:
   for name in ['budget.csv','state.csv','endpoint.csv','restart.bin']:
    path=f'{opt}/{case}/full/{name}';require(current_seasonal[path]==prior_seasonal[path],'seasonal predecessor physical bytes changed '+path)
 require(js('predecessor/owner.json')['qualified']and len(js('predecessor/controls.json'))==45,'exact predecessor owner/controls')
 require(js('supplement/RESULT.json')['status']=='FAILED_FALLBACK_ATOMIC_AND_CHEMICAL_REJECTION_PROPAGATES','failed fallback qualification absent')
 require(js('supplement/RESULT.json')['production_application_sha256']==sha(reader(APP)),'failed fallback executed application source')
 for opt in ['O0','O2']:
  require(f[f'supplement/{opt}/before-1.bin']==f[f'supplement/{opt}/after-1.bin']==f[f'supplement/{opt}/diagnostic-rejected.bin'],'failed fallback leaked committed generation')
  stream=f[f'supplement/{opt}/stdout'];require(stream.count(b'SWAP5_PROJECT_STEP_PROPOSAL_FALLBACK')==1 and b'joint interval rejected'in stream,'failed fallback did not propagate')
 require(b'joint status/water/chemical:            3           0           2'in f['supplement/chemical/stdout'],'chemical rejection did not propagate')
 require(b'native proposal numerical combination not qualified'in f['supplement/seasonal/stdout'],'seasonal proposal silently activated')
 for opt in ['O0','O2']:
  for rain in [1,4]:
   prefix=f'qualified/{opt}-{rain}x-';on=prefix+'on-0/';off=prefix+'off-0/'
   data=rows(on+'budget.csv');reference=rows(off+'budget.csv');require(len(data)==len(reference)==97,'native proposal days')
   original_lines=oldfiles[f'raw/perf01-native-fixed-study/{rain}x-0-legacy/result_output.csv'].decode().splitlines()
   original=list(csv.DictReader(line for line in original_lines if not line.startswith('*')))[1:]
   require(len(original)==97,'original forcing census')
   independent=10*max(abs(float(s['water_end_cm'])-float(s['water_start_cm'])-float(r['RAIN'])+float(s['runoff_cm'])+float(s['soil_evaporation_cm'])+float(s['pond_evaporation_cm'])+float(s['actual_transpiration_cm'])-float(r['BOT']))for r,s in zip(original,data))
   require(independent<1e-9,'independent original-forcing gross water')
   for r in data:
    require(abs(float(r['water_residual_cm']))<1e-10,'native proposal hard water')
    require(abs(float(r['water_end_cm'])-float(r['water_start_cm'])-float(r['water_in_cm'])+float(r['water_out_cm']))<1e-10,'native proposal gross water')
    require(float(r['solute_start_mg_cm2'])==float(r['solute_end_mg_cm2'])==0,'native proposal positive tracer')
   # Default-OFF remains byte-exact to the original admitted O2 native run.
   incumbent=f'raw/perf01-native-fixed-study/{rain}x-0-current/'
   for name in ['budget.csv','state.csv','endpoint.csv','restart.bin']:
    require(f[off+name]==oldfiles[incumbent+name],'native proposal default changed '+name)
    for rep in range(3 if opt=='O2'else 1):require(f[prefix+'on-'+str(rep)+'/'+name]==f[on+name],'native proposal nondeterminism '+name)
    require(f[prefix+'rollback/'+name]==f[on+name],'rollback instrumentation changed physics '+name)
   for name in ['state.csv','endpoint.csv','restart.bin']:require(f[prefix+'resume/'+name]==f[on+name],'native proposal fresh restart '+name)
   require(rows(prefix+'resume/budget.csv')==data[48:],'native proposal restart daily rows')
   require(10*max(abs(float(r['runoff_cm'])-float(s['runoff_cm']))for r,s in zip(reference,data))<.01,'native proposal daily runoff')
   require(10*abs(sum(float(s['runoff_cm'])-float(r['runoff_cm'])for r,s in zip(reference,data)))<.01,'native proposal seasonal runoff')
   require(10*max(abs(float(r['water_end_cm'])-float(s['water_end_cm']))for r,s in zip(reference,data))<.01,'native proposal storage')
   for r,s in zip(reference,data):
    require(10*abs(float(r['actual_transpiration_cm'])-float(s['actual_transpiration_cm']))<1e-8,'native proposal uptake')
    require(10*abs(float(r['soil_evaporation_cm'])+float(r['pond_evaporation_cm'])-float(s['soil_evaporation_cm'])-float(s['pond_evaporation_cm']))<1e-8,'native proposal total evaporation')
   # Actual proposal failures, exact complete pre/post committed generations.
   days=[83]if rain==1 else[7,74,92]
   for day in days:require(f[prefix+f'rollback/before-{day}.bin']==f[prefix+f'rollback/after-{day}.bin'],'native proposal failure leaked state')
   stream=f[f'qualified/{opt}-{rain}x-on-0.stdout'].decode()
   found=[int(line.split()[1])for line in stream.splitlines()if'SWAP5_PROJECT_STEP_PROPOSAL_FALLBACK'in line]
   require(found==days,'missing real proposal fallback')
   for label in ['positive-tracer','picard','implicit-transport']:
    require(b'native proposal'in f[f'qualified/{opt}-reject-{label}.stdout'],'native proposal unsupported accepted')
 for rain in [1,4]:
  for name in ['budget.csv','state.csv','endpoint.csv','restart.bin']:require(f[f'qualified/O0-{rain}x-on-0/{name}']==f[f'qualified/O2-{rain}x-on-0/{name}'],'proposal optimization drift')
  for rep in range(3):
   for arm in ['off','on']:
    for name in ['budget.csv','state.csv','endpoint.csv','restart.bin']:
     require(f[f'qualified/frontend-{rain}x-{arm}-{rep}/{name}']==f[f'qualified/O2-{rain}x-{arm}-0/{name}'],'native frontend changed physics')
 return dict({**json.loads(prior_seasonal['predecessor/owner.json']),**seasonal_result,**nut_result},qualified=True,status='NATIVE_ZERO_TRACER_PROPOSAL_AND_ATOMIC_DAY_FALLBACK_PASS',default_enabled=False,
  qualification_scope='COMPOSED_NATIVE_PROPOSAL_ZERO_TRACER_AND_DEFAULT_SEASONAL_481_DAY',
  full_mc_sol01_closed=False,full_mc_nut01_closed=False,current_source_tree=git('rev-parse','HEAD:src'),
  predecessor_scope='Original saturated-flux proof retained under unchanged-default inheritance, not a fresh full NUT run',
  proposal_scope='Constructed native97day simple crop/ETref zero tracer1x/4x, optional only',
  native_application_processes=40,actual_failed_water_rollbacks=8,negative_native_controls=6,
  canonically_admitted=False,measured={k:v for k,v in q['cases'].items()if k.startswith('O2')})
def verify():source();return validate(capsule())
def self_test():
 source();f=capsule();validate(f);passed=[]
 def reject(label,fn):
  try:fn()
  except(AssertionError,KeyError,ValueError):passed.append(label);return
  raise AssertionError('accepted native proposal corruption '+label)
 for p in record()['source_admission']['postimages']:
  reject('source '+p,lambda p=p:source(lambda q:(ROOT/q).read_bytes()+(b'!'if p==q else b'')))
 reject('foreign scientific caller',lambda:source(changed={'src/foreign_proposal.f90':'A'}))
 for p in ['qualified/RESULT.json','predecessor/owner.json','predecessor/controls.json','qualified/O2-4x-on-0/budget.csv','qualified/O0-1x-rollback/after-83.bin','qualified/O2-4x-resume/restart.bin','qualified/O2-reject-positive-tracer.stdout','supplement/RESULT.json','supplement/chemical/stdout','supplement/seasonal/stdout','seasonal-current/O2/cross_year/full/budget.csv']:
  bad=dict(f);bad.pop(p);reject('missing '+p,lambda bad=bad:validate(bad))
 for p in ['qualified/O2-4x-rollback/after-7.bin','qualified/O2-1x-off-0/state.csv','qualified/frontend-4x-on-2/restart.bin','supplement/O2/diagnostic-rejected.bin']:
  bad=dict(f);bad[p]+=b'!';reject('changed '+p,lambda bad=bad:validate(bad))
 return passed
if __name__=='__main__':
 import sys
 print(json.dumps(self_test()if'--self-test'in sys.argv else verify(),indent=2))
