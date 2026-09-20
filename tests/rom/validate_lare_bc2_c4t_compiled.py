#!/usr/bin/env python3
from __future__ import annotations
import argparse,json,math,pathlib,re
import numpy as np

HISTS=("V01","V02","V03","V04")
STEPS=64

def fields(line):
    out={}
    for p in line.split("|")[1:]:
        if "=" in p:
            k,v=p.split("=",1);out[k]=v
    return out

def qstats(xs,kind):
    a=np.asarray(xs,float);aa=np.abs(a)
    if kind=="FMC":
        ordered=sorted(float(x) for x in aa)
        p95=ordered[min(len(ordered)-1,math.ceil(.95*len(ordered))-1)]
    else:
        p95=float(np.percentile(aa,95))
    return {"count":int(len(a)),"mean":float(np.mean(a)),"mean_abs":float(np.mean(aa)),
            "rmse":float(np.sqrt(np.mean(a*a))),"p95_abs":p95,
            "max_abs":float(np.max(aa))}

def sign(x):return 1 if x>0 else -1 if x<0 else 0

def parse_ref(path):
    states={};nodes={}
    for line in pathlib.Path(path).read_text(errors="replace").splitlines():
        if line.startswith("F_ROMV2_D13_REF_STATE|"):
            r=fields(line);states[(r["HISTORY"].strip(),int(r["STEP"]))]=r
        elif line.startswith("F_ROMV2_D13_REF_NODE|"):
            r=fields(line);nodes[(r["HISTORY"].strip(),int(r["STEP"]),int(r["NODE"]))]=r
    if len(states)!=4*64 or len(nodes)!=4*64*16:raise SystemExit("C4T reference structure")
    return states,nodes

def parse_candidate(path,kind):
    states={};cells={}
    state_prefix="LARE_BC2_C4T_STATE|" if kind=="LARE" else "LARE_BC2_C4T_FMC_STATE|"
    cell_prefix="LARE_BC2_C4T_CELL|" if kind=="LARE" else "LARE_BC2_C4T_FMC_CELL|"
    for line in pathlib.Path(path).read_text(errors="replace").splitlines():
        if line.startswith(state_prefix):
            r=fields(line);states[(r["HISTORY"].strip(),int(r["STEP"]))]=r
        elif line.startswith(cell_prefix):
            r=fields(line);cells[(r["HISTORY"].strip(),int(r["STEP"]),int(r["CELL"]))]=r
    if len(states)!=4*64 or len(cells)!=4*64*16:
        raise SystemExit(f"C4T {kind} validation structure states={len(states)} cells={len(cells)}")
    return states,cells

def compute(path,kind,refstates,refnodes):
    states,cells=parse_candidate(path,kind)
    allS=[];allC=[];allQ=[];allT=[];signerr=0;by={}
    for h in HISTS:
        es=[];ec=[];eq=[];et=[];hsign=0;rcum=0.0
        for st in range(1,STEPS+1):
            c=states[(h,st)];r=refstates[(h,st)]
            rcum+=float(r["BOTTOM_OUTWARD_EXCHANGE"])
            total=float(c["TOTAL_STORAGE"]);cum=float(c["CUM_BOTTOM"]);q=float(c["BOTTOM_FLUX"])
            rt=float(r["TOTAL_STORAGE"]);rq=float(r["BOTTOM_FLUX"])
            es.append(total-rt);ec.append(cum-rcum);eq.append(q-rq)
            if sign(rq)!=0 and sign(q)!=sign(rq):hsign+=1
            for cell in range(1,17):
                et.append(float(cells[(h,st,cell)]["THETA"])-float(refnodes[(h,st,cell)]["THETA"]))
        by[h]={
          "total_storage_error_cm":qstats(es,kind),
          "cumulative_bottom_exchange_error_cm":qstats(ec,kind),
          "terminal_bottom_flux_error_cm_per_day":qstats(eq,kind),
          "mapped_R16_cell_theta_error":qstats(et,kind),
          "bottom_flux_sign_error_count":hsign
        }
        allS+=es;allC+=ec;allQ+=eq;allT+=et;signerr+=hsign
    return {"pooled":{
      "total_storage_error_cm":qstats(allS,kind),
      "cumulative_bottom_exchange_error_cm":qstats(allC,kind),
      "terminal_bottom_flux_error_cm_per_day":qstats(allQ,kind),
      "mapped_R16_cell_theta_error":qstats(allT,kind),
      "bottom_flux_sign_error_count":signerr
    },"by_history":by}

def compare_stats(actual,expected,kind):
    maxdiff=0.0
    for metric,tol in [
      ("total_storage_error_cm",1e-10),
      ("cumulative_bottom_exchange_error_cm",1e-10),
      ("terminal_bottom_flux_error_cm_per_day",1e-8),
      ("mapped_R16_cell_theta_error",1e-12)
    ]:
        for stat in ("mean","mean_abs","rmse","p95_abs","max_abs"):
            d=abs(float(actual[metric][stat])-float(expected[metric][stat]))
            maxdiff=max(maxdiff,d)
            if d>tol:raise SystemExit(f"{kind} metric mismatch {metric} {stat} {d} > {tol}")
    if int(actual["bottom_flux_sign_error_count"])!=int(expected["bottom_flux_sign_error_count"]):
        raise SystemExit(f"{kind} sign count mismatch")
    return maxdiff

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--kind",choices=("LARE","FMC"),required=True)
    ap.add_argument("--route",required=True)
    ap.add_argument("--o0",required=True,type=pathlib.Path)
    ap.add_argument("--o2",required=True,type=pathlib.Path)
    ap.add_argument("--reference",required=True,type=pathlib.Path)
    ap.add_argument("--c4r-result",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    a=ap.parse_args()
    if a.o0.read_bytes()!=a.o2.read_bytes():raise SystemExit(f"{a.route} O0/O2 validation drift")
    c4r=json.loads(a.c4r_result.read_text())
    rs,rn=parse_ref(a.reference)
    actual=compute(a.o0,a.kind,rs,rn)
    if a.kind=="FMC":
        expected=c4r["comparators"]["FMC_GW200"]
    else:
        mid=a.route.replace("LARE_","")
        m=next(x for x in c4r["lare_members"] if x["id"]==mid)
        expected={"pooled":m["pooled"],"by_history":m["by_history"]}
    maxdiff=compare_stats(actual["pooled"],expected["pooled"],a.route)
    for h in HISTS:
        maxdiff=max(maxdiff,compare_stats(actual["by_history"][h],expected["by_history"][h],a.route+":"+h))
    out={"schema":"swap5.lare.bc2.c4t.compiled-equivalence.v1","route":a.route,"kind":a.kind,
         "pass":True,"O0_O2_stdout_identity":True,"maximum_checked_abs_difference":maxdiff,
         "actual":actual,"timing_authorized_for_route":True}
    a.output.write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print(json.dumps({"route":a.route,"pass":True,"maxdiff":maxdiff},sort_keys=True))
if __name__=="__main__":raise SystemExit(main())
