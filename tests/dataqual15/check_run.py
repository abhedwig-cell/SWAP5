"""Independent original-project balances, checkpoint equality and source comparison."""
import argparse,csv,hashlib,json,math,struct
from pathlib import Path
from checkpoint_layout import layout,payload
p=argparse.ArgumentParser();p.add_argument('--run',type=Path,required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--reference',type=Path,required=True);p.add_argument('--full-run',type=Path);p.add_argument('--peer',type=Path);a=p.parse_args();run=a.run.resolve();rows=lambda f:list(csv.DictReader(f.open()));budget=rows(run/'budget.csv');crop=rows(run/'crop.csv');assert budget and len(budget)==len(crop)
for i,r in enumerate(budget):
 assert all(math.isfinite(float(v))for v in r.values());assert int(r['day'])==int(budget[0]['day'])+i
 assert abs(float(r['residual_cm']))<1e-10
 assert abs(float(r['water_end_cm'])-float(r['water_start_cm'])-float(r['input_cm'])+float(r['output_cm']))<1e-10
 assert abs(float(r['potential_cm'])-float(r['uptake_cm'])-float(r['drought_cm'])-float(r['oxygen_cm']))<1e-10
for r in crop:assert all(math.isfinite(float(v))for v in r.values())
last=int(budget[-1]['day']);raw=(run/'checkpoint.bin').read_bytes();decoded=layout(raw);assert decoded['clock']==last
ref=list(csv.DictReader(l for l in a.reference.read_text().splitlines()if l.strip()and not l.startswith('*')));assert len(ref)>last
reference_differences={}
for field,old in [('water_end_cm','WTOT'),('potential_cm','TPOT'),('uptake_cm','TACT')]:reference_differences[old]=max(abs(float(r[field])-float(ref[int(r['day'])][old]))for r in budget)
for field,old in [('wrt','WRT'),('wlv','WLV'),('wst','WST'),('wso','WSO'),('pwrt','PWRT'),('dvs','DVS'),('tsum','TSUM'),('rd','RD'),('rdpot','RDPOT')]:reference_differences[old]=max(abs(float(r[field])-float(ref[int(r['day'])][old]))for r in crop)
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();report=dict(status='ORIGINAL_EXECUTION_BALANCE_CHECK_PASS_NOT_WHOLE_MODEL_EQUIVALENCE',first_day=int(budget[0]['day']),last_day=last,rows=len(budget),maximum_water_residual_cm=max(abs(float(r['residual_cm']))for r in budget),maximum_heat_accounting_residual_j_cm2=max(abs(float(r['heat_residual_j_cm2']))for r in budget),maximum_reference_differences=reference_differences,checkpoint_sha256=sha(run/'checkpoint.bin'),reference_sha256=sha(a.reference))
if a.full_run:
 full=a.full_run.resolve();end=full/f'checkpoint-{last}.bin';end=end if end.exists()else full/'checkpoint.bin';assert raw==end.read_bytes(),'same-build endpoint checkpoint mismatch'
 all_budget=rows(full/'budget.csv');all_crop=rows(full/'crop.csv');selected={int(r['day'])for r in budget}
 assert budget==[r for r in all_budget if int(r['day'])in selected];assert crop==[r for r in all_crop if int(r['day'])in selected];report['same_build_restart_exact']=True
if a.peer:
 peer=a.peer.resolve();other=peer/f'checkpoint-{last}.bin';other=other if other.exists()else peer/'checkpoint.bin';assert payload(raw)==payload(other.read_bytes()),'O0/O2 physical continuation differs';report['O0_O2_physical_continuation_exact']=True
report['full1827_from_day1']=int(budget[0]['day'])==1 and last==1827
report['scientific_equivalence']=False
a.output.write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2))
