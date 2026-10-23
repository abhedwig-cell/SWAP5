"""Bounded native481-day drainage admission; frozen ancestor is separate proof."""
import base64,csv,hashlib,io,json,re,runpy,subprocess,tarfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
BASE='eb4288359e8208bb2fb03b22c622a68315836455'
STATUS='integration/mc-sol01/drainage/DAY470_STATUS.json'
PARENT='integration/audits/verify_nut_resonant_pool.py'
SELF='integration/audits/verify_saturated_picard.py'
SCIENCE=['src','app','tools','tests','examples','reference','.github','integration/audits','integration/performance','integration/diagnostics']
sha=lambda b:hashlib.sha256(b).hexdigest()
def git(*args):return subprocess.check_output(['git',*args],cwd=ROOT,text=True).strip()
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
 assert delta==r['scientific_delta'],'foreign Picard successor delta'
 assert not git('status','--porcelain','--',*SCIENCE),'dirty Picard science'
 assert reader(PARENT)==projection(),'predecessor assertions changed'
 assert {p for p in delta if p.startswith('src/')}=={'src/legacy/b1_10_port/headcalc.f90'}
 for p,h in r['postimages'].items():assert sha(reader(p))==h,('Picard source',p)
 if changed is not None:
  for p in changed:assert p in delta or subprocess.run(['git','cat-file','-e',BASE+':'+p],cwd=ROOT,capture_output=True).returncode==0,'foreign caller'
 return json.loads(reader('integration/audits/MC_SOL01_DYNAMIC_DECAY_STATUS.json'))['swp_water_successor']
def capsule():
 e=record()['evidence'];raw=base64.b64decode((ROOT/e['path']).read_bytes(),validate=True);assert sha(raw)==e['sha256']
 with tarfile.open(fileobj=io.BytesIO(raw),mode='r:xz')as t:
  ms=t.getmembers();assert len(ms)==len({m.name for m in ms})and all(m.isfile()and not Path(m.name).is_absolute()and'..'not in Path(m.name).parts for m in ms)
  f={m.name:t.extractfile(m).read()for m in ms}
 inventory=json.loads(f.pop('MANIFEST.json'));assert inventory=={p:sha(b)for p,b in f.items()}
 return f
def validate(f):
 def js(p):return json.loads(f[p])
 def rows(p):return[{k:float(v)for k,v in d.items()}for d in csv.DictReader(io.StringIO(f[p].decode()))]
 def inputs(d):
  for p,h in d.items():assert sha((ROOT/p).read_bytes())==h,('executed input',p)
 frozen=js('frozen-current.json');assert frozen['owner']['qualified']and len(frozen['controls'])==156
 assert f['frozen-parent.py']==before(PARENT)
 assert b'470'in f['preimage470/stdout']and b'336         246          69           0'in f['preimage470/stdout']
 assert f['preimage470/diagnostic-rejected.bin']==f['prior469/restart.bin']
 direct=js('direct/result.json');assert direct['status']=='SATURATED_PICARD_MATCHED_UNMATCHED_MASS_NONMUTATION_ABA_PASS';inputs(direct['input_sha256'])
 assert direct['outputs']['O0-current']==direct['outputs']['O2-current']==direct['outputs']['O0-old']==direct['outputs']['O2-old']
 assert b'FCI93_FIXED_K_NATIVE_IMMUTABLE_ORACLE_O0_O2=PASS'in f['fsi35/stdout']
 for opt in ['O0','O2']:
  p='native-'+opt+'/';r=js(p+'result.json');assert r['status']=='NATIVE_DRAMET3_DIVDRA_RESTART_PASS'and r['restart_exact']and r['days']==481
  assert r['original_drainage_sha256']=='4c23dec437ee72338db01b04d82829d57b2cf994f9395bba1691aebaa32cface'
  data=rows(p+'full/budget.csv');assert len(data)==481 and rows(p+'resumed/budget.csv')==data[365:]
  for name in ['state.csv','endpoint.csv','restart.bin']:assert f[p+'full/'+name]==f[p+'resumed/'+name]
  for d in data:
   assert abs(d['water_residual_cm'])<1e-10 and abs(d['solute_residual_mg_cm2'])<1e-10 and d['drainage_cm']>=0
   assert abs(d['water_end_cm']-d['water_start_cm']-d['rain_supplied_cm']+d['runoff_cm']+d['soil_evaporation_cm']+d['pond_evaporation_cm']+d['actual_transpiration_cm']-d['bottom_up_cm']+d['drainage_cm'])<1e-10
  assert abs(sum(d['drainage_cm']for d in data)-28.88302849633615)<1e-12
  for d in rows(p+'full/state.csv'):assert min(d[k]for k in ['theta','concentration_mg_cm3','dissolved_mg_cm2','sorbed_mg_cm2'])>=0
  meta=js('build-'+opt+'/column/build-complete.json');inputs(meta['input_sha256'])
  assert '-fcheck=all'in meta['flags']and '-'+opt in meta['flags']
  for label in ['full','resumed']:assert js(p+label+'/manifest.json')['executable_sha256']==meta['executable_sha256']
  if opt=='O2':
   for name in ['state.csv','endpoint.csv','restart.bin','budget.csv']:assert f[p+'full/'+name]==f['native-O0/full/'+name]
   assert r['source_rejection']and b'restart'in f[p+'source-rejection.stderr']
  else:assert r['events'][-1]['returncode']!=0 and not r['events'][-1]['expected_success']
  keep='preserve-'+opt+'/';k=js(keep+'result.json');assert k['ordinary_days']==481 and all(k['ordinary_bytes_exact'].values())
  for name in ['state.csv','endpoint.csv','restart.bin','budget.csv']:assert f[keep+'ordinary/'+name]==f['prior-ordinary-'+opt+'/'+name]
  w=k['wet'];assert w['status']=='ACTUAL_LATER_RAIN_SEGMENT_FAILURE_DAY_ATOMIC_PASS'and w['complete_days']==6 and w['completed_segments_before_rejection']==14
  assert f[keep+'wet/prefix/restart.bin']==f[keep+'wet/rejected/diagnostic-rejected.bin']!=f[keep+'wet/rejected/diagnostic-partial-candidate.bin']
  research=js('trace-'+opt+'/result.json');assert research['status']=='SIX_CURRENT_WATER_TRACES_EXACT_TO_PR1401';inputs(research['current_provider_inputs'])
 hist=js('nut-current/hist/result.json');inputs(hist['input_sha256']);assert hist['status']=='HIST_BOUNDED_PHYSICAL_PASS_NOT_FULL_MIGRATION'
 reuse=js('nut-current/hist/REUSE.json');assert reuse['fresh_compile_events']==2 and reuse['reused_compile_events']==652 and reuse['fresh_native_events']==78 and reuse['complete_incumbent_results_exact']
 joint=js('nut-current/joint/result.json');inputs(joint['input_sha256']);assert joint['status']=='RESONANT_ACTUAL_CROP_IMMOBILISATION_O0_O2_PASS'and joint['actual_runs']==18 and joint['separate_process_restarts']==36
 for e in js('nut-current/joint/events.json'):
  assert e['returncode']==0
  if e['category']=='native':assert b'NONDEPLETING_COMPETING_JOINT_PASS'in f['nut-current/joint/'+e['stdout']]
 research_results={}
 for label,path in [('joint','integration/mc-sol01/fct_joint_acceptance/verify.py'),('reactive','integration/mc-sol01/fct_reactive/verify.py')]:
  ns=runpy.run_path(str(ROOT/path));files={p[len('research-'+label+'/'):]:b for p,b in f.items()if p.startswith('research-'+label+'/')}
  research_results[label]=ns['assess'](files)
  assert not research_results[label]['production_activated']
 cpu=js('cpu/result.json');assert cpu['status']=='ACTUAL_CPU_NOT_GENERAL_SPEED_CLAIM'and cpu['runs']['normal']['complete_days']==481 and cpu['runs']['wet']['complete_days']==6
 return dict(qualified=True,status='NATIVE_ORIGINAL_DRA_481_DAY_SATURATED_PICARD_QUALIFIED',bounded_days=481,O0_O2_exact=True,restart365_exact=True,original_no_DRA481_exact=True,current_NUT_processes=78,current_NUT_coupled_runs=18,current_NUT_restarts=36,frozen_controls=156,research=research_results,full_original_Andelst=False,full_mc_sol01_closed=False,full_mc_nut01_closed=False,canonically_admitted=False)
def verify():source();return validate(capsule())
def self_test():
 source();f=capsule();validate(f);passed=[]
 def reject(label,fn):
  try:fn()
  except(AssertionError,KeyError,ValueError):passed.append(label);return
  raise AssertionError('accepted Picard corruption '+label)
 for p in record()['postimages']:reject('source '+p,lambda p=p:source(lambda q:(ROOT/q).read_bytes()+(b'!'if p==q else b'')))
 reject('foreign caller',lambda:source(changed={'src/foreign_picard.f90':'A'}))
 for p in ['native-O2/full/budget.csv','native-O0/resumed/restart.bin','preserve-O2/wet/rejected/diagnostic-rejected.bin','nut-current/hist/result.json','nut-current/joint/result.json','direct/result.json','frozen-current.json','cpu/result.json']:
  bad=dict(f);bad[p]+=b'!';reject('raw '+p,lambda bad=bad:validate(bad))
 return passed
if __name__=='__main__':print(json.dumps(verify(),indent=2))
