"""Read-only audit of actual candidate journals, native continuations and source bindings."""
from pathlib import Path
import hashlib,io,json,math,statistics,zipfile
here=Path(__file__).resolve().parent;root=here.parents[2];sha=lambda b:hashlib.sha256(b).hexdigest();read=lambda p:json.loads(p.read_bytes())
for name,digest in read(here/'SEAL.json').items():assert sha((here/name).read_bytes())==digest,name
analysis=read(here/'ANALYSIS.json');current=read(here/'CURRENT.json');provenance=read(here/'PROVENANCE.json')
def rows(z,p):return [json.loads(s) for s in z.read(p+'/daily.jsonl').splitlines()]
def physical(data):return [{k:v for k,v in r.items() if k not in ('column','revision')} for r in data]
def csv(z,p):return [s for s in z.read(p+'/original/result_output.csv').decode().splitlines() if s.strip() and not s.startswith('*')]
def native(z,p,day):
 with zipfile.ZipFile(io.BytesIO(z.read(p+f'/accepted-column-1-day-{day}.zip'))) as n:
  m=json.loads(n.read('checkpoint.json'));data={k:n.read(k) for k in ('result.end','macro.bin')};assert m['files']=={k:sha(v) for k,v in data.items()};return data,m

def balance(data):
 for r in data:
  assert r['committed'] and abs(r['kernel_residual_cm'])<=1e-10
  f,s,e=r['external_flux_cm'],r['stock_start_cm'],r['stock_end_cm'];water=math.fsum([*f[:7],*(-v for v in f[7:]),*s,*(-v for v in e)])
  end,delta,rain,irrig,bottom,drain,decay,uptake,reported=r['solute_ledger_mg_cm2'];solute=math.fsum([end,-r['solute_start_mg_cm2'],-rain,-irrig,-bottom,drain,decay,uptake])
  assert water==r['independent_residual_cm'] and solute==r['solute_independent_residual_mg_cm2'] and abs(water)<=1e-10 and abs(solute)<=1e-10 and abs(reported)<=1e-10

def cold(z,p,pattern):
 data=rows(z,p+'/full');assert [r['day'] for r in data]==list(range(1,1462));balance(data)
 for a,b in ((109,111),(365,367),(453,455),(1460,1461),(109,1461)):
  q=pattern.format(a=a,b=b);actual=rows(z,q);balance(actual);assert physical(actual)==physical(data[a:b]);assert csv(z,q)[-(b-a):]==csv(z,p+'/full')[a+2:b+2];assert native(z,q,b)[0]==native(z,p+'/full',b)[0]
 return data
with zipfile.ZipFile(here/'WINDOWS.zip') as w,zipfile.ZipFile(here/'UBUNTU.zip') as u,zipfile.ZipFile(here/'DIAGNOSTIC.zip') as d,zipfile.ZipFile(root/'integration/f-ci/saltfarm-newton-work01/WINDOWS_CURRENT.zip') as gold:
 for label,z in [('WINDOWS',w),('DIAGNOSTIC',d)]:
  for name,digest in read(here/(label+'_FILES.json')).items():assert sha(z.read(name))==digest,name
 for opt in ('O0','O2'):
  p=f'current-accept-{opt}';data=cold(w,p,p+'/restart{a}-{b}');g=f'accept-{opt}/full';assert physical(data)==physical(rows(gold,g));assert csv(w,p+'/full')==csv(gold,g)
  meta=json.loads(w.read(f'current-{opt}/BUILD.json'));identity=meta['identity'];direct=identity['direct_day_kernel'];assert direct['protocol']=='swap5-direct-day-kernel-1'
  for key,name in [('bridge_sha256','direct_day_kernel.f90'),('host_sha256','direct_day_kernel.py')]:assert direct[key]==sha(w.read('actual-source/'+name))
  for day in (109,111,365,367,453,455,1460,1461):
   payload,m=native(w,p+'/full',day);assert payload==native(gold,g,day)[0];assert m['binding']['build']['direct_day_kernel']==direct
  for name,digest in provenance['generated_original_sources'][opt].items():assert sha(w.read(f'current-{opt}/'+name))==digest
  udp=f'accept-{opt}';ud=cold(u,udp,udp+'/restart{a}-{b}');um=json.loads(u.read(f'qualified-{opt}/BUILD.json'));assert um['identity']['direct_day_kernel']['protocol']==direct['protocol']
  assert json.loads(u.read(udp+'/RESULT.json'))['status']=='FULL_PASS'
  assert len(current['comparison'][opt]['refusals'])==6 and current['windows'][opt]['status']=='FULL_PASS'
 assert physical(rows(u,'accept-O0/full'))==physical(rows(u,'accept-O2/full'))
 # Audit private full controls and actual kernel-only replay against the golden data.
 for i,(mode,opt) in enumerate((('pipe','O2'),('direct','O2'),('direct','O2'),('pipe','O2'),('direct','O0'))):
  p=f'full/run{i}-{mode}-{opt}';data=rows(d,p);balance(data);assert physical(data)==physical(rows(gold,f'accept-{opt}/full'));assert csv(d,p)==csv(gold,f'accept-{opt}/full')
  for day in (109,111,365,367,453,455,1460,1461):assert native(d,p,day)[0]==native(gold,f'accept-{opt}/full',day)[0]
 for i,mode in enumerate(('pipe','direct','direct','pipe')):
  receipts=json.loads(d.read(f'kernel-replay/run{i}-{mode}/receipts.json'));data=rows(gold,'accept-O2/full');assert len(receipts)==1461
  for day,(r,v) in enumerate(zip(data,receipts),1):assert v[:3]==[1,day,day] and v[3]==r['kernel_residual_cm'] and v[4]==r['bottom_outward_cm']
 for key in ('full_O2','kernel_only_actual1461'):
  v=analysis[key];assert v['pipe_mean']==statistics.mean(v['pipe_seconds']) and v['direct_mean']==statistics.mean(v['direct_seconds']);assert v['fraction_saved']==1-v['direct_mean']/v['pipe_mean'];assert max(v['direct_seconds'])<min(v['pipe_seconds'])
print('CURRENT_WINDOWS_UBUNTU_O0_O2_FOUR_FULL_PERIODS_TWENTY_COLD_WINDOWS_SOURCES_BALANCES_NATIVE_AND_ACTUAL_KERNEL_REPLAY_VERIFIED')
