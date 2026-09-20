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
    ap.add_argument("--c5i-materializer",required=True,type=pathlib.Path)
    ap.add_argument("--c5e-materializer",required=True,type=pathlib.Path)
    ap.add_argument("--c5d-materializer",required=True,type=pathlib.Path)
    ap.add_argument("--c5c-materializer",required=True,type=pathlib.Path)
    ap.add_argument("--c5a-materializer",required=True,type=pathlib.Path)
    ap.add_argument("--c4z-materializer",required=True,type=pathlib.Path)
    ap.add_argument("--source",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    ap.add_argument("--manifest",required=True,type=pathlib.Path)
    a=ap.parse_args()

    with tempfile.TemporaryDirectory() as td:
        td=pathlib.Path(td)
        base=td/"c5i_base.f90"
        bm=td/"c5i_manifest.json"
        subprocess.run([
          sys.executable,str(a.c5i_materializer),
          "--c5e-materializer",str(a.c5e_materializer),
          "--c5d-materializer",str(a.c5d_materializer),
          "--c5c-materializer",str(a.c5c_materializer),
          "--c5a-materializer",str(a.c5a_materializer),
          "--c4z-materializer",str(a.c4z_materializer),
          "--source",str(a.source),
          "--output",str(base),
          "--manifest",str(bm)
        ],check=True)
        m=json.loads(bm.read_text())
        if m.get("response_based") is not False:
            raise SystemExit("C5I base materializer is not response-independent")
        text=base.read_text(encoding="utf-8")

    text=one(
      text,
      "call require(any(numnod==[512,1024]),'LAREGW1 C5E geometry is R512/R1024')",
      "call require(numnod==2048,'LAREGW1 C5L geometry is R2048')",
      "R2048 geometry guard"
    )
    text=one(
      text,
      "write(*,'(A)') 'LAREGW1_C5I_B14_T16_GENERATED=TRUE'",
      "write(*,'(A)') 'LAREGW1_C5L_B14_R2048_T16_GENERATED=TRUE'",
      "C5L completion marker"
    )

    a.output.write_text(text,encoding="utf-8")
    out={
      "schema":"swap5.lare.bc2.c5l.r2048-t16-materialization.v1",
      "source_harness_sha256":sha256(a.source),
      "c5i_materializer_sha256":sha256(a.c5i_materializer),
      "output_sha256":sha256(a.output),
      "geometry":{"id":"R2048","nodes":2048,"dz_cm":0.078125},
      "temporal_factor":16,
      "main_step_dt_day":0.00005,
      "main_steps_per_history":16384,
      "physical_horizon_day":0.8192,
      "current_reference_boundary_unchanged":True,
      "physical_history_changed":False,
      "reference_retry_policy_changed":False,
      "solver_or_physics_changed":False,
      "node_output_suppressed":True,
      "response_based":False
    }
    a.manifest.write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print(json.dumps(out,sort_keys=True))
    return 0

if __name__=="__main__":
    raise SystemExit(main())
