#!/usr/bin/env python3
from __future__ import annotations
import argparse, hashlib, json, pathlib, subprocess, sys, tempfile

def sha256(path:pathlib.Path)->str:
    return hashlib.sha256(path.read_bytes()).hexdigest()

def replace_one(text:str,old:str,new:str,label:str)->str:
    n=text.count(old)
    if n!=1: raise SystemExit(f"{label}: expected one match, found {n}")
    return text.replace(old,new,1)

def main()->int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--purpose",required=True,choices=("SURF_P","GW_LB"))
    ap.add_argument("--material",required=True,choices=("B01","B14"))
    ap.add_argument("--member",required=True)
    ap.add_argument("--temporal-factor",required=True,type=int,choices=(8,16,32))
    ap.add_argument("--source",required=True,type=pathlib.Path)
    ap.add_argument("--surface-materializer",type=pathlib.Path)
    ap.add_argument("--gw-materializer",type=pathlib.Path)
    ap.add_argument("--c5a-materializer",type=pathlib.Path)
    ap.add_argument("--c4z-materializer",type=pathlib.Path)
    ap.add_argument("--coarse-output-adapter",required=True,type=pathlib.Path)
    ap.add_argument("--representation-ladder",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    ap.add_argument("--manifest",required=True,type=pathlib.Path)
    a=ap.parse_args()

    ladder=json.loads(a.representation_ladder.read_text())
    family=ladder[a.purpose]["family"]
    if a.member not in family: raise SystemExit("member not in frozen P4 family")
    if (a.purpose=="SURF_P" and not a.member.startswith("S")) or (a.purpose=="GW_LB" and not a.member.startswith("G")):
        raise SystemExit("member/purpose mismatch")
    bounds=[float(x) for x in family[a.member]["boundaries_cm"]]
    nodes=len(bounds)-1

    with tempfile.TemporaryDirectory() as td:
        td=pathlib.Path(td); base=td/"base.f90"; bm=td/"base.json"
        if a.purpose=="SURF_P":
            if a.surface_materializer is None: raise SystemExit("--surface-materializer required")
            subprocess.run([
              sys.executable,str(a.surface_materializer),"--source",str(a.source),
              "--material",a.material,"--temporal-factor",str(a.temporal_factor),
              "--output",str(base),"--manifest",str(bm)
            ],check=True)
            text=base.read_text()
            text=replace_one(
              text,
              "call require(mod(numnod,16)==0,'LAREDYN0R ROMPURP_P4_SURFACE geometry divisible by 16')",
              "call require(mod(numnod,16)==0,'LAREDYN0R ROMPURP_P1_SURFACE geometry divisible by 16')",
              "surface coarse-output adapter guard-label bridge")
            base.write_text(text); purpose_arg="surface"
        else:
            if None in (a.gw_materializer,a.c5a_materializer,a.c4z_materializer):
                raise SystemExit("GW materializer dependencies required")
            subprocess.run([
              sys.executable,str(a.gw_materializer),
              "--c5a-materializer",str(a.c5a_materializer),
              "--c4z-materializer",str(a.c4z_materializer),
              "--source",str(a.source),"--material",a.material,
              "--temporal-factor",str(a.temporal_factor),
              "--output",str(base),"--manifest",str(bm)
            ],check=True)
            text=base.read_text()
            text=replace_one(
              text,
              "call require(any(numnod==[512,1024,2048]),'LAREGW1 ROMPURP_P4_GW geometry is R512/R1024/R2048')",
              f"call require(numnod=={nodes},'LAREGW1 ROMPURP_P4_MATCHED_RICHARDS frozen same-partition geometry')",
              "P4 matched GW geometry guard")
            text=replace_one(
              text,
              "call require(mod(numnod,16)==0,'LAREGW1 ROMPURP_P4_GW profile geometry divisible by 16')",
              "call require(mod(numnod,16)==0,'LAREGW1 ROMPURP_P1_GW profile geometry divisible by 16')",
              "GW coarse-output adapter guard-label bridge")
            base.write_text(text); purpose_arg="gw"

        m=json.loads(bm.read_text())
        if m.get("response_based") is not False: raise SystemExit("base materializer must be response-independent")
        cm=td/"coarse.json"
        subprocess.run([
          sys.executable,str(a.coarse_output_adapter),"--source",str(base),"--purpose",purpose_arg,
          "--output",str(a.output),"--manifest",str(cm)
        ],check=True)
        if json.loads(cm.read_text()).get("response_based") is not False:
            raise SystemExit("coarse output adapter must be response-independent")

    out={
      "schema":"swap5.rom-purpose.p4.matched-richards-materialization.v1",
      "purpose":a.purpose,"material":a.material,"member":a.member,
      "boundaries_cm":bounds,"layer_thickness_cm":[bounds[i+1]-bounds[i] for i in range(nodes)],
      "temporal_factor":a.temporal_factor,"transaction_dt_day":0.0008/a.temporal_factor,
      "source_sha256":sha256(a.source),"output_sha256":sha256(a.output),
      "coarse_output_adapter_sha256":sha256(a.coarse_output_adapter),
      "representation_ladder_sha256":sha256(a.representation_ladder),
      "solver":"conventional Reference-Richards","nodes":nodes,
      "forcing_changed":False,"solver_or_physics_changed":False,"numerical_policy_changed":False,
      "output_serialization_changed_only":True,"response_based":False
    }
    a.manifest.parent.mkdir(parents=True,exist_ok=True)
    a.manifest.write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print(json.dumps(out,sort_keys=True)); return 0

if __name__=="__main__": raise SystemExit(main())
