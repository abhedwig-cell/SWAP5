#!/usr/bin/env python3
"""Map non-hydraulic BRO descriptors to the exact target InvestigatedInterval."""
from __future__ import annotations
import argparse,hashlib,json,xml.etree.ElementTree as ET
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
 targets={(r["bro_id"],r["hyd_sha256"]):r for r in corpus["intervals"]}
 if len(targets)!=len(corpus["intervals"]): raise SystemExit("corpus hydraulic identity is not unique")
 rows=[]
 for bid in sorted({k[0] for k in targets}):
  st,ct,b=fetch(DEFAULT_BASE+"/objects/"+bid)
  if st//100!=2: raise SystemExit(f"fetch failed {bid}: {st}")
  root=ET.fromstring(b)
  for ordinal,iv in enumerate(e for e in root.iter() if local(e.tag)=="InvestigatedInterval"):
   begin=next(((e.text or "").strip() for e in iv.iter() if local(e.tag)=="beginDepth"),None)
   end=next(((e.text or "").strip() for e in iv.iter() if local(e.tag)=="endDepth"),None)
   hyd=None; ets=[]
   for da in (e for e in iv.iter() if local(e.tag)=="DataArray"):
    et=next((e.attrib.get("name") for e in da.iter() if local(e.tag)=="elementType"),None); ets.append(et)
    if et=="WaterContentAndConductivityAtSpecificSoilWaterPotential":
     hyd=next(((e.text or "").strip() for e in da.iter() if local(e.tag)=="values"),"")
   if not hyd or "ShapeHydraulicConductivityCurve" not in ets: continue
   hyd_hash=hashlib.sha256(hyd.encode()).hexdigest(); target=targets.get((bid,hyd_hash))
   if target is None: continue
   if str(begin)!=str(target["begin_depth"]) or str(end)!=str(target["end_depth"]): raise SystemExit(f"hash/depth mismatch {bid} {hyd_hash}")
   vals=leaves(iv)
   rows.append({"bro_id":bid,"hyd_sha256":hyd_hash,"begin_depth":begin,"end_depth":end,"interval_ordinal":ordinal,"descriptors":vals})
 if len(rows)!=len(corpus["intervals"]) or len({(r["bro_id"],r["hyd_sha256"]) for r in rows})!=len(rows): raise SystemExit(f"interval provenance mismatch rows={len(rows)} expected={len(corpus['intervals'])}")
 coverage={k:sum(bool(r["descriptors"].get(k)) for r in rows) for k in sorted(CANDIDATES)}
 ambiguous={k:sum(len(r["descriptors"].get(k,[]))>1 for r in rows) for k in sorted(CANDIDATES)}
 out={"n_intervals":len(rows),"rows":rows,"coverage":coverage,"ambiguous":ambiguous,"forbidden":sorted(FORBIDDEN)}
 Path(a.out).write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
 print(f"BRO_PRIOR_INTERVAL_AUDIT|INTERVALS={len(rows)}")
 for k in sorted(CANDIDATES):
  print(f"BRO_PRIOR_INTERVAL_DESCRIPTOR|NAME={k}|COVERAGE={coverage[k]}/{len(rows)}|AMBIGUOUS={ambiguous[k]}")
if __name__=="__main__": main()
