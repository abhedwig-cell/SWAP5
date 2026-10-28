"""Source-bound candidate macropore conductivity and real model qualification."""
import base64,collections,csv,hashlib,io,json,math,re,runpy,subprocess,tarfile,tempfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];BASE='cba2117d679fe1165cc03c60e86e67943a777466'
STATUS='integration/dataqual06/STATUS.json';SELF='integration/audits/verify_dataqual06_current.py';PARENT='integration/audits/verify_dataqual05_current.py'
sha=lambda b:hashlib.sha256(b).hexdigest()
def git(*a):return subprocess.check_output(['git',*a],cwd=ROOT,text=True).strip()
def parent_projection():
 raw=subprocess.check_output(['git','show',BASE+':'+PARENT],cwd=ROOT).decode()
 for name,args in [('source','reader,changed'),('verify',''),('self_test',''),('fsi35_successors','')]:
  at=re.search(r'^def '+name+r'\(',raw,re.M).start();end=raw.index('):',at)+2
  if raw[end:end+1]!='\n':raw=raw[:end]+'\n '+raw[end:]
  end+=1;raw=raw[:end]+" if (ROOT/'"+STATUS+"').is_file():return __import__('runpy').run_path(str(ROOT/'"+SELF+"'))['"+name+"']("+args+")\n"+raw[end:]
 return raw.encode()
def source(reader=lambda p:(ROOT/p).read_bytes(),changed=None):
 s=json.loads(reader(STATUS));assert s['baseline']==BASE and s['implemented']and s['tested']
 git('merge-base','--is-ancestor',BASE,'HEAD')
 assert not git('diff','HEAD','--','src','app','tools','tests','integration/audits','integration/performance'),'unpersisted science'
 delta={r.split('\t')[1]:r.split('\t')[0]for r in git('diff','--name-status',BASE,'HEAD','--','src','app','tools','tests','examples','reference','.github','integration/audits','integration/performance').splitlines()}
 assert delta==s['scientific_delta'],'foreign scientific delta'
 assert reader(PARENT)==parent_projection(),'predecessor assertions modified'
 assert set(s['postimages'])==set(delta)|set(s['auxiliary_sources']),'source inventory'
 for p,h in s['postimages'].items():assert sha(reader(p))==h,p
 # Unchanged DATAQUAL05 dependency proofs remain bound to their original bytes.
 old=json.loads(reader('integration/dataqual05/STATUS.json'))
 for p,h in old['postimages'].items():
  if p not in delta:assert sha(reader(p))==h,p
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
 report=js('FINAL_RESULT.json');posts=js('executed-postimages.json')
 assert posts and posts==json.loads((ROOT/STATUS).read_bytes())['postimages']
 for p,h in posts.items():assert sha(f['executed/'+p])==h and sha((ROOT/p).read_bytes())==h,p
 contract=js('contract/RESULT.json');assert len(contract)==2
 for opt in ['O0','O2']:
  assert f['contract/'+opt+'/stdout'].startswith(b'SURFACE_CONDUCTIVITY_PASS 162 NEGATIVE 4')
  assert f['contract/'+opt+'/linear.stdout']==f['contract/'+opt+'/previous.stdout']
 assert f['contract/O0/stdout']==f['contract/O2/stdout']
 aggregate=[dict(batch=b,**x)for b in report['batches']for x in js(b+'/results.json')]
 assert len(aggregate)==report['scenario_executions']
 assert dict(collections.Counter(x['qualification_category']for x in aggregate))==report['categories']
 assert sum(x['status']=='PASS'for x in aggregate)==report['water_qualified_executions']
 assert len({x['configuration_sha256']for x in aggregate})==report['distinct_configurations']
 assert len({x['configuration_sha256']for x in aggregate if x['status']=='PASS'})==report['distinct_water_qualified_configurations']
 assert len(js('native-events.json'))==report['native_process_executions_including_restarts']
 wet=js('dq06-wet32-O2/results.json');assert len(wet)==32 and len({json.dumps(x['input_sha256'],sort_keys=True)for x in wet})==32
 for x in aggregate:
  pre=x['batch']+'/'+x['id']+'/run/'
  for p,h in x['input_sha256'].items():assert sha(f[x['batch']+'/'+x['id']+'/inputs/'+p])==h
  m=js(pre+'manifest.json');assert m['memory_limit_mib']==1024
  for p,h in m['files'].items():assert sha(f[pre+p])==h,(pre,p)
  if x['status']=='PASS':
   assert x['qualification_category']=='successful_water_qualified'and x['physical_complete']and x['execution_complete']
   assert m['status']=='COMPLETE'and next(e for e in m['events']if e['label']=='native')['returncode']==0
   assert x['mass_rejections']==0 and x['water_max_independent_cm']<=1e-10
   state=rows(pre+'state.csv');temp=rows(pre+'temperature.csv');assert len(state)==len(temp)==112
   assert all(math.isfinite(float(v))for row in state+temp for v in row.values())
   assert all(0<=float(z['theta'])<=1 for z in state)
   for row in rows(pre+'budget.csv'):
    assert all(math.isfinite(float(v))for v in row.values())
    for k in ['max_macro_cell_cm','max_matrix_cm','max_combined_cm','max_net_source_cm']:assert abs(float(row[k]))<=1e-10
   assert abs(float(rows(pre+'budget.csv')[-1]['t1'])-x['configuration'].get('stop_at_time',x['configuration']['days']))<=1e-10
   if x['restart']=='exact':
    for p in ['state.csv','temperature.csv','restart.bin']:assert f[pre+p]==f[x['batch']+'/'+x['id']+'/resumed/'+p]
  elif x['status']=='CENSORED':assert x['qualification_category']=='budget_exceeded'and not x['physical_complete']
 for name in ['default-two','original-corrected-two','low-oa64v2-00','low-oa64v2-08']:
  a='dq06-qualification-O0/'+name+'/run/';b='dq06-qualification-O2/'+name+'/run/'
  for p in ['state.csv','temperature.csv']:assert f[a+p]==f[b+p],(name,p)
  assert f[a+'restart.bin'][72:-4]==f[b+'restart.bin'][72:-4],name
 for name in ['default-two','original-corrected-two']:
  for opt in ['O0','O2']:
   a='dq06-qualification-'+opt+'/'+name+'/run/';b='parent/'+name+'/'
   for p in ['state.csv','temperature.csv','budget.csv','progress.csv','cost.csv','diagnostics.csv']:assert f[a+p]==f[b+p],(name,opt,p)
   assert f[a+'restart.bin'][72:-4]==f[b+'restart.bin'][72:-4]
 assert js('controls/RESULT.json')['passed']==6
 fs=js('fsi35/RESULT.json');assert fs['returncode']==0 and fs['unchanged_dependencies']==26
 assert fs['source']=={p:sha((ROOT/p).read_bytes())for p in fs['source']}
 assert b'FCI93_FIXED_K_NATIVE_IMMUTABLE_ORACLE_O0_O2=PASS'in f['fsi35/stdout']
 return dict(dataqual06_tested=True,qualified=True,production_admission_changed=False,full_historical_closure=False,measured=report)
def inherited():
 # Replay the literal predecessor raw assertions against its executed source
 # projection, never claim old changed-dependency proof as current qualification.
 old=runpy.run_path(str(ROOT/PARENT));oldsource=old['source'].__globals__
 oldfiles=old['capsule']()
 with tempfile.TemporaryDirectory()as folder:
  q=Path(folder)
  for p in json.loads(oldfiles['executed-postimages.json']):
   out=q/p;out.parent.mkdir(parents=True,exist_ok=True);out.write_bytes(oldfiles['executed/'+p])
  p=q/'integration/dataqual05/STATUS.json';p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes((ROOT/'integration/dataqual05/STATUS.json').read_bytes())
  oldsource['ROOT']=q
  result=old['validate'](oldfiles)
 assert result['qualified'];return dict(dataqual05_raw_qualified=True,scope='literal predecessor executed source projection; changed dependencies requalified by DATAQUAL06')
def verify():source();r=validate(capsule());r['inherited']=inherited();return r
def fsi35_successors():
 source();f=capsule();validate(f)
 deps=json.loads((ROOT/'integration/audits/FCI93_NON_M1_COMPILE_DEPENDENCIES_20261011.json').read_bytes())['dependencies']
 changed=[d['path']for d in deps if git('rev-parse','HEAD:'+d['path'])!=git('rev-parse',BASE+':'+d['path'])]
 assert changed==['src/adapter/mod_b110_dynamic_top_boundary_solver_adapter.f90']
 return {d['path']:dict(historical_blob=d['blob'],canonical_blob=git('rev-parse','HEAD:'+d['path']))for d in deps}
def self_test():
 source();f=capsule();validate(f);passed=[]
 def reject(label,fn):
  try:fn()
  except(AssertionError,KeyError,ValueError,TypeError,UnicodeError):passed.append(label);return
  raise AssertionError('accepted corrupt conductivity proof '+label)
 s=json.loads((ROOT/STATUS).read_bytes())
 for p in s['postimages']:reject('source:'+p,lambda p=p:source(lambda q:(ROOT/q).read_bytes()+b' 'if q==p else(ROOT/q).read_bytes()))
 for p in ['FINAL_RESULT.json','contract/RESULT.json','controls/RESULT.json','fsi35/RESULT.json','executed-postimages.json']:
  bad=dict(f);bad[p]=b'{}';reject('raw:'+p,lambda bad=bad:validate(bad))
 bad=dict(f);r=json.loads(bad['FINAL_RESULT.json']);r['water_qualified_executions']+=1;bad['FINAL_RESULT.json']=json.dumps(r).encode();reject('inflated-count',lambda:validate(bad))
 bad=dict(f);p='dq06-qualification-O2/low-oa64v2-00/run/restart.bin';bad[p]=bad[p][:-1]+bytes([bad[p][-1]^1]);reject('restart-crc',lambda:validate(bad))
 return dict(passed=len(passed),controls=passed)
if __name__=='__main__':print(json.dumps(dict(result=verify(),negative_controls=self_test(),fsi35=fsi35_successors()),indent=2))
