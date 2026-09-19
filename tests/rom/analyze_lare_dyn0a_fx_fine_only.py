#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import pathlib
import re
from collections import defaultdict

SE_BY_INDEX = {1: 0.65, 2: 0.85, 3: 0.95}
FORCING_BY_INDEX = {1: "EQ", 2: "WET", 3: "DRY", 4: "WET_DRY"}
PARTITIONS = {
    "D3": [0.0, 140.0, 150.0, 160.0],
    "D2": [0.0, 150.0, 160.0],
}


def fields(payload: str) -> dict[str, str]:
    out = {}
    for item in payload.split("|"):
        if "=" in item:
            k, v = item.split("=", 1)
            out[k] = v
    return out


def case_from_reference(case_id: str, partition: str) -> str:
    m = re.fullmatch(r"S([123])_B1_F([1234])", case_id)
    if not m:
        raise ValueError(case_id)
    se = SE_BY_INDEX[int(m.group(1))]
    forcing = FORCING_BY_INDEX[int(m.group(2))]
    return f"{partition}_SE{int(round(100*se)):03d}_FIXED_FLUX_{forcing}"


def load_reference_case(path: pathlib.Path):
    rows = defaultdict(list)
    for line in path.open(errors="replace"):
        if not line.startswith("LAREDYN0R_NODE|"):
            continue
        row = fields(line.split("|", 1)[1])
        rows[int(row["STEP"])].append({
            "node": int(row["NODE"]),
            "z": float(row["Z"]),
            "dz": float(row["DZ"]),
            "theta": float(row["THETA"]),
        })
    for step in rows:
        rows[step].sort(key=lambda x: x["node"])
    return rows


def project_storage(rows, bounds):
    out = []
    for lo, hi in zip(bounds, bounds[1:]):
        storage = 0.0
        covered = 0.0
        for row in rows:
            c = abs(row["z"])
            top = c - 0.5 * row["dz"]
            bot = c + 0.5 * row["dz"]
            w = max(0.0, min(hi, bot) - max(lo, top))
            if w > 0:
                storage += row["theta"] * w
                covered += w
        if abs(covered - (hi - lo)) > 1e-9:
            raise SystemExit(f"coverage mismatch {lo}-{hi}: {covered}")
        out.append(storage)
    return out


def fine_series(ref_dir, case_id, bounds):
    rows = load_reference_case(ref_dir / f"fine-{case_id}-o2.txt")
    if set(rows) != set(range(1, 1025)):
        raise SystemExit(f"incomplete fine case {case_id}")
    return [project_storage(rows[s], bounds) for s in range(1, 1025)]


def summarize(candidate, reference):
    diffs = [[c-r for c,r in zip(cr, rr)] for cr,rr in zip(candidate,reference)]
    nlayer = len(reference[0])
    per_layer_max = [max(abs(row[i]) for row in diffs) for i in range(nlayer)]
    per_layer_mean = [sum(abs(row[i]) for row in diffs)/len(diffs) for i in range(nlayer)]
    return {
        "max_abs_layer_storage_cm": max(per_layer_max),
        "mean_abs_layer_storage_cm": sum(sum(abs(v) for v in row) for row in diffs)/(len(diffs)*nlayer),
        "per_layer_max_abs_storage_cm": per_layer_max,
        "per_layer_mean_abs_storage_cm": per_layer_mean,
        "final_signed_layer_storage_cm": diffs[-1],
        "max_abs_bottom_layer_storage_cm": per_layer_max[-1],
        "mean_abs_bottom_layer_storage_cm": per_layer_mean[-1],
    }


def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--ode",required=True,type=pathlib.Path)
    ap.add_argument("--reference-dir",required=True,type=pathlib.Path)
    ap.add_argument("--reference-status",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    args=ap.parse_args()

    ode=json.loads(args.ode.read_text())
    status=json.loads(args.reference_status.read_text())
    assert ode["decision"]=="LARE_DYN0A_HEUN_REFINEMENT_CHARACTERIZED"
    assert status["decision"]=="LARE_DYN0A_FX_REFERENCE_CASES_CHARACTERIZED"

    result_parts={}
    for part,bounds in PARTITIONS.items():
        cases=[]
        excluded=[]
        for ref_case in sorted(status["geometries"]["fine"]):
            lid=case_from_reference(ref_case,part)
            ls=ode["cases"][lid]["status"]
            fs=status["geometries"]["fine"][ref_case]["status"]
            if fs!="QUALIFIED" or ls!="QUALIFIED":
                excluded.append({
                    "reference_case":ref_case,
                    "lare_case":lid,
                    "fine_status":fs,
                    "lare_status":ls
                })
                continue
            fine=fine_series(args.reference_dir,ref_case,bounds)
            lraw=ode["cases"][lid]["finest_reference"]["layer_storage_cm"]
            if len(lraw)!=1025:
                raise SystemExit(f"unexpected LARE length {lid}")
            lare=[[float(v) for v in row] for row in lraw[1:]]
            cases.append({
                "reference_case":ref_case,
                "lare_case":lid,
                "forcing":FORCING_BY_INDEX[int(ref_case[-1])],
                "se0":SE_BY_INDEX[int(ref_case[1])],
                "error":summarize(lare,fine)
            })

        dynamic=[c for c in cases if c["forcing"]!="EQ"]
        eq=[c for c in cases if c["forcing"]=="EQ"]

        def agg(rows,key):
            vals=[float(r["error"][key]) for r in rows]
            return None if not vals else {"maximum":max(vals),"mean":sum(vals)/len(vals)}

        result_parts[part]={
            "qualified_case_count":len(cases),
            "qualified_dynamic_case_count":len(dynamic),
            "qualified_equilibrium_case_count":len(eq),
            "excluded_case_count":len(excluded),
            "excluded_cases":excluded,
            "cases":cases,
            "aggregate_all":{
                k:agg(cases,k) for k in (
                    "max_abs_layer_storage_cm",
                    "mean_abs_layer_storage_cm",
                    "max_abs_bottom_layer_storage_cm"
                )
            },
            "aggregate_dynamic_only":{
                k:agg(dynamic,k) for k in (
                    "max_abs_layer_storage_cm",
                    "mean_abs_layer_storage_cm",
                    "max_abs_bottom_layer_storage_cm"
                )
            }
        }

    result={
        "schema":"swap5.lare.dyn0a.fx.fine-only-characterization.v1",
        "workstream":"F-ROM-LARE",
        "work_unit":"LARE-DYN0A-FX-FINE",
        "decision":"LARE_DYN0A_FX_FINE_REFERENCE_CHARACTERIZED",
        "claim_limit":"Fine-Reference characterization only. No equal-dimension coarse-Richards verdict is inferred for cases where coarse Richards lacks numerical qualification.",
        "partitions":result_parts,
        "absolute_application_acceptance_adjudicated":False,
        "speed_claim":False,
        "production_rom_authorized":False
    }
    args.output.write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    print(json.dumps({
        "schema":result["schema"],
        "decision":result["decision"],
        "D3_dynamic_count":result_parts["D3"]["qualified_dynamic_case_count"],
        "D3_dynamic_aggregate":result_parts["D3"]["aggregate_dynamic_only"],
        "D2_dynamic_count":result_parts["D2"]["qualified_dynamic_case_count"],
        "D2_dynamic_aggregate":result_parts["D2"]["aggregate_dynamic_only"]
    },sort_keys=True))
    return 0

if __name__=="__main__":
    raise SystemExit(main())
