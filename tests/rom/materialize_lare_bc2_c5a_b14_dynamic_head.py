#!/usr/bin/env python3
from __future__ import annotations
import argparse, hashlib, json, pathlib, subprocess, sys, tempfile

B14={
  "theta_r":0.01,
  "theta_s":0.416774,
  "alpha_per_cm":0.00541,
  "n":1.301528,
  "Ksat_cm_per_day":0.895023,
  "mualem_lambda":-0.334926,
}

def sha256(path:pathlib.Path)->str:
    return hashlib.sha256(path.read_bytes()).hexdigest()

def one(text:str,old:str,new:str,label:str)->str:
    n=text.count(old)
    if n!=1:
        raise SystemExit(f"{label}: expected one match, found {n}")
    return text.replace(old,new,1)

def main()->int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--c4z-materializer",required=True,type=pathlib.Path)
    ap.add_argument("--source",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    ap.add_argument("--manifest",required=True,type=pathlib.Path)
    a=ap.parse_args()

    with tempfile.TemporaryDirectory() as td:
        td=pathlib.Path(td)
        base=td/"c4z_base.f90"
        base_manifest=td/"c4z_manifest.json"
        subprocess.run([
          sys.executable,str(a.c4z_materializer),
          "--source",str(a.source),
          "--output",str(base),
          "--manifest",str(base_manifest)
        ],check=True)
        m=json.loads(base_manifest.read_text())
        if m.get("response_based") is not False:
            raise SystemExit("C4Z base materializer is not response-independent")
        text=base.read_text(encoding="utf-8")

    text=one(
      text,
      "    tr=0.02_real64;ts=0.427494_real64;alpha=0.021659_real64\n"
      "    nn=1.734737_real64;ks=31.225016_real64;lam=0.98087_real64",
      "    tr=0.01_real64;ts=0.416774_real64;alpha=0.00541_real64\n"
      "    nn=1.301528_real64;ks=0.895023_real64;lam=-0.334926_real64",
      "B14 constitutive parameter block"
    )
    text=one(text,"label='C4Z_BLIND'","label='C5A_B14  '","split label")
    text=one(
      text,
      "write(*,'(A)') 'LAREGW1_C4Z_BLIND_DYNAMIC_HEAD_GENERATED=TRUE'",
      "write(*,'(A)') 'LAREGW1_C5A_B14_DYNAMIC_HEAD_GENERATED=TRUE'",
      "completion marker"
    )
    a.output.write_text(text,encoding="utf-8")
    out={
      "schema":"swap5.lare.bc2.c5a.b14-dynamic-materialization.v1",
      "source_harness_sha256":sha256(a.source),
      "c4z_materializer_sha256":sha256(a.c4z_materializer),
      "output_sha256":sha256(a.output),
      "material":"B14",
      "B14":B14,
      "matched_transfer":{
        "histories":"exact C4Z Z01-Z04 effective-saturation anchors and switching times",
        "head_multipliers":"exact C4Z 0.875/1.125 material-specific h0 factors",
        "top_forcing":"gravity-consistent material-specific qeq only",
        "reference_retry_policy":"exact C4Z pre-existing D13 integrated-water-depth policy"
      },
      "allowed_changes":[
        "B01 constitutive constants -> frozen B14 constants",
        "split and completion labels only"
      ],
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
