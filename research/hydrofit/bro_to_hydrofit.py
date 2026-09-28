#!/usr/bin/env python3
from __future__ import annotations
import argparse,csv,json,math,xml.etree.ElementTree as ET
from pathlib import Path
def local(t): return t.rsplit('}',1)[-1]
def main():
 ap=argparse.ArgumentParser(); ap.add_argument("xml"); ap.add_argument("--csv",required=True); ap.add_argument("--meta",required=True); a=ap.parse_args()
 root=ET.fromstring(Path(a.xml).read_bytes())
 broid=next((e.text.strip() for e in root.iter() if local(e.tag)=="broId" and e.text),None)
 rows=[]; models=[]
 for iv in (e for e in root.iter() if local(e.tag)=="InvestigatedInterval"):
  begin=next(((e.text or '').strip() for e in iv.iter() if local(e.tag)=="beginDepth"),None)
  end=next(((e.text or '').strip() for e in iv.iter() if local(e.tag)=="endDepth"),None)
  theta_s=next(((e.text or '').strip() for e in iv.iter() if local(e.tag)=="volumetricWaterContentAtSaturation"),None)
  theta_r=next(((e.text or '').strip() for e in iv.iter() if local(e.tag)=="residualVolumetricWaterContent"),None)
  ksat=next(((e.text or '').strip() for e in iv.iter() if local(e.tag)=="modelledSaturatedHydraulicConductivity"),None)
  model=None
  conductivity_shape=None
  arrays=[]
  for da in (e for e in iv.iter() if local(e.tag)=="DataArray"):
   et=None; vals=""
   for e in da.iter():
    if local(e.tag)=="elementType": et=e.attrib.get("name")
    if local(e.tag)=="values": vals=(e.text or '').strip()
   arrays.append((et,vals))
   if et=="WaterContentAndConductivityAtSpecificSoilWaterPotential":
    for block in vals.split():
     p=block.split(",")
     if len(p)!=3: raise ValueError(f"unexpected hydraulic tuple {block!r}")
     h,theta,k=map(float,p)
     rows.append({"bro_id":broid,"begin_depth_m":begin,"end_depth_m":end,"soil_water_potential":h,"volumetric_water_content":theta,"hydraulic_conductivity_cm_d":k})
   elif et=="ShapeRetentionCurve":
    p=[float(x) for x in vals.split(",")]
    model={"begin_depth_m":begin,"end_depth_m":end,"theta_s":theta_s,"theta_r":theta_r,"modelled_ksat_cm_d":ksat,"shape_retention":p}
   elif et=="ShapeHydraulicConductivityCurve":
    conductivity_shape=[float(x) for x in vals.split(",")]
  if model is not None:
   model["shape_conductivity"]=conductivity_shape
   model["l"]=conductivity_shape[3] if conductivity_shape and len(conductivity_shape)>=4 else None
   models.append(model)
 with open(a.csv,"w",newline="") as f:
  names=list(rows[0]) if rows else ["bro_id","begin_depth_m","end_depth_m","soil_water_potential","volumetric_water_content","hydraulic_conductivity_cm_d"]
  w=csv.DictWriter(f,fieldnames=names); w.writeheader(); w.writerows(rows)
 Path(a.meta).write_text(json.dumps({"bro_id":broid,"observation_count":len(rows),"models":models},indent=2)+"\n")
 print(f"BRO_HYDROFIT_EXPORT|BRO_ID={broid}|OBS={len(rows)}|MODELS={len(models)}|INTERVALS={len(set((r['begin_depth_m'],r['end_depth_m']) for r in rows))}")
 if not rows: raise SystemExit("no hydraulic observations")
if __name__=="__main__": main()
