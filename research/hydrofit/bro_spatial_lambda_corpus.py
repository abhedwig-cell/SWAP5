#!/usr/bin/env python3
from __future__ import annotations
import argparse,json,time,xml.etree.ElementTree as ET
from pathlib import Path
from bro_bhrp_fetch import fetch,DEFAULT_BASE
def local(t): return t.rsplit('}',1)[-1]
def main():
 ap=argparse.ArgumentParser(); ap.add_argument("--out",required=True); ap.add_argument("--inspect-limit",type=int,default=200); a=ap.parse_args()
 lats=[round(50.8+.2*i,1) for i in range(14)]
 lons=[round(3.5+.3*i,1) for i in range(13)]
 ids=set(); errors=[]; capped=[]
 for lat in lats:
  for lon in lons:
   body=json.dumps({"area":{"enclosingCircle":{"center":{"lat":lat,"lon":lon},"radius":10.0}},"deliveryAccountableParty":"27378529","characteristicModelled":"JA"}).encode()
   st,ct,b=fetch(DEFAULT_BASE+"/characteristics/searches",method="POST",body=body)
   if st//100!=2:
    txt=b.decode("utf-8","replace")
    errors.append({"lat":lat,"lon":lon,"status":st,"body":txt[:500]})
    if "2000" in txt: capped.append((lat,lon))
    continue
   try: root=ET.fromstring(b)
   except Exception as e:
    errors.append({"lat":lat,"lon":lon,"status":st,"body":"parse:"+repr(e)}); continue
   here=set()
   for e in root.iter():
    txt=(e.text or '').strip()
    if local(e.tag)=="broId" or txt.startswith("BHR"): here.add(txt)
   ids.update(here)
   print(f"BRO_SPATIAL_CELL|LAT={lat}|LON={lon}|IDS={len(here)}")
   time.sleep(.01)
 frozen=sorted(ids)
 print(f"BRO_SPATIAL_DISCOVERY|CELLS={len(lats)*len(lons)}|UNIQUE={len(frozen)}|ERRORS={len(errors)}|CAPPED={len(capped)}")
 rec=[]; fail=0; bodem=0
 for bid in frozen[:a.inspect_limit]:
  st,ct,b=fetch(DEFAULT_BASE+"/objects/"+bid)
  if st//100!=2: fail+=1; continue
  root=ET.fromstring(b)
  vals=lambda n:[(e.text or '').strip() for e in root.iter() if local(e.tag)==n and (e.text or '').strip()]
  if "bodemfysischOnderzoek" not in vals("surveyPurpose"): continue
  bodem+=1
  proc=vals("modellingProcedure"); meth=vals("modellingMethod")
  for iv in (e for e in root.iter() if local(e.tag)=="InvestigatedInterval"):
   begin=next(((e.text or '').strip() for e in iv.iter() if local(e.tag)=="beginDepth"),None); end=next(((e.text or '').strip() for e in iv.iter() if local(e.tag)=="endDepth"),None)
   hyd=shape=None
   for da in (e for e in iv.iter() if local(e.tag)=="DataArray"):
    et=next((e.attrib.get("name") for e in da.iter() if local(e.tag)=="elementType"),None)
    v=next(((e.text or '').strip() for e in da.iter() if local(e.tag)=="values"),"")
    if et=="WaterContentAndConductivityAtSpecificSoilWaterPotential": hyd=v
    elif et=="ShapeHydraulicConductivityCurve": shape=v
   if hyd and shape:
    shp=[float(x) for x in shape.split(",")]
    rec.append({"bro_id":bid,"begin_depth":begin,"end_depth":end,"lambda":shp[3],"observations":len(hyd.split()),"procedure":proc[0] if proc else None,"method":meth[0] if meth else None})
 Path(a.out).write_text(json.dumps({"candidates":frozen,"errors":errors,"capped":capped,"inspected":min(a.inspect_limit,len(frozen)),"fetch_failures":fail,"bodemfysisch_objects":bodem,"intervals":rec},indent=2)+"\n")
 print(f"BRO_SPATIAL_CORPUS|INSPECTED={min(a.inspect_limit,len(frozen))}|FETCH_FAIL={fail}|BODEM={bodem}|INTERVALS={len(rec)}")
 if rec:
  import numpy as np,collections
  x=np.array([r["lambda"] for r in rec]); q=np.quantile(x,[.05,.25,.5,.75,.95])
  print(f"BRO_SPATIAL_LAMBDA|MIN={x.min():.9g}|Q05={q[0]:.9g}|Q25={q[1]:.9g}|MEDIAN={q[2]:.9g}|Q75={q[3]:.9g}|Q95={q[4]:.9g}|MAX={x.max():.9g}|NEG={(x<0).sum()}|ZERO={(x==0).sum()}|POS={(x>0).sum()}|OUTSIDE_M4_0={((x<-4)|(x>0)).sum()}")
  print("BRO_SPATIAL_PROCEDURES="+json.dumps(collections.Counter(r["procedure"] for r in rec),sort_keys=True))
if __name__=="__main__": main()
