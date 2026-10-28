"""Source-bound nonlinear runoff, isolated batches and actual preservation evidence."""
import base64,collections,csv,hashlib,io,json,math,subprocess,tarfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];BASE='5a0b0fcd4461d651c141919da09a8ddcb9ff25e2'
STATUS='integration/dataqual05/STATUS.json';SELF='integration/audits/verify_dataqual05_current.py';PARENT='integration/audits/verify_dataqual04_current.py';PERF='integration/performance/authority.py'
sha=lambda b:hashlib.sha256(b).hexdigest()
def git(*args):return subprocess.check_output(['git',*args],cwd=ROOT,text=True).strip()
def parent_projection():
 text=subprocess.check_output(['git','show',BASE+':'+PARENT],cwd=ROOT,text=True)
 for name,args in [('source','reader,changed'),('verify',''),('self_test',''),('fsi35_successors','')]:
  at=text.index('def '+name+'(');end=text.index('):',at)+2
  if text[end:end+1]!='\n':text=text[:end]+'\n '+text[end:]
  end+=1;text=text[:end]+" if (ROOT/'"+STATUS+"').is_file():return __import__('runpy').run_path(str(ROOT/'"+SELF+"'))['"+name+"']("+args+")\n"+text[end:]
 return text.encode()
def perf_projection():
 raw=subprocess.check_output(['git','show',BASE+':'+PERF],cwd=ROOT)
 hook="    if (ROOT/'"+STATUS+"').is_file():\n        return runpy.run_path(str(ROOT/'"+SELF+"'))['fsi35_successors']()\n"
 return raw.replace(b'def fsi35_successors():\n',b'def fsi35_successors():\n'+hook.encode(),1)
def source(reader=lambda p:(ROOT/p).read_bytes(),changed=None):
 s=json.loads(reader(STATUS));assert s['baseline']==BASE and s['implemented']and s['tested']
 git('merge-base','--is-ancestor',BASE,'HEAD')
 assert not git('diff','HEAD','--','src','app','tools','tests','integration/audits','integration/performance'),'unpersisted science'
 delta={r.split('\t')[1]:r.split('\t')[0]for r in git('diff','--name-status',BASE,'HEAD','--','src','app','tools','tests','examples','reference','.github','integration/audits','integration/performance').splitlines()}
 assert delta==s['scientific_delta'],'foreign scientific delta'
 assert {p for p in delta if p.startswith('src/')}==set(s['core_changes'])
 assert reader(PARENT)==parent_projection(),'predecessor assertions changed'
 assert reader(PERF)==perf_projection(),'registry changed beyond explicit successor'
 for p,h in s['postimages'].items():assert sha(reader(p))==h,p
 if changed is not None:
  for p in changed:assert p in delta or subprocess.run(['git','cat-file','-e',BASE+':'+p],cwd=ROOT,capture_output=True).returncode==0,p
 return json.loads(reader('integration/audits/MC_SOL01_DYNAMIC_DECAY_STATUS.json'))['swp_water_successor']
def capsule():
 s=json.loads((ROOT/STATUS).read_bytes());raw=base64.b64decode(b''.join((ROOT/p).read_bytes()for p in s['evidence']['parts']),validate=True);assert sha(raw)==s['evidence']['sha256']
 with tarfile.open(fileobj=io.BytesIO(raw),mode='r:xz')as t:
  ms=t.getmembers();assert all(m.isfile()and not Path(m.name).is_absolute()and'..'not in Path(m.name).parts for m in ms)
  assert len(ms)==len({m.name for m in ms});f={m.name:t.extractfile(m).read()for m in ms}
 assert json.loads(f.pop('MANIFEST.json'))=={p:sha(v)for p,v in f.items()};return f
def validate(f):
 js=lambda p:json.loads(f[p]);rows=lambda p:list(csv.DictReader(io.StringIO(f[p].decode())))
 r=js('FINAL_RESULT.json');assert r['physical_completions']>0 and r['distinct_configurations']>=64
 posts=js('executed-postimages.json');assert posts==json.loads((ROOT/STATUS).read_bytes())['postimages']and posts,'missing/foreign source inventory'
 for p,h in posts.items():assert sha(f['executed/'+p])==h and sha((ROOT/p).read_bytes())==h,p
 design=js('executed/integration/dataqual05/design-v2.json')
 assert design['unique_factor_rows']==64 and design['covered_level_pairs']==264
 corrected=js('wet-window64-v2-O2/results.json');assert len(corrected)==64
 assert len({json.dumps(x['configuration']['factors'],sort_keys=True)for x in corrected})==64
 assert len({json.dumps(x['input_sha256'],sort_keys=True)for x in corrected})==64
 contract=js('contract/RESULT.json');assert len(contract)==2 and all(x['linear_predecessor_exact']and x['providers']==4 for x in contract)
 for opt in ['O0','O2']:
  assert f['contract/'+opt+'/stdout'].startswith(b'POWER_RUNOFF_PASS 360')
  assert f['contract/'+opt+'/linear.stdout']==f['contract/'+opt+'/previous.stdout']
 assert f['contract/O0/stdout']==f['contract/O2/stdout']
 aggregate=[dict(batch=batch,**x)for batch in r['batches']for x in js(batch+'/results.json')]
 assert len(aggregate)==r['scenario_executions']
 assert sum(x['status']=='PASS'for x in aggregate)==r['physical_completions']
 assert dict(collections.Counter(x['qualification_category']for x in aggregate))==r['categories']
 assert len(js('native-events.json'))==r['native_process_executions_including_restarts']
 for x in aggregate:
  for name,h in x['input_sha256'].items():assert sha(f[x['batch']+'/'+x['id']+'/inputs/'+name])==h
 for batch in r['batches']:
  results=js(batch+'/results.json')
  for x in results:
   prefix=batch+'/'+x['id']+'/run/'
   if x['status']=='PASS':
    assert x['qualification_category']=='successful_water_qualified'and x['physical_complete']
    assert x['water_max_independent_cm']<=1e-10 and x['mass_rejections']==0
    manifest=js(prefix+'manifest.json');assert manifest['status']=='COMPLETE'
    assert next(e for e in manifest['events']if e['label']=='native')['returncode']==0
    for name,h in manifest['files'].items():assert sha(f[prefix+name])==h,name
    state=rows(prefix+'state.csv');temperature=rows(prefix+'temperature.csv');assert len(state)==len(temperature)==112
    assert all(math.isfinite(float(v))for row in state+temperature for v in row.values())
    assert all(0<=float(x['theta'])<=1 for x in state)
    for row in rows(prefix+'budget.csv'):
     assert all(math.isfinite(float(v))for v in row.values())
     for k in ['max_macro_cell_cm','max_matrix_cm','max_combined_cm','max_net_source_cm']:assert abs(float(row[k]))<=1e-10
    if x['restart']=='exact':
     for name in ['state.csv','temperature.csv','restart.bin']:assert f[prefix+name]==f[batch+'/'+x['id']+'/resumed/'+name]
   elif x['status']=='CENSORED':assert x['qualification_category']=='budget_exceeded'and not x['physical_complete']
 for name in ['oa64-00','oa64-08','default-two','original-corrected-two']:
  for path in ['state.csv','temperature.csv']:assert f['qualification-O0/'+name+'/run/'+path]==f['qualification-O2/'+name+'/run/'+path]
  assert f['qualification-O0/'+name+'/run/restart.bin'][72:-4]==f['qualification-O2/'+name+'/run/restart.bin'][72:-4]
 for name in ['cap-storm-e0p5-r4p0','cap-storm-e2p0-r4p0']:
  for path in ['state.csv','temperature.csv']:assert f['capped-qualification-O0/'+name+'/run/'+path]==f['capped-storms-O2/'+name+'/run/'+path]
  assert f['capped-qualification-O0/'+name+'/run/restart.bin'][72:-4]==f['capped-storms-O2/'+name+'/run/restart.bin'][72:-4]
 for name in ['oa64-00','oa64-08']:
  for path in ['state.csv','temperature.csv','budget.csv','progress.csv','cost.csv','diagnostics.csv','restart.bin']:
   assert f['serial-check-O2/'+name+'/run/'+path]==f['qualification-O2/'+name+'/run/'+path]
 for path in ['state.csv','temperature.csv','budget.csv','progress.csv','cost.csv','diagnostics.csv']:
  assert f['qualification-O2/default-two/run/'+path]==f['parent/default-two/'+path]
 assert js('controls/RESULT.json')['passed']>=6
 fsi=js('fsi35/RESULT.json');assert fsi['returncode']==0 and fsi['unchanged_dependencies']==26
 assert b'FCI93_FIXED_K_NATIVE_IMMUTABLE_ORACLE_O0_O2=PASS'in f['fsi35/stdout']
 return dict(dataqual05_tested=True,qualified=True,production_admission_changed=False,full_historical_closure=False,measured=r)
def verify():source();return validate(capsule())
def fsi35_successors():
 source();f=capsule();validate(f)
 deps=json.loads((ROOT/'integration/audits/FCI93_NON_M1_COMPILE_DEPENDENCIES_20261011.json').read_bytes())['dependencies']
 changed=[d['path']for d in deps if git('rev-parse','HEAD:'+d['path'])!=git('rev-parse',BASE+':'+d['path'])]
 assert changed==['src/solver/mod_b110_dynamic_top_boundary_provider.f90']
 assert json.loads(f['fsi35/RESULT.json'])['source']=={d['path']:sha((ROOT/d['path']).read_bytes())for d in deps}
 return {d['path']:dict(historical_blob=d['blob'],canonical_blob=git('rev-parse','HEAD:'+d['path']))for d in deps}
def self_test():
 source();f=capsule();validate(f);passed=[]
 def reject(label,fn):
  try:fn()
  except(AssertionError,KeyError,ValueError,TypeError,UnicodeError):passed.append(label);return
  raise AssertionError('accepted corrupt runoff proof '+label)
 s=json.loads((ROOT/STATUS).read_bytes())
 for p in s['postimages']:
  reject('source:'+p,lambda p=p:source(lambda q:(ROOT/q).read_bytes()+b' 'if q==p else(ROOT/q).read_bytes()))
 for p in ['FINAL_RESULT.json','contract/RESULT.json','fsi35/RESULT.json','controls/RESULT.json','executed-postimages.json']:
  altered=dict(f);altered[p]=b'{}';reject('evidence:'+p,lambda altered=altered:validate(altered))
 altered=dict(f);report=json.loads(altered['FINAL_RESULT.json']);report['physical_completions']+=1;altered['FINAL_RESULT.json']=json.dumps(report).encode();reject('inflated-completion-count',lambda:validate(altered))
 altered=dict(f);result=json.loads(altered['wet-window64-v2-O2/results.json']);result[-1]['input_sha256']=result[0]['input_sha256'];altered['wet-window64-v2-O2/results.json']=json.dumps(result).encode();reject('repeated-input-labelled-unique',lambda:validate(altered))
 for name in ['oa64-00','oa64-08','default-two','original-corrected-two']:
  p='qualification-O2/'+name+'/run/restart.bin';altered=dict(f);altered[p]=altered[p][:-1]+bytes([altered[p][-1]^1]);reject('restart:'+name,lambda altered=altered:validate(altered))
 return dict(passed=len(passed),controls=passed)
if __name__=='__main__':print(json.dumps(dict(result=verify(),negative_controls=self_test(),fsi35=fsi35_successors()),indent=2))
