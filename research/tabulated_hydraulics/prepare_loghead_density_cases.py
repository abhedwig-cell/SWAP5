#!/usr/bin/env python3
"""Prepare selected TAB-HYD log-head density cases.

Post-failure diagnostic only.  This varies only the number of log10(-h) knots
for the already branch-aware conductivity representation.
"""
from __future__ import annotations
import argparse, importlib.util, json, shutil
from pathlib import Path

HERE=Path(__file__).parent

def load(path, name):
    spec=importlib.util.spec_from_file_location(name,path)
    mod=importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(mod)
    return mod

base=load(HERE/"prepare_envelope_cases.py","tabhyd_base")
logmod=load(HERE/"prepare_envelope_cases_loghead.py","tabhyd_loghead")

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("hupsel_case",type=Path)
    ap.add_argument("staring_csv",type=Path)
    ap.add_argument("output_root",type=Path)
    ap.add_argument("--densities",default="250,500,900")
    ns=ap.parse_args()
    densities=[int(x) for x in ns.densities.split(",")]
    if any(n < 20 or n > 1000 for n in densities):
        raise SystemExit("density must be between 20 and MATAB=1000")

    if ns.output_root.exists():
        shutil.rmtree(ns.output_root)
    ns.output_root.mkdir(parents=True)

    series=base.read_staring(ns.staring_csv)
    selected=("loam_mid_free","clay_wet_free")
    manifest={}
    for n in densities:
        base.uniform_rows=lambda p, n=n: logmod.loghead_rows(p,n)
        for scenario in selected:
            spec=base.SCENARIOS[scenario]
            params=[series[spec["top"]],series[spec["sub"]]]
            name=f"{scenario}__n{n}"
            dst=ns.output_root/name
            base.prepare_case(ns.hupsel_case,dst,params,spec,table=True,kimpl=0)
            manifest[name]={"rows":n,"top":spec["top"],"sub":spec["sub"]}
            print(f"CASE {name} rows={n}")

    # analytical controls need no density duplication
    for scenario in selected:
        spec=base.SCENARIOS[scenario]
        params=[series[spec["top"]],series[spec["sub"]]]
        dst=ns.output_root/f"{scenario}__analytic"
        base.prepare_case(ns.hupsel_case,dst,params,spec,table=False,kimpl=0)
        print(f"CASE {scenario}__analytic")

    (ns.output_root/"manifest.json").write_text(json.dumps(manifest,indent=2,sort_keys=True)+"\n")

if __name__=="__main__":
    main()
