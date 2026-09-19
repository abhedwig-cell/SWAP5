#!/usr/bin/env python3
from __future__ import annotations
import argparse,collections,json,math,pathlib

TR=0.02; TS=0.427494; ALPHA=0.021659; N=1.734737; M=1.0-1.0/N
KS=31.225016; ELL=0.98087; HCM=14.085215420920257
NB=200; I=100; J0=101; J1=199; DEPTH=160.0; DT=10.0/86400.0
DTH=(TS-TR)/NB; TOL=1e-12; RELAX_TOL=1e-14; NSTEPS=360; BLOCK=30
SEQS={
 "P_UP":[0.10,0.25,0.50,0.75]*3,
 "P_DOWN":[0.75,0.50,0.25,0.10]*3,
 "P_ALT_A":[0.10,0.75,0.25,0.50]*3,
 "P_ALT_B":[0.75,0.10,0.50,0.25]*3,
}
HISTS=list(SEQS)

def fields(payload):
    out={}
    for part in payload.split("|"):
        if "=" in part:
            k,v=part.split("=",1); out[k]=v
    return out

def parse_ref(path):
    states={}; nodes=collections.defaultdict(dict)
    for line in pathlib.Path(path).read_text().splitlines():
        if "F_ROMV2_D20_REF_STATE|" in line:
            r=fields(line.split("F_ROMV2_D20_REF_STATE|",1)[1]); states[(r["HISTORY"].strip(),int(r["STEP"]))]=r
        elif "F_ROMV2_D20_REF_NODE|" in line:
            r=fields(line.split("F_ROMV2_D20_REF_NODE|",1)[1]); nodes[(r["HISTORY"].strip(),int(r["STEP"]))][int(r["NODE"])]=r
    expected={(h,s) for h in HISTS for s in range(1,NSTEPS+1)}
    if set(states)!=expected or set(nodes)!=expected:
        raise SystemExit(f"reference structure mismatch {path}: states={len(states)} nodesets={len(nodes)}")
    n=len(nodes[next(iter(nodes))])
    if n not in (2,16): raise SystemExit(f"unexpected nodes {n}")
    if any(set(nodes[k])!=set(range(1,n+1)) for k in expected): raise SystemExit("node map mismatch")
    return {"states":states,"nodes":nodes,"n":n}

def theta(j): return TR+j*DTH
def psi(t):
    se=(t-TR)/(TS-TR); return ((se**(-1/M)-1)**(1/N))/ALPHA
def kval(t):
    se=(t-TR)/(TS-TR); return KS*se**ELL*(1-(1-se**(1/M))**M)**2
TI=theta(I); KI=kval(TI); TD=theta(J1); KD=kval(TD); GEFF=max(abs(psi(TD)),HCM); ADV=(KD-KI)/(TD-TI)

def initial_surface(): return {j:120+(10-120)*(j-J0)/(J1-J0) for j in range(J0,J1+1)}
def initial_gw(): return {j:0.25*abs(psi(theta(j))) for j in range(J0,J1+1)}
def relax(d):
    keys=sorted(d); before=DTH*math.fsum(d.values())
    vals=sorted(d.values(),reverse=True); out={j:v for j,v in zip(keys,vals)}
    if abs(DTH*math.fsum(out.values())-before)>RELAX_TOL: raise ValueError("relax drift")
    return out
def factor(seq,step): return seq[(step-1)//BLOCK]
def surface_step(fronts,f):
    supply=f*KS*DT; gray=KI*DT
    if supply+1e-18<gray: raise ValueError("supply below gray")
    rem=supply-gray; out=dict(fronts)
    for j in range(J0,J1+1):
        z=fronts[j]; raw=z+DT*ADV*(1+GEFF/z)
        if not(0<raw<DEPTH): raise ValueError("surface bounds")
        demand=max(0.0,DTH*(raw-z)); take=min(rem,demand)
        if take>0: out[j]=z+take/DTH; rem-=take
        if take<demand-1e-18 or rem<=1e-18: break
    if rem>1e-14: raise ValueError("unabsorbed supply")
    return relax(out),supply,gray
def gw_velocity(j,h):
    tj=theta(j); return (kval(tj)-KI)/(tj-TI)*(abs(psi(tj))/h-1)
def gw_step(gw):
    raw={j:h+DT*gw_velocity(j,h) for j,h in gw.items()}
    if not all(math.isfinite(h) and 0<h<=DEPTH for h in raw.values()): raise ValueError("gw bounds")
    return relax(raw)
def min_gap(fronts,gw): return min(DEPTH-fronts[j]-gw[j] for j in range(J0,J1+1))
def theta16(fronts,gw):
    vals=[]
    for c in range(16):
        top=10*c; bot=top+10; t=TI
        for j in range(J0,J1+1):
            surf=max(0.0,min(fronts[j],bot)-top)
            gtop=DEPTH-gw[j]; ground=max(0.0,bot-max(gtop,top))
            if surf>0 and ground>0 and min(fronts[j],bot)>max(gtop,top): raise ValueError("overlap")
            t += DTH*(surf+ground)/10
        vals.append(t)
    return vals
def gw_storage(gw): return TI*DEPTH+DTH*math.fsum(gw.values())
def total_storage(fronts,gw): return TI*DEPTH+DTH*math.fsum(fronts.values())+DTH*math.fsum(gw.values())
def bottom_flux(gw): return KI-DTH*math.fsum(gw_velocity(j,gw[j]) for j in range(J0,J1+1))
def sign(x): return 1 if x>0 else -1 if x<0 else 0

def fmc_history(seq):
    fronts=initial_surface(); gw=initial_gw(); rows={}; cum=0.; minsep=1e99; maxmass=0.
    for st in range(1,NSTEPS+1):
        sb=total_storage(fronts,gw); g0=gw_storage(gw)
        fronts2,supply,gray=surface_step(fronts,factor(seq,st))
        gw2=gw_step(gw); g1=gw_storage(gw2)
        bex=gray-(g1-g0); cum+=bex
        sa=total_storage(fronts2,gw2); mass=(sa-sb)-supply+bex
        gap=min_gap(fronts2,gw2)
        if gap<=0 or abs(mass)>TOL: raise ValueError(f"integrity st={st} gap={gap} mass={mass}")
        th=theta16(fronts2,gw2)
        rows[st]={"theta16":th,"upper":10*math.fsum(th[:8]),"lower":10*math.fsum(th[8:]),
                  "total":10*math.fsum(th),"bottom_exchange":bex,"cumulative_bottom":cum,
                  "bottom_flux":bottom_flux(gw2),"mass":mass,"gap":gap,"factor":factor(seq,st)}
        minsep=min(minsep,gap); maxmass=max(maxmass,abs(mass)); fronts,gw=fronts2,gw2
    return rows,minsep,maxmass

def qstats(vals):
    if not vals:return {"count":0}
    a=sorted(abs(x) for x in vals)
    return {"count":len(vals),"mean":sum(vals)/len(vals),"mean_abs":sum(abs(x) for x in vals)/len(vals),
            "rmse":math.sqrt(sum(x*x for x in vals)/len(vals)),
            "p95_abs":a[min(len(a)-1,math.ceil(.95*len(a))-1)],"max_abs":a[-1]}

def metrics(candidate,r16,r2=None,late=False):
    start=271 if late else 1
    pooled={k:[] for k in ("total","cum","profile","upper","lower","q")}
    signerr=0; by={}; minsep=1e99; maxmass=0.
    for h in HISTS:
        if candidate=="FMC":
            rows,sep,mm=fmc_history(SEQS[h]); minsep=min(minsep,sep); maxmass=max(maxmass,mm)
        else:
            rows={}
            src=r2
            for st in range(1,NSTEPS+1):
                s=src["states"][(h,st)]
                if src["n"]==2:
                    th=[float(src["nodes"][(h,st)][1]["THETA"])]*8+[float(src["nodes"][(h,st)][2]["THETA"])]*8
                else: th=[float(src["nodes"][(h,st)][i]["THETA"]) for i in range(1,17)]
                rows[st]={"theta16":th,"upper":float(s["UPPER_STORAGE"]),"lower":float(s["LOWER_STORAGE"]),
                          "total":float(s["TOTAL_STORAGE"]),"bottom_exchange":float(s["BOTTOM_OUTWARD_EXCHANGE"]),
                          "bottom_flux":float(s["BOTTOM_FLUX"]),"mass":float(s["MASS"])}
        cum=refcum=0.; et=[];ec=[];ep=[];eu=[];el=[];eq=[];se=0
        for st in range(1,NSTEPS+1):
            rr=r16["states"][(h,st)]
            rt=[float(r16["nodes"][(h,st)][i]["THETA"]) for i in range(1,17)]
            row=rows[st]; cum+=row["bottom_exchange"]; refcum+=float(rr["BOTTOM_OUTWARD_EXCHANGE"])
            if st<start: continue
            et.append(row["total"]-float(rr["TOTAL_STORAGE"])); ec.append(cum-refcum)
            eu.append(row["upper"]-float(rr["UPPER_STORAGE"])); el.append(row["lower"]-float(rr["LOWER_STORAGE"]))
            ep.extend(a-b for a,b in zip(row["theta16"],rt))
            qe=row["bottom_flux"]-float(rr["BOTTOM_FLUX"]); eq.append(qe)
            if sign(row["bottom_flux"])!=sign(float(rr["BOTTOM_FLUX"])): se+=1
        signerr+=se
        by[h]={"total_storage_error_cm":qstats(et),"cumulative_bottom_exchange_error_cm":qstats(ec),
               "mapped_theta_error":qstats(ep),"upper_storage_error_cm":qstats(eu),"lower_storage_error_cm":qstats(el),
               "bottom_flux_error_cm_per_day":qstats(eq),"bottom_flux_sign_error_count":se}
        pooled["total"]+=et; pooled["cum"]+=ec; pooled["profile"]+=ep; pooled["upper"]+=eu; pooled["lower"]+=el; pooled["q"]+=eq
    return {"by_history":by,"pooled":{
      "total_storage_error_cm":qstats(pooled["total"]),
      "cumulative_bottom_exchange_error_cm":qstats(pooled["cum"]),
      "mapped_R16_cell_theta_error":qstats(pooled["profile"]),
      "upper_storage_error_cm":qstats(pooled["upper"]),"lower_storage_error_cm":qstats(pooled["lower"]),
      "terminal_bottom_flux_error_cm_per_day":qstats(pooled["q"]),
      "bottom_flux_sign_error_count":signerr,
      "minimum_surface_groundwater_separation_cm":None if candidate!="FMC" else minsep,
      "max_abs_FMC_mass_residual_cm":None if candidate!="FMC" else maxmass}}

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--r16",required=True);ap.add_argument("--r2",required=True)
    ap.add_argument("--prereg",required=True);ap.add_argument("--preflight",required=True);ap.add_argument("--output",required=True)
    a=ap.parse_args()
    p=json.loads(pathlib.Path(a.prereg).read_text()); pre=json.loads(pathlib.Path(a.preflight).read_text())
    assert pre["decision"]=="D20_FMC_ONE_HOUR_PREFLIGHT_PASS"
    r16=parse_ref(a.r16); r2=parse_ref(a.r2)
    fullF=metrics("FMC",r16); fullR=metrics("R2",r16,r2); lateF=metrics("FMC",r16,late=True); lateR=metrics("R2",r16,r2,late=True)
    ff=fullF["pooled"]; fr=fullR["pooled"]; lf=lateF["pooled"]; lr=lateR["pooled"]
    gates={
      "full_total":ff["total_storage_error_cm"]["rmse"]<=fr["total_storage_error_cm"]["rmse"],
      "full_cumulative":ff["cumulative_bottom_exchange_error_cm"]["rmse"]<=fr["cumulative_bottom_exchange_error_cm"]["rmse"],
      "full_profile":ff["mapped_R16_cell_theta_error"]["rmse"]<=fr["mapped_R16_cell_theta_error"]["rmse"],
      "full_flux":ff["terminal_bottom_flux_error_cm_per_day"]["rmse"]<=fr["terminal_bottom_flux_error_cm_per_day"]["rmse"],
      "full_sign":ff["bottom_flux_sign_error_count"]<=fr["bottom_flux_sign_error_count"],
      "late_total":lf["total_storage_error_cm"]["rmse"]<=lr["total_storage_error_cm"]["rmse"],
      "late_cumulative":lf["cumulative_bottom_exchange_error_cm"]["rmse"]<=lr["cumulative_bottom_exchange_error_cm"]["rmse"],
      "late_profile":lf["mapped_R16_cell_theta_error"]["rmse"]<=lr["mapped_R16_cell_theta_error"]["rmse"],
      "late_flux":lf["terminal_bottom_flux_error_cm_per_day"]["rmse"]<=lr["terminal_bottom_flux_error_cm_per_day"]["rmse"]
    }
    retained=all(gates.values())
    decision="FMC_ONE_HOUR_PERSISTENCE_RETAINS_RESEARCH_CANDIDACY" if retained else "FMC_ONE_HOUR_PERSISTENCE_NOT_COMPETITIVE_OR_NOT_ROBUST"
    out={"schema":"swap5.f-romv2-d20.result.v1","workstream":"F-ROM","work_unit":"F-ROMV2-D20","decision":decision,
         "preflight":{"decision":pre["decision"],"equal_cumulative_top_input":pre["equal_cumulative_top_input"]},
         "FMC":{"full_hour":fullF,"late_window":lateF},"R2":{"full_hour":fullR,"late_window":lateR},
         "frontier":{"gates":gates,"all_views_required":True,"retained":retained},
         "application_acceptance":False,"formal_performance_claim":False,"production_rom_authorized":False}
    pathlib.Path(a.output).write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print(json.dumps({"decision":decision,"FMC_full":ff,"R2_full":fr,"FMC_late":lf,"R2_late":lr,"frontier":out["frontier"]},sort_keys=True))
    return 0
if __name__=="__main__": raise SystemExit(main())
