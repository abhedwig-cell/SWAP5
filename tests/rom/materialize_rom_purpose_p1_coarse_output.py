#!/usr/bin/env python3
from __future__ import annotations
import argparse, hashlib, json, pathlib, re

def sha(p): return hashlib.sha256(pathlib.Path(p).read_bytes()).hexdigest()

def replace_one(text,pattern,repl,label):
    rx=re.compile(pattern,re.MULTILINE|re.DOTALL)
    hits=rx.findall(text)
    if len(hits)!=1: raise SystemExit(f"{label}: expected one block, found {len(hits)}")
    return rx.sub(repl,text,count=1)

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--source",required=True,type=pathlib.Path)
    ap.add_argument("--purpose",required=True,choices=("surface","gw"))
    ap.add_argument("--output",required=True,type=pathlib.Path)
    ap.add_argument("--manifest",required=True,type=pathlib.Path)
    a=ap.parse_args()
    text=a.source.read_text()
    if a.purpose=="surface":
        text=replace_one(text,
          r"    real\(real64\) :: total,bin_theta\n    integer :: bin,lo_node,hi_node,nodes_per_bin\n",
          "    real(real64) :: total\n    integer :: node\n","surface declarations")
        text=replace_one(text,
          r"^      if\(mod\(step,OUTPUT_FACTOR\)==0\)then\n        call require\(mod\(numnod,16\)==0,'LAREDYN0R ROMPURP_P1_SURFACE geometry divisible by 16'\).*?^      end if",
          """      if(mod(step,OUTPUT_FACTOR)==0)then
        do node=1,numnod
          write(*,'(*(g0))') 'ROMPURP_P1_COARSE_NODE|PURPOSE=surface|CASE=',trim(case_label(ih)), &
               '|STEP=',step,'|OBS_STEP=',step/OUTPUT_FACTOR,'|NODE=',node,'|THETA=',physical%water_content(node)
        end do
      end if""","surface observation output")
    else:
        text=replace_one(text,
          r"    real\(real64\) :: total,upper,lower\n    integer :: bin,lo_node,hi_node,nodes_per_bin\n    real\(real64\) :: bin_theta\n",
          "    real(real64) :: total,upper,lower\n    integer :: node\n","gw declarations")
        text=replace_one(text,
          r"^      call require\(mod\(numnod,16\)==0,[^\n]*profile geometry divisible by 16[^\n]*\)\n      if\(mod\(step,OUTPUT_FACTOR\)==0\)then.*?^      end if",
          """      if(mod(step,OUTPUT_FACTOR)==0)then
        do node=1,numnod
          write(*,'(*(g0))') 'ROMPURP_P1_COARSE_NODE|PURPOSE=gw|HISTORY=',trim(history_label(ih)), &
               '|STEP=',step,'|OBS_STEP=',step/OUTPUT_FACTOR,'|NODE=',node,'|THETA=',physical%water_content(node)
        end do
      end if""","gw observation output")
    a.output.write_text(text)
    m={
      "schema":"swap5.rom-purpose.p1.coarse-output-adapter.v1",
      "purpose":a.purpose,"source_sha256":sha(a.source),"output_sha256":sha(a.output),
      "change":"Replace fine 10-cm diagnostic serialization with observation-window native-layer theta serialization for the frozen four-node same-partition coarse-Richards diagnostic.",
      "forcing_changed":False,"solver_or_physics_changed":False,"numerical_policy_changed":False,
      "response_based":False
    }
    a.manifest.write_text(json.dumps(m,indent=2,sort_keys=True)+"\n")
    print(json.dumps(m,sort_keys=True))
if __name__=="__main__": main()
