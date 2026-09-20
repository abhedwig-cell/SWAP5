#!/usr/bin/env python3
from __future__ import annotations
import argparse, hashlib, json, pathlib, subprocess, sys, tempfile

def sha256(path:pathlib.Path)->str:
    return hashlib.sha256(path.read_bytes()).hexdigest()

def one(text:str,old:str,new:str,label:str)->str:
    n=text.count(old)
    if n!=1:
        raise SystemExit(f"{label}: expected one match, found {n}")
    return text.replace(old,new,1)

def main()->int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--c5a-materializer",required=True,type=pathlib.Path)
    ap.add_argument("--c4z-materializer",required=True,type=pathlib.Path)
    ap.add_argument("--source",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    ap.add_argument("--manifest",required=True,type=pathlib.Path)
    a=ap.parse_args()

    with tempfile.TemporaryDirectory() as td:
        td=pathlib.Path(td)
        base=td/"c5a_base.f90"
        base_manifest=td/"c5a_manifest.json"
        subprocess.run([
          sys.executable,str(a.c5a_materializer),
          "--c4z-materializer",str(a.c4z_materializer),
          "--source",str(a.source),
          "--output",str(base),
          "--manifest",str(base_manifest)
        ],check=True)
        m=json.loads(base_manifest.read_text())
        if m.get("response_based") is not False:
            raise SystemExit("C5A materializer is not response-independent")
        text=base.read_text(encoding="utf-8")

    text=one(
      text,
      "call require(any(numnod==[2,16]),'LAREGW1 C4Z geometry is R2 or R16')",
      "call require(any(numnod==[16,32,64]),'LAREGW1 C5C geometry is R16/R32/R64')",
      "reference geometry guard"
    )
    text=one(
      text,
      "write(*,'(A)') 'LAREGW1_C5A_B14_DYNAMIC_HEAD_GENERATED=TRUE'",
      "write(*,'(A)') 'LAREGW1_C5C_B14_REFERENCE_REFINEMENT_GENERATED=TRUE'",
      "completion marker"
    )
    a.output.write_text(text,encoding="utf-8")
    out={
      "schema":"swap5.lare.bc2.c5c.reference-materialization.v1",
      "source_harness_sha256":sha256(a.source),
      "c4z_materializer_sha256":sha256(a.c4z_materializer),
      "c5a_materializer_sha256":sha256(a.c5a_materializer),
      "output_sha256":sha256(a.output),
      "allowed_reference_geometries":{
        "R16":{"nodes":16,"dz_cm":10.0},
        "R32":{"nodes":32,"dz_cm":5.0},
        "R64":{"nodes":64,"dz_cm":2.5}
      },
      "workload":"exact C5A B14 Z01-Z04 dynamic prescribed-head workload",
      "reference_retry_policy":"exact C5A/C4Z pre-existing D13 integrated-water-depth policy",
      "material_changed":False,
      "history_changed":False,
      "boundary_semantics_changed":False,
      "reference_retry_policy_changed":False,
      "solver_or_physics_changed":False,
      "response_based":False
    }
    a.manifest.write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print(json.dumps(out,sort_keys=True))
    return 0

if __name__=="__main__":
    raise SystemExit(main())
