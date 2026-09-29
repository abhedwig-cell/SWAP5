#!/usr/bin/env python3
"""F-PE-ELASTIC10C service-valid 10-km BHR-GT settlement pilot."""
from __future__ import annotations
import hashlib, json, math, re, sys
import xml.etree.ElementTree as ET
from datetime import datetime, timezone
from pathlib import Path

sys.path.insert(0,str(Path(__file__).resolve().parent))
from bro_bhrgt_fetch import fetch, DEFAULT_BASE

CENTER={"lat":52.038297852,"lon":5.31447958948}
RADIUS_KM=10.0
MAX_OBJECTS=5
ANALYSIS_TYPE="zetting"

def local(tag:str)->str:
    return tag.rsplit("}",1)[-1]

def norm(s:str)->str:
    return re.sub(r"[^a-z0-9]+","",s.lower())

def txt(e)->str:
    return (e.text or "").strip()

def manifest(url,status,ctype,data,**extra):
    d={
      "retrieved_utc":datetime.now(timezone.utc).isoformat(),
      "url":url,
      "http_status":status,
      "content_type":ctype,
      "size_bytes":len(data),
      "sha256":hashlib.sha256(data).hexdigest(),
    }
    d.update(extra)
    return d

def write_evidence(root:Path,name:str,url:str,status:int,ctype:str,data:bytes,**extra):
    (root/f"{name}.response").write_bytes(data)
    (root/f"{name}.manifest.json").write_text(
        json.dumps(manifest(url,status,ctype,data,**extra),indent=2,sort_keys=True)+"\n"
    )

def bro_ids_from_xml(data:bytes)->list[str]:
    root=ET.fromstring(data)
    ids={txt(e) for e in root.iter() if local(e.tag).lower()=="broid" and txt(e)}
    return sorted(ids)

def hrefs(elems)->list[str]:
    out=[]
    for e in elems:
        for key,value in e.attrib.items():
            if local(key).lower()=="href":
                out.append(value)
    return out

def elements_named(elems,*names):
    wanted={norm(x) for x in names}
    return [e for e in elems if norm(local(e.tag)) in wanted]

def float_value(text:str):
    try:
        value=float(text)
    except (TypeError,ValueError):
        return None
    return value if math.isfinite(value) else None

def step_type_tokens(step)->list[str]:
    tokens=[]
    for e in elements_named(list(step.iter()),"stepType"):
        if txt(e):
            tokens.append(txt(e))
        for key,value in e.attrib.items():
            if local(key).lower()=="href":
                tokens.append(value.rsplit("/",1)[-1])
    return tokens

def series_info(step, element_name:str, record_suffix:str)->dict:
    blocks=[e for e in step.iter() if norm(local(e.tag))==norm(element_name)]
    record_bound=False
    values=[]
    refs=[]
    for block in blocks:
        elems=list(block.iter())
        refs.extend(hrefs(elems))
        if any(record_suffix in x for x in refs):
            record_bound=True
        values.extend(txt(e) for e in elems if norm(local(e.tag))=="values" and txt(e))
    return {
        "block_count":len(blocks),
        "record_bound":record_bound,
        "values_block_count":len(values),
        "values_total_chars":sum(len(x) for x in values),
        "nonempty":record_bound and bool(values),
        "hrefs":refs,
    }

def audit_step(step,index:int)->dict:
    elems=list(step.iter())
    stress_text=[txt(e) for e in elements_named(elems,"verticalStress") if txt(e)]
    stress=next((v for v in (float_value(x) for x in stress_text) if v is not None),None)
    tokens=step_type_tokens(step)
    unload=any("ontlast" in x.lower() or "unload" in x.lower() for x in tokens)
    height=series_info(step,"heightChangeDuringSettlement","HeightAtSpecificState.xml")
    stress_series=series_info(step,"stressChangeDuringSettlement","StressAtSpecificSettlement.xml")
    return {
        "index":index,
        "step_type_tokens":tokens,
        "explicit_unload":unload,
        "vertical_stress_text":stress_text,
        "vertical_stress_kpa":stress,
        "height_series":height,
        "stress_series":stress_series,
        "endpoint_candidate":stress is not None and height["nonempty"],
        "effective_stress_series_candidate":stress_series["nonempty"],
    }

def audit_settlement(det,index:int)->dict:
    elems=list(det.iter())
    step_nodes=[e for e in elems if norm(local(e.tag))=="determinationstep"]
    steps=[audit_step(e,i+1) for i,e in enumerate(step_nodes)]
    endpoints=[s for s in steps if s["endpoint_candidate"]]
    stresses=[s["vertical_stress_kpa"] for s in endpoints]
    distinct_stresses=sorted(set(stresses))
    unload_endpoints=[s for s in endpoints if s["explicit_unload"]]
    r3_steps=[s for s in steps if s["effective_stress_series_candidate"]]

    if r3_steps:
        readiness="R3"
    elif len(endpoints)>=2 and len(distinct_stresses)>=2 and unload_endpoints:
        readiness="R2"
    elif endpoints or any(s["stress_series"]["nonempty"] for s in steps):
        readiness="R1"
    else:
        readiness="R0"

    return {
        "index":index,
        "readiness":readiness,
        "determination_step_count":len(steps),
        "usable_endpoint_count":len(endpoints),
        "distinct_vertical_stress_count":len(distinct_stresses),
        "distinct_vertical_stress_kpa":distinct_stresses,
        "unload_endpoint_count":len(unload_endpoints),
        "effective_stress_series_step_count":len(r3_steps),
        "steps":steps,
    }

def audit_object(data:bytes,bro_id:str)->dict:
    root=ET.fromstring(data)
    elems=list(root.iter())
    settlement=[
        e for e in elems
        if "settlementcharacteristicsdetermination" in norm(local(e.tag))
    ]
    determinations=[audit_settlement(det,i+1) for i,det in enumerate(settlement)]
    rank={"R0":0,"R1":1,"R2":2,"R3":3}
    readiness=max(
        (d["readiness"] for d in determinations),
        key=lambda x:rank[x],
        default="R0",
    )

    def vals(*names):
        return [txt(e) for e in elements_named(elems,*names) if txt(e)]

    return {
        "bro_id":bro_id,
        "readiness":readiness,
        "settlement_determination_count":len(settlement),
        "determinations":determinations,
        "begin_depth_values":vals("beginDepth","startDepth"),
        "end_depth_values":vals("endDepth"),
        "sample_moisture_values":vals("sampleMoistness"),
        "sample_quality_values":vals("sampleQuality"),
        "volumetric_mass_density_values":vals("volumetricMassDensity"),
        "solids_density_values":vals("volumetricMassDensitySolids"),
        "water_content_values":vals("waterContent"),
        "organic_matter_values":vals("organicMatterContent"),
    }

def main():
    out=Path(sys.argv[1])
    out.mkdir(parents=True,exist_ok=True)

    body={
      "area":{"enclosingCircle":{"center":CENTER,"radius":RADIUS_KM}},
      "analysisType":ANALYSIS_TYPE,
    }
    payload=json.dumps(body,separators=(",",":"),sort_keys=True).encode()
    url=DEFAULT_BASE.rstrip("/")+"/characteristics/searches"
    status,ctype,data=fetch(url,method="POST",body=payload)
    write_evidence(
        out,"search-10p0km",url,status,ctype,data,
        request_body=body,radius_km=RADIUS_KM,
        inherited_empty_searches={
          "0.5km_sha256":"468141a2b713cbc49de8601f4957ffa937da5d144285514a02bb24c691bd2eca",
          "5.0km_sha256":"cf49c38acc348210926b17468af7eb6a6a71a0c95fb3eda2cda07017e8073e72",
        },
    )
    print(f"F_PE_ELASTIC10C_SEARCH|RADIUS_KM={RADIUS_KM}|STATUS={status}")
    if not (200<=status<300):
        print("F_PE_ELASTIC10C_RESULT=SERVICE_ERROR")
        return 2

    try:
        ids=bro_ids_from_xml(data)
    except ET.ParseError as e:
        print("F_PE_ELASTIC10C_RESULT=SEARCH_XML_PARSE_ERROR")
        print("F_PE_ELASTIC10C_PARSE_ERROR="+str(e))
        return 2

    print(f"F_PE_ELASTIC10C_SEARCH_IDS={len(ids)}")
    summary={
      "radius_km":RADIUS_KM,
      "selected_bro_ids":ids[:MAX_OBJECTS],
      "all_returned_bro_id_count":len(ids),
      "objects":[],
    }
    if not ids:
        (out/"summary.json").write_text(json.dumps(summary,indent=2,sort_keys=True)+"\n")
        print("F_PE_ELASTIC10C_RESULT=NEGATIVE_NO_OBJECTS_10KM")
        return 0

    any_fetch_error=False
    for bro_id in ids[:MAX_OBJECTS]:
        object_url=DEFAULT_BASE.rstrip("/")+"/objects/"+bro_id
        ostatus,octype,odata=fetch(object_url)
        safe=re.sub(r"[^A-Za-z0-9_.-]+","_",bro_id)
        write_evidence(out,f"object-{safe}",object_url,ostatus,octype,odata,bro_id=bro_id)
        if not (200<=ostatus<300):
            any_fetch_error=True
            rec={"bro_id":bro_id,"status":"FETCH_ERROR","http_status":ostatus}
        else:
            try:
                rec=audit_object(odata,bro_id)
                rec["http_status"]=ostatus
            except ET.ParseError as e:
                any_fetch_error=True
                rec={"bro_id":bro_id,"status":"XML_PARSE_ERROR","http_status":ostatus,"parse_error":str(e)}
        summary["objects"].append(rec)
        print("F_PE_ELASTIC10C_OBJECT="+json.dumps(rec,separators=(",",":"),sort_keys=True))

    (out/"summary.json").write_text(json.dumps(summary,indent=2,sort_keys=True)+"\n")
    if any_fetch_error:
        print("F_PE_ELASTIC10C_RESULT=INCOMPLETE_OBJECT_FETCH")
        return 2

    ready=[x for x in summary["objects"] if x.get("readiness") in {"R2","R3"}]
    print(f"F_PE_ELASTIC10C_OBJECTS={len(summary['objects'])}")
    print(f"F_PE_ELASTIC10C_TARGET_READY={len(ready)}")
    print("F_PE_ELASTIC10C_RESULT="+("TARGET_READY" if ready else "NEGATIVE_R0_R1_ONLY"))
    return 0

if __name__=="__main__":
    raise SystemExit(main())
