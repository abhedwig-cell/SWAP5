#!/usr/bin/env python3
from __future__ import annotations
import argparse,ctypes,json,math,pathlib

TR=.02;TS=.427494;ALPHA=.021659;N=1.734737;M=1-1/N;KS=31.225016;ELL=.98087
SE0=.85;SEG=80.;DT=.0008

def h_theta(t):
    if not(TR<t<TS): raise ValueError("theta-domain")
    se=(t-TR)/(TS-TR)
    return -((se**(-1/M)-1)**(1/N))/ALPHA

def theta_h(h):
    if not(math.isfinite(h) and h<0): raise ValueError("h-domain")
    se=(1+(ALPHA*abs(h))**N)**(-M)
    t=TR+(TS-TR)*se
    if not(TR<t<TS): raise ValueError("theta-domain")
    return t

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
        if x not in cache: cache[x]=ev(x)
        return cache[x]
    for seed in seeds:
        if not(lo<seed<hi): continue
        e0=E(seed);finite=[]
        if e0[0]: finite.append((seed,e0))
        for bound in (lo,hi):
            a=seed;b=bound;base=e0 if e0[0] else None
            for _ in range(80):
                x=.5*(a+b);ex=E(x)
                if ex[0]:
                    finite.append((x,ex))
                    if base is not None and (base[1]==0 or ex[1]==0 or base[1]*ex[1]<0):
                        aa,bb=sorted((seed,x));ea=E(aa);eb=E(bb)
                        break
                    a=x
                else:b=x
            else:
                continue
            break
        else:
            finite.sort(key=lambda p:p[0]);aa=bb=None
            for (x,ex),(y,ey) in zip(finite,finite[1:]):
                if ex[1]==0 or ey[1]==0 or ex[1]*ey[1]<0:
                    aa,bb=x,y;ea,eb=ex,ey;break
            if aa is None: continue
        if not(ea[0] and eb[0]) or ea[1]*eb[1]>0: continue
        if ea[1]==0:return {"ok":True,"root":aa,"residual":0.0}
        if eb[1]==0:return {"ok":True,"root":bb,"residual":0.0}
        for _ in range(100):
            mid=.5*(aa+bb)
            if mid==aa or mid==bb: break
            em=E(mid)
            if not em[0]: return {"ok":False,"reason":"invalid_midpoint"}
            if ea[1]*em[1]<=0:bb=mid;eb=em
            else:aa=mid;ea=em
        mid=.5*(aa+bb);em=E(mid)
        return {"ok":bool(em[0]),"root":mid,"residual":em[1] if em[0] else None}
    return {"ok":False,"reason":"no_finite_sign_bracket"}

def eval_q(kernel,q,hb,target):
    try:
        s,ht=kernel.integrate(hb,q);return True,s-target,ht
    except Exception as e:return False,None,str(e)

def eval_z(kernel,z,q,target):
    try:
        hb=-math.exp(z);s,ht=kernel.integrate(hb,q);return True,s-target,(hb,ht)
    except Exception as e:return False,None,str(e)

def lower(kernel,Sl,mode,boundary,h0,k0):
    tm=Sl/SEG;hm=h_theta(tm);km=k_h(hm)
    if mode=="HEAD":
        hb=boundary
        root=solve([km,0.,k0],-KS,KS,lambda q:eval_q(kernel,q,hb,Sl))
        if not root["ok"]:return {"ok":False,"stage":"lower_q","detail":root}
        s,hi=kernel.integrate(hb,root["root"])
        return {"ok":True,"qb":root["root"],"hb":hb,"hi":hi,"storage_residual":s-Sl}
    q=boundary;zlo=math.log(1e-8);zhi=math.log(1e6)
    root=solve([math.log(-hm),math.log(-h0)],zlo,zhi,lambda z:eval_z(kernel,z,q,Sl))
    if not root["ok"]:return {"ok":False,"stage":"lower_h","detail":root}
    hb=-math.exp(root["root"]);s,hi=kernel.integrate(hb,q)
    return {"ok":True,"qb":q,"hb":hb,"hi":hi,"storage_residual":s-Sl}

def upper(kernel,Su,hi,h0,k0):
    tm=Su/SEG;hm=h_theta(tm);km=k_h(hm)
    root=solve([km,0.,k0],-KS,KS,lambda q:eval_q(kernel,q,hi,Su))
    if not root["ok"]:return {"ok":False,"stage":"upper_q","detail":root}
    s,hs=kernel.integrate(hi,root["root"])
    return {"ok":True,"qi":root["root"],"hs":hs,"storage_residual":s-Su}

def main():
    ap=argparse.ArgumentParser();ap.add_argument("--prereg",required=True);ap.add_argument("--lib",required=True);ap.add_argument("--output",required=True)
    a=ap.parse_args();p=json.loads(pathlib.Path(a.prereg).read_text());k=Kernel(a.lib)
    assert p["phase"]=="PREREGISTERED_BEFORE_PREFLIGHT"
    assert p["candidate"]["id"]=="QS2_COMPOSITE"
    assert p["segment_profile_equations"]["RK4_subintervals_per_80cm_segment"]==512

    t0=TR+SE0*(TS-TR);h0=h_theta(t0);k0=k_h(h0);s80=SEG*t0;delta=.5*DT*KS
    states=[
      ("EQ",s80,s80),("PARTITION_A",s80-delta,s80+delta),("PARTITION_B",s80+delta,s80-delta),
      ("TOTAL_DRY",s80-delta,s80-delta),("TOTAL_WET",s80+delta,s80+delta)]
    boundaries=[("FLUX_EQ","FLUX",k0),("HEAD_RISE","HEAD",.75*h0),("HEAD_FALL","HEAD",1.25*h0)]
    rows=[];passed=True
    for sid,Su,Sl in states:
      for bid,mode,b in boundaries:
        lo=lower(k,Sl,mode,b,h0,k0)
        if lo["ok"]:up=upper(k,Su,lo["hi"],h0,k0)
        else:up={"ok":False,"stage":"not_reached"}
        ok=lo["ok"] and up["ok"] and abs(lo["storage_residual"])<=1e-10 and abs(up["storage_residual"])<=1e-10
        passed &= ok
        rows.append({"state":sid,"boundary":bid,"upper_storage_cm":Su,"lower_storage_cm":Sl,
                     "lower":lo,"upper":up,"pass":ok})
    eq=next(r for r in rows if r["state"]=="EQ" and r["boundary"]=="FLUX_EQ")
    eq_control=eq["pass"] and abs(eq["lower"]["qb"]-k0)<=1e-10 and abs(eq["upper"]["qi"]-k0)<=1e-10 and abs(eq["lower"]["hi"]-h0)<=1e-8
    passed &= eq_control
    out={"schema":"swap5.f-romv2-d8.preflight-result.v1","workstream":"F-ROM","work_unit":"F-ROMV2-D8",
         "decision":"D8_QS2_COMPOSITE_PREFLIGHT_PASS" if passed else "D8_QS2_COMPOSITE_PREFLIGHT_NO_GO",
         "trajectory_evidence_consumed":False,"initial":{"theta":t0,"h_cm":h0,"K_cm_per_day":k0,"segment_storage_cm":s80},
         "delta_cm":delta,"equilibrium_control_pass":eq_control,"cases":rows,"preflight_pass":passed,
         "post_preflight_search_or_equation_retuning_authorized":False,"production_rom_authorized":False}
    pathlib.Path(a.output).write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print(json.dumps({"decision":out["decision"],"equilibrium_control_pass":eq_control,
                      "cases":[{"state":r["state"],"boundary":r["boundary"],"pass":r["pass"]} for r in rows]},sort_keys=True))
    return 0 if passed else 2

if __name__=="__main__":raise SystemExit(main())
