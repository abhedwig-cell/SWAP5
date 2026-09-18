#!/usr/bin/env python3
from __future__ import annotations
import argparse, hashlib, json, math, pathlib

EPS=0.0005420462931603476
NG=8
NMASK=1<<NG

def fields(payload: str) -> dict[str,str]:
    out={}
    for part in payload.split("|"):
        if "=" in part:
            k,v=part.split("=",1)
            out[k]=v
    return out

def mask_tuple(mask):
    return tuple(i+1 for i in range(NG) if mask&(1<<i))

def linf(a,b):
    return max(abs(x-y) for x,y in zip(a,b))

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--input",required=True)
    ap.add_argument("--repeat",required=True)
    ap.add_argument("--prereg",required=True)
    ap.add_argument("--output",required=True)
    args=ap.parse_args()

    raw=pathlib.Path(args.input).read_text()
    repeat=pathlib.Path(args.repeat).read_text()
    prereg=json.loads(pathlib.Path(args.prereg).read_text())
    repeat_identity=(raw==repeat)

    nodes={}
    for line in raw.splitlines():
        if "ROM1AR1D3_NODE|" not in line:
            continue
        r=fields(line.split("ROM1AR1D3_NODE|",1)[1])
        if r.get("SPLIT","").strip()!="DISCOVERY":
            raise SystemExit("non-discovery node encountered")
        key=(r["HISTORY"],int(r["STEP"]))
        nodes.setdefault(key,{})[int(r["NODE"])]=float(r["THETA"])

    expected={(f"D{i:02d}",s) for i in range(1,9) for s in range(1,65)}
    structure=(set(nodes)==expected and all(set(nodes[k])==set(range(1,17)) for k in expected))
    if not structure:
        raise SystemExit("ROM1B3Q1 discovery structure mismatch")

    states=[]
    for key in sorted(expected):
        theta=[nodes[key][i] for i in range(1,17)]
        means=[0.5*(theta[i]+theta[i+1]) for i in range(0,16,2)]
        states.append({"key":key,"theta":theta,"means":means})

    relevant=[]
    eligible=0
    for ia,a in enumerate(states):
        for b in states[ia+1:]:
            if a["key"][0]==b["key"][0]:
                continue
            eligible+=1
            full=linf(a["theta"],b["theta"])
            if full<=EPS:
                continue
            mean_d=[abs(x-y) for x,y in zip(a["means"],b["means"])]
            full_band=[
              max(abs(a["theta"][2*i]-b["theta"][2*i]),
                  abs(a["theta"][2*i+1]-b["theta"][2*i+1]))
              for i in range(8)
            ]
            relevant.append((mean_d,full_band,full))

    collision=[0]*NMASK
    min_sep=[math.inf]*NMASK
    max_hidden=[0.0]*NMASK
    monotonic_ok=True
    full_identity_ok=True
    max_full_identity_abs=0.0

    for mean_d,full_band,full in relevant:
        # Quotient norm: unresolved bands can choose the minimum compatible
        # cellwise difference = |dmean|; resolved bands are fixed cellwise.
        d=[0.0]*NMASK
        d[0]=max(mean_d)
        for mask in range(1,NMASK):
            bandmax=0.0
            for i in range(8):
                v=full_band[i] if mask&(1<<i) else mean_d[i]
                if v>bandmax: bandmax=v
            d[mask]=bandmax
        full_delta=abs(d[NMASK-1]-full)
        max_full_identity_abs=max(max_full_identity_abs,full_delta)
        if d[NMASK-1] != full:
            full_identity_ok=False
        for mask,dist in enumerate(d):
            min_sep[mask]=min(min_sep[mask],dist)
            if dist<=EPS:
                collision[mask]+=1
                max_hidden[mask]=max(max_hidden[mask],full)
        for mask in range(NMASK):
            for bit in range(8):
                if mask&(1<<bit): continue
                if d[mask|(1<<bit)] < d[mask]:
                    monotonic_ok=False

    rows=[]; by_k={}; zero_masks=[]
    for mask in range(NMASK):
        subset=mask_tuple(mask)
        k=len(subset)
        zero=(collision[mask]==0)
        if zero: zero_masks.append(mask)
        row={
          "mask":mask,
          "added_components":[f"G{i}" for i in subset],
          "added_count":k,
          "dimension":8+k,
          "collision_count":collision[mask],
          "zero_collision":zero,
          "minimum_induced_theta_linf_over_full_distinguishable_pairs":min_sep[mask],
          "minimum_separation_margin_over_theta_floor":min_sep[mask]-EPS,
          "maximum_hidden_full_theta_linf_among_collisions":max_hidden[mask],
        }
        rows.append(row)
        rec=by_k.setdefault(k,{
          "added_count":k,"candidate_count":0,"zero_collision_candidate_count":0,
          "minimum_collision_count":10**18,"maximum_collision_count":0
        })
        rec["candidate_count"]+=1
        rec["zero_collision_candidate_count"]+=int(zero)
        rec["minimum_collision_count"]=min(rec["minimum_collision_count"],collision[mask])
        rec["maximum_collision_count"]=max(rec["maximum_collision_count"],collision[mask])

    selected=None
    if zero_masks:
        min_k=min(len(mask_tuple(m)) for m in zero_masks)
        candidates=[m for m in zero_masks if len(mask_tuple(m))==min_k]
        best_margin=max(min_sep[m]-EPS for m in candidates)
        candidates=[m for m in candidates if min_sep[m]-EPS==best_margin]
        chosen=min(candidates,key=mask_tuple)
        selected=next(r for r in rows if r["mask"]==chosen)
        decision=("ROM1B3Q1_DISCOVERY_ENRICHED_COORDINATE_FROZEN"
                  if min_k<8 else "ROM1B3Q1_ONLY_FULL_THETA_STATE_SEPARATES")
    else:
        decision="ROM1B3Q1_INDUCED_NORM_RECONCILIATION_BLOCKED"

    controls={
      "Z8_mask0_collision_count":collision[0],
      "Z8_matches_ROM1B1":collision[0]==5617,
      "full_mask255_collision_count":collision[NMASK-1],
      "full_mask_matches_Z16_zero_collision":collision[NMASK-1]==0,
      "full_mask_induced_distance_equals_cellwise_for_every_relevant_pair":full_identity_ok,
      "maximum_full_mask_identity_abs_difference":max_full_identity_abs,
      "added_component_monotonicity":monotonic_ok
    }
    complete=(
      repeat_identity and structure and eligible==114688 and len(states)==512 and
      controls["Z8_matches_ROM1B1"] and controls["full_mask_matches_Z16_zero_collision"] and
      controls["full_mask_induced_distance_equals_cellwise_for_every_relevant_pair"] and
      controls["added_component_monotonicity"] and
      prereg["unchanged_authority"]["heldout_used"] is False and
      prereg["unchanged_authority"]["B14_used"] is False and
      prereg["unchanged_authority"]["future_probe_outcomes_used_for_subset_selection"] is False
    )
    if not complete:
        decision="ROM1B3Q1_INDUCED_NORM_RECONCILIATION_BLOCKED"

    result={
      "schema":"swap5.rom1b3q1.result.v1","workstream":"F-ROM","work_unit":"ROM-1B3Q1",
      "decision":decision,"repeat_stdout_bitwise_identity":repeat_identity,
      "discovery_state_count":len(states),"eligible_cross_history_pair_count":eligible,
      "full_state_distinguishable_pair_count":len(relevant),"theta_collision_floor":EPS,
      "candidate_family_size":NMASK,"qualification_controls":controls,
      "summary_by_added_count":[by_k[k] for k in sorted(by_k)],
      "selected_candidate":selected,"all_candidates":rows,
      "raw_discovery_sha256":hashlib.sha256(raw.encode()).hexdigest(),
      "ROM1B3_componentwise_result_reclassified":False,
      "theta_floor_changed":False,"component_rescaled":False,
      "heldout_used":False,"B14_used":False,
      "future_probe_outcomes_used_for_subset_selection":False,
      "pod_or_modal_basis_used":False,"memory_variable_selected":False,
      "closure_model_fit":False,"production_rom_authorized":False
    }
    pathlib.Path(args.output).write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    print(json.dumps({
      "schema":result["schema"],"work_unit":result["work_unit"],"decision":decision,
      "qualification_controls":controls,
      "summary_by_added_count":result["summary_by_added_count"],
      "selected_candidate":selected,
      "repeat_stdout_bitwise_identity":repeat_identity,
      "heldout_used":False,"B14_used":False
    },sort_keys=True))
    return 0 if complete else 2

if __name__=="__main__":
    raise SystemExit(main())
