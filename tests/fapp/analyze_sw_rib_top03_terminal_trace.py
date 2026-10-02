#!/usr/bin/env python3
"""Analyze observational and pressure-aware progress research."""
import argparse,csv,hashlib,json
from pathlib import Path
ap=argparse.ArgumentParser();ap.add_argument('--logdir',type=Path,default=Path('/tmp'));args=ap.parse_args()
root=Path(__file__).resolve().parents[2]
out=root/'integration/sw-rib-top03/evidence/terminal_trace';out.mkdir(parents=True,exist_ok=True)
def key(r):return tuple(r[k] for k in ('geometry','bottom_mode','profile','history','steps'))
baseline={}
for g in (2,3):
 for r in csv.DictReader((root/f'integration/sw-rib-top03/evidence/surface_transition/geometry{g}_O0.csv').open()):baseline[key(r)]=r
names=['geometry','bottom_mode','profile','history','steps','step','iteration','backtrack','dt','factor','old_norm','new_norm','Fmax','head_change','delta_max','old_top','new_top','old_bottom','new_bottom','qtop','qbot','Kbottom_frozen','Cbottom','jacdiag','bottom_residual','hmin','hmax','Kface','cp_tol','total_tol','head_metric','residual_sum']
variants={};hashes={}
for variant in ('stock','strict'):
 records=[];trace=[]
 for g in (2,3):
  p=args.logdir/f'top03-terminal-g{g}-{variant}.log';hashes[p.name]=hashlib.sha256(p.read_bytes()).hexdigest()
  blocks=[];traces=[];stops=[];changes=[];header=None
  for l in p.read_text().splitlines():
   if l.startswith('geometry,'):
    header=l.split(',');blocks.append([]);traces.append([]);stops.append([]);changes.append([])
   elif header and l.startswith(f'{g},'):
    v=next(csv.reader([l]));assert len(v)==len(header);blocks[-1].append(dict(zip(header,v)))
   elif l.startswith('ITER,'):
    v=next(csv.reader([l]))[1:];assert len(v)==len(names);traces[-1].append(dict(zip(names,map(float,v))))
   elif l.startswith('STOP,'):stops[-1].append(l)
   elif l.startswith('REGIME_CHANGE,'):changes[-1].append(l)
  assert len(blocks)==2 and all(len(b)==351 for b in blocks)
  def stable(r):return {k:(v.strip() if k=='solver_route' else float(v)) for k,v in r.items() if k!='cpu_seconds'}
  assert [stable(r) for r in blocks[0]]==[stable(r) for r in blocks[1]]
  assert traces[0]==traces[1] and stops[0]==stops[1] and changes[0]==changes[1]
  if variant=='stock':assert all(stable(r)==stable(baseline[key(r)]) for r in blocks[0])
  with (out/f'{variant}_geometry{g}_O0.csv').open('w') as f:
   w=csv.DictWriter(f,fieldnames=header);w.writeheader();w.writerows(blocks[0])
  (out/f'{variant}_geometry{g}_stops_O0.csv').write_text('\n'.join(stops[0])+'\n')
  for profile in (1,2,3):
   with (out/f'{variant}_geometry{g}_profile{profile}_trace_O0.csv').open('w') as f:
    w=csv.DictWriter(f,fieldnames=names);w.writeheader();w.writerows(t for t in traces[0] if int(t['profile'])==profile)
  records.extend(blocks[0]);trace.extend(traces[0])
 repaired=[];new=[];diffs=[];controls=0
 for r in records:
  a=baseline[key(r)];ok=r['stop_code']=='0';oldok=a['stop_code']=='0'
  assert abs(float(r['ledger_residual_cm']))<=1e-10
  if r['profile']=='3' and r['history'] in ('1','2'):
   assert ok;extra=.02 if r['history']=='2' else 0.
   assert abs(float(r['transfer_cm'])+1.1875+extra)<=1e-12;controls+=1
  if ok and not oldok:repaired.append(key(r))
  if not ok and oldok:new.append(key(r))
  if ok and oldok:diffs.append(abs(float(r['transfer_cm'])-float(a['transfer_cm'])))
 terminal=[t for t in trace if t['iteration']==80]
 failures={key(r) for r in records if r['stop_code']=='1'}
 # A complete-at-80 solve must not be misclassified as a failure.
 terminal_failed=[t for t in terminal if tuple(str(int(t[n])) for n in names[:5]) in failures]
 pressure_only=[t for t in terminal_failed if t['Fmax']<=t['cp_tol'] and abs(t['residual_sum'])<=t['total_tol'] and t['head_metric']>1e-12]
 growth=[t for t in trace if t['new_norm']>=t['old_norm'] and t['backtrack']<=16 and t['Fmax']<t['cp_tol'] and t['head_metric']>1e-12]
 variants[variant]={'O0_O2_identity':True,'baseline_numerical_identity':variant=='stock','trajectories_per_build':702,
 'analytical_controls_pass':controls,'failures':len(failures),'repaired_count':len(repaired),'new_failure_count':len(new),
 'terminal_failed_traces':len(terminal_failed),'terminal_pressure_only_failures':len(pressure_only),
 'observed_growth_shortcuts_while_pressure_not_converged':len(growth),
 'terminal_backtracking_exhaustions':sum(t['backtrack']>16 for t in terminal_failed),
 'max_aggregate_ledger_cm':max(abs(float(r['ledger_residual_cm'])) for r in records),
 'max_top_difference_both_complete_cm':max(diffs),'iterations_total':sum(int(r['iterations']) for r in records),
 'repaired':repaired,'new_failures':new}
result={'scope':'isolated terminal trace and pressure-aware line-search shortcut research',
 'source_checkpoint':'71bb2d49c68639df7b48df167380c007d82acf5a','production_qualified':False,
 'decision':'RESIDUAL_GROWTH_SHORTCUT_CONFIRMED__PARTIAL_REPAIR_NOT_SUFFICIENT_FOR_ADMISSION',
 'variants':variants,'log_sha256':hashes,'source_sha256':{}}
for p in ['tests/fapp/make_top03_terminal_trace_probe.py','tests/fapp/run_sw_rib_top03_terminal_trace.sh','tests/fapp/analyze_sw_rib_top03_terminal_trace.py']:
 result['source_sha256'][p]=hashlib.sha256((root/p).read_bytes()).hexdigest()
(root/'integration/sw-rib-top03/TOP03_TERMINAL_TRACE_RESULT.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({v:{k:x for k,x in r.items() if k not in ('repaired','new_failures')} for v,r in variants.items()},indent=2))
