#!/usr/bin/env python3
from __future__ import annotations
import argparse, importlib.util, json, pathlib, sys
import numpy as np

HERE=pathlib.Path(__file__).resolve().parent

def load(name,path):
    spec=importlib.util.spec_from_file_location(name,str(path))
    mod=importlib.util.module_from_spec(spec)
    sys.modules[name]=mod
    spec.loader.exec_module(mod)
    return mod

c4v=load("c4v_diag_base",HERE/"analyze_lare_bc2_c4v_one_day.py")

def stats(v):
    a=np.asarray(v,dtype=float)
    if len(a)==0:
        return {"count":0}
    return {
      "count":int(len(a)),
      "min":float(np.min(a)),
      "median":float(np.median(a)),
      "p95":float(np.percentile(a,95)),
      "max":float(np.max(a)),
      "mean":float(np.mean(a))
    }

def segments(steps):
    if not steps:return []
    out=[];start=prev=steps[0]
    for s in steps[1:]:
        if s==prev+1:
            prev=s
        else:
            out.append([start,prev]);start=prev=s
    out.append([start,prev])
    return out

def percentile_rank(value,distribution):
    a=np.asarray(distribution,dtype=float)
    return float(100.0*np.count_nonzero(a<=value)/len(a))

def q_at_step(r16,history_series,hist,step):
    ref=float(r16["states"][(hist,step)]["BOTTOM_FLUX"])
    cand=ref+float(history_series["Q"][step-1])
    return ref,cand

def characterize_member(member,r16,c4v_result):
    run=c4v.run_lare(member,r16)
    if run["status"]!="QUALIFIED":
        return {"id":member["id"],"status":run["status"],"failure":run["failure"],
                "max_abs_water_ledger_cm":run["max_abs_water_ledger_cm"]}
    out={"id":member["id"],"dimension":member["dimension"],"status":"QUALIFIED",
         "max_abs_water_ledger_cm":run["max_abs_water_ledger_cm"],"histories":{}}
    route_key="LARE_"+member["id"]
    for hist in c4v.HISTS:
        z=run["series"][hist]
        refq=[float(r16["states"][(hist,s)]["BOTTOM_FLUX"]) for s in range(1,c4v.NSTEPS+1)]
        candq=[refq[i]+float(z["Q"][i]) for i in range(c4v.NSTEPS)]
        mismatch=[i+1 for i,(r,c) in enumerate(zip(refq,candq)) if c4v.sign(r)!=0 and c4v.sign(c)!=c4v.sign(r)]
        refrev=c4v.reversal_steps([c4v.sign(x) for x in refq])
        candrev=c4v.reversal_steps([c4v.sign(x) for x in candq])
        expected=c4v_result["summaries"][route_key]["1024"]["by_history"][hist]
        if int(expected["bottom_flux_sign_errors"])!=len(mismatch):
            raise RuntimeError(f"sign count reproduction mismatch {member['id']} {hist}")
        if list(expected["reference_reversal_steps"])!=refrev:
            raise RuntimeError(f"Reference reversal reproduction mismatch {member['id']} {hist}")
        if list(expected["candidate_reversal_steps"])!=candrev:
            raise RuntimeError(f"candidate reversal reproduction mismatch {member['id']} {hist}")

        abs_all_ref=[abs(x) for x in refq]
        abs_ref=[abs(refq[s-1]) for s in mismatch]
        abs_cand=[abs(candq[s-1]) for s in mismatch]
        abs_err=[abs(candq[s-1]-refq[s-1]) for s in mismatch]
        ranks=[percentile_rank(abs(refq[s-1]),abs_all_ref) for s in mismatch]
        first=None
        if mismatch:
            s=mismatch[0];first={"step":s,"day":s*c4v.OBS_DT,
                "reference_q_cm_per_day":refq[s-1],"candidate_q_cm_per_day":candq[s-1],
                "reference_abs_q_percentile_rank":percentile_rank(abs(refq[s-1]),abs_all_ref)}
        revdetail=[]
        for s in candrev:
            rr,cc=q_at_step(r16,z,hist,s)
            revdetail.append({"step":s,"day":s*c4v.OBS_DT,
                              "reference_q_cm_per_day":rr,"candidate_q_cm_per_day":cc,
                              "reference_abs_q_percentile_rank":percentile_rank(abs(rr),abs_all_ref)})
        out["histories"][hist]={
          "sign_mismatch_count":len(mismatch),
          "sign_mismatch_segments":segments(mismatch),
          "first_mismatch":first,
          "last_mismatch_step":None if not mismatch else mismatch[-1],
          "reference_reversal_steps":refrev,
          "candidate_reversal_steps":candrev,
          "candidate_reversal_detail":revdetail,
          "mismatch_abs_reference_q_cm_per_day":stats(abs_ref),
          "mismatch_abs_candidate_q_cm_per_day":stats(abs_cand),
          "mismatch_abs_flux_error_cm_per_day":stats(abs_err),
          "mismatch_reference_abs_q_percentile_rank":stats(ranks),
          "all_steps_abs_reference_q_cm_per_day":stats(abs_all_ref),
          "day_1p024_reference_q_cm_per_day":refq[-1],
          "day_1p024_candidate_q_cm_per_day":candq[-1]
        }
    return out

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--r16",required=True,type=pathlib.Path)
    ap.add_argument("--c4v-result",required=True,type=pathlib.Path)
    ap.add_argument("--c4v-prereg",required=True,type=pathlib.Path)
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    a=ap.parse_args()
    p=json.loads(a.prereg.read_text());v=json.loads(a.c4v_result.read_text());vp=json.loads(a.c4v_prereg.read_text())
    assert p["phase"]=="POST_C4V_EXPOSED_DIAGNOSTIC_BOUND_BEFORE_REEXECUTION"
    assert v["decision"]=="C4V_HIGHER_DIMENSION_GW_FRONTIER_PERSISTS"
    r16=c4v.parse_ref(a.r16)
    wanted=set(p["scope"]["members"])
    members=[m for m in vp["representations"]["LARE"]["full_frozen_ladder"] if m["id"] in wanted]
    if [m["id"] for m in members] != ["R4","R5","R6","R8","R12","R16"]:
        raise SystemExit("member binding mismatch")
    results=[characterize_member(m,r16,v) for m in members]
    complete=all(x["status"]=="QUALIFIED" for x in results)
    ledger=max([x["max_abs_water_ledger_cm"] for x in results] or [0.0])
    hard=complete and ledger<=float(p["hard_gates"]["maximum_lare_water_ledger_cm"])

    # Mechanism summary is descriptive and threshold-free.
    mech={}
    for mid in ("R4","R5","R6","R8","R12","R16"):
        x=next(z for z in results if z["id"]==mid)
        v03=x["histories"]["V03"]
        mech[mid]={
          "V03_mismatch_count":v03["sign_mismatch_count"],
          "V03_segments":v03["sign_mismatch_segments"],
          "V03_candidate_reversal_steps":v03["candidate_reversal_steps"],
          "V03_reference_reversal_steps":v03["reference_reversal_steps"],
          "V03_first_mismatch":v03["first_mismatch"],
          "V03_mismatch_reference_abs_q":v03["mismatch_abs_reference_q_cm_per_day"],
          "V03_mismatch_reference_abs_q_percentile_rank":v03["mismatch_reference_abs_q_percentile_rank"]
        }
    decision="C4W_SPURIOUS_REVERSAL_MAGNITUDE_CHARACTERIZED" if hard else "C4W_DIAGNOSTIC_BLOCKED"
    out={
      "schema":"swap5.lare.bc2.c4w.result.v1","workstream":"F-ROM-LARE","work_unit":"LARE-BC2-C4W",
      "decision":decision,
      "integrity":{"pass":hard,"all_members_complete":complete,"maximum_water_ledger_cm":ledger,
                   "c4v_sign_and_reversal_reproduction":"PASS" if hard else "BLOCKED"},
      "members":results,
      "mechanism_summary":mech,
      "interpretation_boundaries":[
        "This is a post-C4V exposed diagnostic. It cannot alter the C4V decision or minimum persistent dimension.",
        "No near-zero deadband or application tolerance is defined.",
        "Percentile ranks are descriptive within-history magnitude context only.",
        "No closure, partition, timestep, Reference trajectory or production source is changed."
      ],
      "application_acceptance_adjudicated":False,
      "speed_claim_authorized":False,
      "production_rom_authorized":False
    }
    a.output.write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print(json.dumps({"decision":decision,"integrity":out["integrity"],"mechanism_summary":mech},sort_keys=True))
    return 0 if hard else 2

if __name__=="__main__":
    raise SystemExit(main())
