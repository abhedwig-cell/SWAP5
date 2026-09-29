#!/usr/bin/env python3
"""Audit leakage-free candidate descriptors for the frozen BRO lambda corpus."""
from __future__ import annotations
import argparse,hashlib,json,math,statistics,xml.etree.ElementTree as ET
from pathlib import Path
from bro_bhrp_fetch import fetch,DEFAULT_BASE

def local(t): return t.rsplit('}',1)[-1]
def fnum(x):
 try: return float(x)
 except (TypeError,ValueError): return None
def parse_hyd(v):
 out=[]
 for row in (v or "").split():
  try:
   a=[float(x) for x in row.split(",")]
   if len(a)>=3: out.append(a[:3])
  except ValueError: pass
 return out
def summary(vals):
 x=[v for v in vals if v is not None and math.isfinite(v)]
 return {"n":len(x),"min":min(x) if x else None,"max":max(x) if x else None,
         "median":statistics.median(x) if x else None}
def main():
 ap=argparse.ArgumentParser(); ap.add_argument("--corpus",required=True); ap.add_argument("--out",required=True); a=ap.parse_args()
 corpus=json.loads(Path(a.corpus).read_text()); targets={(r["bro_id"],r["hyd_sha256"]):r for r in corpus["intervals"]}
 if len(targets)!=len(corpus["intervals"]): raise SystemExit("corpus hydraulic identity is not unique")
 bybro={}
 for bid,_ in targets: bybro.setdefault(bid,[]).append(1)
 rows=[]; metadata={}
 for bid in sorted(bybro):
  st,ct,b=fetch(DEFAULT_BASE+"/objects/"+bid)
  if st//100!=2: raise SystemExit(f"fetch failed {bid}: {st}")
  root=ET.fromstring(b)
  # Inventory scalar leaf fields outside DataArray. Values are audited for coverage, not selected predictively here.
  scalars={}
  for e in root.iter():
   if list(e): continue
   txt=(e.text or "").strip()
   if txt and local(e.tag) not in {"values"}: scalars.setdefault(local(e.tag),set()).add(txt)
  metadata[bid]={k:sorted(v) for k,v in scalars.items()}
  for iv in (e for e in root.iter() if local(e.tag)=="InvestigatedInterval"):
   begin=next(((e.text or "").strip() for e in iv.iter() if local(e.tag)=="beginDepth"),None)
   end=next(((e.text or "").strip() for e in iv.iter() if local(e.tag)=="endDepth"),None)
   hyd=None
   for da in (e for e in iv.iter() if local(e.tag)=="DataArray"):
    et=next((e.attrib.get("name") for e in da.iter() if local(e.tag)=="elementType"),None)
    if et=="WaterContentAndConductivityAtSpecificSoilWaterPotential":
     hyd=next(((e.text or "").strip() for e in da.iter() if local(e.tag)=="values"),"")
   if not hyd: continue
   hyd_hash=hashlib.sha256(hyd.encode()).hexdigest(); target=targets.get((bid,hyd_hash))
   if target is None: continue
   if str(begin)!=str(target["begin_depth"]) or str(end)!=str(target["end_depth"]): raise SystemExit(f"hash/depth mismatch {bid} {hyd_hash}")
   obs=parse_hyd(hyd); h=[x[0] for x in obs]; th=[x[1] for x in obs]; k=[x[2] for x in obs if x[2]>0]
   bd=fnum(begin); ed=fnum(end)
   rows.append({"bro_id":bid,"hyd_sha256":hyd_hash,"begin_depth":bd,"end_depth":ed,"thickness":ed-bd if bd is not None and ed is not None else None,
    "n_obs":len(obs),"h_min":min(h) if h else None,"h_max":max(h) if h else None,"h_span":max(h)-min(h) if h else None,
    "theta_min":min(th) if th else None,"theta_max":max(th) if th else None,"theta_span":max(th)-min(th) if th else None,
    "log10k_min":math.log10(min(k)) if k else None,"log10k_max":math.log10(max(k)) if k else None,
    "log10k_span":math.log10(max(k)/min(k)) if k else None})
 if len(rows)!=len(corpus["intervals"]) or len({(r["bro_id"],r["hyd_sha256"]) for r in rows})!=len(rows): raise SystemExit(f"target mismatch rows={len(rows)} expected={len(corpus['intervals'])}")
 fields=[k for k in rows[0] if k!="bro_id"]
 coverage={k:sum(r.get(k) is not None for r in rows) for k in fields}
 # Object-level scalar metadata coverage. Exclude hydraulic source-fit fields by name.
 forbidden={"shapefactorAlpha","shapefactorN","shapefactorM","shapefactorLambda","weightfactor"}
 meta_keys=sorted(set().union(*(set(v) for v in metadata.values()))-forbidden)
 meta_cov={k:sum(k in metadata[bid] for bid in metadata) for k in meta_keys}
 out={"n_intervals":len(rows),"n_objects":len(metadata),"measurement_rows":rows,"measurement_coverage":coverage,
      "object_metadata_coverage":meta_cov,"object_metadata_values":metadata}
 Path(a.out).write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
 print(f"BRO_PRIOR_AUDIT|OBJECTS={len(metadata)}|INTERVALS={len(rows)}")
 for k in fields: print(f"BRO_PRIOR_DESCRIPTOR|NAME={k}|COVERAGE={coverage[k]}/{len(rows)}|SUMMARY={json.dumps(summary([r.get(k) for r in rows]),sort_keys=True)}")
 for k in meta_keys:
  if meta_cov[k]: print(f"BRO_PRIOR_METADATA|NAME={k}|OBJECT_COVERAGE={meta_cov[k]}/{len(metadata)}")
if __name__=="__main__": main()
