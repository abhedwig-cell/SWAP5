"""Bounded existing-Boesten owner composition; original assertions preserved."""
import base64,csv,hashlib,io,json,re,runpy,subprocess,tarfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
BASE='4beca65677d3f66b7caebc5246351e7302863f6b'
STATUS='integration/mc-sol01/boesten/STATUS.json'
SELF='integration/audits/verify_native_boesten.py'
PARENT='integration/audits/verify_nut_nondepleting.py'
RAIN='integration/audits/verify_native_detailed_rain.py'
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
 r=record(reader);assert r['baseline']==BASE;git('merge-base','--is-ancestor',BASE,'HEAD')
 delta={line.split('\t')[1]:line.split('\t')[0]for line in git('diff','--name-status',BASE,'HEAD','--',*SCIENCE).splitlines()}
 assert delta==r['scientific_delta'],'unregistered Boesten scientific delta'
 assert not git('status','--porcelain','--',*SCIENCE),'dirty Boesten science'
 assert reader(PARENT)==projection(),'predecessor assertion body changed'
 old=before('tests/fapp/run_ppa_wu04b_boesten_evaporation.sh').decode()
 assert reader('tests/fapp/run_ppa_wu04b_boesten_evaporation.sh').decode()==old.replace("trap 'rm -rf \"$BUILD\"' EXIT", "if [[ \"${SWAP5_KEEP_BUILD:-0}\" != \"1\" ]]; then trap 'rm -rf \"$BUILD\"' EXIT; fi"),'original water gate assertions changed'
 for p,h in r['postimages'].items():assert sha(reader(p))==h,('Boesten source',p)
 if changed is not None:
  for p in changed:assert p in delta or subprocess.run(['git','cat-file','-e',BASE+':'+p],cwd=ROOT,capture_output=True).returncode==0,'foreign Boesten caller'
 return json.loads(reader('integration/audits/MC_SOL01_DYNAMIC_DECAY_STATUS.json'))['swp_water_successor']
def capsule():
 e=record()['evidence'];raw=base64.b64decode(b''.join((ROOT/e['path']).read_bytes().split()),validate=True);assert sha(raw)==e['decoded_sha256']
 with tarfile.open(fileobj=io.BytesIO(raw),mode='r:xz')as t:
  ms=t.getmembers();assert len(ms)==len({m.name for m in ms})and all(m.isfile()and not Path(m.name).is_absolute()and'..'not in Path(m.name).parts for m in ms)
  f={m.name:t.extractfile(m).read()for m in ms}
 inventory=json.loads(f.pop('MANIFEST.json'));assert inventory=={p:sha(b)for p,b in f.items()}
 return f
def validate(f):
 def js(p):return json.loads(f[p])
 def rows(p):return [{k:float(v)for k,v in r.items()}for r in csv.DictReader(io.StringIO(f[p].decode()))]
 assert js('predecessor/owner.json')['qualified']and len(js('predecessor/controls.json'))==40
 assert f['predecessor/source.py']==before(PARENT)
 incumbent=runpy.run_path(str(ROOT/RAIN))['capsule']()
 nut=runpy.run_path(str(ROOT/PARENT));old_nut=nut['capsule']()
 # Original NUT assertions retain their historical receipts and identities for
 # these changed water providers; fresh current HIST/joint executions follow.
 class ArchivedPath:
  def __init__(self,p):self.p=p
  def read_bytes(self):return before(self.p)
 class HistoricalRoot:
  def __truediv__(self,p):return ArchivedPath(p)if p in ['src/runtime/mod_fmr_serialized_reference_backend.f90','src/runtime/mod_fmr_process_hydraulic_view_binding.f90']else ROOT/p
 nut['validate'].__globals__['ROOT']=HistoricalRoot()
 assert nut['validate'](old_nut)['qualified']
 hist=js('nut-current/hist/result.json');reuse=js('nut-current/hist/REUSE.json')
 assert hist['status']=='HIST_BOUNDED_PHYSICAL_PASS_NOT_FULL_MIGRATION'and hist['results']==json.loads(old_nut['hist/result.json'])['results']
 assert reuse['status']=='CURRENT_BOESTEN_NUT_HIST_ASSERTIONS_AND_ENDPOINTS_EXACT'
 assert reuse['all_original_assertions_completed']and reuse['complete_incumbent_results_exact']and reuse['fresh_native_events']==78
 assert reuse['fresh_compile_events']+reuse['reused_compile_events']==654
 joint_nut=js('nut-current/joint/result.json')
 assert joint_nut['status']=='NONDEPLETING_ACTUAL_CROP_RICHARDS_IMMOBILISATION_O0_O2_PASS'
 assert joint_nut['results']==json.loads(old_nut['joint/result.json'])['results']
 assert joint_nut['actual_runs']==4 and joint_nut['separate_process_restarts']==8
 for prefix,r in [('hist',hist),('joint',joint_nut)]:
  for p,h in r['input_sha256'].items():assert sha((ROOT/p).read_bytes())==h,('current NUT source',p)
  events=js('nut-current/'+prefix+'/events.json');assert all(e['returncode']==0 for e in events)
  for e in events:
   for stream in ['stdout','stderr']:assert'nut-current/'+prefix+'/'+e[stream]in f
 for opt in ['O0','O2']:
  for case in ['compete','immobilise']:
   stem='nut-current/joint/'+opt+'/'+case
   assert f[stem+'.endpoint']==old_nut['joint/'+opt+'/'+case+'.endpoint']
   for day in [1,4]:
    for suffix in ['', '.ledger']:assert f[stem+'.endpoint'+suffix]==f[stem+'.fresh-'+str(day)+suffix]
   for day in [2,5]:
    for kind in ['exhaust','stale','water']:assert f[stem+'.restart.before-'+str(day)]==f[stem+'.restart.'+kind+'-reject-'+str(day)]
 assert b'PPA-WU04-B BOESTEN PRESERVATION PASS'in f['original-water/gate.log']
 assert b'PPA_WU04B_O0_O2_OUTPUT_IDENTITY=PASS'in f['original-water/gate.log']
 for opt in ['O0','O2']:
  joint=js('joint-'+opt+'/result.json');assert joint['status']=='BOESTEN_ROOT_POND_SOLUTE_REJECTION_RETRY_ABA_V3_FRESH_DECODE_PASS'
  assert all(e['returncode']==0 for e in joint['events'])
  for p,h in joint['inputs'].items():assert sha((ROOT/p).read_bytes())==h,('compiled joint source',p)
  for x,y in [('original.bin','rejected.bin'),('original.bin','unsupported.bin'),('retry.bin','fresh.bin'),('retry.bin','again.bin'),('original.bin','invalid.bin'),('retry.bin','decoded.bin')]:assert f['joint-'+opt+'/'+x]==f['joint-'+opt+'/'+y]
  prefix='native-'+opt+'/';r=js(prefix+'result.json');assert r['status']=='NATIVE_BOESTEN_ROOT_SOLUTE_V3_RESTART_PASS'
  for p,h in r['source'].items():assert sha((ROOT/p).read_bytes())==h,('native executed source',p)
  assert set(r['cases'])=={'short','historical'}
  current_build=js('build-'+opt+'/column/build-complete.json')
  for case,days,split in [('short',8,3),('historical',481,365)]:
   path=prefix+case+'/';assert r['cases'][case]['days']==days and r['cases'][case]['complete_period']
   for p in ['state.csv','endpoint.csv','restart.bin']:assert f[path+'full/'+p]==f[path+'resumed/'+p]
   assert f[path+'full/restart.bin'][:8]==b'S5MJ0003'
   assert js(path+'full/manifest.json')['executable_sha256']==current_build['executable_sha256']
   audit_text=f[path+'full/input.nml'].decode()
   audit=json.loads(base64.b64decode(''.join(l.split('=',1)[1]for l in audit_text.splitlines()if l.startswith('! native_project_audit_base64='))))
   assert abs(audit['boesten_cofred']-(.79 if case=='historical'else .35))<1e-15
   assert b'COFREDBO='in f[path+'full/input.swp']
   data=rows(path+'full/budget.csv');assert len(data)==days and rows(path+'resumed/budget.csv')==data[split:]
   for d in data:
    for kind,unit in [('water','cm'),('solute','mg_cm2')]:
     assert abs(d[kind+'_residual_'+unit])<1e-10
     assert abs(d[kind+'_end_'+unit]-d[kind+'_start_'+unit]-d[kind+'_in_'+unit]+d[kind+'_out_'+unit])<1e-10
    if case=='historical':assert abs(d['water_end_cm']-d['water_start_cm']-d['rain_supplied_cm']+d['runoff_cm']+d['soil_evaporation_cm']+d['pond_evaporation_cm']+d['actual_transpiration_cm']-d['bottom_up_cm'])<1e-10
   assert all(min(d[k]for k in ['theta','concentration_mg_cm3','dissolved_mg_cm2','sorbed_mg_cm2'])>=0. for d in rows(path+'full/state.csv'))
   if opt=='O2':
    for p in ['state.csv','endpoint.csv','restart.bin','budget.csv']:assert f[path+'full/'+p]==f['native-O0/'+case+'/full/'+p],'Boesten optimization drift'
  for component in ['column','read_project','read_crop','read_root']:
   b=js('build-'+opt+'/'+component+'/build-complete.json');assert b['status']=='BUILT'and'-'+opt in b['flags']and'-fcheck=all'in b['flags']
   for p,h in b['input_sha256'].items():assert sha((ROOT/p).read_bytes())==h,('actual current build',p)
  preserved=js('rain-'+opt+'/result.json');assert preserved['status']=='NATIVE_DETAILED_RAIN_SOIL_FACTOR_COMPOSITION_PASS'
  for case in ['pulse','cross_year']:
   for p in ['budget.csv','state.csv','endpoint.csv','restart.bin']:
    path=case+'/full/'+p;assert f['rain-'+opt+'/'+path]==incumbent['rain-'+opt+'/'+path],'prior detailed rain physics changed'
  assert js('daily-'+opt+'/result.json')['status']=='SEASONAL_BOTTOM_COMPOSITION_PASS'
  assert js('proposal-'+opt+'/result.json')['status']=='CURRENT_APPLICATION_WET_PROPOSAL_97_DAY_EXACT'
  wet=js('wet-'+opt+'/result.json');assert wet['status']=='ACTUAL_LATER_RAIN_SEGMENT_FAILURE_DAY_ATOMIC_PASS'
  assert wet['complete_days']==6 and wet['completed_segments_before_rejection']==14
  assert f['wet-'+opt+'/prefix/restart.bin']==f['wet-'+opt+'/rejected/diagnostic-rejected.bin']!=f['wet-'+opt+'/rejected/diagnostic-partial-candidate.bin']
 return dict(qualified=True,status='NATIVE_BOESTEN_ROOT_SOLUTE_O0_O2_481_DAY_V3_AND_CURRENT_NUT_QUALIFIED',full_original_Andelst=False,full_mc_sol01_closed=False,full_mc_nut01_closed=False,canonically_admitted=False,frozen_predecessor_controls=40,current_NUT_HIST_processes=78,current_NUT_coupled_runs=4,current_NUT_process_restarts=8)
def verify():source();return validate(capsule())
def self_test():
 source();f=capsule();validate(f);passed=[]
 def reject(label,fn):
  try:fn()
  except(AssertionError,KeyError,ValueError):passed.append(label);return
  raise AssertionError('accepted Boesten corruption '+label)
 for p in record()['postimages']:reject('source '+p,lambda p=p:source(lambda q:(ROOT/q).read_bytes()+(b'!'if p==q else b'')))
 reject('foreign source',lambda:source(changed={'src/foreign_boesten.f90':'A'}))
 for p in ['native-O2/historical/full/budget.csv','native-O0/historical/resumed/restart.bin','joint-O2/rejected.bin','joint-O0/decoded.bin','original-water/gate.log','predecessor/controls.json','rain-O2/cross_year/full/state.csv','nut-current/hist/result.json','nut-current/joint/O0/compete.endpoint']:
  bad=dict(f);bad.pop(p);reject('missing '+p,lambda bad=bad:validate(bad))
 return passed
if __name__=='__main__':print(json.dumps(verify(),indent=2))
