#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import pathlib

ROUTES={
    "R512_T32":32,
    "R1024_T32":32,
    "R2048_T32":32,
    "R2048_T16":16,
    "R2048_T8":8,
}

def main()->int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--binding",required=True,type=pathlib.Path)
    ap.add_argument("--segment1-root",required=True,type=pathlib.Path)
    ap.add_argument("--segment2-root",required=True,type=pathlib.Path)
    ap.add_argument("--output-dir",required=True,type=pathlib.Path)
    a=ap.parse_args()

    b=json.loads(a.binding.read_text())
    a.output_dir.mkdir(parents=True,exist_ok=True)

    for case in b["cases"]:
        material=case["material"]; route=case["route"]; opt=int(case["opt"]); history=int(case["history"])
        hh=f"{history:02d}"
        n1=f"segment1.txt"; n2=f"segment2.txt"
        art1=f"p3gwseg1-{material}-{route}-o{opt}-h{history}"
        art2=f"p3gwseg2-{material}-{route}-o{opt}-h{history}"
        p1=a.segment1_root/art1/n1
        p2=a.segment2_root/art2/n2
        if not p1.exists() or not p2.exists():
            raise SystemExit(f"missing segments for {material} {route} O{opt} h{history}")
        text=p1.read_text(errors="strict")+p2.read_text(errors="strict")
        factor=ROUTES[route]
        if text.count("LAREGW1_STATE|")!=1024*factor:
            raise SystemExit("repaired history state coverage mismatch")
        if text.count("LAREGW1_PROFILE|")!=1024*16:
            raise SystemExit("repaired history profile coverage mismatch")
        out=a.output_dir/f"gw_{material}_{route}_o{opt}_h{hh}.txt"
        out.write_text(text)

    summary={
        "schema":"swap5.rom-purpose.p3.gw-reference-missing-slice-repair-result.v1",
        "source_run":b["source_run"],
        "case_count":len(b["cases"]),
        "cases":b["cases"],
        "scientific_change":False,
        "response_based":False
    }
    (a.output_dir/"repair_result.json").write_text(json.dumps(summary,indent=2,sort_keys=True)+"\n")
    return 0

if __name__=="__main__":
    raise SystemExit(main())
