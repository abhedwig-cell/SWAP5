#!/usr/bin/env python3
from __future__ import annotations
import argparse,collections,json,math,pathlib

HISTS=["X25","X50","X75","X125"]
NSTEPS=64
EARLY=set(range(1,9))

def fields(payload):
    out={}
    for part in payload.split("|"):
        if "=" in part:
            k,v=part.split("=",1); out[k]=v
    return out

def parse_ref(path,nodes):
    states={}; nm=collections.defaultdict(dict)
    for line in pathlib.Path(path).read_text().splitlines():
        if "F_ROMV2_D19_REF_STATE|" in line:
            r=fields(line.split("F_ROMV2_D19_REF_STATE|",1)[1]); states[(r["HISTORY"].strip(),int(r["STEP"]))]=r
        elif "F_ROMV2_D19_REF_NODE|" in line:
            r=fields(line.split("F_ROMV2_D19_REF_NODE|",1)[1]); nm[(r["HISTORY"].strip(),int(r["STEP"]))][int(r["NODE"])]=r
    exp={(h,s) for h in HISTS for s in range(1,NSTEPS+1)}
    if set(states)!=exp or set(nm)!=exp: raise SystemExit(f"reference structure mismatch: {path}")
    if any(set(nm[k])!=set(range(1,nodes+1)) for k in exp): raise SystemExit(f"reference node count mismatch: {path}")
    return states,nm

def stats(vals):
    vals=[float(v) for v in vals]
    if not vals:return {"count":0}
    av=sorted(abs(v) for v in vals)
    return {"count":len(vals),"mean":sum(vals)/len(vals),"mean_abs":sum(abs(v) for v in vals)/len(vals),
            "rmse":math.sqrt(sum(v*v for v in vals)/len(vals)),
            "p95_abs":av[min(len(av)-1,math.ceil(.95*len(av))-1)],"max_abs":av[-1]}

def sign(x): return 1 if x>0 else -1 if x<0 else 0

def theta_map(nodes,n):
    if n==16:return [float(nodes[i]["THETA"]) for i in range(1,17)]
    if n==2:return [float(nodes[1]["THETA"])]*8+[float(nodes[2]["THETA"])]*8
    raise ValueError(n)

def summary_dict(acc,sign_errors):
    return {
      "total_storage_error_cm":stats(acc["storage"]),
      "upper_storage_error_cm":stats(acc["upper"]),
      "lower_storage_error_cm":stats(acc["lower"]),
      "cumulative_bottom_exchange_error_cm":stats(acc["cum"]),
      "mapped_theta_error":stats(acc["theta"]),
      "terminal_bottom_flux_error_cm_per_day":stats(acc["q"]),
      "bottom_flux_sign_error_count":sign_errors
    }

def compare(model_states,model_nodes,n,ref_states,ref_nodes,fmc=None):
    keys=("storage","upper","lower","cum","theta","q")
    pooled={k:[] for k in keys}; early={k:[] for k in keys}
    total_sign=early_sign=0; by={}
    cum_m={h:0.0 for h in HISTS}; cum_r={h:0.0 for h in HISTS}
    for h in HISTS:
        ha={k:[] for k in keys}; he={k:[] for k in keys}; hs=hes=0
        for step in range(1,NSTEPS+1):
            rr=ref_states[(h,step)]
            rt=[float(ref_nodes[(h,step)][i]["THETA"]) for i in range(1,17)]
            cum_r[h]+=float(rr["BOTTOM_OUTWARD_EXCHANGE"])
            if fmc is None:
                mr=model_states[(h,step)]; mt=theta_map(model_nodes[(h,step)],n)
                cum_m[h]+=float(mr["BOTTOM_OUTWARD_EXCHANGE"])
                storage=float(mr["TOTAL_STORAGE"]); q=float(mr["BOTTOM_FLUX"])
                upper=float(mr["UPPER_STORAGE"]); lower=float(mr["LOWER_STORAGE"])
            else:
                row=fmc[h]["steps"][step-1]; mt=[float(x) for x in row["theta16"]]
                cum_m[h]=float(row["cumulative_bottom_outward_exchange_cm"])
                storage=float(row["storage_cm"]); q=float(row["terminal_bottom_outward_flux_cm_per_day"])
                upper=10.0*sum(mt[:8]); lower=10.0*sum(mt[8:])
            vals={
              "storage":storage-float(rr["TOTAL_STORAGE"]),
              "upper":upper-float(rr["UPPER_STORAGE"]),
              "lower":lower-float(rr["LOWER_STORAGE"]),
              "cum":cum_m[h]-cum_r[h],
              "q":q-float(rr["BOTTOM_FLUX"])
            }
            for k,v in vals.items():
                pooled[k].append(v); ha[k].append(v)
                if step in EARLY: early[k].append(v); he[k].append(v)
            terr=[mt[i]-rt[i] for i in range(16)]
            pooled["theta"].extend(terr); ha["theta"].extend(terr)
            if step in EARLY: early["theta"].extend(terr); he["theta"].extend(terr)
            if sign(q)!=sign(float(rr["BOTTOM_FLUX"])):
                total_sign+=1; hs+=1
                if step in EARLY: early_sign+=1; hes+=1
        by[h]={"all":summary_dict(ha,hs),"early_steps_1_8":summary_dict(he,hes)}
    return {"pooled":summary_dict(pooled,total_sign),"early_steps_1_8":summary_dict(early,early_sign),"by_history":by}

def main():
    ap=argparse.ArgumentParser()
    for a in ("r16","r2","preflight","prereg","authorization","output"): ap.add_argument("--"+a,required=True)
    a=ap.parse_args()
    p=json.loads(pathlib.Path(a.prereg).read_text()); auth=json.loads(pathlib.Path(a.authorization).read_text())
    pre=json.loads(pathlib.Path(a.preflight).read_text())
    assert p["phase"]=="PREREGISTERED_BEFORE_INTERNAL_PREFLIGHT_AND_SWAP_TRAJECTORY_EXECUTION"
    assert auth["phase"]=="STAGE2_AUTHORIZED_AFTER_IMMUTABLE_FMC_PREFLIGHT"
    assert auth["stage2"]["SWAP_trajectory_generation_authorized"] is True
    assert pre["decision"]=="D19_FMC_EXACT_CONTACT_MERGE_PREFLIGHT_PASS"
    assert pre["SWAP_trajectory_generation_authorized"] is True
    r16s,r16n=parse_ref(a.r16,16); r2s,r2n=parse_ref(a.r2,2)
    fmc=pre["histories"]
    fc=compare(None,None,0,r16s,r16n,fmc=fmc); rc=compare(r2s,r2n,2,r16s,r16n)
    fp,rp=fc["pooled"],rc["pooled"]; fe,re=fc["early_steps_1_8"],rc["early_steps_1_8"]
    gates={
      "all_total_storage":fp["total_storage_error_cm"]["rmse"]<=rp["total_storage_error_cm"]["rmse"],
      "all_cumulative_bottom_exchange":fp["cumulative_bottom_exchange_error_cm"]["rmse"]<=rp["cumulative_bottom_exchange_error_cm"]["rmse"],
      "all_mapped_theta":fp["mapped_theta_error"]["rmse"]<=rp["mapped_theta_error"]["rmse"],
      "all_bottom_flux_magnitude":fp["terminal_bottom_flux_error_cm_per_day"]["rmse"]<=rp["terminal_bottom_flux_error_cm_per_day"]["rmse"],
      "all_bottom_flux_sign":fp["bottom_flux_sign_error_count"]<=rp["bottom_flux_sign_error_count"],
      "early_total_storage":fe["total_storage_error_cm"]["rmse"]<=re["total_storage_error_cm"]["rmse"],
      "early_cumulative_bottom_exchange":fe["cumulative_bottom_exchange_error_cm"]["rmse"]<=re["cumulative_bottom_exchange_error_cm"]["rmse"],
      "early_mapped_theta":fe["mapped_theta_error"]["rmse"]<=re["mapped_theta_error"]["rmse"],
      "early_bottom_flux_magnitude":fe["terminal_bottom_flux_error_cm_per_day"]["rmse"]<=re["terminal_bottom_flux_error_cm_per_day"]["rmse"]
    }
    retained=all(gates.values())
    decision="FMC_EXACT_CONTACT_MERGE_RETAINS_RESEARCH_CANDIDACY" if retained else "FMC_EXACT_CONTACT_MERGE_NOT_COMPETITIVE_OR_NOT_ROBUST"
    maxmass=max(float(v["max_abs_step_mass_residual_cm"]) for v in fmc.values())
    maxmerge=max(abs(float(v["merge_storage_residual_cm"])) for v in fmc.values())
    out={
      "schema":"swap5.f-romv2-d19.result.v1","workstream":"F-ROM","work_unit":"F-ROMV2-D19",
      "decision":decision,
      "preflight":{"decision":pre["decision"],"merge_counts":{h:v["merge_count"] for h,v in fmc.items()},
                   "max_abs_merge_storage_residual_cm":maxmerge,"max_abs_step_mass_residual_cm":maxmass},
      "integrity":{"pass":maxmass<=1e-12 and maxmerge<=1e-14,"hard_mass_gate_cm":1e-12},
      "FMC":fc,"R2":rc,"frontier":{"gates":gates,"all_views_required":True,"retained":retained},
      "application_acceptance":False,"formal_performance_claim":False,"production_rom_authorized":False
    }
    pathlib.Path(a.output).write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print(json.dumps({"decision":decision,"gates":gates,"FMC_pooled":fp,"R2_pooled":rp,
                      "FMC_early":fe,"R2_early":re},sort_keys=True))
    return 0

if __name__=="__main__": raise SystemExit(main())
