"""Recompute diagnostic clocks, actual balances, exact controls and own restart."""
from pathlib import Path
import hashlib,io,json,math,re,statistics,zipfile
here=Path(__file__).resolve().parent;root=here.parents[2];sha=lambda b:hashlib.sha256(b).hexdigest();read=lambda p:json.loads(p.read_bytes());seal=read(here/'SEAL.json');runs=read(here/'RESULT.json');analysis=read(here/'ANALYSIS.json')
for file,key in [('raw.zip','sha256'),('FILES.json','files_sha256'),('RESULT.json','result_sha256'),('ANALYSIS.json','analysis_sha256'),('PROVENANCE.json','provenance_sha256')]:assert sha((here/file).read_bytes())==seal[key]
def rows(z,p):return [json.loads(s) for s in z.read(p).splitlines()]
def physical(data):return [{k:v for k,v in r.items() if k not in ('column','revision')} for r in data]
def csv(z,p):return [s for s in z.read(p).decode().splitlines() if s.strip() and not s.startswith('*')]
def native(z,p):
 with zipfile.ZipFile(io.BytesIO(z.read(p))) as n:return {k:n.read(k) for k in ('result.end','macro.bin')}
def balance(data):
 for r in data:
  assert r['committed'] and abs(r['kernel_residual_cm'])<=1e-10
  f,s,e=r['external_flux_cm'],r['stock_start_cm'],r['stock_end_cm'];water=math.fsum([*f[:7],*(-v for v in f[7:]),*s,*(-v for v in e)])
  end,delta,rain,irrig,bottom,drain,decay,uptake,reported=r['solute_ledger_mg_cm2'];solute=math.fsum([end,-r['solute_start_mg_cm2'],-rain,-irrig,-bottom,drain,decay,uptake])
  assert water==r['independent_residual_cm'] and solute==r['solute_independent_residual_mg_cm2'] and abs(water)<=1e-10 and abs(solute)<=1e-10 and abs(reported)<=1e-10
assert len(runs)==12
with zipfile.ZipFile(here/'raw.zip') as z,zipfile.ZipFile(root/'integration/f-ci/saltfarm-newton-work01/raw.zip') as old,zipfile.ZipFile(root/'integration/f-ci/saltfarm-newton-work01/WINDOWS_CURRENT.zip') as accepted:
 for p,d in read(here/'FILES.json').items():assert sha(z.read(p))==d,p
 for i,r in enumerate(runs):
  tag=r['mode']+('-clock' if r['instrumented'] else '-plain');p=f'run{i}-{tag}';data=rows(z,p+'/daily.jsonl');assert [v['day'] for v in data]==list(range(1,366));balance(data)
  source,sourcep=(old,'timing/0-control/') if r['mode']=='control' else (accepted,'accept-O2/full/')
  assert physical(data)==physical(rows(source,sourcep+'daily.jsonl')[:365]);assert csv(z,p+'/original/result_output.csv')==csv(source,sourcep+'original/result_output.csv')[:367]
  golden,gp=(old,'trace365b/run/') if r['mode']=='control' else (accepted,'accept-O2/full/')
  assert native(z,p+'/accepted-column-1-day-109.zip')==native(golden,gp+'accepted-column-1-day-109.zip')
  hist=re.findall(r'^\s+(\d+)\s+(\d+)\s+(\d+)\s*$',z.read(p+'/original/swap.log').decode(),re.M);assert sum(int(n)*int(c) for n,c,b in hist)==r['iterations'];assert sum(int(c) for n,c,b in hist)==r['headcalc_calls']==9527
  if r['instrumented']:
   values=list(map(int,z.read(p+'/PERF_CLOCK.txt').decode().split()[1:]));assert len(values)==17
   for j,(name,phase) in enumerate(r['phases'].items()):assert phase['calls']==values[j] and phase['seconds']==values[j+8]/values[16]
   assert sum(values[6:8])==r['iterations'] and values[:6]==[9527]*6
 for mode in ('control','candidate'):
  i=next(i for i,r in enumerate(runs) if r['mode']==mode and r['instrumented']);p=f'run{i}-{mode}-clock';q='restart-'+mode;actual=rows(z,q+'/daily.jsonl');balance(actual);assert physical(actual)==physical(rows(z,p+'/daily.jsonl')[109:111]);assert csv(z,q+'/original/result_output.csv')[-2:]==csv(z,p+'/original/result_output.csv')[111:113];assert native(z,q+'/accepted-column-1-day-111.zip')==native(z,p+'/accepted-column-1-day-111.zip')
 controls=[r for r in runs if r['instrumented'] and r['mode']=='control'];mean=statistics.mean;loop=mean(r['phases']['ordinary_iteration']['seconds']+r['phases']['padding_iteration']['seconds'] for r in controls);wall=mean(r['wall'] for r in controls);assert loop/wall==analysis['attribution']['newton_body_fraction_of_wall']
 for name,group in [('plain_ABBA',runs[:4]),('clock_ABBA',runs[4:8]),('clock_BAAB',runs[8:])]:
  for mode in ('control','candidate'):
   selected=[r for r in group if r['mode']==mode];assert [r['wall'] for r in selected]==analysis[name][mode]['walls'];assert mean(r['wall'] for r in selected)==analysis[name][mode]['wall_mean']
  assert 1-analysis[name]['candidate']['wall_mean']/analysis[name]['control']['wall_mean']==analysis[name]['wall_fraction_saved']
 pad=mean(r['phases']['padding_iteration']['seconds']/r['phases']['padding_iteration']['calls'] for r in controls);ordinary=mean(r['phases']['ordinary_iteration']['seconds']/r['phases']['ordinary_iteration']['calls'] for r in controls);estimate=6848*pad-81*ordinary
 assert estimate==analysis['attribution']['estimated_removed_net_newton_seconds'] and estimate/wall==analysis['attribution']['estimated_fraction_whole_wall_saved']
print('12_BOUNDED_CONTROLS_CLOCKS_BALANCES_PHYSICAL_CSV_NATIVE_AND_TWO_COLD_WORKERS_VERIFIED')
