#!/usr/bin/env python3
"""Analyze isolated controller research; passing checks are not admission."""
import argparse,csv,json,hashlib
from pathlib import Path
ap=argparse.ArgumentParser();ap.add_argument('--logdir',type=Path,default=Path('/tmp'));args=ap.parse_args()
root=Path(__file__).resolve().parents[2]
out=root/'integration/sw-rib-top03/evidence/temporal_controller';out.mkdir(parents=True,exist_ok=True)
all_rows=[];traces=[];hashes={}
for geometry in (2,3):
    path=args.logdir/f'top03-controller-g{geometry}c.log'
    hashes[str(path)]=hashlib.sha256(path.read_bytes()).hexdigest()
    builds=[];trace_builds=[];header=None
    for line in path.read_text().splitlines():
        if line.startswith('geometry,'):
            header=line.split(',');builds.append([]);trace_builds.append([])
        elif header and line.startswith(f'{geometry},'):
            builds[-1].append(dict(zip(header,next(csv.reader([line])))))
        elif line.startswith('TRACE,'):
            trace_builds[-1].append(line)
    assert len(builds)==2 and len(builds[0])==48
    def stable(r):return {k:float(v) for k,v in r.items() if k!='cpu_seconds'}
    assert [stable(r) for r in builds[0]]==[stable(r) for r in builds[1]]
    assert trace_builds[0]==trace_builds[1]
    for r in builds[0]:
        assert abs(float(r['ledger_cm']))<=1e-10
        if int(r['stop_code'])==0:assert abs(float(r['time_days'])-.25)<=1e-14
        else:assert float(r['time_days'])<.25
        r['build']='O0';all_rows.append(r)
    with (out/f'geometry{geometry}_O0.csv').open('w') as f:
        w=csv.DictWriter(f,fieldnames=list(builds[0][0]));w.writeheader();w.writerows(builds[0])
    (out/f'geometry{geometry}_trace_O0.csv').write_text('\n'.join(trace_builds[0])+'\n')
    traces.extend(trace_builds[0])
comparisons=[]
for r in all_rows:
    if int(r['policy'])==0:continue
    refs=[x for x in all_rows if x['geometry']==r['geometry'] and x['bottom_mode']==r['bottom_mode'] and x['profile']==r['profile'] and int(x['policy'])==0]
    ref=max(refs,key=lambda x:int(x['accepted']))
    c={k:float(r[k]) for k in ['geometry','bottom_mode','profile','policy','budget_cm','stop_code','accepted','rejected','time_days']}
    c['reference_complete']=int(ref['stop_code'])==0
    c['controller_complete']=int(r['stop_code'])==0
    if c['controller_complete'] and c['reference_complete']:
        c['top_difference_cm']=abs(float(r['top_cm'])-float(ref['top_cm']))
        c['relative_top_difference']=c['top_difference_cm']/abs(float(ref['top_cm']))
        dz=[.5,.5,1.,1.] if int(r['geometry'])==2 else [2.5]*40
        c['water_l1_difference_cm']=sum(abs(float(r[f'theta{i+1}'])-float(ref[f'theta{i+1}']))*d for i,d in enumerate(dz))
    comparisons.append(c)
result={'scope':'isolated research, no production candidate/receipt/commit',
        'source_checkpoint':'17fb8d0d15f04f3dcedfacc0e3338ddcdbd72fad plus persisted final observation/trace additions',
        'canonical_reviewed':'828df126e0c0d70f5cbfae51614bfc3b53e832a4',
        'O0_O2_identity':True,'grids_per_build':96,'controller_complete':sum(c['controller_complete'] for c in comparisons),
        'controller_trials':len(comparisons),'references_complete':sum(int(x['stop_code'])==0 for x in all_rows if int(x['policy'])==0),
        'reference_trials':24,'max_aggregate_ledger_cm':max(abs(float(x['ledger_cm'])) for x in all_rows),
        'log_sha256':hashes,'source_sha256':{str(p.relative_to(root)):hashlib.sha256(p.read_bytes()).hexdigest() for p in [root/'tests/fapp/test_sw_rib_top03_temporal_controller.f90',root/'tests/fapp/run_sw_rib_top03_temporal_controller.sh',Path(__file__).resolve()]},'comparisons':comparisons,
        'decision':'STATE_ONLY_THROUGHPUT_MASKING_CONFIRMED__LINEAR_TIME_BUDGET_CONTROLLER_FALSIFIED_AS_GENERAL_REPAIR',
        'production_qualified':False}
(root/'integration/sw-rib-top03/TOP03_TEMPORAL_CONTROLLER_RESULT.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({k:v for k,v in result.items() if k not in ('comparisons','log_sha256')},indent=2))
print('Completed comparisons:',json.dumps([c for c in comparisons if c['controller_complete']],indent=2))
