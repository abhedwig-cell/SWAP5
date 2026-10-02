#!/usr/bin/env python3
"""Compare isolated guarded Newton directions with persisted unguarded research."""
import argparse,csv,hashlib,json
from pathlib import Path
ap=argparse.ArgumentParser();ap.add_argument('--logdir',type=Path,default=Path('/tmp'));args=ap.parse_args()
root=Path(__file__).resolve().parents[2]
out=root/'integration/sw-rib-top03/evidence/newton_guard';out.mkdir(parents=True,exist_ok=True)
def key(r):return tuple(r[k] for k in ('geometry','bottom_mode','profile','history','steps'))
baseline={}
for g in (2,3):
    p=root/f'integration/sw-rib-top03/evidence/surface_transition/geometry{g}_O0.csv'
    for r in csv.DictReader(p.open()):baseline[key(r)]=r
results={};hashes={}
for cap in ('1','0.1'):
    records=[]
    for g in (2,3):
        p=args.logdir/f'top03-guard-g{g}-c{cap}.log'
        hashes[p.name]=hashlib.sha256(p.read_bytes()).hexdigest()
        blocks=[];stops=[];changes=[];header=None
        for l in p.read_text().splitlines():
            if l.startswith('geometry,'):
                header=l.split(',');blocks.append([]);stops.append([]);changes.append([])
            elif header and l.startswith(f'{g},'):
                v=next(csv.reader([l]));assert len(v)==len(header);blocks[-1].append(dict(zip(header,v)))
            elif l.startswith('STOP,'):stops[-1].append(l)
            elif l.startswith('REGIME_CHANGE,'):changes[-1].append(l)
        assert len(blocks)==2 and all(len(b)==351 for b in blocks)
        def stable(r):return {k:(v.strip() if k=='solver_route' else float(v)) for k,v in r.items() if k!='cpu_seconds'}
        assert [stable(r) for r in blocks[0]]==[stable(r) for r in blocks[1]]
        assert stops[0]==stops[1] and changes[0]==changes[1]
        with (out/f'cap{cap}_geometry{g}_O0.csv').open('w') as f:
            w=csv.DictWriter(f,fieldnames=header);w.writeheader();w.writerows(blocks[0])
        (out/f'cap{cap}_geometry{g}_stops_O0.csv').write_text('\n'.join(stops[0])+'\n')
        records.extend(blocks[0])
    repaired=[];new=[];retained=[];diffs=[];control=0
    for r in records:
        a=baseline[key(r)];ok=r['stop_code']=='0';oldok=a['stop_code']=='0'
        assert abs(float(r['ledger_residual_cm']))<=1e-10
        assert abs(float(r['max_step_soil_residual_cm']))<=1e-10
        if int(r['profile'])==3 and int(r['history']) in (1,2):
            assert ok
            extra=.02 if r['history']=='2' else 0.
            assert abs(float(r['transfer_cm'])+1.1875+extra)<=1e-12
            control+=1
        item={'key':key(r),'completed':int(r['completed']),'iterations':int(r['iterations'])}
        if ok and not oldok:repaired.append(item)
        elif not ok and oldok:new.append(item)
        elif not ok:retained.append(item)
        else:diffs.append(abs(float(r['transfer_cm'])-float(a['transfer_cm'])))
    results[cap]={'trajectories_per_build':len(records),'O0_O2_identity':True,
        'analytical_controls_pass':control,'failures':len(new)+len(retained),
        'repaired_count':len(repaired),'new_failure_count':len(new),
        'within_solve_switches':sum(int(r['within_solve_switches']) for r in records),
        'max_aggregate_ledger_cm':max(abs(float(r['ledger_residual_cm'])) for r in records),
        'max_top_difference_both_complete_cm':max(diffs),
        'iterations_total':sum(int(r['iterations']) for r in records),
        'baseline_iterations_total':sum(int(r['iterations']) for r in baseline.values()),
        'repaired':repaired,'new_failures':new,'retained_failure_count':len(retained)}
sources=['tests/fapp/make_top03_newton_guard_probe.py','tests/fapp/run_sw_rib_top03_newton_guard.sh','tests/fapp/analyze_sw_rib_top03_newton_guard.py','src/legacy/b1_10_port/headcalc.f90']
result={'scope':'isolated direction-scaling research, no production candidate/receipt/commit',
 'preregistration_commit':'8559048762c44ce3223f42e46b446f5503b99e48',
 'decision':'DIRECTION_CAP_REMOVES_EXTREME_SWITCHING_BUT_IS_NOT_SUFFICIENT_REPAIR',
 'production_qualified':False,'variants':results,'log_sha256':hashes,
 'source_sha256':{p:hashlib.sha256((root/p).read_bytes()).hexdigest() for p in sources}}
(root/'integration/sw-rib-top03/TOP03_NEWTON_GUARD_RESULT.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({cap:{k:v for k,v in r.items() if k not in ('repaired','new_failures')} for cap,r in results.items()},indent=2))
