#!/usr/bin/env python3
"""Audit structural/depth provenance for soil descriptors relative to hydrophysical intervals."""
from __future__ import annotations
import argparse,json,xml.etree.ElementTree as ET
from pathlib import Path
from bro_bhrp_fetch import fetch,DEFAULT_BASE
def local(t): return t.rsplit('}',1)[-1]
DESCRIPTORS={"organicMatterContent","clayContent","sandContent","siltContent","textureClass","dryBulkDensity","horizonCode"}
DEPTH_NAMES={"beginDepth","endDepth","upperBoundary","lowerBoundary","depth1","depth2","depth3","depth4"}
def txt(e): return (e.text or "").strip()
def f(x):
 try:return float(x)
 except:return None
def main():
 ap=argparse.ArgumentParser(); ap.add_argument("--corpus",required=True); ap.add_argument("--out",required=True); a=ap.parse_args()
 corpus=json.loads(Path(a.corpus).read_text()); bids=sorted({r["bro_id"] for r in corpus["intervals"]})
 target={(r["bro_id"],str(r["begin_depth"]),str(r["end_depth"])) for r in corpus["intervals"]}
 records=[]
 for bid in bids:
  st,ct,b=fetch(DEFAULT_BASE+"/objects/"+bid)
  if st//100!=2: raise SystemExit(f"fetch {bid} {st}")
  root=ET.fromstring(b); parent={c:p for p in root.iter() for c in p}
  for e in root.iter():
   name=local(e.tag)
   if name not in DESCRIPTORS or not txt(e): continue
   # Walk ancestors and record nearest containers carrying explicit depth semantics.
   anc=[]; p=parent.get(e); level=0
   while p is not None and level<10:
    vals={}
    for q in p.iter():
     qn=local(q.tag)
     if qn in DEPTH_NAMES and txt(q): vals.setdefault(qn,[]).append(txt(q))
    anc.append({"level":level+1,"tag":local(p.tag),"depths":{k:sorted(set(v)) for k,v in vals.items()}})
    p=parent.get(p); level+=1
   records.append({"bro_id":bid,"descriptor":name,"value":txt(e),"ancestors":anc})
 out={"records":records}
 Path(a.out).write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
 print(f"BRO_PRIOR_STRUCTURE|OBJECTS={len(bids)}|RECORDS={len(records)}")
 for d in sorted(DESCRIPTORS):
  rr=[r for r in records if r["descriptor"]==d]
  nearest={}
  depthful=0
  for r in rr:
   hit=next((x for x in r["ancestors"] if x["depths"]),None)
   if hit: depthful+=1; nearest[hit["tag"]]=nearest.get(hit["tag"],0)+1
  print(f"BRO_PRIOR_STRUCTURE_DESCRIPTOR|NAME={d}|VALUES={len(rr)}|WITH_DEPTH_ANCESTOR={depthful}|NEAREST={json.dumps(nearest,sort_keys=True)}")
if __name__=="__main__": main()
