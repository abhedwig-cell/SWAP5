#!/usr/bin/env python3
"""P-LID02 structural characterization: severe interval and duplicate identities."""
from __future__ import annotations
import argparse,hashlib,json,xml.etree.ElementTree as ET
from pathlib import Path
from bro_bhrp_fetch import fetch,DEFAULT_BASE
def local(t):return t.rsplit('}',1)[-1]
def val(node,name):return next(((e.text or "").strip() for e in node.iter() if local(e.tag)==name and (e.text or "").strip()),None)
def main():
 ap=argparse.ArgumentParser();ap.add_argument("--corpus",required=True);ap.add_argument("--out",required=True);a=ap.parse_args()
 corp=json.loads(Path(a.corpus).read_text()); counts={}
 for r in corp["intervals"]:
  k=(r["bro_id"],str(r["begin_depth"]),str(r["end_depth"]));counts.setdefault(k,[]).append(r)
 keys=[k for k,v in counts.items() if len(v)>1]; severe=("BHR000000378532","0.65","0.75")
 bids=sorted({k[0] for k in keys}|{severe[0]}); out={"duplicate_keys":[],"severe":None}
 for bid in bids:
  st,ct,b=fetch(DEFAULT_BASE+"/objects/"+bid)
  if st//100!=2:raise SystemExit(f"fetch {bid} {st}")
  root=ET.fromstring(b); matches={}
  for ordinal,iv in enumerate(e for e in root.iter() if local(e.tag)=="InvestigatedInterval"):
   k=(bid,str(val(iv,"beginDepth")),str(val(iv,"endDepth")))
   if k not in keys and k!=severe:continue
   hyd=shape=None
   for da in (e for e in iv.iter() if local(e.tag)=="DataArray"):
    et=next((e.attrib.get("name") for e in da.iter() if local(e.tag)=="elementType"),None);v=next(((e.text or "").strip() for e in da.iter() if local(e.tag)=="values"),"")
    if et=="WaterContentAndConductivityAtSpecificSoilWaterPotential":hyd=v
    elif et=="ShapeHydraulicConductivityCurve":shape=v
   ids={}
   for e in iv.iter():
    n=local(e.tag);t=(e.text or "").strip()
    if t and ("id" in n.lower() or "determination" in n.lower()):ids.setdefault(n,[]).append(t)
   rec={"ordinal":ordinal,"horizon":val(iv,"horizonCode"),"shape":shape,"lambda":float(shape.split(",")[3]) if shape else None,
        "hyd_count":len(hyd.split()) if hyd else 0,"hyd_sha256":hashlib.sha256((hyd or "").encode()).hexdigest(),"ids":{x:sorted(set(y)) for x,y in ids.items()}}
   matches.setdefault(k,[]).append(rec)
  for k in keys:
   if k[0]==bid:
    z={"key":k,"frozen_lambdas":[r["lambda"] for r in counts[k]],"xml_matches":matches.get(k,[])}
    out["duplicate_keys"].append(z);print("BRO_LID02_DUP|"+json.dumps(z,sort_keys=True))
  if bid==severe[0]:
   z={"key":severe,"xml_matches":matches.get(severe,[])}
   out["severe"]=z;print("BRO_LID02_SEVERE_SOURCE|"+json.dumps(z,sort_keys=True))
 Path(a.out).write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
 print(f"BRO_LID02_SUMMARY|DUPLICATE_KEYS={len(keys)}|SEVERE_XML_MATCHES={len(out['severe']['xml_matches'])}")
if __name__=="__main__":main()
