"""Current original-input KSATEXM admission, with unchanged inherited assertions."""
import base64,csv,hashlib,io,json,re,runpy,subprocess,tarfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];BASE='7afa86335ed18c1f2365151d16f39385bf39d9e7'
STATUS='integration/mc-sol01/drainage/KSATEXM_INPUT_STATUS.json';SELF='integration/audits/verify_ksatexm_input_current.py';PARENT='integration/audits/verify_hydrostatic_bootstrap_current.py'
SCIENCE=['src','app','tools','tests','examples','reference','.github','integration/audits'];sha=lambda b:hashlib.sha256(b).hexdigest()
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
 delta={x.split('\t')[1]:x.split('\t')[0]for x in git('diff','--name-status',BASE,'HEAD','--',*SCIENCE).splitlines()};assert delta==s['scientific_delta'];assert not any(p.startswith('src/')for p in delta)
 assert {p for p in delta if p.startswith('app/')}=={'app/solute_column/main.f90','app/solute_column/read_swp_water.f90'}
 assert not git('status','--porcelain','--',*SCIENCE);assert reader(PARENT)==projection()
 for p,h in s['postimages'].items():assert sha(reader(p))==h,('KSATEXM input',p)
 if changed is not None:
  for p in changed:assert p in delta or subprocess.run(['git','cat-file','-e',BASE+':'+p],cwd=ROOT,capture_output=True).returncode==0,'foreign caller'
 return json.loads(reader('integration/audits/MC_SOL01_DYNAMIC_DECAY_STATUS.json'))['swp_water_successor']
def capsule():
 e=json.loads((ROOT/STATUS).read_bytes())['evidence'];raw=base64.b64decode((ROOT/e['path']).read_bytes(),validate=True);assert sha(raw)==e['sha256']and len(raw)==e['bytes']
 with tarfile.open(fileobj=io.BytesIO(raw),mode='r:xz')as t:
  ms=t.getmembers();assert len(ms)==e['members']==len({m.name for m in ms});assert all(m.isfile()and not Path(m.name).is_absolute()and'..'not in Path(m.name).parts for m in ms);f={m.name:t.extractfile(m).read()for m in ms}
 assert json.loads(f.pop('MANIFEST.json'))=={p:sha(b)for p,b in f.items()};return f
def validate(f):
 # Preserve all prior raw scientific assertions, now exercised on current callers.
 inherited=runpy.run_path(str(ROOT/PARENT))['validate'](f);assert inherited['qualified']
 parent=json.loads(f['ksatexm-parent/proof.json']);assert parent['owner']['qualified']and len(parent['controls'])==17
 raw=f['ksatexm-parent/commit.raw'];assert hashlib.sha1(b'commit '+str(len(raw)).encode()+b'\0'+raw).hexdigest()==BASE
 for opt in ['O0','O2']:
  prefix='ksatexm-'+opt+'/';r=json.loads(f[prefix+'RESULT.json']);assert r['status']=='KSATEXM_INPUT_COMPONENT_COUPLED_RESTART_PASS';assert r['source_nodes']==112 and r['coupled_cases']==r['fresh_process_restarts']==3 and r['rejected_processes']==11
  assert len(r['events'])==25 and sum(e['returncode']!=0 for e in r['events'])==11
  assert all((e['returncode']==0)==e['expected_success']for e in r['events'])
  for p,h in r['input_sha256'].items():assert sha((ROOT/p).read_bytes())==h and sha(f['executed/'+p])==h,p
  assert len(r['results']['original'])==112
  if opt=='O2':assert r['results']==json.loads(f['ksatexm-O0/RESULT.json'])['results']
  assert r['results']['below']==r['results']['equal'];assert r['results']['active']['files']['state.csv']!=r['results']['equal']['files']['state.csv']
  for name in ['below','equal','active']:
   c=prefix+name+'/';result=r['results'][name]
   for p,h in result['files'].items():assert sha(f[c+'full/'+p])==h and f[c+'full/'+p]==f[c+'resumed/'+p]
   rows=lambda p:list(csv.DictReader(io.StringIO(f[p].decode())));budget=rows(c+'full/budget.csv');assert len(budget)==3 and rows(c+'resumed/budget.csv')==budget[1:]
   for row in budget:assert abs(float(row['water_residual_cm']))<1e-10 and abs(float(row['solute_residual_mg_cm2']))<1e-10
   for label in ['forbidden','forbidden-restart']:assert not any(p.startswith(c+label+'/')for p in f)
 for name,p in [('ksatexm_heat.nml','input.nml'),('ksatexm_heat.swp','source.swp')]:assert(ROOT/'examples/solute_column'/name).read_bytes()==f['ksatexm-O2/active/'+p]
 return dict(qualified=True,source_nodes=112,source_original_KSATEXM_equals_KSATFIT=True,new_coupled_cases=6,new_exact_process_restarts=6,rejected_new_processes=22,current_hydrostatic_preservation=inherited,all_process_solver_sources_unchanged=True,full_original_Andelst=False,canonically_admitted=False)
def verify():
 source();return validate(capsule())
def fsi35_successors():
 source();deps=json.loads((ROOT/'integration/audits/FCI93_NON_M1_COMPILE_DEPENDENCIES_20261011.json').read_bytes())['dependencies']
 for d in deps:assert git('rev-parse','HEAD:'+d['path'])==git('rev-parse',BASE+':'+d['path'])
 return json.loads(capsule()['ksatexm-parent/proof.json'])['fsi35']
def self_test():
 source();f=capsule();validate(f);passed=[]
 def reject(label,fn):
  try:fn()
  except(AssertionError,KeyError,ValueError,TypeError,UnicodeError):passed.append(label);return
  raise AssertionError('accepted KSATEXM corruption '+label)
 for p in json.loads((ROOT/STATUS).read_bytes())['postimages']:reject('source '+p,lambda p=p:source(lambda q:(ROOT/q).read_bytes()+(b'!'if p==q else b'')))
 reject('foreign caller',lambda:source(changed={'src/foreign_ksatexm.f90':'A'}))
 for p in ['ksatexm-O0/RESULT.json','ksatexm-O2/active/resumed/restart.bin','ksatexm-O0/active/full/budget.csv','proof-O2/app-shallow/resumed/restart.bin']:
  bad=dict(f);bad[p]+=b'!';reject('raw '+p,lambda bad=bad:validate(bad))
 return passed
if __name__=='__main__':print(json.dumps(verify(),indent=2))
