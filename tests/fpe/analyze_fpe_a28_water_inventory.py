"""Independent accepted-window inventory; no acceptance-gate modification.

Usage: python analyze_fpe_a28_water_inventory.py result.json log.txt output.json
The fixture has rainfall, matrix bottom flow, and distinct RFM deep receipts;
no evaporation, root extraction, drainage, runoff or irrigation is enabled.
Only the final two complete correctors at each t0 belong to that window.
Group by t0 because Fortran/Python stdout buffering can reorder their prints.
"""
import json,re,sys
from pathlib import Path

result=json.loads(Path(sys.argv[1]).read_text())
initial=result['initial_matrix_cm'];dt=result['dt_day']
water={}
pattern=re.compile(r'(\w+)=\s*(T|F|[+-]?(?:\d+\.?\d*|\.\d+)(?:[EeDd][+-]?\d+)?)')
for line in Path(sys.argv[2]).read_text().splitlines():
 if 'A28_CORRECTOR_WATER' in line:
  record={k:(v=='T' if v in ('T','F') else float(v.replace('D','E'))) for k,v in pattern.findall(line)}
  window=round(record['t0']/dt)+1
  water.setdefault(window,[]).append(record)
published=[water[row['window']][-2:] for row in result['rows']]
assert all(len(pair)==2 for pair in published)
rain=0.;bottom=[0.,0.];deep=[0.,0.];rows=[]
max_inventory_difference=0.;max_flux_difference=0.;max_local_residual=0.
for row,correctors in zip(result['rows'],published):
 rain+=row['rain_cm_day']*dt
 missing=[]
 for i,record in enumerate(correctors):
  assert record['complete']
  exchange=row[f'q{i+1}']*dt*86400.*100.
  max_flux_difference=max(max_flux_difference,abs(exchange-record['matrix_bottom']))
  # Incoming and outgoing bottom water may both occur during one window.
  receipt=record['output']-record['matrix_bottom']-(record['input']-row['rain_cm_day']*dt)
  deep[i]+=receipt;bottom[i]+=exchange
  unassigned=rain-(row['matrix'][i]+row['rfm'][i]-initial[i]-result['initial_rfm_cm'][i])-bottom[i]
  missing.append(unassigned)
  max_inventory_difference=max(max_inventory_difference,abs(unassigned-deep[i]))
  max_local_residual=max(max_local_residual,abs(record['storage_end']-record['storage_start']-record['input']+record['output']))
 rows.append(dict(window=row['window'],rain_cm=rain,unassigned_receipt_cm=missing,
                  direct_deep_receipt_cm=list(deep),weighted_receipt_cm=.35*missing[0]+.65*missing[1]))
output=dict(status='DISTINCT_DEEP_RECEIPT_ABSENT_FROM_MODFLOW_INTERFACE',
 source_result_sha256=__import__('hashlib').sha256(Path(sys.argv[1]).read_bytes()).hexdigest(),
 source_log_sha256=__import__('hashlib').sha256(Path(sys.argv[2]).read_bytes()).hexdigest(),
 max_inventory_vs_direct_difference_cm=max_inventory_difference,
 max_matrix_interface_difference_cm=max_flux_difference,max_local_mass_residual_cm=max_local_residual,
 interpretation='SWAP has a distinct accounted external RFM receipt; this fixture has no receiver ledger or MODFLOW publication for it. This is not a SWAP local mass failure.',rows=rows)
assert max_inventory_difference<1e-12 and max_flux_difference<1e-12 and max_local_residual<1e-12
Path(sys.argv[3]).write_text(json.dumps(output,indent=2)+'\n')
print(json.dumps({k:v for k,v in output.items() if k!='rows'}))
