#!/usr/bin/env python3
"""F-PE-ELASTIC10D fixed 12-cell Dutch BHR-GT settlement discovery."""
from __future__ import annotations
import json, re, sys
import xml.etree.ElementTree as ET
from pathlib import Path

sys.path.insert(0,str(Path(__file__).resolve().parent))
from bro_bhrgt_fetch import fetch, DEFAULT_BASE
from run_bhrgt_settlement_pilot10 import write_evidence, bro_ids_from_xml, audit_object

RADIUS_KM=10.0
ANALYSIS_TYPE="zetting"
MAX_PER_CELL=2

CENTERS=(
    ("wageningen",51.97,5.67),
    ("utrecht",52.09,5.12),
    ("zwolle",52.52,6.09),
    ("assen",52.99,6.56),
    ("leeuwarden",53.20,5.80),
    ("alkmaar",52.63,4.75),
    ("rotterdam",51.92,4.48),
    ("breda",51.59,4.78),
    ("eindhoven",51.44,5.48),
    ("venlo",51.37,6.17),
    ("arnhem",51.98,5.91),
    ("lelystad",52.52,5.47),
)

def safe_name(s:str)->str:
    return re.sub(r"[^A-Za-z0-9_.-]+","_",s)

def main():
    out=Path(sys.argv[1])
    out.mkdir(parents=True,exist_ok=True)

    searches=[]
    cell_ids={}
    search_incomplete=False
    all_ids=set()

    url=DEFAULT_BASE.rstrip("/")+"/characteristics/searches"

    for name,lat,lon in CENTERS:
        body={
          "area":{"enclosingCircle":{"center":{"lat":lat,"lon":lon},"radius":RADIUS_KM}},
          "analysisType":ANALYSIS_TYPE,
        }
        payload=json.dumps(body,separators=(",",":"),sort_keys=True).encode()
        status,ctype,data=fetch(url,method="POST",body=payload)
        write_evidence(
            out,f"search-{name}",url,status,ctype,data,
            request_body=body,cell=name,radius_km=RADIUS_KM,
        )
        rec={"cell":name,"lat":lat,"lon":lon,"http_status":status,"bro_ids":[]}
        if not (200<=status<300):
            search_incomplete=True
            rec["error"]="HTTP_ERROR"
        else:
            try:
                ids=bro_ids_from_xml(data)
                rec["bro_ids"]=ids
                cell_ids[name]=ids
                all_ids.update(ids)
            except ET.ParseError as e:
                search_incomplete=True
                rec["error"]="XML_PARSE_ERROR"
                rec["parse_error"]=str(e)
        searches.append(rec)
        print(f"F_PE_ELASTIC10D_SEARCH|CELL={name}|STATUS={status}|IDS={len(rec['bro_ids'])}")

    summary={
      "radius_km":RADIUS_KM,
      "analysis_type":ANALYSIS_TYPE,
      "centers":[{"name":n,"lat":a,"lon":b} for n,a,b in CENTERS],
      "searches":searches,
      "all_returned_unique_bro_id_count":len(all_ids),
      "selected_objects":[],
      "objects":[],
    }

    if search_incomplete:
        (out/"summary.json").write_text(json.dumps(summary,indent=2,sort_keys=True)+"\n")
        print("F_PE_ELASTIC10D_RESULT=INCOMPLETE_SEARCH")
        return 2

    owned=set()
    selections=[]
    for name,_,_ in CENTERS:
        ids=cell_ids.get(name,[])
        for bro_id in ids[:MAX_PER_CELL]:
            if bro_id in owned:
                print(f"F_PE_ELASTIC10D_DUPLICATE_SKIP|CELL={name}|BRO_ID={bro_id}")
                continue
            owned.add(bro_id)
            selections.append({"bro_id":bro_id,"owning_cell":name})

    summary["selected_objects"]=selections

    if not selections:
        (out/"summary.json").write_text(json.dumps(summary,indent=2,sort_keys=True)+"\n")
        print("F_PE_ELASTIC10D_CELLS=12")
        print("F_PE_ELASTIC10D_UNIQUE_IDS=0")
        print("F_PE_ELASTIC10D_RESULT=NATIONAL_GRID_NO_OBJECTS")
        return 0

    fetch_incomplete=False
    for sel in selections:
        bro_id=sel["bro_id"]
        cell=sel["owning_cell"]
        object_url=DEFAULT_BASE.rstrip("/")+"/objects/"+bro_id
        status,ctype,data=fetch(object_url)
        safe=safe_name(bro_id)
        write_evidence(
            out,f"object-{safe}",object_url,status,ctype,data,
            bro_id=bro_id,owning_cell=cell,
        )
        if not (200<=status<300):
            fetch_incomplete=True
            rec={"bro_id":bro_id,"owning_cell":cell,"http_status":status,"status":"FETCH_ERROR"}
        else:
            try:
                rec=audit_object(data,bro_id)
                rec["owning_cell"]=cell
                rec["http_status"]=status
            except ET.ParseError as e:
                fetch_incomplete=True
                rec={
                  "bro_id":bro_id,"owning_cell":cell,"http_status":status,
                  "status":"XML_PARSE_ERROR","parse_error":str(e),
                }
        summary["objects"].append(rec)
        print("F_PE_ELASTIC10D_OBJECT="+json.dumps(rec,separators=(",",":"),sort_keys=True))

    (out/"summary.json").write_text(json.dumps(summary,indent=2,sort_keys=True)+"\n")

    if fetch_incomplete:
        print("F_PE_ELASTIC10D_RESULT=INCOMPLETE_OBJECT_FETCH")
        return 2

    ready=[x for x in summary["objects"] if x.get("readiness") in {"R2","R3"}]
    print("F_PE_ELASTIC10D_CELLS=12")
    print(f"F_PE_ELASTIC10D_UNIQUE_IDS={len(all_ids)}")
    print(f"F_PE_ELASTIC10D_SELECTED_OBJECTS={len(selections)}")
    print(f"F_PE_ELASTIC10D_TARGET_READY={len(ready)}")
    if ready:
        print("F_PE_ELASTIC10D_RESULT=TARGET_READY")
    else:
        print("F_PE_ELASTIC10D_RESULT=COVERAGE_PRESENT_R0_R1_ONLY")
    return 0

if __name__=="__main__":
    raise SystemExit(main())
