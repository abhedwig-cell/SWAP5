#!/usr/bin/env python3
from __future__ import annotations
import argparse, json, pathlib

HISTORY_INDEX={"F00":1,"F01":2,"F02":3,"H00":4,"H01":5,"H02":6}

def parse_key(key: str):
    a,b=key.split("|")
    ah,ast=a.split(":"); bh,bst=b.split(":")
    return (ah,int(ast)),(bh,int(bst))

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--authority",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    args=ap.parse_args()
    a=json.loads(args.authority.read_text())
    if a["decision"]!="INDEPENDENT_STATE_INFORMATION_SCREEN_AND_PAIR_FREEZE_QUALIFIED":
        raise SystemExit("wrong Layer-ROM state authority")
    starts=set()
    pair_count=0
    for rid,keys in a["pair_freeze"]["representation_pairs"].items():
        if len(keys)!=6:
            raise SystemExit(f"pair count drift {rid}")
        for key in keys:
            x,y=parse_key(key); starts.add(x); starts.add(y); pair_count+=1
    rows=sorted(starts,key=lambda x:(HISTORY_INDEX[x[0]],x[1]))
    if len(rows)!=30:
        raise SystemExit(f"expected 30 unique starts, got {len(rows)}")
    args.output.write_text("".join(f"{HISTORY_INDEX[h]} {s}\n" for h,s in rows))
    print(json.dumps({
        "decision":"LAYER_ROM_PHASE_A_FUTURE_STARTS_FROZEN",
        "representation_pair_rows":pair_count,
        "unique_start_count":len(rows),
        "starts":[f"{h}:{s}" for h,s in rows],
    },sort_keys=True))
    return 0

if __name__=="__main__":
    raise SystemExit(main())
