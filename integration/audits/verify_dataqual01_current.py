"""DATAQUAL01 source/evidence successor; experimental success never promotes physics."""
import base64,csv,hashlib,io,json,math,subprocess,tarfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
BASE='e47e98c6b8e614c75284c831925a34d7756cd4b0'
STATUS='integration/dataqual01/STATUS.json'
SELF='integration/audits/verify_dataqual01_current.py'
PARENT='integration/audits/verify_entry_ramp_current.py'
sha=lambda b:hashlib.sha256(b).hexdigest()
def git(*args):return subprocess.check_output(['git',*args],cwd=ROOT,text=True).strip()
def projection():
 text=subprocess.check_output(['git','show',BASE+':'+PARENT],cwd=ROOT,text=True)
 for name,args in [('source','reader,changed'),('verify',''),('self_test',''),('fsi35_successors','')]:
  marker='def '+name+'(';at=text.index(marker);end=text.index('):',at)+2
  # One-line predecessor verify body is preserved after the dispatch.
  if text[end:end+1]!='\n':text=text[:end]+'\n '+text[end:]
  end+=1;text=text[:end]+" if (ROOT/'"+STATUS+"').is_file():return __import__('runpy').run_path(str(ROOT/'"+SELF+"'))['"+name+"']("+args+")\n"+text[end:]
 return text.encode()
def source(reader=lambda p:(ROOT/p).read_bytes(),changed=None):
 if (ROOT/'integration/dataqual02/STATUS.json').is_file():return __import__('runpy').run_path(str(ROOT/'integration/audits/verify_dataqual02_current.py'))['source'](reader,changed)
 s=json.loads(reader(STATUS));assert s['baseline']==BASE and s['tested']
 git('merge-base','--is-ancestor',BASE,'HEAD')
 assert not git('diff','HEAD','--','src','app','tools','tests','integration/audits'),'unpersisted source'
 for p,h in s['postimages'].items():assert sha(reader(p))==h,p
 delta={x.split('\t')[1]:x.split('\t')[0]for x in git('diff','--name-status',BASE,'HEAD','--','src','app','tools','tests','examples','reference','.github','integration/audits').splitlines()}
 assert delta==s['scientific_delta'],'foreign DATAQUAL01 delta'
 assert reader(PARENT)==projection(),'predecessor assertions changed'
 if changed is not None:
  for p in changed:assert p in delta or subprocess.run(['git','cat-file','-e',BASE+':'+p],cwd=ROOT,capture_output=True).returncode==0,'foreign caller'
 return json.loads(reader('integration/audits/MC_SOL01_DYNAMIC_DECAY_STATUS.json'))['swp_water_successor']
def capsule():
 s=json.loads((ROOT/STATUS).read_bytes());raw=base64.b64decode(b''.join((ROOT/p).read_bytes()for p in s['evidence']['parts']),validate=True)
 assert sha(raw)==s['evidence']['sha256']
 with tarfile.open(fileobj=io.BytesIO(raw),mode='r:xz')as t:
  ms=t.getmembers();assert all(m.isfile()and not Path(m.name).is_absolute()and'..'not in Path(m.name).parts for m in ms)
  assert len(ms)==len({m.name for m in ms});f={m.name:t.extractfile(m).read()for m in ms}
 assert json.loads(f.pop('MANIFEST.json'))=={p:sha(v)for p,v in f.items()}
 return f
def validate(f):
 js=lambda p:json.loads(f[p]);report=js('FINAL_RESULT.json');assert report['physical_passes']>=20
 assert report['active_oxygen_reduction_cm']>0 and report['production_oxygen_rejected']
 assert report['physical_exact_O0_O2']and report['predecessor_two_days_exact']
 assert report['restart_exact']and report['invalid_input_rejected']and report['censored_runs']>0
 for p,h in js('executed-postimages.json').items():assert sha(f['executed/'+p])==h and sha((ROOT/p).read_bytes())==h,p
 runs=js('aggregate-results.json');assert len(runs)==report['scenario_executions']
 assert sum(r['status']=='PASS'for r in runs)==report['physical_passes']
 for r in runs:
  if r['status']!='PASS':continue
  prefix='batches/'+r['batch']+'/'+r['id']+'/run/'
  manifest=js(prefix+'manifest.json');assert manifest['status']=='COMPLETE'
  assert all(e['returncode']==0 and not e['censored']for e in manifest['events'])
  for p,h in manifest['files'].items():assert sha(f[prefix+p])==h,prefix+p
  budget=list(csv.DictReader(io.StringIO(f[prefix+'budget.csv'].decode())))
  state=list(csv.DictReader(io.StringIO(f[prefix+'state.csv'].decode())))
  assert budget and len(state)==112
  for row in budget:
   assert all(math.isfinite(float(v))for v in row.values())
   for k in ['max_macro_cell_cm','max_matrix_cm','max_combined_cm','max_net_source_cm']:assert abs(float(row[k]))<=1e-10
  assert all(math.isfinite(float(row['head_cm']))and 0<=float(row['theta'])<=1 for row in state)
  assert abs(float(budget[-1]['t1'])-r['configuration'].get('stop_at_time',r['configuration']['days']))<=1e-9
 for opt in ['O0','O2']:
  for name in ['preserve','rootless']:
   proof=js(name+'-'+opt+'/RESULT.json');assert all(e['returncode']==0 for e in proof['events'])
   for p,h in proof['input_sha256'].items():assert sha((ROOT/p).read_bytes())==h,p
 assert js('restart-controls/RESULT.json')['passed']==6
 parent=js('parent-owner.json');assert parent['result']['qualified']and len(parent['negative_controls'])>=20
 result=dict(parent['result']);result.update(dataqual01_experimental_route_tested=True,dataqual01_production_promoted=False,
  dataqual01_summary=report,canonically_admitted=False)
 return result
def verify():
 if (ROOT/'integration/dataqual02/STATUS.json').is_file():return __import__('runpy').run_path(str(ROOT/'integration/audits/verify_dataqual02_current.py'))['verify']()
 source();return validate(capsule())
def fsi35_successors():
 if (ROOT/'integration/dataqual02/STATUS.json').is_file():return __import__('runpy').run_path(str(ROOT/'integration/audits/verify_dataqual02_current.py'))['fsi35_successors']()
 source();deps=json.loads((ROOT/'integration/audits/FCI93_NON_M1_COMPILE_DEPENDENCIES_20261011.json').read_bytes())['dependencies']
 for d in deps:assert git('rev-parse','HEAD:'+d['path'])==git('rev-parse',BASE+':'+d['path']),d['path']
 return dict(status='UNCHANGED_EXECUTABLE_DEPENDENCIES',dependencies=len(deps),baseline=BASE)
def self_test():
 if (ROOT/'integration/dataqual02/STATUS.json').is_file():return __import__('runpy').run_path(str(ROOT/'integration/audits/verify_dataqual02_current.py'))['self_test']()
 source();f=capsule();validate(f);passed=[]
 def reject(label,fn):
  try:fn()
  except(AssertionError,KeyError,ValueError,TypeError,UnicodeError):passed.append(label);return
  raise AssertionError('accepted corrupt DATAQUAL01 '+label)
 for p in json.loads((ROOT/STATUS).read_bytes())['postimages']:
  reject('source '+p,lambda p=p:source(lambda q:(ROOT/q).read_bytes()+(b'!'if q==p else b'')))
 reject('foreign caller',lambda:source(changed={'src/foreign_dataqual.f90':'A'}))
 for p in ['FINAL_RESULT.json','parent-owner.json','restart-controls/RESULT.json']:
  bad=dict(f);bad[p]+=b'!';reject('raw '+p,lambda bad=bad:validate(bad))
 return passed
if __name__=='__main__':print(json.dumps(dict(result=verify(),negative_controls=self_test(),fsi35=fsi35_successors()),indent=2))
