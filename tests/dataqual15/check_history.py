"""Verify contiguous native restart segments and measured original-reference differences.

Session interruption is not a successful process exit. A complete history requires
all original days, byte-identical incoming checkpoints, one executable/source
identity, and a final successful native completion. No rebinding is permitted.
"""
import argparse,csv,hashlib,json,math,struct
from pathlib import Path
from checkpoint_layout import layout

def check(segments,reference):
 sha=lambda raw:hashlib.sha256(raw).hexdigest()
 rows=lambda p:list(csv.DictReader(p.open()))
 ref=list(csv.DictReader(l for l in reference.read_text().splitlines()if l.strip()and not l.startswith('*')))
 budgets=[];crops=[];records=[];prior=None;identity=None;captures={}
 for folder in segments:
  b=rows(folder/'budget.csv');c=rows(folder/'crop.csv');assert b and len(b)==len(c)
  first,last=int(b[0]['day']),int(b[-1]['day'])
  launch=folder/'LAUNCH.json'
  if launch.exists():r=json.loads(launch.read_text())
  else:
   # The first day1 run predates durable LAUNCH metadata. Its original
   # application binding contains the executable and complete source digest.
   r=json.loads((folder/'application.binding').read_text())
  current=(r['executable_sha256'],r['source_sha256'])
  if identity is None:identity=current
  assert current==identity,'native executable or scientific source changed'
  if prior is None:assert first==1
  else:
   assert first==int(budgets[-1]['day'])+1,'gap or overlap in original days'
   origin=(folder/'restart-origin.bin').read_bytes()
   assert origin==prior,'incoming checkpoint is not exact preceding endpoint'
   if r.get('restart_sha256'):assert sha(origin)==r['restart_sha256']
  for i,(water,crop)in enumerate(zip(b,c)):
   assert int(water['day'])==first+i==int(crop['day'])
   assert all(math.isfinite(float(v))for v in [*water.values(),*crop.values()])
   assert abs(float(water['residual_cm']))<1e-10
   assert abs(float(water['water_end_cm'])-float(water['water_start_cm'])-float(water['input_cm'])+float(water['output_cm']))<1e-10
   assert abs(float(water['potential_cm'])-float(water['uptake_cm'])-float(water['drought_cm'])-float(water['oxygen_cm']))<1e-10
  prior=(folder/'checkpoint.bin').read_bytes();assert layout(prior)['clock']==last
  for f in [*folder.glob('checkpoint-*.bin'),folder/'checkpoint.bin']:
   raw=f.read_bytes();day=int(layout(raw)['clock'])
   if day in captures:assert captures[day]==raw
   captures[day]=raw
  terminal=json.loads((folder/'RESULT.json').read_text())if(folder/'RESULT.json').exists()else None
  records.append(dict(folder=folder.name,first_day=first,last_day=last,checkpoint_sha256=sha(prior),native_terminal=terminal is not None,returncode=terminal['returncode']if terminal else None,seconds=terminal['seconds']if terminal else None))
  budgets+=b;crops+=c
 last=int(budgets[-1]['day']);assert len(ref)>last
 differences={}
 for field,old in [('water_end_cm','WTOT'),('potential_cm','TPOT'),('uptake_cm','TACT')]:differences[old]=max(abs(float(r[field])-float(ref[int(r['day'])][old]))for r in budgets)
 for field,old in [('wrt','WRT'),('wlv','WLV'),('wst','WST'),('wso','WSO'),('pwrt','PWRT'),('dvs','DVS'),('tsum','TSUM'),('rd','RD'),('rdpot','RDPOT')]:differences[old]=max(abs(float(r[field])-float(ref[int(r['day'])][old]))for r in crops)
 # Source grass HRVDM/PHRVDM are annual counters, whereas the new joint
 # continuation intentionally keeps project totals. Sum completed source years.
 totals={};carry=[0.,0.]
 for day,row in enumerate(ref):
  if day and row['DATE'][:4]!=ref[day-1]['DATE'][:4]:
   carry=[carry[i]+float(ref[day-1][k])for i,k in enumerate(['HRVDM','PHRVDM'])]
  totals[day]=[carry[i]+float(row[k])for i,k in enumerate(['HRVDM','PHRVDM'])]
 harvest=[]
 for day,raw in sorted(captures.items()):
  m=layout(raw)['management'];_,actual,potential,cut,pcut=struct.unpack_from('=iddi i'.replace(' ',''),raw,m)
  harvest.append(dict(day=day,actual_kg_ha=actual,potential_kg_ha=potential,source_actual_kg_ha=totals[day][0],source_potential_kg_ha=totals[day][1],actual_difference_kg_ha=actual-totals[day][0],potential_difference_kg_ha=potential-totals[day][1],next_cut=cut,next_potential_cut=pcut))
 final=records[-1];complete=last==1827 and final['native_terminal']and final['returncode']==0
 return dict(status='COMPLETE_ORIGINAL_EXECUTION'if complete else'BOUNDED_ORIGINAL_EXECUTION',completed_days=last,contiguous_from_day1=True,same_build_checkpoint_chain_exact=True,full_original_execution=complete,scientific_equivalence=False,segments=records,maximum_water_residual_cm=max(abs(float(r['residual_cm']))for r in budgets),maximum_heat_accounting_residual_j_cm2=max(abs(float(r['heat_residual_j_cm2']))for r in budgets),maximum_reference_differences=differences,harvest_at_native_checkpoints=harvest,reference_sha256=sha(reference.read_bytes()),executable_sha256=identity[0])

if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--segments',type=Path,nargs='+',required=True);p.add_argument('--reference',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
 report=check(a.segments,a.reference);a.output.write_text(json.dumps(report,indent=2)+'\n');print(json.dumps({k:v for k,v in report.items()if k!='harvest_at_native_checkpoints'},indent=2))
