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
    return {"frontier":[r for r in routes if not dom[r]],"dominated_by":dom}

def min_lare(front):
    xs=[r for r in front if r.startswith("LARE_")]
    return None if not xs else min(xs,key=lambda r:int(r.split("_R")[1]))

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--fidelity",required=True,type=pathlib.Path)
    ap.add_argument("--timing",required=True,type=pathlib.Path)
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--compiled-equivalence",required=True,type=pathlib.Path)
    ap.add_argument("--workflow-result",type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    a=ap.parse_args()
    f=json.loads(a.fidelity.read_text());t=json.loads(a.timing.read_text());p=json.loads(a.prereg.read_text())
    eq=json.loads(a.compiled_equivalence.read_text())
    assert p["phase"]=="PREREGISTERED_AFTER_C4S_BEFORE_COMPILED_COST_EXPOSURE"
    assert p["decision_logic"]["C4T_LARE_PURPOSE_VALUE_SIGNAL_RESOLVED"].find("same purpose")>=0
    assert f["timing_exposed"] is False
    assert t["decision"]=="C4T_SHARED_HOST_TIMING_COMPLETE"
    assert eq["pass"] is True
    fid=f["compact"]
    if set(fid)!=set(t["route_stats"]):raise SystemExit("C4T fidelity/timing route mismatch")

    purpose={
      "GW":analyze_purpose(fid,t,GW),
      "PROFILE":analyze_purpose(fid,t,PROFILE)
    }
    lare=[r for r in fid if r.startswith("LARE_")]
    non_lare_reduced=[r for r in fid if r.startswith("COR_") or r=="FMC"]
    cheaper_r16={r:cost_status(t,r,"R16")=="A_RESOLVED_CHEAPER" for r in fid if r!="R16"}

    positive_by_purpose={}
    for pname,res in purpose.items():
        # Literal preregistration: candidate must be on the frontier for THIS
        # purpose and resolved cheaper than R16. Frontier membership already
        # means it is not resolved-dominated by FMC/CoRichards (or any route)
        # on that same purpose.
        positive_by_purpose[pname]=[
          r for r in lare if cheaper_r16[r] and r in res["frontier"]
        ]

    positive=any(positive_by_purpose.values())
    every_lare_both_dominated=all(
      bool(purpose["GW"]["dominated_by"][r]) and bool(purpose["PROFILE"]["dominated_by"][r])
      for r in lare
    )
    no_lare_cheaper=not any(cheaper_r16[r] for r in lare)
    some_non_lare_cheaper=any(cheaper_r16.get(r,False) for r in non_lare_reduced)

    if positive:
        decision="C4T_LARE_PURPOSE_VALUE_SIGNAL_RESOLVED"
    elif every_lare_both_dominated or (no_lare_cheaper and some_non_lare_cheaper):
        decision="C4T_LARE_PURPOSE_VALUE_SIGNAL_NEGATIVE"
    else:
        decision="C4T_LARE_PURPOSE_VALUE_SIGNAL_UNRESOLVED"

    workflow=None
    if a.workflow_result and a.workflow_result.exists():
        workflow=json.loads(a.workflow_result.read_text())

    out={
      "schema":"swap5.lare.bc2.c4t.same-purpose-reconciliation.v1",
      "workstream":"F-ROM-LARE","work_unit":"LARE-BC2-C4T",
      "phase":"PREREGISTERED_LOGIC_RECONCILIATION_WRITTEN_BEFORE_TIMING_RESULT_EXPOSURE",
      "decision":decision,
      "reason":"Apply the C4T positive decision clause literally per purpose rather than requiring absence of non-LARE dominance on the other purpose.",
      "purpose_frontiers":{
        k:{**v,"minimum_lare_frontier_member":min_lare(v["frontier"]),
           "positive_lare_members":positive_by_purpose[k]}
        for k,v in purpose.items()
      },
      "resolved_cheaper_than_R16":cheaper_r16,
      "workflow_result_decision":None if workflow is None else workflow.get("decision"),
      "workflow_result_differs":False if workflow is None else workflow.get("decision")!=decision,
      "raw_fidelity_changed":False,
      "raw_timing_changed":False,
      "cost_rule_changed":False,
      "negative_rule_changed":False,
      "application_acceptance_adjudicated":False,
      "formal_performance_claim":False,
      "speed_claim_authorized":False,
      "production_rom_authorized":False
    }
    a.output.write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print(json.dumps({
      "decision":decision,
      "positive_by_purpose":positive_by_purpose,
      "GW_frontier":purpose["GW"]["frontier"],
      "PROFILE_frontier":purpose["PROFILE"]["frontier"],
      "workflow_result_differs":out["workflow_result_differs"]
    },sort_keys=True))

if __name__=="__main__":
    raise SystemExit(main())
