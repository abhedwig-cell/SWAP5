#!/usr/bin/env python3
from __future__ import annotations
import argparse, hashlib, json, pathlib, re, subprocess, sys, tempfile

def sha(p): return hashlib.sha256(pathlib.Path(p).read_bytes()).hexdigest()
def replace_one_regex(text,pat,repl,label):
    text,n=re.subn(pat,repl,text,count=1,flags=re.MULTILINE)
    if n!=1: raise SystemExit(f"{label}: expected 1 match, found {n}")
    return text

def apply_material(text,mat):
    text=replace_one_regex(text,
      r"tr=0\.02_real64;ts=0\.427494_real64;alpha=0\.021659_real64\n\s*nn=1\.734737_real64;ks=31\.225016_real64;lam=0\.98087_real64",
      f"tr={mat['theta_r']:.17g}_real64;ts={mat['theta_s']:.17g}_real64;alpha={mat['alpha_per_cm']:.17g}_real64\n    nn={mat['n']:.17g}_real64;ks={mat['Ksat_cm_per_day']:.17g}_real64;lam={mat['lambda']:.17g}_real64",
      "constitutive block")
    text=re.sub(r"real\(real64\), parameter :: theta_r_b01=0\.02_real64",
                f"real(real64), parameter :: theta_r_b01={mat['theta_r']:.17g}_real64",text)
    text=re.sub(r"real\(real64\), parameter :: theta_s_b01=0\.427494_real64",
                f"real(real64), parameter :: theta_s_b01={mat['theta_s']:.17g}_real64",text)
    return text

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--purpose",required=True,choices=("SURF_P","GW_LB"))
    ap.add_argument("--material",required=True)
    ap.add_argument("--materials",required=True,type=pathlib.Path)
    ap.add_argument("--surface-source",type=pathlib.Path)
    ap.add_argument("--gw-source",type=pathlib.Path)
    ap.add_argument("--surface-materializer",type=pathlib.Path)
    ap.add_argument("--gw-materializer",type=pathlib.Path)
    ap.add_argument("--c5a-materializer",type=pathlib.Path)
    ap.add_argument("--c4z-materializer",type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    ap.add_argument("--manifest",required=True,type=pathlib.Path)
    a=ap.parse_args()
    mats=json.loads(a.materials.read_text())["materials"]
    if a.material not in mats: raise SystemExit("unknown material")
    mat=mats[a.material]
    with tempfile.TemporaryDirectory() as td:
        td=pathlib.Path(td); base=td/"base.f90"; bm=td/"base.json"
        if a.purpose=="SURF_P":
            subprocess.run([sys.executable,str(a.surface_materializer),"--source",str(a.surface_source),
              "--material","B01","--temporal-factor","8","--output",str(base),"--manifest",str(bm)],check=True)
        else:
            subprocess.run([sys.executable,str(a.gw_materializer),
              "--c5a-materializer",str(a.c5a_materializer),"--c4z-materializer",str(a.c4z_materializer),
              "--source",str(a.gw_source),"--material","B01","--temporal-factor","8",
              "--output",str(base),"--manifest",str(bm)],check=True)
        text=base.read_text()
    text=apply_material(text,mat)
    if a.purpose=="GW_LB":
        text,n=re.subn(r"call require\(any\(numnod==\[512,1024,2048\]\),'LAREGW1 ROMPURP_P3_GW geometry is R512/R1024/R2048'\)",
          "call require(any(numnod==[128,256]),'LAREGW1 ROMPRACT P2A geometry is R128/R256')",text,count=1)
        if n!=1: raise SystemExit(f"GW geometry guard replacement found {n}")
    a.output.write_text(text)
    manifest={
      "schema":"swap5.rom-practical.p2a.reference-materialization.v1",
      "purpose":a.purpose,"material":a.material,"parameters":mat,
      "base_materializer_response_based":False,"solver_or_physics_changed":False,
      "forcing_history_changed":False,"temporal_factor":8,
      "output_sha256":sha(a.output),"source_branch_role":"evidence/provenance only"
    }
    a.manifest.write_text(json.dumps(manifest,indent=2,sort_keys=True)+"\n")
    print(json.dumps(manifest,sort_keys=True))
if __name__=="__main__": main()
