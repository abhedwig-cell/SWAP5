"""Independent short boundary science; reads original producers without replay."""
from pathlib import Path
import hashlib,json,sys,zipfile,subprocess
from decimal import Decimal,localcontext
import argparse
p=argparse.ArgumentParser();p.add_argument('--evidence',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
R=Path(__file__).resolve().parents[2];E=a.evidence.resolve();sys.path[:0]=[str(R/'tests/nomacro_drainage'),str(R/'tests/nomacro_scheduled_subsurface')]
from ria12_boundary_native import native
from ria12_science import original_samples,standard_cde_daily
from ordinary_pond_evidence import physical
from implicit_conductivity_forensics import water
SHA=lambda b:hashlib.sha256(b).hexdigest();observed=[]
for kind in ('water','cde'):
 for drain,bottom in ((0,5),(0,6),(0,8),(1,5),(1,8)):
  label=f'ria12-boundary-{kind}-d{drain}-b{bottom}-O0-short-v1';root=E/label;sample_root=E/(label+'-original-samples');q=json.loads((root/'RESULT.json').read_text());sample=json.loads((sample_root/'RESULT.json').read_text());bundle=Path(q['build_root']);meta=json.loads((bundle/'BUILD.json').read_text());inputs=Path(q['input_root']);parameters=(sample_root/'original-parameters.bin').read_bytes()
  assert q['days']==2 and q['status']=='ACTUAL_RIA12_BOUNDARY_TWO_DAY_PHYSICAL_NATIVE_COLD_USER_OUTPUT_PASS_NOT_ADMITTED' and q['source']==q['actual_completion_head']==q['build']['actual_completion_head']=='2d5a36917e678f4f5ab47ae2c0edf545cd0412e1'
  assert SHA((bundle/'BUILD.json').read_bytes())==q['actual_BUILD_sha256'] and meta['identity']['original_output']['original_ria12_boundary']['drainage']==drain and meta['identity']['original_output']['original_ria12_boundary']['bottom']==bottom
  assert sample['profile_RESULT_sha256']==SHA((root/'RESULT.json').read_bytes()) and sample['daily_sha256']==SHA((root/'trajectory/daily.jsonl').read_bytes()) and sample['original_parameter_bytes_sha256']==SHA(parameters)
  rows=lambda p:[json.loads(line) for line in (p/'daily.jsonl').read_text().splitlines()]
  data=rows(root/'trajectory');cold=rows(root/'own-1');assert len(data)==2 and physical(cold)==physical(data[1:])
  original_samples(sample_root,Path(sample['component_root']),sample,inputs,data)
  proofs=[]
  for folder,actual in ((root/'trajectory',data),(root/'own-1',cold)):
   proof=water(actual);native_days=[]
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
  with zipfile.ZipFile(root/'trajectory/accepted-column-1-day-2.zip') as a,zipfile.ZipFile(root/'own-1/accepted-column-1-day-2.zip') as b:assert all(a.read(n)==b.read(n) for n in ('macro.bin','result.end'))
  peak=Decimal(0)
  with localcontext() as c:
   c.prec=60
   for row in data:
    d=lambda v:Decimal(str(v));residual=sum(map(d,row['stock_start_cm']))+sum(map(d,row['external_flux_cm'][:7]))-sum(map(d,row['external_flux_cm'][7:]))-sum(map(d,row['stock_end_cm']));assert abs(residual)<=Decimal('1e-10');peak=max(peak,abs(residual))
  observed.append(dict(case=label,actual_producer=q['source'],actual_BUILD_sha256=q['actual_BUILD_sha256'],decimal_global_peak_cm=str(peak),original_theta_stock_peak_cm=sample['maximum_original_theta_stock_difference_cm'],warm_cold=proofs))
record=dict(status='ALL10_ACTUAL_TWO_DAY_RIA_BOUNDARY_GLOBAL_CDE_ORIGINAL_STOCK_PARAMETER_BYTES_AND_EXACT_COLD_PASS_NOT_QUALIFIED',actual_observer=subprocess.check_output(['git','rev-parse','HEAD'],cwd=R).decode().strip(),contexts=observed,model_executions=0,compiler_executions=0,full35_periods_replayed=0,canonical_admission=False,whole_scope='PARTIAL / NOT_QUALIFIED')
with a.output.open('x') as f:json.dump(record,f,indent=2)
print(record['status'])
