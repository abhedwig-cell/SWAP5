#!/usr/bin/env python3
from __future__ import annotations
import argparse,collections,json,math,pathlib

TR=0.02; TS=0.427494; ALPHA=0.021659; N=1.734737; M=1.0-1.0/N
KS=31.225016; ELL=0.98087; NBINS=200; I=100; J0=101; J1=199
HCM=14.085215420920257; DTH=(TS-TR)/NBINS; DEPTH=160.0
DT=10.0/86400.0; NSUB=9; OBS_DT=90.0/86400.0; NOBS=64
HISTORIES={
"S10_P16_H48":{"z101":20.0,"z199":2.0,"rain_factor":0.10,"pulse_obs":16},
"M25_P16_H48":{"z101":60.0,"z199":5.0,"rain_factor":0.25,"pulse_obs":16},
"D50_P16_H48":{"z101":120.0,"z199":10.0,"rain_factor":0.50,"pulse_obs":16},
"M50_P32_H32":{"z101":60.0,"z199":5.0,"rain_factor":0.50,"pulse_obs":32},
}

def fields(s):
    out={}
    for p in s.split("|"):
        if "=" in p:
            k,v=p.split("=",1); out[k]=v
    return out
def parse_ref(path):
    states={}; nodes=collections.defaultdict(dict); n=None
    for line in pathlib.Path(path).read_text().splitlines():
        if line.startswith("F_ROMV2_D16_REF_GEOMETRY|"):
            n=int(fields(line.split("|",1)[1])["N"])
        elif "F_ROMV2_D16_REF_STATE|" in line:
            r=fields(line.split("F_ROMV2_D16_REF_STATE|",1)[1]); states[(r["HISTORY"].strip(),int(r["STEP"]))]=r
        elif "F_ROMV2_D16_REF_NODE|" in line:
            r=fields(line.split("F_ROMV2_D16_REF_NODE|",1)[1]); nodes[(r["HISTORY"].strip(),int(r["STEP"]))][int(r["NODE"])]=r
    expected={(h,s) for h in HISTORIES for s in range(1,NOBS+1)}
    if n is None or set(states)!=expected or set(nodes)!=expected:
        raise SystemExit(f"reference structure mismatch {path} n={n} states={len(states)} nodes={len(nodes)}")
    if any(set(nodes[k])!=set(range(1,n+1)) for k in expected):
        raise SystemExit(f"node structure mismatch {path}")
    return {"n":n,"states":states,"nodes":nodes}

def theta(j): return TR+j*DTH
def psi(t):
    se=(t-TR)/(TS-TR); return ((se**(-1/M)-1)**(1/N))/ALPHA
def kval(t):
    if t<=TR:return 0.0
    if t>=TS:return KS
    se=(t-TR)/(TS-TR)
    return KS*se**ELL*(1-(1-se**(1/M))**M)**2
THETA_I=theta(I); K_I=kval(THETA_I)
def eq18(z):
    td=theta(J1); kd=kval(td)
    return (kd-K_I)/(td-THETA_I)*(1+max(abs(psi(td)),HCM)/z)
def eq19(j): return (kval(theta(j))-kval(theta(j-1)))/DTH
def init_fronts(spec):
    return {j:spec["z101"]+(spec["z199"]-spec["z101"])*(j-J0)/(J1-J0) for j in range(J0,J1+1)}
def relax(f):
    ks=sorted(f); vs=sorted((f[j] for j in ks),reverse=True)
    return dict(zip(ks,vs))
def pulse_substep(f,rain):
    rem=rain*DT; out=dict(f)
    for j in range(J0,J1+1):
        raw=f[j]+eq18(f[j])*DT
        demand=max(0.0,DTH*(raw-f[j]))
        take=min(rem,demand)
        if take>0: out[j]=f[j]+take/DTH; rem-=take
        if take<demand-1e-18 or rem<=1e-18: break
    if rem>1e-14: raise RuntimeError("unexpected dry-bin/surface residual after frozen preflight")
    return relax(out)
def translate(slugs):
    out={}
    for j,(a,b) in slugs.items():
        d=eq19(j)*DT; na=a+d; nb=b+d
        if not(0<=na<nb<=DEPTH): raise RuntimeError("slug leaves domain")
        out[j]=(na,nb)
    return out
def cells_fronts(fronts,n=16):
    dz=DEPTH/n; vals=[]
    for c in range(n):
        a=c*dz;b=(c+1)*dz;v=THETA_I
        for z in fronts.values():
            v+=DTH*max(0.0,min(z,b)-a)/dz if z>a else 0.0
        vals.append(v)
    return vals
def cells_slugs(slugs,n=16):
    dz=DEPTH/n;vals=[]
    for c in range(n):
        a=c*dz;b=(c+1)*dz;v=THETA_I
        for top,bot in slugs.values():
            v+=DTH*max(0.0,min(bot,b)-max(top,a))/dz
        vals.append(v)
    return vals
def fmc_history(spec):
    fronts=init_fronts(spec); slugs=None; rows={}
    for step in range(1,NOBS+1):
        for _ in range(NSUB):
            if step<=spec["pulse_obs"]:
                fronts=pulse_substep(fronts,spec["rain_factor"]*KS)
            else:
                if slugs is None: slugs={j:(0.0,z) for j,z in fronts.items()}
                slugs=translate(slugs)
        vals=cells_fronts(fronts) if slugs is None else cells_slugs(slugs)
        rows[step]=vals
    return rows
def qstats(vals):
    if not vals:return {"count":0}
    a=sorted(abs(x) for x in vals)
    return {"count":len(vals),"mean":sum(vals)/len(vals),"mean_abs":sum(abs(x) for x in vals)/len(vals),
            "rmse":math.sqrt(sum(x*x for x in vals)/len(vals)),
            "p95_abs":a[min(len(a)-1,math.ceil(.95*len(a))-1)],"max_abs":a[-1]}
def zones(vals):
    return 10.0*sum(vals[:8]),10.0*sum(vals[8:])
def moment(vals):
    return sum(t*10.0*(5.0+10.0*i) for i,t in enumerate(vals))
def ref16_cells(ref,h,s):
    return [float(ref["nodes"][(h,s)][i]["THETA"]) for i in range(1,17)]
def ref2_cells(ref,h,s):
    a=float(ref["nodes"][(h,s)][1]["THETA"]);b=float(ref["nodes"][(h,s)][2]["THETA"])
    return [a]*8+[b]*8

def eval_candidate(name,getcells,r16):
    all_e=[]; pulse_e=[]; hiatus_e=[]; up=[];low=[];mom=[]; by={}
    for h,spec in HISTORIES.items():
        he=[];hp=[];hh=[];hu=[];hl=[];hm=[]
        for step in range(1,NOBS+1):
            c=getcells(h,step); r=ref16_cells(r16,h,step)
            e=[x-y for x,y in zip(c,r)]
            he+=e; (hp if step<=spec["pulse_obs"] else hh).extend(e)
            cu,cl=zones(c);ru,rl=zones(r)
            hu.append(cu-ru);hl.append(cl-rl);hm.append(moment(c)-moment(r))
        all_e+=he;pulse_e+=hp;hiatus_e+=hh;up+=hu;low+=hl;mom+=hm
        by[h]={"theta_error":qstats(he),"pulse_theta_error":qstats(hp),"hiatus_theta_error":qstats(hh),
               "upper_storage_error_cm":qstats(hu),"lower_storage_error_cm":qstats(hl),
               "first_moment_error_cm2":qstats(hm)}
    return {"id":name,"pooled":{"theta_error":qstats(all_e),"pulse_theta_error":qstats(pulse_e),
             "hiatus_theta_error":qstats(hiatus_e),"upper_storage_error_cm":qstats(up),
             "lower_storage_error_cm":qstats(low),"first_moment_error_cm2":qstats(mom)},"by_history":by}

def ref_integrity(ref):
    masses=[];bottom=[];fall=0;nl=0;back=0
    for r in ref["states"].values():
        masses.append(float(r["MASS"]));bottom.append(float(r["BOTTOM_OUTWARD_EXCHANGE"]))
        fall+=str(r["FALLBACK"]).lower() in ("t","true",".true.")
        nl+=int(r["NL"]);back+=int(r["BACKTRACK"])
    return {"max_abs_mass_residual_cm":max(abs(x) for x in masses),
            "max_abs_bottom_exchange_cm":max(abs(x) for x in bottom),
            "research_reattempt_count":fall,"nonlinear_iterations_total":nl,"backtracking_total":back}

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--r16",required=True);ap.add_argument("--r2",required=True)
    ap.add_argument("--prereg",required=True);ap.add_argument("--preflight",required=True);ap.add_argument("--output",required=True)
    a=ap.parse_args();p=json.loads(pathlib.Path(a.prereg).read_text());pre=json.loads(pathlib.Path(a.preflight).read_text())
    if pre["decision"]!="D16_FMC_MATCHED_SURFACE_PREFLIGHT_PASS": raise SystemExit("preflight authority missing")
    r16=parse_ref(a.r16);r2=parse_ref(a.r2)
    if r16["n"]!=16 or r2["n"]!=2: raise SystemExit("geometry mismatch")
    fmc={h:fmc_history(spec) for h,spec in HISTORIES.items()}
    fmc_eval=eval_candidate("FMC_SURFACE",lambda h,s:fmc[h][s],r16)
    r2_eval=eval_candidate("R2",lambda h,s:ref2_cells(r2,h,s),r16)
    fi=ref_integrity(r16);ri=ref_integrity(r2)
    integrity=(fi["max_abs_mass_residual_cm"]<=1e-12 and ri["max_abs_mass_residual_cm"]<=1e-12
               and fi["max_abs_bottom_exchange_cm"]<=1e-12 and ri["max_abs_bottom_exchange_cm"]<=1e-12)
    profile_pass=fmc_eval["pooled"]["theta_error"]["rmse"]<=r2_eval["pooled"]["theta_error"]["rmse"]
    hiatus_pass=fmc_eval["pooled"]["hiatus_theta_error"]["rmse"]<=r2_eval["pooled"]["hiatus_theta_error"]["rmse"]
    zone_pass=(fmc_eval["pooled"]["upper_storage_error_cm"]["rmse"]<=r2_eval["pooled"]["upper_storage_error_cm"]["rmse"]
               and fmc_eval["pooled"]["lower_storage_error_cm"]["rmse"]<=r2_eval["pooled"]["lower_storage_error_cm"]["rmse"])
    positive=integrity and profile_pass and hiatus_pass
    decision="FMC_SURFACE_ROUTE_RETAINS_DEVELOPMENT_RESEARCH_CANDIDACY" if positive else "FMC_SURFACE_ROUTE_NOT_COMPETITIVE_OR_NOT_ROBUST_IN_BOUNDED_DEVELOPMENT_ENVELOPE"
    out={"schema":"swap5.f-romv2-d16.result.v1","workstream":"F-ROM","work_unit":"F-ROMV2-D16",
         "decision":decision,"integrity":{"pass":integrity,"R16":fi,"R2":ri},
         "FMC":fmc_eval,"R2":r2_eval,
         "frontier":{"pooled_profile_view_pass":profile_pass,"hiatus_profile_view_pass":hiatus_pass,
                     "zone_storage_view_pass":zone_pass,"retained":positive},
         "boundary":{"top_flux_matched":True,"bottom_flux_zero":True,"dry_bin_activation":False,
                     "ponding":False,"runoff":False},
         "blind_confirmation":False,"application_acceptance":False,"formal_performance_claim":False,
         "production_rom_authorized":False}
    pathlib.Path(a.output).write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print(json.dumps({"decision":decision,"integrity":out["integrity"],"frontier":out["frontier"],
                      "FMC_pooled":fmc_eval["pooled"],"R2_pooled":r2_eval["pooled"]},sort_keys=True))
    return 0
if __name__=="__main__":raise SystemExit(main())
