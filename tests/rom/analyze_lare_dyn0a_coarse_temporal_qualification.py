#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import math
import pathlib
import re
from collections import defaultdict

SUBSTEPS=(1,2,4,8,16)
OBS_DT=0.0008
NSTEP=1024
NODES={"d3":3,"d2":2}
DZ={"d3":[140.0,10.0,10.0],"d2":[150.0,10.0]}


def fields(payload:str)->dict[str,str]:
    out={}
    for item in payload.split("|"):
        if "=" in item:
            k,v=item.split("=",1); out[k]=v
    return out


def load_success(path:pathlib.Path, geom:str):
    states={}
    nodes=defaultdict(dict)
    summary={}
    for line in path.read_text(errors="replace").splitlines():
        if line.startswith("LAREDYN0R_STATE|"):
            row=fields(line.split("|",1)[1])
            states[int(row["STEP"])]={
                "total":float(row["TOTAL_STORAGE"]),
                "bflux":float(row["BOTTOM_DOWNWARD_FLUX"]),
            }
        elif line.startswith("LAREDYN0R_NODE|"):
            row=fields(line.split("|",1)[1])
            step=int(row["STEP"]); node=int(row["NODE"])
            nodes[step][node]=float(row["THETA"])
        elif line.startswith("LAREDYN0R_") and "=" in line and "|" not in line:
            k,v=line.split("=",1); summary[k]=v.strip()
    if set(states)!=set(range(1,NSTEP+1)):
        raise ValueError(f"incomplete states {path}: {len(states)}")
    if set(nodes)!=set(range(1,NSTEP+1)):
        raise ValueError(f"incomplete node steps {path}: {len(nodes)}")
    for step in nodes:
        if set(nodes[step])!=set(range(1,NODES[geom]+1)):
            raise ValueError(f"incomplete nodes {path} step {step}")
    return states,nodes,summary


def compare(a,b,geom):
    sa,na,_=a; sb,nb,_=b
    max_layer=0.0; sum_layer=0.0; count=0
    max_total=0.0; max_bflux=0.0
    for step in range(1,NSTEP+1):
        for node,dz in enumerate(DZ[geom],start=1):
            da=na[step][node]*dz
            db=nb[step][node]*dz
            d=abs(da-db)
            max_layer=max(max_layer,d); sum_layer+=d; count+=1
        max_total=max(max_total,abs(sa[step]["total"]-sb[step]["total"]))
        max_bflux=max(max_bflux,abs(sa[step]["bflux"]-sb[step]["bflux"]))
    return {
        "max_abs_layer_storage_cm":max_layer,
        "mean_abs_layer_storage_cm":sum_layer/count,
        "max_abs_total_storage_cm":max_total,
        "max_abs_bottom_flux_cm_per_day":max_bflux,
    }


def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--evidence-dir",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    args=ap.parse_args()
    root=args.evidence_dir
    manifest=json.loads((root/"execution_manifest.json").read_text())
    results={}
    qualified_count=0
    blocked_count=0

    for geom in ("d3","d2"):
        results[geom]={}
        for case in manifest["cases"]:
            routes={}
            parsed={}
            for sub in SUBSTEPS:
                row=manifest["runs"][geom][case][str(sub)]
                status=row["status"]
                routes[str(sub)]={"status":status,"internal_dt_day":OBS_DT/sub}
                if status=="QUALIFIED":
                    p=root/row["o2_file"]
                    parsed[sub]=load_success(p,geom)
                    routes[str(sub)]["max_abs_mass_residual_cm"]=float(parsed[sub][2].get("LAREDYN0R_MAX_ABS_MASS","nan"))
                    routes[str(sub)]["fallback_count"]=int(parsed[sub][2].get("LAREDYN0R_TOTAL_FALLBACK_COUNT","0"))

            pairwise={}
            prev_metric=None
            monotonic=True
            for left,right in zip(SUBSTEPS[:-1],SUBSTEPS[1:]):
                if left in parsed and right in parsed:
                    m=compare(parsed[left],parsed[right],geom)
                    pairwise[f"{left}_vs_{right}"]=m
                    if prev_metric is not None:
                        for key in ("max_abs_layer_storage_cm","max_abs_total_storage_cm","max_abs_bottom_flux_cm_per_day"):
                            if m[key] > prev_metric[key] + max(1e-15,1e-10*max(1.0,prev_metric[key])):
                                monotonic=False
                    prev_metric=m

            finest_pair=pairwise.get("8_vs_16")
            temporal_qualified=(
                routes["8"]["status"]=="QUALIFIED"
                and routes["16"]["status"]=="QUALIFIED"
                and finest_pair is not None
                and all(math.isfinite(float(v)) for v in finest_pair.values())
                and monotonic
            )
            if temporal_qualified: qualified_count+=1
            else: blocked_count+=1
            results[geom][case]={
                "temporal_qualification":"QUALIFIED" if temporal_qualified else "BLOCKED_COARSE_RICHARDS_TEMPORAL_QUALIFICATION",
                "routes":routes,
                "pairwise_refinement":pairwise,
                "refinement_monotonic":monotonic,
                "finest_successful_substeps":max((s for s in SUBSTEPS if s in parsed),default=None),
                "finest_successful_internal_dt_day":(
                    OBS_DT/max((s for s in SUBSTEPS if s in parsed))
                    if parsed else None
                ),
                "finest_pair_8_vs_16":finest_pair,
            }

    payload={
      "schema":"swap5.lare.dyn0a.coarse-richards-temporal-qualification.result.v1",
      "workstream":"F-ROM-LARE",
      "work_unit":"LARE-DYN0A-CQ",
      "decision":"LARE_DYN0A_COARSE_RICHARDS_TEMPORAL_QUALIFICATION_MAPPED",
      "internal_dt_day":[OBS_DT/s for s in SUBSTEPS],
      "substeps":list(SUBSTEPS),
      "qualified_case_count":qualified_count,
      "blocked_case_count":blocked_count,
      "geometries":results,
      "spatial_grid_changed":False,
      "forcing_changed":False,
      "new_fallback_policy_introduced":False,
      "lare_error_used_for_dt_selection":False,
      "application_acceptance_adjudicated":False,
      "production_rom_authorized":False,
    }
    args.output.write_text(json.dumps(payload,indent=2,sort_keys=True)+"\n")
    print(json.dumps({
      "schema":payload["schema"],
      "decision":payload["decision"],
      "qualified_case_count":qualified_count,
      "blocked_case_count":blocked_count,
      "d3_qualified":sum(v["temporal_qualification"]=="QUALIFIED" for v in results["d3"].values()),
      "d2_qualified":sum(v["temporal_qualification"]=="QUALIFIED" for v in results["d2"].values()),
    },sort_keys=True))
    return 0

if __name__=="__main__":
    raise SystemExit(main())
