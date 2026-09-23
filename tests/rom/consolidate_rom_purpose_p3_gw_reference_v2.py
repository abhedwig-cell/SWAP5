#!/usr/bin/env python3
from __future__ import annotations
import argparse, json, pathlib

ROUTES={"R512_T32":32,"R1024_T32":32,"R2048_T32":32,"R2048_T16":16,"R2048_T8":8}

def matches(root:pathlib.Path|None,name:str):
    if root is None:
        return []
    return list(root.rglob(name))

def main()->int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--source-root",required=True,type=pathlib.Path)
    ap.add_argument("--r2048-root",required=True,type=pathlib.Path)
    ap.add_argument("--missing-root",type=pathlib.Path)
    ap.add_argument("--missing-binding",type=pathlib.Path)
    ap.add_argument("--output-dir",required=True,type=pathlib.Path)
    a=ap.parse_args()

    missing_cases=set()
    missing_binding=None
    if a.missing_binding is not None:
        missing_binding=json.loads(a.missing_binding.read_text())
        missing_cases={(x["material"],x["route"],int(x["opt"]),int(x["history"]))
                       for x in missing_binding["cases"]}
        if any(route=="R2048_T32" for _,route,_,_ in missing_cases):
            raise SystemExit("R2048_T32 must come entirely from authoritative stratum recovery")

    a.output_dir.mkdir(parents=True,exist_ok=True)
    provenance={}
    for material in ("B01","B14"):
      rendered={}
      for route,factor in ROUTES.items():
        for opt in (0,2):
          if route=="R2048_T32":
            name=f"gw_{material}_{route}_o{opt}.txt"
            rr=matches(a.r2048_root,name)
            if len(rr)!=1:
                raise SystemExit(f"expected exactly one authoritative recovered route {name}, got {len(rr)}")
            text=rr[0].read_text(errors="strict")
            if text.count("LAREGW1_STATE|")!=4*1024*factor:
                raise SystemExit(f"R2048 recovered state coverage mismatch {material} O{opt}")
            if text.count("LAREGW1_PROFILE|")!=4*1024*16:
                raise SystemExit(f"R2048 recovered profile coverage mismatch {material} O{opt}")
            provenance[f"{material}/{route}/O{opt}"]={
              "origin":"AUTHORITATIVE_FULL_R2048_T32_EXACT_STATE_RECOVERY",
              "path":str(rr[0])
            }
          else:
            chunks=[]
            for history in range(1,5):
              hh=f"{history:02d}"
              name=f"gw_{material}_{route}_o{opt}_h{hh}.txt"
              key=(material,route,opt,history)
              src=matches(a.source_root,name)
              rep=matches(a.missing_root,name)
              if key in missing_cases:
                if len(rep)!=1:
                    raise SystemExit(f"expected one targeted missing-slice repair {key}, got {len(rep)}")
                if len(src)>0:
                    raise SystemExit(f"targeted missing case unexpectedly also has successful source artifact {key}")
                chosen=rep[0]; origin="TARGETED_NON_R2048_EXACT_STATE_REPAIR"
              else:
                if len(src)!=1:
                    raise SystemExit(f"expected one successful original source slice {key}, got {len(src)}")
                if len(rep)>0:
                    raise SystemExit(f"unbound repair artifact for source-success case {key}")
                chosen=src[0]; origin="ORIGINAL_SUCCESSFUL_SOURCE_SLICE"
              chunks.append(chosen.read_text(errors="strict"))
              provenance[f"{material}/{route}/O{opt}/h{history}"]={"origin":origin,"path":str(chosen)}
            text="".join(chunks)
            if text.count("LAREGW1_STATE|")!=4*1024*factor:
                raise SystemExit(f"state coverage mismatch {material} {route} O{opt}")
            if text.count("LAREGW1_PROFILE|")!=4*1024*16:
                raise SystemExit(f"profile coverage mismatch {material} {route} O{opt}")

          out=a.output_dir/f"gw_{material}_{route}_o{opt}.txt"
          out.write_text(text)
          rendered[(route,opt)]=text

        if rendered[(route,0)]!=rendered[(route,2)]:
          raise SystemExit(f"O0/O2 identity mismatch {material} {route}")

    result={
      "schema":"swap5.rom-purpose.p3.gw-reference-consolidation.v2",
      "routes":list(ROUTES),
      "r2048_t32_authority":"AUTHORITATIVE_FULL_STRATUM_EXACT_STATE_RECOVERY",
      "targeted_non_r2048_repair_case_count":len(missing_cases),
      "targeted_non_r2048_repair_cases":([] if missing_binding is None else missing_binding["cases"]),
      "provenance":provenance,
      "complete_route_files":20,
      "scientific_change":False,
      "forcing_changed":False,
      "numerical_policy_changed":False,
      "solver_or_physics_changed":False
    }
    (a.output_dir/"consolidation.json").write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    return 0

if __name__=="__main__":
    raise SystemExit(main())
