"""Detailed-rain caller qualification with immutable predecessor assertions."""
import base64,csv,hashlib,io,json,runpy,subprocess,tarfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
BASE='c22fe5b2bfad9cd832be4bca34c8fde1ac40cae7'
STATUS='integration/mc-sol01/detailed_rain/STATUS.json'
SELF='integration/audits/verify_native_detailed_rain.py'
PARENT='integration/performance/verify_native_proposal_successor.py'
SCIENCE=['src','app','tools','tests','examples','reference','.github','integration/audits','integration/performance','integration/diagnostics']
sha=lambda b:hashlib.sha256(b).hexdigest()
def git(*a):return subprocess.check_output(['git',*a],cwd=ROOT,text=True).strip()
def before(p):return subprocess.check_output(['git','show',BASE+':'+p],cwd=ROOT)
def record(reader=lambda p:(ROOT/p).read_bytes()):return json.loads(reader(STATUS))
def projection():
 s=before(PARENT).decode().replace('def verify():source();return validate(capsule())\n','def verify():\n source();return validate(capsule())\n')
 for name,args in [('source','reader,changed'),('verify',''),('self_test','')]:
  at=s.index('\n',s.index('def '+name+'('))+1
  s=s[:at]+" if (ROOT/'"+STATUS+"').is_file():return __import__('runpy').run_path(str(ROOT/'"+SELF+"'))['"+name+"']("+args+")\n"+s[at:]
 return s.encode()
def source(reader=lambda p:(ROOT/p).read_bytes(),changed=None):
 if (ROOT/'integration/mc-nut01/nondepleting_top/STATUS.json').is_file():return __import__('runpy').run_path(str(ROOT/'integration/audits/verify_nut_nondepleting.py'))['source'](reader,changed)
 r=record(reader);assert r['baseline']==BASE
 git('merge-base','--is-ancestor',BASE,'HEAD')
 assert git('rev-parse','HEAD:src')==git('rev-parse',BASE+':src'),'shared owner changed'
 delta={s.split('\t')[1]:s.split('\t')[0]for s in git('diff','--name-status',BASE,'HEAD','--',*SCIENCE).splitlines()}
 assert delta==r['scientific_delta'],'unregistered rain caller delta'
 assert not git('status','--porcelain','--',*SCIENCE),'dirty rain science'
 assert reader(PARENT)==projection(),'predecessor assertion bodies changed'
 for p,h in r['postimages'].items():assert sha(reader(p))==h,('rain source',p)
 if changed is not None:
  for p in changed:assert p in delta or subprocess.run(['git','cat-file','-e',BASE+':'+p],cwd=ROOT,capture_output=True).returncode==0,'foreign caller'
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
 assert js('predecessor/owner.json')['qualified'] and len(js('predecessor/controls.json'))==24
 assert f['predecessor/source.py']==before(PARENT),'original assertion body identity'
 incumbent=runpy.run_path(str(ROOT/'integration/audits/verify_native_seasonal_bottom.py'))['capsule']()
 proposal=runpy.run_path(str(ROOT/PARENT))['capsule']()
 for opt in ['O0','O2']:
  root='rain-'+opt+'/';r=js(root+'result.json');assert r['status']=='NATIVE_DETAILED_RAIN_SOIL_FACTOR_COMPOSITION_PASS'
  oracle,mh,bh=runpy.run_path(str(ROOT/'tests/nut-sol/qualify_native_detailed_rain.py'))['rain_oracle']()
  assert f[root+'rain-oracle.f90']==oracle.encode()and r['original_meteo_sha256']==mh and r['whole_LoadRainData_sha256']==bh
  assert set(r['cases'])=={'pulse','cross_year'} and all(e['returncode']==(0 if e['expected_success']else 1)for e in r['events'])
  for p,h in r['inputs'].items():assert sha((ROOT/p).read_bytes())==h,('executed rain source',p)
  for component in ['column','read_project','read_crop','read_root']:
   b=js('build-'+opt+'/'+component+'/build-complete.json');assert b['status']=='BUILT'and'-'+opt in b['flags']and'-fcheck=all'in b['flags']
   for p,h in b['input_sha256'].items():assert sha((ROOT/p).read_bytes())==h,('actual build input',p)
  for case,days,split in [('pulse',8,3),('cross_year',481,365)]:
   prefix=root+case+'/';assert r['cases'][case]['days']==days and r['cases'][case]['full_period']
   for p in ['state.csv','endpoint.csv','restart.bin']:assert f[prefix+'full/'+p]==f[prefix+'resumed/'+p]
   data=rows(prefix+'full/budget.csv');assert len(data)==days and rows(prefix+'resumed/budget.csv')==data[split:]
   text=f[prefix+'full/input.nml'].decode();audit=json.loads(base64.b64decode(''.join(l.split('=',1)[1]for l in text.splitlines()if l.startswith('! native_project_audit_base64='))))
   expected=rows(prefix+'original-events.csv');assert [{k:float(v)for k,v in x.items()}for x in audit['rain_events']]==expected
   assert len(expected)==(32 if case=='pulse'else 2630)
   original=rows(prefix+'original-rain.csv')
   for i,d in enumerate(data):
    assert abs(d['rain_supplied_cm']-original[i]['rain_cm'])<1e-11
    for substance,unit in [('water','cm'),('solute','mg_cm2')]:
     assert abs(d[substance+'_residual_'+unit])<1e-10
     assert abs(d[substance+'_end_'+unit]-d[substance+'_start_'+unit]-d[substance+'_in_'+unit]+d[substance+'_out_'+unit])<1e-10
    assert abs(d['water_end_cm']-d['water_start_cm']-d['rain_supplied_cm']+d['soil_evaporation_cm']+d['pond_evaporation_cm']+d['runoff_cm']+d['actual_transpiration_cm']-d.get('bottom_up_cm',0.))<1e-10
   for period in audit['prepared_periods']:
    original=rows(prefix+'preparation/original-'+str(period['index'])+'.csv')
    assert len(original)==len(period['plan'])
    for x,y in zip(original,period['plan']):
     for k in x:assert abs(x[k]-float(y[k]))<=1e-13*max(1.,abs(x[k]))
   if opt=='O2':
    for p in ['state.csv','endpoint.csv','restart.bin','budget.csv']:assert f[prefix+'full/'+p]==f['rain-O0/'+case+'/full/'+p],'optimization drift'
  preserved=js('preserved-'+opt+'/result.json');assert preserved['status']=='SEASONAL_BOTTOM_COMPOSITION_PASS'
  for case in ['default','seasonal','cross_year']:
   for p in ['state.csv','endpoint.csv','restart.bin','budget.csv']:
    path=opt+'/'+case+'/full/'+p;assert f['preserved-'+path]==incumbent[path],'incumbent physical output changed'
  wet=js('wet-'+opt+'/result.json');assert wet['status']=='ACTUAL_LATER_RAIN_SEGMENT_FAILURE_DAY_ATOMIC_PASS'
  assert wet['completed_segments_before_rejection']>0
  prefix='wet-'+opt+'/';assert f[prefix+'prefix/restart.bin']==f[prefix+'rejected/diagnostic-rejected.bin']!=f[prefix+'rejected/diagnostic-partial-candidate.bin']
  q=js('proposal-'+opt+'/result.json');assert q['status']=='CURRENT_APPLICATION_WET_PROPOSAL_97_DAY_EXACT'
  for p in ['state.csv','endpoint.csv','restart.bin','budget.csv']:assert f['proposal-'+opt+'/current/'+p]==proposal['qualified/'+opt+'-4x-on-0/'+p]
 return dict(qualified=True,status='NATIVE_DETAILED_RAIN_CFBS_O0_O2_481_DAY_AND_ATOMIC_DAY_QUALIFIED',historical_rain_intervals=2630,full_original_Andelst=False,full_mc_sol01_closed=False,full_mc_nut01_closed=False,canonically_admitted=False,predecessor_controls=24,predecessor_scope='Frozen exact canonical assertion execution; current application physical preservation is freshly tested')
def verify():
 if (ROOT/'integration/mc-nut01/nondepleting_top/STATUS.json').is_file():return __import__('runpy').run_path(str(ROOT/'integration/audits/verify_nut_nondepleting.py'))['verify']()
 source();return validate(capsule())
def self_test():
 if (ROOT/'integration/mc-nut01/nondepleting_top/STATUS.json').is_file():return __import__('runpy').run_path(str(ROOT/'integration/audits/verify_nut_nondepleting.py'))['self_test']()
 source();f=capsule();validate(f);passed=[]
 def reject(label,fn):
  try:fn()
  except(AssertionError,KeyError,ValueError):passed.append(label);return
  raise AssertionError('accepted rain corruption '+label)
 for p in record()['postimages']:reject('source '+p,lambda p=p:source(lambda q:(ROOT/q).read_bytes()+(b'!'if p==q else b'')))
 reject('foreign caller',lambda:source(changed={'src/foreign_rain.f90':'A'}))
 for p in ['rain-O2/cross_year/full/budget.csv','rain-O0/pulse/resumed/restart.bin','rain-O2/cross_year/original-events.csv','predecessor/controls.json','wet-O2/rejected/diagnostic-rejected.bin','proposal-O0/current/restart.bin']:
  bad=dict(f);bad[p]+=b'!';reject('raw '+p,lambda bad=bad:validate(bad))
 return passed
if __name__=='__main__':print(json.dumps(verify(),indent=2))
