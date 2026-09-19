#!/usr/bin/env python3
from __future__ import annotations
import argparse,json,pathlib,shutil

CASES=[f"S{s}_B1_F{f}" for s in (1,2,3) for f in (1,2,3,4)]

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--shard-dir",required=True,type=pathlib.Path)
    ap.add_argument("--output-dir",required=True,type=pathlib.Path)
    args=ap.parse_args()
    out=args.output_dir
    out.mkdir(parents=True,exist_ok=True)
    manifest={"schema":"swap5.lare.corichards.q1.execution-manifest.v1","member":"R16","cases":CASES,"runs":{c:{} for c in CASES}}
    seen=set()
    for p in sorted(args.shard_dir.rglob("case_manifest.json")):
        r=json.loads(p.read_text())
        if r.get("schema")!="swap5.lare.corichards.q1.r16-case-manifest.v1": continue
        c=r["case"]
        if c in seen: raise SystemExit(f"duplicate shard {c}")
        seen.add(c)
        manifest["runs"][c]=r["runs"]
        for log in p.parent.glob("R16-*.txt"):
            dst=out/log.name
            if dst.exists(): raise SystemExit(f"duplicate log {dst.name}")
            shutil.copy2(log,dst)
    if seen!=set(CASES):
        raise SystemExit(f"case set mismatch missing={sorted(set(CASES)-seen)} extra={sorted(seen-set(CASES))}")
    (out/"execution_manifest.json").write_text(json.dumps(manifest,indent=2,sort_keys=True)+"\n")
    print(json.dumps({"member":"R16","case_count":len(seen),"merged":True},sort_keys=True))
    return 0
if __name__=="__main__": raise SystemExit(main())
