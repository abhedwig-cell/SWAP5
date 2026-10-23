"""Typed policy successor: frozen assertions plus fresh affected current execution."""
import csv,hashlib,io,json,re,runpy,subprocess,tarfile
from functools import lru_cache
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
BASE='ef2110c6b0f1aa315eabb00c3672705b6d51a3bf'
STATUS='benchmarks/performance/PERF01_TYPED_WATER_FLUX_20261023_STATUS.json'
PARENT='integration/audits/verify_nut_single_zero_pool.py'
SELF='integration/audits/verify_perf01_typed_water_flux.py'
SCIENCE=['src','app','tools','tests','examples','reference','.github','integration/audits','integration/performance','integration/diagnostics']
sha=lambda b:hashlib.sha256(b).hexdigest()
def git(*args):return subprocess.check_output(['git',*args],cwd=ROOT,text=True).strip()
def before(p,ref=BASE):return subprocess.check_output(['git','show',ref+':'+p],cwd=ROOT)
def record(reader=lambda p:(ROOT/p).read_bytes()):return json.loads(reader(STATUS))
def projection():
 s=before(PARENT).decode()
 for name,args in [('source','reader,changed'),('verify',''),('self_test','')]:
  at=s.index('\n',re.search(r'^def '+name+r'\(',s,re.M).start())+1
  s=s[:at]+" if (ROOT/'"+STATUS+"').is_file():return __import__('runpy').run_path(str(ROOT/'"+SELF+"'))['"+name+"']("+args+")\n"+s[at:]
 return s.encode()
def source(reader=lambda p:(ROOT/p).read_bytes(),changed=None):
 r=record(reader);assert r['owner_baseline']==BASE
 git('merge-base','--is-ancestor',BASE,'HEAD')
 delta={s.split('\t')[1]:s.split('\t')[0]for s in git('diff','--name-status',BASE,'HEAD','--',*SCIENCE).splitlines()}
 assert delta==r['owner_scientific_delta'],'foreign typed-policy scientific delta'
 assert not git('status','--porcelain','--',*SCIENCE),'dirty typed-policy science'
 assert reader(PARENT)==projection(),'incumbent assertion body changed'
 for p,h in r['owner_postimages'].items():assert sha(reader(p))==h,('typed/current preserved source',p)
 if changed is not None:
  for p in changed:assert p in delta or subprocess.run(['git','cat-file','-e',BASE+':'+p],cwd=ROOT,capture_output=True).returncode==0,'foreign typed-policy caller'
 return json.loads(reader('integration/audits/MC_SOL01_DYNAMIC_DECAY_STATUS.json'))['swp_water_successor']
@lru_cache(None)
def frozen():
 ns=dict(__file__=str(ROOT/PARENT),__name__='unchanged_single_zero_assertions');exec(compile(before(PARENT),PARENT,'exec'),ns)
 owned=set(record()['owner_archived_source_aliases'])
 class ArchivedPath:
  def __init__(self,p):self.p=p
  def read_bytes(self):return before(self.p)
  def __str__(self):return str(ROOT/self.p)
  def __fspath__(self):return str(ROOT/self.p)
 class HistoricalRoot:
  def __str__(self):return str(ROOT)
  def __fspath__(self):return str(ROOT)
  def __truediv__(self,p):return ArchivedPath(p)if p in owned else ROOT/p
 ns['ROOT']=HistoricalRoot()
 # Only historical source-identity readers are projected. Current source()
 # never accepts an old postimage. Preserve meaningful inherited controls:
 # an unmodified archived reader must pass before testing its corruption.
 aliases=record()['owner_archived_source_aliases']
 projection_errors=[];projection_checks=[]
 def archived_source(reader=None,changed=None):
  if reader is None:return source(changed=changed)
  def current_reader(p,repair=False):
   observed=reader(p)
   if repair and observed.endswith(b'!'):
    original=sha(observed[:-1])
    if original in aliases.get(p,[])or original==record()['owner_postimages'].get(p):observed=observed[:-1]
   return(ROOT/p).read_bytes()if sha(observed)in aliases.get(p,[])else observed
  try:
   source(lambda p:current_reader(p,True));projection_checks.append(True)
  except(AssertionError,KeyError,ValueError)as error:projection_errors.append(str(error))
  return source(current_reader,changed)
 ns['source']=archived_source
 ns['_source_projection_errors']=projection_errors;ns['_source_projection_checks']=projection_checks
 archived_source(lambda p:(ns['ROOT']/p).read_bytes())
 return ns
def capsule():
 e=record()['owner_evidence'];raw=(ROOT/e['path']).read_bytes();assert sha(raw)==e['sha256']
 with tarfile.open(fileobj=io.BytesIO(raw),mode='r:xz')as t:
  ms=t.getmembers();assert len(ms)==len({m.name for m in ms})and all(m.isfile()and not Path(m.name).is_absolute()and'..'not in Path(m.name).parts for m in ms)
  f={m.name:t.extractfile(m).read()for m in ms}
 assert json.loads(f.pop('MANIFEST.json'))=={p:sha(b)for p,b in f.items()};return f
def fct_assess(f,self_test=False):
 here=ROOT/'integration/mc-sol01/fct_joint_acceptance';n=runpy.run_path(str(here/'verify.py'))
 old=n['unpack'](here/'EVIDENCE.tar.xz.b64',json.loads((here/'EVIDENCE_INDEX.json').read_text())['decoded_sha256'])
 labels=json.loads(old['ROUNDS.json']);label='typed-current';assert label not in labels
 for p,b in f.items():
  if p.startswith('fct/'):old[label+'/'+p[4:]]=b
 old['ROUNDS.json']=json.dumps(labels+[label]).encode()
 result=n['assess'](old)
 if self_test:result['controls']=n['controls'](old)
 return result
def validate(f):
 js=lambda p:json.loads(f[p])
 def rows(p):return [{k:float(v)for k,v in d.items()}for d in csv.DictReader(io.StringIO(f[p].decode()))]
 assert f['predecessor/source.py']==before(PARENT)
 assert len(js('predecessor/controls.json'))==134 and js('predecessor/owner.json')['qualified']
 assert frozen()['verify']()['qualified']
 old=frozen()['capsule']();drain=frozen()['predecessor']()['capsule']()
 def inputs(r,key='input_sha256'):
  for p,h in r[key].items():assert sha((ROOT/p).read_bytes())==h and sha(f['source/'+p])==h,('executed current source',p)
 h=js('nut-hist/result.json');es=js('nut-hist/events.json');reuse=js('nut-hist/REUSE.json');inputs(h)
 assert h['status']=='HIST_BOUNDED_PHYSICAL_PASS_NOT_FULL_MIGRATION'and h['results']==json.loads(old['hist/result.json'])['results']
 assert len(es)==737 and all(e['returncode']==0 for e in es)
 assert sum(e['category']=='compile'for e in es)==654
 assert sum(e['category']in ['native','restart_native','trace_native']for e in es)==78
 assert sum(e['category']=='restart_native'for e in es)==56
 assert reuse['status']=='TYPED_CURRENT_HIST_ALL_ASSERTIONS_AND_ENDPOINTS_EXACT'and reuse['all_original_assertions_completed']
 assert reuse['fresh_compile_events']+reuse['reused_compile_events']==654 and reuse['fresh_native_events']==78
 assert reuse['original_recipe_sha256']==sha((ROOT/'tests/nut-crop/run_hist_complete.py').read_bytes())
 for e in es:
  if e['category']in ['native','restart_native','trace_native','link']:assert e['receipt_scope']=='FRESH_CURRENT_EXECUTION'
  if e['category']=='compile'and e['receipt_scope'].startswith('REUSED_'):
   opt=next(v[1:]for v in e['command']if v in ['-O0','-O2']);obj=Path(e['command'][-1]).name
   assert e['object_sha256']==reuse['old_artifacts'][opt+'/'+obj]
 for opt,row in h['results'].items():
  assert sha(f['nut-hist/'+opt+'/default.endpoint'])==row['default_endpoint']
  for name,digest in row['endpoint'].items():assert sha(f['nut-hist/'+opt+'/'+name+'.endpoint'])==digest
 n=js('nut-joint/result.json');inputs(n);assert n['status']=='SINGLE_ZERO_ACTUAL_CROP_IMMOBILISATION_O0_O2_PASS'
 assert n['actual_runs']==14 and n['separate_process_restarts']==28 and n['results']==json.loads(old['joint/result.json'])['results']
 assert all(e['returncode']==0 for e in js('nut-joint/events.json'))
 for opt in ['O0','O2']:
  for case in ['compete','immobilise','limited','zero_pools','all_zero','bio_zero','hum_zero']:
   stem='nut-joint/'+opt+'/'+case
   for day in [1,4]:
    for suffix in ['','.ledger']:assert f[stem+'.endpoint'+suffix]==f[stem+'.fresh-'+str(day)+suffix]
   for day in [2,5]:
    for kind in ['exhaust','stale','water']:assert f[stem+'.restart.before-'+str(day)]==f[stem+'.restart.'+kind+'-reject-'+str(day)]
  for family in ['drain','boesten']:
   prefix='native-'+family+'-'+opt+'/';r=js(prefix+'result.json')
   assert r['status']==('NATIVE_DRAMET3_DIVDRA_RESTART_PASS'if family=='drain'else'NATIVE_BOESTEN_ROOT_SOLUTE_V3_RESTART_PASS')
   cases=['']if family=='drain'else['short/','historical/']
   for case in cases:
    p=prefix+case;data=rows(p+'full/budget.csv');days=469 if family=='drain'else(8 if case=='short/'else 481);split=3 if days==8 else 365
    assert len(data)==days and rows(p+'resumed/budget.csv')==data[split:]
    for name in ['state.csv','endpoint.csv','restart.bin']:assert f[p+'full/'+name]==f[p+'resumed/'+name]
    reference=('native-'+opt+'/full/'if family=='drain'else'preserved-'+opt+'/'+case+'full/')
    for name in ['state.csv','endpoint.csv','budget.csv','restart.bin']:assert f[p+'full/'+name]==drain[reference+name],('incumbent default drift',family,opt,name)
    for d in data:
     for kind in ['water','solute']:assert abs(d[kind+'_residual_'+('cm'if kind=='water'else'mg_cm2')])<1e-10
    if opt=='O2':
     for name in ['state.csv','endpoint.csv','budget.csv','restart.bin']:assert f[p+'full/'+name]==f[prefix.replace('O2','O0')+case+'full/'+name]
   if family=='drain':assert abs(sum(d['drainage_cm']for d in data)-27.903797127580066)<1e-12
  for flavor in ['plain','boesten']:
   p='joint-drain-'+flavor+'-'+opt+'/';assert js(p+'result.json')['status']=='DRAINAGE_JOINT_PASS'
   for x,y in [('original.bin','rejected.bin'),('original.bin','invalid.bin'),('original.bin','geometry.bin'),('retry.bin','fresh.bin'),('retry.bin','again.bin')]:assert f[p+x]==f[p+y]
  p='wet-'+opt+'/';r=js(p+'result.json');assert r['status']=='ACTUAL_LATER_RAIN_SEGMENT_FAILURE_DAY_ATOMIC_PASS'and r['complete_days']==6 and r['completed_segments_before_rejection']==14
  assert f[p+'prefix/restart.bin']==f[p+'rejected/diagnostic-rejected.bin']!=f[p+'rejected/diagnostic-partial-candidate.bin']
  p='failed470-'+opt+'/';assert js(p+'result.json')['status']=='CURRENT_DAY470_FAILURE_COMPLETE_COMMITTED_GENERATION_EXACT'
  assert f[p+'rejected/diagnostic-rejected.bin']==f['native-drain-'+opt+'/full/restart.bin']
  r=js('research-'+opt+'/result.json');assert r['status']=='SIX_CURRENT_WATER_TRACES_EXACT_TO_PR1401';inputs(r,'current_provider_inputs')
  for nodes in [40,80,160]:
   for factor in [.8,1.2]:
    path=f'research-{opt}/water-{opt}-{nodes}-{factor}.txt';assert f[path]==drain[path]
  meta=js('build-'+opt+'/column/build-complete.json');inputs(meta);assert '-'+opt in meta['flags']and'-fcheck=all'in meta['flags']
  for family in ['drain','boesten']:
   cases=['']if family=='drain'else['short/','historical/']
   for case in cases:assert js('native-'+family+'-'+opt+'/'+case+'full/manifest.json')['executable_sha256']==meta['executable_sha256']
 fct=fct_assess(f);assert fct['cases']==24
 typed=runpy.run_path(str(ROOT/'benchmarks/performance/seal_perf01_typed_water_flux.py'))
 q=json.loads((ROOT/'benchmarks/performance/PERF01_TYPED_WATER_FLUX_20261023_RESULT.json').read_text());raw=(ROOT/q['evidence']['path']).read_bytes();assert sha(raw)==q['evidence']['sha256']
 assert typed['validate'](typed['unpack'](raw))['native_option_processes']==62
 return dict(qualified=True,status='TYPED_WATER_FLUX_AND_CURRENT_NATIVE_DRAINAGE_NUT_FCT_O0_O2_QUALIFIED',canonically_admitted=False,
  default_native_469_and_481_byte_exact=True,current_NUT_HIST_processes=78,current_NUT_coupled_runs=14,current_NUT_process_restarts=28,
  current_SOL_research_water_traces=12,current_FCT_joint_cases=24,typed_native_processes=62,full_original_Andelst=False,full_mc_sol01_closed=False,full_mc_nut01_closed=False,
  open_incumbent_limit='native drainage day470 and wet day7 unchanged; full SOL/NUT migration not closed')
def verify():
 source();return validate(capsule())
def self_test():
 source();ns=frozen();old=ns['self_test']();assert len(old)==134
 assert not ns['_source_projection_errors'],('invalid inherited reader context',ns['_source_projection_errors'])
 assert len(ns['_source_projection_checks'])>=71
 f=capsule();validate(f);passed=['incumbent:'+p for p in old]
 passed+=['FCT:'+p for p in fct_assess(f,True)['controls']]
 def reject(label,fn):
  try:fn()
  except(AssertionError,KeyError,ValueError,TypeError):passed.append(label);return
  raise AssertionError('accepted typed-owner corruption '+label)
 for p in record()['owner_postimages']:reject('source '+p,lambda p=p:source(lambda q:(ROOT/q).read_bytes()+(b'!'if p==q else b'')))
 reject('foreign caller',lambda:source(changed={'src/foreign_typed_policy.f90':'A'}))
 for p in ['nut-hist/O0/default.endpoint','nut-joint/O2/hum_zero.fresh-4.ledger','native-drain-O0/full/budget.csv',
  'native-boesten-O2/historical/resumed/restart.bin','joint-drain-boesten-O0/rejected.bin','wet-O2/rejected/diagnostic-rejected.bin',
  'failed470-O0/rejected/diagnostic-rejected.bin','research-O2/water-O2-40-0.8.txt','fct/003.stdout']:
  bad=dict(f);bad[p]+=b'!';reject('raw '+p,lambda bad=bad:validate(bad))
 for p in record()['owner_archived_source_aliases']:
  if p in record()['owner_postimages']and before(p)!=(ROOT/p).read_bytes():reject('old current source '+p,lambda p=p:source(lambda q:before(q)if q==p else(ROOT/q).read_bytes()))
 return passed
if __name__=='__main__':
 import sys
 print(json.dumps(self_test()if'--self-test'in sys.argv else verify(),indent=2))
