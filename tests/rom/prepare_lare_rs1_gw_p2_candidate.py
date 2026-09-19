#!/usr/bin/env python3
from __future__ import annotations
import argparse, json, pathlib

CONTROL_PREFIX="CONTROL_"

def selected_roles(p1: dict) -> dict[str,list[str]]:
    rows=p1["selected_partitions"]
    dims=sorted(int(k[1:]) for k in rows if k.startswith("D"))
    one_x={d:int(rows[f"D{d}"]["collision_counts"]["1.0"]) for d in dims}
    four_x={d:int(rows[f"D{d}"]["collision_counts"]["4.0"]) for d in dims}
    separating=min(d for d in dims if one_x[d]==0)
    aggressive=max(2,separating-1)
    plateau_min=min(four_x.values())
    plateau=min(d for d in dims if four_x[d]==plateau_min)
    roles={}
    for role,d in (
        ("D_AGGRESSIVE",aggressive),
        ("D_STATE_SEPARATING",separating),
        ("D_ROBUST_PLATEAU",plateau),
    ):
        roles.setdefault(f"D{d}",[]).append(role)
    return roles

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--p1",required=True,type=pathlib.Path)
    ap.add_argument("--p2",required=True,type=pathlib.Path)
    ap.add_argument("--matrix-output",type=pathlib.Path)
    ap.add_argument("--candidate")
    ap.add_argument("--starts-output",type=pathlib.Path)
    ap.add_argument("--candidate-manifest-output",type=pathlib.Path)
    args=ap.parse_args()
    p1=json.loads(args.p1.read_text())
    p2=json.loads(args.p2.read_text())
    assert p1["decision"]=="LARE_RS1_GW_P1_RESPONSE_BLIND_PARTITIONS_FROZEN"
    assert p2["phase"]=="PREREGISTERED_BEFORE_FORMAL_P1_PAIR_FUTURE_RESPONSE_EXECUTION"

    roles=selected_roles(p1)
    controls=[CONTROL_PREFIX+x for x in p2["representation_selection_rule"]["controls"]]
    candidates=sorted(roles,key=lambda x:int(x[1:]))+controls

    if args.matrix_output:
        args.matrix_output.write_text(json.dumps({
            "candidate": candidates
        },separators=(",",":"))+"\n")

    if args.candidate:
        cid=args.candidate
        if cid not in candidates:
            raise SystemExit(f"candidate not authorized by P2 rule: {cid}")
        manifest=p1["frozen_adversarial_pairs"][cid]
        starts=set()
        for pair in manifest["pairs"]:
            for side in ("a","b"):
                h=pair[side]["history"]
                step=int(pair[side]["step"])
                if not (h.startswith("G") and len(h)==3):
                    raise SystemExit(f"bad history {h}")
                ih=int(h[1:])+1
                if not (1<=ih<=6 and 1<=step<=1024):
                    raise SystemExit(f"bad start {h}:{step}")
                starts.add((ih,step))
        if args.starts_output:
            args.starts_output.write_text("".join(f"{ih} {step}\n" for ih,step in sorted(starts)))
        if args.candidate_manifest_output:
            out={
                "schema":"swap5.lare.rs1.gw.p2.candidate-manifest.v1",
                "candidate_id":cid,
                "roles":roles.get(cid,["FIXED_CONTROL"]),
                "pair_count":len(manifest["pairs"]),
                "unique_start_count":len(starts),
                "partition": (
                    p1["selected_partitions"][cid]
                    if cid in p1["selected_partitions"]
                    else p1["fixed_controls"][cid.removeprefix(CONTROL_PREFIX)]
                ),
                "pairs":manifest["pairs"]
            }
            args.candidate_manifest_output.write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
        print(json.dumps({"candidate":cid,"unique_start_count":len(starts),"roles":roles.get(cid,["FIXED_CONTROL"])},sort_keys=True))
    else:
        print(json.dumps({"matrix":{"candidate":candidates},"roles":roles},sort_keys=True))
    return 0

if __name__=="__main__":
    raise SystemExit(main())
