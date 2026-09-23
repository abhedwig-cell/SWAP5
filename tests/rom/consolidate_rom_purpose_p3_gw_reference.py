#!/usr/bin/env python3
from __future__ import annotations
import argparse, json, pathlib

ROUTES={"R512_T32":32,"R1024_T32":32,"R2048_T32":32,"R2048_T16":16,"R2048_T8":8}

def one(root:pathlib.Path,name:str):
    xs=list(root.rglob(name))
    return xs

def main()->int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--source-root",required=True,type=pathlib.Path)
    ap.add_argument("--repair-root",required=True,type=pathlib.Path)
    ap.add_argument("--repair-binding",required=True,type=pathlib.Path)
    ap.add_argument("--output-dir",required=True,type=pathlib.Path)
    a=ap.parse_args()
    b=json.loads(a.repair_binding.read_text())
    repaired={(x["material"],x["route"],int(x["opt"]),int(x["history"])) for x in b["cases"]}
    a.output_dir.mkdir(parents=True,exist_ok=True)

    provenance={}
    for material in ("B01","B14"):
      for route,factor in ROUTES.items():
        rendered={}
        for opt in (0,2):
          chunks=[]
          for history in range(1,5):
            hh=f"{history:02d}"
            name=f"gw_{material}_{route}_o{opt}_h{hh}.txt"
            key=(material,route,opt,history)
            src=one(a.source_root,name)
            rep=one(a.repair_root,name)
            if key in repaired:
              if len(rep)!=1:
                raise SystemExit(f"expected one repaired slice {key}, got {len(rep)}")
              if len(src)>0:
                raise SystemExit(f"repaired case unexpectedly also has source artifact {key}")
              chosen=rep[0]; origin="EXACT_STATE_HALF_SEGMENT_REPAIR"
            else:
              if len(src)!=1:
                raise SystemExit(f"expected one original successful slice {key}, got {len(src)}")
              if len(rep)>0:
                raise SystemExit(f"unbound repair artifact exists for successful source case {key}")
              chosen=src[0]; origin="ORIGINAL_SUCCESSFUL_HISTORY_SLICE"
            chunks.append(chosen.read_text(errors="strict"))
            provenance[f"{material}/{route}/O{opt}/h{history}"]={"origin":origin,"path":str(chosen)}
          text="".join(chunks)
          if text.count("LAREGW1_STATE|")!=4*1024*factor:
            raise SystemExit(f"state coverage mismatch {material} {route} O{opt}")
          if text.count("LAREGW1_PROFILE|")!=4*1024*16:
            raise SystemExit(f"profile coverage mismatch {material} {route} O{opt}")
          out=a.output_dir/f"gw_{material}_{route}_o{opt}.txt"
          out.write_text(text)
          rendered[opt]=text
        if rendered[0]!=rendered[2]:
          raise SystemExit(f"O0/O2 identity failure after consolidation {material} {route}")

    result={
      "schema":"swap5.rom-purpose.p3.gw-reference-consolidation.v1",
      "source_run":b["source_run"],
      "repair_case_count":len(repaired),
      "repair_cases":b["cases"],
      "provenance":provenance,
      "complete_route_count":10,
      "scientific_change":False,
      "forcing_changed":False,
      "numerical_policy_changed":False,
      "solver_or_physics_changed":False
    }
    (a.output_dir/"consolidation.json").write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    return 0
if __name__=="__main__":
    raise SystemExit(main())
