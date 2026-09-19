#!/usr/bin/env python3
from __future__ import annotations
import argparse,ctypes,json,math,pathlib

TR=0.02; TS=0.427494; ALPHA=0.021659; N=1.734737; M=1.0-1.0/N
KS=31.225016; ELL=0.98087; SE0=0.85; DEPTH=160.0; HALF=80.0; NINT=1024; DT=0.0008
HISTS=[*(f"D{i:02d}" for i in range(1,9)),*(f"V{i:02d}" for i in range(1,5))]

def fields(payload):
    out={}
    for part in payload.split("|"):
        if "=" in part:
            k,v=part.split("=",1); out[k]=v
    return out

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

_C_PROFILE=None

def bind_c_profile(path):
    global _C_PROFILE
    lib=ctypes.CDLL(str(path))
    fn=lib.qs1_integrate
    fn.argtypes=[ctypes.c_double,ctypes.c_double,ctypes.POINTER(ctypes.c_double)]
    fn.restype=ctypes.c_int
    _C_PROFILE=fn

def integrate(hb,q):
    if _C_PROFILE is not None:
        out=(ctypes.c_double*4)()
        rc=_C_PROFILE(float(hb),float(q),out)
        if rc!=0:
            raise ValueError(f"profile-domain-{rc}")
        return float(out[0]),float(out[1]),float(out[2])
    dy=DEPTH/NINT; h=hb; s=0.; slo=0.; shi=0.
    for j in range(NINT):
        def fh(x): return q/k_h(x)-1.0
        k1h=fh(h); k1s=theta_h(h)
        h2=h+0.5*dy*k1h; k2h=fh(h2); k2s=theta_h(h2)
        h3=h+0.5*dy*k2h; k3h=fh(h3); k3s=theta_h(h3)
        h4=h+dy*k3h; k4h=fh(h4); k4s=theta_h(h4)
        h += dy*(k1h+2*k2h+2*k3h+k4h)/6.
        ds=dy*(k1s+2*k2s+2*k3s+k4s)/6.
        s+=ds
        if j < NINT//2: slo+=ds
        else: shi+=ds
        if not(math.isfinite(h) and h<0): raise ValueError("profile-domain")
    return s,shi,slo

def eval_q(q,hb,target):
    try:
        s,u,l=integrate(hb,q); return (True,s-target,s,(u,l))
    except Exception as e: return (False,None,None,str(e))

def eval_z(z,q,target):
    try:
        hb=-math.exp(z); s,u,l=integrate(hb,q); return (True,s-target,s,(hb,u,l))
    except Exception as e: return (False,None,None,str(e))

def find_bracket(seed,lo,hi,ev):
    e0=ev(seed)
    finite=[]
    if e0[0]: finite.append((seed,e0))
    for bound in (lo,hi):
        a=seed; b=bound
        base=e0 if e0[0] else None
        for _ in range(80):
            x=.5*(a+b); ex=ev(x)
            if ex[0]:
                finite.append((x,ex))
                if base is not None and (base[1]==0 or ex[1]==0 or base[1]*ex[1]<0):
                    return (seed,x),finite
                a=x
            else:
                b=x
    finite.sort(key=lambda p:p[0])
    for (x,a),(y,b) in zip(finite,finite[1:]):
        if a[1]==0 or b[1]==0 or a[1]*b[1]<0: return (x,y),finite
    return None,finite

def solve(seeds,lo,hi,ev):
    cache={}
    def E(x):
        if x not in cache: cache[x]=ev(x)
        return cache[x]
    allfinite=[]
    for seed in seeds:
        if not(lo<seed<hi): continue
        br,fin=find_bracket(seed,lo,hi,E); allfinite+=fin
        if not br: continue
        a,b=sorted(br); ea=E(a); eb=E(b)
        if not(ea[0] and eb[0]) or ea[1]*eb[1]>0: continue
        for _ in range(100):
            m=.5*(a+b)
            if m==a or m==b: break
            em=E(m)
            if not em[0]: return {"ok":False,"reason":"invalid_midpoint"}
            if ea[1]*em[1]<=0: b=m; eb=em
            else: a=m; ea=em
        m=.5*(a+b); em=E(m)
        return {"ok":em[0],"root":m,"residual":em[1] if em[0] else None}
    return {"ok":False,"reason":"no_finite_sign_bracket"}

def parse_ref(path):
    states={}
    for line in pathlib.Path(path).read_text().splitlines():
        if "F_ROMV2_D7_REF_STATE|" in line:
            r=fields(line.split("F_ROMV2_D7_REF_STATE|",1)[1])
            states[(r["HISTORY"],int(r["STEP"]))]=r
    expected={(h,s) for h in HISTS for s in range(1,65)}
    if set(states)!=expected: raise SystemExit("R16 reference structure mismatch")
    return states

def forcing(symbol,k0,h0):
    if symbol in ("TOP_PLUS","COMBINED_RISE_PLUS"): qtop=.99*k0
    elif symbol in ("TOP_MINUS","COMBINED_FALL_MINUS"): qtop=1.01*k0
    else: qtop=k0
    if symbol in ("HOLD","TOP_PLUS","TOP_MINUS"):
        return qtop,2,None,k0
    if symbol in ("BOTTOM_HEAD_RISE","COMBINED_RISE_PLUS"):
        return qtop,5,.75*h0,None
    if symbol in ("BOTTOM_HEAD_FALL","COMBINED_FALL_MINUS"):
        return qtop,5,1.25*h0,None
    raise ValueError(symbol)

def manifold(storage,symbol,k0,h0,last_q,last_h):
    tmean=storage/DEPTH
    if not(TR<tmean<TS): return {"ok":False,"reason":"storage_bounds"}
    hmean=h_theta(tmean); kmean=k_h(hmean)
    qtop,mode,hb,qfix=forcing(symbol,k0,h0)
    if mode==5:
        seeds=[x for x in (last_q,kmean,0.0,k0) if x is not None]
        root=solve(seeds,-KS,KS,lambda q:eval_q(q,hb,storage))
        if not root["ok"]: return {"ok":False,"reason":"q_root","detail":root}
        q=root["root"]; s,u,l=integrate(hb,q)
        return {"ok":True,"qbottom":q,"hbottom":hb,"upper":u,"lower":l,"qroot":q,"hroot":last_h}
    zlo=math.log(1e-8); zhi=math.log(1e6)
    zseeds=[]
    if last_h is not None and last_h<0: zseeds.append(math.log(-last_h))
    zseeds += [math.log(-hmean),math.log(-h0)]
    root=solve(zseeds,zlo,zhi,lambda z:eval_z(z,qfix,storage))
    if not root["ok"]: return {"ok":False,"reason":"h_root","detail":root}
    hb=-math.exp(root["root"]); s,u,l=integrate(hb,qfix)
    return {"ok":True,"qbottom":qfix,"hbottom":hb,"upper":u,"lower":l,"qroot":last_q,"hroot":hb}

def sign(x): return 1 if x>0 else -1 if x<0 else 0
def reversals(d):
    out=[]; prev=None
    for s in sorted(d):
        sg=sign(d[s])
        if sg==0: continue
        if prev is not None and sg!=prev: out.append(s)
        prev=sg
    return out
def qstats(v):
    if not v:return {"count":0}
    a=sorted(abs(x) for x in v)
    return {"count":len(v),"mean":sum(v)/len(v),"mean_abs":sum(abs(x) for x in v)/len(v),
            "rmse":math.sqrt(sum(x*x for x in v)/len(v)),
            "p95_abs":a[min(len(a)-1,math.ceil(.95*len(a))-1)],"max_abs":a[-1]}

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--reference",required=True); ap.add_argument("--prereg",required=True)
    ap.add_argument("--preflight",required=True); ap.add_argument("--output",required=True)
    ap.add_argument("--profile-lib")
    a=ap.parse_args()
    if a.profile_lib:
        bind_c_profile(a.profile_lib)
    p=json.loads(pathlib.Path(a.prereg).read_text())
    pre=json.loads(pathlib.Path(a.preflight).read_text())
    assert pre["decision"]=="D7_ADMISSIBLE_ROOT_SEARCH_PREFLIGHT_PASS"
    ref=parse_ref(a.reference)
    t0=TR+SE0*(TS-TR); h0=h_theta(t0); k0=k_h(h0); s0=DEPTH*t0

    by={}; allS=[]; allU=[]; allL=[]; allC=[]; allQ=[]
    failure=None; maxmass=0.; sign_total=0; revmis=0
    for hist in HISTS:
        S=s0; cum=0.; refcum=0.; lastq=k0; lasth=h0
        es=[]; eu=[]; el=[]; ec=[]; eq=[]; cq={}; rq={}
        for step in range(1,65):
            rr=ref[(hist,step)]; sym=rr["SYMBOL"].strip()
            qtop,_,_,_=forcing(sym,k0,h0)
            m1=manifold(S,sym,k0,h0,lastq,lasth)
            if not m1["ok"]: failure={"history":hist,"step":step,"stage":"stage1",**m1}; break
            Sp=S+DT*(qtop-m1["qbottom"])
            if not(TR*DEPTH<Sp<TS*DEPTH):
                failure={"history":hist,"step":step,"stage":"predictor_storage_bounds","storage":Sp}; break
            m2=manifold(Sp,sym,k0,h0,m1.get("qroot"),m1.get("hroot"))
            if not m2["ok"]: failure={"history":hist,"step":step,"stage":"stage2",**m2}; break
            Snew=S+.5*DT*((qtop-m1["qbottom"])+(qtop-m2["qbottom"]))
            if not(TR*DEPTH<Snew<TS*DEPTH):
                failure={"history":hist,"step":step,"stage":"corrected_storage_bounds","storage":Snew}; break
            bex=.5*DT*(m1["qbottom"]+m2["qbottom"]); top=-DT*qtop
            mass=(Snew-S)+top+bex; maxmass=max(maxmass,abs(mass))
            if abs(mass)>1e-12:
                failure={"history":hist,"step":step,"stage":"mass","mass":mass}; break
            mt=manifold(Snew,sym,k0,h0,m2.get("qroot"),m2.get("hroot"))
            if not mt["ok"]: failure={"history":hist,"step":step,"stage":"terminal",**mt}; break
            lastq=mt.get("qroot"); lasth=mt.get("hroot")
            cum+=bex; refcum+=float(rr["BOTTOM_OUTWARD_EXCHANGE"])
            eS=Snew-float(rr["TOTAL_STORAGE"])
            eU=mt["upper"]-float(rr["UPPER_STORAGE"])
            eL=mt["lower"]-float(rr["LOWER_STORAGE"])
            eC=cum-refcum; eQ=mt["qbottom"]-float(rr["BOTTOM_FLUX"])
            es.append(eS);eu.append(eU);el.append(eL);ec.append(eC);eq.append(eQ)
            cq[step]=mt["qbottom"]; rq[step]=float(rr["BOTTOM_FLUX"]); S=Snew
        if failure: break
        se=sum(sign(cq[s])!=sign(rq[s]) for s in cq if sign(rq[s])!=0)
        cr=reversals(cq); rrv=reversals(rq); mm=cr!=rrv
        sign_total+=se; revmis+=int(mm)
        by[hist]={"total_storage_error_cm":qstats(es),"upper_storage_error_cm":qstats(eu),
                  "lower_storage_error_cm":qstats(el),"cumulative_bottom_exchange_error_cm":qstats(ec),
                  "terminal_bottom_flux_error_cm_per_day":qstats(eq),"bottom_flux_sign_error_count":se,
                  "R16_reversal_steps":rrv,"QS1_reversal_steps":cr,"reversal_sequence_mismatch":mm,
                  "final_cumulative_bottom_exchange_error_cm":ec[-1],
                  "R16_final_cumulative_bottom_exchange_cm":refcum,
                  "relative_final_cumulative_bottom_exchange_error":ec[-1]/refcum if refcum else None}
        allS+=es;allU+=eu;allL+=el;allC+=ec;allQ+=eq

    integrity=failure is None and len(by)==12
    pooled=None
    if integrity:
        pooled={"total_storage_error_cm":qstats(allS),"upper_storage_error_cm":qstats(allU),
                "lower_storage_error_cm":qstats(allL),"cumulative_bottom_exchange_error_cm":qstats(allC),
                "terminal_bottom_flux_error_cm_per_day":qstats(allQ),
                "bottom_flux_sign_error_count":sign_total,"history_reversal_sequence_mismatch_count":revmis}
    r2=p["comparators"]["R2"]
    bal=trans=False
    if integrity:
        bal=pooled["total_storage_error_cm"]["rmse"]<=r2["total_storage_rmse_cm"] and pooled["cumulative_bottom_exchange_error_cm"]["rmse"]<=r2["cumulative_bottom_exchange_rmse_cm"]
        trans=pooled["terminal_bottom_flux_error_cm_per_day"]["rmse"]<=r2["terminal_bottom_flux_rmse_cm_per_day"] and sign_total<=r2["bottom_flux_sign_errors"]
    positive=integrity and (bal or trans)
    decision="QS1_HYDROLOGICALLY_WORTH_TABULATING" if positive else "QS1_NOT_WORTH_TABULATING_IN_EXPOSED_B01_DOMAIN"
    out={"schema":"swap5.f-romv2-d7.result.v1","workstream":"F-ROM","work_unit":"F-ROMV2-D7",
         "decision":decision,"integrity":{"pass":integrity,"failure":failure,"max_abs_transaction_mass_residual_cm":maxmass},
         "pooled":pooled,"by_history":by,
         "development_frontier":{"balance_view_pass":bal,"transient_view_pass":trans,"retained":positive},
         "application_acceptance":False,"formal_performance_claim":False,"production_rom_authorized":False}
    pathlib.Path(a.output).write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print(json.dumps({"decision":decision,"integrity":out["integrity"],"pooled":pooled,"frontier":out["development_frontier"]},sort_keys=True))
    return 0

if __name__=="__main__": raise SystemExit(main())
