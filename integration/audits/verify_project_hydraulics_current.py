"""Source-bound admission of the existing native project hydraulic owners."""
import base64,csv,hashlib,io,json,re,runpy,subprocess,tarfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];BASE='3f184a488bce19bfcabf9c349cbff0d836b8cfeb'
STATUS='integration/mc-sol01/drainage/PROJECT_HYDRAULICS_STATUS.json';SELF='integration/audits/verify_project_hydraulics_current.py';PARENT='integration/audits/verify_ksatexm_input_current.py';SCIENCE=['src','app','tools','tests','examples','reference','.github','integration/audits'];sha=lambda b:hashlib.sha256(b).hexdigest()
def git(*a):return subprocess.check_output(['git',*a],cwd=ROOT,text=True).strip()
def projection():
 t=subprocess.check_output(['git','show',BASE+':'+PARENT],cwd=ROOT,text=True)
 for name,args in [('source','reader,changed'),('verify',''),('self_test',''),('fsi35_successors','')]:
  start=re.search(r'^def '+name+r'\(',t,re.M).start();at=t.index(':',t.index(')',start))+1
  if t[at:at+1]!='\n':t=t[:at]+'\n '+t[at:]
  at=t.index('\n',start)+1;t=t[:at]+" if (ROOT/'"+STATUS+"').is_file():return __import__('runpy').run_path(str(ROOT/'"+SELF+"'))['"+name+"']("+args+")\n"+t[at:]
 return t.encode()
def source(reader=lambda p:(ROOT/p).read_bytes(),changed=None):
 s=json.loads(reader(STATUS));assert s['baseline']==BASE;git('merge-base','--is-ancestor',BASE,'HEAD')
 delta={x.split('\t')[1]:x.split('\t')[0]for x in git('diff','--name-status',BASE,'HEAD','--',*SCIENCE).splitlines()};assert delta==s['scientific_delta']
 assert set(delta)=={'app/solute_project/main.f90','tools/solute/run_project.py',PARENT,SELF};assert not git('status','--porcelain','--',*SCIENCE)
 assert reader(PARENT)==projection()
 for p,h in s['postimages'].items():assert sha(reader(p))==h,('project hydraulics source',p)
 if changed is not None:
  for p in changed:assert p in delta or subprocess.run(['git','cat-file','-e',BASE+':'+p],cwd=ROOT,capture_output=True).returncode==0,'foreign caller'
 return json.loads(reader('integration/audits/MC_SOL01_DYNAMIC_DECAY_STATUS.json'))['swp_water_successor']
def capsule():
 e=json.loads((ROOT/STATUS).read_bytes())['evidence'];raw=base64.b64decode((ROOT/e['path']).read_bytes(),validate=True);assert sha(raw)==e['sha256']and len(raw)==e['bytes']
 with tarfile.open(fileobj=io.BytesIO(raw),mode='r:xz')as t:
  ms=t.getmembers();assert len(ms)==e['members']==len({m.name for m in ms});assert all(m.isfile()and not Path(m.name).is_absolute()and'..'not in Path(m.name).parts for m in ms);f={m.name:t.extractfile(m).read()for m in ms}
 assert json.loads(f.pop('MANIFEST.json'))=={p:sha(b)for p,b in f.items()};return f
def validate(f):
 # Reuse accepted unchanged column/provider/heat evidence without another run.
 old=runpy.run_path(str(ROOT/PARENT));inherited=old['validate'](old['capsule']());assert inherited['qualified']
 parent=json.loads(f['parent/proof.json']);assert parent['owner']['qualified']and len(parent['controls'])==14
 raw=f['parent/commit.raw'];assert hashlib.sha1(b'commit '+str(len(raw)).encode()+b'\0'+raw).hexdigest()==BASE
 for opt in ['O0','O2']:
  prefix='project-'+opt+'/';r=json.loads(f[prefix+'RESULT.json']);assert r['status']=='PROJECT_HYDRAULICS_BBC481_RESTART_PASS';assert r['source_nodes']==12 and r['complete_days']==481 and r['coupled_cases']==r['fresh_process_restarts']==2 and r['rejected_processes']==10
  assert len(r['events'])==18 and all((e['returncode']==0)==e['expected_success']for e in r['events'])
  for p,h in r['input_sha256'].items():assert sha((ROOT/p).read_bytes())==h and sha(f['executed/'+p])==h,p
  if opt=='O2':assert r['results']==json.loads(f['project-O0/RESULT.json'])['results']
  assert r['results']['below']==r['results']['equal'];assert r['active_KSATEXM_Picard_composition']=='REJECTED_BY_EXISTING_ADMISSION_GUARD'
  blocked=[b for p,b in f.items()if p.startswith(prefix+'active/full.pending-')and p.endswith('/stdout')];assert len(blocked)==1
  assert b'joint status/water/chemical:'in blocked[0]and b'101'in blocked[0]and b'joint interval rejected'in blocked[0]
  assert not any(p.startswith(prefix+'blocked-active/')for p in f)
  rows=lambda p:list(csv.DictReader(io.StringIO(f[p].decode())))
  for name in ['below','equal']:
   c=prefix+name+'/';result=r['results'][name];budget=rows(c+'full/budget.csv');assert len(budget)==481 and budget[365:]==rows(c+'resumed/budget.csv')
   assert budget==result['budget'];assert sum(float(x['drainage_cm'])for x in budget)>0
   for p,h in result['files'].items():assert sha(f[c+'full/'+p])==h and f[c+'full/'+p]==f[c+'resumed/'+p]
   for row in budget:
    assert abs(float(row['water_residual_cm']))<1e-10 and abs(float(row['solute_residual_mg_cm2']))<1e-10
    independent=float(row['water_end_cm'])-float(row['water_start_cm'])-float(row['rain_supplied_cm'])+float(row['runoff_cm'])+float(row['soil_evaporation_cm'])+float(row['pond_evaporation_cm'])+float(row['actual_transpiration_cm'])-float(row['bottom_up_cm'])+float(row['drainage_cm']);assert abs(independent)<1e-10
   for row in rows(c+'full/state.csv'):assert min(float(row[k])for k in ['theta','concentration_mg_cm3','dissolved_mg_cm2','sorbed_mg_cm2'])>=0
  for p,h in r['results']['default']['files'].items():assert sha(f[prefix+'default/'+p])==h and f[prefix+'default/'+p]==f[prefix+'baseline/'+p]
  assert f[prefix+'default/budget.csv']==f[prefix+'baseline/budget.csv']
 return dict(qualified=True,current_cases=4,days_per_case=481,exact_process_restarts=4,rejected_processes=20,default_artifact_comparisons=8,unchanged_column_qualification=inherited,full_original_Andelst=False,canonically_admitted=False)
def verify():source();return validate(capsule())
def fsi35_successors():
 source();deps=json.loads((ROOT/'integration/audits/FCI93_NON_M1_COMPILE_DEPENDENCIES_20261011.json').read_bytes())['dependencies']
 for d in deps:assert git('rev-parse','HEAD:'+d['path'])==git('rev-parse',BASE+':'+d['path'])
 return json.loads(capsule()['parent/proof.json'])['fsi35']
def self_test():
 source();f=capsule();validate(f);passed=[]
 def reject(label,fn):
  try:fn()
  except(AssertionError,KeyError,ValueError,TypeError,UnicodeError):passed.append(label);return
  raise AssertionError('accepted project hydraulic corruption '+label)
 for p in json.loads((ROOT/STATUS).read_bytes())['postimages']:reject('source '+p,lambda p=p:source(lambda q:(ROOT/q).read_bytes()+(b'!'if p==q else b'')))
 reject('foreign caller',lambda:source(changed={'src/foreign_project.f90':'A'}))
 for p in ['project-O0/RESULT.json','project-O2/equal/resumed/restart.bin','project-O0/equal/full/budget.csv','project-O2/default/state.csv']:
  bad=dict(f);bad[p]+=b'!';reject('raw '+p,lambda bad=bad:validate(bad))
 return passed
if __name__=='__main__':print(json.dumps(verify(),indent=2))
