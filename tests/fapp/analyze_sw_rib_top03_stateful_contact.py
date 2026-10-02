#!/usr/bin/env python3
"""Independent origin-K layer balance and matched explicit trajectory audit."""
import argparse,collections,hashlib,json
from pathlib import Path
from analyze_sw_rib_top03_explicit_layer import parse,key,diff,reference_ready
from analyze_sw_rib_top03_continuous_contact import conductivity

def theta(h):
    tr,ts,alpha,n=.032,.423,.0135,1.455;m=1-1/n
    at=lambda h:tr+(ts-tr)/(1+abs(alpha*h)**n)**m
    if h>=0:return ts
    if h>-.01:return min(at(-.01)+(ts-at(-.01))/.01*(h+.01),ts)
    return at(h)

def analyze(build,previous,source,canonical):
    x=(build/'o0/records.json').read_bytes();y=(build/'o2/records.json').read_bytes()
    raw=json.loads(x);assert raw==json.loads(y)
    inherited={key(r['case']):r for r in json.loads((previous/'o0/records.json').read_bytes())}
    keep=[r for r in raw if r['case']['analytic']==0 and r['case']['mode'] in [1,2]]
    assert len(keep)==54 and all(r==inherited[key(r['case'])] for r in keep)
    rows={key(r['case']):parse(r) for r in raw};profiles=[];lifecycles=[]
    for r in raw:
        c=r['case'];lines=[s.split() for s in r['stdout'].splitlines()]
        for s in lines:
            if s[0]=='LIFECYCLE_PASS':
                vals=list(map(float,s[1:]));assert max(map(abs,vals))<=1e-11
                lifecycles.append(dict(case=c,mass_errors_cm=vals))
        for s in lines:
            if s[0]!='LAYER_BINDING':continue
            event,policy=map(int,s[1:3]);H,hso,hs,dt,external,matrix=map(float,s[3:]);assert policy==0
            v=[list(map(float,t[3:])) for t in lines if t[0]=='LAYER_PROFILE' and int(t[1])==event]
            bottom=next(float(t[2]) for t in lines if t[0]=='LAYER_BOTTOM' and int(t[1])==event)
            n=2*c['m'];assert len(v)==n;dz=c['L']/n;d=.25/c['m'];ks=c['L']/c['R']
            h0=[t[0] for t in v];h=[t[1] for t in v];th=[theta(t) for t in h];th0=[theta(t) for t in h0]
            k=[conductivity(t,ks) for t in h0];ksoil=conductivity(hso,4.75)
            q=[(ks+conductivity(h[0],ks))/dz*(h[0]-H-.5*dz)]
            q += [(h[i]-h[i-1]-dz)/(.5*dz/k[i-1]+.5*dz/k[i]) for i in range(1,n)]
            q += [(hs-d-h[-1]-.5*dz)/(.5*dz/k[-1]+d/ksoil)]
            flux_error=max(abs(a-b) for a,b in zip(q,[t[3] for t in v]+[bottom]))
            theta_error=max(abs(a-t[2]) for a,t in zip(th,v))
            residual=max(abs(dz*(th[i]-th0[i])/dt+q[i]-q[i+1]) for i in range(n))
            storage=sum(dz*(a-b) for a,b in zip(th,th0))
            mass_error=abs(storage-external+matrix)
            interface_error=abs(h[-1]+.5*dz+q[-1]*.5*dz/k[-1]-(hs-d-q[-1]*d/ksoil))
            assert flux_error<=1e-10 and theta_error<=1e-12 and residual<=1e-10 and mass_error<=1e-11 and interface_error<=1e-10,(c,event,flux_error,residual,mass_error)
            profiles.append(dict(case=c,event=event,independent_flux_error_cm_day=flux_error,independent_theta_error=theta_error,independent_compartment_residual_cm_day=residual,independent_mass_error_cm=mass_error,interface_error_cm=interface_error))
    comparisons=[]
    for R in [.5,1]:
        for wet in [0,1]:
            a=dict(mode=1,L=.2,R=R,m=32,ns=512,wet=wet,mean=6,analytic=0);b=dict(a,mode=6)
            for e in range(1,7):
                ar=reference_ready(rows,a,e,True);br=reference_ready(rows,b,e,True)
                aa=rows[key(a)]['events'].get(e);bb=rows[key(b)]['events'].get(e)
                item=dict(R_day=R,prewetted=bool(wet),event=e,explicit_reference=ar,reduced_reference=br,physical_equivalence=None)
                if aa and bb:
                    error=diff(aa,bb);budget={k:.005+.02*abs(aa[k]) for k in ['top','bottom','interface']};budget.update(water_l1=.005,head_inf=.5)
                    within={k:error[k]<=budget[k] for k in budget}
                    item.update(difference=error,budget=budget,within=within)
                    if ar['ready'] and br['ready']:item['physical_equivalence']=all(within.values())
                comparisons.append(item)
    dynamic=[r for r in rows.values() if r['case']['analytic']==0 and r['case']['mode']==6]
    saturated=[r for r in rows.values() if r['case']['analytic']==1]
    assert len(saturated)==18 and all(r['complete'] and r['analytic'][1]<=1e-9 and r['analytic'][2]<=1e-10 for r in saturated)
    return dict(schema='swap5.top03.stateful_contact.v1',source_postimage=source,canonical_inspected=canonical,production_code_changed=False,production_admission=False,cases_per_build=len(raw),O0_O2_raw_records_exact=x==y,raw_sha256=hashlib.sha256(x).hexdigest(),inherited_trajectories_exact=54,saturated_controls=18,new_trajectories=len(dynamic),new_trajectories_completed=sum(r['complete'] for r in dynamic),stopped_trajectories=[dict(case=r['case'],stop=r['stop']) for r in dynamic if not r['complete']],max_soil_layer_mass_error_cm=max(abs(e['mass']) for r in rows.values() for e in r['events'].values()),physical_verdict_counts=dict(collections.Counter(str(c['physical_equivalence']) for c in comparisons)),comparisons=comparisons,independent_profile_audits=profiles,lifecycle_cases=lifecycles,scope='Time-discrete distributed storage reduction matching pinned SWKIMPL=0 explicit layer. Component candidate/restart gates only; no production receipt/runtime/restart admission.')

def main():
    p=argparse.ArgumentParser();p.add_argument('build',type=Path);p.add_argument('output',type=Path);p.add_argument('--previous',type=Path,required=True);p.add_argument('--source',required=True);p.add_argument('--canonical',required=True);a=p.parse_args()
    r=analyze(a.build,a.previous,a.source,a.canonical);a.output.write_text(json.dumps(r,indent=2)+'\n');print(json.dumps({k:v for k,v in r.items() if k not in ['comparisons','independent_profile_audits','lifecycle_cases']},indent=2));print('independent_profiles',len(r['independent_profile_audits']),'lifecycle_cases',len(r['lifecycle_cases']))
if __name__=='__main__':main()
