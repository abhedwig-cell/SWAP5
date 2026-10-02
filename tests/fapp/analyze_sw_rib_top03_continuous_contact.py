#!/usr/bin/env python3
"""Independent SciPy continuum oracle, competing-FV roots and fixed budgets."""
from __future__ import annotations
import argparse,collections,hashlib,json,math,warnings
from pathlib import Path
import scipy
from scipy.integrate import quad,IntegrationWarning
from scipy.optimize import brentq
from analyze_sw_rib_top03_explicit_layer import parse,key,diff,reference_ready
from analyze_sw_rib_top03_nonlinear_contact import number


def conductivity(h,ks):
    tr,ts,alpha,n,l=0.032,0.423,0.0135,1.455,0.365
    m=1-1/n
    tc=tr+(ts-tr)/((1+abs(alpha*(-0.01))**n)**m)
    if h>=0:theta=ts
    elif h>-0.01:theta=min(tc+(ts-tc)/0.01*(h+0.01),ts)
    else:theta=tr+(ts-tr)/((1+abs(alpha*h)**n)**m)
    se=(theta-tr)/(ts-tr)
    if se>1-1e-6:return ks
    return ks*se**l*(1-(1-se**(1/m))**m)**2


def continuum(c,cut):
    H,hs,L,R,m=c['H'],c['hs'],c['L'],c['R'],c['m']
    d=0.25/m;ks=L/R;ksoil=conductivity(hs,4.75);rm=d/ksoil;es=hs-d
    jsat=(H+L-es)/(R+rm)
    def integral(j):
        hi=es+j*rm
        value=0;err=0
        if hi<cut:
            value,err=quad(lambda h:conductivity(h,ks)/(j-conductivity(h,ks)),hi,min(cut,H),epsabs=1e-12,epsrel=1e-12,limit=200)
        start=max(hi,cut)
        if H>start:value+=(H-start)*ks/(j-ks)
        return value,err
    if es+jsat*rm>=cut:
        return -jsat,es+jsat*rm,0,0
    j=brentq(lambda j:integral(j)[0]-L,ks*(1+1e-10),jsat,xtol=1e-12,rtol=1e-14,maxiter=100)
    value,err=integral(j)
    return -j,es+j*rm,abs(value-L),err


def main():
    ap=argparse.ArgumentParser();ap.add_argument('build',type=Path);ap.add_argument('output',type=Path)
    ap.add_argument('--previous',type=Path,required=True);ap.add_argument('--source',required=True);ap.add_argument('--canonical',required=True)
    a=ap.parse_args();b=a.build;x0=(b/'o0/records.json').read_bytes();x2=(b/'o2/records.json').read_bytes()
    raw=json.loads(x0);raw2=json.loads(x2)
    projection=lambda rs:[{k:r[k] for k in ['case','returncode','stdout']} for r in rs]
    assert projection(raw)==projection(raw2)
    previous={key(r['case']):r for r in json.loads((a.previous/'o0/records.json').read_bytes())}
    inherited=[r for r in raw if r['case']['analytic']==0 and r['case']['mode'] in [1,2]]
    assert len(inherited)==54 and all(r==previous[key(r['case'])] for r in inherited)
    local=[];branches=[];warnings_seen=[]
    for row in raw:
        c=row['case'];tokens=[line.split() for line in row['stdout'].splitlines()]
        if c['analytic']==2:
            x=next(t for t in tokens if t[0]=='CONTROL');v=list(map(number,x[2:]))
            item=dict(case=c,status=int(x[1]),q=v[0],length_residual=v[1],flux_identity_error=v[2],seed_head_error=v[3],seed_flux_error=v[4],interface_head=v[5],cut_head=v[6])
            assert item['status']==1,('continuum local unavailable',c,item)
            assert v[1]<=1e-11 and v[2]<=1e-10 and v[3]<=1e-7 and v[4]<=1e-9
            ks=c['L']/c['R'];sample_errors=[]
            for t in tokens:
                if t[0]=='K_SAMPLE':
                    h,k=map(number,t[1:]);error=abs(k-conductivity(h,ks));sample_errors.append(error)
                    assert error<=1e-11+1e-9*abs(k),('independent constitutive reconstruction mismatch',c,h,error)
            assert len(sample_errors)==9
            item['max_independent_K_error']=max(sample_errors)
            with warnings.catch_warnings(record=True) as w:
                warnings.simplefilter('always',IntegrationWarning)
                q,hi,res,err=continuum(c,item['cut_head'])
            warnings_seen += [dict(case=c,message=str(t.message)) for t in w]
            item.update(independent_q=q,independent_interface=hi,independent_length_residual=res,independent_quadrature_error=err,
                        independent_flux_error=abs(q-v[0]),independent_interface_error=abs(hi-v[5]))
            assert abs(q-v[0])<=1e-9 and abs(hi-v[5])<=1e-8 and res<=1e-9 and err<=1e-9
            t=next((t for t in tokens if t[0]=='TANGENT'),None)
            item['tangent']=list(map(number,t[1:])) if t else None
            if t:
                tv=item['tangent'];assert tv[2]<=1e-6+1e-4*abs(tv[1]) and tv[5]<=1e-6+1e-4*abs(tv[4])
            else:item['tangent_unavailable']=next(t[0] for t in tokens if t[0].startswith('TANGENT_'))
            local.append(item)
        if c['analytic']==3:
            roots={};profiles={};audits={}
            for t in tokens:
                if t[0]=='ROOT':roots[int(t[1])]=dict(status=int(t[2]),iterations=int(t[3]),q=number(t[4]),reported_residual=number(t[5]),interface=number(t[6]))
                if t[0]=='ROOT_PROFILE':profiles.setdefault(int(t[1]),[]).append(list(map(number,t[3:])))
                if t[0]=='ROOT_AUDIT':audits[int(t[1])]=list(map(number,t[2:]))
            for seed,p in profiles.items():
                n=2*c['m'];dz=c['L']/n;d=0.25/c['m'];ksoil=conductivity(c['hs'],4.75);ks=c['L']/c['R']
                assert len(p)==n;head=[x[0] for x in p];k=[conductivity(x,ks) for x in head]
                assert max(abs(k[i]/ks-p[i][1]) for i in range(n))<=1e-9
                flux=[-(ks+k[0])/dz*(c['H']-head[0]+0.5*dz)]
                for i in range(1,n):flux.append((head[i]-head[i-1]-dz)/(0.5*dz/k[i-1]+0.5*dz/k[i]))
                flux.append((c['hs']-d-head[-1]-0.5*dz)/(0.5*dz/k[-1]+d/ksoil))
                error=max(abs(x-y) for x,y in zip(flux,flux[1:]))
                iface=abs(head[-1]+0.5*dz+roots[seed]['q']*0.5*dz/k[-1]-roots[seed]['interface'])
                assert error<=1e-10 and iface<=1e-9 and abs(flux[-1]-roots[seed]['q'])<=1e-10
                roots[seed].update(independent_face_error=error,independent_interface_error=iface,
                                   saturation_mask=[x==ks for x in k])
            distinct=False;mask_diff=None;gap=None
            if 0 in profiles and 1 in profiles:
                gap=abs(roots[0]['q']-roots[1]['q']);distinct=gap>1e-9
                mask_diff=sum(x!=y for x,y in zip(roots[0]['saturation_mask'],roots[1]['saturation_mask']))
            cx=next(t for t in tokens if t[0]=='CONTINUUM')
            branches.append(dict(case=c,roots=roots,fortran_audits=audits,distinct_roots=distinct,flux_gap=gap,cut_branch_mask_differences=mask_diff,
                                 continuum_status=int(cx[1]),continuum_q=number(cx[2]),continuum_interface=number(cx[3])))
    assert len(local)==468 and len(branches)==8
    analytical=[parse(r) for r in raw if r['case']['analytic']==1]
    assert len(analytical)==18 and all(x['complete'] and x['analytic'][1]<=1e-9 and x['analytic'][2]<=1e-10 for x in analytical)
    trajectories={key(r['case']):parse(r) for r in raw if r['case']['analytic']==0}
    audits=[];stopped=[]
    for r in raw:
        if r['case']['analytic']!=0:continue
        for line in r['stdout'].splitlines():
            t=line.split()
            if t and t[0]=='CONTINUOUS':
                v=list(map(number,t[2:]));audits.append(dict(case=r['case'],event=int(t[1]),length_residual=v[0],flux_identity_error=v[1],flux_error=v[2],interface_head=v[3],q=v[4]))
                assert v[0]<=1e-11 and v[1]<=1e-10 and v[2]<=1e-10
            if t and t[0] in ['STOP_CONTACT','STOP','CONTACT_UNAVAILABLE']:stopped.append(dict(case=r['case'],line=line,returncode=r['returncode']))
    comparisons=[]
    for R in [0.5,1.0]:
        for wet in [0,1]:
            ca=dict(mode=1,L=0.2,R=R,m=32,ns=512,wet=wet,mean=6,analytic=0);cb=dict(ca,mode=6,wet=0)
            for event in range(1,7):
                ar=reference_ready(trajectories,ca,event,True);br=reference_ready(trajectories,cb,event,True)
                aa=trajectories[key(ca)]['events'].get(event);bb=trajectories[key(cb)]['events'].get(event)
                item=dict(R_day=R,prewetted=bool(wet),event=event,explicit_reference=ar,reduced_reference=br,physical_equivalence=None)
                if aa is not None and bb is not None:
                    error=diff(aa,bb);budget={k:0.005+0.02*abs(aa[k]) for k in ['top','bottom','interface']};budget.update(water_l1=0.005,head_inf=0.5)
                    within={k:error[k]<=budget[k] for k in budget};item.update(explicit=aa,reduced=bb,difference=error,budget=budget,within=within)
                    if ar['ready'] and br['ready']:item['physical_equivalence']=all(within.values())
                comparisons.append(item)
    tangents=[c for c in local if c['tangent']]
    r=dict(schema='swap5.sw_rib_top03.continuous_contact.v1',date='2026-10-02',source_postimage=a.source,canonical_inspected=a.canonical,
           production_code_changed=False,production_admission=False,records_per_build=len(raw),O0_O2_physical_records_exact=True,
           O0_O2_raw_records_exact=x0==x2,raw_O0_sha256=hashlib.sha256(x0).hexdigest(),raw_O2_sha256=hashlib.sha256(x2).hexdigest(),
           inherited_trajectories_exact=54,analytical_controls=18,analytical_max_head_error_cm=max(x['analytic'][1] for x in analytical),
           analytical_max_flux_error_cm_day=max(x['analytic'][2] for x in analytical),local_control_count=len(local),local_available=len(local),
           independent_scipy_version=scipy.__version__,independent_max_flux_error=max(c['independent_flux_error'] for c in local),
           independent_max_interface_error=max(c['independent_interface_error'] for c in local),
           independent_max_length_residual=max(c['independent_length_residual'] for c in local),
           local_max_length_residual=max(c['length_residual'] for c in local),local_max_flux_identity_error=max(c['flux_identity_error'] for c in local),
           local_max_seed_flux_difference=max(c['seed_flux_error'] for c in local),local_tangent_available=len(tangents),
           local_tangent_unavailable=dict(collections.Counter(c['tangent_unavailable'] for c in local if not c['tangent'])),
           local_max_flux_tangent_error=max(c['tangent'][2] for c in tangents),local_max_interface_tangent_error=max(c['tangent'][5] for c in tangents),
           verified_distinct_FV_root_points=sum(c['distinct_roots'] for c in branches),branch_audits=branches,
           trajectory_counts=[dict(mode=k[0],wet=k[1],complete=k[2],count=v) for k,v in sorted(collections.Counter((x['case']['mode'],x['case']['wet'],x['complete']) for x in trajectories.values()).items())],
           max_mass_error_cm=max(abs(e[k]) for row in trajectories.values() for e in row['events'].values() for k in ['mass','solver_mass']),
           physical_verdict_counts=dict(collections.Counter(str(c['physical_equivalence']) for c in comparisons)),
           candidate_audits=audits,local_controls=local,comparisons=comparisons,stopped_cases=stopped,independent_quadrature_warnings=warnings_seen,
           scope='Continuum stationary Darcy layer with unchanged constitutive jump, independently verified scalar integration. Discrete-FV competing roots retained; no evolving layer storage, receipt/restart or production admission.')
    a.output.write_text(json.dumps(r,indent=2)+'\n')
    print(json.dumps({k:v for k,v in r.items() if k not in ['local_controls','candidate_audits','comparisons','branch_audits','stopped_cases','independent_quadrature_warnings']},indent=2))
    for c in comparisons:
        if c['event'] in [1,6]:print(json.dumps({k:c.get(k) for k in ['R_day','prewetted','event','physical_equivalence','difference','within']}))

if __name__=='__main__':main()
