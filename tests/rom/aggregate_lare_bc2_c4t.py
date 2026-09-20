#!/usr/bin/env python3
from __future__ import annotations
import argparse,json,pathlib

TOL=1e-12
GW=("storage_rmse_cm","cumulative_bottom_rmse_cm","bottom_flux_rmse_cm_per_day","bottom_flux_sign_errors")
PROFILE=GW+("mapped_theta_rmse",)

def fidelity_relation(a,b,keys):
    no_worse=True;strict=False
    for k in keys:
        av=a[k];bv=b[k]
        if k=="bottom_flux_sign_errors":
            if int(av)>int(bv):no_worse=False
            if int(av)<int(bv):strict=True
        else:
            if float(av)>float(bv)+TOL:no_worse=False
            if float(av)<float(bv)-TOL:strict=True
    return no_worse,strict

def cost_status(timing,a,b):
    return timing["pairwise_cpu"][a][b]["status"]

def analyze_purpose(fid,timing,keys):
    routes=list(fid)
    dom={r:[] for r in routes}
    for a in routes:
        for b in routes:
            if a==b:continue
            nw,strict=fidelity_relation(fid[a]["fidelity"],fid[b]["fidelity"],keys)
            if nw and strict and cost_status(timing,a,b)=="A_RESOLVED_CHEAPER":
                dom[b].append(a)
    frontier=[r for r in routes if not dom[r]]
    return {"frontier":frontier,"dominated_by":dom}

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--fidelity",required=True,type=pathlib.Path)
    ap.add_argument("--timing",required=True,type=pathlib.Path)
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--compiled-equivalence",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    a=ap.parse_args()
    f=json.loads(a.fidelity.read_text());t=json.loads(a.timing.read_text());p=json.loads(a.prereg.read_text())
    eq=json.loads(a.compiled_equivalence.read_text())
    assert p["phase"]=="PREREGISTERED_AFTER_C4S_BEFORE_COMPILED_COST_EXPOSURE"
    assert f["timing_exposed"] is False
    assert t["decision"]=="C4T_SHARED_HOST_TIMING_COMPLETE"
    assert eq["pass"] is True
    fid=f["compact"]
    if set(fid)!=set(t["route_stats"]):raise SystemExit("C4T fidelity/timing route mismatch")

    gw=analyze_purpose(fid,t,GW);profile=analyze_purpose(fid,t,PROFILE)
    lare=[r for r in fid if r.startswith("LARE_")]
    non_lare_reduced=[r for r in fid if r.startswith("COR_") or r=="FMC"]
    cheaper_r16={r:cost_status(t,r,"R16")=="A_RESOLVED_CHEAPER" for r in fid if r!="R16"}
    lare_positive=[
      r for r in lare
      if cheaper_r16[r] and (r in gw["frontier"] or r in profile["frontier"])
      and not any(x=="FMC" or x.startswith("COR_") for x in (gw["dominated_by"][r]+profile["dominated_by"][r]))
    ]

    every_lare_both_dominated=all(bool(gw["dominated_by"][r]) and bool(profile["dominated_by"][r]) for r in lare)
    no_lare_cheaper=not any(cheaper_r16[r] for r in lare)
    some_non_lare_cheaper=any(cheaper_r16.get(r,False) for r in non_lare_reduced)
    if lare_positive:
        decision="C4T_LARE_PURPOSE_VALUE_SIGNAL_RESOLVED"
    elif every_lare_both_dominated or (no_lare_cheaper and some_non_lare_cheaper):
        decision="C4T_LARE_PURPOSE_VALUE_SIGNAL_NEGATIVE"
    else:
        decision="C4T_LARE_PURPOSE_VALUE_SIGNAL_UNRESOLVED"

    def min_lare(front):
        xs=[r for r in front if r.startswith("LARE_")]
        return None if not xs else min(xs,key=lambda r:int(r.split("_R")[1]))

    out={
      "schema":"swap5.lare.bc2.c4t.result.v1","workstream":"F-ROM-LARE","work_unit":"LARE-BC2-C4T",
      "decision":decision,
      "integrity":{"pass":True,"compiled_equivalence_pass":True,"timing_complete":True,"route_count":len(fid)},
      "purpose_frontiers":{
        "GW":{**gw,"minimum_lare_frontier_member":min_lare(gw["frontier"])},
        "PROFILE":{**profile,"minimum_lare_frontier_member":min_lare(profile["frontier"])}
      },
      "lare_positive_members":lare_positive,
      "resolved_cheaper_than_R16":cheaper_r16,
      "fidelity":fid,
      "cost":{r:t["route_stats"][r] for r in fid},
      "pairwise_cpu":t["pairwise_cpu"],
      "interpretation":[
        "Resolved value dominance requires componentwise no-worse purpose fidelity with at least one strict fidelity improvement and a paired two-SE resolved CPU cost advantage.",
        "C4T uses no weighted cost-error score and no post-result hydrological tolerance.",
        "This is a shared-host screening result only; MP performance governance still forbids a portable or formal speedup claim.",
        "RossFast is absent because no production-admitted fixed-head mode-5 RossFast route exists for the frozen C4R workload."
      ],
      "application_acceptance_adjudicated":False,
      "formal_performance_claim":False,
      "speed_claim_authorized":False,
      "production_rom_authorized":False
    }
    a.output.write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print(json.dumps({"decision":decision,"GW_frontier":gw["frontier"],"PROFILE_frontier":profile["frontier"],
                      "lare_positive_members":lare_positive,
                      "minimum_GW_LARE":out["purpose_frontiers"]["GW"]["minimum_lare_frontier_member"],
                      "minimum_PROFILE_LARE":out["purpose_frontiers"]["PROFILE"]["minimum_lare_frontier_member"]},sort_keys=True))
if __name__=="__main__":main()
