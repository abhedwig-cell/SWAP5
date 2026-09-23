#!/usr/bin/env python3
from __future__ import annotations
import argparse, pathlib, re

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--source",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    a=ap.parse_args()
    text=a.source.read_text()
    old="call require(any(numnod==[128,256]),'LAREGW1 ROMPRACT P2A geometry is R128/R256')"
    new="call require(any(numnod==[4,6,128,256]),'LAREGW1 ROMPRACT P2C geometry is G4/G6/R128/R256')"
    if text.count(old)!=1:
        raise SystemExit(f"geometry guard expected once, found {text.count(old)}")
    text=text.replace(old,new,1)
    pat=re.compile(
      r"(?ms)^      call require\(mod\(numnod,16\)==0,'LAREGW1 ROMPURP_P3_GW profile geometry divisible by 16'\)\n"
      r"      if\(mod\(step,OUTPUT_FACTOR\)==0\)then\n.*?^      end if\n")
    text,n=pat.subn("",text,count=1)
    if n!=1:
        raise SystemExit(f"profile block expected once, found {n}")
    a.output.write_text(text)
    print("ROM_PRACTICAL_P2C_SAME_PARTITION_REFERENCE=PASS")
if __name__=="__main__": main()
