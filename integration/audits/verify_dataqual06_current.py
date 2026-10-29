"""Bounded variable-surface source, real native water evidence and preservation."""
import base64,csv,hashlib,io,json,math,re,subprocess,tarfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];BASE='cba2117d679fe1165cc03c60e86e67943a777466'
STATUS='integration/dataqual06/STATUS.json';SELF='integration/audits/verify_dataqual06_current.py';PARENT='integration/audits/verify_dataqual05_current.py';PERF='integration/performance/authority.py'
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
 if (ROOT/'integration/dataqual07/STATUS.json').is_file():return __import__('runpy').run_path(str(ROOT/'integration/audits/verify_dataqual07_current.py'))['source'](reader,changed)
 s=json.loads(reader(STATUS));assert s['baseline']==BASE and s['implemented']and s['tested']
 git('merge-base','--is-ancestor',BASE,'HEAD')
 assert not git('diff','HEAD','--','src','app','tools','tests','integration/audits','integration/performance'),'unpersisted science'
 delta={r.split('\t')[1]:r.split('\t')[0]for r in git('diff','--name-status',BASE,'HEAD','--','src','app','tools','tests','examples','reference','.github','integration/audits','integration/performance').splitlines()}
 assert delta==s['scientific_delta'],'foreign scientific delta'
 compile(reader(PARENT).decode(),PARENT,'exec')
 compile(reader(PERF).decode(),PERF,'exec')
 assert reader(PARENT)==parent_projection(),'parent authority changed beyond explicit delegation'
 assert reader(PERF)==perf_projection(),'FSI authority changed beyond explicit delegation'
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
 js=lambda p:json.loads(f[p]);rows=lambda p:list(csv.DictReader(io.StringIO(f[p].decode())))
 r=js('RESULT.json');s=json.loads((ROOT/STATUS).read_bytes());posts=js('executed-postimages.json');assert posts==s['postimages']
 for p,h in posts.items():assert sha(f['executed/'+p])==h and sha((ROOT/p).read_bytes())==h,p
 contract=js('contract/RESULT.json');assert len(contract)==2
 for opt in ['O0','O2']:assert f['contract/'+opt+'/stdout'].startswith(b'SURFACE_CONDUCTIVITY_PASS 945')
 assert f['contract/O0/stdout']==f['contract/O2/stdout']
 aggregate=[dict(batch=b,**x)for b in r['batches']for x in js(b+'/results.json')]
 assert len(aggregate)==r['scenario_executions']
 assert sum(x['status']=='PASS'for x in aggregate)==r['water_qualified_executions']
 for x in aggregate:
  pre=x['batch']+'/'+x['id']+'/run/'
  for name,h in x['input_sha256'].items():assert sha(f[x['batch']+'/'+x['id']+'/inputs/'+name])==h
  if x['status']!='PASS':continue
  assert x['physical_complete']and x['mass_rejections']==0 and x['water_max_independent_cm']<=1e-10
  m=js(pre+'manifest.json');assert m['status']=='COMPLETE'
  assert next(e for e in m['events']if e['label']=='native')['returncode']==0
  for name,h in m['files'].items():assert sha(f[pre+name])==h
  st=rows(pre+'state.csv');tt=rows(pre+'temperature.csv');assert len(st)==len(tt)==112
  assert all(math.isfinite(float(v))for row in st+tt for v in row.values())
  assert all(0<=float(row['theta'])<=1 for row in st)
  for row in rows(pre+'budget.csv'):
   for k in ['max_macro_cell_cm','max_matrix_cm','max_combined_cm','max_net_source_cm']:assert abs(float(row[k]))<=1e-10
  if x['restart']=='exact':
   for name in ['state.csv','temperature.csv','restart.bin']:assert f[pre+name]==f[x['batch']+'/'+x['id']+'/resumed/'+name]
 compose=js('compose32-O2/results.json');assert len(compose)==32 and len({json.dumps(x['input_sha256'],sort_keys=True)for x in compose})==32
 for name in ['low-v0p0005-r1-e0p5','low-v0p001-r1-e2']:
  for p in ['state.csv','temperature.csv']:assert f['restarts-O0/'+name+'/run/'+p]==f['restarts-O2/'+name+'/run/'+p]
  assert f['restarts-O0/'+name+'/run/restart.bin'][72:-4]==f['restarts-O2/'+name+'/run/restart.bin'][72:-4]
 for name in ['default-two','original-corrected-two']:
  for p in ['state.csv','temperature.csv','budget.csv','progress.csv','cost.csv','diagnostics.csv']:
   assert f['preservation-O2/'+name+'/run/'+p]==f['baseline/'+name+'/'+p]
  assert f['preservation-O2/'+name+'/run/restart.bin'][72:-4]==f['baseline/'+name+'/restart.bin'][72:-4]
 for batch,name in [('uncapped-O0','uncapped-low-v0p0005-r1-e2'),('uncapped-wet-O0','uncapped-low-v0p0005-r4-e0p5')]:
  for p in ['state.csv','temperature.csv']:assert f[batch+'/'+name+'/run/'+p]==f['uncapped8-O2/'+name+'/run/'+p]
  assert f[batch+'/'+name+'/run/restart.bin'][72:-4]==f['uncapped8-O2/'+name+'/run/restart.bin'][72:-4]
 wet=next(x for x in aggregate if x['batch']=='uncapped-wet-O0');assert wet['status']=='PASS'and wet['flux_totals_cm']['pond_to_macro_cm']>0.02
 for x in aggregate:
  if x['batch'].startswith('uncapped')and x['status']=='PASS':
   text=f[x['batch']+'/'+x['id']+'/run/macro.nml'].decode()
   k=float(re.search(r'source_surface_conductivity=\s*(\S+)',text)[1]);assert 0<k<1000
 assert js('controls/RESULT.json')['passed']==8
 fs=js('fsi35/RESULT.json');assert fs['returncode']==0 and fs['unchanged_dependencies']==25
 assert b'FCI93_FIXED_K_NATIVE_IMMUTABLE_ORACLE_O0_O2=PASS'in f['fsi35/stdout']
 ref=js('reference/RESULT.json');assert ref['reference']['source_tree']['manifest_sha256']=='5bab54598c3519c1b1f2f313431ba0947f39c9673eb1fbc7eec719477f9f2d0e'
 assert len(ref['cases'])==3 and all(x['complete']and x['returncode']==100 for x in ref['cases'])
 return dict(dataqual06_tested=True,qualified=True,production_admission_changed=False,full_historical_closure=False,measured=r)
def verify():
 if (ROOT/'integration/dataqual07/STATUS.json').is_file():return __import__('runpy').run_path(str(ROOT/'integration/audits/verify_dataqual07_current.py'))['verify']()
 source();return validate(capsule())
def fsi35_successors():
 if (ROOT/'integration/dataqual07/STATUS.json').is_file():return __import__('runpy').run_path(str(ROOT/'integration/audits/verify_dataqual07_current.py'))['fsi35_successors']()
 source();f=capsule();validate(f)
 deps=json.loads((ROOT/'integration/audits/FCI93_NON_M1_COMPILE_DEPENDENCIES_20261011.json').read_bytes())['dependencies']
 assert json.loads(f['fsi35/RESULT.json'])['source']=={d['path']:sha((ROOT/d['path']).read_bytes())for d in deps}
 return {d['path']:dict(historical_blob=d['blob'],canonical_blob=git('rev-parse','HEAD:'+d['path']))for d in deps}
def self_test():
 if (ROOT/'integration/dataqual07/STATUS.json').is_file():return __import__('runpy').run_path(str(ROOT/'integration/audits/verify_dataqual07_current.py'))['self_test']()
 source();f=capsule();validate(f);passed=[]
 def reject(label,fn):
  try:fn()
  except(AssertionError,KeyError,ValueError,TypeError,UnicodeError):passed.append(label);return
  raise AssertionError('accepted corrupt evidence '+label)
 s=json.loads((ROOT/STATUS).read_bytes())
 for p in s['postimages']:reject('source:'+p,lambda p=p:source(lambda q:(ROOT/q).read_bytes()+b' 'if q==p else(ROOT/q).read_bytes()))
 for p in ['RESULT.json','contract/RESULT.json','fsi35/RESULT.json','controls/RESULT.json','executed-postimages.json']:
  altered=dict(f);altered[p]=b'{}';reject('evidence:'+p,lambda altered=altered:validate(altered))
 return dict(passed=len(passed),controls=passed)
if __name__=='__main__':print(json.dumps(dict(result=verify(),negative_controls=self_test(),fsi35=fsi35_successors()),indent=2))
