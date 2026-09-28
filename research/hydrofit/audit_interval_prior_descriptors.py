#!/usr/bin/env python3
"""Map non-hydraulic BRO descriptors to the exact target InvestigatedInterval."""
from __future__ import annotations
import argparse,json,xml.etree.ElementTree as ET
from pathlib import Path
from bro_bhrp_fetch import fetch,DEFAULT_BASE
def local(t): return t.rsplit('}',1)[-1]
FORBIDDEN={
 "shapefactorAlpha","shapefactorN","shapefactorM","shapefactorLambda","weightfactor",
 "modelledSaturatedHydraulicConductivity","residualVolumetricWaterContent",
 "volumetricWaterContentAtSaturation","saturatedHydraulicConductivity","simpleCurve"
}
CANDIDATES={
 "dryBulkDensity","organicMatterContent","clayContent","siltContent","sandContent",
 "textureClass","soilClass","standardSoilName","pedologicalSoilName","horizonCode",
 "organicMatterClass","carbonateClass","soilTypeLoamBased","containsGravel","sampleQuality"
}
def leaves(node):
 out={}
 for e in node.iter():
  if list(e): continue
  k=local(e.tag); v=(e.text or "").strip()
  if v and k in CANDIDATES and k not in FORBIDDEN: out.setdefault(k,[]).append(v)
 return {k:sorted(set(v)) for k,v in out.items()}
def main():
 ap=argparse.ArgumentParser(); ap.add_argument("--corpus",required=True); ap.add_argument("--out",required=True); a=ap.parse_args()
 corpus=json.loads(Path(a.corpus).read_text())
 counts={}
 for r in corpus["intervals"]:
  key=(r["bro_id"],str(r["begin_depth"]),str(r["end_depth"])); counts[key]=counts.get(key,0)+1
 rows=[]
 for bid in sorted({k[0] for k in counts}):
  st,ct,b=fetch(DEFAULT_BASE+"/objects/"+bid)
  if st//100!=2: raise SystemExit(f"fetch failed {bid}: {st}")
  root=ET.fromstring(b)
  for ordinal,iv in enumerate(e for e in root.iter() if local(e.tag)=="InvestigatedInterval"):
   begin=next(((e.text or "").strip() for e in iv.iter() if local(e.tag)=="beginDepth"),None)
   end=next(((e.text or "").strip() for e in iv.iter() if local(e.tag)=="endDepth"),None)
   key=(bid,str(begin),str(end))
   if counts.get(key,0)<=0: continue
   # Require that this exact interval is hydrophysical, not merely same-depth descriptive material.
   ets=[e.attrib.get("name") for da in iv.iter() if local(da.tag)=="DataArray" for e in da.iter() if local(e.tag)=="elementType"]
   if "WaterContentAndConductivityAtSpecificSoilWaterPotential" not in ets or "ShapeHydraulicConductivityCurve" not in ets: continue
   vals=leaves(iv)
   rows.append({"bro_id":bid,"begin_depth":begin,"end_depth":end,"interval_ordinal":ordinal,"descriptors":vals})
   counts[key]-=1
 remaining=sum(counts.values())
 if remaining or len(rows)!=len(corpus["intervals"]): raise SystemExit(f"interval provenance mismatch rows={len(rows)} expected={len(corpus['intervals'])} remaining={remaining}")
 coverage={k:sum(bool(r["descriptors"].get(k)) for r in rows) for k in sorted(CANDIDATES)}
 ambiguous={k:sum(len(r["descriptors"].get(k,[]))>1 for r in rows) for k in sorted(CANDIDATES)}
 out={"n_intervals":len(rows),"rows":rows,"coverage":coverage,"ambiguous":ambiguous,"forbidden":sorted(FORBIDDEN)}
 Path(a.out).write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
 print(f"BRO_PRIOR_INTERVAL_AUDIT|INTERVALS={len(rows)}")
 for k in sorted(CANDIDATES):
  print(f"BRO_PRIOR_INTERVAL_DESCRIPTOR|NAME={k}|COVERAGE={coverage[k]}/{len(rows)}|AMBIGUOUS={ambiguous[k]}")
if __name__=="__main__": main()
