"""Fresh native rotation/restarts on verified already-qualified provider binaries.

No compilation is relabelled: the original measured build inventory is retained
and provider/module/executable hashes are checked before and after every phase.
"""
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
import hashlib,json,os,re,shutil,subprocess,threading,time
ROOT=Path(__file__).resolve().parents[2]
PROVIDERS=Path(os.environ['N_SURFACE_PROVIDERS']).resolve()
OUT=Path(os.environ['N_SURFACE_ROTATION_DIR']).resolve();OUT.mkdir(exist_ok=False)
PHASE=os.environ.get('N_SURFACE_ROTATION_PHASE','baseline');assert PHASE in ['baseline','fresh','incumbent']
BASE=Path(os.environ.get('N_SURFACE_BASELINE_DIR',str(OUT))).resolve()
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
SELF_SHA=sha(Path(__file__))
prior=json.loads((PROVIDERS/'result.json').read_text())
assert prior['status']=='SURFACE_N_B1_ACTUAL_PHYSICAL_PASS_NOT_ADMITTED'and prior['days']==2
for p,h in prior['input_sha256'].items():assert sha(ROOT/p)==h,('changed qualified provider input',p)
assert sha(PROVIDERS/'generated_driver.f90')==prior['generated_driver_sha256']
events=json.loads((PROVIDERS/'events.json').read_text());assert all(e['returncode']==0 for e in events)
artifacts={}
for opt in ['O0','O2']:
 exe=PROVIDERS/opt/'hist';assert exe.exists()
 for p in (PROVIDERS/opt).iterdir():
  if p.is_file()and(p.suffix in ['.o','.mod','.smod']or p==exe):artifacts[str(p)]=sha(p)
 for e in events:
  if e['category']=='compile'and '/'+opt+'/'in e['command'][e['command'].index('-o')+1]:
   c=e['command'];assert '-'+opt in c and '-fcheck=all'in c and '-ffpe-trap=invalid,zero,overflow'in c
   assert c[c.index('-o')+1]in artifacts
assert artifacts
(OUT/'provider_identity.json').write_text(json.dumps(dict(result_sha256=sha(PROVIDERS/'result.json'),artifacts=artifacts,input_sha256=prior['input_sha256'],original_build_events_sha256=sha(PROVIDERS/'events.json')),indent=2)+'\n')
lock=threading.Lock();rows=[];started=time.perf_counter()
def execute(job):
 opt,profile,day=job;b=OUT/opt/(profile+'-'+str(day));b.mkdir(parents=True)
 exe=PROVIDERS/opt/'hist';restart=b/'state.restart';endpoint=b/'endpoint'
 if PHASE=='fresh':
  source=BASE/opt/'surface-profile-0'/('state.restart.'+str(day))
  assert source.is_file();shutil.copyfile(source,restart)
  args=[str(exe),'resume',str(restart),str(endpoint),profile,str(day),'730']
 else:
  args=[str(exe),'write',str(restart),str(endpoint)]
  if profile=='surface-profile':args += [profile,'0','730']
  elif profile!='default':args += [profile]
 t=time.perf_counter();env={**os.environ,'OMP_NUM_THREADS':'1','GFORTRAN_UNBUFFERED_ALL':'1'}
 with (b/'stdout').open('wb')as stdout,(b/'stderr').open('wb')as stderr:
  p=subprocess.run(args,cwd=b,stdout=stdout,stderr=stderr,env=env)
 r=dict(opt=opt,profile=profile,first_day=day,command=args,returncode=p.returncode,seconds=time.perf_counter()-t,stdout_sha256=sha(b/'stdout'),stderr_sha256=sha(b/'stderr'))
 if PHASE=='fresh':r['input_restart_sha256']=sha(restart)
 if p.returncode==0:
  r['endpoint_sha256']=sha(endpoint)
  if PHASE=='fresh':assert endpoint.read_bytes()==(BASE/opt/'surface-profile-0'/'endpoint').read_bytes(),'fresh endpoint differs'
  text=(b/'stdout').read_text()
  if profile=='surface-profile':
   assert re.search(r'SURFACE_N_B1_PHYSICAL_DAYS\s+730',text)
   budget=re.findall(r'ROTATION_BUDGET\s+([^\n]+)',text);assert budget
   values=[float(x.replace('D','E'))for x in budget[-1].split()]
   assert len(values)==5 and abs(values[-1])<=1e-12*max(1.,abs(values[0]),abs(values[3]))
   r['nitrogen_budget_kg_m2']=values
 with lock:
  rows.append(r);(OUT/'events.json').write_text(json.dumps(rows,indent=2)+'\n')
 assert p.returncode==0,(job,p.returncode)
 return r
jobs=[(o,'surface-profile',0)for o in ['O0','O2']]if PHASE=='baseline'else[(o,'surface-profile',d)for o in ['O0','O2']for d in [1,120,121,365,366,500]]if PHASE=='fresh'else[(o,p,0)for o in ['O0','O2']for p in ['default','source-profile','rotation-profile','atmospheric-profile','humus-profile']]
with ThreadPoolExecutor(max_workers=2)as pool:completed=list(pool.map(execute,jobs))
for p,h in artifacts.items():assert sha(Path(p))==h,'provider artifact changed'
for p,h in prior['input_sha256'].items():assert sha(ROOT/p)==h,'provider source changed during execution'
if PHASE in ['baseline','incumbent']:
 for profile in {r['profile']for r in completed}:
  a=OUT/'O0'/(profile+'-0')/'endpoint';b=OUT/'O2'/(profile+'-0')/'endpoint';assert a.read_bytes()==b.read_bytes(),'O0/O2 endpoint drift'
if PHASE=='incumbent':
 import base64,io,tarfile
 s=json.loads((ROOT/'integration/mc-nut01/MC-NUT01-HIST-COMPLETE_STATUS.json').read_text())
 with tarfile.open(fileobj=io.BytesIO(base64.b64decode((ROOT/s['historical_guard']['physical_evidence']['path']).read_bytes())))as t:
  for row in completed:
   name='nut-hist-capacity-qualified/'+row['opt']+'/'+row['profile']+'.endpoint'
   assert (OUT/row['opt']/(row['profile']+'-0')/'endpoint').read_bytes()==t.extractfile(name).read(),'original endpoint changed'
assert sha(Path(__file__))==SELF_SHA,'phase runner changed during execution'
r=dict(status='SURFACE_N_B1_REUSED_PROVIDER_'+PHASE.upper()+'_PASS_NOT_ADMITTED',phase=PHASE,execution_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),input_sha256={str(Path(__file__).relative_to(ROOT)):sha(Path(__file__))},provider_result_sha256=sha(PROVIDERS/'result.json'),jobs=completed,seconds=time.perf_counter()-started)
(OUT/'result.json').write_text(json.dumps(r,indent=2)+'\n');print(r['status'])
