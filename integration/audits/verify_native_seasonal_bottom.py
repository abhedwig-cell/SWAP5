"""Bounded native seasonal caller admission; inherited science stays source exact."""
import base64,csv,hashlib,io,json,runpy,subprocess,tarfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
BASE='7ae093c5b32b4abfd10a6a37c8113ecffa2cdbb6'
STATUS='integration/audits/MC_SOL01_DYNAMIC_DECAY_STATUS.json'
KEY='historical_integration01_20261023'
PARENT='integration/audits/verify_nut_historical_output_caller.py'
SELF='integration/audits/verify_native_seasonal_bottom.py'
PARENTS=[PARENT,'integration/audits/native_project_admission.py','integration/audits/verify_nut_saved_calendar_output.py','integration/performance/verify_saturated_flux_successor.py']
SCIENCE=['src','app','tools','tests','examples','reference','.github','integration/audits','integration/performance','integration/diagnostics']
def sha(raw):return hashlib.sha256(raw).hexdigest()
def git(*args):return subprocess.check_output(['git',*args],cwd=ROOT,text=True).strip()
def before(path):return subprocess.check_output(['git','show',BASE+':'+path],cwd=ROOT)
def record(reader=lambda p:(ROOT/p).read_bytes()):return json.loads(reader(STATUS))[KEY]
def enabled():return KEY in json.loads((ROOT/STATUS).read_text())
def projection(path=PARENT):
 text=before(path).decode()
 for name,args in [('source','reader,changed'),('verify',''),('self_test','')]:
  at=text.index('\n',text.index('def '+name+'('))+1
  hook=" if '"+KEY+"' in json.loads((ROOT/'"+STATUS+"').read_text()):return __import__('runpy').run_path(str(ROOT/'"+SELF+"'))['"+name+"']("+args+")\n"
  text=text[:at]+hook+text[at:]
 return text.encode()
def source(reader=lambda p:(ROOT/p).read_bytes(),changed=None):
 successor=ROOT/'integration/audits/verify_nut_regular_limits.py'
 if successor.is_file():
  owner=__import__('runpy').run_path(str(successor))
  if owner['enabled']():return owner['source'](reader,changed)
 r=record(reader);assert r['baseline']==BASE
 git('merge-base','--is-ancestor',BASE,'HEAD')
 assert git('rev-parse','HEAD:src')==git('rev-parse',BASE+':src'),'shared physical owner changed'
 delta={row.split('\t')[1]:row.split('\t')[0]for row in git('diff','--name-status',BASE,'HEAD','--',*SCIENCE).splitlines()}
 assert delta==r['scientific_delta'],'unregistered seasonal source delta'
 assert not git('status','--porcelain','--',*SCIENCE),'dirty seasonal science'
 for p,h in {**r['postimages'],**r['incumbent_inputs']}.items():assert sha(reader(p))==h,('seasonal source',p)
 for path in PARENTS:assert reader(path)==projection(path),'incumbent assertion body changed '+path
 current=json.loads(reader(STATUS));current.pop(KEY);assert current==json.loads(before(STATUS)),'unrelated SOL authority changed'
 if changed is not None:
  for p in changed:
   assert p in delta or subprocess.run(['git','cat-file','-e',BASE+':'+p],cwd=ROOT,capture_output=True).returncode==0,'foreign seasonal science'
 return json.loads(reader(STATUS))['swp_water_successor']
def capsule():
 r=record();raw=base64.b64decode(b''.join((ROOT/r['evidence']['path']).read_bytes().split()),validate=True)
 assert sha(raw)==r['evidence']['decoded_sha256']
 with tarfile.open(fileobj=io.BytesIO(raw),mode='r:xz')as t:
  members=t.getmembers();assert len(members)==len({m.name for m in members})and all(m.isfile()and not Path(m.name).is_absolute()and'..'not in Path(m.name).parts for m in members)
  f={m.name:t.extractfile(m).read()for m in members}
 manifest=json.loads(f.pop('MANIFEST.json'));assert set(f)==set(manifest)and all(sha(f[p])==h for p,h in manifest.items())
 return f
def validate(f):
 def js(p):return json.loads(f[p])
 prior=js('predecessor/owner.json');controls=js('predecessor/controls.json')
 assert prior['qualified']and len(controls)==record()['incumbent_control_count'],'incumbent complete admission lost'
 assert f['predecessor/source.py']==before(PARENT),'predecessor assertion body identity'
 for opt in ['O0','O2']:
  prefix=opt+'/';r=js(prefix+'result.json');assert r['status']=='SEASONAL_BOTTOM_COMPOSITION_PASS'
  build=js('build-'+opt+'/column/build-complete.json')
  assert build['status']=='BUILT'and '-'+opt in build['flags']and'-fcheck=all'in build['flags']
  for p,h in build['input_sha256'].items():assert sha((ROOT/p).read_bytes())==h,('actual compiled source',p)
  for name in ['default','seasonal','cross_year']:assert js(prefix+name+'/full/manifest.json')['executable_sha256']==build['executable_sha256']
  assert set(r['cases'])=={'default','seasonal','cross_year'}and len(r['events'])==11
  assert [e['returncode']for e in r['events']]==[0,0,0,0,0,0,1,0,0,0,1]
  assert sha(f['execution-recipe.py'])==r['sources']['tests/nut-sol/qualify_native_seasonal_bottom.py']
  for p,h in r['sources'].items():
   if p!='tests/nut-sol/qualify_native_seasonal_bottom.py':assert sha((ROOT/p).read_bytes())==h
  assert b'PPA-LOW02-TIME INDEPENDENT QUALIFICATION PASS'in f['oracle/'+opt+'/stdout']
  for name,days,split in [('default',8,3),('seasonal',8,3),('cross_year',481,365)]:
   case=prefix+name+'/'
   for p in ['state.csv','endpoint.csv','restart.bin']:assert f[case+'full/'+p]==f[case+'resumed/'+p],(opt,name,p)
   def rows(p):return [{k:float(v)for k,v in r.items()}for r in csv.DictReader(io.StringIO(f[case+p].decode()))]
   budget=rows('full/budget.csv');assert len(budget)==days and rows('resumed/budget.csv')==budget[split:]
   document=f[case+'full/input.nml'].decode();audit=json.loads(base64.b64decode(''.join(l.split('=',1)[1]for l in document.splitlines()if l.startswith('! native_project_audit_base64='))))
   for i,d in enumerate(budget):
    for substance,unit in [('water','cm'),('solute','mg_cm2')]:
     assert abs(d[substance+'_residual_'+unit])<1e-10
     assert abs(d[substance+'_end_'+unit]-d[substance+'_start_'+unit]-d[substance+'_in_'+unit]+d[substance+'_out_'+unit])<1e-10
    if name!='default':
     rain=float(audit['prepared_periods'][0]['rain'][i]['rain_cm_day'])
     gross=d['water_end_cm']-d['water_start_cm']-rain+d['soil_evaporation_cm']+d['pond_evaporation_cm']+d['runoff_cm']+d['actual_transpiration_cm']-d['bottom_up_cm']
     assert abs(gross)<1e-10,'independent seasonal gross water budget'
   if name=='default':
    for p in ['state.csv','endpoint.csv','restart.bin','budget.csv']:assert f[case+'full/'+p]==f['incumbent/'+opt+'/'+p],'unchanged constant-bottom physics'
   if name=='seasonal':assert min(d['bottom_up_cm']for d in budget)<0<max(d['bottom_up_cm']for d in budget)
   if name=='cross_year':
    assert audit['days']==481 and audit['periods']==3 and audit['seasonal_bottom']['bottom_amplitude']==.005
    assert f[case+'full/input.swp']==f[case+'split/input.swp'],'immutable future calendar'
    for p in ['state.csv','endpoint.csv','restart.bin','budget.csv']:assert f[case+'full/'+p]==f['O0/cross_year/full/'+p],'optimization drift'
 return dict(qualified=True,status='NATIVE_SEASONAL_BOTTOM_O0_O2_481_DAY_QUALIFIED',native_daily_observations=994,cross_year_restart_exact=True,optimization_exact=True,incumbent_controls=record()['incumbent_control_count'],full_historical_migration=False,full_mc_sol01_closed=False,full_mc_nut01_closed=False)
def verify():
 successor=ROOT/'integration/audits/verify_nut_regular_limits.py'
 if successor.is_file():
  owner=__import__('runpy').run_path(str(successor))
  if owner['enabled']():return owner['verify']()
 source();return {**json.loads(capsule()['predecessor/owner.json']),**validate(capsule()),'qualification_scope':'BOUNDED_NATIVE_SEASONAL_SWBOTB2_CALLER_WITH_SOURCE_EXACT_INCUMBENT','canonically_admitted':False}
def self_test():
 successor=ROOT/'integration/audits/verify_nut_regular_limits.py'
 if successor.is_file():
  owner=__import__('runpy').run_path(str(successor))
  if owner['enabled']():return owner['self_test']()
 source();f=capsule();validate(f);controls=['incumbent:'+x for x in json.loads(f['predecessor/controls.json'])]
 def reject(label,fn):
  try:fn()
  except(AssertionError,ValueError,KeyError):controls.append(label);return
  raise AssertionError('accepted seasonal corruption '+label)
 for p in [SELF,PARENT,'app/solute_project/main.f90','app/solute_crop/read_swp_project.f90','tools/solute/run_project.py','src/runtime/mod_fmr_serialized_reference_backend.f90']:
  reject('source '+p,lambda p=p:source(lambda q:(ROOT/q).read_bytes()+(b'!'if q==p else b'')))
 for p in ['O0/cross_year/full/budget.csv','O2/cross_year/resumed/restart.bin','predecessor/controls.json','execution-recipe.py']:
  bad=dict(f);bad[p]+=b'!';reject('raw '+p,lambda bad=bad:validate(bad))
 bad=dict(f);bad.pop('oracle/O2/stdout');reject('missing oracle',lambda:validate(bad))
 reject('foreign source',lambda:source(changed={'src/foreign_seasonal.f90':'A'}))
 return controls
if __name__=='__main__':print(json.dumps(verify(),indent=2))
