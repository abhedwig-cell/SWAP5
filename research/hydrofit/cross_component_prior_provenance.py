#!/usr/bin/env python3
"""Apply preregistered depth-overlap provenance rules to BRO soil descriptors."""
from __future__ import annotations
import argparse,json,math,xml.etree.ElementTree as ET
from pathlib import Path
from bro_bhrp_fetch import fetch,DEFAULT_BASE
def local(t): return t.rsplit('}',1)[-1]
def text(e): return (e.text or "").strip()
def num(x):
 try:return float(x)
 except:return None
DESC={"clayContent","sandContent","siltContent","organicMatterContent","dryBulkDensity","horizonCode"}
PRIORITY={"EXACT":4,"CONTAINS_TARGET":3,"TARGET_CONTAINS_SOURCE":2,"PARTIAL":1}
def interval(node):
 vals={}
 for e in node.iter():
  k=local(e.tag)
  if k in ("beginDepth","endDepth") and text(e) and k not in vals: vals[k]=num(text(e))
 if vals.get("beginDepth") is not None and vals.get("endDepth") is not None:return vals["beginDepth"],vals["endDepth"]
 return None
def relation(a,b,c,d,tol=1e-9):
 ov=max(0.0,min(b,d)-max(a,c))
 if ov<=tol:return "NONE",0.0
 if abs(a-c)<=tol and abs(b-d)<=tol:return "EXACT",1.0
 if c<=a+tol and d>=b-tol:return "CONTAINS_TARGET",ov/(b-a)
 if a<=c+tol and b>=d-tol:return "TARGET_CONTAINS_SOURCE",ov/(b-a)
 return "PARTIAL",ov/(b-a)
def main():
 ap=argparse.ArgumentParser(); ap.add_argument("--corpus",required=True); ap.add_argument("--out",required=True); a=ap.parse_args()
 corpus=json.loads(Path(a.corpus).read_text()); rows=[]
 by={}
 for r in corpus["intervals"]: by.setdefault(r["bro_id"],[]).append(r)
 for bid,targets in sorted(by.items()):
  st,ct,b=fetch(DEFAULT_BASE+"/objects/"+bid)
  if st//100!=2:raise SystemExit(f"fetch {bid} {st}")
  root=ET.fromstring(b); parent={c:p for p in root.iter() for c in p}
  sources=[]
  for e in root.iter():
   dn=local(e.tag)
   if dn not in DESC or not text(e):continue
   p=parent.get(e); depthnode=None
   while p is not None:
    iv=interval(p)
    if iv is not None: depthnode=p; break
    p=parent.get(p)
   if depthnode is None:continue
   family=local(depthnode.tag)
   # Enforce preregistered source families.
   if dn in {"clayContent","sandContent","siltContent"} and family!="soilLayer":continue
   if dn=="organicMatterContent" and family not in {"soilLayer","InvestigatedInterval"}:continue
   if dn=="dryBulkDensity" and family not in {"InvestigatedInterval","WaterContentAndConductivityUnderDecreasingSoilWaterPotentialDetermination"}:continue
   sources.append({"descriptor":dn,"value":text(e),"family":family,"depth":iv})
  for t in targets:
   ta,tb=float(t["begin_depth"]),float(t["end_depth"])
   out={"bro_id":bid,"begin_depth":ta,"end_depth":tb,"descriptors":{}}
   for dn in sorted(DESC):
    cand=[]
    for s in sources:
     if s["descriptor"]!=dn:continue
     rel,cov=relation(ta,tb,*s["depth"])
     if rel!="NONE":cand.append({**s,"relation":rel,"coverage":cov})
    if not cand:
     out["descriptors"][dn]={"status":"MISSING","candidates":[]};continue
    best=max(PRIORITY[x["relation"]] for x in cand)
    top=[x for x in cand if PRIORITY[x["relation"]]==best]
    if top[0]["relation"]=="PARTIAL":
     status="PARTIAL_ONLY"; assigned=None
    else:
     vals=sorted({x["value"] for x in top})
     status="ASSIGNED" if len(vals)==1 else "AMBIGUOUS"; assigned=vals[0] if len(vals)==1 else None
    out["descriptors"][dn]={"status":status,"assigned":assigned,"candidates":top}
   rows.append(out)
 summary={}
 for dn in sorted(DESC):
  c={}
  for r in rows:
   s=r["descriptors"][dn]["status"];c[s]=c.get(s,0)+1
  summary[dn]=c
 Path(a.out).write_text(json.dumps({"rows":rows,"summary":summary},indent=2,sort_keys=True)+"\n")
 print(f"BRO_PRIOR_CROSS|INTERVALS={len(rows)}")
 for dn,c in summary.items():print(f"BRO_PRIOR_CROSS_DESCRIPTOR|NAME={dn}|STATUS={json.dumps(c,sort_keys=True)}")
if __name__=="__main__":main()
