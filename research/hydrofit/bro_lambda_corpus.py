#!/usr/bin/env python3
from __future__ import annotations
import argparse,collections,json,statistics,time,xml.etree.ElementTree as ET
from urllib.parse import urlencode
from pathlib import Path
import numpy as np
from bro_bhrp_fetch import fetch,DEFAULT_BASE

def local(t): return t.rsplit('}',1)[-1]
def texts(root,name): return [(e.text or '').strip() for e in root.iter() if local(e.tag)==name and (e.text or '').strip()]
def main():
 ap=argparse.ArgumentParser(); ap.add_argument("--party",default="27378529"); ap.add_argument("--limit",type=int,default=100); ap.add_argument("--out",required=True); a=ap.parse_args()
 url=DEFAULT_BASE+"/bro-ids?"+urlencode({"bronhouder":a.party})
 status,ctype,b=fetch(url); 
 if status//100!=2: raise SystemExit(f"bro-ids status {status}: {b[:500]!r}")
 root=ET.fromstring(b); ids=sorted(set(texts(root,"broId")))
 print(f"BRO_CORPUS_IDS|PARTY={a.party}|COUNT={len(ids)}|FIRST={ids[:5]}")
 rec=[]; failures=0; bodem=0
 for i,bid in enumerate(ids[:a.limit]):
  st,ct,obj=fetch(DEFAULT_BASE+"/objects/"+bid)
  if st//100!=2:
   failures+=1; print(f"BRO_CORPUS_FETCH_FAIL|BRO={bid}|STATUS={st}"); continue
  x=ET.fromstring(obj)
  purposes=texts(x,"surveyPurpose")
  if "bodemfysischOnderzoek" not in purposes: continue
  bodem+=1
  procedure=texts(x,"modellingProcedure")
  method=texts(x,"modellingMethod")
  for iv in (e for e in x.iter() if local(e.tag)=="InvestigatedInterval"):
   begin=next(iter(texts(iv,"beginDepth")),None); end=next(iter(texts(iv,"endDepth")),None)
   hyd=None; shape=None
   for da in (e for e in iv.iter() if local(e.tag)=="DataArray"):
    et=next((e.attrib.get("name") for e in da.iter() if local(e.tag)=="elementType"),None)
    vals=next(((e.text or '').strip() for e in da.iter() if local(e.tag)=="values"),"")
    if et=="WaterContentAndConductivityAtSpecificSoilWaterPotential": hyd=vals
    elif et=="ShapeHydraulicConductivityCurve": shape=vals
   if hyd and shape:
    shp=[float(z) for z in shape.split(",")]
    tuples=[z for z in hyd.split() if len(z.split(","))==3]
    rec.append({"bro_id":bid,"begin_depth":begin,"end_depth":end,"lambda":shp[3],"weightfactor":shp[4] if len(shp)>4 else None,"observations":len(tuples),"procedure":procedure[0] if procedure else None,"method":method[0] if method else None})
  time.sleep(.02)
 Path(a.out).write_text(json.dumps({"party":a.party,"total_ids":len(ids),"inspected":min(a.limit,len(ids)),"fetch_failures":failures,"bodemfysisch_objects":bodem,"intervals":rec},indent=2)+"\n")
 vals=np.array([r["lambda"] for r in rec],float)
 print(f"BRO_CORPUS_SUMMARY|INSPECTED={min(a.limit,len(ids))}|FAIL={failures}|BODEM_OBJECTS={bodem}|INTERVALS={len(rec)}")
 if len(vals):
  qs=np.quantile(vals,[.05,.25,.5,.75,.95])
  print(f"BRO_CORPUS_LAMBDA|MIN={vals.min():.9g}|Q05={qs[0]:.9g}|Q25={qs[1]:.9g}|MEDIAN={qs[2]:.9g}|Q75={qs[3]:.9g}|Q95={qs[4]:.9g}|MAX={vals.max():.9g}|NEG={(vals<0).sum()}|ZERO={(vals==0).sum()}|POS={(vals>0).sum()}|OUTSIDE_M4_0={((vals<-4)|(vals>0)).sum()}")
  print("BRO_CORPUS_PROCEDURES="+json.dumps(collections.Counter(r["procedure"] for r in rec),sort_keys=True))
  print("BRO_CORPUS_METHODS="+json.dumps(collections.Counter(r["method"] for r in rec),sort_keys=True))
  obs=np.array([r["observations"] for r in rec])
  print(f"BRO_CORPUS_OBS|MIN={obs.min()}|MEDIAN={np.median(obs):g}|MAX={obs.max()}")
if __name__=="__main__": main()
