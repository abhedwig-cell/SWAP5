#!/usr/bin/env python3
from __future__ import annotations
import argparse,json,math,pathlib

TR=0.02; TS=0.427494; ALPHA=0.021659; N=1.734737; M=1.0-1.0/N
KS=31.225016; ELL=0.98087
NB=200; I=100; J0=101; J1=199; DEPTH=160.0; DT=10.0/86400.0
DTH=(TS-TR)/NB; SLUG_LEN=5.0; MASS_TOL=1e-12; RELAX_TOL=1e-14
HISTS={"X25":0.25,"X50":0.50,"X75":0.75,"X125":1.25}; NSTEPS=64

def theta(j): return TR+j*DTH
def psi(t):
    se=(t-TR)/(TS-TR)
    return ((se**(-1.0/M)-1.0)**(1.0/N))/ALPHA
def kval(t):
    se=(t-TR)/(TS-TR)
    k=KS*se**ELL*(1.0-(1.0-se**(1.0/M))**M)**2
    if not(math.isfinite(k) and k>0): raise ValueError("K domain")
    return k

TI=theta(I); KI=kval(TI)

def initial_premerge(lam):
    slugs={}; gw={}
    for j in range(J0,J1+1):
        h=lam*abs(psi(theta(j)))
        if not(math.isfinite(h) and 0<h<DEPTH): raise ValueError("H bounds")
        gtop=DEPTH-h; a=gtop-SLUG_LEN; b=gtop
        if not(0<a<b==gtop<DEPTH): raise ValueError("contact geometry")
        slugs[j]=(a,b); gw[j]=h
    return slugs,gw

def storage(slugs,gw):
    return TI*DEPTH+DTH*(math.fsum(b-a for a,b in slugs.values())+math.fsum(gw.values()))

def theta16(slugs,gw):
    vals=[]
    for c in range(16):
        top=10.0*c; bot=top+10.0; t=TI
        for j in range(J0,J1+1):
            s=0.0
            if j in slugs:
                a,b=slugs[j]; s=max(0.0,min(b,bot)-max(a,top))
            gtop=DEPTH-gw[j]; g=max(0.0,bot-max(gtop,top))
            if j in slugs:
                a,b=slugs[j]
                if min(b,bot)>max(gtop,top)+1e-14: raise ValueError("overlap")
            t+=DTH*(s+g)/10.0
        if not(TR<t<TS): raise ValueError("theta16 bounds")
        vals.append(t)
    return vals

def merge_exact(slugs,gw):
    before=storage(slugs,gw); n=0
    out=dict(gw)
    for j,(a,b) in slugs.items():
        gtop=DEPTH-out[j]
        if abs(b-gtop)>1e-12: raise ValueError("not exact contact")
        out[j]+=b-a
        if not(0<out[j]<=DEPTH): raise ValueError("merged H bounds")
        n+=1
    after=storage({},out)
    return {},out,n,after-before

def relax(gw):
    keys=sorted(gw); before=DTH*math.fsum(gw.values())
    vals=sorted(gw.values(),reverse=True); out={j:v for j,v in zip(keys,vals)}
    drift=DTH*math.fsum(out.values())-before
    if abs(drift)>RELAX_TOL: raise ValueError("relax drift")
    return out,drift

def gw_velocity(j,h):
    tj=theta(j); kj=kval(tj)
    return (kj-KI)/(tj-TI)*(abs(psi(tj))/h-1.0)

def gw_step(gw):
    raw={}
    for j,h in gw.items():
        nh=h+DT*gw_velocity(j,h)
        if not(math.isfinite(nh) and 0<nh<=DEPTH): raise ValueError(f"gw raw bounds {j}")
        raw[j]=nh
    return relax(raw)

def bottom_flux(gw):
    return -DTH*math.fsum(gw_velocity(j,gw[j]) for j in range(J0,J1+1))

def run(lam):
    slugs,gw=initial_premerge(lam)
    spre=storage(slugs,gw); thpre=theta16(slugs,gw)
    slugs,gw,nmerge,merge_drift=merge_exact(slugs,gw)
    spost=storage(slugs,gw); thpost=theta16(slugs,gw)
    if nmerge!=99: return {"pass":False,"reason":"merge_count","merge_count":nmerge}
    if abs(merge_drift)>RELAX_TOL: return {"pass":False,"reason":"merge_drift","merge_drift":merge_drift}
    if max(abs(a-b) for a,b in zip(thpre,thpost))>1e-14:
        return {"pass":False,"reason":"physical_profile_changed_by_representation_merge"}
    if abs(spost-spre)>RELAX_TOL: return {"pass":False,"reason":"storage_changed_by_merge"}

    rows=[]; cum=0.0; maxmass=0.0; maxrelax=0.0
    for step in range(1,NSTEPS+1):
        sb=storage({},gw)
        gw2,drift=gw_step(gw); maxrelax=max(maxrelax,abs(drift)); gw=gw2
        sa=storage({},gw); bex=-(sa-sb); cum+=bex; mass=(sa-sb)+bex
        maxmass=max(maxmass,abs(mass))
        if abs(mass)>MASS_TOL: raise ValueError("mass gate")
        rows.append({"step":step,"storage_cm":sa,"bottom_outward_exchange_cm":bex,
                     "cumulative_bottom_outward_exchange_cm":cum,
                     "terminal_bottom_outward_flux_cm_per_day":bottom_flux(gw),
                     "theta16":theta16({},gw)})
    return {
      "pass":True,"premerge_storage_cm":spre,"postmerge_storage_cm":spost,
      "premerge_theta16":thpre,"postmerge_theta16":thpost,
      "merge_count":nmerge,"merge_storage_residual_cm":merge_drift,
      "max_abs_relaxation_storage_drift_cm":maxrelax,
      "max_abs_step_mass_residual_cm":maxmass,"steps":rows
    }

def main():
    ap=argparse.ArgumentParser(); ap.add_argument("--prereg",required=True); ap.add_argument("--output",required=True)
    a=ap.parse_args(); p=json.loads(pathlib.Path(a.prereg).read_text())
    assert p["phase"]=="PREREGISTERED_BEFORE_INTERNAL_PREFLIGHT_AND_SWAP_TRAJECTORY_EXECUTION"
    assert p["exact_contact_initial_state"]["slug_length_cm"]==5
    assert p["firewalls"].count("NO_CONTACT_GAP")==1
    rows={}
    for h,lam in HISTS.items():
        try: rows[h]=run(lam)
        except Exception as exc: rows[h]={"pass":False,"reason":str(exc)}
    passed=all(v.get("pass") for v in rows.values())
    out={"schema":"swap5.f-romv2-d19.internal-preflight.v1","workstream":"F-ROM","work_unit":"F-ROMV2-D19",
         "decision":"D19_FMC_EXACT_CONTACT_MERGE_PREFLIGHT_PASS" if passed else "D19_FMC_EXACT_CONTACT_MERGE_PREFLIGHT_NO_GO",
         "SWAP_trajectory_evidence_consumed":False,"histories":rows,"preflight_pass":passed,
         "SWAP_trajectory_generation_authorized":passed,
         "post_preflight_lambda_slug_bin_substep_merge_retuning_authorized":False,
         "production_rom_authorized":False}
    pathlib.Path(a.output).write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print(json.dumps({"decision":out["decision"],"summary":{h:{k:v.get(k) for k in ("pass","merge_count","merge_storage_residual_cm","max_abs_step_mass_residual_cm")} for h,v in rows.items()}},sort_keys=True))
    return 0 if passed else 2
if __name__=="__main__": raise SystemExit(main())
