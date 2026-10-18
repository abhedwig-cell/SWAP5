"""Continuous current audited rotation and short exact native transition windows.

No compilation is inferred: reuse only the eight-day independent-audit executable
and every byte-bound original provider and generated driver artifact.
"""
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
import datetime,hashlib,json,os,re,subprocess,threading,time
ROOT=Path(__file__).resolve().parents[2]
PROVIDERS=Path(os.environ['N_SURFACE_AUDIT_PROVIDERS']).resolve()
OUT=Path(os.environ['N_SURFACE_WINDOW_DIR']).resolve();OUT.mkdir(exist_ok=False)
PHASE=os.environ.get('N_SURFACE_WINDOW_PHASE','baseline');assert PHASE in ['baseline','fresh']
BASE=Path(os.environ.get('N_SURFACE_BASELINE_DIR',str(OUT))).resolve()
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();SELF_SHA=sha(Path(__file__))
prior=json.loads((PROVIDERS/'result.json').read_text())
assert prior['status']=='SURFACE_N_B1_ROTATION_WATER_N_AUDIT_PASS_NOT_ADMITTED'
assert prior['days']==8 and prior['boundary']=='fixed-head'
assert sha(PROVIDERS/'water_audit.f90')==prior['generated_driver_sha256']
assert '    if(.true.)then' in(PROVIDERS/'water_audit.f90').read_text()
for p,h in prior['input_sha256'].items():assert sha(ROOT/p)==h,p
artifacts={**prior['artifacts'],**prior['generated_artifacts']};assert len(prior['generated_artifacts'])==4
for opt in ['O0','O2']:
 assert str(PROVIDERS/opt/'audit')in artifacts and str(PROVIDERS/opt/'audit.o')in artifacts
for p,h in artifacts.items():assert sha(Path(p))==h,p
original=json.loads((PROVIDERS/'events.json').read_text());assert all(e['returncode']==0 for e in original)
assert sum(e['category']=='driver_compile'for e in original)==2
assert sum(e['category']=='native'for e in original)==2
for e in original:
 if e['category']=='driver_compile':assert '-fcheck=all'in e['command']and'-ffpe-trap=invalid,zero,overflow'in e['command']
if PHASE=='fresh':
 b=json.loads((BASE/'result.json').read_text())
 assert b['status']=='SURFACE_B1_CONTINUOUS_AUDIT_730_DAYS_O0_O2_PASS_NOT_ADMITTED'
 assert b['provider_result_sha256']==sha(PROVIDERS/'result.json')
 for p,h in b['input_sha256'].items():assert sha(ROOT/p)==h,p
# Include before/after harvest and successor, year boundary and every later
# actual historical material date from the executed immutable source fixture.
windows={(1,3),(119,120),(120,121),(364,365),(365,366),(499,500),(500,501)}
if PHASE=='fresh':
 fixture=(BASE/'O0'/'baseline'/'source-crop-startup.snm').read_text()
 dates=re.findall(r'^(\d{4}-\d\d-\d\d)\s',fixture,re.M);assert len(dates)==6
 initial=datetime.date.fromisoformat(dates[0]);assert initial==datetime.date(1900,12,30)
 for date in dates:
  d=(datetime.date.fromisoformat(date)-initial).days
  if d>0:windows.add((d,d+1))
lock=threading.Lock();records=[]
def execute(job):
 opt,first,last=job;b=OUT/opt/('baseline'if PHASE=='baseline'else f'{first}-{last}');b.mkdir(parents=True)
 exe=PROVIDERS/opt/'audit';restart=b/'restart';endpoint=b/'endpoint'
 if PHASE=='fresh':
  seed=BASE/opt/'baseline'/f'restart.{first}';assert seed.is_file()
  restart.write_bytes(seed.read_bytes());expected=BASE/opt/'baseline'/f'restart.{last}';assert expected.is_file()
 command=[str(exe),'write'if PHASE=='baseline'else'resume',str(restart),str(endpoint),'surface-profile',str(first),str(last)]
 started=time.perf_counter()
 with(b/'stdout').open('wb')as stdout,(b/'stderr').open('wb')as stderr:
  r=subprocess.run(command,cwd=b,stdout=stdout,stderr=stderr,env={**os.environ,'OMP_NUM_THREADS':'1','GFORTRAN_UNBUFFERED_ALL':'1'})
 row=dict(opt=opt,first=first,last=last,command=command,returncode=r.returncode,seconds=time.perf_counter()-started,stdout_sha256=sha(b/'stdout'),stderr_sha256=sha(b/'stderr'))
 if r.returncode==0:
  row['endpoint_sha256']=sha(endpoint)
  if PHASE=='fresh':
   assert endpoint.read_bytes()==expected.read_bytes(),('fresh complete native state drift',opt,first,last)
   row['seed_sha256']=sha(seed);row['continuous_state_sha256']=sha(expected)
  else:
   text=(b/'stdout').read_text();metrics={}
   for line in text.splitlines():
    fields=line.split()
    if fields and(fields[0].startswith('AUDIT_')or fields[0]=='ROTATION_BUDGET'):metrics[fields[0]]=[float(v.replace('D','E'))for v in fields[1:]]
   assert len(metrics)==9 and re.search(r'SURFACE_N_B1_PHYSICAL_DAYS\s+730',text)
   assert abs(metrics['ROTATION_BUDGET'][-1])<=1e-12
   assert abs(metrics['AUDIT_WATER_CM'][-1])<=1e-10
   assert max(map(abs,metrics['AUDIT_SURFACE_WATER_CM'][-2:]))<=1e-10
   assert max(map(abs,metrics['AUDIT_SURFACE_N_KG_M2'][-2:]))<=1e-12
   for day in range(1,731):assert(b/f'restart.{day}').is_file(),('missing continuous state',day)
   for day in [120,366]:assert(b/f'restart.reject-before-{day}').read_bytes()==(b/f'restart.reject-after-{day}').read_bytes(),'rollback state drift'
   row['metrics']=metrics
 with lock:
  records.append(row);(OUT/'events.json').write_text(json.dumps(records,indent=2)+'\n')
 assert r.returncode==0,(opt,first,last,r.returncode)
 return row
jobs=[(o,0,730)for o in ['O0','O2']]if PHASE=='baseline'else[(o,a,b)for o in ['O0','O2']for a,b in sorted(windows)]
started=time.perf_counter()
with ThreadPoolExecutor(max_workers=2)as pool:rows=list(pool.map(execute,jobs))
if PHASE=='baseline':
 assert(OUT/'O0/baseline/endpoint').read_bytes()==(OUT/'O2/baseline/endpoint').read_bytes(),'optimization native drift'
 assert rows[0]['metrics']==rows[1]['metrics'],'optimization audit drift'
for p,h in artifacts.items():assert sha(Path(p))==h,p
for p,h in prior['input_sha256'].items():assert sha(ROOT/p)==h,p
assert sha(Path(__file__))==SELF_SHA
result=dict(status='SURFACE_B1_CONTINUOUS_AUDIT_730_DAYS_O0_O2_PASS_NOT_ADMITTED'if PHASE=='baseline'else'SURFACE_B1_FRESH_TRANSITION_WINDOWS_EXACT_NATIVE_PASS_NOT_ADMITTED',phase=PHASE,execution_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),provider_result_sha256=sha(PROVIDERS/'result.json'),input_sha256={**prior['input_sha256'],str(Path(__file__).relative_to(ROOT)):SELF_SHA},artifacts=artifacts,records=rows,seconds=time.perf_counter()-started)
(OUT/'result.json').write_text(json.dumps(result,indent=2)+'\n');print(result['status'])
