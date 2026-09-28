#!/usr/bin/env python3
"""Frozen P-LID01 reclassification of P-LPRIOR03 output. No refitting."""
from __future__ import annotations
import argparse,re
def cls(c):
 if not (c < float("inf")) or c>=1e8:return "SEVERE"
 if c>=1e6:return "POOR"
 if c>=1e4:return "MODERATE"
 return "WELL_CONDITIONED"
def main():
 ap=argparse.ArgumentParser();ap.add_argument("log");a=ap.parse_args()
 rows=[]
 for line in open(a.log,encoding="utf-8"):
  if "BRO_PRIOR_FIT|" not in line:continue
  s=line[line.index("BRO_PRIOR_FIT|"):].strip();d={}
  for x in s.split("|")[1:]:
   if "=" in x:
    k,v=x.split("=",1);d[k]=v
  c=float(d["COND"]); cc=cls(c); blocks=d["BLOCKS"]!="NONE"; qualified=(not blocks and cc!="SEVERE")
  rows.append((d["POLICY"],d["BRO"],d["DEPTH"],cc,qualified,c,blocks))
  print(f"BRO_LID01|POLICY={d['POLICY']}|BRO={d['BRO']}|DEPTH={d['DEPTH']}|COND={c:.9g}|CLASS={cc}|BOUND_BLOCK={int(blocks)}|QUALIFIED_IDENTIFIABILITY={int(qualified)}")
 policies=sorted({r[0] for r in rows})
 for p in policies:
  z=[r for r in rows if r[0]==p]; counts={k:sum(r[3]==k for r in z) for k in ("WELL_CONDITIONED","MODERATE","POOR","SEVERE")}
  print(f"BRO_LID01_SUMMARY|POLICY={p}|N={len(z)}|WELL={counts['WELL_CONDITIONED']}|MODERATE={counts['MODERATE']}|POOR={counts['POOR']}|SEVERE={counts['SEVERE']}|QUALIFIED={sum(r[4] for r in z)}")
if __name__=="__main__":main()
