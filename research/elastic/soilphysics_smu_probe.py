#!/usr/bin/env python3
"""F-PE-ELASTIC12A3: bounded direct soil-map-unit route probe."""
from __future__ import annotations
import argparse, hashlib, json, math, urllib.parse, urllib.request
from pathlib import Path

BASE="https://www.soilphysics.wur.nl/soil.php"
EXPECTED_ID=16160
EXPECTED_SMU="Rn47C"
CANDIDATES=(("smu",EXPECTED_SMU),("bodemcode",EXPECTED_SMU))

def fetch(params):
    url=BASE+"?"+urllib.parse.urlencode(params)
    req=urllib.request.Request(url,headers={"User-Agent":"SWAP5-F-PE-ELASTIC12A3/1.0"})
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

def accepted(x):
    if not isinstance(x,dict) or x.get("id")!=EXPECTED_ID or x.get("smu")!=EXPECTED_SMU:
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

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--output",required=True)
    a=ap.parse_args()
    probes=[]; winners=[]
    for key,val in CANDIDATES:
        url,status,ctype,data=fetch({key:val})
        obj=parse(data)
        rec={
          "parameter":key,"url":url,"http_status":status,"content_type":ctype,
          "bytes":len(data),"sha256":sha(data),
          "json_object":isinstance(obj,dict),
          "keys":sorted(obj.keys()) if isinstance(obj,dict) else [],
          "returned_id":obj.get("id") if isinstance(obj,dict) else None,
          "returned_smu":obj.get("smu") if isinstance(obj,dict) else None,
          "horizon_count":len(obj.get("horizon",[])) if isinstance(obj,dict) and isinstance(obj.get("horizon"),list) else 0,
          "accepted":accepted(obj),
        }
        probes.append(rec)
        if rec["accepted"]: winners.append(key)
        print("F_PE_ELASTIC12A3_PROBE="+json.dumps(rec,separators=(",",":"),sort_keys=True))
    classification="DIRECT_SMU_ROUTE_CONFIRMED" if winners else "NO_DIRECT_SMU_ROUTE_CONFIRMED"
    Path(a.output).write_text(json.dumps({"probes":probes,"accepted_parameters":winners,"classification":classification},indent=2)+"\n")
    print("F_PE_ELASTIC12A3_CLASSIFICATION="+classification)
    print("F_PE_ELASTIC12A3=PASS")

if __name__=="__main__":
    raise SystemExit(main())
