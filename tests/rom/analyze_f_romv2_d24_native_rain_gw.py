#!/usr/bin/env python3
from __future__ import annotations
import argparse,json,math,pathlib,collections

TR=0.02; TS=0.427494; ALPHA=0.021659; N=1.734737; M=1.0-1.0/N
KS=31.225016; ELL=0.98087; HCM=14.085215420920257
NBINS=200; I=100; J0=101; J1=199; DEPTH=160.0; DT=10.0/86400.0
DTH=(TS-TR)/NBINS; TOL=1e-12; PONDMAX=KS*DT; RSRO=0.001
HISTS={"RG05":0.5,"RG20":2.0,"RG40":4.0}; STEPS=16

def fields(payload):
    out={}
    for p in payload.split("|"):
        if "=" in p:
            k,v=p.split("=",1); out[k]=v
    return out

def parse_ref(path):
    states={}; nodes=collections.defaultdict(dict); geom=None
    for line in pathlib.Path(path).read_text().splitlines():
        if "F_ROMV2_D24_REF_GEOMETRY|" in line:
            geom=fields(line.split("F_ROMV2_D24_REF_GEOMETRY|",1)[1])
        elif "F_ROMV2_D24_REF_STATE|" in line:
            r=fields(line.split("F_ROMV2_D24_REF_STATE|",1)[1]); states[(r["HISTORY"],int(r["STEP"]))]=r
        elif "F_ROMV2_D24_REF_NODE|" in line:
            r=fields(line.split("F_ROMV2_D24_REF_NODE|",1)[1]); nodes[(r["HISTORY"],int(r["STEP"]))][int(r["NODE"])]=r
    if geom is None: raise SystemExit(f"missing geometry in {path}")
    n=int(geom["N"]); expected={(h,s) for h in HISTS for s in range(1,STEPS+1)}
    if set(states)!=expected or set(nodes)!=expected: raise SystemExit(f"reference structure mismatch {path}")
    if any(set(nodes[k])!=set(range(1,n+1)) for k in expected): raise SystemExit(f"node structure mismatch {path}")
    return {"n":n,"states":states,"nodes":nodes}

def theta(j): return TR+j*DTH
def psi(t):
    se=(t-TR)/(TS-TR); return ((se**(-1/M)-1)**(1/N))/ALPHA
def kval(t):
    se=(t-TR)/(TS-TR)
    return KS*se**ELL*(1-(1-se**(1/M))**M)**2

TI=theta(I); KI=kval(TI); TD=theta(J1); KD=kval(TD)
GEFF=max(abs(psi(TD)),HCM); ADV=(KD-KI)/(TD-TI)

def initial_surface(): return {j:120.0+(10.0-120.0)*(j-J0)/(J1-J0) for j in range(J0,J1+1)}
def initial_gw(): return {j:0.25*abs(psi(theta(j))) for j in range(J0,J1+1)}

def relax_map(d):
    keys=sorted(d); before=DTH*math.fsum(d.values())
    vals=sorted((d[j] for j in keys),reverse=True); out={j:v for j,v in zip(keys,vals)}
    after=DTH*math.fsum(out.values())
    if abs(after-before)>1e-14: raise ValueError("relaxation mass drift")
    return out

def surface_route(residual):
    if residual<=PONDMAX:return residual,0.0
    ratio=DT/RSRO; store=(residual+ratio*PONDMAX)/(1+ratio); return store,residual-store

def connected_surface_step(fronts,available):
    gray=KI*DT
    if available+1e-18<gray: raise ValueError("surface water below gray demand")
    rem=available-gray; out=dict(fronts); alloc=0.0
    for j in range(J0,J1+1):
        z=fronts[j]; raw=z+DT*ADV*(1+GEFF/z)
        if not(math.isfinite(raw) and 0<raw<DEPTH): raise ValueError("surface front bounds")
        demand=max(0.0,DTH*(raw-z)); take=min(rem,demand)
        if take>0: out[j]=z+take/DTH; rem-=take; alloc+=take
        if take<demand-1e-18 or rem<=1e-18: break
    out=relax_map(out); store,runoff=surface_route(max(0.0,rem))
    return out,gray,alloc,store,runoff

def gw_velocity(j,h):
    tj=theta(j); return (kval(tj)-KI)/(tj-TI)*(abs(psi(tj))/h-1.0)

def gw_step(gw):
    raw={j:h+DT*gw_velocity(j,h) for j,h in gw.items()}
    if not all(math.isfinite(h) and 0<h<=DEPTH for h in raw.values()): raise ValueError("gw bounds")
    return relax_map(raw)

def gw_storage(gw): return TI*DEPTH+DTH*math.fsum(gw.values())
def total_storage(fronts,gw): return TI*DEPTH+DTH*math.fsum(fronts.values())+DTH*math.fsum(gw.values())
def min_gap(fronts,gw): return min(DEPTH-fronts[j]-gw[j] for j in range(J0,J1+1))
def terminal_bottom_flux(gw): return KI-DTH*math.fsum(gw_velocity(j,gw[j]) for j in range(J0,J1+1))

def mapped_theta16(fronts,gw):
    vals=[]
    for c in range(16):
        top=10*c;bot=top+10;t=TI
        for j in range(J0,J1+1):
            surf=max(0.0,min(fronts[j],bot)-top); gtop=DEPTH-gw[j]; ground=max(0.0,bot-max(gtop,top))
            if surf>0 and ground>0 and min(fronts[j],bot)>max(gtop,top): raise ValueError("overlap")
            t+=DTH*(surf+ground)/10.0
        if not(TR<t<TS): raise ValueError("mapped theta bounds")
        vals.append(t)
    return vals

def fmc_history(factor):
    fronts=initial_surface();gw=initial_gw();store=0.;cumrun=0.;cumin=0.;cumbot=0.;rows=[]
    for step in range(1,STEPS+1):
        rain=factor*KS*DT; sb=total_storage(fronts,gw); g0=gw_storage(gw); prev=store
        fronts2,gray,alloc,store,runoff=connected_surface_step(fronts,prev+rain)
        gw2=gw_step(gw); g1=gw_storage(gw2); dgw=g1-g0
        infil=gray+alloc; bottom=gray-dgw; sa=total_storage(fronts2,gw2)
        surfledger=prev+rain-infil-store-runoff; soilledger=(sa-sb)-infil+bottom
        globalledger=(sa-sb)+store-prev+runoff+bottom-rain
        gap=min_gap(fronts2,gw2)
        if gap<=0 or max(abs(surfledger),abs(soilledger),abs(globalledger))>TOL: raise ValueError("FMC integrity")
        th=mapped_theta16(fronts2,gw2); cumrun+=runoff;cumin+=infil;cumbot+=bottom
        rows.append({"step":step,"rain_cm":rain,"infiltration_cm":infil,"cumulative_infiltration_cm":cumin,
                     "surface_store_cm":store,"runoff_cm":runoff,"cumulative_runoff_cm":cumrun,
                     "total_storage_cm":10*math.fsum(th),"upper_storage_cm":10*math.fsum(th[:8]),
                     "lower_storage_cm":10*math.fsum(th[8:]),"theta16":th,
                     "bottom_exchange_cm":bottom,"cumulative_bottom_exchange_cm":cumbot,
                     "bottom_flux_cm_per_day":terminal_bottom_flux(gw2),"minimum_separation_cm":gap,
                     "surface_ledger_cm":surfledger,"global_ledger_cm":globalledger})
        fronts,gw=fronts2,gw2
    return rows

def ref_rows(ref,h):
    cum_in=0.;cum_bot=0.;out=[]
    for step in range(1,STEPS+1):
        r=ref["states"][(h,step)]; cum_in+=float(r["INFIL_CM"]);cum_bot+=float(r["BOTTOM_OUTWARD_EXCHANGE"])
        theta_nodes=[float(ref["nodes"][(h,step)][j]["THETA"]) for j in range(1,ref["n"]+1)]
        mapped=theta_nodes if ref["n"]==16 else [theta_nodes[0]]*8+[theta_nodes[1]]*8
        out.append({"step":step,"cumulative_infiltration_cm":cum_in,"surface_store_cm":float(r["SURFACE_STORE_CM"]),
                    "cumulative_runoff_cm":float(r["CUM_RUNOFF_CM"]),"total_storage_cm":float(r["TOTAL_STORAGE"]),
                    "upper_storage_cm":float(r["UPPER_STORAGE"]),"lower_storage_cm":float(r["LOWER_STORAGE"]),
                    "theta16":mapped,"cumulative_bottom_exchange_cm":cum_bot,
                    "bottom_flux_cm_per_day":float(r["BOTTOM_FLUX"]),"surface_ledger_cm":float(r["SURFACE_LEDGER_CM"]),
                    "mass_cm":float(r["MASS"])})
    return out

def qstats(v):
    a=sorted(abs(x) for x in v)
    return {"count":len(v),"mean":sum(v)/len(v),"mean_abs":sum(abs(x) for x in v)/len(v),
            "rmse":math.sqrt(sum(x*x for x in v)/len(v)),"p95_abs":a[min(len(a)-1,math.ceil(.95*len(a))-1)],
            "max_abs":a[-1]}
def sign(x): return 1 if x>0 else -1 if x<0 else 0

def compare(rows,refrows):
    keys=["cumulative_infiltration_cm","surface_store_cm","cumulative_runoff_cm","total_storage_cm",
          "cumulative_bottom_exchange_cm","upper_storage_cm","lower_storage_cm","bottom_flux_cm_per_day"]
    errs={k:[] for k in keys}; theta_err=[]; signerr=0
    for c,r in zip(rows,refrows):
        for k in keys: errs[k].append(c[k]-r[k])
        theta_err.extend(a-b for a,b in zip(c["theta16"],r["theta16"]))
        if sign(c["bottom_flux_cm_per_day"])!=sign(r["bottom_flux_cm_per_day"]): signerr+=1
    out={k:qstats(v) for k,v in errs.items()};out["mapped_theta"]=qstats(theta_err);out["bottom_flux_sign_error_count"]=signerr
    return out

def main():
    ap=argparse.ArgumentParser();ap.add_argument("--prereg",required=True);ap.add_argument("--preflight",required=True)
    ap.add_argument("--r16",required=True);ap.add_argument("--r2",required=True);ap.add_argument("--output",required=True)
    a=ap.parse_args();p=json.loads(pathlib.Path(a.prereg).read_text());pre=json.loads(pathlib.Path(a.preflight).read_text())
    assert pre["decision"]=="D24_FMC_NATIVE_RAIN_GW_PREFLIGHT_PASS"
    assert p["phase"]=="PREREGISTERED_BEFORE_FMC_INTERNAL_PREFLIGHT_AND_RICHARDS_TRAJECTORY_EXECUTION"
    R16=parse_ref(a.r16);R2=parse_ref(a.r2)
    if R16["n"]!=16 or R2["n"]!=2: raise SystemExit("geometry mismatch")
    metrics={"FMC":{},"R2":{}}; by={}; minsep=1e99; integrity=True
    pooled={name:collections.defaultdict(list) for name in ("FMC","R2")}
    sign_tot={"FMC":0,"R2":0}
    for h,f in HISTS.items():
        rr=ref_rows(R16,h); fr=fmc_history(f); cr=ref_rows(R2,h)
        integrity &= all(abs(x["surface_ledger_cm"])<=TOL and abs(x["mass_cm"])<=TOL for x in rr+cr)
        minsep=min(minsep,min(x["minimum_separation_cm"] for x in fr))
        by[h]={}
        for name,rows in (("FMC",fr),("R2",cr)):
            m=compare(rows,rr);by[h][name]=m;sign_tot[name]+=m["bottom_flux_sign_error_count"]
            for k,v in m.items():
                if isinstance(v,dict): pooled[name][k].extend([]) # placeholder; recompute below
        # pooled raw errors
        for name,rows in (("FMC",fr),("R2",cr)):
            for c,r in zip(rows,rr):
                for k in ("cumulative_infiltration_cm","surface_store_cm","cumulative_runoff_cm","total_storage_cm","cumulative_bottom_exchange_cm","upper_storage_cm","lower_storage_cm","bottom_flux_cm_per_day"):
                    pooled[name][k].append(c[k]-r[k])
                pooled[name]["mapped_theta"].extend(a-b for a,b in zip(c["theta16"],r["theta16"]))
    summary={}
    for name in ("FMC","R2"):
        summary[name]={k:qstats(v) for k,v in pooled[name].items()}
        summary[name]["bottom_flux_sign_error_count"]=sign_tot[name]
    gates={
      "cumulative_infiltration_RMSE":summary["FMC"]["cumulative_infiltration_cm"]["rmse"]<=summary["R2"]["cumulative_infiltration_cm"]["rmse"],
      "surface_store_RMSE":summary["FMC"]["surface_store_cm"]["rmse"]<=summary["R2"]["surface_store_cm"]["rmse"],
      "cumulative_runoff_RMSE":summary["FMC"]["cumulative_runoff_cm"]["rmse"]<=summary["R2"]["cumulative_runoff_cm"]["rmse"],
      "total_storage_RMSE":summary["FMC"]["total_storage_cm"]["rmse"]<=summary["R2"]["total_storage_cm"]["rmse"],
      "cumulative_bottom_exchange_RMSE":summary["FMC"]["cumulative_bottom_exchange_cm"]["rmse"]<=summary["R2"]["cumulative_bottom_exchange_cm"]["rmse"],
      "mapped_theta_RMSE":summary["FMC"]["mapped_theta"]["rmse"]<=summary["R2"]["mapped_theta"]["rmse"],
      "terminal_bottom_flux_RMSE":summary["FMC"]["bottom_flux_cm_per_day"]["rmse"]<=summary["R2"]["bottom_flux_cm_per_day"]["rmse"],
      "bottom_flux_sign_error_count":summary["FMC"]["bottom_flux_sign_error_count"]<=summary["R2"]["bottom_flux_sign_error_count"]
    }
    retained=bool(integrity and all(gates.values()))
    decision="FMC_NATIVE_RAINFALL_GROUNDWATER_COMPOSITION_RETAINS_RESEARCH_CANDIDACY_RELATIVE_TO_R2" if retained else "FMC_NATIVE_RAINFALL_GROUNDWATER_COMPOSITION_NOT_COMPETITIVE_OR_NOT_ROBUST"
    out={"schema":"swap5.f-romv2-d24.result.v1","workstream":"F-ROM","work_unit":"F-ROMV2-D24","decision":decision,
         "integrity":{"pass":bool(integrity),"minimum_FMC_surface_groundwater_separation_cm":minsep},
         "metrics_vs_R16":summary,"by_history":by,"frontier_gates":gates,"retained":retained,
         "interpretation":{"R16_threshold_equivalence_required":False,"application_acceptance":False,"formal_performance_claim":False},
         "production_rom_authorized":False}
    pathlib.Path(a.output).write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print(json.dumps({"decision":decision,"integrity":out["integrity"],"gates":gates,"FMC":summary["FMC"],"R2":summary["R2"]},sort_keys=True))
    return 0

if __name__=="__main__": raise SystemExit(main())
