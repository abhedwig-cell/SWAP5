#!/usr/bin/env python3
from __future__ import annotations
import hashlib, json, sys, time
import xml.etree.ElementTree as ET
from pathlib import Path
from urllib.request import Request,urlopen
from urllib.error import URLError,HTTPError

UA="SWAP5-F-PE-ELASTIC11A/0.1"
URLS=[
 "http://schema.broservices.nl/xsd/bhrgtcommon/2.0/HeightAtSpecificState.xml",
 "http://schema.broservices.nl/xsd/bhrgtcommon/2.0/StressAtSpecificSettlement.xml",
]

def local(t): return t.rsplit("}",1)[-1]

def fetch(url):
    attempts=[url]
    if url.startswith("http://"): attempts.append("https://"+url[len("http://"):])
    last=None
    for u in attempts:
        try:
            with urlopen(Request(u,headers={"User-Agent":UA}),timeout=30) as r:
                return u,int(r.status),r.headers.get("Content-Type",""),r.read()
        except (URLError,HTTPError) as e:
            last=e
    raise RuntimeError(f"schema fetch failed {url}: {last}")

def parse_schema(data):
    root=ET.fromstring(data)
    fields=[]
    for f in root.iter():
        if local(f.tag)!="field": continue
        rec={"name":f.attrib.get("name","")}
        for e in f.iter():
            ln=local(e.tag)
            if ln in {"Time","Quantity","Count","Text"}:
                rec["type"]=ln
                for k,v in e.attrib.items(): rec[local(k)]=v
            elif ln=="uom":
                for k,v in e.attrib.items(): rec["uom_"+local(k)]=v
        fields.append(rec)
    return fields

def main():
    out=Path(sys.argv[1]); out.mkdir(parents=True,exist_ok=True)
    summary=[]
    for url in URLS:
        final,status,ctype,data=fetch(url)
        name=url.rsplit("/",1)[-1]
        (out/name).write_bytes(data)
        fields=parse_schema(data)
        rec={
          "name":name,"requested_url":url,"final_url":final,"http_status":status,
          "content_type":ctype,"bytes":len(data),
          "sha256":hashlib.sha256(data).hexdigest(),"fields":fields,
        }
        (out/(name+".json")).write_text(json.dumps(rec,indent=2,sort_keys=True)+"\n")
        summary.append(rec)
        print("F_PE_ELASTIC11A_SCHEMA="+json.dumps(rec,separators=(",",":"),sort_keys=True))
    if len(summary)!=2 or any(not x["fields"] for x in summary):
        raise SystemExit("F_PE_ELASTIC11A_FAIL=missing_fields")
    (out/"summary.json").write_text(json.dumps(summary,indent=2,sort_keys=True)+"\n")
    print("F_PE_ELASTIC11A_SCHEMA_BINDING=PASS")

if __name__=="__main__": raise SystemExit(main())
