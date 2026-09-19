#!/usr/bin/env python3
from __future__ import annotations
import argparse,collections,json,math,pathlib

HISTS=["M25","M50","M75","M125"]
NSTEPS=64
TRANSITION_STEPS=set(range(1,9))

def fields(payload):
    out={}
    for part in payload.split("|"):
        if "=" in part:
            k,v=part.split("=",1); out[k]=v
    return out

def parse_ref(path,nodes):
    states={}
    node_map=collections.defaultdict(dict)
    for line in pathlib.Path(path).read_text().splitlines():
        if "F_ROMV2_D18_REF_STATE|" in line:
            r=fields(line.split("F_ROMV2_D18_REF_STATE|",1)[1])
            states[(r["HISTORY"].strip(),int(r["STEP"]))]=r
        elif "F_ROMV2_D18_REF_NODE|" in line:
            r=fields(line.split("F_ROMV2_D18_REF_NODE|",1)[1])
            node_map[(r["HISTORY"].strip(),int(r["STEP"]))][int(r["NODE"])]=r
    expected={(h,s) for h in HISTS for s in range(1,NSTEPS+1)}
    if set(states)!=expected: raise SystemExit(f"state structure mismatch {path}")
    if set(node_map)!=expected: raise SystemExit(f"node structure mismatch {path}")
    for k in expected:
        if set(node_map[k])!=set(range(1,nodes+1)): raise SystemExit(f"node count mismatch {path} {k}")
    return states,node_map

def qstats(vals):
    vals=[float(x) for x in vals]
    if not vals:return {"count":0}
    av=sorted(abs(x) for x in vals)
    return {
      "count":len(vals),"mean":sum(vals)/len(vals),"mean_abs":sum(abs(x) for x in vals)/len(vals),
      "rmse":math.sqrt(sum(x*x for x in vals)/len(vals)),
      "p95_abs":av[min(len(av)-1,math.ceil(.95*len(av))-1)],"max_abs":av[-1]
    }

def sign(x): return 1 if x>0 else -1 if x<0 else 0

def mapped_theta(nodes,n):
    if n==16:
        return [float(nodes[i]["THETA"]) for i in range(1,17)]
    if n==2:
        return [float(nodes[1]["THETA"])]*8+[float(nodes[2]["THETA"])]*8
    raise ValueError(n)

def compare_model(model_states,model_nodes,n,ref_states,ref_nodes,fmc=None):
    pooled={k:[] for k in ("storage","cum","theta","q")}
    trans={k:[] for k in ("storage","cum","theta","q")}
    sign_errors=0; trans_sign_errors=0; cum_model={h:0.0 for h in HISTS}; cum_ref={h:0.0 for h in HISTS}
    by={}
    for h in HISTS:
        hs={k:[] for k in ("storage","cum","theta","q")}
        ts={k:[] for k in ("storage","cum","theta","q")}
        se=0; tse=0
        for step in range(1,NSTEPS+1):
            rr=ref_states[(h,step)]
            rnodes=[float(ref_nodes[(h,step)][i]["THETA"]) for i in range(1,17)]
            cum_ref[h]+=float(rr["BOTTOM_OUTWARD_EXCHANGE"])
            if fmc is None:
                mr=model_states[(h,step)]
                mnodes=mapped_theta(model_nodes[(h,step)],n)
                cum_model[h]+=float(mr["BOTTOM_OUTWARD_EXCHANGE"])
                storage=float(mr["TOTAL_STORAGE"])
                q=float(mr["BOTTOM_FLUX"])
            else:
                row=fmc[h]["steps"][step-1]
                mnodes=[float(x) for x in row["theta16"]]
                cum_model[h]=float(row["cumulative_bottom_outward_exchange_cm"])
                storage=float(row["storage_cm"])
                q=float(row["terminal_bottom_outward_flux_cm_per_day"])
            es=storage-float(rr["TOTAL_STORAGE"])
            ec=cum_model[h]-cum_ref[h]
            eq=q-float(rr["BOTTOM_FLUX"])
            et=[mnodes[i]-rnodes[i] for i in range(16)]
            for k,v in (("storage",es),("cum",ec),("q",eq)):
                pooled[k].append(v); hs[k].append(v)
                if step in TRANSITION_STEPS: trans[k].append(v); ts[k].append(v)
            pooled["theta"].extend(et); hs["theta"].extend(et)
            if step in TRANSITION_STEPS: trans["theta"].extend(et); ts["theta"].extend(et)
            if sign(q)!=sign(float(rr["BOTTOM_FLUX"])):
                sign_errors+=1; se+=1
                if step in TRANSITION_STEPS: trans_sign_errors+=1; tse+=1
        by[h]={
          "all":{"total_storage_error_cm":qstats(hs["storage"]),"cumulative_bottom_exchange_error_cm":qstats(hs["cum"]),
                 "mapped_theta_error":qstats(hs["theta"]),"terminal_bottom_flux_error_cm_per_day":qstats(hs["q"]),
                 "bottom_flux_sign_error_count":se},
          "transition_steps_1_8":{"total_storage_error_cm":qstats(ts["storage"]),"cumulative_bottom_exchange_error_cm":qstats(ts["cum"]),
                 "mapped_theta_error":qstats(ts["theta"]),"terminal_bottom_flux_error_cm_per_day":qstats(ts["q"]),
                 "bottom_flux_sign_error_count":tse}
        }
    return {
      "pooled":{"total_storage_error_cm":qstats(pooled["storage"]),"cumulative_bottom_exchange_error_cm":qstats(pooled["cum"]),
                "mapped_theta_error":qstats(pooled["theta"]),"terminal_bottom_flux_error_cm_per_day":qstats(pooled["q"]),
                "bottom_flux_sign_error_count":sign_errors},
      "transition_steps_1_8":{"total_storage_error_cm":qstats(trans["storage"]),"cumulative_bottom_exchange_error_cm":qstats(trans["cum"]),
                "mapped_theta_error":qstats(trans["theta"]),"terminal_bottom_flux_error_cm_per_day":qstats(trans["q"]),
                "bottom_flux_sign_error_count":trans_sign_errors},
      "by_history":by
    }

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--r16",required=True); ap.add_argument("--r2",required=True)
    ap.add_argument("--preflight",required=True); ap.add_argument("--prereg",required=True); ap.add_argument("--output",required=True)
    a=ap.parse_args()
    p=json.loads(pathlib.Path(a.prereg).read_text())
    pre=json.loads(pathlib.Path(a.preflight).read_text())
    assert pre["decision"]=="D18_FMC_SLUG_GW_MERGE_PREFLIGHT_PASS"
    assert pre["SWAP_trajectory_generation_authorized"] is True
    r16s,r16n=parse_ref(a.r16,16); r2s,r2n=parse_ref(a.r2,2)
    fmc=pre["histories"]

    fmc_cmp=compare_model(None,None,0,r16s,r16n,fmc=fmc)
    r2_cmp=compare_model(r2s,r2n,2,r16s,r16n)

    fp=fmc_cmp["pooled"]; rp=r2_cmp["pooled"]
    ft=fmc_cmp["transition_steps_1_8"]; rt=r2_cmp["transition_steps_1_8"]
    gates={
      "all_total_storage":fp["total_storage_error_cm"]["rmse"]<=rp["total_storage_error_cm"]["rmse"],
      "all_cumulative_bottom_exchange":fp["cumulative_bottom_exchange_error_cm"]["rmse"]<=rp["cumulative_bottom_exchange_error_cm"]["rmse"],
      "all_mapped_theta":fp["mapped_theta_error"]["rmse"]<=rp["mapped_theta_error"]["rmse"],
      "all_bottom_flux_magnitude":fp["terminal_bottom_flux_error_cm_per_day"]["rmse"]<=rp["terminal_bottom_flux_error_cm_per_day"]["rmse"],
      "all_bottom_flux_sign":fp["bottom_flux_sign_error_count"]<=rp["bottom_flux_sign_error_count"],
      "transition_total_storage":ft["total_storage_error_cm"]["rmse"]<=rt["total_storage_error_cm"]["rmse"],
      "transition_cumulative_bottom_exchange":ft["cumulative_bottom_exchange_error_cm"]["rmse"]<=rt["cumulative_bottom_exchange_error_cm"]["rmse"],
      "transition_mapped_theta":ft["mapped_theta_error"]["rmse"]<=rt["mapped_theta_error"]["rmse"],
      "transition_bottom_flux_magnitude":ft["terminal_bottom_flux_error_cm_per_day"]["rmse"]<=rt["terminal_bottom_flux_error_cm_per_day"]["rmse"]
    }
    retained=all(gates.values())
    decision="FMC_SLUG_GROUNDWATER_MERGE_RETAINS_RESEARCH_CANDIDACY" if retained else "FMC_SLUG_GROUNDWATER_MERGE_NOT_COMPETITIVE_OR_NOT_ROBUST"

    max_fmc_mass=max(float(v["max_abs_step_mass_residual_cm"]) for v in fmc.values())
    result={
      "schema":"swap5.f-romv2-d18.result.v1","workstream":"F-ROM","work_unit":"F-ROMV2-D18",
      "decision":decision,
      "preflight":{
        "decision":pre["decision"],"SWAP_trajectory_evidence_consumed":False,
        "all_histories_pass":all(v.get("pass") for v in fmc.values()),
        "first_step_merge_counts":{h:v["first_step_merge_count"] for h,v in fmc.items()},
        "max_abs_merge_storage_drift_cm":max(float(v["max_abs_merge_storage_drift_cm"]) for v in fmc.values()),
        "max_abs_step_mass_residual_cm":max_fmc_mass
      },
      "integrity":{"pass":max_fmc_mass<=1e-12,"hard_mass_gate_cm":1e-12},
      "FMC":fmc_cmp,"R2":r2_cmp,
      "frontier":{"gates":gates,"all_views_required":True,"retained":retained},
      "application_acceptance":False,"formal_performance_claim":False,"production_rom_authorized":False
    }
    pathlib.Path(a.output).write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    print(json.dumps({"decision":decision,"gates":gates,"FMC_pooled":fp,"R2_pooled":rp,
                      "FMC_transition":ft,"R2_transition":rt},sort_keys=True))
    return 0

if __name__=="__main__": raise SystemExit(main())
