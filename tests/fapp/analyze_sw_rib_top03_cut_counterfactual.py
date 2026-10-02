#!/usr/bin/env python3
"""Classify declared constitutive counterfactual; never grant production admission."""
import csv, hashlib, json
from collections import Counter
from pathlib import Path
root=Path(__file__).resolve().parents[2]
out=root/'integration/sw-rib-top03/evidence/cut_counterfactual';out.mkdir(parents=True,exist_ok=True)
def key(r):return tuple(r[k] for k in ('geometry','bottom_mode','profile','history','steps'))
def stable(r):return {k:(v.strip() if k=='solver_route' else float(v)) for k,v in r.items() if k!='cpu_seconds'}
results={};hashes={}
for policy in ('stock','strict'):
 rows=[];baseline={};oracles=[]
 for g in (2,3):
  base=root/f'integration/sw-rib-top03/evidence/terminal_trace/{policy}_geometry{g}_O0.csv'
  baseline.update({key(r):r for r in csv.DictReader(base.open())})
  log=Path(f'/tmp/top03-counterfactual-g{g}-{policy}.log');hashes[log.name]=hashlib.sha256(log.read_bytes()).hexdigest()
  blocks=[];stops=[];header=None;oracle=[]
  for line in log.read_text().splitlines():
   if line.startswith('COUNTERFACTUAL_ORACLE,'):oracle.append(line)
   elif line.startswith('geometry,'):header=line.split(',');blocks.append([]);stops.append([])
   elif header and line.startswith(f'{g},'):
    v=next(csv.reader([line]));assert len(v)==len(header);blocks[-1].append(dict(zip(header,v)))
   elif line.startswith('STOP,'):stops[-1].append(line)
  assert len(blocks)==2 and all(len(b)==351 for b in blocks)
  assert len(oracle)==2 and oracle[0]==oracle[1]
  assert [stable(r) for r in blocks[0]]==[stable(r) for r in blocks[1]] and stops[0]==stops[1]
  for opt,b in enumerate(blocks):
   with (out/f'{policy}_geometry{g}_O{opt*2}.csv').open('w') as f:
    w=csv.DictWriter(f,fieldnames=header);w.writeheader();w.writerows(b)
  (out/f'{policy}_geometry{g}_stops_O0.csv').write_text('\n'.join(stops[0])+'\n')
  rows.extend(blocks[0]);oracles.append(oracle[0])
 repaired=[];retained=[];new=[];diffs=[];controls=0
 for r in rows:
  b=baseline[key(r)];ok=r['stop_code']=='0';oldok=b['stop_code']=='0'
  assert abs(float(r['ledger_residual_cm']))<=1e-10 and abs(float(r['max_step_soil_residual_cm']))<=1e-10
  if r['profile']=='3' and r['history'] in ('1','2'):
   assert ok;extra=.02 if r['history']=='2' else 0.
   assert abs(float(r['transfer_cm'])+1.1875+extra)<=1e-12;controls+=1
  if ok and not oldok:repaired.append(key(r))
  elif not ok and oldok:new.append(key(r))
  elif not ok:retained.append(key(r))
  if ok and oldok:
   diffs.append({k:abs(float(r[k])-float(b[k])) for k in ('transfer_cm','bottom_cm','storage_change_cm')})
 sequences=[]
 for g in ('2','3'):
  for profile in ('1','2'):
   for history in ('1','2','3'):
    seq=[{k:r[k] for k in ('steps','completed','stop_code','transfer_cm','bottom_cm','water_l1_diff_cm','head_inf_diff_cm')} for r in rows if r['geometry']==g and r['profile']==profile and r['history']==history and r['bottom_mode']=='7' and int(r['steps'])>=512]
    sequences.append({'geometry':g,'profile':profile,'history':history,'refinement':seq})
 results[policy]={'O0_O2_identity':True,'trajectories_per_build':len(rows),'oracle':oracles,
  'baseline_failures':sum(r['stop_code']!='0' for r in baseline.values()),'failures':len(retained)+len(new),
  'repaired_count':len(repaired),'new_failure_count':len(new),'retained_count':len(retained),
  'analytical_controls_pass':controls,'max_ledger_cm':max(abs(float(r['ledger_residual_cm'])) for r in rows),
  'max_complete_window_differences_cm':{k:max(d[k] for d in diffs) for k in diffs[0]},
  'iterations_total':sum(int(r['iterations']) for r in rows),'repaired':repaired,'new_failures':new,'retained':retained,
  'new_failures_by_bottom_mode':dict(Counter(k[1] for k in new)),
  'repairs_by_bottom_mode':dict(Counter(k[1] for k in repaired)),
  'free_drainage_finest_sequences':sequences}
result={'scope':'isolated declared conductivity counterfactual, stock/pressure-aware line search; no kernel or commit',
 'source_checkpoint':'e452ebab26523c825cda5e5fdd92b7911d009b0c',
 'decision':'REMOVING_K_SHORTCUT_ALONE_FALSIFIED_AS_ROBUST_REPAIR__NO_PRODUCTION_ADMISSION',
 'production_qualified':False,'reference_equivalence':False,'variants':results,'log_sha256':hashes}
result['source_sha256']={str(p.relative_to(root)):hashlib.sha256(p.read_bytes()).hexdigest() for p in [root/'tests/fapp'/n for n in ('make_top03_cut_counterfactual.py','run_sw_rib_top03_cut_counterfactual.sh','analyze_sw_rib_top03_cut_counterfactual.py')]}
(root/'integration/sw-rib-top03/TOP03_CUT_COUNTERFACTUAL_RESULT.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({p:{k:v for k,v in r.items() if k not in ('repaired','new_failures','retained','free_drainage_finest_sequences')} for p,r in results.items()},indent=2))
