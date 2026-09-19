#!/usr/bin/env python3
from __future__ import annotations
import argparse,json,math,pathlib

TR=0.02; TS=0.427494; ALPHA=0.021659; N=1.734737; M=1.0-1.0/N
KS=31.225016; ELL=0.98087; SE0=0.85; DEPTH=160.0; NINT=1024; DT=0.0008

def theta_h(h):
    if not(math.isfinite(h) and h<0): raise ValueError("h-domain")
    se=(1+(ALPHA*abs(h))**N)**(-M)
    t=TR+(TS-TR)*se
    if not(TR<t<TS): raise ValueError("theta-domain")
    return t

def h_theta(t):
    if not(TR<t<TS): raise ValueError("theta-domain")
    se=(t-TR)/(TS-TR)
    return -((se**(-1/M)-1)**(1/N))/ALPHA

def k_h(h):
    t=theta_h(h); se=(t-TR)/(TS-TR)
    k=KS*se**ELL*(1-(1-se**(1/M))**M)**2
    if not(math.isfinite(k) and k>0): raise ValueError("K-domain")
    return k

def integrate(hb,q):
    dy=DEPTH/NINT; h=hb; stor=0.0
    for _ in range(NINT):
        def fh(x): return q/k_h(x)-1.0
        k1h=fh(h); k1s=theta_h(h)
        h2=h+0.5*dy*k1h; k2h=fh(h2); k2s=theta_h(h2)
        h3=h+0.5*dy*k2h; k3h=fh(h3); k3s=theta_h(h3)
        h4=h+dy*k3h; k4h=fh(h4); k4s=theta_h(h4)
        h += dy*(k1h+2*k2h+2*k3h+k4h)/6.0
        stor += dy*(k1s+2*k2s+2*k3s+k4s)/6.0
        if not(math.isfinite(h) and h<0): raise ValueError("profile-domain")
    return stor

def ev_q(q,hb,target):
    try:
        s=integrate(hb,q); return (True,s-target,s,None)
    except Exception as e: return (False,None,None,str(e))

def ev_z(z,q,target):
    try:
        h=-math.exp(z); s=integrate(h,q); return (True,s-target,s,h)
    except Exception as e: return (False,None,None,str(e))

def bracket_from_seed(seed,lo,hi,ev):
    finite=[]
    e0=ev(seed)
    if e0[0]: finite.append((seed,e0))
    for bound in (lo,hi):
        a=seed; b=bound
        base=e0 if e0[0] else None
        last=None
        for _ in range(80):
            x=0.5*(a+b)
            ex=ev(x)
            if ex[0]:
                finite.append((x,ex))
                if base is not None and (base[1]==0 or ex[1]==0 or base[1]*ex[1]<0):
                    return (seed,x),finite
                last=(x,ex); a=x
            else:
                b=x
        if base is None and last is not None:
            base=last[1]; seed=last[0]
    finite.sort(key=lambda x:x[0])
    for (x,a),(y,b) in zip(finite,finite[1:]):
        if a[1]==0 or b[1]==0 or a[1]*b[1]<0:
            return (x,y),finite
    return None,finite

def solve(seeds,lo,hi,ev):
    allfinite=[]
    for seed in seeds:
        if not(lo<seed<hi): continue
        br,fin=bracket_from_seed(seed,lo,hi,ev); allfinite+=fin
        if br:
            a,b=sorted(br); ea=ev(a); eb=ev(b)
            if not(ea[0] and eb[0]): continue
            if ea[1]==0: return {"ok":True,"root":a,"residual":ea[1],"finite_count":len(allfinite)}
            if eb[1]==0: return {"ok":True,"root":b,"residual":eb[1],"finite_count":len(allfinite)}
            if ea[1]*eb[1]>0: continue
            for _ in range(100):
                m=0.5*(a+b); em=ev(m)
                if not em[0]: return {"ok":False,"reason":"invalid_midpoint"}
                if ea[1]*em[1]<=0: b=m; eb=em
                else: a=m; ea=em
            m=0.5*(a+b); em=ev(m)
            return {"ok":em[0],"root":m,"residual":em[1] if em[0] else None,
                    "finite_count":len(allfinite),"bracket_width":abs(b-a)}
    return {"ok":False,"reason":"no_finite_sign_bracket","finite_count":len(allfinite)}

def main():
    ap=argparse.ArgumentParser(); ap.add_argument("--prereg",required=True); ap.add_argument("--output",required=True)
    a=ap.parse_args(); p=json.loads(pathlib.Path(a.prereg).read_text())
    assert p["phase"]=="PREREGISTERED_BEFORE_PREFLIGHT"
    assert p["candidate"]["id"]=="QS1"
    assert p["constitutive_and_profile_identity"]["RK4_subintervals"]==1024
    assert p["preflight"]["trajectory_data_consumed"] is False

    t0=TR+SE0*(TS-TR); h0=h_theta(t0); k0=k_h(h0); s0=DEPTH*t0
    targets=[("S_MINUS",s0-DT*KS),("S0",s0),("S_PLUS",s0+DT*KS)]
    rows=[]
    for name,target in targets:
        tmean=target/DEPTH
        hmean=h_theta(tmean)
        kmean=k_h(hmean)
        qres=solve([kmean,0.0,k0],-KS,KS,lambda q:ev_q(q,h0,target))
        zlo=math.log(1e-8); zhi=math.log(1e6)
        zseeds=[math.log(-hmean),math.log(-h0)]
        hres=solve(zseeds,zlo,zhi,lambda z:ev_z(z,k0,target))
        if hres.get("ok"): hres["h_root_cm"]=-math.exp(hres["root"])
        rows.append({"target_id":name,"target_storage_cm":target,"q_root":qres,"h_root":hres})

    passed=all(r["q_root"].get("ok") and r["h_root"].get("ok") for r in rows)
    result={
      "schema":"swap5.f-romv2-d7.preflight-result.v1","workstream":"F-ROM","work_unit":"F-ROMV2-D7",
      "decision":"D7_ADMISSIBLE_ROOT_SEARCH_PREFLIGHT_PASS" if passed else "D7_ADMISSIBLE_ROOT_SEARCH_PREFLIGHT_NO_GO",
      "trajectory_evidence_consumed":False,
      "initial":{"theta":t0,"h_cm":h0,"K_cm_per_day":k0,"storage_cm":s0},
      "synthetic_scale_dt_times_Ksat_cm":DT*KS,
      "targets":rows,
      "preflight_pass":passed,
      "post_preflight_search_retuning_authorized":False,
      "production_rom_authorized":False
    }
    pathlib.Path(a.output).write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    print(json.dumps(result,sort_keys=True))
    return 0 if passed else 2

if __name__=="__main__": raise SystemExit(main())
