#!/usr/bin/env python3
from __future__ import annotations
import argparse,json,math,pathlib

TR=0.02; TS=0.427494; ALPHA=0.021659; N=1.734737; M=1.0-1.0/N
KS=31.225016; ELL=0.98087; SE0=0.85; DZ=80.0; DT=0.001; EPS=1.0e-4; MAXCORR=100
HISTS=["P01","P02","P03","P04"]; NSTEPS=64; HARD_MASS=1.0e-12

def fields(payload):
    out={}
    for p in payload.split("|"):
        if "=" in p:
            k,v=p.split("=",1); out[k]=v
    return out

def parse(path):
    states={}
    geom=None
    for line in pathlib.Path(path).read_text().splitlines():
        if "F_ROMV2_D10_REF_GEOMETRY|" in line:
            geom=fields(line.split("F_ROMV2_D10_REF_GEOMETRY|",1)[1])
        elif "F_ROMV2_D10_REF_STATE|" in line:
            r=fields(line.split("F_ROMV2_D10_REF_STATE|",1)[1])
            states[(r["HISTORY"],int(r["STEP"]))]=r
    expected={(h,s) for h in HISTS for s in range(1,NSTEPS+1)}
    if set(states)!=expected: raise SystemExit(f"state structure mismatch {path}")
    if geom is None: raise SystemExit("missing geometry")
    return {"n":int(geom["N"]),"states":states}

def se(theta):
    if not(TR<theta<TS): raise ValueError("theta outside open domain")
    return (theta-TR)/(TS-TR)

def psi(theta):
    x=se(theta)
    return ((x**(-1.0/M)-1.0)**(1.0/N))/ALPHA

def kval(theta):
    x=se(theta)
    k=KS*x**ELL*(1.0-(1.0-x**(1.0/M))**M)**2
    if not(math.isfinite(k) and k>=0): raise ValueError("invalid K")
    return k

TH0=TR+SE0*(TS-TR); K0=kval(TH0)

def fluxes(t1,t2,qtop):
    p1=psi(t1); p2=psi(t2)
    k1=kval(t1); k2=kval(t2)
    q1=0.5*(k1+k2)*(1.0+(p2-p1)/80.0)
    q2=KS*(1.0-p2/40.0)
    if not all(math.isfinite(x) for x in (qtop,q1,q2)):
        raise ValueError("nonfinite flux")
    return q1,q2

def deriv(t1,t2,qtop):
    q1,q2=fluxes(t1,t2,qtop)
    return (qtop-q1)/DZ,(q1-q2)/DZ,q1,q2

def heun_step(t1,t2,qtop):
    d1a,d2a,q1a,q2a=deriv(t1,t2,qtop)
    cur1=t1+DT*d1a; cur2=t2+DT*d2a
    if not(TR<cur1<TS and TR<cur2<TS):
        return {"ok":False,"reason":"predictor_bounds"}
    accepted=None
    for it in range(1,MAXCORR+1):
        d1b,d2b,q1b,q2b=deriv(cur1,cur2,qtop)
        new1=t1+0.5*DT*(d1a+d1b)
        new2=t2+0.5*DT*(d2a+d2b)
        if not(TR<new1<TS and TR<new2<TS):
            return {"ok":False,"reason":"corrector_bounds","iterations":it}
        diff=max(abs(new1-cur1),abs(new2-cur2))
        accepted=(new1,new2,q1b,q2b,it,diff)
        if diff<=EPS:
            break
        cur1,cur2=new1,new2
    else:
        return {"ok":False,"reason":"corrector_nonconvergence","iterations":MAXCORR}
    new1,new2,q1used,q2used,it,diff=accepted
    q1term,q2term=fluxes(new1,new2,qtop)
    bottom_exchange=0.5*DT*(q2a+q2used)
    top_exchange=-DT*qtop
    mass=DZ*(new1-t1)+DZ*(new2-t2)+top_exchange+bottom_exchange
    if not math.isfinite(mass) or abs(mass)>HARD_MASS:
        return {"ok":False,"reason":"mass_gate","mass":mass}
    return {"ok":True,"theta1":new1,"theta2":new2,"q2":q2term,
            "bottom_exchange":bottom_exchange,"mass":mass,"iterations":it,
            "corrector_diff":diff,"q1_terminal":q1term}

def factor(hist,step):
    if hist=="P01": return 1.0
    if hist=="P02": return 0.5 if ((step-1)//16)%2==0 else 1.5
    if hist=="P03": return 0.0 if ((step-1)//8)%2==0 else 2.0
    if hist=="P04":
        if step<=8:return 1.0
        if step<=24:return 0.25
        if step<=32:return 1.75
        if step<=48:return 0.75
        return 1.25
    raise ValueError(hist)

def sign(x): return 1 if x>0 else -1 if x<0 else 0
def reversals(d):
    out=[]; prev=None
    for st in sorted(d):
        s=sign(d[st])
        if s==0:continue
        if prev is not None and s!=prev:out.append(st)
        prev=s
    return out

def qstats(v):
    a=sorted(abs(x) for x in v)
    return {"count":len(v),"mean":sum(v)/len(v),"mean_abs":sum(abs(x) for x in v)/len(v),
            "rmse":math.sqrt(sum(x*x for x in v)/len(v)),
            "p95_abs":a[min(len(a)-1,math.ceil(.95*len(a))-1)],"max_abs":a[-1]}

def compare_candidate(candidate_states,r16_states):
    allS=[];allU=[];allL=[];allC=[];allQ=[];by={}; sign_total=0;revmis=0
    for h in HISTS:
        cum=refcum=0.; es=[];eu=[];el=[];ec=[];eq=[];cf={};rf={}
        for st in range(1,NSTEPS+1):
            c=candidate_states[(h,st)]; r=r16_states[(h,st)]
            cum+=c["bex"]; refcum+=float(r["BOTTOM_OUTWARD_EXCHANGE"])
            eS=c["total"]-float(r["TOTAL_STORAGE"]); eU=c["upper"]-float(r["UPPER_STORAGE"]); eL=c["lower"]-float(r["LOWER_STORAGE"])
            eC=cum-refcum; eQ=c["q"]-float(r["BOTTOM_FLUX"])
            es.append(eS);eu.append(eU);el.append(eL);ec.append(eC);eq.append(eQ)
            cf[st]=c["q"];rf[st]=float(r["BOTTOM_FLUX"])
        signs=sum(sign(cf[x])!=sign(rf[x]) for x in cf if sign(rf[x])!=0)
        cr=reversals(cf);rr=reversals(rf); mm=cr!=rr
        sign_total+=signs;revmis+=int(mm)
        by[h]={"total_storage_error_cm":qstats(es),"upper_storage_error_cm":qstats(eu),
               "lower_storage_error_cm":qstats(el),"cumulative_bottom_exchange_error_cm":qstats(ec),
               "terminal_bottom_flux_error_cm_per_day":qstats(eq),"bottom_flux_sign_error_count":signs,
               "R16_reversal_steps":rr,"candidate_reversal_steps":cr,"reversal_sequence_mismatch":mm,
               "final_cumulative_bottom_exchange_error_cm":ec[-1],"R16_final_cumulative_bottom_exchange_cm":refcum}
        allS+=es;allU+=eu;allL+=el;allC+=ec;allQ+=eq
    return {"pooled":{"total_storage_error_cm":qstats(allS),"upper_storage_error_cm":qstats(allU),
                      "lower_storage_error_cm":qstats(allL),"cumulative_bottom_exchange_error_cm":qstats(allC),
                      "terminal_bottom_flux_error_cm_per_day":qstats(allQ),
                      "bottom_flux_sign_error_count":sign_total,
                      "history_reversal_sequence_mismatch_count":revmis},"by_history":by}

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--r16",required=True);ap.add_argument("--r2",required=True);ap.add_argument("--prereg",required=True);ap.add_argument("--output",required=True)
    a=ap.parse_args()
    p=json.loads(pathlib.Path(a.prereg).read_text())
    assert p["phase"]=="PREREGISTERED_BEFORE_EXECUTION"
    assert p["he2"]["id"]=="HE2_PUBLISHED_FIXED_H"
    assert p["he2"]["corrector_tolerance_theta"]==1e-4
    r16=parse(a.r16); r2=parse(a.r2)
    if r16["n"]!=16 or r2["n"]!=2: raise SystemExit("geometry mismatch")

    # convert R2 output to common candidate representation
    r2c={}
    for key,r in r2["states"].items():
        r2c[key]={"total":float(r["TOTAL_STORAGE"]),"upper":float(r["UPPER_STORAGE"]),
                  "lower":float(r["LOWER_STORAGE"]),"bex":float(r["BOTTOM_OUTWARD_EXCHANGE"]),"q":float(r["BOTTOM_FLUX"])}
    r2cmp=compare_candidate(r2c,r16["states"])

    he={}
    maxmass=0.; totalcorr=0; maxcorr=0; failure=None
    for h in HISTS:
        t1=t2=TH0
        # matched two zero-head seed intervals with qtop=K0
        for seed_i in range(2):
            out=heun_step(t1,t2,K0)
            if not out["ok"]:
                failure={"history":h,"stage":"seed","seed_interval":seed_i+1,**out};break
            t1,t2=out["theta1"],out["theta2"];maxmass=max(maxmass,abs(out["mass"]));totalcorr+=out["iterations"];maxcorr=max(maxcorr,out["iterations"])
        if failure:break
        for st in range(1,NSTEPS+1):
            qtop=factor(h,st)*K0
            out=heun_step(t1,t2,qtop)
            if not out["ok"]:
                failure={"history":h,"step":st,**out};break
            t1,t2=out["theta1"],out["theta2"];maxmass=max(maxmass,abs(out["mass"]));totalcorr+=out["iterations"];maxcorr=max(maxcorr,out["iterations"])
            he[(h,st)]={"total":DZ*t1+DZ*t2,"upper":DZ*t1,"lower":DZ*t2,
                        "bex":out["bottom_exchange"],"q":out["q2"],"corr":out["iterations"]}
        if failure:break

    integrity=failure is None and len(he)==len(HISTS)*NSTEPS
    hecmp=compare_candidate(he,r16["states"]) if integrity else None
    balance=trans=False
    if integrity:
        hp=hecmp["pooled"]; rp=r2cmp["pooled"]
        balance=hp["total_storage_error_cm"]["rmse"]<=rp["total_storage_error_cm"]["rmse"] and hp["cumulative_bottom_exchange_error_cm"]["rmse"]<=rp["cumulative_bottom_exchange_error_cm"]["rmse"]
        trans=hp["terminal_bottom_flux_error_cm_per_day"]["rmse"]<=rp["terminal_bottom_flux_error_cm_per_day"]["rmse"] and hp["bottom_flux_sign_error_count"]<=rp["bottom_flux_sign_error_count"]
    retained=integrity and (balance or trans)
    decision="HE2_PUBLISHED_CORE_RETAINS_SWAPH_EXTENSION_INTEREST" if retained else "HE2_PUBLISHED_CORE_NOT_COMPETITIVE_ON_ITS_ZERO_HEAD_ENVELOPE"
    out={"schema":"swap5.f-romv2-d10.result.v1","workstream":"F-ROM","work_unit":"F-ROMV2-D10","decision":decision,
         "literature_faithful_subset":True,"arbitrary_nonzero_bottom_head_tested":False,
         "HE2":{"integrity":{"pass":integrity,"failure":failure,"max_abs_transaction_mass_residual_cm":maxmass},
                "corrector":{"total_iterations":totalcorr,"max_iterations_single_step":maxcorr,
                             "mean_iterations_per_seed_or_step": totalcorr/(len(HISTS)*(NSTEPS+2)) if integrity else None},
                "comparison":hecmp},
         "R2":{"comparison":r2cmp},
         "frontier":{"balance_view_pass":balance,"transient_view_pass":trans,"retained":retained},
         "application_acceptance":False,"formal_performance_claim":False,"production_rom_authorized":False}
    pathlib.Path(a.output).write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print(json.dumps({"decision":decision,"HE2_integrity":out["HE2"]["integrity"],"HE2_pooled":hecmp["pooled"] if hecmp else None,
                      "R2_pooled":r2cmp["pooled"],"frontier":out["frontier"],"corrector":out["HE2"]["corrector"]},sort_keys=True))
    return 0

if __name__=="__main__": raise SystemExit(main())
