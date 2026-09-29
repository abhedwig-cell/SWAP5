#!/usr/bin/env python3
"""F-PE-ELASTIC10B bounded BHR-GT settlement-object pilot."""
from __future__ import annotations
import hashlib, json, re, sys
import xml.etree.ElementTree as ET
from datetime import datetime, timezone
from pathlib import Path

sys.path.insert(0,str(Path(__file__).resolve().parent))
from bro_bhrgt_fetch import fetch, DEFAULT_BASE

CENTER={"lat":52.038297852,"lon":5.31447958948}
RADII_KM=(0.5,5.0,25.0)
MAX_OBJECTS=5
ANALYSIS_TYPE="zetting"
BRO_RE=re.compile(r"\bBHR[A-Z0-9]{8,}\b",re.I)

def local(tag:str)->str:
    return tag.rsplit("}",1)[-1]

def txt(e)->str:
    return (e.text or "").strip()

def manifest(url,status,ctype,data,**extra):
    d={
      "retrieved_utc":datetime.now(timezone.utc).isoformat(),
      "url":url,"http_status":status,"content_type":ctype,
      "size_bytes":len(data),"sha256":hashlib.sha256(data).hexdigest(),
    }
    d.update(extra); return d

def write_evidence(root:Path,name:str,url:str,status:int,ctype:str,data:bytes,**extra):
    (root/f"{name}.response").write_bytes(data)
    (root/f"{name}.manifest.json").write_text(json.dumps(manifest(url,status,ctype,data,**extra),indent=2,sort_keys=True)+"\n")

def bro_ids_from_xml(data:bytes)->list[str]:
    ids=set()
    try:
      root=ET.fromstring(data)
      for e in root.iter():
        if local(e.tag).lower()=="broid" and txt(e):
          ids.add(txt(e))
    except ET.ParseError:
      pass
    for m in BRO_RE.findall(data.decode("utf-8","ignore")):
      ids.add(m)
    return sorted(ids)

def norm(s:str)->str:
    return re.sub(r"[^a-z0-9]+","",s.lower())

def audit_object(data:bytes, bro_id:str)->dict:
    root=ET.fromstring(data)
    elems=list(root.iter())
    names=[local(e.tag) for e in elems]
    lower=[x.lower() for x in names]
    alltext="\n".join(txt(e) for e in elems if txt(e))
    xmltext=data.decode("utf-8","ignore")

    def elements_named(*wanted):
      w={norm(x) for x in wanted}
      return [e for e in elems if norm(local(e.tag)) in w]

    settlement=[e for e in elems if "settlementcharacteristicsdetermination" in norm(local(e.tag))]
    step_types=[txt(e) for e in elements_named("stepType") if txt(e)]
    vertical_stress=[txt(e) for e in elements_named("verticalStress") if txt(e)]
    vertical_strain=[txt(e) for e in elements_named("verticalStrain") if txt(e)]
    eff_stress=[txt(e) for e in elements_named("verticalEffectiveStress") if txt(e)]
    pore=[txt(e) for e in elements_named("excessPoreWaterPressure","poreWaterPressureDifference") if txt(e)]
    values=[txt(e) for e in elems if norm(local(e.tag))=="values" and txt(e)]
    begin_depth=[txt(e) for e in elements_named("beginDepth","startDepth") if txt(e)]
    end_depth=[txt(e) for e in elements_named("endDepth") if txt(e)]
    moisture=[txt(e) for e in elements_named("sampleMoistness","waterContent") if txt(e)]
    quality=[txt(e) for e in elements_named("sampleQuality") if txt(e)]
    density=[txt(e) for e in elements_named("volumetricMassDensity") if txt(e)]
    solids_density=[txt(e) for e in elements_named("volumetricMassDensitySolids") if txt(e)]
    organic=[txt(e) for e in elements_named("organicMatterContent") if txt(e)]
    methods=[txt(e) for e in elements_named("determinationMethod","determinationProcedure") if txt(e)]

    # Some SWE field names are attributes rather than element text. Preserve
    # keyword evidence from the raw XML as well.
    raw_has_strain="verticalStrain" in xmltext
    raw_has_vstress="verticalStress" in xmltext
    raw_has_eff="verticalEffectiveStress" in xmltext
    unload=any(("ontlast" in x.lower() or "unload" in x.lower()) for x in step_types)
    stress_series=raw_has_vstress or raw_has_eff
    strain_series=raw_has_strain
    nonempty_series=len(values)>0

    if not settlement:
      readiness="R0"
    elif unload and stress_series and strain_series and nonempty_series:
      readiness="R2"
    elif raw_has_eff and strain_series and nonempty_series:
      readiness="R3"
    elif stress_series and strain_series and nonempty_series:
      readiness="R1"
    else:
      readiness="R0"

    return {
      "bro_id":bro_id,
      "readiness":readiness,
      "settlement_determination_count":len(settlement),
      "step_types":step_types,
      "vertical_stress_value_count":len(vertical_stress),
      "vertical_strain_value_count":len(vertical_strain),
      "vertical_effective_stress_value_count":len(eff_stress),
      "pore_pressure_value_count":len(pore),
      "swe_values_block_count":len(values),
      "swe_values_total_chars":sum(len(x) for x in values),
      "raw_has_vertical_strain_field":raw_has_strain,
      "raw_has_vertical_stress_field":raw_has_vstress,
      "raw_has_vertical_effective_stress_field":raw_has_eff,
      "explicit_unload_step":unload,
      "begin_depth_values":begin_depth,
      "end_depth_values":end_depth,
      "sample_moisture_values":moisture,
      "sample_quality_values":quality,
      "volumetric_mass_density_values":density,
      "solids_density_values":solids_density,
      "organic_matter_values":organic,
      "determination_method_values":methods,
    }

def main():
    out=Path(sys.argv[1]); out.mkdir(parents=True,exist_ok=True)
    selected_ids=[]
    selected_radius=None
    search_records=[]
    for radius in RADII_KM:
      body={
        "area":{"enclosingCircle":{"center":CENTER,"radius":radius}},
        "analysisType":ANALYSIS_TYPE,
      }
      payload=json.dumps(body,separators=(",",":"),sort_keys=True).encode()
      url=DEFAULT_BASE.rstrip("/")+"/characteristics/searches"
      status,ctype,data=fetch(url,method="POST",body=payload)
      write_evidence(out,f"search-{str(radius).replace('.','p')}km",url,status,ctype,data,
                     request_body=body,radius_km=radius)
      ids=bro_ids_from_xml(data) if 200<=status<300 else []
      search_records.append({"radius_km":radius,"http_status":status,"bro_ids":ids})
      print(f"F_PE_ELASTIC10B_SEARCH|RADIUS_KM={radius}|STATUS={status}|IDS={len(ids)}")
      if ids:
        selected_radius=radius
        selected_ids=ids[:MAX_OBJECTS]
        break

    summary={"selected_radius_km":selected_radius,"selected_bro_ids":selected_ids,
             "searches":search_records,"objects":[]}
    if selected_radius is None:
      (out/"summary.json").write_text(json.dumps(summary,indent=2,sort_keys=True)+"\n")
      print("F_PE_ELASTIC10B_RESULT=NEGATIVE_NO_OBJECTS")
      return 0

    for bro_id in selected_ids:
      url=DEFAULT_BASE.rstrip("/")+"/objects/"+bro_id
      status,ctype,data=fetch(url)
      safe=re.sub(r"[^A-Za-z0-9_.-]+","_",bro_id)
      write_evidence(out,f"object-{safe}",url,status,ctype,data,bro_id=bro_id)
      if not (200<=status<300):
        rec={"bro_id":bro_id,"readiness":"R0","http_status":status}
      else:
        try:
          rec=audit_object(data,bro_id); rec["http_status"]=status
        except ET.ParseError as e:
          rec={"bro_id":bro_id,"readiness":"R0","http_status":status,"parse_error":str(e)}
      summary["objects"].append(rec)
      print("F_PE_ELASTIC10B_OBJECT="+json.dumps(rec,separators=(",",":"),sort_keys=True))

    (out/"summary.json").write_text(json.dumps(summary,indent=2,sort_keys=True)+"\n")
    ready=[x for x in summary["objects"] if x.get("readiness") in {"R2","R3"}]
    print(f"F_PE_ELASTIC10B_SELECTED_RADIUS_KM={selected_radius}")
    print(f"F_PE_ELASTIC10B_OBJECTS={len(summary['objects'])}")
    print(f"F_PE_ELASTIC10B_TARGET_READY={len(ready)}")
    print("F_PE_ELASTIC10B_RESULT="+("TARGET_READY" if ready else "NEGATIVE_R0_R1_ONLY"))
    return 0

if __name__=="__main__":
    raise SystemExit(main())
