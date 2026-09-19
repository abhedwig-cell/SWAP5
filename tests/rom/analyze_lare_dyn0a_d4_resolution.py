#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import pathlib
import re
from collections import defaultdict

D3_BOUNDS = [0.0, 140.0, 150.0, 160.0]
SE_BY_INDEX = {1:0.65,2:0.85,3:0.95}
FORCING_BY_INDEX = {1:"EQ",2:"WET",3:"DRY",4:"WET_DRY"}


def fields(payload: str) -> dict[str,str]:
    out={}
    for item in payload.split("|"):
        if "=" in item:
            k,v=item.split("=",1); out[k]=v
    return out


def reference_case_to_lare(case_id: str, partition: str) -> str:
    m=re.fullmatch(r"S([123])_B1_F([1234])",case_id)
    if not m:
        raise ValueError(case_id)
    se=SE_BY_INDEX[int(m.group(1))]
    forcing=FORCING_BY_INDEX[int(m.group(2))]
    return f"{partition}_SE{int(round(100*se)):03d}_FIXED_FLUX_{forcing}"


def load_ref_nodes(path: pathlib.Path):
    rows=defaultdict(list)
    for line in path.open(errors="replace"):
        if not line.startswith("LAREDYN0R_NODE|"):
            continue
        p=fields(line.split("|",1)[1])
        rows[int(p["STEP"])].append({
            "node":int(p["NODE"]),
            "z":float(p["Z"]),
            "dz":float(p["DZ"]),
            "theta":float(p["THETA"]),
        })
    for step in rows:
        rows[step].sort(key=lambda x:x["node"])
    return rows


def project(rows,bounds):
    out=[]
    for lo,hi in zip(bounds,bounds[1:]):
        storage=0.0; covered=0.0
        for row in rows:
            center=abs(row["z"])
            top=center-0.5*row["dz"]; bot=center+0.5*row["dz"]
            width=max(0.0,min(hi,bot)-max(lo,top))
            storage += row["theta"]*width
            covered += width
        if abs(covered-(hi-lo))>1e-9:
            raise SystemExit(f"coverage {covered} for {lo}-{hi}")
        out.append(storage)
    return out


def fine_series(path: pathlib.Path):
    rows=load_ref_nodes(path)
    if set(rows)!=set(range(1,1025)):
        raise SystemExit(f"incomplete fine trajectory {path}")
    return [project(rows[s],D3_BOUNDS) for s in range(1,1025)]


def d4_to_d3_series(lare_case: dict):
    raw=lare_case["finest_reference"]["layer_storage_cm"]
    if len(raw)!=1025:
        raise SystemExit("unexpected D4 trajectory length")
    out=[]
    for row in raw[1:]:
        if len(row)!=4:
            raise SystemExit("D4 shape")
        out.append([float(row[0])+float(row[1]),float(row[2]),float(row[3])])
    return out


def metrics(candidate,reference):
    diffs=[[c-r for c,r in zip(crow,rrow)] for crow,rrow in zip(candidate,reference)]
    absvals=[abs(v) for row in diffs for v in row]
    n=len(diffs); nl=3
    return {
        "max_abs_common_band_storage_cm":max(absvals),
        "mean_abs_common_band_storage_cm":sum(absvals)/(n*nl),
        "max_abs_140_150_storage_cm":max(abs(row[1]) for row in diffs),
        "max_abs_150_160_storage_cm":max(abs(row[2]) for row in diffs),
        "final_signed_common_band_storage_cm":diffs[-1],
    }


def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--d4",required=True,type=pathlib.Path)
    ap.add_argument("--d3-fine-only",required=True,type=pathlib.Path)
    ap.add_argument("--reference-dir",required=True,type=pathlib.Path)
    ap.add_argument("--reference-status",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    args=ap.parse_args()

    d4=json.loads(args.d4.read_text())
    d3=json.loads(args.d3_fine_only.read_text())
    status=json.loads(args.reference_status.read_text())["geometries"]["fine"]

    d3_cases={
        row["reference_case"]:row
        for row in d3["partitions"]["D3"]["cases"]
    }
    rows=[]
    exclusions=[]
    for ref_case in sorted(status):
        d4_id=reference_case_to_lare(ref_case,"D4")
        d4case=d4["cases"][d4_id]
        if (
            status[ref_case]["status"]!="QUALIFIED"
            or ref_case not in d3_cases
            or d4case["status"]!="QUALIFIED"
        ):
            exclusions.append({
                "reference_case":ref_case,
                "fine_status":status[ref_case]["status"],
                "d3_available":ref_case in d3_cases,
                "d4_status":d4case["status"],
            })
            continue
        ref=fine_series(args.reference_dir/f"fine-{ref_case}-o2.txt")
        d4m=metrics(d4_to_d3_series(d4case),ref)
        d3e=d3_cases[ref_case]["error"]
        d3m={
            "max_abs_common_band_storage_cm":float(d3e["max_abs_layer_storage_cm"]),
            "mean_abs_common_band_storage_cm":float(d3e["mean_abs_layer_storage_cm"]),
            "max_abs_140_150_storage_cm":float(d3e["per_layer_max_abs_storage_cm"][1]),
            "max_abs_150_160_storage_cm":float(d3e["per_layer_max_abs_storage_cm"][2]),
            "final_signed_common_band_storage_cm":[float(v) for v in d3e["final_signed_layer_storage_cm"]],
        }
        forcing=d3_cases[ref_case]["forcing"]
        se0=float(d3_cases[ref_case]["se0"])
        rows.append({
            "reference_case":ref_case,
            "se0":se0,
            "forcing":forcing,
            "D3":d3m,
            "D4_coarsened_to_D3_bands":d4m,
            "D4_noninferior_max":d4m["max_abs_common_band_storage_cm"] <= d3m["max_abs_common_band_storage_cm"] + 1e-15,
            "D4_noninferior_mean":d4m["mean_abs_common_band_storage_cm"] <= d3m["mean_abs_common_band_storage_cm"] + 1e-15,
            "D4_strict_better_max":d4m["max_abs_common_band_storage_cm"] < d3m["max_abs_common_band_storage_cm"] - 1e-15,
            "D4_strict_better_mean":d4m["mean_abs_common_band_storage_cm"] < d3m["mean_abs_common_band_storage_cm"] - 1e-15,
        })

    dynamic=[r for r in rows if r["forcing"]!="EQ"]
    high=[r for r in dynamic if r["se0"]>=0.85]
    all_noninferior=all(r["D4_noninferior_max"] and r["D4_noninferior_mean"] for r in dynamic)
    high_strict_both=any(r["D4_strict_better_max"] and r["D4_strict_better_mean"] for r in high)
    any_high_improvement=any(r["D4_strict_better_max"] or r["D4_strict_better_mean"] for r in high)

    if dynamic and all_noninferior and high_strict_both:
        decision="RESOLUTION_BENEFIT_CLEAR"
    elif high and not any_high_improvement:
        decision="CLOSURE_LIMIT_DOMINANT"
    else:
        decision="RESOLUTION_EFFECT_MIXED"

    result={
        "schema":"swap5.lare.dyn0a.d4.resolution-result.v1",
        "workstream":"F-ROM-LARE",
        "work_unit":"LARE-DYN0A-D4",
        "decision":decision,
        "comparison_bands_cm":[[0,140],[140,150],[150,160]],
        "common_case_count":len(rows),
        "common_dynamic_case_count":len(dynamic),
        "excluded_cases":exclusions,
        "cases":rows,
        "aggregate":{
            "D3_maximum_dynamic_common_band_error_cm":max((r["D3"]["max_abs_common_band_storage_cm"] for r in dynamic),default=None),
            "D4_maximum_dynamic_common_band_error_cm":max((r["D4_coarsened_to_D3_bands"]["max_abs_common_band_storage_cm"] for r in dynamic),default=None),
            "D3_mean_of_case_mean_dynamic_error_cm":(
                sum(r["D3"]["mean_abs_common_band_storage_cm"] for r in dynamic)/len(dynamic) if dynamic else None
            ),
            "D4_mean_of_case_mean_dynamic_error_cm":(
                sum(r["D4_coarsened_to_D3_bands"]["mean_abs_common_band_storage_cm"] for r in dynamic)/len(dynamic) if dynamic else None
            ),
            "all_dynamic_noninferior_on_max_and_mean":all_noninferior,
            "at_least_one_high_state_case_strictly_better_on_max_and_mean":high_strict_both,
        },
        "application_acceptance_adjudicated":False,
        "coarse_richards_verdict":"NOT_PART_OF_D4_RESOLUTION_GATE",
        "production_rom_authorized":False,
    }
    args.output.write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    print(json.dumps({
        "schema":result["schema"],
        "decision":decision,
        "common_dynamic":len(dynamic),
        "aggregate":result["aggregate"],
    },sort_keys=True))
    return 0

if __name__=="__main__":
    raise SystemExit(main())
