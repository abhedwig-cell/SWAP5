#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import pathlib
import re

SUBSTEPS=(1,2,4,8)
CASES=tuple(f"S{s}_B1_F{f}" for s in (1,2,3) for f in (1,2,3,4))


def fields(payload: str) -> dict[str,str]:
    out={}
    for item in payload.split("|"):
        if "=" in item:
            k,v=item.split("=",1); out[k]=v
    return out


def load_storage(path: pathlib.Path) -> list[list[float]]:
    rows={}
    for line in path.open(errors="replace"):
        if not line.startswith("LAREDYN0R_NODE|"):
            continue
        p=fields(line.split("|",1)[1])
        step=int(p["STEP"])
        rows.setdefault(step,[]).append((int(p["NODE"]),float(p["THETA"]),float(p["DZ"])))
    if set(rows)!=set(range(1,1025)):
        raise ValueError(f"incomplete qualified trajectory {path}")
    result=[]
    for step in range(1,1025):
        vals=sorted(rows[step])
        result.append([theta*dz for _,theta,dz in vals])
    return result


def compare(a,b):
    if len(a)!=len(b): raise ValueError("length")
    vals=[]
    for ra,rb in zip(a,b):
        if len(ra)!=len(rb): raise ValueError("shape")
        vals.extend(abs(x-y) for x,y in zip(ra,rb))
    return {
        "max_abs_layer_storage_cm": max(vals),
        "mean_abs_layer_storage_cm": sum(vals)/len(vals),
    }


def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--evidence-dir",required=True,type=pathlib.Path)
    ap.add_argument("--geometry",required=True,choices=("d3","d2"))
    ap.add_argument("--output",required=True,type=pathlib.Path)
    args=ap.parse_args()

    status={}
    for line in (args.evidence_dir/"status.tsv").read_text().splitlines():
        geom,case,sub,opt,state=line.split("\t")
        if geom!=args.geometry: continue
        status.setdefault(case,{}).setdefault(int(sub),{})[int(opt)]=state

    cases={}
    for case in CASES:
        refinements={}
        for sub in SUBSTEPS:
            states=status.get(case,{}).get(sub,{})
            if set(states)!={0,2} or states[0]!=states[2]:
                raise SystemExit(f"status drift {case} substeps={sub}: {states}")
            state=states[0]
            row={"status":state}
            if state=="QUALIFIED":
                p=args.evidence_dir/f"{args.geometry}-{case}-s{sub}-o2.txt"
                row["storage"]=load_storage(p)
            refinements[str(sub)]=row

        successful=[s for s in SUBSTEPS if refinements[str(s)]["status"]=="QUALIFIED"]
        finest=max(successful) if successful else None
        convergence={}
        for a,b in zip(SUBSTEPS[:-1],SUBSTEPS[1:]):
            if refinements[str(a)]["status"]=="QUALIFIED" and refinements[str(b)]["status"]=="QUALIFIED":
                convergence[f"s{a}_vs_s{b}"]=compare(
                    refinements[str(a)]["storage"],refinements[str(b)]["storage"]
                )
        cases[case]={
            "refinement_status":{str(s):refinements[str(s)]["status"] for s in SUBSTEPS},
            "finest_successful_substeps":finest,
            "finest_internal_dt_day":(0.0008/finest if finest else None),
            "successive_refinement_difference":convergence,
        }

    qualified_finest=sum(v["finest_successful_substeps"] is not None for v in cases.values())
    all_blocked=[c for c,v in cases.items() if v["finest_successful_substeps"] is None]
    result={
        "schema":"swap5.lare.dyn0a.crq.v1",
        "workstream":"F-ROM-LARE",
        "work_unit":"LARE-DYN0A-CRQ",
        "geometry":args.geometry.upper(),
        "substep_ladder":list(SUBSTEPS),
        "internal_dt_day":[0.0008/s for s in SUBSTEPS],
        "case_count":len(CASES),
        "case_with_any_qualified_route_count":qualified_finest,
        "case_blocked_all_refinements_count":len(all_blocked),
        "blocked_all_refinements":all_blocked,
        "cases":cases,
        "tolerance_relaxed":False,
        "fallback_authority_expanded":False,
        "spatial_partition_changed":False,
        "production_rom_authorized":False,
    }
    args.output.write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    print(json.dumps({
        "schema":result["schema"],
        "geometry":result["geometry"],
        "qualified":qualified_finest,
        "blocked_all":all_blocked,
    },sort_keys=True))
    return 0

if __name__=="__main__":
    raise SystemExit(main())
