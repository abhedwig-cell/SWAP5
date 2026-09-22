from __future__ import annotations

import argparse
import itertools
import json
from collections import Counter
from pathlib import Path

from test_gc_rootzone_memory_rzm06e03d_census import (
    bits_key,
    parse_candidate_nodes,
    parse_d04,
    parse_e01,
    parse_e03,
)

LADDER=[1e-4,1e-5,1e-6,1e-7,1e-8,1e-9,1e-10,1e-12]
H16_MIN=1e-2

def summary(s:dict, vectors:bool=False)->dict:
    out={
      "provenance":s["provenance"],
      "profile_water_cm":s["profile_water_cm"],
      "root30_water_cm":s["root30_water_cm"],
      "H16_cm":s["pressure_head_cm"][15],
      "theta16":s["water_content"][15],
    }
    if vectors:
        out["pressure_head_cm"]=s["pressure_head_cm"]
        out["water_content"]=s["water_content"]
    return out

def metrics(a:dict,b:dict)->dict:
    return {
      "abs_delta_profile_water_cm":abs(b["profile_water_cm"]-a["profile_water_cm"]),
      "abs_delta_root30_water_cm":abs(b["root30_water_cm"]-a["root30_water_cm"]),
      "abs_delta_H16_cm":abs(b["pressure_head_cm"][15]-a["pressure_head_cm"][15]),
      "abs_delta_theta16":abs(b["water_content"][15]-a["water_content"][15]),
    }

def rank_key(r:dict):
    return (-r["abs_delta_H16_cm"],r["abs_delta_root30_water_cm"],r["abs_delta_profile_water_cm"],
            -r["abs_delta_theta16"],tuple(r["A"]["provenance"]),tuple(r["B"]["provenance"]))

def pair_summary(r:dict|None,vectors:bool=False):
    if r is None:return None
    return {"A":summary(r["A"],vectors),"B":summary(r["B"],vectors),
            **{k:v for k,v in r.items() if k.startswith("abs_delta_")}}

def main()->int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--d04",required=True)
    ap.add_argument("--e01",required=True)
    ap.add_argument("--e03",required=True)
    ap.add_argument("--e03b",required=True)
    ap.add_argument("--e03c",required=True)
    args=ap.parse_args()

    states=[]
    states.extend(parse_d04(Path(args.d04)))
    states.extend(parse_e01(Path(args.e01)))
    states.extend(parse_e03(Path(args.e03)))
    states.extend(parse_candidate_nodes(Path(args.e03b),"RZM06E03B","E03B"))
    states.extend(parse_candidate_nodes(Path(args.e03c),"RZM06E03C","E03C"))
    assert states

    raw_by_source=Counter(s["provenance"][0] for s in states)
    dedup={}
    for s in sorted(states,key=lambda x:tuple(x["provenance"])):
        dedup.setdefault(bits_key(s),s)
    unique=sorted(dedup.values(),key=lambda x:tuple(x["provenance"]))

    pairs=[]
    for a,b in itertools.combinations(unique,2):
        m=metrics(a,b)
        if m["abs_delta_H16_cm"]>=H16_MIN:
            pairs.append({"A":a,"B":b,**m})

    rung_results=[]
    selected_rung=None
    selected_pair=None
    for eps in LADDER:
        q=[r for r in pairs if r["abs_delta_profile_water_cm"]<=eps and r["abs_delta_root30_water_cm"]<=eps]
        q.sort(key=rank_key)
        rung_results.append({
          "epsilon_cm":eps,
          "qualifying_pairs":len(q),
          "best_pair":pair_summary(q[0] if q else None)
        })
        if q:
            selected_rung=eps
            selected_pair=q[0]

    exact=[r for r in pairs if r["abs_delta_profile_water_cm"]==0.0 and r["abs_delta_root30_water_cm"]==0.0]
    exact.sort(key=rank_key)

    if exact:
        decision="SELECTED_EXACT_STORAGE_MATCHED_INTERFACE_STATE_PAIR"
        selected_mode="EXACT"
        selected_pair=exact[0]
    elif selected_rung is not None and selected_rung<1e-4:
        decision="SELECTED_TIGHTER_STORAGE_MATCHED_INTERFACE_STATE_PAIR"
        selected_mode=selected_rung
    else:
        decision="CURRENT_LIBRARY_RESOLUTION_CEILING"
        selected_mode=None
        selected_pair=None

    evidence={
      "schema":"swap5.gc_rootzone_memory.rzm06e05.nested_storage_resolution_census.v1",
      "preregistration_commit":"21bbfdf16edbe842647b345223454bd3507a1a03",
      "production_changes":False,
      "firewall":{"response_fields_parsed":False,"state_input":"node H/theta plus provenance only"},
      "library":{"raw_state_count":len(states),"unique_state_count":len(unique),"raw_by_source":dict(sorted(raw_by_source.items()))},
      "H16_gate_cm":H16_MIN,
      "rungs":rung_results,
      "exact_rung":{"qualifying_pairs":len(exact),"best_pair":pair_summary(exact[0] if exact else None)},
      "selected_mode":selected_mode,
      "selected_pair":pair_summary(selected_pair,True) if selected_pair else None,
      "decision":decision,
      "nonclaims":["E05 performs no response probe","a selected pair establishes tighter state-space availability only",
                   "failure to find a tighter pair is not proof of exact state sufficiency"]
    }
    print("RZM06E05_CENSUS_JSON",json.dumps(evidence,sort_keys=True,separators=(",",":")))
    print("GC_RZM06E05_RESPONSE_BLIND_RESOLUTION_CENSUS=PASS")
    return 0

if __name__=="__main__":
    raise SystemExit(main())
