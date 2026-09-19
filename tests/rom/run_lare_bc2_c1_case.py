#!/usr/bin/env python3
from __future__ import annotations

import argparse
import importlib.util
import json
import pathlib

HERE=pathlib.Path(__file__).resolve().parent

def load_module(name,filename):
    spec=importlib.util.spec_from_file_location(name,HERE/filename)
    m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);return m

c1=load_module("bc2c1","analyze_lare_bc2_c1_teacher_forced.py")
c0=c1.c0

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--reference",required=True,type=pathlib.Path)
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--c0-result",required=True,type=pathlib.Path)
    ap.add_argument("--width",required=True,type=float)
    ap.add_argument("--history",required=True)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    a=ap.parse_args()

    pre=json.loads(a.prereg.read_text())
    c0res=json.loads(a.c0_result.read_text())
    assert pre["phase"]=="PREREGISTERED_BEFORE_TEACHER_FORCED_DRIFT_DECOMPOSITION"
    assert c0res["decision"]==pre["predecessor"]["required_decision"]
    assert a.width in c1.WIDTHS
    assert a.history in c0.HISTORY_STEPS

    init_meta,init_nodes,states,nodes=c0.b0.load_reference(a.reference)
    runs={}
    failures={}
    for dt in c1.DTS:
        key=f"{dt:.8f}"
        try:
            runs[key]=c1.decompose(
                a.history,a.width,dt,init_meta,init_nodes,states,nodes
            )
        except (ValueError,RuntimeError,FloatingPointError) as exc:
            failures[key]=str(exc)

    out={
        "schema":"swap5.lare.bc2.c1.case.v1",
        "width_cm":a.width,
        "history":a.history,
        "runs":runs,
        "failures":failures,
    }
    a.output.write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print(json.dumps({
        "width_cm":a.width,
        "history":a.history,
        "routes":sorted(runs),
        "failures":failures,
        "classifications":{
            k:{
                "state_shape":v["state_shape"]["dominance"],
                "q90":v["fluxes"]["q90"]["dominance"],
                "qi":v["fluxes"]["qi"]["dominance"],
                "qH":v["fluxes"]["qH"]["dominance"],
            } for k,v in runs.items()
        }
    },sort_keys=True))
    return 0

if __name__=="__main__":
    raise SystemExit(main())
