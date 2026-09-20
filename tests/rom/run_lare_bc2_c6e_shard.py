#!/usr/bin/env python3
from __future__ import annotations

import argparse
import importlib.util
import json
import pathlib


def load(name: str, path: pathlib.Path):
    spec=importlib.util.spec_from_file_location(name,path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"cannot load {path}")
    mod=importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--qualifier",required=True,type=pathlib.Path)
    ap.add_argument("--core",required=True,type=pathlib.Path)
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--c6d",required=True,type=pathlib.Path)
    ap.add_argument("--shard-index",required=True,type=int)
    ap.add_argument("--shard-count",required=True,type=int)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    a=ap.parse_args()

    if a.shard_count<=0 or not (0<=a.shard_index<a.shard_count):
        raise SystemExit("invalid shard geometry")

    q=load("c6e_qualifier",a.qualifier)
    core=load("c6c_core",a.core)
    p=json.loads(a.prereg.read_text())
    c6d=json.loads(a.c6d.read_text())

    assert p["phase"]=="PREREGISTERED_BEFORE_C6E_NUMERICAL_RESPONSE"
    assert p["scientific_firewall"]["hydrological_response_used"] is False
    assert p["scientific_firewall"]["c6d_response_used_for_design"] is False
    assert c6d["decision"]=="AUTHORIZE_RESPONSE_FREE_PRESCRIBED_FLUX_BOUNDARY_MATHEMATICAL_QUALIFICATION_BEFORE_FRESH_BLIND_FREE_RUNNING"

    cases=q.build_cases(core,p)
    assert len(cases)==126
    rows=[]
    for idx,case in enumerate(cases):
        if idx % a.shard_count != a.shard_index:
            continue
        row=q.qualify_case(core,case,p)
        row["case_index"]=idx
        rows.append(row)

    out={
      "schema":"swap5.lare.bc2.c6e.shard.v1",
      "workstream":"F-ROM-LARE",
      "work_unit":"LARE-BC2-C6E",
      "shard_index":a.shard_index,
      "shard_count":a.shard_count,
      "total_case_count":len(cases),
      "case_count":len(rows),
      "rows":rows,
      "scientific_firewall":{
        "hydrological_response_used":False,
        "model_run_executed":False,
        "c6d_response_used_for_design":False,
        "free_running_bemr_implemented":False,
        "moment_fitting":False,
        "moment_localization":False,
        "c6c_retuning":False,
        "production_rom_authorized":False
      }
    }
    a.output.parent.mkdir(parents=True,exist_ok=True)
    a.output.write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print(json.dumps({
      "shard_index":a.shard_index,
      "shard_count":a.shard_count,
      "case_count":len(rows),
      "first_case_index":rows[0]["case_index"] if rows else None,
      "last_case_index":rows[-1]["case_index"] if rows else None
    },sort_keys=True))


if __name__=="__main__":
    main()
