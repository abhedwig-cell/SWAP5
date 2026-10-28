"""Perched diagonal numerical-policy successor; no production promotion."""
import base64,csv,hashlib,io,json,math,subprocess,tarfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];BASE='4b61966e63bcb20d0688c919687a798147226114'
PARENT='integration/audits/verify_dataqual02_current.py';SELF='integration/audits/verify_dataqual03_current.py';STATUS='integration/dataqual03/STATUS.json'
sha=lambda b:hashlib.sha256(b).hexdigest()
def git(*args):return subprocess.check_output(['git',*args],cwd=ROOT,text=True).strip()
def projection():
 text=subprocess.check_output(['git','show',BASE+':'+PARENT],cwd=ROOT,text=True)
 for name,args in [('source','reader,changed'),('verify',''),('self_test',''),('fsi35_successors','')]:
  at=text.index('def '+name+'(');end=text.index('):',at)+2
  if text[end:end+1]!='\n':text=text[:end]+'\n '+text[end:]
  end+=1;text=text[:end]+" if (ROOT/'"+STATUS+"').is_file():return __import__('runpy').run_path(str(ROOT/'"+SELF+"'))['"+name+"']("+args+")\n"+text[end:]
 return text.encode()
def source(reader=lambda p:(ROOT/p).read_bytes(),changed=None):
 s=json.loads(reader(STATUS));assert s['baseline']==BASE and s['tested'];git('merge-base','--is-ancestor',BASE,'HEAD')
 assert not git('diff','HEAD','--','src','app','tools','tests','integration/audits'),'unpersisted source'
 delta={r.split('\t')[1]:r.split('\t')[0]for r in git('diff','--name-status',BASE,'HEAD','--','src','app','tools','tests','examples','reference','.github','integration/audits').splitlines()}
 assert delta==s['scientific_delta'],'foreign surface-demand delta'
 assert {p for p in delta if p.startswith('src/')}==set(s['core_changes']),'foreign physical/numerical source change'
 assert reader(PARENT)==projection(),'predecessor assertions changed'
 for p,h in s['postimages'].items():assert sha(reader(p))==h,p
 if changed is not None:
  for p in changed:assert p in delta or subprocess.run(['git','cat-file','-e',BASE+':'+p],cwd=ROOT,capture_output=True).returncode==0,'foreign caller'
 return json.loads(reader('integration/audits/MC_SOL01_DYNAMIC_DECAY_STATUS.json'))['swp_water_successor']
def capsule():
 s=json.loads((ROOT/STATUS).read_bytes());raw=base64.b64decode(b''.join((ROOT/p).read_bytes()for p in s['evidence']['parts']),validate=True);assert sha(raw)==s['evidence']['sha256']
 with tarfile.open(fileobj=io.BytesIO(raw),mode='r:xz')as t:
  ms=t.getmembers();assert all(m.isfile()and not Path(m.name).is_absolute()and'..'not in Path(m.name).parts for m in ms)
  assert len(ms)==len({m.name for m in ms});f={m.name:t.extractfile(m).read()for m in ms}
 assert json.loads(f.pop('MANIFEST.json'))=={p:sha(v)for p,v in f.items()};return f
def validate(f):
 js=lambda p:json.loads(f[p]);r=js('FINAL_RESULT.json')
 assert r['default_preserved_exact']and r['O0_O2_endpoint_exact']and r['primary_restart_exact']and r['failed_window_rollback_exact']
 assert r['primary_end_day']==2.5140000000028522 and r['new_committed_checkpoint']==2.7479999999995925
 assert r['window_off_censored']and r['window_on_complete']and r['three_day_complete']==False
 assert js('controls/RESULT.json')['passed']==6
 for p,h in js('executed-postimages.json').items():assert sha(f['executed/'+p])==h and sha((ROOT/p).read_bytes())==h,p
 for opt in ['O0','O2']:
  leaf=js('leaf-'+opt+'/RESULT.json');assert len(leaf)==2 and all(x['returncode']==0 for x in leaf)
  for name in ['preserve','rootless']:
   q=js(name+'-'+opt+'/RESULT.json');assert all(x['returncode']==0 for x in q['events'])
   for p,h in q['input_sha256'].items():assert sha((ROOT/p).read_bytes())==h,p
  build=js('build/'+opt+'/column/build-complete.json')
  for p,h in build['input_sha256'].items():assert sha((ROOT/p).read_bytes())==h,p
 for name in ['default-two','surface-two-off']:
  for p in ['state.csv','temperature.csv','budget.csv','progress.csv','cost.csv','diagnostics.csv']:
   assert f['primary-O2/'+name+'/run/'+p]==f['parent/'+name+'/'+p]
 for p in ['state.csv','temperature.csv']:
  assert f['primary-O2/jacobian-primary/run/'+p]==f['resumed-O0/'+p]
 for p in ['state.csv','temperature.csv','restart.bin']:
  assert f['primary-O2/jacobian-primary/run/'+p]==f['primary-O2/jacobian-primary/resumed/'+p]
 for prefix in ['primary-O2/jacobian-primary/run/','checkpoint2743/','checkpoint2748/','resumed-O0/']:
  m=js(prefix+'manifest.json');assert m['status']=='COMPLETE'
  for p,h in m['files'].items():assert sha(f[prefix+p])==h,p
  for row in csv.DictReader(io.StringIO(f[prefix+'budget.csv'].decode())):
   assert all(math.isfinite(float(v))for v in row.values())
   for k in ['max_macro_cell_cm','max_matrix_cm','max_combined_cm','max_net_source_cm']:assert abs(float(row[k]))<=1.e-10
 assert f['checkpoint2748/restart.bin']==f['three/diagnostic-rejected.bin']
 parent=js('parent-owner.json');assert parent['result']['dataqual02_tested']
 result=dict(parent['result']);result.update(dataqual03_tested=True,dataqual03_numerical_policy=r,canonically_admitted=False)
 return result
def verify():source();return validate(capsule())
def fsi35_successors():
 source();deps=json.loads((ROOT/'integration/audits/FCI93_NON_M1_COMPILE_DEPENDENCIES_20261011.json').read_bytes())['dependencies']
 for d in deps:assert git('rev-parse','HEAD:'+d['path'])==git('rev-parse',BASE+':'+d['path']),d['path']
 return dict(status='UNCHANGED_EXECUTABLE_DEPENDENCIES',dependencies=len(deps),baseline=BASE)
def self_test():
 source();f=capsule();validate(f);passed=[]
 def reject(label,fn):
  try:fn()
  except(AssertionError,KeyError,ValueError,TypeError,UnicodeError):passed.append(label);return
  raise AssertionError('accepted corrupt surface-demand proof '+label)
 for p in json.loads((ROOT/STATUS).read_bytes())['postimages']:reject('source '+p,lambda p=p:source(lambda q:(ROOT/q).read_bytes()+(b'!'if q==p else b'')))
 reject('foreign caller',lambda:source(changed={'src/foreign_surface.f90':'A'}))
 for p in ['FINAL_RESULT.json','controls/RESULT.json','parent-owner.json']:
  bad=dict(f);bad[p]+=b'!';reject('raw '+p,lambda bad=bad:validate(bad))
 return passed
if __name__=='__main__':print(json.dumps(dict(result=verify(),negative_controls=self_test(),fsi35=fsi35_successors()),indent=2))
