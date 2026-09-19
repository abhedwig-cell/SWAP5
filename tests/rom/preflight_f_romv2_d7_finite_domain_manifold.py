#!/usr/bin/env python3
from __future__ import annotations
import argparse, json, math, pathlib

TR=0.02; TS=0.427494; ALPHA=0.021659; N=1.734737; M=1.0-1.0/N
KS=31.225016; ELL=0.98087; SE0=0.85; DEPTH=160.0; NINT=1024

def theta_of_h(h):
    if not (math.isfinite(h) and h<0.0): raise ValueError("h-domain")
    se=(1.0+(ALPHA*abs(h))**N)**(-M); t=TR+(TS-TR)*se
    if not (TR<t<TS): raise ValueError("theta-domain")
    return t
def h_of_theta(t):
    if not (TR<t<TS): raise ValueError("theta-domain")
    se=(t-TR)/(TS-TR)
    return -((se**(-1.0/M)-1.0)**(1.0/N))/ALPHA
def k_of_h(h):
    t=theta_of_h(h); se=(t-TR)/(TS-TR)
    k=KS*se**ELL*(1.0-(1.0-se**(1.0/M))**M)**2
    if not (math.isfinite(k) and k>0.0): raise ValueError("K-domain")
    return k
def integrate(hb,q):
    dy=DEPTH/NINT; h=hb; s=0.0
    for _ in range(NINT):
        def dh(x): return q/k_of_h(x)-1.0
        k1h=dh(h); k1s=theta_of_h(h)
        h2=h+0.5*dy*k1h; k2h=dh(h2); k2s=theta_of_h(h2)
        h3=h+0.5*dy*k2h; k3h=dh(h3); k3s=theta_of_h(h3)
        h4=h+dy*k3h; k4h=dh(h4); k4s=theta_of_h(h4)
        h += dy*(k1h+2*k2h+2*k3h+k4h)/6.0
        s += dy*(k1s+2*k2s+2*k3s+k4s)/6.0
        if not (math.isfinite(h) and h<0.0): raise ValueError("profile-domain")
    return s,h

def eval_profile(hb,q,target):
    try:
        s,ht=integrate(hb,q)
        return {"finite":True,"storage":s,"residual":s-target,"top_head":ht}
    except Exception as e:
        return {"finite":False,"storage":None,"residual":None,"top_head":None,"error":str(e)}

def adjacent_brackets(candidates, eval_fn, center):
    vals=[(x,eval_fn(x)) for x in sorted(set(candidates))]
    exact=[(x,r) for x,r in vals if r["finite"] and r["residual"]==0.0]
    if exact:
        x,r=min(exact,key=lambda z:(abs(z[0]-center),z[0]))
        return {"kind":"exact","x":x,"result":r,"finite_count":sum(v["finite"] for _,v in vals),"candidate_count":len(vals)}
    brackets=[]
    for (a,ra),(b,rb) in zip(vals,vals[1:]):
        if not (ra["finite"] and rb["finite"]): continue
        if ra["residual"]*rb["residual"]<0.0:
            brackets.append((a,ra,b,rb))
    if not brackets:
        return {"kind":"none","finite_count":sum(v["finite"] for _,v in vals),"candidate_count":len(vals)}
    a,ra,b,rb=min(brackets,key=lambda z:(abs(0.5*(z[0]+z[2])-center),z[0]))
    return {"kind":"bracket","a":a,"ra":ra,"b":b,"rb":rb,"finite_count":sum(v["finite"] for _,v in vals),"candidate_count":len(vals)}

def bisect_profile(a,b,eval_fn):
    ra=eval_fn(a); rb=eval_fn(b)
    if not (ra["finite"] and rb["finite"] and ra["residual"]*rb["residual"]<0): raise ValueError("bad initial bracket")
    for _ in range(64):
        m=0.5*(a+b); rm=eval_fn(m)
        if not rm["finite"]: raise ValueError("invalid midpoint")
        if rm["residual"]==0.0: a=b=m; ra=rb=rm; break
        if ra["residual"]*rm["residual"]<0.0: b=m; rb=rm
        else: a=m; ra=rm
    x=0.5*(a+b); r=eval_fn(x)
    if not r["finite"]: raise ValueError("invalid final root")
    return x,r

def q_search(target,hb):
    tc=target/DEPTH; qc=k_of_h(h_of_theta(tc)); inc=KS/1024.0
    c=[-KS,KS,qc]
    for k in range(11):
        d=inc*(2**k)
        c += [max(-KS,min(KS,qc-d)),max(-KS,min(KS,qc+d))]
    f=lambda q:eval_profile(hb,q,target)
    br=adjacent_brackets(c,f,qc)
    if br["kind"]=="none": return {"ok":False,"search":br}
    if br["kind"]=="exact": return {"ok":True,"root":br["x"],"profile":br["result"],"search":br}
    root,r=bisect_profile(br["a"],br["b"],f)
    return {"ok":True,"root":root,"profile":r,"search":br}

def h_search(target,q):
    tc=target/DEPTH; hc=h_of_theta(tc); s0=abs(hc)
    c=[-1e6,-1e-8,hc]
    for j in range(-80,81):
        suction=min(1e6,max(1e-8,s0*2**(j/4.0)))
        c.append(-suction)
    f=lambda h:eval_profile(h,q,target)
    br=adjacent_brackets(c,f,hc)
    if br["kind"]=="none": return {"ok":False,"search":br}
    if br["kind"]=="exact": return {"ok":True,"root":br["x"],"profile":br["result"],"search":br}
    root,r=bisect_profile(br["a"],br["b"],f)
    return {"ok":True,"root":root,"profile":r,"search":br}

def main():
    ap=argparse.ArgumentParser(); ap.add_argument("--prereg",required=True); ap.add_argument("--output",required=True)
    a=ap.parse_args(); p=json.loads(pathlib.Path(a.prereg).read_text())
    assert p["phase"]=="PREREGISTERED_BEFORE_PREFLIGHT_OR_TRAJECTORY_EXECUTION"
    assert p["profile_integrator"]["RK4_subintervals"]==1024
    assert p["root_search_common"]["bisection_iterations"]==64
    t0=TR+SE0*(TS-TR); h0=h_of_theta(t0); k0=k_of_h(h0); s0=DEPTH*t0
    cases={
      "PRESCRIBED_FLUX_EQUILIBRIUM":h_search(s0,k0),
      "BOTTOM_HEAD_RISE":q_search(s0,0.75*h0),
      "BOTTOM_HEAD_FALL":q_search(s0,1.25*h0),
    }
    passed=all(v["ok"] for v in cases.values())
    decision="D7_FINITE_DOMAIN_SEARCH_PREFLIGHT_PASS" if passed else "D7_FINITE_DOMAIN_SEARCH_NO_GO_BEFORE_TRAJECTORY_EXPOSURE"
    out={"schema":"swap5.f-romv2-d7.preflight-result.v1","workstream":"F-ROM","work_unit":"F-ROMV2-D7",
         "decision":decision,"trajectory_evidence_consumed":False,
         "initial_equilibrium":{"theta":t0,"h_cm":h0,"K_cm_per_day":k0,"storage_cm":s0},
         "cases":cases,"production_rom_authorized":False}
    pathlib.Path(a.output).write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print(json.dumps(out,sort_keys=True))
if __name__=="__main__": main()
