#!/usr/bin/env python3
from __future__ import annotations
import argparse,json,math,pathlib

TR=0.02; TS=0.427494; ALPHA=0.021659; N=1.734737; M=1.0-1.0/N
KS=31.225016; ELL=0.98087; NBINS=200; I=100; J0=101; J1=199
HCM=14.085215420920257; DEPTH=160.0; DT=10.0/86400.0
DTH=(TS-TR)/NBINS; TOL=1.0e-14
FACTORS={"S10":0.10,"S25":0.25,"S50":0.50,"S75":0.75}
PULSE=16; NSTEPS=64

def fields(payload):
    out={}
    for p in payload.split("|"):
        if "=" in p:
            k,v=p.split("=",1); out[k]=v
    return out

def parse_ref(path):
    states={}; nodes={}; initial={}; geom=None
    for line in pathlib.Path(path).read_text().splitlines():
        if "F_ROMV2_D16_REF_GEOMETRY|" in line:
            geom=fields(line.split("F_ROMV2_D16_REF_GEOMETRY|",1)[1])
        elif "F_ROMV2_D16_REF_INITIAL|" in line:
            r=fields(line.split("F_ROMV2_D16_REF_INITIAL|",1)[1]); initial[r["HISTORY"].strip()]=r
        elif "F_ROMV2_D16_REF_INITIAL_NODE|" in line:
            r=fields(line.split("F_ROMV2_D16_REF_INITIAL_NODE|",1)[1])
            nodes[(r["HISTORY"].strip(),0,int(r["NODE"]))]=r
        elif "F_ROMV2_D16_REF_STATE|" in line:
            r=fields(line.split("F_ROMV2_D16_REF_STATE|",1)[1])
            states[(r["HISTORY"].strip(),int(r["STEP"]))]=r
        elif "F_ROMV2_D16_REF_NODE|" in line:
            r=fields(line.split("F_ROMV2_D16_REF_NODE|",1)[1])
            nodes[(r["HISTORY"].strip(),int(r["STEP"]),int(r["NODE"]))]=r
    if geom is None: raise SystemExit("missing reference geometry")
    n=int(geom["N"])
    expected={(h,s) for h in FACTORS for s in range(1,NSTEPS+1)}
    if set(states)!=expected or set(initial)!=set(FACTORS):
        raise SystemExit(f"reference structure mismatch {path}")
    if len(nodes)!=len(FACTORS)*(NSTEPS+1)*n:
        raise SystemExit(f"reference node structure mismatch {path}")
    return {"n":n,"states":states,"nodes":nodes,"initial":initial}

def theta(j): return TR+j*DTH
def psi(t):
    se=(t-TR)/(TS-TR)
    return ((se**(-1.0/M)-1.0)**(1.0/N))/ALPHA
def kval(t):
    se=(t-TR)/(TS-TR)
    return KS*se**ELL*(1.0-(1.0-se**(1.0/M))**M)**2

TI=theta(I); TD=theta(J1); KI=kval(TI); KD=kval(TD)
GEFF=max(abs(psi(TD)),HCM); ADV=(KD-KI)/(TD-TI)

def initial_fronts():
    return {j:120.0+(10.0-120.0)*(j-J0)/(J1-J0) for j in range(J0,J1+1)}

def relax(fronts):
    keys=sorted(fronts)
    before=DTH*math.fsum(fronts[j] for j in keys)
    vals=sorted((fronts[j] for j in keys),reverse=True)
    out={j:v for j,v in zip(keys,vals)}
    after=DTH*math.fsum(out.values())
    if abs(after-before)>TOL: raise ValueError("relaxation mass drift")
    return out

def pulse_step(fronts,factor):
    supply=factor*KS*DT; rem=supply; out=dict(fronts)
    for j in range(J0,J1+1):
        z=fronts[j]
        v=ADV*(1.0+GEFF/z)
        raw=z+DT*v
        demand=max(0.0,DTH*(raw-z)); take=min(rem,demand)
        if take>0.0:
            out[j]=z+take/DTH; rem-=take
        if take<demand-1.0e-18 or rem<=1.0e-18: break
    if rem>TOL: raise ValueError("unabsorbed prescribed infiltration")
    return relax(out),supply

def slug_velocity(j):
    return (kval(theta(j))-kval(theta(j-1)))/(theta(j)-theta(j-1))

def mapped_theta16(connected,slugs):
    vals=[]
    for cell in range(16):
        top=10.0*cell; bottom=top+10.0
        t=TI
        if connected is not None:
            for z in connected.values():
                overlap=max(0.0,min(z,bottom)-top)
                t+=DTH*overlap/10.0
        if slugs is not None:
            for st,length in slugs.values():
                sb=st+length
                overlap=max(0.0,min(sb,bottom)-max(st,top))
                t+=DTH*overlap/10.0
        if not(TR<t<TS): raise ValueError("mapped theta bounds")
        vals.append(t)
    return vals

def fmc_history(factor):
    fronts=initial_fronts(); slugs=None; supplied=0.0
    rows={}
    maxmass=0.0
    for step in range(1,NSTEPS+1):
        if step<=PULSE:
            before=TI*DEPTH+DTH*math.fsum(fronts.values())
            fronts,supply=pulse_step(fronts,factor); supplied+=supply
            after=TI*DEPTH+DTH*math.fsum(fronts.values())
            mass=(after-before)-supply
            theta16=mapped_theta16(fronts,None)
        else:
            if step==PULSE+1:
                slugs={j:[0.0,z] for j,z in fronts.items()}
                fronts=None
            before=TI*DEPTH+DTH*math.fsum(length for _,length in slugs.values())
            for j,(top,length) in list(slugs.items()):
                nt=top+slug_velocity(j)*DT
                nb=nt+length
                if not(0.0<=nt<nb<DEPTH): raise ValueError("slug bounds")
                slugs[j]=[nt,length]
            after=TI*DEPTH+DTH*math.fsum(length for _,length in slugs.values())
            mass=after-before
            theta16=mapped_theta16(None,slugs)
        maxmass=max(maxmass,abs(mass))
        upper=10.0*math.fsum(theta16[:8]); lower=10.0*math.fsum(theta16[8:])
        total=upper+lower
        rows[step]={"theta16":theta16,"upper":upper,"lower":lower,"total":total,
                    "cumulative_infiltration":supplied,"mass_residual":mass}
    return rows,maxmass

def qstats(v):
    if not v:return {"count":0}
    a=sorted(abs(x) for x in v)
    return {"count":len(v),"mean":sum(v)/len(v),"mean_abs":sum(abs(x) for x in v)/len(v),
            "rmse":math.sqrt(sum(x*x for x in v)/len(v)),
            "p95_abs":a[min(len(a)-1,math.ceil(.95*len(a))-1)],"max_abs":a[-1]}

def compare_candidate(name,ref16,ref2=None):
    all_u=[];all_l=[];all_t=[];all_prof=[];hi_u=[];hi_l=[];hi_prof=[];by={};maxmass=0.0
    for h,factor in FACTORS.items():
        if name=="FMC":
            rows,mm=fmc_history(factor); maxmass=max(maxmass,mm)
        else:
            rows={}
            for st in range(1,NSTEPS+1):
                c=ref2["states"][(h,st)]
                ct=[float(ref2["nodes"][(h,st,1)]["THETA"])]*8+[float(ref2["nodes"][(h,st,2)]["THETA"])]*8
                rows[st]={"theta16":ct,"upper":float(c["UPPER_STORAGE"]),"lower":float(c["LOWER_STORAGE"]),
                          "total":float(c["TOTAL_STORAGE"]),"cumulative_infiltration":None,"mass_residual":float(c["MASS"])}
                maxmass=max(maxmass,abs(float(c["MASS"])))
        eu=[];el=[];et=[];ep=[];heu=[];hel=[];hep=[]
        for st in range(1,NSTEPS+1):
            r=ref16["states"][(h,st)]
            rt=[float(ref16["nodes"][(h,st,n)]["THETA"]) for n in range(1,17)]
            row=rows[st]
            u=row["upper"]-float(r["UPPER_STORAGE"]); l=row["lower"]-float(r["LOWER_STORAGE"]); t=row["total"]-float(r["TOTAL_STORAGE"])
            prof=[a-b for a,b in zip(row["theta16"],rt)]
            eu.append(u);el.append(l);et.append(t);ep+=prof
            if st>PULSE:
                heu.append(u);hel.append(l);hep+=prof
        by[h]={
          "upper_storage_error_cm":qstats(eu),"lower_storage_error_cm":qstats(el),
          "total_storage_error_cm":qstats(et),"mapped_R16_cell_theta_error":qstats(ep),
          "hiatus_upper_storage_error_cm":qstats(heu),"hiatus_lower_storage_error_cm":qstats(hel),
          "hiatus_mapped_R16_cell_theta_error":qstats(hep)
        }
        all_u+=eu;all_l+=el;all_t+=et;all_prof+=ep;hi_u+=heu;hi_l+=hel;hi_prof+=hep
    return {
      "pooled":{
        "upper_storage_error_cm":qstats(all_u),"lower_storage_error_cm":qstats(all_l),
        "total_storage_error_cm":qstats(all_t),"mapped_R16_cell_theta_error":qstats(all_prof),
        "hiatus_upper_storage_error_cm":qstats(hi_u),"hiatus_lower_storage_error_cm":qstats(hi_l),
        "hiatus_mapped_R16_cell_theta_error":qstats(hi_prof)
      },
      "by_history":by,"max_abs_mass_residual_cm":maxmass
    }

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--r16",required=True);ap.add_argument("--r2",required=True)
    ap.add_argument("--prereg",required=True);ap.add_argument("--preflight",required=True);ap.add_argument("--output",required=True)
    a=ap.parse_args()
    p=json.loads(pathlib.Path(a.prereg).read_text()); pre=json.loads(pathlib.Path(a.preflight).read_text())
    assert p["phase"]=="PREREGISTERED_BEFORE_INTERNAL_PREFLIGHT_AND_SWAP_TRAJECTORY_EXECUTION"
    assert pre["decision"]=="D16_FMC_SURFACE_REDISTRIBUTION_INTERNAL_PREFLIGHT_PASS"
    r16=parse_ref(a.r16);r2=parse_ref(a.r2)
    if r16["n"]!=16 or r2["n"]!=2: raise SystemExit("geometry mismatch")

    # Exact initial total/partition mapping must agree between R16 and R2.
    for h in FACTORS:
        for key in ("TOTAL_STORAGE","UPPER_STORAGE","LOWER_STORAGE"):
            if abs(float(r16["initial"][h][key])-float(r2["initial"][h][key]))>1e-12:
                raise SystemExit(f"initial R16/R2 mapping mismatch {h} {key}")

    fmc=compare_candidate("FMC",r16)
    r2c=compare_candidate("R2",r16,r2)
    fp=fmc["pooled"]; rp=r2c["pooled"]
    gates={
      "all_step_upper_storage":fp["upper_storage_error_cm"]["rmse"]<=rp["upper_storage_error_cm"]["rmse"],
      "all_step_profile_theta":fp["mapped_R16_cell_theta_error"]["rmse"]<=rp["mapped_R16_cell_theta_error"]["rmse"],
      "hiatus_upper_storage":fp["hiatus_upper_storage_error_cm"]["rmse"]<=rp["hiatus_upper_storage_error_cm"]["rmse"],
      "hiatus_profile_theta":fp["hiatus_mapped_R16_cell_theta_error"]["rmse"]<=rp["hiatus_mapped_R16_cell_theta_error"]["rmse"]
    }
    integrity=(fmc["max_abs_mass_residual_cm"]<=1e-12 and r2c["max_abs_mass_residual_cm"]<=1e-12)
    retained=integrity and all(gates.values())
    decision="FMC_SURFACE_REDISTRIBUTION_RETAINS_RESEARCH_CANDIDACY" if retained else "FMC_SURFACE_REDISTRIBUTION_NOT_COMPETITIVE_OR_NOT_ROBUST"
    out={
      "schema":"swap5.f-romv2-d16.result.v1","workstream":"F-ROM","work_unit":"F-ROMV2-D16",
      "decision":decision,"preflight_decision":pre["decision"],
      "candidate":{"id":"FMC_SURFACE200","moisture_bins":NBINS,"process_step_seconds":10,
                   "pulse_steps":PULSE,"hiatus_steps":NSTEPS-PULSE,"bottom_flux_cm_per_day":0.0,
                   "full_order_fallback_used":False},
      "integrity":{"pass":integrity,"FMC_max_abs_mass_residual_cm":fmc["max_abs_mass_residual_cm"],
                   "R2_max_abs_mass_residual_cm":r2c["max_abs_mass_residual_cm"]},
      "FMC":fmc,"R2":r2c,
      "frontier":{"gates":gates,"retained":retained},
      "application_acceptance":False,"formal_performance_claim":False,"production_rom_authorized":False
    }
    pathlib.Path(a.output).write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print(json.dumps({"decision":decision,"integrity":out["integrity"],"FMC":fp,"R2":rp,"frontier":out["frontier"]},sort_keys=True))
    return 0

if __name__=="__main__": raise SystemExit(main())
