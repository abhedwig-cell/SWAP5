"""Read-only independent physical/native audit; no model or timing reruns."""
from pathlib import Path
import hashlib,io,json,math,zipfile
P=Path(__file__).resolve().parent
sha=lambda raw:hashlib.sha256(raw).hexdigest()
for name,digest in json.loads((P/'SEAL.json').read_bytes()).items():assert sha((P/name).read_bytes())==digest,name
q=json.loads((P/'RESULT.json').read_bytes());assert q['status']=='NO_PRODUCTION_OPTIMIZATION_QUALIFIED' and not q['production_changed'] and not q['tolerances_changed']
def rows(z,p):return [json.loads(v) for v in z.read(p+'/daily.jsonl').splitlines()]
def physical(r):return [{k:v for k,v in x.items() if k not in ('column','revision')} for x in r]
def csv(z,p):return [v for v in z.read(p+'/original/result_output.csv').decode().splitlines() if v.strip() and not v.startswith('*')]
def balance(data):
 for r in data:
  assert r['committed'] and abs(r['kernel_residual_cm'])<=1e-10
  f,s,e=r['external_flux_cm'],r['stock_start_cm'],r['stock_end_cm'];water=math.fsum([*f[:7],*(-v for v in f[7:]),*s,*(-v for v in e)])
  end,delta,rain,irrig,bottom,drain,decay,uptake,reported=r['solute_ledger_mg_cm2'];solute=math.fsum([end,-r['solute_start_mg_cm2'],-rain,-irrig,-bottom,drain,decay,uptake])
  assert water==r['independent_residual_cm'] and solute==r['solute_independent_residual_mg_cm2'] and abs(water)<=1e-10 and abs(solute)<=1e-10 and abs(reported)<=1e-10
def native(z,p,day):
 with zipfile.ZipFile(io.BytesIO(z.read(p+f'/accepted-column-1-day-{day}.zip'))) as n:
  values={k:n.read(k) for k in ('result.end','macro.bin')};meta=json.loads(n.read('checkpoint.json'));assert meta['files']=={k:sha(v) for k,v in values.items()};return values,meta
with zipfile.ZipFile(P/'RAW.zip') as z,zipfile.ZipFile(P.parent/'saltfarm-guard-cost05/COMPOSITION_WINDOWS.zip') as golden:
 for name,digest in json.loads((P/'FILES.json').read_bytes()).items():assert sha(z.read(name))==digest,name
 expected=rows(golden,'accept-O2/full')
 for i,mode in enumerate(('original','typed','typed','original')):
  p=f'full/run{i}-{mode}';data=rows(z,p);assert len(data)==1461 and physical(data)==physical(expected);balance(data);assert csv(z,p)==csv(golden,'accept-O2/full')
  for day in (109,111,365,367,453,455,1460,1461):
   value,meta=native(z,p,day);assert value==native(golden,'accept-O2/full',day)[0];assert meta['binding']['private_typed_probe06']['mode']==mode
 for low,high in ((109,111),(365,367),(453,455),(1460,1461),(109,1461)):
  p=f'full/restart{low}-{high}';actual=rows(z,p);balance(actual);assert physical(actual)==physical(expected[low:high]);assert csv(z,p)[-(high-low):]==csv(golden,'accept-O2/full')[low+2:high+2];assert native(z,p,high)[0]==native(golden,'accept-O2/full',high)[0]
 legacy=z.read('original431-reference.csv');actual=z.read('original431/result_output.csv');assert sha(legacy)==q['original_reference']['old_csv_sha256']
 a,b=actual.decode().splitlines(),legacy.decode().splitlines();assert len(a)==len(b)==1469;different=[i for i,(x,y) in enumerate(zip(a,b)) if x!=y];assert different==[4] and a[4].startswith('* Generated at:') and b[4].startswith('* Generated at:')
print('FOUR_FULL_O2_FIVE_EXACT_COLD_NATIVE_WATER_SOLUTE_AND_LITERAL_ORIGINAL_RECORDS_VERIFIED_NO_SPEEDUP_ADMITTED')
