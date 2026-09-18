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

def z8_and_g(theta):
    z=[]; g=[]
    for i in range(0,16,2):
        a=theta[i]; b=theta[i+1]
        z.append(0.5*(a+b))
        g.append(0.5*(a-b))
    return z,g

def linf(a,b):
    return max(abs(x-y) for x,y in zip(a,b))

def mask_tuple(mask):
    return tuple(i+1 for i in range(NG) if mask&(1<<i))

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
        raise SystemExit("ROM1B3 discovery structure mismatch")

    states=[]
    recon_max=0.0
    for key in sorted(expected):
        theta=[nodes[key][i] for i in range(1,17)]
        z,g=z8_and_g(theta)
        recon=[]
        for m,c in zip(z,g):
            recon.extend((m+c,m-c))
        recon_max=max(recon_max,linf(theta,recon))
        states.append({"key":key,"theta":theta,"z":z,"g":g})

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
            base=linf(a["z"],b["z"])
            gd=tuple(abs(x-y) for x,y in zip(a["g"],b["g"]))
            relevant.append((base,gd,full))

    collision=[0]*NMASK
    min_sep=[math.inf]*NMASK
    max_hidden=[0.0]*NMASK
    for base,gd,full in relevant:
        d=[base]*NMASK
        for mask in range(1,NMASK):
            lsb=mask & -mask
            bit=lsb.bit_length()-1
            prev=mask^lsb
            d[mask]=max(d[prev],gd[bit])
        for mask,dist in enumerate(d):
            min_sep[mask]=min(min_sep[mask],dist)
            if dist<=EPS:
                collision[mask]+=1
                max_hidden[mask]=max(max_hidden[mask],full)

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
          "minimum_candidate_linf_over_full_distinguishable_pairs":min_sep[mask],
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
        decision=("ROM1B3_DISCOVERY_ENRICHED_COORDINATE_FROZEN"
                  if min_k<8 else "ROM1B3_NO_REDUCED_STATE_SEPARATING_ENRICHMENT")
    else:
        decision="ROM1B3_NO_REDUCED_STATE_SEPARATING_ENRICHMENT"

    full_mask=NMASK-1
    full_control={
      "mask":full_mask,
      "dimension":16,
      "exactly_invertible_parameterization":True,
      "maximum_theta_reconstruction_abs_error":recon_max,
      "collision_count_under_preregistered_coordinate_metric":collision[full_mask],
      "minimum_candidate_linf_over_full_distinguishable_pairs":min_sep[full_mask],
      "note":"Invertibility is an information statement; the mean/half-contrast L_inf metric need not equal the cellwise Z16 L_inf metric."
    }

    complete=(repeat_identity and structure and eligible==114688 and len(states)==512 and
              prereg["data_firewall"]["heldout_used"] is False and
              prereg["data_firewall"]["B14_used"] is False and
              prereg["data_firewall"]["B2_future_probe_outcomes_used_to_rank_subsets"] is False)
    if not complete:
        decision="ROM1B3_ENRICHMENT_CENSUS_BLOCKED"

    result={
      "schema":"swap5.rom1b3.result.v1","workstream":"F-ROM","work_unit":"ROM-1B3",
      "decision":decision,"repeat_stdout_bitwise_identity":repeat_identity,
      "discovery_state_count":len(states),"eligible_cross_history_pair_count":eligible,
      "full_state_distinguishable_pair_count":len(relevant),"theta_collision_floor":EPS,
      "candidate_family_size":NMASK,
      "summary_by_added_count":[by_k[k] for k in sorted(by_k)],
      "selected_candidate":selected,
      "full_G1_to_G8_equivalence_control":full_control,
      "all_candidates":rows,
      "raw_discovery_sha256":hashlib.sha256(raw.encode()).hexdigest(),
      "heldout_used":False,"B14_used":False,
      "future_probe_outcomes_used_for_subset_selection":False,
      "pod_or_modal_basis_used":False,"memory_variable_selected":False,
      "closure_model_fit":False,"production_rom_authorized":False
    }
    pathlib.Path(args.output).write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    summary={k:result[k] for k in (
      "schema","work_unit","decision","discovery_state_count",
      "eligible_cross_history_pair_count","full_state_distinguishable_pair_count",
      "summary_by_added_count","selected_candidate","full_G1_to_G8_equivalence_control",
      "repeat_stdout_bitwise_identity","heldout_used","B14_used")}
    print(json.dumps(summary,sort_keys=True))
    return 0 if complete else 2

if __name__=="__main__":
    raise SystemExit(main())
