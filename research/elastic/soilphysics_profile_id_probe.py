#!/usr/bin/env python3
"""F-PE-ELASTIC12A2: bounded WUR soil-profile direct-ID route probe."""
from __future__ import annotations
import argparse, hashlib, json, math, urllib.parse, urllib.request
from pathlib import Path

BASE="https://www.soilphysics.wur.nl/soil.php"
CANDIDATES=("id","iprofile","profile","normalsoilprofile_id")

def fetch(params):
    url=BASE+"?"+urllib.parse.urlencode(params)
    req=urllib.request.Request(url,headers={"User-Agent":"SWAP5-F-PE-ELASTIC12A2/1.0"})
    try:
        with urllib.request.urlopen(req,timeout=60) as r:
            data=r.read()
            return url,r.status,r.headers.get("Content-Type",""),data
    except Exception as e:
        return url,getattr(e,"code",None),str(e),b""

def sha(data): return hashlib.sha256(data).hexdigest()

def parse(data):
    try:
        x=json.loads(data.decode("utf-8"))
        return x if isinstance(x,dict) else None
    except Exception:
        return None

def valid_profile(x,expected_id):
    if not isinstance(x,dict) or x.get("id")!=expected_id:
        return False
    h=x.get("horizon")
    if not isinstance(h,list) or not h:
        return False
    for row in h:
        try:
            d=float(row.get("density"))
        except Exception:
            continue
        if math.isfinite(d) and d>0 and isinstance(row.get("spu"),str) and row["spu"]:
            return True
    return False

def record(url,status,ctype,data,obj):
    return {
      "url":url,"http_status":status,"content_type":ctype,"bytes":len(data),"sha256":sha(data),
      "json_object":isinstance(obj,dict),
      "keys":sorted(obj.keys()) if isinstance(obj,dict) else [],
      "returned_id":obj.get("id") if isinstance(obj,dict) else None,
      "horizon_count":len(obj.get("horizon",[])) if isinstance(obj,dict) and isinstance(obj.get("horizon"),list) else 0,
    }

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--output",required=True)
    a=ap.parse_args()

    url,status,ctype,data=fetch({"latitude":52,"longitude":5})
    obj=parse(data)
    if not isinstance(obj,dict) or not isinstance(obj.get("id"),int):
        raise SystemExit("F_PE_ELASTIC12A2_FAIL documented coordinate route")
    expected=obj["id"]
    documented=record(url,status,ctype,data,obj)
    print("F_PE_ELASTIC12A2_DOCUMENTED="+json.dumps(documented,separators=(",",":"),sort_keys=True))

    probes=[]
    winners=[]
    for name in CANDIDATES:
        url,status,ctype,data=fetch({name:expected})
        x=parse(data)
        rec=record(url,status,ctype,data,x)
        rec["parameter"]=name
        rec["accepted"]=valid_profile(x,expected)
        probes.append(rec)
        if rec["accepted"]: winners.append(name)
        print("F_PE_ELASTIC12A2_PROBE="+json.dumps(rec,separators=(",",":"),sort_keys=True))

    classification="DIRECT_PROFILE_ID_ROUTE_CONFIRMED" if winners else "NO_DIRECT_PROFILE_ID_ROUTE_CONFIRMED"
    result={"documented":documented,"expected_id":expected,"probes":probes,"accepted_parameters":winners,"classification":classification}
    Path(a.output).write_text(json.dumps(result,indent=2)+"\n")
    print("F_PE_ELASTIC12A2_CLASSIFICATION="+classification)
    print("F_PE_ELASTIC12A2=PASS")

if __name__=="__main__":
    raise SystemExit(main())
