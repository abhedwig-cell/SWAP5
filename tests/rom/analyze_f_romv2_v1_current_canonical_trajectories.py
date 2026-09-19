#!/usr/bin/env python3
from __future__ import annotations
import argparse,collections,json,math,pathlib,hashlib

def fields(s):
    out={}
    for part in s.split("|"):
        if "=" in part:
            k,v=part.split("=",1); out[k]=v
    return out

def as_bool(v):
    return str(v).strip().upper() in {"T","TRUE",".TRUE.","1"}

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--input",required=True)
    ap.add_argument("--repeat",required=True)
    ap.add_argument("--output",required=True)
    a=ap.parse_args()
    raw=pathlib.Path(a.input).read_text()
    repeat=pathlib.Path(a.repeat).read_text()
    repeat_identity=raw==repeat

    states=[]; nodes=[]; histories=[]; fallbacks=[]; summary={}
    current_history=None; current_step=0
    for line in raw.splitlines():
        if "F_ROMV2_V1_STATE|" in line:
            r=fields(line.split("F_ROMV2_V1_STATE|",1)[1]); states.append(r)
            current_history=r["HISTORY"]; current_step=int(r["STEP"])
        elif "F_ROMV2_V1_NODE|" in line:
            nodes.append(fields(line.split("F_ROMV2_V1_NODE|",1)[1]))
        elif "F_ROMV2_V1_HISTORY_PASS|" in line:
            histories.append(fields(line.split("F_ROMV2_V1_HISTORY_PASS|",1)[1]))
        elif "F_ROMV2_V1_FALLBACK|" in line:
            r=fields(line.split("F_ROMV2_V1_FALLBACK|",1)[1])
            r["_history_context"]=current_history; r["_step_context"]=current_step+1
            fallbacks.append(r)
        elif line.startswith("F_ROMV2_V1_") and "=" in line and "|" not in line:
            k,v=line.split("=",1); summary[k]=v.strip()

    expected_training={f"D{i:02d}" for i in range(1,9)}
    expected_validation={f"V{i:02d}" for i in range(1,5)}
    expected=expected_training|expected_validation
    by_hist=collections.defaultdict(list)
    for s in states: by_hist[s.get("HISTORY","")].append(s)
    split=collections.Counter(s.get("SPLIT","").strip() for s in states)
    history_structure=(set(by_hist)==expected and all(len(by_hist[h])==64 for h in expected)
                       and len(histories)==12 and {h.get("HISTORY") for h in histories}==expected)
    split_ok=split["TRAINING"]==512 and split["VALIDATION"]==256
    node_count=collections.Counter((n.get("HISTORY",""),int(n.get("STEP","0"))) for n in nodes)
    node_structure=(len(nodes)==768*16 and all(node_count[(h,s)]==16 for h in expected for s in range(1,65)))

    finite_states=True; max_mass=0.0
    for s in states:
        vals=[float(s[k]) for k in ("T","TOTAL_STORAGE","UPPER_STORAGE","LOWER_STORAGE",
                                    "TOP_EXCHANGE","BOTTOM_OUTWARD_EXCHANGE","BOTTOM_FLUX","MASS")]
        finite_states &= all(math.isfinite(v) for v in vals)
        max_mass=max(max_mass,abs(float(s["MASS"])))
    finite_nodes=True; hmin=math.inf; hmax=-math.inf; thmin=math.inf; thmax=-math.inf
    for n in nodes:
        h=float(n["H"]); th=float(n["THETA"])
        finite_nodes &= math.isfinite(h) and math.isfinite(th)
        hmin=min(hmin,h); hmax=max(hmax,h); thmin=min(thmin,th); thmax=max(thmax,th)

    progression=True
    for h,rows in by_hist.items():
        rows=sorted(rows,key=lambda r:int(r["STEP"]))
        for i,r in enumerate(rows,1):
            progression &= int(r["STEP"])==i and int(r["REV"])==2+i

    fallback_ok=True; total_only=0; local=0; fallback_rows=[]
    fallback_by_split=collections.Counter()
    fallback_by_history=collections.Counter()
    for f in fallbacks:
        hist=f.get("_history_context")
        spl="TRAINING" if hist in expected_training else "VALIDATION" if hist in expected_validation else "UNKNOWN"
        fallback_by_split[spl]+=1; fallback_by_history[hist]+=1
        cls=f["CLASS"]; bal=int(f["BAL_FLAGS"]); head=int(f["HEAD_FLAGS"])
        rmax=float(f["RMAX"]); rsum=float(f["RSUM"])
        rep=float(f["REP_BOUND_CM"]); total_int=float(f["ABS_TOTAL_RESIDUAL_CM"])
        local_int=float(f["LOCAL_INTEGRATED_CM"])
        cp=float(f["FALLBACK_CP_TOL"]); tot=float(f["FALLBACK_TOTAL_TOL"])
        t0=float(f["HISTORY_STEP_T0"]); t1=float(f["T1"]); dt=t1-t0
        common=(head==0 and rep>0 and total_int<=rep and tot>=1e-12)
        if cls=="RETRY_TOTAL_ONLY":
            ok=common and bal==0 and rmax<=1e-12 and abs(rsum)>1e-12 and cp==1e-12
            total_only+=1
        elif cls=="RETRY_LOCAL_BALANCE":
            expected_cp=max(1e-12,1.6e-15/dt)
            cp_ok=abs(cp-expected_cp)<=4.0*math.ulp(expected_cp)
            ok=common and bal>0 and local_int<=1.6e-15 and cp_ok
            local+=1
        else:
            ok=False
        fallback_ok &= ok
        fallback_rows.append({
          "split":spl,"history":hist,"step":f.get("_step_context"),
          "bottom_mode":int(f["BOTTOM_MODE"]),"classification":cls,
          "local_balance_flag_count":bal,"head_flag_count":head,
          "max_abs_local_residual_cm_per_day":rmax,
          "local_integrated_cm":local_int,
          "total_residual_cm_per_day":rsum,
          "total_integrated_cm":total_int,
          "total_representation_bound_cm":rep,
          "fallback_compartment_tolerance_cm_per_day":cp,
          "fallback_total_tolerance_cm_per_day":tot,
        })

    state_fallback_count=sum(1 for s in states if as_bool(s["FALLBACK"]))
    fallback_count_consistent=state_fallback_count==len(fallbacks)
    summary_ok=(
      summary.get("F_ROMV2_V1_HISTORY_COUNT")=="12"
      and summary.get("F_ROMV2_V1_TRAINING_HISTORY_COUNT")=="8"
      and summary.get("F_ROMV2_V1_VALIDATION_HISTORY_COUNT")=="4"
      and summary.get("F_ROMV2_V1_STATE_COUNT")=="768"
      and summary.get("F_ROMV2_V1_TRAINING_STATE_COUNT")=="512"
      and summary.get("F_ROMV2_V1_VALIDATION_STATE_COUNT")=="256"
      and summary.get("F_ROMV2_V1_B14_MATERIAL_TRANSFER_GENERATED")=="FALSE"
      and summary.get("F_ROMV2_V1_EXECUTION_COMPLETE")=="PASS"
    )
    qualified=all([repeat_identity,history_structure,split_ok,node_structure,finite_states,finite_nodes,
                   progression,max_mass<=1e-12,fallback_ok,fallback_count_consistent,summary_ok])
    decision="F_ROMV2_V1_CURRENT_CANONICAL_TRAJECTORIES_QUALIFIED" if qualified else "F_ROMV2_V1_CURRENT_CANONICAL_TRAJECTORIES_NO_GO"
    result={
      "schema":"swap5.f-romv2-v1-trajectory.result.v1",
      "work_unit":"F-ROMV2-V1-TRAJECTORY",
      "decision":decision,
      "repeat_stdout_bitwise_identity":repeat_identity,
      "library":{
        "material":"B01","history_count":len(histories),"accepted_state_count":len(states),
        "training_state_count":split["TRAINING"],"validation_state_count":split["VALIDATION"],
        "node_record_count":len(nodes),"nodes_per_state":16,
      },
      "fallback":{
        "count":len(fallbacks),"state_fallback_count":state_fallback_count,
        "total_only_count":total_only,"local_balance_count":local,
        "by_split":dict(fallback_by_split),"by_history":dict(fallback_by_history),
        "semantics_pass":fallback_ok,"count_consistent":fallback_count_consistent,
        "rows":fallback_rows,
      },
      "ranges":{"pressure_head_cm":[hmin,hmax],"water_content":[thmin,thmax],
                "max_abs_step_mass_residual_cm":max_mass},
      "gates":{
        "history_structure":history_structure,"split_counts":split_ok,"node_structure":node_structure,
        "finite_primary_outputs":finite_states,"finite_full_profiles":finite_nodes,
        "revision_progression":progression,"hard_mass_gate":max_mass<=1e-12,
        "fallback_semantics":fallback_ok,"B14_not_generated":summary.get("F_ROMV2_V1_B14_MATERIAL_TRANSFER_GENERATED")=="FALSE"
      },
      "payload":{"raw_sha256":hashlib.sha256(raw.encode()).hexdigest(),
                 "repeat_sha256":hashlib.sha256(repeat.encode()).hexdigest()},
      "scientific_firewalls":{
        "policy_retuned_from_validation":False,"B14_generated":False,
        "reduced_coordinate_selected":False,"pod_or_modal_basis_fit":False,
        "memory_variable_selected":False,"closure_model_fit":False
      },
      "c2_blind_evaluation_authorized":qualified,
      "production_solver_authorized":False
    }
    pathlib.Path(a.output).write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    print(json.dumps(result,sort_keys=True))
    return 0 if qualified else 2

if __name__=="__main__":
    raise SystemExit(main())
