#!/usr/bin/env python3
"""Bounded surface-transition research; never production admission."""
import argparse,csv,hashlib,json
from collections import Counter
from pathlib import Path

ap=argparse.ArgumentParser()
ap.add_argument('--logdir',type=Path,default=Path('/tmp'))
args=ap.parse_args()
root=Path(__file__).resolve().parents[2]
out=root/'integration/sw-rib-top03/evidence/surface_transition'
out.mkdir(parents=True,exist_ok=True)
rows=[];changes=[];hashes={};stops=[]
for geometry in (2,3):
    path=args.logdir/f'top03-surface-g{geometry}b.log'
    hashes[path.name]=hashlib.sha256(path.read_bytes()).hexdigest()
    builds=[];change_builds=[];stop_builds=[];header=None
    for line in path.read_text().splitlines():
        if line.startswith('geometry,'):
            header=line.split(',');builds.append([]);change_builds.append([]);stop_builds.append([])
        elif header and line.startswith(f'{geometry},'):
            values=next(csv.reader([line]));assert len(values)==len(header)
            builds[-1].append(dict(zip(header,values)))
        elif line.startswith('REGIME_CHANGE,'):change_builds[-1].append(line)
        elif line.startswith('STOP,'):stop_builds[-1].append(line)
    assert len(builds)==2 and all(len(b)==351 for b in builds)
    def stable(r):return {k:(v.strip() if k=='solver_route' else float(v)) for k,v in r.items() if k!='cpu_seconds'}
    assert [stable(r) for r in builds[0]]==[stable(r) for r in builds[1]]
    assert change_builds[0]==change_builds[1] and stop_builds[0]==stop_builds[1]
    with (out/f'geometry{geometry}_O0.csv').open('w') as f:
        w=csv.DictWriter(f,fieldnames=header);w.writeheader();w.writerows(builds[0])
    (out/f'geometry{geometry}_changes_O0.csv').write_text('\n'.join(change_builds[0])+'\n')
    (out/f'geometry{geometry}_stops_O0.csv').write_text('\n'.join(stop_builds[0])+'\n')
    rows.extend(builds[0]);changes.extend(change_builds[0]);stops.extend(stop_builds[0])

for r in rows:
    assert abs(float(r['ledger_residual_cm']))<=1e-10
    assert abs(float(r['max_step_soil_residual_cm']))<=1e-10
    if int(r['stop_code'])==0:assert int(r['completed'])==int(r['steps'])
    if int(r['history']) in (1,2):
        assert int(r['external_calls'])==int(r['evaluations'])
        assert int(r['flux_calls'])==0 and int(r['within_solve_switches'])==0
        assert int(r['accepted_regime_switches'])==0
        if int(r['profile'])==3:
            assert int(r['stop_code'])==0
            extra=.02 if int(r['history'])==2 else 0.
            assert abs(float(r['transfer_cm'])+1.1875+extra)<=1e-12
            assert abs(float(r['storage_change_cm'])-extra)<=1e-12
            assert abs(float(r['bottom_cm'])+1.1875)<=1e-12

# Changing the prior local pond alone should not alter the soil trajectory.
paired=[]
for a in rows:
    if a['history']!='1':continue
    b=next(x for x in rows if x['geometry']==a['geometry'] and x['bottom_mode']==a['bottom_mode'] and x['profile']==a['profile'] and x['steps']==a['steps'] and x['history']=='2')
    for k in ('stop_code','completed','iterations'):
        assert a[k]==b[k],(k,a,b)
    if int(a['completed'])>0:
        assert abs(float(b['transfer_cm'])-float(a['transfer_cm'])+.02)<=1e-10
    paired.append({'geometry':int(a['geometry']),'bottom':int(a['bottom_mode']),'profile':int(a['profile']),'steps':int(a['steps']),'same_status_progress_iterations':True})

finest=[]
for r in rows:
    if r['steps']!='4096':continue
    finest.append({k:(r[k] if k=='solver_route' else float(r[k])) for k in r if k!='cpu_seconds'})
summary={'scope':'synthetic lower-boundary/soil/head-history factorial research only',
         'canonical_reviewed':'828df126e0c0d70f5cbfae51614bfc3b53e832a4',
         'preregistration_commit':'69b73e9cfd8187c3c1d2f327f0aebde2491b2f14',
         'O0_O2_identity':True,'trajectories_per_build':len(rows),
         'analytical_constant_saturated_controls':156,'constant_abrupt_pairs':len(paired),
         'max_aggregate_ledger_cm':max(abs(float(r['ledger_residual_cm'])) for r in rows),
         'failure_by_history':dict(Counter(r['history'] for r in rows if r['stop_code']!='0')),
         'within_solve_changes':len(changes),
         'records_with_within_solve_changes':sum(int(r['within_solve_switches'])>0 for r in rows),
         'failure_without_any_boundary_switch':sum(r['stop_code']!='0' and r['history'] in ('1','2') for r in rows),
         'all_failures_free_drainage':all(r['bottom_mode']=='7' for r in rows if r['stop_code']!='0'),
         'positive_qtop_exclusions':sum(r['stop_code']=='2' for r in rows),
         'log_sha256':hashes,'source_sha256':{},'finest_grids':finest,
         'decision':'SWITCHING_NOT_NECESSARY_FOR_FAILURE__RISING_HEAD_NOT_SUFFICIENT_REPAIR',
         'production_qualified':False}
for p in ['tests/fapp/test_sw_rib_top03_surface_transition.f90','tests/fapp/mod_top03_observed_top.f90','tests/fapp/run_sw_rib_top03_surface_transition.sh','tests/fapp/analyze_sw_rib_top03_surface_transition.py']:
    summary['source_sha256'][p]=hashlib.sha256((root/p).read_bytes()).hexdigest()
(root/'integration/sw-rib-top03/TOP03_SURFACE_TRANSITION_RESULT.json').write_text(json.dumps(summary,indent=2)+'\n')
print(json.dumps({k:v for k,v in summary.items() if k not in ('finest_grids','source_sha256','log_sha256')},indent=2))
