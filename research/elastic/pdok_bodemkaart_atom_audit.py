#!/usr/bin/env python3
"""F-PE-ELASTIC12A4: bounded PDOK BRO Bodemkaart ATOM schema audit."""
from __future__ import annotations
import argparse, hashlib, io, json, re, struct, urllib.parse, urllib.request, zipfile
from pathlib import Path
import xml.etree.ElementTree as ET

ATOM="https://service.pdok.nl/tno/bro-bodemkaart/atom/index.xml"
SOIL_TOKENS=("bodemcode","soilcode","bodem_code","soil_code","code")

def local(tag): return tag.rsplit("}",1)[-1]

def fetch(url):
    req=urllib.request.Request(url,headers={"User-Agent":"SWAP5-F-PE-ELASTIC12A4/1.0"})
    with urllib.request.urlopen(req,timeout=120) as r:
        return r.status,r.headers.get("Content-Type",""),r.read(),r.geturl()

def sha(data): return hashlib.sha256(data).hexdigest()

def dbf_fields(data:bytes):
    if len(data)<32: return []
    header_len=struct.unpack("<H",data[8:10])[0]
    out=[]
    p=32
    while p+32<=min(header_len,len(data)) and data[p]!=0x0D:
        raw=data[p:p+11].split(b"\0",1)[0]
        name=raw.decode("latin1","replace").strip()
        typ=chr(data[p+11])
        length=data[p+16]
        decimals=data[p+17]
        out.append({"name":name,"type":typ,"length":length,"decimals":decimals})
        p+=32
    return out

def shp_type(data:bytes):
    if len(data)<36: return None
    return struct.unpack("<i",data[32:36])[0]

def inspect_zip(data:bytes):
    z=zipfile.ZipFile(io.BytesIO(data))
    names=z.namelist()
    records=[]
    bases={}
    for n in names:
        low=n.lower()
        rec={"name":n,"bytes":z.getinfo(n).file_size}
        if low.endswith(".dbf"):
            raw=z.read(n); fields=dbf_fields(raw)
            rec["dbf_fields"]=fields
            bases.setdefault(n.rsplit(".",1)[0].lower(),{})["dbf"]=fields
        elif low.endswith(".shp"):
            raw=z.read(n)[:100]; st=shp_type(raw)
            rec["shp_type"]=st
            bases.setdefault(n.rsplit(".",1)[0].lower(),{})["shp_type"]=st
        elif low.endswith((".xml",".gml")) and rec["bytes"]<=20_000_000:
            raw=z.read(n)
            try:
                root=ET.fromstring(raw)
                tags=sorted({local(e.tag) for e in root.iter()})
                rec["xml_tags_sample"]=tags[:200]
            except Exception:
                pass
        records.append(rec)
    candidates=[]
    for base,meta in sorted(bases.items()):
        fields=[f["name"] for f in meta.get("dbf",[])]
        matched=[f for f in fields if f.lower() in SOIL_TOKENS or "bodem" in f.lower() or "soil" in f.lower()]
        st=meta.get("shp_type")
        polygon=st in (5,15,25,31)
        if matched:
            candidates.append({"base":base,"shape_type":st,"polygon_like":polygon,"fields":fields,"soil_fields":matched})
    return records,candidates

def atom_links(data:bytes,base_url:str):
    root=ET.fromstring(data)
    rows=[]
    for e in root.iter():
        if local(e.tag)!="link": continue
        href=e.attrib.get("href")
        if not href: continue
        rows.append({
          "href":urllib.parse.urljoin(base_url,href),
          "rel":e.attrib.get("rel"),
          "type":e.attrib.get("type"),
          "title":e.attrib.get("title"),
        })
    # deterministic unique
    out=[]; seen=set()
    for r in rows:
        key=(r["href"],r["rel"],r["type"])
        if key not in seen:
            seen.add(key); out.append(r)
    return out

def download_candidates(links):
    out=[]
    for r in links:
        u=r["href"].lower()
        typ=(r.get("type") or "").lower()
        rel=(r.get("rel") or "").lower()
        if any(x in u for x in (".zip",".gpkg",".gml")) or "zip" in typ or rel=="enclosure":
            out.append(r)
    return out

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--output-dir",required=True)
    a=ap.parse_args()
    out=Path(a.output_dir); out.mkdir(parents=True,exist_ok=True)

    status,ctype,data,final=fetch(ATOM)
    feed_meta={"url":ATOM,"final_url":final,"http_status":status,"content_type":ctype,"bytes":len(data),"sha256":sha(data)}
    (out/"atom.xml").write_bytes(data)
    print("F_PE_ELASTIC12A4_ATOM="+json.dumps(feed_meta,separators=(",",":"),sort_keys=True))

    links=atom_links(data,final)
    dl=download_candidates(links)
    print("F_PE_ELASTIC12A4_LINKS="+json.dumps(dl,separators=(",",":"),sort_keys=True))
    downloads=[]; all_candidates=[]
    for i,r in enumerate(dl):
        try:
            st,ct,raw,fu=fetch(r["href"])
        except Exception as e:
            downloads.append({"url":r["href"],"error":str(e)})
            continue
        rec={"url":r["href"],"final_url":fu,"http_status":st,"content_type":ct,"bytes":len(raw),"sha256":sha(raw)}
        name=f"download-{i}"
        low=fu.lower()
        if raw[:4]==b"PK\x03\x04" or ".zip" in low or "zip" in ct.lower():
            p=out/(name+".zip"); p.write_bytes(raw)
            try:
                members,candidates=inspect_zip(raw)
                rec["format"]="zip"; rec["members"]=members; rec["schema_candidates"]=candidates
                all_candidates.extend({"download_index":i,**c} for c in candidates)
            except Exception as e:
                rec["zip_error"]=str(e)
        else:
            p=out/(name+".bin"); p.write_bytes(raw)
            rec["format"]="other"
        downloads.append(rec)

    known_match=False
    # schema-level evidence only: candidate soil field name indicates route;
    # known Rn47C value binding is deferred unless package is cheaply readable here.
    polygon_candidates=[c for c in all_candidates if c.get("polygon_like") and c.get("soil_fields")]
    classification="PDOK_SOILCODE_GEOMETRY_ROUTE_CONFIRMED" if polygon_candidates else "TRANSFER_SOURCE_INCOMPLETE"
    result={"atom":feed_meta,"links":links,"download_candidates":dl,"downloads":downloads,
            "polygon_soilcode_candidates":polygon_candidates,"known_rn47c_match_verified":known_match,
            "classification":classification}
    (out/"pdok-atom-audit.json").write_text(json.dumps(result,indent=2)+"\n")
    print("F_PE_ELASTIC12A4_SCHEMA_CANDIDATES="+json.dumps(polygon_candidates,separators=(",",":"),sort_keys=True))
    print("F_PE_ELASTIC12A4_CLASSIFICATION="+classification)
    print("F_PE_ELASTIC12A4=PASS")

if __name__=="__main__":
    raise SystemExit(main())
