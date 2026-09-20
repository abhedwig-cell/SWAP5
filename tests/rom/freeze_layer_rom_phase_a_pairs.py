#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import pathlib


def main() -> int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--state-result",required=True,type=pathlib.Path)
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    args=ap.parse_args()

    result=json.loads(args.state_result.read_text())
    prereg=json.loads(args.prereg.read_text())
    if result["decision"]!="INDEPENDENT_STATE_INFORMATION_SCREEN_COMPLETE":
        raise SystemExit("wrong independent state result")
    if prereg["phase"]!="PREREGISTERED_BEFORE_INDEPENDENT_REFERENCE_RESULT_EXPOSURE":
        raise SystemExit("wrong state-response preregistration")
    required=int(prereg["adversarial_pair_freeze"]["pair_count_per_representation"])
    representations=prereg["adversarial_pair_freeze"]["representation_ids"]

    frozen={}
    unique={}
    for rid in representations:
        row=result["representations"][rid]
        c1=int(row["collision_counts"]["1.0"])
        c2=int(row["collision_counts"]["2.0"])
        if c1>=required:
            selection_class="ALIAS_1X"
            maximum_radius=1.0
        elif c2>=required:
            selection_class="ALIAS_2X"
            maximum_radius=2.0
        else:
            selection_class="NEAR_BOUNDARY"
            maximum_radius=None

        pairs=row["nearest_adversarial"]["pairs"][:required]
        if len(pairs)!=required:
            raise SystemExit(f"insufficient nearest pairs for {rid}")
        if maximum_radius is not None and any(float(p["candidate_distance_over_floor"])>maximum_radius for p in pairs):
            raise SystemExit(f"pair radius contract failed for {rid}")

        out=[]
        for index,pair in enumerate(pairs,1):
            a=pair["a"]; b=pair["b"]
            physical_key=f'{a["history"]}:{a["step"]}|{b["history"]}:{b["step"]}'
            if physical_key not in unique:
                unique[physical_key]={
                    "a":a,
                    "b":b,
                    "used_by":[],
                }
            unique[physical_key]["used_by"].append(rid)
            out.append({
                "pair_id":f"{rid}_P{index:02d}",
                "physical_key":physical_key,
                "a":a,
                "b":b,
                "candidate_theta_linf":pair["candidate_theta_linf"],
                "candidate_distance_over_floor":pair["candidate_distance_over_floor"],
                "full_theta_linf":pair["full_theta_linf"],
                "full_distance_over_floor":pair["full_distance_over_floor"],
            })
        frozen[rid]={
            "selection_class":selection_class,
            "pair_count":required,
            "pairs":out,
        }

    payload={
        "schema":"swap5.layer-rom.phase-a.pair-manifest.v1",
        "workstream":"F-ROM-LAYER",
        "work_unit":"LAYER-ROM-PHASE-A-STATE1-PAIR-FREEZE",
        "decision":"INDEPENDENT_ADVERSARIAL_PAIRS_FROZEN_BEFORE_FUTURE_RESPONSE",
        "source":{
            "state_result_stdout_sha256":result["input"]["stdout_sha256"],
            "diagnostic_theta_floor":result["input"]["diagnostic_theta_floor"],
        },
        "representations":frozen,
        "unique_physical_pairs":unique,
        "pair_selection_used_future_response":False,
        "future_response_executed":False,
        "application_acceptance_adjudicated":False,
        "production_rom_authorized":False,
    }
    args.output.write_text(json.dumps(payload,indent=2,sort_keys=True)+"\n")
    print(json.dumps({
        "decision":payload["decision"],
        "unique_physical_pair_count":len(unique),
        "selection_class":{rid:frozen[rid]["selection_class"] for rid in representations},
    },sort_keys=True))
    return 0


if __name__=="__main__":
    raise SystemExit(main())
