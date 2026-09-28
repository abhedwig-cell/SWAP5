#!/usr/bin/env python3
"""Report exact depth semantics used by BRO soilLayer components."""
from __future__ import annotations
import argparse,json,xml.etree.ElementTree as ET
from pathlib import Path
from bro_bhrp_fetch import fetch,DEFAULT_BASE
def local(t): return t.rsplit('}',1)[-1]
def main():
 ap=argparse.ArgumentParser(); ap.add_argument("--corpus",required=True); ap.add_argument("--out",required=True); a=ap.parse_args()
 corpus=json.loads(Path(a.corpus).read_text()); bids=sorted({r["bro_id"] for r in corpus["intervals"]}); rows=[]
 for bid in bids:
  st,ct,b=fetch(DEFAULT_BASE+"/objects/"+bid)
  if st//100!=2: raise SystemExit(f"fetch {bid} {st}")
  root=ET.fromstring(b)
  for i,sl in enumerate(e for e in root.iter() if local(e.tag)=="soilLayer"):
   vals={}
   for e in sl.iter():
    v=(e.text or "").strip()
    if not v: continue
    k=local(e.tag)
    if any(x in k.lower() for x in ("depth","boundary","upper","lower")):
     vals.setdefault(k,[]).append(v)
   desc={}
   for e in sl.iter():
    k=local(e.tag); v=(e.text or "").strip()
    if k in {"clayContent","sandContent","siltContent","organicMatterContent","horizonCode"} and v: desc.setdefault(k,[]).append(v)
   rows.append({"bro_id":bid,"ordinal":i,"depth_fields":{k:sorted(set(v)) for k,v in vals.items()},"descriptors":{k:sorted(set(v)) for k,v in desc.items()}})
 Path(a.out).write_text(json.dumps({"rows":rows},indent=2,sort_keys=True)+"\n")
 print(f"BRO_SOILLAYER_DEPTH|OBJECTS={len(bids)}|LAYERS={len(rows)}")
 patterns={}
 for r in rows:
  key=",".join(sorted(r["depth_fields"]))
  patterns[key]=patterns.get(key,0)+1
 for k,n in sorted(patterns.items()): print(f"BRO_SOILLAYER_DEPTH_PATTERN|FIELDS={k}|COUNT={n}")
 for r in rows[:20]: print("BRO_SOILLAYER_DEPTH_EXAMPLE|"+json.dumps(r,sort_keys=True))
if __name__=="__main__":main()
