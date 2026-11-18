"""Read-only recomputation from actual trajectories and native checkpoints."""
from pathlib import Path
from decimal import Decimal
import hashlib,io,json,math,re,zipfile
here=Path(__file__).resolve().parent;root=here.parents[2];sha=lambda b:hashlib.sha256(b).hexdigest();load=lambda p:json.loads(p.read_bytes());seal=load(here/'SEAL.json');index=load(here/'FILES.json');r=load(here/'RESULT.json')
assert sha((here/'RESULT.json').read_bytes())==seal['result_sha256'];assert sha((here/'FILES.json').read_bytes())==seal['index_sha256'];assert sha((here/seal['archive']).read_bytes())==seal['sha256'];assert not r['tolerances_changed'] and not r['fixed_RC3_changed']
# Compare checkout text without claiming portable model qualification. Raw
# executed Windows source hashes remain immutable in each actual build.
for p,digest in r['production_source_lf_sha256'].items():assert sha((root/p).read_bytes().replace(b'\r\n',b'\n'))==digest,p
def records(z,p):return [json.loads(s) for s in z.read(p).decode().splitlines()]
def physical(data):return [{k:v for k,v in x.items() if k not in ('column','revision')} for x in data]
def native(z,p):
 with zipfile.ZipFile(io.BytesIO(z.read(p))) as q:return {n:q.read(n) for n in ('result.end','macro.bin')}
def csvlines(z,p):return [s for s in z.read(p).decode().splitlines() if s.strip() and not s.startswith('*')]
def check(data):
 assert data and all(x['committed'] and abs(x['independent_residual_cm'])<=1e-10 and abs(x['kernel_residual_cm'])<=1e-10 and abs(x['solute_independent_residual_mg_cm2'])<=1e-10 for x in data)
with zipfile.ZipFile(here/seal['archive']) as z:
 for p,digest in index.items():assert sha(z.read(p))==digest,p
 full={}
 for opt in ('O0','O2'):
  prefix='accept-'+opt;data=records(z,prefix+'/full/daily.jsonl');full[opt]=data;check(data);assert [d['day'] for d in data]==list(range(1,1462));report=r['full_'+opt]
  assert max(abs(d['independent_residual_cm']) for d in data)==report['budgets']['max_water_cm'];assert math.fsum(d['independent_residual_cm'] for d in data)==report['budgets']['sum_water_residual_cm']
  identity=json.loads(z.read('qualified-'+opt+'/BUILD.json'))['identity'];assert '-'+opt in identity['donor_flags'] and '-'+opt in identity['kernel_flags'];assert identity['water_polish_policy']=='strict-water-half-interior-polish-v1'
  assert sha(z.read('qualified-'+opt+'/BUILD.json'))==report['build_sha256']
  for window in report['restarts']:
   start,end=window['start'],window['end'];sub=prefix+f'/restart{start}-{end}';actual=records(z,sub+'/daily.jsonl');check(actual);assert physical(actual)==physical(data[start:end]);assert csvlines(z,sub+'/original/result_output.csv')[-(end-start):]==csvlines(z,prefix+'/full/original/result_output.csv')[start+2:end+2];assert native(z,sub+f'/accepted-column-1-day-{end}.zip')==native(z,prefix+f'/full/accepted-column-1-day-{end}.zip')
 assert physical(full['O0'])==physical(full['O2'])
 for i,mode in enumerate(('control','candidate','candidate','control')):
  prefix=f'timing/{i}-{mode}';data=records(z,prefix+'/daily.jsonl');check(data);assert len(data)==1461
  if mode=='candidate':assert physical(data)==physical(full['O2'])
  elif i==0:control=data
  else:assert physical(data)==physical(control)
  hist=re.findall(r'^\s+(\d+)\s+(\d+)\s+(\d+)\s*$',z.read(prefix+'/original/swap.log').decode(),re.M);assert sum(int(n)*int(c) for n,c,b in hist)==r['timing']['sequence'][i]['iterations']
 assert r['work']['saved_iterations']==27612
 failed=records(z,'no-polish1461/run/daily.jsonl');assert len(failed)==454 and all(x['committed'] for x in failed[:-1]);assert failed[-1]['committed'] is False and abs(failed[-1]['independent_residual_cm'])>1e-10
 assert physical(records(z,'trace365b/run/daily.jsonl'))==physical(control[:365]);assert physical(records(z,'candidate-count365/run/daily.jsonl'))==physical(full['O2'][:365])
 comparison=json.loads(z.read('COMPARISON.json'));assert sha(z.read('original431.csv'))==comparison['original_reference_sha256'];assert comparison['scientific_equivalence'].startswith('NOT_QUALIFIED')
 import csv
 parsed=lambda p:list(csv.DictReader(csvlines(z,p)))
 a=parsed('accept-O2/full/original/result_output.csv');b=parsed('timing/0-control/original/result_output.csv');old=parsed('original431.csv');assert len(a)==len(b)==len(old)==1462;assert [d['DATE'] for d in a]==[d['DATE'] for d in old]
 assert set(comparison['fields'])==set(a[0])-{'DATE'}
 for k,v in comparison['fields'].items():
  assert max(abs(Decimal(x[k])-Decimal(y[k])) for x,y in zip(a,b))==Decimal(v['candidate_control_max']);assert max(abs(Decimal(x[k])-Decimal(y[k])) for x,y in zip(a,old))==Decimal(v['candidate_original_max'])
 print('FULL_O0_O2_BALANCES_EXACT_NATIVE_CSV_RESTART_REFUSAL_AND_ORIGINAL_COMPARISON_VERIFIED')
