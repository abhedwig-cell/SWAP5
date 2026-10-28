"""Observed failed-trial costs and bounded iteration budgets; no physics promotion."""
import base64,csv,hashlib,io,json,math,subprocess,tarfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];BASE='872cf5aacdd87981206c9c1b6d05318d26fad3e1'
PARENT='integration/audits/verify_dataqual03_current.py';SELF='integration/audits/verify_dataqual04_current.py';STATUS='integration/dataqual04/STATUS.json'
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
 if (ROOT/'integration/dataqual05/STATUS.json').is_file():return __import__('runpy').run_path(str(ROOT/'integration/audits/verify_dataqual05_current.py'))['source'](reader,changed)
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
 assert r['default_preserved_exact']and r['O0_O2_endpoint_exact']and r['primary_restart_exact']
 assert r['failed_window_rollback_exact']and r['iteration_budget_does_not_fix_stall']
 assert r['failed_work_counted']and r['three_day_complete']==False
 assert js('controls/RESULT.json')['passed']==6
 for p,h in js('executed-postimages.json').items():assert sha(f['executed/'+p])==h and sha((ROOT/p).read_bytes())==h,p
 physical=['state.csv','temperature.csv','budget.csv','progress.csv','cost.csv','diagnostics.csv']
 baseline=list(csv.DictReader(io.StringIO(f['baseline/replay/cost.csv'].decode())))[-1]
 for opt in ['O0','O2']:
  build=js('build/'+opt+'/column/build-complete.json')
  for p,h in build['input_sha256'].items():assert sha((ROOT/p).read_bytes())==h,p
  short=js('short-'+opt+'/results.json');assert len(short)==8 and sum(x['status']=='PASS'for x in short)==4
  batch=js('two-'+opt+'/results.json');assert len(batch)==2 and all(x['status']=='PASS'for x in batch)
  for p in physical:assert f['two-'+opt+'/default-two/run/'+p]==f['parent/default-two/'+p]
  for p in ['state.csv','temperature.csv','restart.bin']:
   assert f['two-'+opt+'/budget128-two/run/'+p]==f['two-'+opt+'/budget128-two/resumed/'+p]
  for name in ['default-two','budget128-two']:
   prefix='two-'+opt+'/'+name+'/run/';m=js(prefix+'manifest.json');assert m['status']=='COMPLETE'
   for p,h in m['files'].items():assert sha(f[prefix+p])==h,p
   for row in csv.DictReader(io.StringIO(f[prefix+'budget.csv'].decode())):
    assert all(math.isfinite(float(v))for v in row.values())
    for k in ['max_macro_cell_cm','max_matrix_cm','max_combined_cm','max_net_source_cm']:assert abs(float(row[k]))<=1.e-10
 for p in ['state.csv','temperature.csv']:
  assert f['two-O0/budget128-two/run/'+p]==f['two-O2/budget128-two/run/'+p]
 assert f['two-O0/budget128-two/run/restart.bin'][72:-4]==f['two-O2/budget128-two/run/restart.bin'][72:-4]
 for name in ['cost-O0','cost-O2','budget128','budget256']:
  q=js(name+'/RESULT.json');assert q['origin_state_only']and not q['new_restart_qualified']
  assert q['rollback_exact']and not q['censored']and q['returncode']!=0
  assert f[name+'/diagnostic-rejected.bin']==f[name+'/origin.bin']
  rejects=[x.split()for x in f[name+'/stderr'].decode().splitlines()if x.strip().startswith('MACRO_REJECT')]
  cost=list(csv.DictReader(io.StringIO(f[name+'/cost.csv'].decode())))[-1]
  assert int(cost['nonlinear_iterations'])==int(baseline['nonlinear_iterations'])+sum(int(x[9])for x in rejects)
  assert int(cost['headcalc_calls'])==int(baseline['headcalc_calls'])+len(rejects)
  for p in ['budget.csv','progress.csv','diagnostics.csv']:assert f[name+'/'+p]==f['baseline/replay/'+p]
 parent=js('parent-owner.json');assert parent['result']['dataqual03_tested']
 result=dict(parent['result']);result.update(dataqual04_tested=True,dataqual04_measured_cost=r,canonically_admitted=False)
 return result
def verify():
 if (ROOT/'integration/dataqual05/STATUS.json').is_file():return __import__('runpy').run_path(str(ROOT/'integration/audits/verify_dataqual05_current.py'))['verify']()
 source();return validate(capsule())
def fsi35_successors():
 if (ROOT/'integration/dataqual05/STATUS.json').is_file():return __import__('runpy').run_path(str(ROOT/'integration/audits/verify_dataqual05_current.py'))['fsi35_successors']()
 source();deps=json.loads((ROOT/'integration/audits/FCI93_NON_M1_COMPILE_DEPENDENCIES_20261011.json').read_bytes())['dependencies']
 for d in deps:assert git('rev-parse','HEAD:'+d['path'])==git('rev-parse',BASE+':'+d['path']),d['path']
 return dict(status='UNCHANGED_EXECUTABLE_DEPENDENCIES',dependencies=len(deps),baseline=BASE)
def self_test():
 if (ROOT/'integration/dataqual05/STATUS.json').is_file():return __import__('runpy').run_path(str(ROOT/'integration/audits/verify_dataqual05_current.py'))['self_test']()
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
