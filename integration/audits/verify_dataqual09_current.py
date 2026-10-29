"""Source-bound text-only diagnostic policy and exact native preservation evidence."""
import base64,csv,hashlib,io,json,math,runpy,subprocess,tarfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
BASE='a59ecaa23a492bcf193e83575a9a1f00fe97023b'
PARENT='integration/audits/verify_dataqual07_current.py'
SELF='integration/audits/verify_dataqual09_current.py'
STATUS='integration/dataqual09/STATUS.json'
sha=lambda b:hashlib.sha256(b).hexdigest()
def git(*args):return subprocess.check_output(['git',*args],cwd=ROOT,text=True).strip()
def baseline(p):return subprocess.check_output(['git','show',BASE+':'+p],cwd=ROOT)
def parent_projection():
 import re
 text=baseline(PARENT).decode()
 for name,args in [('source','reader,changed'),('verify',''),('self_test',''),('fsi35_successors',''),('validate','f')]:
  at=re.search(r'^def '+name+r'\(',text,re.M).start();end=text.index('):',at)+2
  if text[end:end+1]!='\n':text=text[:end]+'\n '+text[end:]
  end+=1;text=text[:end]+" if (ROOT/'"+STATUS+"').is_file():return __import__('runpy').run_path(str(ROOT/'"+SELF+"'))['"+('validate_predecessor' if name=='validate' else name)+"']("+args+")\n"+text[end:]
 return text.encode()
def source(reader=None,changed=None):
 if reader is None:reader=lambda p:(ROOT/p).read_bytes()
 s=json.loads(reader(STATUS));assert s['baseline']==BASE
 assert not git('diff','HEAD','--','src','app','tools','tests','integration/audits')
 delta={r.split('\t')[1]:r.split('\t')[0]for r in git('diff','--name-status',BASE,'HEAD','--','src','app','tools','tests','examples','reference','.github','integration/audits','integration/performance').splitlines()}
 assert delta==s['scientific_delta'],'foreign scientific delta'
 assert reader(PARENT)==parent_projection(),'parent delegation drift'
 for p,h in s['postimages'].items():assert sha(reader(p))==h,p
 # The only runtime execution changes are a default-true text flag and five write guards.
 p='src/runtime/mod_macropore_single_column_runtime.f90';old=baseline(p).decode()
 expected=old.replace('  type, public :: macropore_runtime_policy_t\n','  type, public :: macropore_runtime_policy_t\n    ! Text-only stage observations. No accepted flux trace or state is disabled.\n    logical :: emit_stage_diagnostics=.true.\n',1)
 import re
 expected,n=re.subn(r"(?m)^(\s*)write\(\*",r'\1if(policy%emit_stage_diagnostics)write(*',expected)
 assert n==5 and reader(p)==expected.encode(),'non-text runtime change'
 return json.loads(reader('integration/audits/MC_SOL01_DYNAMIC_DECAY_STATUS.json'))['swp_water_successor']
def inherited(evidence=None):
 # Validate the immutable predecessor under its exact preimages. The three
 # executed source files differ only on the separately checked current surface.
 class Entry:
  def __init__(self,p):self.p=p
  def read_bytes(self):
   return baseline(self.p) if self.p in projected else (ROOT/self.p).read_bytes()
 class View:
  def __truediv__(self,p):return Entry(str(p))
 projected={'src/runtime/mod_macropore_single_column_runtime.f90','app/solute_project/main_water.f90','tools/solute/run_native_water.py',PARENT}
 ns={'__file__':str(ROOT/PARENT),'__name__':'inherited_dataqual07'}
 exec(compile(baseline(PARENT),str(ROOT/PARENT),'exec'),ns)
 ns['ROOT']=View()
 return ns['validate'](ns['capsule']() if evidence is None else evidence)
def validate_predecessor(f):
 source();return inherited(f)
def capsule():
 m=json.loads((ROOT/'integration/dataqual09/CAPSULE.json').read_bytes())
 raw=base64.b64decode(b''.join((ROOT/p).read_bytes()for p in m['parts']),validate=True)
 assert sha(raw)==m['sha256'] and len(raw)==m['bytes']
 with tarfile.open(fileobj=io.BytesIO(raw),mode='r:xz')as t:
  members=t.getmembers();assert len(members)==m['members']==len({x.name for x in members})
  assert all(x.isfile()and not Path(x.name).is_absolute()and'..'not in Path(x.name).parts for x in members)
  f={x.name:t.extractfile(x).read()for x in members}
 assert json.loads(f.pop('MANIFEST.json'))=={p:sha(b)for p,b in f.items()};return f
def validate(f):
 js=lambda p:json.loads(f[p]);results=[]
 ns={'__file__':str(ROOT/PARENT),'__name__':'predecessor_capsule'};exec(compile(baseline(PARENT),str(ROOT/PARENT),'exec'),ns);prior=ns['capsule']()
 for opt in ['O0','O2']:
  build=js('build/'+opt+'/bundle.json')
  assert build['physical_build']['provider_count']==194
  column=json.loads((ROOT/('integration/dataqual09/BUILD_'+opt+'.json')).read_bytes())
  assert column['provider_count']==194 and '-fcheck=all'in column['flags']
  assert sha(f['recovery/native-'+opt])==column['executable_sha256']==build['executable_sha256'][build['exe']]
  for p,h in column['input_sha256'].items():assert sha((ROOT/p).read_bytes())==h,p
  for p,h in build['physical_build']['input_sha256'].items():assert sha((ROOT/p).read_bytes())==h,p
  for r in js(opt+'/RESULT.json'):
   results.append(r)
   if not r['qualified_pair']:continue
   assert r['pair']['loud']['binding']==r['pair']['quiet']['binding']
   assert r['pair']['loud']['hashes']==r['pair']['quiet']['hashes']
   for mode in ['loud','quiet']:
    pre=opt+'/'+r['id']+'/'+mode+'/'
    m=js(pre+'manifest.json');assert m['status']=='COMPLETE'
    native=next(e for e in m['events']if e['label']=='native');assert native['returncode']==0
    assert m['binding_sha256']==r['pair'][mode]['binding']
    for p,h in m['files'].items():assert sha(f[pre+p])==h
    for p,h in r['pair'][mode]['hashes'].items():assert sha(f[pre+p])==h
    budget=list(csv.DictReader(io.StringIO(f[pre+'budget.csv'].decode())))
    for row in budget:
     for k in ['max_macro_cell_cm','max_matrix_cm','max_combined_cm','max_net_source_cm']:assert abs(float(row[k]))<=1e-10
   for p in ['state.csv','temperature.csv','budget.csv','progress.csv','cost.csv','diagnostics.csv']:
    assert f[opt+'/'+r['id']+'/loud/'+p]==prior['restarts-'+opt+'/'+r['id']+'/run/'+p]
   assert f[opt+'/'+r['id']+'/loud/restart.bin'][72:-4]==prior['restarts-'+opt+'/'+r['id']+'/run/restart.bin'][72:-4]
   assert b'MIGMAC01_RUNTIME_PRE'in f[opt+'/'+r['id']+'/loud/native.stdout']
   assert b'MIGMAC01_RUNTIME_PRE'not in f[opt+'/'+r['id']+'/quiet/native.stdout']
   assert b'PPA_WU05A18_RUNTIME_STAGE'not in f[opt+'/'+r['id']+'/quiet/native.stdout']
  restart=js(opt+'/RESTART.json');assert restart['loud_prefix_quiet_suffix_exact']
  for p in restart['files']:assert f[opt+'/'+restart['id']+'/quiet/'+p]==f[opt+'/'+restart['id']+'/resumed/'+p]
 assert sum(r['qualified_pair']for r in results)>=3
 assert js('controls.json')['passed']==6
 for name in ['default-two','original-corrected-two']:
  for p in ['state.csv','temperature.csv','budget.csv','progress.csv','cost.csv','diagnostics.csv']:
   assert f['preservation/'+name+'/run/'+p]==prior['preservation/'+name+'/run/'+p]
  assert f['preservation/'+name+'/run/restart.bin'][72:-4]==prior['preservation/'+name+'/run/restart.bin'][72:-4]
 extensions=js('extensions/RESULT.json');assert len(extensions)==2
 for r in extensions:
  if r['status']!='PASS':continue
  pre='extensions/'+r['id']+'/'
  assert f[pre+'origin.bin']==f['O2/'+r['id']+'/quiet/restart.bin']
  for p in ['input.nml','input.swp','macro.nml']:assert f[pre+p]==f['O2/'+r['id']+'/quiet/'+p]
  assert sha(f[pre+'origin.bin'])==r['origin_sha256'] and r['returncode']==0
  for p in ['state.csv','temperature.csv']:
   rows=list(csv.DictReader(io.StringIO(f[pre+p].decode())));assert len(rows)==112
   assert all(math.isfinite(float(v))for row in rows for v in row.values())
   if p=='state.csv':assert all(0<=float(row['theta'])<=1 for row in rows)
  rows=list(csv.DictReader(io.StringIO(f[pre+'budget.csv'].decode())))
  assert float(rows[0]['t0'])==1.4424999999973807 and float(rows[-1]['t1'])==r['target']
  for row in rows:
   for k in ['max_macro_cell_cm','max_matrix_cm','max_combined_cm','max_net_source_cm']:assert abs(float(row[k]))<=1e-10
  assert all(int(row['mass_rejections'])==0 for row in csv.DictReader(io.StringIO(f[pre+'progress.csv'].decode())))
 def sig(c):
  defaults=dict(mode='experimental',source_surface_demand=False,perched_jacobian=False,solver_max_iterations=64,anchored=True,entry_width_cm=1e-4,transformations=[])
  return json.dumps({k:c.get(k,v)for k,v in defaults.items()},sort_keys=True)
 durations={}
 for r in json.loads(prior['baseline-rows.json'])+json.loads(prior['all-results.json']):
  if r['status']=='PASS':durations[sig(r['configuration'])]=max(durations.get(sig(r['configuration']),0),r['completed_days'])
 # Carry the independently qualified DATAQUAL08 day2 prefix, not its censored targets.
 old08=runpy.run_path(str(ROOT/'integration/dataqual09/read_dataqual08.py'))['read']()
 for r in json.loads(old08['five/RETAINED.json'])['retained']:
  durations[sig(r['configuration'])]=max(durations.get(sig(r['configuration']),0),r['completed_days'])
 assert len(durations)==83 and abs(sum(durations.values())-94.17599999972299)<1e-9
 cases=json.loads((ROOT/'integration/dataqual09/cases.json').read_bytes())['scenarios']
 for r in extensions:
  if r['status']=='PASS':
   key=sig(next(c for c in cases if c['id']==r['id']));assert key in durations;durations[key]=max(durations[key],r['completed_days'])
 summary=json.loads((ROOT/'integration/dataqual09/RESULT.json').read_bytes())
 assert len(durations)==summary['water_qualified']==83 and abs(sum(durations.values())-summary['configuration_days'])<1e-9
 return dict(qualified=True,physical_changes=False,qualified_pairs=sum(r['qualified_pair']for r in results),speedup_established=False)
def verify():source();inherited();return validate(capsule())
def fsi35_successors():
 verify()
 deps=json.loads((ROOT/'integration/audits/FCI93_NON_M1_COMPILE_DEPENDENCIES_20261011.json').read_bytes())['dependencies']
 for d in deps:assert (ROOT/d['path']).read_bytes()==baseline(d['path'])
 return {d['path']:dict(historical_blob=d['blob'],canonical_blob=git('rev-parse','HEAD:'+d['path']))for d in deps}
def self_test():
 source();s=json.loads((ROOT/STATUS).read_bytes());passed=0
 for p in s['postimages']:
  try:source(lambda q:(ROOT/q).read_bytes()+b' 'if q==p else(ROOT/q).read_bytes())
  except AssertionError:passed+=1;continue
  raise AssertionError('accepted corrupt source '+p)
 return dict(passed=passed)
if __name__=='__main__':print(json.dumps(dict(result=verify(),negative_controls=self_test()),indent=2))
