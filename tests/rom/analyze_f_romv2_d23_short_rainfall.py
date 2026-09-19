#!/usr/bin/env python3
from __future__ import annotations
import argparse,json,math,pathlib

TR=0.02; TS=0.427494; ALPHA=0.021659; N=1.734737; M=1.0-1.0/N
KS=31.225016; ELL=0.98087; NBINS=200; I=100; J0=101; J1=199
HCM=14.085215420920257; DEPTH=160.0; DT=10.0/86400.0
DTH=(TS-TR)/NBINS; TOL=1e-14; PONDMAX=KS*DT; RSRO=0.001
HISTS={"R05":0.5,"R20":2.0,"R40":4.0}; STORM=16; NSTEPS=64

def fields(payload):
    out={}
    for p in payload.split("|"):
        if "=" in p:
            k,v=p.split("=",1); out[k]=v
    return out

def theta(j): return TR+j*DTH
def psi(t):
    se=(t-TR)/(TS-TR)
    return ((se**(-1.0/M)-1.0)**(1.0/N))/ALPHA
def kval(t):
    if t<=TR:return 0.0
    if t>=TS:return KS
    se=(t-TR)/(TS-TR)
    return KS*se**ELL*(1.0-(1.0-se**(1.0/M))**M)**2

TI=theta(I); TD=theta(J1); KI=kval(TI); KD=kval(TD)
GEFF=max(abs(psi(TD)),HCM); ADV=(KD-KI)/(TD-TI)

def parse_ref(path):
    states={}; nodes={}; geom=None
    for line in pathlib.Path(path).read_text().splitlines():
        if "F_ROMV2_D23_REF_GEOMETRY|" in line:
            geom=fields(line.split("F_ROMV2_D23_REF_GEOMETRY|",1)[1])
        elif "F_ROMV2_D23_REF_STATE|" in line:
            r=fields(line.split("F_ROMV2_D23_REF_STATE|",1)[1])
            states[(r["HISTORY"].strip(),int(r["STEP"]))]=r
        elif "F_ROMV2_D23_REF_NODE|" in line:
            r=fields(line.split("F_ROMV2_D23_REF_NODE|",1)[1])
            nodes[(r["HISTORY"].strip(),int(r["STEP"]),int(r["NODE"]))]=r
    if geom is None: raise SystemExit("missing geometry")
    n=int(geom["N"])
    expected={(h,s) for h in HISTS for s in range(1,NSTEPS+1)}
    if set(states)!=expected: raise SystemExit(f"state structure mismatch {path}")
    if len(nodes)!=len(HISTS)*NSTEPS*n: raise SystemExit(f"node structure mismatch {path}")
    return {"n":n,"states":states,"nodes":nodes}

def initial_fronts():
    return {j:120.0+(10.0-120.0)*(j-J0)/(J1-J0) for j in range(J0,J1+1)}

def relax(fronts):
    keys=sorted(fronts); vals=sorted((fronts[j] for j in keys),reverse=True)
    before=DTH*math.fsum(fronts.values()); out={j:v for j,v in zip(keys,vals)}
    after=DTH*math.fsum(out.values())
    if abs(after-before)>TOL: raise ValueError("relax mass")
    return out

def slug_velocity(j):
    return (kval(theta(j))-kval(theta(j-1)))/(theta(j)-theta(j-1))

def surface_route(residual):
    if residual<=PONDMAX:return residual,0.0
    ratio=DT/RSRO
    store=(residual+ratio*PONDMAX)/(1.0+ratio)
    return store,residual-store

def mapped_theta16(fronts,slugs):
    vals=[]
    for cell in range(16):
        top=10.0*cell;bot=top+10.0;t=TI
        if fronts is not None:
            for z in fronts.values():
                t+=DTH*max(0.0,min(z,bot)-top)/10.0
        else:
            for st,length in slugs.values():
                sb=st+length
                t+=DTH*max(0.0,min(sb,bot)-max(st,top))/10.0
        if not(TR<t<TS): raise ValueError("mapped theta bounds")
        vals.append(t)
    return vals

def soil_storage(fronts,slugs):
    return math.fsum(mapped_theta16(fronts,slugs))*10.0

def connected_step(fronts,available):
    rem=available; out=dict(fronts); infil=0.0
    for j in range(J0,J1+1):
        z=fronts[j];raw=z+ADV*(1.0+GEFF/z)*DT
        if not(math.isfinite(raw) and 0<raw<DEPTH):raise ValueError("front bounds")
        demand=max(0.0,DTH*(raw-z));take=min(rem,demand)
        if take>0:
            out[j]=z+take/DTH;rem-=take;infil+=take
        if take<demand-1e-18 or rem<=1e-18:break
    out=relax(out);store,runoff=surface_route(max(0.0,rem))
    return out,infil,store,runoff

def fmc_history(factor):
    fronts=initial_fronts();slugs=None;surf=0.0;cumrun=0.0;cuminfil=0.0;rows=[]
    for step in range(1,NSTEPS+1):
        rain=factor*KS*DT if step<=STORM else 0.0
        before=soil_storage(fronts,slugs);prev=surf
        if fronts is not None:
            fronts,infil,surf,runoff=connected_step(fronts,prev+rain)
            if step>STORM and surf<=TOL:
                slugs={j:[0.0,z] for j,z in fronts.items()};fronts=None
        else:
            if rain>TOL or prev>TOL:raise ValueError("surface input after detach")
            for j,(top,length) in list(slugs.items()):
                nt=top+slug_velocity(j)*DT;nb=nt+length
                if not(0<=nt<nb<DEPTH):raise ValueError("slug bounds")
                slugs[j]=[nt,length]
            infil=0.0;surf=0.0;runoff=0.0
        after=soil_storage(fronts,slugs)
        ledger=prev+rain-infil-surf-runoff
        global_step=(after-before)+surf-prev+runoff-rain
        if abs(ledger)>1e-12 or abs(global_step)>1e-12:raise ValueError("FMC ledger")
        cumrun+=runoff;cuminfil+=infil
        th=mapped_theta16(fronts,slugs)
        rows.append({"step":step,"rain_cm":rain,"infiltration_cm":infil,"cumulative_infiltration_cm":cuminfil,
                     "surface_store_cm":surf,"runoff_cm":runoff,"cumulative_runoff_cm":cumrun,
                     "total_storage_cm":math.fsum(th)*10.0,
                     "upper_storage_cm":math.fsum(th[:8])*10.0,"lower_storage_cm":math.fsum(th[8:])*10.0,
                     "theta16":th,"surface_ledger_cm":ledger})
    return rows

def qstats(v):
    if not v:return {"count":0}
    av=sorted(abs(x) for x in v)
    return {"count":len(v),"mean":sum(v)/len(v),"mean_abs":sum(abs(x) for x in v)/len(v),
            "rmse":math.sqrt(sum(x*x for x in v)/len(v)),
            "p95_abs":av[min(len(av)-1,math.ceil(.95*len(av))-1)],"max_abs":av[-1]}

def first_step(rows,key):
    for r in rows:
        if r[key]>TOL:return r["step"]
    return None

def ref_rows(ref,h):
    cum_in=0.0
    out=[]
    for step in range(1,NSTEPS+1):
        r=ref["states"][(h,step)]
        cum_in+=float(r["INFIL_CM"])
        theta=[float(ref["nodes"][(h,step,j)]["THETA"]) for j in range(1,ref["n"]+1)]
        if ref["n"]==2:
            mapped=[theta[0]]*8+[theta[1]]*8
        else:
            mapped=theta
        out.append({"step":step,"infiltration_cm":float(r["INFIL_CM"]),"cumulative_infiltration_cm":cum_in,
                    "surface_store_cm":float(r["SURFACE_STORE_CM"]),"runoff_cm":float(r["RUNOFF_CM"]),
                    "cumulative_runoff_cm":float(r["CUM_RUNOFF_CM"]),
                    "total_storage_cm":float(r["TOTAL_STORAGE"]),"upper_storage_cm":float(r["UPPER_STORAGE"]),
                    "lower_storage_cm":float(r["LOWER_STORAGE"]),"theta16":mapped,
                    "surface_ledger_cm":float(r["SURFACE_LEDGER_CM"]),
                    "soil_mass_cm":float(r["MASS"]),"bottom_exchange_cm":float(r["BOTTOM_OUTWARD_EXCHANGE"])})
    return out

def errors(cand,ref,key,steps=None):
    idx=range(NSTEPS) if steps is None else [s-1 for s in steps]
    return [cand[i][key]-ref[i][key] for i in idx]

def theta_errors(cand,ref,steps=None):
    idx=range(NSTEPS) if steps is None else [s-1 for s in steps]
    return [cand[i]["theta16"][j]-ref[i]["theta16"][j] for i in idx for j in range(16)]

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--prereg",required=True);ap.add_argument("--preflight",required=True)
    ap.add_argument("--r16",required=True);ap.add_argument("--r2",required=True);ap.add_argument("--output",required=True)
    a=ap.parse_args()
    p=json.loads(pathlib.Path(a.prereg).read_text());pre=json.loads(pathlib.Path(a.preflight).read_text())
    assert pre["decision"]=="D23_FMC_SHORT_RAINFALL_INTERNAL_PREFLIGHT_PASS"
    assert p["phase"]=="PREREGISTERED_BEFORE_FMC_INTERNAL_PREFLIGHT_AND_RICHARDS_TRAJECTORY_EXECUTION"
    R16=parse_ref(a.r16);R2=parse_ref(a.r2)
    if R16["n"]!=16 or R2["n"]!=2:raise SystemExit("geometry mismatch")

    rows={"R16":{},"R2":{},"FMC":{}}
    integrity=True
    for h,f in HISTS.items():
        rows["R16"][h]=ref_rows(R16,h);rows["R2"][h]=ref_rows(R2,h);rows["FMC"][h]=fmc_history(f)
        for route in ("R16","R2"):
            integrity &= all(abs(x["surface_ledger_cm"])<=1e-12 and abs(x["soil_mass_cm"])<=1e-12 and abs(x["bottom_exchange_cm"])<=1e-12 for x in rows[route][h])

    metrics={}
    hiatus=range(17,65)
    for name in ("R2","FMC"):
        e_ci=[];e_store=[];e_run=[];e_up=[];e_theta=[];e_up_h=[];e_theta_h=[];e_tot=[];e_low=[]
        by={}
        for h in HISTS:
            c=rows[name][h];r=rows["R16"][h]
            xci=errors(c,r,"cumulative_infiltration_cm"); xs=errors(c,r,"surface_store_cm")
            xr=errors(c,r,"cumulative_runoff_cm"); xu=errors(c,r,"upper_storage_cm")
            xt=theta_errors(c,r); xuh=errors(c,r,"upper_storage_cm",hiatus); xth=theta_errors(c,r,hiatus)
            et=errors(c,r,"total_storage_cm"); el=errors(c,r,"lower_storage_cm")
            e_ci+=xci;e_store+=xs;e_run+=xr;e_up+=xu;e_theta+=xt;e_up_h+=xuh;e_theta_h+=xth;e_tot+=et;e_low+=el
            by[h]={"cumulative_infiltration_rmse_cm":qstats(xci)["rmse"],
                   "surface_store_rmse_cm":qstats(xs)["rmse"],"cumulative_runoff_rmse_cm":qstats(xr)["rmse"],
                   "upper_storage_rmse_cm":qstats(xu)["rmse"],"mapped_theta_rmse":qstats(xt)["rmse"],
                   "hiatus_upper_storage_rmse_cm":qstats(xuh)["rmse"],"hiatus_mapped_theta_rmse":qstats(xth)["rmse"],
                   "first_ponding_step":first_step(c,"surface_store_cm"),"first_runoff_step":first_step(c,"runoff_cm"),
                   "final_cumulative_runoff_error_cm":xr[-1],"final_upper_storage_error_cm":xu[-1],
                   "final_lower_storage_error_cm":el[-1]}
        metrics[name]={"pooled":{
          "cumulative_infiltration_error_cm":qstats(e_ci),"surface_store_error_cm":qstats(e_store),
          "cumulative_runoff_error_cm":qstats(e_run),"upper_storage_error_cm":qstats(e_up),
          "mapped_theta_error":qstats(e_theta),"hiatus_upper_storage_error_cm":qstats(e_up_h),
          "hiatus_mapped_theta_error":qstats(e_theta_h),"total_storage_error_cm":qstats(e_tot),
          "lower_storage_error_cm":qstats(e_low)},"by_history":by}

    gates={
      "cumulative_infiltration_RMSE":metrics["FMC"]["pooled"]["cumulative_infiltration_error_cm"]["rmse"]<=metrics["R2"]["pooled"]["cumulative_infiltration_error_cm"]["rmse"],
      "surface_store_RMSE":metrics["FMC"]["pooled"]["surface_store_error_cm"]["rmse"]<=metrics["R2"]["pooled"]["surface_store_error_cm"]["rmse"],
      "cumulative_runoff_RMSE":metrics["FMC"]["pooled"]["cumulative_runoff_error_cm"]["rmse"]<=metrics["R2"]["pooled"]["cumulative_runoff_error_cm"]["rmse"],
      "upper_storage_RMSE":metrics["FMC"]["pooled"]["upper_storage_error_cm"]["rmse"]<=metrics["R2"]["pooled"]["upper_storage_error_cm"]["rmse"],
      "mapped_theta_RMSE":metrics["FMC"]["pooled"]["mapped_theta_error"]["rmse"]<=metrics["R2"]["pooled"]["mapped_theta_error"]["rmse"],
      "hiatus_upper_storage_RMSE":metrics["FMC"]["pooled"]["hiatus_upper_storage_error_cm"]["rmse"]<=metrics["R2"]["pooled"]["hiatus_upper_storage_error_cm"]["rmse"],
      "hiatus_mapped_theta_RMSE":metrics["FMC"]["pooled"]["hiatus_mapped_theta_error"]["rmse"]<=metrics["R2"]["pooled"]["hiatus_mapped_theta_error"]["rmse"]
    }
    retained=integrity and all(gates.values())
    decision="FMC_SHORT_RAINFALL_TRAJECTORY_RETAINS_FAST_SURFACE_RESEARCH_CANDIDACY_RELATIVE_TO_R2" if retained else "FMC_SHORT_RAINFALL_TRAJECTORY_NOT_COMPETITIVE_WITH_R2"
    diagnostics={}
    for h in HISTS:
        diagnostics[h]={name:{"first_ponding_step":first_step(rows[name][h],"surface_store_cm"),
                              "first_runoff_step":first_step(rows[name][h],"runoff_cm"),
                              "final_cumulative_runoff_cm":rows[name][h][-1]["cumulative_runoff_cm"]}
                        for name in ("R16","R2","FMC")}
    out={"schema":"swap5.f-romv2-d23.result.v1","workstream":"F-ROM","work_unit":"F-ROMV2-D23",
         "decision":decision,"integrity":{"pass":bool(integrity)},"metrics_vs_R16":metrics,
         "frontier_gates":gates,"all_required":True,"retained":retained,
         "native_timing_diagnostics":diagnostics,
         "interpretation":{"R16_threshold_equivalence_required":False,"D21_reclassified":False,"D22_reclassified":False,
                           "application_acceptance":False,"formal_performance_claim":False},
         "production_rom_authorized":False}
    pathlib.Path(a.output).write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print(json.dumps({"decision":decision,"integrity":integrity,"gates":gates,
                      "FMC":metrics["FMC"]["pooled"],"R2":metrics["R2"]["pooled"],"timing":diagnostics},sort_keys=True))
    return 0

if __name__=="__main__": raise SystemExit(main())
