"""Bound the experimental storage Jacobian to real flux, linear and native evidence."""
import base64,csv,hashlib,io,json,math,re,runpy,subprocess,tarfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
BASE='078845d20aeaa48d20b2633356e305a6eadfdedd'
PARENT='integration/audits/verify_dataqual09_current.py'
SELF='integration/audits/verify_dataqual10_current.py'
STATUS='integration/dataqual10/STATUS.json'
PROJECTED=['src/process/macropore/mod_ppa_wu05a15_exchange_derivative.f90','src/runtime/mod_ppa_wu05a16_inner_macropore_provider.f90','src/solver/mod_soil_water_solver_contract.f90','src/solver/mod_reference_linear_solver.f90','src/legacy/b1_10_port/headcalc.f90','tools/solute/run_dataqual_batch.py']
sha=lambda b:hashlib.sha256(b).hexdigest()
def git(*args):return subprocess.check_output(['git',*args],cwd=ROOT,text=True).strip()
def baseline(p):return subprocess.check_output(['git','show',BASE+':'+p],cwd=ROOT)
def parent_projection():
 text=baseline(PARENT).decode()
 for name,args in [('source','reader,changed'),('verify',''),('self_test',''),('fsi35_successors','')]:
  at=re.search(r'^def '+name+r'\(',text,re.M).start();end=text.index('):',at)+2
  if text[end:end+1]!='\n':text=text[:end]+'\n '+text[end:]
  end+=1;text=text[:end]+" if (ROOT/'"+STATUS+"').is_file():return __import__('runpy').run_path(str(ROOT/'"+SELF+"'))['"+name+"']("+args+")\n"+text[end:]
 needle=" projected={'src/runtime/mod_macropore_single_column_runtime.f90','app/solute_project/main_water.f90','tools/solute/run_native_water.py',PARENT}\n"
 assert needle in text
 text=text.replace(needle,needle+" if (ROOT/'"+STATUS+"').is_file():projected.update("+repr(PROJECTED)+")\n",1)
 return text.encode()
def source(reader=None,changed=None):
 if (ROOT/'integration/dataqual11/STATUS.json').is_file():return __import__('runpy').run_path(str(ROOT/'integration/audits/verify_dataqual11_current.py'))['source'](reader,changed)
 if reader is None:reader=lambda p:(ROOT/p).read_bytes()
 s=json.loads(reader(STATUS));assert s['baseline']==BASE
 assert not git('diff','HEAD','--','src','app','tools','tests','integration/audits')
 delta={r.split('\t')[1]:r.split('\t')[0]for r in git('diff','--name-status',BASE,'HEAD','--','src','app','tools','tests','examples','reference','.github','integration/audits','integration/performance').splitlines()}
 assert delta==s['scientific_delta'],'foreign scientific delta'
 assert reader(PARENT)==parent_projection(),'predecessor delegation drift'
 for p,h in s['postimages'].items():assert sha(reader(p))==h,p
 return json.loads(reader('integration/audits/MC_SOL01_DYNAMIC_DECAY_STATUS.json'))['swp_water_successor']
def unpack(meta_path):
 m=json.loads((ROOT/meta_path).read_bytes());raw=base64.b64decode(b''.join((ROOT/p).read_bytes()for p in m['parts']),validate=True)
 assert sha(raw)==m['sha256'] and len(raw)==m['bytes']
 with tarfile.open(fileobj=io.BytesIO(raw),mode='r:xz')as t:
  ms=t.getmembers();assert len(ms)==m['members']==len({x.name for x in ms})
  assert all(x.isfile()and not Path(x.name).is_absolute()and'..'not in Path(x.name).parts for x in ms)
  f={x.name:t.extractfile(x).read()for x in ms}
 assert json.loads(f.pop('MANIFEST.json'))=={p:sha(b)for p,b in f.items()};return f
def validate(f):
 js=lambda p:json.loads(f[p]);rows=lambda p:list(csv.DictReader(io.StringIO(f[p].decode())))
 for opt in ['O0','O2']:
  b=json.loads((ROOT/('integration/dataqual10/BUILD_'+opt+'.json')).read_bytes())
  assert b['provider_count']==194 and '-fcheck=all'in b['flags']
  assert sha(f['recovery/native-'+opt])==b['executable_sha256']
  for p,h in b['input_sha256'].items():assert sha((ROOT/p).read_bytes())==h,p
  out=f['contract/'+opt+'-candidate/native.stdout']
  assert b'CONSERVATIVE_LIMITER_JACOBIAN_PASS          48           0'in out
  assert b'STORAGE_COUPLING_FEEDBACK_PASS          72'in out
  assert b'BASELINE_LIMITER_DERIVATIVE_DEFECTS          24          48'in f['contract/'+opt+'-baseline/native.stdout']
  legacy=lambda raw:[x for x in raw.splitlines()if x.startswith(b'LEGACY')]
  assert legacy(out)==legacy(f['contract/'+opt+'-baseline/native.stdout'])
  assert b'DATAQUAL10_LOW_RANK_SOLVE_PASS         216'in f['linear/'+opt+'/stdout']
 assert b'FCI93_FIXED_K_NATIVE_IMMUTABLE_ORACLE_O0_O2=PASS'in f['fsi/stdout']
 fs=js('fsi/RESULT.json');assert fs['returncode']==0
 for p,h in fs['source_sha256'].items():assert sha((ROOT/p).read_bytes())==h,p
 for oracle in fs['oracles']:
  raw=f['fsi/'+oracle['name']]
  if oracle['name']=='fkt15_stubs.f90':raw=f['fsi/original-fkt15_stubs.f90']
  assert hashlib.sha1(b'blob '+str(len(raw)).encode()+b'\0'+raw).hexdigest()==oracle['blob']
 for opt in ['o0','o2']:
  for name in ['task2','surface','dispatch']:assert f['fsi/'+opt+'/'+name+'.txt']==f['fsi/o0/'+name+'.txt']
 all_results=[]
 for batch in js('BATCHES.json'):
  for r in js(batch+'/results.json'):
   all_results.append(dict(batch=batch,**r))
   if r['status']!='PASS':continue
   pre=batch+'/'+r['id']+'/run/';m=js(pre+'manifest.json')
   assert m['status']=='COMPLETE' and next(e for e in m['events']if e['label']=='native')['returncode']==0
   for p,h in m['files'].items():assert sha(f[pre+p])==h
   state=rows(pre+'state.csv');temperature=rows(pre+'temperature.csv');assert len(state)==len(temperature)==112
   assert all(math.isfinite(float(v))for row in state+temperature for v in row.values())
   assert all(0<=float(row['theta'])<=1 for row in state)
   budget=rows(pre+'budget.csv');assert budget
   for row in budget:
    assert all(math.isfinite(float(v))for v in row.values())
    for k in ['max_macro_cell_cm','max_matrix_cm','max_combined_cm','max_net_source_cm']:assert abs(float(row[k]))<=1e-10
   assert abs(float(budget[-1]['t1'])-r['configuration'].get('stop_at_time',r['configuration']['days']))<=1e-9
   assert all(int(row['mass_rejections'])==0 for row in rows(pre+'progress.csv'))
   if r['restart']=='exact':
    for p in ['state.csv','temperature.csv','restart.bin']:assert f[pre+p]==f[batch+'/'+r['id']+'/resumed/'+p]
 light='low-v0p001-r1-e2'
 for p in ['state.csv','temperature.csv']:assert f['cases-O0/'+light+'/run/'+p]==f['cases-O2/'+light+'/run/'+p]
 assert f['cases-O0/'+light+'/run/restart.bin'][72:-4]==f['cases-O2/'+light+'/run/restart.bin'][72:-4]
 old=unpack('integration/dataqual09/CAPSULE.json')
 for name in ['default-two','original-corrected-two']:
  for p in ['state.csv','temperature.csv','budget.csv','progress.csv','cost.csv','diagnostics.csv']:
   assert f['preservation/'+name+'/run/'+p]==old['preservation/'+name+'/run/'+p]
  assert f['preservation/'+name+'/run/restart.bin'][72:-4]==old['preservation/'+name+'/run/restart.bin'][72:-4]
 summary=json.loads((ROOT/'integration/dataqual10/RESULT.json').read_bytes())
 assert len(all_results)==summary['scenario_rows']
 assert sum(r['status']=='PASS'for r in all_results)==summary['water_qualified_rows']
 durations,started=coverage(all_results)
 assert len(started)==summary['started'] and len(durations)==summary['water_qualified']
 assert abs(sum(durations.values())-summary['configuration_days'])<1e-9
 return dict(qualified=True,physical_laws_changed=False,numerical_storage_coupling=True,measured=summary)
def coverage(current):
 def sig(c):
  defaults=dict(mode='experimental',source_surface_demand=False,perched_jacobian=False,solver_max_iterations=64,anchored=True,entry_width_cm=1e-4,transformations=[])
  return json.dumps({k:c.get(k,v)for k,v in defaults.items()},sort_keys=True)
 ns=runpy.run_path(str(ROOT/'integration/audits/verify_dataqual07_current.py'));prior=ns['capsule']()
 durations={};started=set()
 def add(r):
  key=sig(r['configuration'])
  if r.get('status')in ['PASS','CENSORED']or r.get('attempts',0)>0:started.add(key)
  if r.get('status')=='PASS':durations[key]=max(durations.get(key,0),r['completed_days'])
 for r in json.loads(prior['baseline-rows.json'])+json.loads(prior['all-results.json']):add(r)
 old08=runpy.run_path(str(ROOT/'integration/dataqual09/read_dataqual08.py'))['read']()
 for r in json.loads(old08['five/RETAINED.json'])['retained']:
  add(dict(r,status='PASS'))
 old09=unpack('integration/dataqual09/CAPSULE.json')
 cases=json.loads((ROOT/'integration/dataqual09/cases.json').read_bytes())['scenarios']
 for r in json.loads(old09['extensions/RESULT.json']):
  if r['status']=='PASS':add(dict(r,configuration=next(c for c in cases if c['id']==r['id'])))
 assert len(durations)==83 and abs(sum(durations.values())-94.35949999972217)<1e-9
 for r in current:add(r)
 return durations,started
def verify():
 if (ROOT/'integration/dataqual12/STATUS.json').is_file():return __import__('runpy').run_path(str(ROOT/'integration/audits/verify_dataqual12_current.py'))['verify']()
 source();return validate(unpack('integration/dataqual10/CAPSULE.json'))
def fsi35_successors():
 verify()
 deps=json.loads((ROOT/'integration/audits/FCI93_NON_M1_COMPILE_DEPENDENCIES_20261011.json').read_bytes())['dependencies']
 return {d['path']:dict(historical_blob=d['blob'],canonical_blob=git('rev-parse','HEAD:'+d['path']))for d in deps}
def self_test():
 source();s=json.loads((ROOT/STATUS).read_bytes());passed=0
 for p in s['postimages']:
  try:source(lambda q:(ROOT/q).read_bytes()+b' 'if q==p else(ROOT/q).read_bytes())
  except AssertionError:passed+=1;continue
  raise AssertionError('accepted corrupt source '+p)
 return dict(passed=passed)
if __name__=='__main__':print(json.dumps(dict(result=verify(),negative_controls=self_test()),indent=2))
