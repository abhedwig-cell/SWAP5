#!/usr/bin/env python3
from __future__ import annotations
import argparse, importlib.util, json, pathlib, re, sys, hashlib

HERE=pathlib.Path(__file__).resolve().parent

def load(name,path):
    spec=importlib.util.spec_from_file_location(name,path)
    mod=importlib.util.module_from_spec(spec)
    sys.modules[name]=mod
    spec.loader.exec_module(mod)
    return mod

def sha(path):
    return hashlib.sha256(pathlib.Path(path).read_bytes()).hexdigest()

def replace_once(text,old,new,label):
    if text.count(old)!=1:
        raise SystemExit(f"{label}: expected one occurrence, found {text.count(old)}")
    return text.replace(old,new,1)

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--c4r-materializer",required=True,type=pathlib.Path)
    ap.add_argument("--fortran-source",required=True,type=pathlib.Path)
    ap.add_argument("--fortran-output",required=True,type=pathlib.Path)
    ap.add_argument("--analyzer-source",required=True,type=pathlib.Path)
    ap.add_argument("--analyzer-output",required=True,type=pathlib.Path)
    ap.add_argument("--manifest",required=True,type=pathlib.Path)
    a=ap.parse_args()

    c4r=load("c4r_materializer_for_c4v",a.c4r_materializer)
    tmpf=a.fortran_output.with_suffix(".c4r.tmp.f90")
    tmpa=a.analyzer_output.with_suffix(".c4r.tmp.py")
    c4r.materialize_fortran(a.fortran_source,tmpf)
    c4r.materialize_analyzer(a.analyzer_source,tmpa)

    ftext=tmpf.read_text(encoding="utf-8")
    ftext=replace_once(
        ftext,
        "integer, parameter :: NHIST=4, NSTEPS=64",
        "integer, parameter :: NHIST=4, NSTEPS=1024",
        "Fortran NSTEPS"
    )
    a.fortran_output.write_text(ftext,encoding="utf-8")

    atext=tmpa.read_text(encoding="utf-8")
    atext=replace_once(atext,"NSTEPS=64","NSTEPS=1024","analyzer NSTEPS")
    a.analyzer_output.write_text(atext,encoding="utf-8")
    tmpf.unlink();tmpa.unlink()

    manifest={
      "schema":"swap5.lare.bc2.c4v.horizon-materialization.v1",
      "c4r_materializer_sha256":sha(a.c4r_materializer),
      "fortran_source_sha256":sha(a.fortran_source),
      "fortran_output_sha256":sha(a.fortran_output),
      "analyzer_source_sha256":sha(a.analyzer_source),
      "analyzer_output_sha256":sha(a.analyzer_output),
      "horizon_steps":1024,
      "allowed_changes":[
        "C4R history-label/lambda/split materialization",
        "NSTEPS 64 -> 1024 in Reference harness",
        "NSTEPS 64 -> 1024 in FMC analyzer"
      ],
      "physics_or_closure_changed":False,
      "timestep_changed":False,
      "initial_states_changed":False
    }
    a.manifest.write_text(json.dumps(manifest,indent=2,sort_keys=True)+"\n")
    print(json.dumps(manifest,sort_keys=True))

if __name__=="__main__":
    raise SystemExit(main())
