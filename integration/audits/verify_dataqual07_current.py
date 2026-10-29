"""Bound the experimental stock limiter to executed source and retained water evidence."""
import base64,csv,hashlib,io,json,math,re,subprocess,tarfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];BASE='93d302d8c10850940b33aefd2ffd815f3d63b65a'
STATUS='integration/dataqual07/STATUS.json';SELF='integration/audits/verify_dataqual07_current.py';PARENT='integration/audits/verify_dataqual06_current.py';PERF='integration/performance/authority.py'
sha=lambda b:hashlib.sha256(b).hexdigest()
def git(*args):return subprocess.check_output(['git',*args],cwd=ROOT,text=True).strip()
def parent_projection():
 text=subprocess.check_output(['git','show',BASE+':'+PARENT],cwd=ROOT,text=True)
 for name,args in [('source','reader,changed'),('verify',''),('self_test',''),('fsi35_successors','')]:
  at=re.search(r'^def '+re.escape(name)+r'\(',text,re.M).start();end=text.index('):',at)+2
  if text[end:end+1]!='\n':text=text[:end]+'\n '+text[end:]
  end+=1;text=text[:end]+" if (ROOT/'"+STATUS+"').is_file():return __import__('runpy').run_path(str(ROOT/'"+SELF+"'))['"+name+"']("+args+")\n"+text[end:]
 return text.encode()
def perf_projection():
 raw=subprocess.check_output(['git','show',BASE+':'+PERF],cwd=ROOT)
 hook="    if (ROOT/'"+STATUS+"').is_file():\n        return runpy.run_path(str(ROOT/'"+SELF+"'))['fsi35_successors']()\n"
 return raw.replace(b'def fsi35_successors():\n',b'def fsi35_successors():\n'+hook.encode(),1)
def source(reader=lambda p:(ROOT/p).read_bytes(),changed=None):
 if (ROOT/'integration/dataqual09/STATUS.json').is_file():return __import__('runpy').run_path(str(ROOT/'integration/audits/verify_dataqual09_current.py'))['source'](reader,changed)
 s=json.loads(reader(STATUS));assert s['baseline']==BASE and s['implemented']and s['tested']
 git('merge-base','--is-ancestor',BASE,'HEAD')
 assert not git('diff','HEAD','--','src','app','tools','tests','integration/audits','integration/performance'),'unpersisted science'
 delta={r.split('\t')[1]:r.split('\t')[0]for r in git('diff','--name-status',BASE,'HEAD','--','src','app','tools','tests','examples','reference','.github','integration/audits','integration/performance').splitlines()}
 assert delta==s['scientific_delta'],'foreign scientific delta'
 assert reader(PARENT)==parent_projection(),'parent delegation delta'
 assert reader(PERF)==perf_projection(),'FSI delegation delta'
 for p,h in s['postimages'].items():assert sha(reader(p))==h,p
 return json.loads(reader('integration/audits/MC_SOL01_DYNAMIC_DECAY_STATUS.json'))['swp_water_successor']
def capsule():
 s=json.loads((ROOT/STATUS).read_bytes());raw=base64.b64decode(b''.join((ROOT/p).read_bytes()for p in s['evidence']['parts']),validate=True)
 assert sha(raw)==s['evidence']['sha256']
 with tarfile.open(fileobj=io.BytesIO(raw),mode='r:xz')as t:
  ms=t.getmembers();assert len(ms)==len({m.name for m in ms})
  assert all(m.isfile()and not Path(m.name).is_absolute()and'..'not in Path(m.name).parts for m in ms)
  f={m.name:t.extractfile(m).read()for m in ms}
 assert json.loads(f.pop('MANIFEST.json'))=={p:sha(v)for p,v in f.items()};return f
def validate(f):
 if (ROOT/'integration/dataqual09/STATUS.json').is_file():return __import__('runpy').run_path(str(ROOT/'integration/audits/verify_dataqual09_current.py'))['validate_predecessor'](f)
 js=lambda p:json.loads(f[p]);rows=lambda p:list(csv.DictReader(io.StringIO(f[p].decode())))
 s=json.loads((ROOT/STATUS).read_bytes());r=js('RESULT.json');posts=js('executed-postimages.json');assert posts==s['postimages']
 for p,h in posts.items():assert sha(f['executed/'+p])==h and sha((ROOT/p).read_bytes())==h,p
 for opt in ['O0','O2']:
  assert f['contract/'+opt+'/result'].startswith(b' DATAQUAL07_STORAGE_BOUNDS_PASS        1919')
  b=js('build/'+opt+'/bundle.json')
  assert sha(f['recovery/native-'+opt])==b['executable_sha256'][b['exe']]
  for p,h in b['physical_build']['input_sha256'].items():assert sha((ROOT/p).read_bytes())==h,p
 assert f['contract/O0/result']==f['contract/O2/result']
 aggregate=[dict(batch=b,**x)for b in r['batches']for x in js(b+'/results.json')]
 assert aggregate==js('all-results.json')and len(aggregate)==r['scenario_executions']
 assert sum(x['status']=='PASS'for x in aggregate)==r['water_qualified_executions']
 for x in aggregate:
  pre=x['batch']+'/'+x['id']+'/run/'
  if 'input_sha256'in x:
   for p,h in x['input_sha256'].items():assert sha(f[x['batch']+'/'+x['id']+'/inputs/'+p])==h
  if x['status']!='PASS':continue
  m=js(pre+'manifest.json');assert m['status']=='COMPLETE'
  assert next(e for e in m['events']if e['label']=='native')['returncode']==0
  for p,h in m['files'].items():assert sha(f[pre+p])==h
  st=rows(pre+'state.csv');tt=rows(pre+'temperature.csv');assert len(st)==len(tt)==112
  assert all(math.isfinite(float(v))for row in st+tt for v in row.values())
  assert all(0<=float(row['theta'])<=1 for row in st)
  budget=rows(pre+'budget.csv');progress=rows(pre+'progress.csv');assert budget and progress
  assert abs(float(budget[-1]['t1'])-x['configuration'].get('stop_at_time',x['configuration']['days']))<=1e-9
  assert all(int(row['mass_rejections'])==0 for row in progress)
  for row in budget:
   assert all(math.isfinite(float(v))for v in row.values())
   for k in ['max_macro_cell_cm','max_matrix_cm','max_combined_cm','max_net_source_cm']:assert abs(float(row[k]))<=1e-10
  if x['restart']=='exact':
   for p in ['state.csv','temperature.csv','restart.bin']:assert f[pre+p]==f[x['batch']+'/'+x['id']+'/resumed/'+p]
 for name in ['low-v0p001-r1-e2','low-v0p0005-r4-e0p5']:
  for p in ['state.csv','temperature.csv']:assert f['restarts-O0/'+name+'/run/'+p]==f['restarts-O2/'+name+'/run/'+p]
  assert f['restarts-O0/'+name+'/run/restart.bin'][72:-4]==f['restarts-O2/'+name+'/run/restart.bin'][72:-4]
 for name in ['default-two','original-corrected-two']:
  for p in ['state.csv','temperature.csv','budget.csv','progress.csv','cost.csv','diagnostics.csv']:
   assert f['preservation/'+name+'/run/'+p]==f['baseline/'+name+'/'+p]
  assert f['preservation/'+name+'/run/restart.bin'][72:-4]==f['baseline/'+name+'/restart.bin'][72:-4]
 assert f['integral/original-stock-2p748/run/restart.bin']==f['integral/original-stock-five/run/diagnostic-rejected.bin']
 assert js('controls/RESULT.json')['passed']==5
 fs=js('baseline-fsi35-RESULT.json');deps=json.loads((ROOT/'integration/audits/FCI93_NON_M1_COMPILE_DEPENDENCIES_20261011.json').read_bytes())['dependencies']
 assert fs['returncode']==0 and fs['source']=={d['path']:sha((ROOT/d['path']).read_bytes())for d in deps}
 assert b'FCI93_FIXED_K_NATIVE_IMMUTABLE_ORACLE_O0_O2=PASS'in f['baseline-fsi35-stdout']
 # Recalculate the physical configuration denominator, excluding only the new numerical policy.
 def sig(x):
  c=x['configuration'];defaults=dict(mode='experimental',source_surface_demand=False,perched_jacobian=False,solver_max_iterations=64,anchored=True,entry_width_cm=1e-4,transformations=[])
  return json.dumps({k:c.get(k,v)for k,v in defaults.items()},sort_keys=True)
 old=js('baseline-rows.json');before={};after={}
 for x in old:
  if x['status']=='PASS':before[sig(x)]=max(before.get(sig(x),0),x['completed_days'])
 after=dict(before)
 for x in aggregate:
  if x['status']=='PASS':after[sig(x)]=max(after.get(sig(x),0),x['completed_days'])
 assert len(before)==77 and len(after)==r['combined_water_qualified']
 assert len(set(after)-set(before))==r['extra_water_qualified_configurations']
 assert abs(sum(after.values())-r['combined_deduplicated_configuration_days'])<1e-9
 return dict(dataqual07_tested=True,qualified=True,production_admission_changed=False,full_historical_closure=False,measured=r)
def verify():
 if (ROOT/'integration/dataqual09/STATUS.json').is_file():return __import__('runpy').run_path(str(ROOT/'integration/audits/verify_dataqual09_current.py'))['verify']()
 source();return validate(capsule())
def fsi35_successors():
 if (ROOT/'integration/dataqual09/STATUS.json').is_file():return __import__('runpy').run_path(str(ROOT/'integration/audits/verify_dataqual09_current.py'))['fsi35_successors']()
 source();validate(capsule())
 deps=json.loads((ROOT/'integration/audits/FCI93_NON_M1_COMPILE_DEPENDENCIES_20261011.json').read_bytes())['dependencies']
 return {d['path']:dict(historical_blob=d['blob'],canonical_blob=git('rev-parse','HEAD:'+d['path']))for d in deps}
def self_test():
 if (ROOT/'integration/dataqual09/STATUS.json').is_file():return __import__('runpy').run_path(str(ROOT/'integration/audits/verify_dataqual09_current.py'))['self_test']()
 source();f=capsule();validate(f);passed=[]
 def reject(label,fn):
  try:fn()
  except(AssertionError,KeyError,ValueError,TypeError,UnicodeError):passed.append(label);return
  raise AssertionError('accepted corrupt evidence '+label)
 s=json.loads((ROOT/STATUS).read_bytes())
 for p in s['postimages']:reject('source:'+p,lambda p=p:source(lambda q:(ROOT/q).read_bytes()+b' 'if q==p else(ROOT/q).read_bytes()))
 for p in ['RESULT.json','all-results.json','controls/RESULT.json','executed-postimages.json','baseline-fsi35-RESULT.json']:
  altered=dict(f);altered[p]=b'{}';reject('evidence:'+p,lambda altered=altered:validate(altered))
 return dict(passed=len(passed),controls=passed)
if __name__=='__main__':print(json.dumps(dict(result=verify(),negative_controls=self_test(),fsi35=fsi35_successors()),indent=2))
