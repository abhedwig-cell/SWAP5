#!/usr/bin/env python3
from __future__ import annotations
import argparse, hashlib, json, pathlib, re, subprocess, sys, tempfile

def sha256(path:pathlib.Path)->str:
    return hashlib.sha256(path.read_bytes()).hexdigest()

def one(text:str,old:str,new:str,label:str)->str:
    n=text.count(old)
    if n!=1:
        raise SystemExit(f"{label}: expected one match, found {n}")
    return text.replace(old,new,1)

def main()->int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--c5c-materializer",required=True,type=pathlib.Path)
    ap.add_argument("--c5a-materializer",required=True,type=pathlib.Path)
    ap.add_argument("--c4z-materializer",required=True,type=pathlib.Path)
    ap.add_argument("--source",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    ap.add_argument("--manifest",required=True,type=pathlib.Path)
    a=ap.parse_args()

    with tempfile.TemporaryDirectory() as td:
        td=pathlib.Path(td)
        base=td/"c5c_base.f90"
        base_manifest=td/"c5c_manifest.json"
        subprocess.run([
          sys.executable,str(a.c5c_materializer),
          "--c5a-materializer",str(a.c5a_materializer),
          "--c4z-materializer",str(a.c4z_materializer),
          "--source",str(a.source),
          "--output",str(base),
          "--manifest",str(base_manifest)
        ],check=True)
        text=base.read_text(encoding="utf-8")

    text=one(
      text,
      "call require(any(numnod==[16,32,64]),'LAREGW1 C5C geometry is R16/R32/R64')",
      "call require(any(numnod==[128,256]),'LAREGW1 C5D geometry is R128/R256')",
      "geometry guard"
    )
    text=one(
      text,
      "write(*,'(A)') 'LAREGW1_C5C_B14_REFERENCE_REFINEMENT_GENERATED=TRUE'",
      "write(*,'(A)') 'LAREGW1_C5D_B14_REFERENCE_EXTENSION_GENERATED=TRUE'",
      "completion marker"
    )
    node_pat=re.compile(
      r"\n      do node=1,numnod\n"
      r"        write\(\*,'\(\*\(g0\)\)'\) 'LAREGW1_NODE\|SPLIT=',trim\(split_label\(ih\)\),'\|HISTORY=',trim\(history_label\(ih\)\), &\n"
      r"             '\|STEP=',step,'\|NODE=',node,'\|H=',physical%pressure_head\(node\),'\|THETA=',physical%water_content\(node\)\n"
      r"      end do"
    )
    text,n=node_pat.subn("",text,count=1)
    if n!=1:
        raise SystemExit(f"node-output suppression: expected one loop, found {n}")

    a.output.write_text(text,encoding="utf-8")
    out={
      "schema":"swap5.lare.bc2.c5d.reference-extension-materialization.v1",
      "source_harness_sha256":sha256(a.source),
      "c5c_materializer_sha256":sha256(a.c5c_materializer),
      "c5a_materializer_sha256":sha256(a.c5a_materializer),
      "c4z_materializer_sha256":sha256(a.c4z_materializer),
      "output_sha256":sha256(a.output),
      "allowed_reference_geometries":{
        "R128":{"nodes":128,"dz_cm":1.25},
        "R256":{"nodes":256,"dz_cm":0.625}
      },
      "node_output_suppressed":True,
      "state_output_retained":True,
      "history_summary_retained":True,
      "mass_and_transaction_gates_retained":True,
      "workload_changed":False,
      "reference_retry_policy_changed":False,
      "solver_or_physics_changed":False,
      "response_based":False
    }
    a.manifest.write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print(json.dumps(out,sort_keys=True))
    return 0

if __name__=="__main__":
    raise SystemExit(main())
