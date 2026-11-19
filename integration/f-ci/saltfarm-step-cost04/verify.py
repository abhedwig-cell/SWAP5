"""Read-only verification of actual full trajectories and private CSV trial."""
from pathlib import Path
import hashlib,io,json,math,re,statistics,zipfile
here=Path(__file__).resolve().parent;root=here.parents[2];read=lambda p:json.loads(p.read_bytes());sha=lambda b:hashlib.sha256(b).hexdigest()
for name,digest in read(here/'SEAL.json').items():assert sha((here/name).read_bytes())==digest,name
result=read(here/'RESULT.json');analysis=read(here/'ANALYSIS.json');restart=read(here/'RESTART.json')
def rows(z,p):return [json.loads(x) for x in z.read(p+'/daily.jsonl').splitlines()]
def physical(data):return [{k:v for k,v in r.items() if k not in ('column','revision')} for r in data]
def csv(z,p):return [x for x in z.read(p+'/original/result_output.csv').decode().splitlines() if x.strip() and not x.startswith('*')]
def native(z,p,day):
 with zipfile.ZipFile(io.BytesIO(z.read(p+f'/accepted-column-1-day-{day}.zip'))) as n:return {k:n.read(k) for k in ('result.end','macro.bin')}
def balance(data):
 for r in data:
  assert r['committed'] and abs(r['kernel_residual_cm'])<=1e-10
  f,s,e=r['external_flux_cm'],r['stock_start_cm'],r['stock_end_cm'];water=math.fsum([*f[:7],*(-v for v in f[7:]),*s,*(-v for v in e)])
  end,delta,rain,irrig,bottom,drain,decay,uptake,reported=r['solute_ledger_mg_cm2'];solute=math.fsum([end,-r['solute_start_mg_cm2'],-rain,-irrig,-bottom,drain,decay,uptake])
  assert water==r['independent_residual_cm'] and solute==r['solute_independent_residual_mg_cm2'] and abs(water)<=1e-10 and abs(solute)<=1e-10 and abs(reported)<=1e-10
with zipfile.ZipFile(here/'raw.zip') as z,zipfile.ZipFile(root/'integration/f-ci/saltfarm-newton-work01/WINDOWS_CURRENT.zip') as golden:
 for p,digest in read(here/'FILES.json').items():assert sha(z.read(p))==digest,p
 gp='accept-O2/full';gd=rows(golden,gp);gc=csv(golden,gp);assert len(gd)==1461
 for group in ('profile','csv','full'):
  runs=result[group];assert len(runs)==(4 if group=='full' else 2)
  for i,r in enumerate(runs):
   p=group+'/'+('run'+str(i)+'-'+r['mode'] if group=='full' else 'run'+str(i)+'-candidate-clock');n=1461 if group=='full' else 365;data=rows(z,p);assert [v['day'] for v in data]==list(range(1,n+1));balance(data);assert physical(data)==physical(gd[:n]);assert csv(z,p)==gc[:n+2]
   for day in ((109,111,365,367,453,455,1460,1461) if group=='full' else (109,111)):assert native(z,p,day)==native(golden,gp,day)
   if group!='full':
    values=list(map(int,z.read(p+'/PERF_CLOCK.txt').decode().split()[1:]));assert len(values)==27 and values[:13]==[9527]*13
    for j,phase in enumerate(r['phases'].values()):assert phase['seconds']==values[j+13]/values[26] and phase['calls']==values[j]
    assert r['iterations']==28281 and r['headcalc_calls']==9527
  if group!='full':
   p=group+'/run0-candidate-clock';q=group+'/restart-candidate';data=rows(z,q);balance(data);assert physical(data)==physical(rows(z,p)[109:111]);assert csv(z,q)[-2:]==csv(z,p)[111:113];assert native(z,q,111)==native(z,p,111)
 for r in restart['full']:
  a,b=r['start'],r['end'];p='full/run1-candidate';q=f'full/restart{a}-{b}';data=rows(z,q);balance(data);assert physical(data)==physical(rows(z,p)[a:b]);assert csv(z,q)[-(b-a):]==csv(z,p)[a+2:b+2];assert native(z,q,b)==native(z,p,b)
 mean=statistics.mean
 assert analysis['full_mean_fraction_saved']==1-mean(analysis['candidate_seconds'])/mean(analysis['control_seconds'])
 for name,value in analysis['phase_means_seconds'].items():assert value==mean(r['phases'][name]['seconds'] for r in result['profile'])
 assert analysis['decision']=='REJECTED_NO_RELIABLE_WHOLE_RUNTIME_GAIN'
print('FOUR_FULL_PERIODS_FOUR_PROFILES_SEVEN_COLD_WORKERS_EXACT_BALANCES_AND_CLOCKS_VERIFIED')
