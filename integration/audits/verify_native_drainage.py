"""Bounded original-DRA native composition; explicit current/frozen identities."""
import base64,csv,hashlib,io,json,re,runpy,subprocess,tarfile
from functools import lru_cache
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
BASE='57e1b3f2635559df0db0350a96f0e06b2e3b9cc7'
STATUS='integration/mc-sol01/drainage/STATUS.json'
SELF='integration/audits/verify_native_drainage.py'
PARENT='integration/audits/verify_nut_zero_pools.py'
SCIENCE=['src','app','tools','tests','examples','reference','.github','integration/audits','integration/performance','integration/diagnostics']
sha=lambda b:hashlib.sha256(b).hexdigest()
def git(*a):return subprocess.check_output(['git',*a],cwd=ROOT,text=True).strip()
def before(p):return subprocess.check_output(['git','show',BASE+':'+p],cwd=ROOT)
def record(reader=lambda p:(ROOT/p).read_bytes()):return json.loads(reader(STATUS))
def projection():
 s=before(PARENT).decode()
 for name,args in [('source','reader,changed'),('verify',''),('self_test','')]:
  at=s.index('\n',re.search(r'^def '+name+r'\(',s,re.M).start())+1
  s=s[:at]+" if (ROOT/'"+STATUS+"').is_file():return __import__('runpy').run_path(str(ROOT/'"+SELF+"'))['"+name+"']("+args+")\n"+s[at:]
 return s.encode()
def source(reader=lambda p:(ROOT/p).read_bytes(),changed=None):
 r=record(reader);assert r['baseline']==BASE
 git('merge-base','--is-ancestor',BASE,'HEAD')
 delta={s.split('\t')[1]:s.split('\t')[0]for s in git('diff','--name-status',BASE,'HEAD','--',*SCIENCE).splitlines()}
 assert delta==r['scientific_delta'],'foreign drainage scientific delta'
 assert not git('status','--porcelain','--',*SCIENCE),'dirty drainage science'
 assert reader(PARENT)==projection(),'predecessor assertion body changed'
 for p,h in r['postimages'].items():assert sha(reader(p))==h,('drainage source',p)
 if changed is not None:
  for p in changed:assert p in delta or subprocess.run(['git','cat-file','-e',BASE+':'+p],cwd=ROOT,capture_output=True).returncode==0,'foreign drainage caller'
 return json.loads(reader('integration/audits/MC_SOL01_DYNAMIC_DECAY_STATUS.json'))['swp_water_successor']
def capsule():
 e=record()['evidence'];raw=base64.b64decode((ROOT/e['path']).read_bytes(),validate=True);assert sha(raw)==e['sha256']
 with tarfile.open(fileobj=io.BytesIO(raw),mode='r:xz')as t:
  ms=t.getmembers();assert len(ms)==len({m.name for m in ms})and all(m.isfile()and not Path(m.name).is_absolute()and'..'not in Path(m.name).parts for m in ms)
  f={m.name:t.extractfile(m).read()for m in ms}
 inventory=json.loads(f.pop('MANIFEST.json'));assert inventory=={p:sha(b)for p,b in f.items()};return f
@lru_cache(None)
def frozen():
 ns=dict(__file__=str(ROOT/PARENT),__name__='frozen_demand_assertions');exec(compile(before(PARENT),PARENT,'exec'),ns)
 historical={'app/solute_crop/read_swp_project.f90','app/solute_project/main.f90','tools/solute/run_project.py','src/runtime/mod_fmr_serialized_reference_backend.f90'}
 class ArchivedPath:
  def __init__(self,p):self.p=p
  def read_bytes(self):return before(self.p)
 class HistoricalRoot:
  def __str__(self):return str(ROOT)
  def __fspath__(self):return str(ROOT)
  def __truediv__(self,p):return ArchivedPath(p)if p in historical else ROOT/p
 # Preserve every original physical assertion. Only the four changed caller /
 # runtime identities are explicitly historical here; current executions below
 # prove the affected physical composition, NUT and consumed research carriers.
 ns['ROOT']=HistoricalRoot();ns['source']=source
 return ns['verify']()
def validate(f):
 js=lambda p:json.loads(f[p])
 def rows(p):return [{k:float(v)for k,v in x.items()}for x in csv.DictReader(io.StringIO(f[p].decode()))]
 assert f['predecessor/source.py']==before(PARENT)
 assert js('predecessor/owner.json')['qualified']and len(js('predecessor/controls.json'))==75
 assert frozen()['qualified']
 for opt in ['O0','O2']:
  p='native-'+opt+'/';r=js(p+'result.json');assert r['status']=='NATIVE_DRAMET3_DIVDRA_RESTART_PASS'and r['days']==469 and r['restart_exact']
  assert r['original_drainage_sha256']=='4c23dec437ee72338db01b04d82829d57b2cf994f9395bba1691aebaa32cface'
  assert[r['events'][i]['returncode']for i in range(4)]==[0,0,0,1]
  for name in ['state.csv','endpoint.csv','restart.bin']:assert f[p+'full/'+name]==f[p+'resumed/'+name]
  data=rows(p+'full/budget.csv');assert len(data)==469 and rows(p+'resumed/budget.csv')==data[365:]
  for d in data:
   assert abs(d['water_residual_cm'])<1e-10 and abs(d['solute_residual_mg_cm2'])<1e-10 and d['drainage_cm']>=0
   assert abs(d['water_end_cm']-d['water_start_cm']-d['rain_supplied_cm']+d['runoff_cm']+d['soil_evaporation_cm']+d['pond_evaporation_cm']+d['actual_transpiration_cm']-d['bottom_up_cm']+d['drainage_cm'])<1e-10
  assert abs(sum(d['drainage_cm']for d in data)-27.903797127580066)<1e-12
  for d in rows(p+'full/state.csv'):assert min(d[k]for k in ['theta','concentration_mg_cm3','dissolved_mg_cm2','sorbed_mg_cm2'])>=0
  meta=js('build-'+opt+'/column/build-complete.json')
  for path,h in meta['input_sha256'].items():assert sha((ROOT/path).read_bytes())==h,('current compiled input',path)
  assert js(p+'full/manifest.json')['executable_sha256']==meta['executable_sha256']
  if opt=='O2':
   for name in ['state.csv','endpoint.csv','restart.bin','budget.csv']:assert f[p+'full/'+name]==f['native-O0/full/'+name]
  failed='failed470-'+opt+'/'
  assert f[failed+'diagnostic-rejected.bin']==f[p+'full/restart.bin']
  stream=f[failed+'stdout'];assert b'470'in stream and b'336         246          69           0'in stream
  for name in ['plain','boesten']:
   q='joint-'+name+'-'+opt+'/';j=js(q+'result.json');assert j['status']=='DRAINAGE_JOINT_PASS'
   for x,y in [('original.bin','rejected.bin'),('original.bin','invalid.bin'),('original.bin','geometry.bin'),('retry.bin','fresh.bin'),('retry.bin','again.bin')]:assert f[q+x]==f[q+y]
   assert b'DRAINAGE_TRIAL_PARTITION_REJECTION_RETRY_ABA_PASS'in f[q+'001.stdout']
   assert ('existing Boesten wet endpoint reset'in f[q+'joint.f90'].decode())==(name=='boesten')
  keep='preserved-'+opt+'/';assert js(keep+'result.json')['status']=='NATIVE_BOESTEN_ROOT_SOLUTE_V3_RESTART_PASS'
  for name in ['state.csv','endpoint.csv','restart.bin','budget.csv']:assert f[keep+'historical/full/'+name]==f['prior481-'+opt+'/'+name]
  wet='wet-'+opt+'/';w=js(wet+'result.json');assert w['status']=='ACTUAL_LATER_RAIN_SEGMENT_FAILURE_DAY_ATOMIC_PASS'and w['complete_days']==6 and w['completed_segments_before_rejection']==14
  assert f[wet+'prefix/restart.bin']==f[wet+'rejected/diagnostic-rejected.bin']!=f[wet+'rejected/diagnostic-partial-candidate.bin']
  research=js('research-'+opt+'/result.json');assert research['status']=='SIX_CURRENT_WATER_TRACES_EXACT_TO_PR1401'
  for path,h in research['current_provider_inputs'].items():assert sha((ROOT/path).read_bytes())==h
 n=js('nut/hist/result.json');reuse=js('nut/hist/REUSE.json');assert n['status']=='HIST_BOUNDED_PHYSICAL_PASS_NOT_FULL_MIGRATION'
 assert n['results']==js('nut/prior-hist-result.json')['results']and reuse['fresh_native_events']==78 and reuse['fresh_compile_events']==74 and reuse['reused_compile_events']==580
 joint=js('nut/joint/result.json');assert joint['status']=='ZERO_POOL_ACTUAL_CROP_IMMOBILISATION_O0_O2_PASS'and joint['actual_runs']==10 and joint['separate_process_restarts']==20
 assert joint['results']==js('nut/prior-joint-result.json')['results']
 for meta in [n,joint]:
  for path,h in meta['input_sha256'].items():assert sha((ROOT/path).read_bytes())==h,('current NUT input',path)
 assert js('input-controls/result.json')['status']=='NATIVE_DRAINAGE_INPUT_SCOPE_AND_ORIGINAL_MACRO_REJECTION_PASS'
 assert b'unsupported active swmacro'in f['input-controls/original.stderr']
 cpu=js('cpu/result.json');assert cpu['status']=='ACTUAL_CPU_NOT_GENERAL_SPEED_CLAIM'and cpu['runs']['normal']['complete_days']==469 and cpu['runs']['wet']['complete_days']==6
 assert b'64          64'in f['headtol-diagnostic/stdout']
 return dict(qualified=True,status='BOUNDED_NATIVE_DRAMET3_DIVDRA_BOESTEN_469_DAY_QUALIFIED',bounded_days=469,full_original_Andelst=False,full_mc_sol01_closed=False,full_mc_nut01_closed=False,canonically_admitted=False,frozen_predecessor_controls=75,current_NUT_HIST_processes=78,current_NUT_coupled_runs=10,current_NUT_process_restarts=20,current_SOL_research_water_traces=12,open_blocker='day470 Reference nonlinear iteration / wet day7')
def verify():source();return validate(capsule())
def self_test():
 source();f=capsule();validate(f);passed=[]
 def reject(label,fn):
  try:fn()
  except(AssertionError,KeyError,ValueError):passed.append(label);return
  raise AssertionError('accepted drainage corruption '+label)
 for p in record()['postimages']:reject('source '+p,lambda p=p:source(lambda q:(ROOT/q).read_bytes()+(b'!'if p==q else b'')))
 reject('foreign caller',lambda:source(changed={'src/foreign_drainage.f90':'A'}))
 for p in ['native-O2/full/budget.csv','native-O0/resumed/restart.bin','failed470-O2/diagnostic-rejected.bin','joint-boesten-O2/again.bin','wet-O0/rejected/diagnostic-rejected.bin','nut/hist/result.json','nut/joint/result.json','input-controls/original.stderr','research-O2/result.json','cpu/result.json']:
  bad=dict(f)
  if p.endswith('original.stderr'):bad[p]=bad[p].replace(b'swmacro',b'absent')
  else:bad[p]+=b'!'
  reject('raw '+p,lambda bad=bad:validate(bad))
 return passed
if __name__=='__main__':print(json.dumps(verify(),indent=2))
