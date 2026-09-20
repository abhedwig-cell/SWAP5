#!/usr/bin/env python3
from __future__ import annotations
import argparse,json,math,pathlib
import numpy as np

HISTS=("V01","V02","V03","V04")
STEPS=64
DEPTH=160.0

def fields(payload):
    out={}
    for p in payload.split("|"):
        if "=" in p:
            k,v=p.split("=",1);out[k]=v
    return out

def qstats(xs):
    a=np.asarray(xs,dtype=float); aa=np.abs(a)
    return {
      "count":int(len(a)),"mean":float(np.mean(a)),"mean_abs":float(np.mean(aa)),
      "rmse":float(np.sqrt(np.mean(a*a))),"p95_abs":float(np.percentile(aa,95)),
      "max_abs":float(np.max(aa))
    }

def sign(x): return 1 if x>0 else -1 if x<0 else 0

def parse_log(path):
    states={};nodes={};geom=None;initial=None
    for line in pathlib.Path(path).read_text(errors="replace").splitlines():
        if line.startswith("F_ROMV2_D13_REF_GEOMETRY|"):
            geom=fields(line.split("|",1)[1])
        elif line.startswith("F_ROMV2_D13_REF_INITIAL|"):
            initial=fields(line.split("|",1)[1])
        elif line.startswith("F_ROMV2_D13_REF_STATE|"):
            r=fields(line.split("|",1)[1]);states[int(r["STEP"])]=r
        elif line.startswith("F_ROMV2_D13_REF_NODE|"):
            r=fields(line.split("|",1)[1]);nodes[(int(r["STEP"]),int(r["NODE"]))]=r
    if geom is None or initial is None or len(states)!=STEPS:
        raise RuntimeError(f"incomplete log {path}")
    n=int(geom["N"])
    if len(nodes)!=STEPS*n:
        raise RuntimeError(f"node count mismatch {path}")
    return {"n":n,"states":states,"nodes":nodes,"initial":initial}

def parse_r16(path):
    states={};nodes={};initial={};n=None
    for line in pathlib.Path(path).read_text(errors="replace").splitlines():
        if line.startswith("F_ROMV2_D13_REF_GEOMETRY|"):
            r=fields(line.split("|",1)[1]);n=int(r["N"])
        elif line.startswith("F_ROMV2_D13_REF_INITIAL|"):
            r=fields(line.split("|",1)[1]);initial[r["HISTORY"].strip()]=r
        elif line.startswith("F_ROMV2_D13_REF_STATE|"):
            r=fields(line.split("|",1)[1]);states[(r["HISTORY"].strip(),int(r["STEP"]))]=r
        elif line.startswith("F_ROMV2_D13_REF_NODE|"):
            r=fields(line.split("|",1)[1]);nodes[(r["HISTORY"].strip(),int(r["STEP"]),int(r["NODE"]))]=r
    if n!=16 or len(states)!=len(HISTS)*STEPS or len(nodes)!=len(HISTS)*STEPS*16:
        raise RuntimeError("R16 structure mismatch")
    return {"n":n,"states":states,"nodes":nodes,"initial":initial}

def bounds_from_thickness(th):
    out=[0.0];z=0.0
    for x in th:
        z+=float(x);out.append(z)
    if abs(z-DEPTH)>1e-12:raise RuntimeError("depth mismatch")
    return out

def map_to_10cm(theta,bounds):
    vals=[]
    for cell in range(16):
        lo=10.0*cell;hi=lo+10.0;tot=0.0
        for t,a,b in zip(theta,bounds[:-1],bounds[1:]):
            w=max(0.0,min(hi,b)-max(lo,a));tot+=float(t)*w
        vals.append(tot/10.0)
    return vals

def integrated(theta,bounds,lo,hi):
    return sum(float(t)*max(0.0,min(hi,b)-max(lo,a)) for t,a,b in zip(theta,bounds[:-1],bounds[1:]))

def metrics_for_member(member_dir,member,thickness,r16):
    bounds=bounds_from_thickness(thickness)
    allS=[];allC=[];allQ=[];allT=[];allU=[];allL=[];signerr=0;by={}
    for h in HISTS:
        p=pathlib.Path(member_dir)/member/f"{member}-{h}-o0.txt"
        c=parse_log(p)
        if c["n"]!=len(thickness):raise RuntimeError(f"{member} node mismatch")
        cum=0.0;rcum=0.0;es=[];ec=[];eq=[];et=[];eu=[];el=[];hsign=0
        for st in range(1,STEPS+1):
            s=c["states"][st];r=r16["states"][(h,st)]
            cum+=float(s["BOTTOM_OUTWARD_EXCHANGE"]);rcum+=float(r["BOTTOM_OUTWARD_EXCHANGE"])
            es.append(float(s["TOTAL_STORAGE"])-float(r["TOTAL_STORAGE"]))
            ec.append(cum-rcum)
            cq=float(s["BOTTOM_FLUX"]);rq=float(r["BOTTOM_FLUX"]);eq.append(cq-rq)
            if sign(rq)!=0 and sign(cq)!=sign(rq):hsign+=1
            theta=[float(c["nodes"][(st,node)]["THETA"]) for node in range(1,c["n"]+1)]
            mapped=map_to_10cm(theta,bounds)
            for node,t in enumerate(mapped,1):
                et.append(t-float(r16["nodes"][(h,st,node)]["THETA"]))
            ru=sum(float(r16["nodes"][(h,st,node)]["THETA"])*10.0 for node in range(1,9))
            rl=sum(float(r16["nodes"][(h,st,node)]["THETA"])*10.0 for node in range(9,17))
            eu.append(integrated(theta,bounds,0.0,80.0)-ru)
            el.append(integrated(theta,bounds,80.0,160.0)-rl)
        by[h]={
          "total_storage_error_cm":qstats(es),
          "cumulative_bottom_exchange_error_cm":qstats(ec),
          "terminal_bottom_flux_error_cm_per_day":qstats(eq),
          "mapped_R16_cell_theta_error":qstats(et),
          "upper_storage_error_cm":qstats(eu),
          "lower_storage_error_cm":qstats(el),
          "bottom_flux_sign_error_count":hsign,
          "final_cumulative_bottom_exchange_error_cm":ec[-1]
        }
        allS+=es;allC+=ec;allQ+=eq;allT+=et;allU+=eu;allL+=el;signerr+=hsign
    return {"pooled":{
      "total_storage_error_cm":qstats(allS),
      "cumulative_bottom_exchange_error_cm":qstats(allC),
      "terminal_bottom_flux_error_cm_per_day":qstats(allQ),
      "mapped_R16_cell_theta_error":qstats(allT),
      "upper_storage_error_cm":qstats(allU),
      "lower_storage_error_cm":qstats(allL),
      "bottom_flux_sign_error_count":signerr
    },"by_history":by}

def compact(p):
    return {
      "storage_rmse_cm":p["total_storage_error_cm"]["rmse"],
      "cumulative_bottom_rmse_cm":p["cumulative_bottom_exchange_error_cm"]["rmse"],
      "bottom_flux_rmse_cm_per_day":p["terminal_bottom_flux_error_cm_per_day"]["rmse"],
      "mapped_theta_rmse":p["mapped_R16_cell_theta_error"]["rmse"],
      "bottom_flux_sign_errors":p["bottom_flux_sign_error_count"]
    }

def zero_ref():
    z={"count":len(HISTS)*STEPS,"mean":0.0,"mean_abs":0.0,"rmse":0.0,"p95_abs":0.0,"max_abs":0.0}
    zt={"count":len(HISTS)*STEPS*16,"mean":0.0,"mean_abs":0.0,"rmse":0.0,"p95_abs":0.0,"max_abs":0.0}
    return {
      "total_storage_error_cm":dict(z),
      "cumulative_bottom_exchange_error_cm":dict(z),
      "terminal_bottom_flux_error_cm_per_day":dict(z),
      "mapped_R16_cell_theta_error":dict(zt),
      "upper_storage_error_cm":dict(z),
      "lower_storage_error_cm":dict(z),
      "bottom_flux_sign_error_count":0
    }

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--c4r-result",required=True,type=pathlib.Path)
    ap.add_argument("--c4r-r16",required=True,type=pathlib.Path)
    ap.add_argument("--c4s-member-dir",required=True,type=pathlib.Path)
    ap.add_argument("--c4s-closeout",required=True,type=pathlib.Path)
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    a=ap.parse_args()
    pre=json.loads(a.prereg.read_text());c4r=json.loads(a.c4r_result.read_text());c4s=json.loads(a.c4s_closeout.read_text())
    assert pre["phase"]=="PREREGISTERED_AFTER_C4S_BEFORE_COMPILED_COST_EXPOSURE"
    assert c4r["decision"]=="C4R_BLIND_PROFILE_FRONTIER_REPLICATED"
    assert c4s["decision"]=="C4S_CORICHARDS_FULL_COMMON_COHORT_AVAILABLE"
    r16=parse_r16(a.c4r_r16)

    table={}
    # Immutable existing routes.
    for m in c4r["lare_members"]:
        if int(m["dimension"])<16:
            table["LARE_"+m["id"]]={"family":"LARE","dimension":m["dimension"],"metrics":{"pooled":m["pooled"],"by_history":m["by_history"]}}
    table["COR_R2"]={"family":"CoRichards","dimension":2,"metrics":c4r["comparators"]["R2"]}
    table["FMC"]={"family":"FMC","dimension":None,"metrics":c4r["comparators"]["FMC_GW200"]}
    table["R16"]={"family":"Reference","dimension":16,"metrics":{"pooled":zero_ref(),"by_history":{}}}

    th={x["id"].replace("COR_",""):x["partition"] for x in pre["route_set"]["CoRichards"] if x["id"]!="COR_R2"}
    for mid in ("R3","R4","R5","R6","R8","R12"):
        met=metrics_for_member(a.c4s_member_dir,mid,th[mid],r16)
        table["COR_"+mid]={"family":"CoRichards","dimension":int(mid[1:]),"metrics":met}

    # Bind C4R immutable metrics exactly for imported routes.
    for rid,key in [("COR_R2","R2"),("FMC","FMC_GW200")]:
        assert table[rid]["metrics"]["pooled"]==c4r["comparators"][key]["pooled"]
    for m in c4r["lare_members"]:
        if int(m["dimension"])<16:
            assert table["LARE_"+m["id"]]["metrics"]["pooled"]==m["pooled"]

    compact_table={rid:{**{k:v for k,v in row.items() if k!="metrics"},"fidelity":compact(row["metrics"]["pooled"])} for rid,row in table.items()}
    out={
      "schema":"swap5.lare.bc2.c4t.fidelity-table.v1",
      "workstream":"F-ROM-LARE","work_unit":"LARE-BC2-C4T",
      "timing_exposed":False,
      "routes":table,
      "compact":compact_table,
      "purpose_vectors":pre["hydrological_fidelity_binding"]["purpose_vectors"],
      "source":{"C4R_result_sha256":"d913dfc03d46be25e9ca625a789ca47bc6407fd847406de0696fa39d5a522c65",
                "C4S_result_sha256":"6a3fee756d86772b38c879e96acd0fa30d73ad6ec84476ff1c8a60b4291265bd"},
      "application_acceptance_adjudicated":False,
      "weighted_score_used":False
    }
    a.output.write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print(json.dumps(compact_table,sort_keys=True))
    return 0
if __name__=="__main__": raise SystemExit(main())
