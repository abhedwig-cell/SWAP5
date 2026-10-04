"""Reconstruct cell-5 Darcy balance from observation-only HeadCalc output.

The frozen 10cm-cell fixture has no sinks/sources and saturated cells6:10.
SWAP qbot is positive into soil. Thus the cell5 balance is
K5*((h4-h5)/10+1) = 10*delta_theta5/dt - qbot.
This diagnoses a saturation-crossing event; it does not alter acceptance.
Usage: python analyze_fpe_a28_saturation_event.py log.txt output.json
"""
import json,re,sys
from pathlib import Path
NUMBER=r'[+-]?(?:\d+\.\d*|\.\d+|\d+)(?:[EeDd][+-]?\d+)?'
def values(text):
 return [float(v.replace('D','E')) for v in re.findall(NUMBER,text)]
records=[];record={}
for line in Path(sys.argv[1]).read_text().splitlines():
 if 'A28_SAT_EQUATION' in line:
  record=dict(dt=values(line.split('dt=')[1].split('q=')[0])[0],
              q=values(line.split('q=')[1].split('residual=')[0])[0])
 if 'A28_SAT_HEAD' in line:
  record['old']=values(line.split('old=')[1].split('new=')[0])
  record['new']=values(line.split('new=')[1])
 if 'A28_SAT_WATER' in line:
  record['delta']=values(line.split('delta=')[1].split('cap=')[0])
 if 'A28_SAT_FLUX' in line:
  record['k']=values(line.split('kmean=')[1].split('source=')[0])
  assert max(abs(v) for v in values(line.split('source=')[1].split('sink=')[0]))==0
  assert max(abs(v) for v in values(line.split('sink=')[1]))==0
  records.append(record)
rows=[]
for record in records:
 if record['old'][4]<0 and record['new'][4]>0:
  assert all(v>0 for v in record['old'][5:])
  assert all(v==0 for v in record['delta'][5:])
  h4=record['new'][3];h5=record['new'][4];k=record['k'][4]
  delta=record['delta'][4];q=record['q'];dt=record['dt']
  predicted=h4+10-10*(10*delta/dt-q)/k
  rows.append(dict(dt_day=dt,old_h5_cm=record['old'][4],new_h5_cm=h5,
                   theta_deficit=delta,predicted_h5_cm=predicted,
                   equation_error_cm=abs(predicted-h5),
                   postfill_algebraic_h5_cm=h4+10+10*q/k,
                   deficit_pressure_offset_cm=100*delta/dt/k))
assert rows
error=max(row['equation_error_cm'] for row in rows)
assert error<1e-10 # reconstruction tolerance; no transaction gate is changed
result=dict(status='SATURATION_EVENT_STORAGE_DEFICIT_EXPLAINS_PRESSURE_JUMP',
            crossing_steps=len(rows),max_equation_error_cm=error,crossings=rows)
Path(sys.argv[2]).write_text(json.dumps(result,indent=2)+'\n')
print(f'SATURATION_DARCY_RECONSTRUCTION=PASS crossings={len(rows)} max_error_cm={error:.17g}')
