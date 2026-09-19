#!/usr/bin/env python3
from __future__ import annotations
import argparse,ctypes,json,math,pathlib

TR=.02;TS=.427494;ALPHA=.021659;N=1.734737;M=1-1/N;KS=31.225016;ELL=.98087
SE0=.85;SEG=80.;DT=.0008;SEED_DT=.0016;HARD_MASS=1e-12
HISTS=[*(f"D{i:02d}" for i in range(1,9)),*(f"V{i:02d}" for i in range(1,5))]

def fields(payload):
    out={}
    for part in payload.split("|"):
        if "=" in part:
            k,v=part.split("=",1);out[k]=v
    return out

def theta_h(h):
    if not(math.isfinite(h) and h<0): raise ValueError("h-domain")
    se=(1+(ALPHA*abs(h))**N)**(-M);t=TR+(TS-TR)*se
    if not(TR<t<TS): raise ValueError("theta-domain")
    return t

def h_theta(t):
    if not(TR<t<TS): raise ValueError("theta-domain")
    se=(t-TR)/(TS-TR)
    return -((se**(-1/M)-1)**(1/N))/ALPHA

def k_h(h):
    t=theta_h(h);se=(t-TR)/(TS-TR)
    k=KS*se**ELL*(1-(1-se**(1/M))**M)**2
    if not(math.isfinite(k) and k>0): raise ValueError("K-domain")
    return k

class Kernel:
    def __init__(self,path):
        lib=ctypes.CDLL(str(path));self.fn=lib.qs2_integrate_segment
        self.fn.argtypes=[ctypes.c_double,ctypes.c_double,ctypes.POINTER(ctypes.c_double)]
        self.fn.restype=ctypes.c_int
    def integrate(self,hb,q):
        out=(ctypes.c_double*2)();rc=self.fn(float(hb),float(q),out)
        if rc: raise ValueError(f"segment-domain-{rc}")
        return float(out[0]),float(out[1])

def solve(seeds,lo,hi,ev):
    cache={}
    def E(x):
        if x not in cache:cache[x]=ev(x)
        return cache[x]
    finite_all=[]
    for seed in seeds:
        if seed is None or not(lo<seed<hi):continue
        e0=E(seed);finite=[]
        if e0[0]:finite.append((seed,e0))
        bracket=None
        for bound in (lo,hi):
            a=seed;b=bound;base=e0 if e0[0] else None
            for _ in range(80):
                x=.5*(a+b);ex=E(x)
                if ex[0]:
                    finite.append((x,ex))
                    if base is not None and (base[1]==0 or ex[1]==0 or base[1]*ex[1]<0):
                        bracket=tuple(sorted((seed,x)));break
                    a=x
                else:b=x
            if bracket is not None:break
        finite_all.extend(finite)
        if bracket is None:
            finite.sort(key=lambda p:p[0])
            for (x,ex),(y,ey) in zip(finite,finite[1:]):
                if ex[1]==0 or ey[1]==0 or ex[1]*ey[1]<0:
                    bracket=(x,y);break
        if bracket is None:continue
        a,b=bracket;ea=E(a);eb=E(b)
        if not(ea[0] and eb[0]) or ea[1]*eb[1]>0:continue
        if ea[1]==0:return {"ok":True,"root":a,"residual":0.0}
        if eb[1]==0:return {"ok":True,"root":b,"residual":0.0}
        for _ in range(100):
            m=.5*(a+b)
            if m==a or m==b:break
            em=E(m)
            if not em[0]:return {"ok":False,"reason":"invalid_midpoint"}
            if ea[1]*em[1]<=0:b=m;eb=em
            else:a=m;ea=em
        m=.5*(a+b);em=E(m)
        return {"ok":bool(em[0]),"root":m,"residual":em[1] if em[0] else None}
    return {"ok":False,"reason":"no_finite_sign_bracket","finite_count":len(finite_all)}

def ev_q(k,q,hb,target):
    try:s,ht=k.integrate(hb,q);return True,s-target,ht
    except Exception as e:return False,None,str(e)

def ev_z(k,z,q,target):
    try:
        hb=-math.exp(z);s,ht=k.integrate(hb,q);return True,s-target,(hb,ht)
    except Exception as e:return False,None,str(e)

def bottom_boundary(symbol,k0,h0):
    if symbol in ("HOLD","TOP_PLUS","TOP_MINUS"):return "FLUX",k0
    if symbol in ("BOTTOM_HEAD_RISE","COMBINED_RISE_PLUS"):return "HEAD",.75*h0
    if symbol in ("BOTTOM_HEAD_FALL","COMBINED_FALL_MINUS"):return "HEAD",1.25*h0
    raise ValueError(symbol)

def top_flux(symbol,k0):
    if symbol in ("TOP_PLUS","COMBINED_RISE_PLUS"):return .99*k0
    if symbol in ("TOP_MINUS","COMBINED_FALL_MINUS"):return 1.01*k0
    return k0

def lower(k,Sl,symbol,last_qb,last_hb,h0,k0):
    if not(SEG*TR<Sl<SEG*TS):return {"ok":False,"reason":"lower_storage_bounds"}
    tm=Sl/SEG;hm=h_theta(tm);km=k_h(hm);mode,b=bottom_boundary(symbol,k0,h0)
    if mode=="HEAD":
        hb=b;root=solve([last_qb,km,0.,k0],-KS,KS,lambda q:ev_q(k,q,hb,Sl))
        if not root["ok"]:return {"ok":False,"reason":"lower_q_root","detail":root}
        s,hi=k.integrate(hb,root["root"])
        return {"ok":True,"qb":root["root"],"hb":hb,"hi":hi,"qseed":root["root"],"hseed":last_hb,"residual":s-Sl}
    q=b;zlo=math.log(1e-8);zhi=math.log(1e6);zs=[]
    if last_hb is not None and last_hb<0:zs.append(math.log(-last_hb))
    zs.extend([math.log(-hm),math.log(-h0)])
    root=solve(zs,zlo,zhi,lambda z:ev_z(k,z,q,Sl))
    if not root["ok"]:return {"ok":False,"reason":"lower_h_root","detail":root}
    hb=-math.exp(root["root"]);s,hi=k.integrate(hb,q)
    return {"ok":True,"qb":q,"hb":hb,"hi":hi,"qseed":last_qb,"hseed":hb,"residual":s-Sl}

def upper(k,Su,hi,last_qi,h0,k0):
    if not(SEG*TR<Su<SEG*TS):return {"ok":False,"reason":"upper_storage_bounds"}
    tm=Su/SEG;hm=h_theta(tm);km=k_h(hm)
    root=solve([last_qi,km,0.,k0],-KS,KS,lambda q:ev_q(k,q,hi,Su))
    if not root["ok"]:return {"ok":False,"reason":"upper_q_root","detail":root}
    s,hs=k.integrate(hi,root["root"])
    return {"ok":True,"qi":root["root"],"hs":hs,"qseed":root["root"],"residual":s-Su}

def reconstruct(k,Su,Sl,symbol,seeds,h0,k0):
    lo=lower(k,Sl,symbol,seeds["qb"],seeds["hb"],h0,k0)
    if not lo["ok"]:return {"ok":False,"stage":"lower",**lo}
    up=upper(k,Su,lo["hi"],seeds["qi"],h0,k0)
    if not up["ok"]:return {"ok":False,"stage":"upper",**up}
    return {"ok":True,"qb":lo["qb"],"qi":up["qi"],"hb":lo["hb"],"hi":lo["hi"],"hs":up["hs"],
            "seeds":{"qb":lo["qseed"],"hb":lo["hseed"],"qi":up["qseed"]},
            "lower_residual":lo["residual"],"upper_residual":up["residual"]}

def advance(k,Su,Sl,symbol,seeds,h0,k0,dt):
    qt=top_flux(symbol,k0)
    a=reconstruct(k,Su,Sl,symbol,seeds,h0,k0)
    if not a["ok"]:return {"ok":False,"where":"stage1","detail":a}
    Sup=Su+dt*(qt-a["qi"]);Slp=Sl+dt*(a["qi"]-a["qb"])
    if not(SEG*TR<Sup<SEG*TS and SEG*TR<Slp<SEG*TS):
        return {"ok":False,"where":"predictor_bounds","Sup":Sup,"Slp":Slp}
    b=reconstruct(k,Sup,Slp,symbol,a["seeds"],h0,k0)
    if not b["ok"]:return {"ok":False,"where":"stage2","detail":b}
    Sun=Su+.5*dt*((qt-a["qi"])+(qt-b["qi"]))
    Sln=Sl+.5*dt*((a["qi"]-a["qb"])+(b["qi"]-b["qb"]))
    if not(SEG*TR<Sun<SEG*TS and SEG*TR<Sln<SEG*TS):
        return {"ok":False,"where":"corrected_bounds","Sun":Sun,"Sln":Sln}
    bex=.5*dt*(a["qb"]+b["qb"]);top=-dt*qt
    mass=(Sun-Su)+(Sln-Sl)+top+bex
    if not math.isfinite(mass) or abs(mass)>HARD_MASS:
        return {"ok":False,"where":"mass","mass":mass}
    t=reconstruct(k,Sun,Sln,symbol,b["seeds"],h0,k0)
    if not t["ok"]:return {"ok":False,"where":"terminal","detail":t}
    return {"ok":True,"Su":Sun,"Sl":Sln,"bottom_exchange":bex,"bottom_flux":t["qb"],
            "interface_flux":t["qi"],"mass":mass,"seeds":t["seeds"]}

def parse_ref(path):
    states={}
    for line in pathlib.Path(path).read_text().splitlines():
        if "F_ROMV2_D8_REF_STATE|" in line:
            r=fields(line.split("F_ROMV2_D8_REF_STATE|",1)[1]);states[(r["HISTORY"],int(r["STEP"]))]=r
    exp={(h,s) for h in HISTS for s in range(1,65)}
    if set(states)!=exp:raise SystemExit("R16 reference structure mismatch")
    return states

def sign(x):return 1 if x>0 else -1 if x<0 else 0
def reversals(d):
    out=[];prev=None
    for st in sorted(d):
        sg=sign(d[st])
        if sg==0:continue
        if prev is not None and sg!=prev:out.append(st)
        prev=sg
    return out
def qstats(v):
    a=sorted(abs(x) for x in v)
    return {"count":len(v),"mean":sum(v)/len(v),"mean_abs":sum(abs(x) for x in v)/len(v),
            "rmse":math.sqrt(sum(x*x for x in v)/len(v)),
            "p95_abs":a[min(len(a)-1,math.ceil(.95*len(a))-1)],"max_abs":a[-1]}

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--reference",required=True);ap.add_argument("--prereg",required=True)
    ap.add_argument("--preflight",required=True);ap.add_argument("--lib",required=True);ap.add_argument("--output",required=True)
    a=ap.parse_args();p=json.loads(pathlib.Path(a.prereg).read_text());pre=json.loads(pathlib.Path(a.preflight).read_text())
    assert pre["decision"]=="D8_QS2_COMPOSITE_PREFLIGHT_PASS"
    k=Kernel(a.lib);ref=parse_ref(a.reference)
    t0=TR+SE0*(TS-TR);h0=h_theta(t0);k0=k_h(h0);s80=SEG*t0
    seeds0={"qb":k0,"hb":h0,"qi":k0}
    Su=Sl=s80;seeds=dict(seeds0);maxmass=0.
    for _ in range(2):
        z=advance(k,Su,Sl,"HOLD",seeds,h0,k0,SEED_DT)
        if not z["ok"]:raise SystemExit("seed integrity failure "+json.dumps(z))
        Su,Sl,seeds=z["Su"],z["Sl"],z["seeds"];maxmass=max(maxmass,abs(z["mass"]))
    seed_state=(Su,Sl,dict(seeds))

    by={};allS=[];allU=[];allL=[];allC=[];allQ=[];failure=None;sign_total=0;revmis=0
    for hist in HISTS:
        Su,Sl,seeds=seed_state[0],seed_state[1],dict(seed_state[2]);cum=refcum=0.;cq={};rq={}
        es=[];eu=[];el=[];ec=[];eq=[]
        for step in range(1,65):
            rr=ref[(hist,step)];sym=rr["SYMBOL"].strip()
            z=advance(k,Su,Sl,sym,seeds,h0,k0,DT)
            if not z["ok"]:
                failure={"history":hist,"step":step,"symbol":sym,**z};break
            Su,Sl,seeds=z["Su"],z["Sl"],z["seeds"];cum+=z["bottom_exchange"];refcum+=float(rr["BOTTOM_OUTWARD_EXCHANGE"])
            maxmass=max(maxmass,abs(z["mass"]))
            total=Su+Sl;rb=float(rr["BOTTOM_FLUX"])
            eS=total-float(rr["TOTAL_STORAGE"]);eU=Su-float(rr["UPPER_STORAGE"]);eL=Sl-float(rr["LOWER_STORAGE"])
            eC=cum-refcum;eQ=z["bottom_flux"]-rb
            es.append(eS);eu.append(eU);el.append(eL);ec.append(eC);eq.append(eQ)
            cq[step]=z["bottom_flux"];rq[step]=rb
        if failure:break
        se=sum(sign(cq[x])!=sign(rq[x]) for x in cq if sign(rq[x])!=0);cr=reversals(cq);rrv=reversals(rq);mm=cr!=rrv
        sign_total+=se;revmis+=int(mm)
        by[hist]={"total_storage_error_cm":qstats(es),"upper_storage_error_cm":qstats(eu),"lower_storage_error_cm":qstats(el),
                  "cumulative_bottom_exchange_error_cm":qstats(ec),"terminal_bottom_flux_error_cm_per_day":qstats(eq),
                  "bottom_flux_sign_error_count":se,"R16_reversal_steps":rrv,"QS2_reversal_steps":cr,
                  "reversal_sequence_mismatch":mm,"final_cumulative_bottom_exchange_error_cm":ec[-1],
                  "R16_final_cumulative_bottom_exchange_cm":refcum,
                  "relative_final_cumulative_bottom_exchange_error":ec[-1]/refcum if refcum else None}
        allS+=es;allU+=eu;allL+=el;allC+=ec;allQ+=eq
    integrity=failure is None and len(by)==12
    pooled=None
    if integrity:
        pooled={"total_storage_error_cm":qstats(allS),"upper_storage_error_cm":qstats(allU),"lower_storage_error_cm":qstats(allL),
                "cumulative_bottom_exchange_error_cm":qstats(allC),"terminal_bottom_flux_error_cm_per_day":qstats(allQ),
                "bottom_flux_sign_error_count":sign_total,"history_reversal_sequence_mismatch_count":revmis}
    r2=p["comparators"]["R2"];bal=trans=False
    if integrity:
        bal=pooled["total_storage_error_cm"]["rmse"]<=r2["total_storage_rmse_cm"] and pooled["cumulative_bottom_exchange_error_cm"]["rmse"]<=r2["cumulative_bottom_exchange_rmse_cm"]
        trans=pooled["terminal_bottom_flux_error_cm_per_day"]["rmse"]<=r2["terminal_bottom_flux_rmse_cm_per_day"] and sign_total<=r2["bottom_flux_sign_errors"]
    pos=integrity and (bal or trans)
    decision="QS2_COMPOSITE_HYDROLOGICALLY_WORTH_TABULATING" if pos else "QS2_COMPOSITE_NOT_COMPETITIVE_OR_NOT_ROBUST_IN_EXPOSED_B01_DOMAIN"
    out={"schema":"swap5.f-romv2-d8.result.v1","workstream":"F-ROM","work_unit":"F-ROMV2-D8","decision":decision,
         "integrity":{"pass":integrity,"failure":failure,"max_abs_transaction_mass_residual_cm":maxmass},
         "seed":{"upper_storage_cm":seed_state[0],"lower_storage_cm":seed_state[1]},
         "pooled":pooled,"by_history":by,
         "development_frontier":{"balance_view_pass":bal,"transient_view_pass":trans,"retained":pos},
         "application_acceptance":False,"formal_performance_claim":False,"production_rom_authorized":False}
    pathlib.Path(a.output).write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print(json.dumps({"decision":decision,"integrity":out["integrity"],"pooled":pooled,"frontier":out["development_frontier"]},sort_keys=True))
    return 0

if __name__=="__main__":raise SystemExit(main())
