#!/usr/bin/env python3
"""Preregistered local closure controls and eventwise physical comparisons."""
from __future__ import annotations
import argparse,collections,hashlib,json,re
from pathlib import Path
from analyze_sw_rib_top03_explicit_layer import parse,key,diff,reference_ready


def number(s):
    # Fortran's default exponent width omits E for the unavailable huge sentinel.
    if 'e' not in s.lower():s=re.sub(r'(?<=\d)([+-]\d{3})$',r'E\1',s)
    return float(s)


def control(r):
    item=dict(case=r['case'],roots=[],status=None,independent=None,tangent=None)
    for line in r['stdout'].splitlines():
        x=line.split()
        if not x:continue
        if x[0]=='ROOT':item['roots'].append(dict(seed=int(x[1]),status=int(x[2]),iterations=int(x[3]),q=number(x[4]),residual=number(x[5]),interface=number(x[6])))
        if x[0]=='CONTROL':item.update(status=int(x[1]),q=number(x[2]),residual=number(x[3]),interface_error=number(x[4]),seed_head_error=number(x[5]),seed_flux_error=number(x[6]))
        if x[0]=='INDEPENDENT':item['independent']=list(map(number,x[1:]))
        if x[0]=='TANGENT':item['tangent']=list(map(number,x[1:]))
        if x[0] in ['TANGENT_UNAVAILABLE','TANGENT_BRANCH_CROSSING']:item['tangent_unavailable']=x[0]
    assert item['status'] is not None
    if item['status']==1:
        assert item['residual']<=1e-10 and item['interface_error']<=1e-9
        assert item['seed_head_error']<=1e-7 and item['seed_flux_error']<=1e-9
        assert item['independent'] is not None and max(item['independent'])<=1e-10
        if item['tangent']:
            t=item['tangent'];assert t[2]<=1e-6+1e-4*abs(t[1]) and t[5]<=1e-6+1e-4*abs(t[4])
    return item


def main():
    ap=argparse.ArgumentParser();ap.add_argument('build',type=Path);ap.add_argument('output',type=Path)
    ap.add_argument('--previous',type=Path,required=True);ap.add_argument('--source',required=True);ap.add_argument('--canonical',required=True)
    a=ap.parse_args();x0=(a.build/'o0/records.json').read_bytes();x2=(a.build/'o2/records.json').read_bytes()
    raw=json.loads(x0);other=json.loads(x2)
    projected=lambda rs:[{k:r[k] for k in ['case','returncode','stdout']} for r in rs]
    assert projected(raw)==projected(other)
    old={key(r['case']):r for r in json.loads((a.previous/'o0/records.json').read_bytes())}
    inherited=[r for r in raw if r['case']['analytic']==0 and r['case']['mode'] in [1,2]]
    assert len(inherited)==54 and all(r==old[key(r['case'])] for r in inherited)
    controls=[control(r) for r in raw if r['case']['analytic']==2]
    assert len(controls)==468
    analytical=[parse(r) for r in raw if r['case']['analytic']==1]
    assert len(analytical)==18 and all(r['complete'] and r['analytic'][1]<=1e-9 and r['analytic'][2]<=1e-10 for r in analytical)
    trajectories={key(r['case']):parse(r) for r in raw if r['case']['analytic']==0}
    candidate_audits=[];stops=[]
    for r in raw:
        if r['case']['analytic']!=0:continue
        for line in r['stdout'].splitlines():
            t=line.split()
            if t and t[0]=='CONTACT':
                v=list(map(number,t[2:]));candidate_audits.append(dict(case=r['case'],event=int(t[1]),face_residual=v[0],interface_error=v[1],flux_error=v[2],interface_head=v[3],q=v[4]))
                assert v[0]<=1e-10 and v[1]<=1e-9 and v[2]<=1e-10
            if t and t[0] in ['STOP_CONTACT','CONTACT_UNAVAILABLE','STOP']:
                stops.append(dict(case=r['case'],line=line,returncode=r['returncode']))
    comparisons=[]
    for R in [0.5,1.0]:
        for wet in [0,1]:
            ca=dict(mode=1,L=0.2,R=R,m=32,ns=512,wet=wet,mean=6,analytic=0)
            cb=dict(ca,mode=6,wet=0)
            for event in range(1,7):
                ar=reference_ready(trajectories,ca,event,True);br=reference_ready(trajectories,cb,event,True)
                aa=trajectories[key(ca)]['events'].get(event);bb=trajectories[key(cb)]['events'].get(event)
                d=dict(R_day=R,prewetted=bool(wet),event=event,explicit_reference=ar,reduced_reference=br,physical_equivalence=None)
                if aa is not None and bb is not None:
                    error=diff(aa,bb);budget={k:0.005+0.02*abs(aa[k]) for k in ['top','bottom','interface']}
                    budget.update(water_l1=0.005,head_inf=0.5)
                    within={k:error[k]<=budget[k] for k in budget}
                    d.update(explicit=aa,reduced=bb,difference=error,budget=budget,within=within)
                    if ar['ready'] and br['ready']:d['physical_equivalence']=all(within.values())
                comparisons.append(d)
    available=[c for c in controls if c['status']==1];tangents=[c for c in available if c['tangent']]
    r=dict(schema='swap5.sw_rib_top03.nonlinear_contact.v1',date='2026-10-02',source_postimage=a.source,canonical_inspected=a.canonical,
           production_code_changed=False,production_admission=False,records_per_build=len(raw),O0_O2_physical_records_exact=True,
           O0_O2_raw_records_exact=x0==x2,raw_O0_sha256=hashlib.sha256(x0).hexdigest(),raw_O2_sha256=hashlib.sha256(x2).hexdigest(),
           inherited_trajectories_exact=54,analytical_controls=18,analytical_max_head_error_cm=max(c['analytic'][1] for c in analytical),
           analytical_max_flux_error_cm_day=max(c['analytic'][2] for c in analytical),local_control_count=468,
           local_status_counts=dict(collections.Counter(str(c['status']) for c in controls)),local_available=len(available),
           local_max_independent_face_error=max((max(c['independent']) for c in available),default=None),
           local_max_interface_head_error=max((c['interface_error'] for c in available),default=None),
           local_max_seed_head_difference=max((c['seed_head_error'] for c in available),default=None),
           local_tangent_available=len(tangents),local_tangent_unavailable=dict(collections.Counter(c.get('tangent_unavailable') for c in available if not c['tangent'])),
           local_max_flux_tangent_error=max((c['tangent'][2] for c in tangents),default=None),
           local_max_interface_tangent_error=max((c['tangent'][5] for c in tangents),default=None),
           candidate_audits=candidate_audits,
           max_mass_error_cm=max(abs(e[k]) for row in trajectories.values() for e in row['events'].values() for k in ['mass','solver_mass']),
           trajectory_counts=[dict(mode=k[0],wet=k[1],complete=k[2],count=v) for k,v in sorted(collections.Counter((c['case']['mode'],c['case']['wet'],c['complete']) for c in trajectories.values()).items())],
           physical_verdict_counts=dict(collections.Counter(str(c['physical_equivalence']) for c in comparisons)),
           local_controls=controls,comparisons=comparisons,stopped_cases=stops,
           scope='Finite-thickness stationary test-only closure with current-candidate K and matched physical interface. Multistart agreement is bounded evidence, not global uniqueness. No layer storage or transaction admission.')
    a.output.write_text(json.dumps(r,indent=2)+'\n')
    print(json.dumps({k:v for k,v in r.items() if k not in ['local_controls','comparisons','candidate_audits','stopped_cases']},indent=2))
    for c in comparisons:
        if c['event'] in [1,6]:print(json.dumps({k:c.get(k) for k in ['R_day','prewetted','event','physical_equivalence','difference','within']}))

if __name__=='__main__':main()
