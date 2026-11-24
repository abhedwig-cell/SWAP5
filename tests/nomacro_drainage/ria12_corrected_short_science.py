"""Independent short boundary science; reads original producers without replay."""
from pathlib import Path
import hashlib,json,sys,zipfile,subprocess,math
from decimal import Decimal,localcontext
import argparse
p=argparse.ArgumentParser();p.add_argument('--evidence',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
R=Path(__file__).resolve().parents[2];E=a.evidence.resolve();sys.path[:0]=[str(R/'tests/nomacro_drainage'),str(R/'tests/nomacro_scheduled_subsurface')]
from ria12_corrected_native import native
from ria12_corrected_science import original_samples,standard_cde_daily
from ordinary_pond_evidence import physical
from implicit_conductivity_forensics import water
SHA=lambda b:hashlib.sha256(b).hexdigest();observed=[]
cases=[(kind,drain,bottom,f'ria12-corrected-{kind}-d{drain}-b{bottom}-O0-short-v1') for kind in ('water','cde') for drain,bottom in ((1,6),(0,5),(0,6),(0,8),(1,5),(1,8))]
cases += [(kind,1,6,f'ria12-corrected-{kind}-wet-primary-top-O0-short-v1') for kind in ('water','cde')]
cases += [(kind,drain,8,f'ria12-corrected-{kind}-wet8-d{drain}-O0-short-v1') for kind,drain in (('water',0),('cde',1))]
for kind,drain,bottom,label in cases:
  root=E/label;sample_root=E/(label+'-original-samples');q=json.loads((root/'RESULT.json').read_text());sample=json.loads((sample_root/'RESULT.json').read_text());bundle=Path(q['build_root']);meta=json.loads((bundle/'BUILD.json').read_text());inputs=Path(q['input_root']);parameters=(sample_root/'original-parameters.bin').read_bytes()
  assert q['days']==2 and q['status']=='ACTUAL_RIA12_CORRECTED_TWO_DAY_PHYSICAL_NATIVE_COLD_USER_OUTPUT_PASS_NOT_ADMITTED' and q['source']==q['actual_completion_head']==q['build']['actual_completion_head'] and q['source'] in ('aa8580218dff2de7f245e5596d2a5a71ee204c13','8d67858c5c28f9e73a8c1b62dd8aeab1fa59e549')
  assert SHA((bundle/'BUILD.json').read_bytes())==q['actual_BUILD_sha256'] and meta['identity']['original_output']['original_ria12_corrected']['drainage']==drain and meta['identity']['original_output']['original_ria12_corrected']['bottom']==bottom
  assert sample['profile_RESULT_sha256']==SHA((root/'RESULT.json').read_bytes()) and sample['daily_sha256']==SHA((root/'trajectory/daily.jsonl').read_bytes()) and sample['original_parameter_bytes_sha256']==SHA(parameters)
  rows=lambda p:[json.loads(line) for line in (p/'daily.jsonl').read_text().splitlines()]
  data=rows(root/'trajectory');cold=rows(root/'own-1');assert len(data)==2 and physical(cold)==physical(data[1:])
  original_samples(sample_root,Path(sample['component_root']),sample,inputs,data)
  proofs=[]
  for folder,actual in ((root/'trajectory',data),(root/'own-1',cold)):
   try:
    proof=water(actual)
   except ValueError as error:
    assert '-wet-primary-top-' in label and str(error)=='Whole actual implicit water inventory does not close'
    daily=[water([row]) for row in actual]
    assert all(actual[i]['stock_start_cm']==actual[i-1]['stock_end_cm'] for i in range(1,len(actual)))
    total=math.fsum([*actual[0]['stock_start_cm'],*(-v for v in actual[-1]['stock_end_cm']),*(v for row in actual for v in row['external_flux_cm'][:7]),*(-v for row in actual for v in row['external_flux_cm'][7:])])
    assert abs(total)>1e-10
    proof=dict(status='EXPECTED_EXTRA_WET_PRIMARY_GLOBAL_INVENTORY_REFUSAL_NOT_ADMITTED',error=str(error),whole_water_residual_cm=total,unchanged_water_limit_cm=1e-10,daily=daily)
   native_days=[]
   for path in folder.glob('accepted-column-1-day-*.zip'):
    day=int(path.stem.rsplit('-',1)[1]);row=next(r for r in actual if r['day']==day)
    with zipfile.ZipFile(path) as z:
     receipt=json.loads(z.read('checkpoint.json'));assert receipt['binding']==meta['binding'] and receipt['receipt']==row and all(SHA(z.read(n))==s for n,s in receipt['files'].items());native(z.read('macro.bin'),row,meta,parameters)
    native_days.append(day)
   chemical=None
   if kind=='cde':
    from groundwater_snow_forensics import clock
    chemical=dict(unchanged_ledger=clock.ledger(actual,len(actual)),actual_daily=standard_cde_daily(folder,actual,meta['project']['start_date']))
   proofs.append(dict(water=proof,solute=chemical,native_days=sorted(native_days)))
  with zipfile.ZipFile(root/'trajectory/accepted-column-1-day-2.zip') as warm_zip,zipfile.ZipFile(root/'own-1/accepted-column-1-day-2.zip') as cold_zip:assert all(warm_zip.read(n)==cold_zip.read(n) for n in ('macro.bin','result.end'))
  peak=Decimal(0)
  with localcontext() as c:
   c.prec=60
   for row in data:
    d=lambda v:Decimal(str(v));residual=sum(map(d,row['stock_start_cm']))+sum(map(d,row['external_flux_cm'][:7]))-sum(map(d,row['external_flux_cm'][7:]))-sum(map(d,row['stock_end_cm']));assert abs(residual)<=Decimal('1e-10');peak=max(peak,abs(residual))
  observed.append(dict(case=label,classification='NUMERICAL_FAILURE' if '-wet-primary-top-' in label else 'QUALIFIED_SHORT_NOT_ADMITTED',actual_producer=q['source'],actual_BUILD_sha256=q['actual_BUILD_sha256'],decimal_global_peak_cm=str(peak),original_theta_stock_peak_cm=sample['maximum_original_theta_stock_difference_cm'],warm_cold=proofs))
assert len(observed)==16 and sum(x['classification']=='NUMERICAL_FAILURE' for x in observed)==2
assert all(any(p['water'].get('status')=='EXPECTED_EXTRA_WET_PRIMARY_GLOBAL_INVENTORY_REFUSAL_NOT_ADMITTED' for p in x['warm_cold']) for x in observed if x['classification']=='NUMERICAL_FAILURE')
record=dict(status='FOURTEEN_ORIGINAL_DOMAIN_SHORTS_PASS_TWO_EXTRA_WET_PRIMARY_GLOBAL_REFUSALS_RETAINED_NOT_ADMITTED',qualified_original_short_contexts=14,extra_wet_primary_global_refusals=2,actual_observer=subprocess.check_output(['git','rev-parse','HEAD'],cwd=R).decode().strip(),contexts=observed,model_executions=0,compiler_executions=0,full35_periods_replayed=0,canonical_admission=False,whole_scope='PARTIAL / NOT_QUALIFIED')
with a.output.open('x') as f:json.dump(record,f,indent=2)
print(record['status'])
