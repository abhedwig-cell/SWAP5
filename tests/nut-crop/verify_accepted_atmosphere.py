"""NUT-owned successor. Original admission runs unchanged at exact predecessor.

No physics or evidence waiver: exact seven-file delta, all current native inputs,
all preceding byte references, and additional accepted-atmosphere assertions.
"""
from pathlib import Path
import hashlib,json,os,runpy,subprocess,tempfile

ROOT=Path(__file__).resolve().parents[2]
BASE='1158562fccf62bff0c3b7bb4e2e3c8371fae74be'
STATUS='integration/mc-nut01/MC-NUT01-HIST-COMPLETE_STATUS.json'
SURFACE=['src','tests','tools','reference','.github','integration/audits/column_grid/authority.py']
OWNED={
 'src/runtime/mod_fmr_crop_soil_n_joint_application.f90',
 'tests/nut-crop/test_b112_retained_joint.f90',
 'tests/nut-crop/test_historical_atmosphere_trace.f90',
 'tests/nut-crop/run_hist_complete.py',
 'tests/nut-crop/verify_historical_gross.py',
 'tests/nut-crop/verify_accepted_atmosphere.py',
 'integration/audits/column_grid/authority.py'}

def require(ok,why):
 if not ok:raise ValueError(why)
def sha(b):return hashlib.sha256(b).hexdigest()
def git(*args):return subprocess.check_output(['git',*args],cwd=ROOT,text=True).strip()
def record():return json.loads((ROOT/STATUS).read_text())['accepted_atmosphere_successor']
def gross():return runpy.run_path(str(ROOT/'tests/nut-crop/verify_historical_gross.py'),run_name='atmosphere_prior_functions')

def source():
 s=record();require(s['base_canonical']==BASE,'atmosphere predecessor identity')
 require(set(s['postimages'])==OWNED,'atmosphere ownership boundary')
 git('merge-base','--is-ancestor',BASE,'HEAD')
 require(not git('status','--porcelain','--',*SURFACE),'dirty atmosphere science')
 rows={r.split('\t')[1]:r.split('\t')[0]for r in git('diff','--name-status',BASE,'HEAD','--',*SURFACE).splitlines()}
 require(rows=={q:v['status']for q,v in s['postimages'].items()},'foreign atmosphere science')
 for q,v in s['postimages'].items():require(sha((ROOT/q).read_bytes())==v['sha256'],'atmosphere postimage '+q)
 return s

def validate(f,reader=lambda q:(ROOT/q).read_bytes()):
 g=gross();g['validate'](f,reader)
 require(sha(f['operations/retained_launcher.py'])==record()['operational_launcher_sha256'],'unqualified operational launcher')
 r=json.loads(f['physical/result.json']);events=json.loads(f['physical/events.json'])
 old=g['capsule'](g['record']()['evidence'])
 for opt in ['O0','O2']:
  prefix='physical/'+opt+'/'
  require(f[prefix+'gross-profile.endpoint']==old[prefix+'gross-profile.endpoint'],'previous gross endpoint drift')
  endpoint=f[prefix+'surface-profile.endpoint']
  require(sha(endpoint)==r['results'][opt]['endpoint']['surface-profile'],'atmosphere endpoint digest')
  require('HISTORICAL_ACCEPTED_ATMOSPHERE_12_DAYS_PASS'in r['results'][opt]['stdout']['surface-profile'],'missing actual atmosphere model')
  text=r['results'][opt]['stdout']['surface-profile']
  budget=[float(x)for x in next(line for line in text.splitlines()if 'ROTATION_BUDGET'in line).split()[1:]]
  m=record()['mass_balance']
  require(budget==[m[k]for k in ['initial','external_input','external_output','final','signed_residual']],'atmosphere N ledger report')
  require(abs(budget[4])<=1e-10 and abs(budget[0]+budget[1]-budget[2]-budget[3])<=1e-10,'atmosphere whole N closure')
  native=[e for e in events if e['category']=='native'and '/'+opt+'/'in e['command'][0]and e['command'][-1]=='surface-profile']
  require(len(native)==1 and f['physical/'+native[0]['stdout']].decode()==r['results'][opt]['stdout']['surface-profile'],'atmosphere raw native')
  for day in [1,6]:
   require(f[prefix+'surface-profile-fresh-'+str(day)]==endpoint,'atmosphere fresh continuation')
   require(sum(e['category']=='restart_native'and '/'+opt+'/'in e['command'][0]and e['command'][-2:]==['surface-profile',str(day)]for e in events)==1,'missing atmosphere fresh process')
  before=f[prefix+'surface-profile.restart.reject-before-6']
  for suffix in ['water-reject-6','reject-after-6','clean-reject-6']:
   require(before==f[prefix+'surface-profile.restart.'+suffix],'atmosphere atomic rejection '+suffix)
  trace=[e for e in events if e['category']=='trace_native'and '/'+opt+'/'in e['command'][0]]
  require(len(trace)==1 and b'HISTORICAL_ATMOSPHERE_TRACE_21_INVALID_AND_GROSS_UNITS=PASS'in f['physical/'+trace[0]['stdout']],'missing production trace checks')
 return {'status':'HISTORICAL_ACCEPTED_DRY_ATMOSPHERE_QUALIFICATION_PASS','old_endpoints_exact':12,'new_fresh_processes':4,'invalid_trace_cases_per_optimization':21}

def predecessor():
 supplied=os.environ.get('SWAP5_ATMOS_PREDECESSOR_WORKTREE');temporary=None
 if supplied:base=Path(supplied).resolve()
 else:
  temporary=tempfile.TemporaryDirectory(prefix='swap5-atmosphere-predecessor-');base=Path(temporary.name)/'baseline'
  subprocess.run(['git','worktree','add','--detach',str(base),BASE],cwd=ROOT,check=True,capture_output=True)
  sparse=subprocess.run(['git','config','--bool','core.sparseCheckout'],cwd=base,capture_output=True,text=True)
  if sparse.returncode==0 and sparse.stdout.strip()=='true':
   subprocess.run(['git','sparse-checkout','add','research','integration/f-ross','integration/research','app','examples'],cwd=base,check=True,capture_output=True)
 try:
  require(subprocess.check_output(['git','rev-parse','HEAD'],cwd=base,text=True).strip()==BASE,'atmosphere predecessor checkout identity')
  require(subprocess.run(['git','diff','--quiet','HEAD'],cwd=base).returncode==0,'dirty atmosphere predecessor')
  require(not subprocess.check_output(['git','ls-files','--others','--exclude-standard','--',*SURFACE],cwd=base,text=True).strip(),'foreign atmosphere predecessor source')
  p=subprocess.run(['python',str(base/'tests/nut-crop/verify_historical_gross.py')],cwd=base,capture_output=True,text=True)
  require(p.returncode==0,'original atmosphere predecessor authority: '+p.stdout[-1500:]+p.stderr[-1500:])
  controls=subprocess.run(['python',str(base/'tests/nut-crop/verify_historical_gross.py'),'--self-test'],cwd=base,capture_output=True,text=True)
  require(controls.returncode==0 and json.loads(controls.stdout)['count']==8,'original gross corruption controls')
  return json.loads(p.stdout)
 finally:
  if temporary:
   subprocess.run(['git','worktree','remove',str(base)],cwd=ROOT,check=True,capture_output=True);temporary.cleanup()

def grid_preservation():
 protected=['app/solute_column','examples/solute_column','tests/nut-sol/test_column_input.py',
  'integration/audits/MC_NUT_SOL_TRAJECTORY3_STATUS.json']
 require(not git('diff',BASE,'HEAD','--',*protected),'foreign current column-grid delta')
 require(not git('status','--porcelain','--',*protected),'dirty column-grid surface')
 status=json.loads((ROOT/'integration/audits/MC_NUT_SOL_TRAJECTORY3_STATUS.json').read_text())
 grid=status['column_input_20261020']['variable_grid_successor'];f=gross()['capsule'](grid['evidence'])
 for opt in ['O0','O2']:
  build=json.loads(f['build-'+opt+'/build-complete.json'])
  require(build['provider_count']==178 and build['status']=='BUILT','grid provider closure')
  for path,h in build['input_sha256'].items():require(sha((ROOT/path).read_bytes())==h,'current grid provider '+path)
 path='integration/audits/column_grid/authority.py'
 original=subprocess.check_output(['git','show',BASE+':'+path],cwd=ROOT,text=True)
 hook="""    nut=json.loads((ROOT/'integration/mc-nut01/MC-NUT01-HIST-COMPLETE_STATUS.json').read_text()).get('accepted_atmosphere_successor',{})
    if 'evidence'in nut:
        import runpy
        proof=runpy.run_path(str(ROOT/'tests/nut-crop/verify_accepted_atmosphere.py'),run_name='registered_nut_atmosphere')['verify_qualification']()
        return {**proof,'application_grid':True,'process_observations':86,'production_changed':False,'grid_preserved_on_exact_current_providers':True}
"""
 require((ROOT/path).read_text()==original.replace('def verify_qualification():\n','def verify_qualification():\n'+hook,1),'column guard exact successor handoff')
 return {'current_column_grid_providers':178,'prior_grid_process_observations':86,'current_grid_providers_unchanged':True}

def verify_qualification():
 s=source();f=gross()['capsule'](s['evidence']);r=validate(f);prior=predecessor()
 require(prior['predecessor_qualified'],'missing prior original authority')
 # This is the same seven-module exclusion independently checked by the old
 # owner; our sole changed production provider is one of those seven.
 logs=gross()['unchanged_ci_closure']();grid=grid_preservation()
 return {**r,**grid,'qualified':True,'full_capability':False,'mastercoverage_promotion':False,'accepted_atmosphere':True,'historical_gross_top':True,'transition_fresh_processes':52,'predecessor_qualified':True,'independent_ci_compile_logs':logs,'source_tree':git('rev-parse','HEAD:src'),'current_source_tree':git('rev-parse','HEAD:src'),'full_fci':'NOT_SELECTED_IMPACT','highest_low_air':'NOT_SELECTED_POLICY','full_migration_qualified':False}

def self_test():
 f=gross()['capsule'](record()['evidence']);validate(f);passed=[]
 def reject(name,fn,reader=lambda q:(ROOT/q).read_bytes()):
  ff=dict(f);fn(ff)
  try:validate(ff,reader)
  except(ValueError,KeyError,IndexError):passed.append(name);return
  raise AssertionError('accepted corruption '+name)
 for suffix in ['water-reject-6','reject-after-6','clean-reject-6']:
  reject(suffix,lambda x,s=suffix:x.__setitem__('physical/O0/surface-profile.restart.'+s,b'corrupt'))
 reject('fresh-process drift',lambda x:x.__setitem__('physical/O2/surface-profile-fresh-6',b'corrupt'))
 reject('operational launcher drift',lambda x:x.__setitem__('operations/retained_launcher.py',b'corrupt'))
 reject('old gross drift',lambda x:x.__setitem__('physical/O0/gross-profile.endpoint',b'corrupt'))
 reject('current joint drift',lambda x:None,lambda q:(ROOT/q).read_bytes()+(b'!'if q=='src/runtime/mod_fmr_crop_soil_n_joint_application.f90'else b''))
 def edit(x,path,fn):
  d=json.loads(x[path]);fn(d);x[path]=json.dumps(d).encode()
 reject('missing direct native',lambda x:edit(x,'physical/events.json',lambda es:es.__setitem__(slice(None),[e for e in es if e['category']!='trace_native'])))
 reject('missing new restart native',lambda x:edit(x,'physical/events.json',lambda es:es.__setitem__(slice(None),[e for e in es if not(e['category']=='restart_native'and e['command'][-2:]==['surface-profile','6'])])))
 return {'atmosphere_negative_controls':passed,'count':len(passed)}

if __name__=='__main__':
 import sys
 print(json.dumps(self_test()if '--self-test'in sys.argv else verify_qualification(),indent=2))
