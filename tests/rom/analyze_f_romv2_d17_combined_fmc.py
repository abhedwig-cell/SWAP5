#!/usr/bin/env python3
from __future__ import annotations
import argparse,json,math,pathlib,collections

TR=0.02; TS=0.427494; ALPHA=0.021659; N=1.734737; M=1.0-1.0/N
KS=31.225016; ELL=0.98087; HCM=14.085215420920257
NBINS=200; I=100; J0=101; J1=199; DEPTH=160.0; DT=10.0/86400.0
DTH=(TS-TR)/NBINS; TOL=1e-12
HISTS={"C10_G25":0.10,"C25_G25":0.25,"C50_G25":0.50,"C75_G25":0.75}
STEPS=16

def fields(payload):
    out={}
    for part in payload.split("|"):
        if "=" in part:
            k,v=part.split("=",1); out[k]=v
    return out

def parse_ref(path):
    states={}; nodes=collections.defaultdict(dict); initial={}
    for line in pathlib.Path(path).read_text().splitlines():
        if "F_ROMV2_D17_REF_INITIAL|" in line:
            r=fields(line.split("F_ROMV2_D17_REF_INITIAL|",1)[1]); initial[r["HISTORY"]]=r
        elif "F_ROMV2_D17_REF_STATE|" in line:
            r=fields(line.split("F_ROMV2_D17_REF_STATE|",1)[1]); states[(r["HISTORY"],int(r["STEP"]))]=r
        elif "F_ROMV2_D17_REF_NODE|" in line:
            r=fields(line.split("F_ROMV2_D17_REF_NODE|",1)[1])
            if "THETA" not in r or "H" not in r:
                raise SystemExit(f"malformed node record {path}: {line}")
            nodes[(r["HISTORY"],int(r["STEP"]))][int(r["NODE"])]={
                "H":float(r["H"]),"THETA":float(r["THETA"])
            }
    expected={(h,s) for h in HISTS for s in range(1,STEPS+1)}
    if set(states)!=expected or set(nodes)!=expected:
        raise SystemExit(f"reference structure mismatch {path}")
    n=len(nodes[next(iter(nodes))])
    if n not in (2,16): raise SystemExit(f"unexpected node count {n}")
    if any(set(nodes[k])!=set(range(1,n+1)) for k in expected):
        raise SystemExit(f"node map mismatch {path}")
    return {"states":states,"nodes":nodes,"n":n,"initial":initial}

def theta(j): return TR+j*DTH
def psi(t):
    se=(t-TR)/(TS-TR)
    return ((se**(-1/M)-1)**(1/N))/ALPHA
def kval(t):
    se=(t-TR)/(TS-TR)
    return KS*se**ELL*(1-(1-se**(1/M))**M)**2

TI=theta(I); KI=kval(TI); TD=theta(J1); KD=kval(TD)
GEFF=max(abs(psi(TD)),HCM); ADV=(KD-KI)/(TD-TI)

def initial_surface():
    return {j:120.0+(10.0-120.0)*(j-J0)/(J1-J0) for j in range(J0,J1+1)}
def initial_gw():
    return {j:0.25*abs(psi(theta(j))) for j in range(J0,J1+1)}

def relax(d):
    keys=sorted(d)
    vals=sorted((d[j] for j in keys),reverse=True)
    return {j:v for j,v in zip(keys,vals)}

def surface_step(fronts,factor):
    supply=factor*KS*DT; gray=KI*DT; rem=supply-gray; out=dict(fronts)
    if rem<0: raise ValueError("gray demand exceeds supply")
    for j in range(J0,J1+1):
        z=fronts[j]; raw=z+DT*ADV*(1+GEFF/z)
        if not(0<raw<DEPTH): raise ValueError("surface raw bounds")
        demand=max(0.0,DTH*(raw-z)); take=min(rem,demand)
        if take>0: out[j]=z+take/DTH; rem-=take
        if take<demand-1e-18 or rem<=1e-18: break
    if rem>1e-14: raise ValueError("unabsorbed surface supply")
    return relax(out),supply,gray

def gw_velocity(j,h):
    tj=theta(j); return (kval(tj)-KI)/(tj-TI)*(abs(psi(tj))/h-1.0)

def gw_step(gw):
    raw={j:h+DT*gw_velocity(j,h) for j,h in gw.items()}
    if not all(math.isfinite(h) and 0<h<=DEPTH for h in raw.values()):
        raise ValueError("groundwater front bounds")
    return relax(raw)

def min_gap(fronts,gw):
    return min(DEPTH-fronts[j]-gw[j] for j in range(J0,J1+1))

def mapped_theta16(fronts,gw):
    out=[]
    for c in range(16):
        top=10.0*c; bot=top+10.0; t=TI
        for j in range(J0,J1+1):
            surf=max(0.0,min(fronts[j],bot)-top)
            gtop=DEPTH-gw[j]
            ground=max(0.0,bot-max(gtop,top))
            if surf>0 and ground>0 and min(fronts[j],bot)>max(gtop,top):
                raise ValueError("surface-groundwater overlap")
            t += DTH*(surf+ground)/10.0
        if not(TR<t<TS): raise ValueError("mapped theta bounds")
        out.append(t)
    return out

def gw_storage(gw): return TI*DEPTH + DTH*math.fsum(gw.values())
def total_storage(fronts,gw): return TI*DEPTH + DTH*math.fsum(fronts.values()) + DTH*math.fsum(gw.values())
def terminal_bottom_flux(gw): return KI - DTH*math.fsum(gw_velocity(j,gw[j]) for j in range(J0,J1+1))
def sign(x): return 1 if x>0 else -1 if x<0 else 0

def fmc_history(factor):
    fronts=initial_surface(); gw=initial_gw(); cum_bottom=0.; rows={}
    for st in range(1,STEPS+1):
        sb=total_storage(fronts,gw); g0=gw_storage(gw)
        fronts2,supply,gray=surface_step(fronts,factor)
        gw2=gw_step(gw); g1=gw_storage(gw2)
        bottom=gray-(g1-g0); cum_bottom+=bottom
        sa=total_storage(fronts2,gw2)
        mass=(sa-sb)-supply+bottom
        gap=min_gap(fronts2,gw2)
        if gap<=0 or abs(mass)>TOL: raise ValueError(f"integrity step {st}: gap={gap} mass={mass}")
        th=mapped_theta16(fronts2,gw2)
        rows[st]={
          "theta16":th,
          "upper":10*math.fsum(th[:8]),"lower":10*math.fsum(th[8:]),"total":10*math.fsum(th),
          "bottom_exchange":bottom,"cumulative_bottom":cum_bottom,
          "bottom_flux":terminal_bottom_flux(gw2),"mass":mass,"gap":gap
        }
        fronts,gw=fronts2,gw2
    return rows

def qstats(vals):
    if not vals:return {"count":0}
    a=sorted(abs(x) for x in vals)
    return {"count":len(vals),"mean":sum(vals)/len(vals),"mean_abs":sum(abs(x) for x in vals)/len(vals),
            "rmse":math.sqrt(sum(x*x for x in vals)/len(vals)),
            "p95_abs":a[min(len(a)-1,math.ceil(.95*len(a))-1)],"max_abs":a[-1]}

def candidate_rows(name,r16,r2=None):
    byhist={}
    all_tot=[];all_cum=[];all_prof=[];all_u=[];all_l=[];all_q=[];signerr=0
    minsep=1e99
    for h,factor in HISTS.items():
        if name=="FMC":
            rows=fmc_history(factor)
        else:
            rows={}
            ref=r2
            for st in range(1,STEPS+1):
                s=ref["states"][(h,st)]
                if ref["n"]==2:
                    theta16=[float(ref["nodes"][(h,st)][1]["THETA"])]*8+[float(ref["nodes"][(h,st)][2]["THETA"])]*8
                else:
                    theta16=[float(ref["nodes"][(h,st)][n]["THETA"]) for n in range(1,17)]
                rows[st]={"theta16":theta16,"upper":float(s["UPPER_STORAGE"]),"lower":float(s["LOWER_STORAGE"]),
                          "total":float(s["TOTAL_STORAGE"]),"bottom_exchange":float(s["BOTTOM_OUTWARD_EXCHANGE"]),
                          "bottom_flux":float(s["BOTTOM_FLUX"]),"mass":float(s["MASS"])}
        et=[];ec=[];ep=[];eu=[];el=[];eq=[];cum=0.;refcum=0.;se=0
        for st in range(1,STEPS+1):
            rr=r16["states"][(h,st)]
            rt=[float(r16["nodes"][(h,st)][n]["THETA"]) for n in range(1,17)]
            row=rows[st]; cum+=row["bottom_exchange"]; refcum+=float(rr["BOTTOM_OUTWARD_EXCHANGE"])
            et.append(row["total"]-float(rr["TOTAL_STORAGE"])); ec.append(cum-refcum)
            eu.append(row["upper"]-float(rr["UPPER_STORAGE"])); el.append(row["lower"]-float(rr["LOWER_STORAGE"]))
            ep.extend(a-b for a,b in zip(row["theta16"],rt))
            qerr=row["bottom_flux"]-float(rr["BOTTOM_FLUX"]); eq.append(qerr)
            if sign(row["bottom_flux"])!=sign(float(rr["BOTTOM_FLUX"])): se+=1
            if "gap" in row: minsep=min(minsep,row["gap"])
        signerr+=se
        byhist[h]={
          "total_storage_error_cm":qstats(et),"cumulative_bottom_exchange_error_cm":qstats(ec),
          "mapped_R16_cell_theta_error":qstats(ep),"upper_storage_error_cm":qstats(eu),
          "lower_storage_error_cm":qstats(el),"terminal_bottom_flux_error_cm_per_day":qstats(eq),
          "bottom_flux_sign_error_count":se,"final_cumulative_bottom_exchange_error_cm":ec[-1]
        }
        all_tot+=et;all_cum+=ec;all_prof+=ep;all_u+=eu;all_l+=el;all_q+=eq
    return {
      "by_history":byhist,
      "pooled":{
        "total_storage_error_cm":qstats(all_tot),"cumulative_bottom_exchange_error_cm":qstats(all_cum),
        "mapped_R16_cell_theta_error":qstats(all_prof),"upper_storage_error_cm":qstats(all_u),
        "lower_storage_error_cm":qstats(all_l),"terminal_bottom_flux_error_cm_per_day":qstats(all_q),
        "bottom_flux_sign_error_count":signerr,
        "minimum_surface_groundwater_separation_cm":None if name!="FMC" else minsep
      }
    }

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--r16",required=True);ap.add_argument("--r2",required=True)
    ap.add_argument("--prereg",required=True);ap.add_argument("--preflight",required=True);ap.add_argument("--output",required=True)
    a=ap.parse_args()
    p=json.loads(pathlib.Path(a.prereg).read_text()); pre=json.loads(pathlib.Path(a.preflight).read_text())
    assert p["phase"]=="PREREGISTERED_BEFORE_INTERNAL_PREFLIGHT_AND_SWAP_TRAJECTORY_EXECUTION"
    assert pre["decision"]=="D17_FMC_COMBINED_PULSE_GW_PREFLIGHT_PASS"
    r16=parse_ref(a.r16); r2=parse_ref(a.r2)
    if r16["n"]!=16 or r2["n"]!=2: raise SystemExit("geometry identity mismatch")
    fmc=candidate_rows("FMC",r16); coarse=candidate_rows("R2",r16,r2)
    fp=fmc["pooled"]; rp=coarse["pooled"]
    gates={
      "balance_total_storage":fp["total_storage_error_cm"]["rmse"]<=rp["total_storage_error_cm"]["rmse"],
      "balance_cumulative_bottom_exchange":fp["cumulative_bottom_exchange_error_cm"]["rmse"]<=rp["cumulative_bottom_exchange_error_cm"]["rmse"],
      "profile_theta":fp["mapped_R16_cell_theta_error"]["rmse"]<=rp["mapped_R16_cell_theta_error"]["rmse"],
      "groundwater_bottom_flux_magnitude":fp["terminal_bottom_flux_error_cm_per_day"]["rmse"]<=rp["terminal_bottom_flux_error_cm_per_day"]["rmse"],
      "groundwater_bottom_flux_sign":fp["bottom_flux_sign_error_count"]<=rp["bottom_flux_sign_error_count"]
    }
    retained=all(gates.values())
    decision=("FMC_COMBINED_SURFACE_GROUNDWATER_RETAINS_RESEARCH_CANDIDACY"
              if retained else "FMC_COMBINED_SURFACE_GROUNDWATER_NOT_COMPETITIVE_OR_NOT_ROBUST")
    max_fmc_mass=max(abs(row["mass"]) for f in HISTS.values() for row in fmc_history(f).values())
    max_r2_mass=max(abs(float(s["MASS"])) for s in r2["states"].values())
    max_r16_mass=max(abs(float(s["MASS"])) for s in r16["states"].values())
    out={
      "schema":"swap5.f-romv2-d17.result.v1","workstream":"F-ROM","work_unit":"F-ROMV2-D17",
      "decision":decision,
      "integrity":{"pass":True,"FMC_max_abs_mass_residual_cm":max_fmc_mass,
                   "R2_max_abs_mass_residual_cm":max_r2_mass,"R16_max_abs_mass_residual_cm":max_r16_mass,
                   "hard_mass_gate_cm":1e-12},
      "FMC":fmc,"R2":coarse,
      "frontier":{"gates":gates,"all_views_required":True,"retained":retained},
      "application_acceptance":False,"formal_performance_claim":False,"production_rom_authorized":False
    }
    pathlib.Path(a.output).write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print(json.dumps({"decision":decision,"integrity":out["integrity"],"FMC":fp,"R2":rp,"frontier":out["frontier"]},sort_keys=True))
    return 0

if __name__=="__main__": raise SystemExit(main())
