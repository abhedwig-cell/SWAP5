#!/usr/bin/env python3
"""F-PE-ELASTIC12A: official BOFEK/Staringreeks source acquisition and schema audit."""
from __future__ import annotations
import argparse, csv, hashlib, io, json, time, urllib.request, zipfile
from pathlib import Path

URLS={
 "bofek":"https://nhi.nu/documents/225/bofek_1.0.0.zip",
 "staring":"https://nhi.nu/documents/224/staringreeks_1.0.0.zip",
}
EXPECTED_STARING_MEMBER="staringreeks/Data/staringreeks_2018.csv"
EXPECTED_STARING_HEADER=["year","unit","name","wcr","wcs","alpha","npar","lambda","ksfit"]

def fetch(url:str)->bytes:
    req=urllib.request.Request(url,headers={"User-Agent":"SWAP5-F-PE-ELASTIC12/1.0"})
    with urllib.request.urlopen(req,timeout=90) as r:
        return r.read()

def sha(data:bytes)->str:
    return hashlib.sha256(data).hexdigest()

def decode_text(data:bytes):
    for enc in ("utf-8-sig","utf-8","cp1252","latin1"):
        try:
            return data.decode(enc)
        except UnicodeDecodeError:
            pass
    return None

def sniff_csv(name:str,data:bytes):
    text=decode_text(data)
    if text is None:
        return None
    lines=[x for x in text.splitlines() if x.strip()]
    if not lines:
        return None
    head=lines[0]
    delimiter=";" if head.count(";")>head.count(",") else ","
    try:
        row=next(csv.reader([head],delimiter=delimiter))
    except Exception:
        return None
    cols=[x.strip() for x in row]
    low=[x.lower() for x in cols]
    terms=("density","dichtheid","bouwsteen","staring","spu","bulk","profiel","profile","horizon","laag","layer")
    relevant=any(any(t in c for t in terms) for c in low)
    return {"name":name,"delimiter":delimiter,"columns":cols,"relevant":relevant,"rows_estimate":max(0,len(lines)-1)}

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--output-dir",required=True)
    a=ap.parse_args()
    out=Path(a.output_dir); out.mkdir(parents=True,exist_ok=True)
    result={"retrieved_utc":time.strftime("%Y-%m-%dT%H:%M:%SZ",time.gmtime()),"sources":{}}

    archives={}
    for key,url in URLS.items():
        data=fetch(url)
        path=out/f"{key}.zip"
        path.write_bytes(data)
        meta={"url":url,"bytes":len(data),"sha256":sha(data)}
        result["sources"][key]=meta
        archives[key]=data
        print("F_PE_ELASTIC12_SOURCE="+json.dumps({"key":key,**meta},separators=(",",":"),sort_keys=True))

    with zipfile.ZipFile(io.BytesIO(archives["staring"])) as z:
        names=z.namelist()
        if EXPECTED_STARING_MEMBER not in names:
            raise SystemExit("F_PE_ELASTIC12A_FAIL exact Staringreeks 2018 member missing")
        raw=z.read(EXPECTED_STARING_MEMBER)
        text=decode_text(raw)
        rows=list(csv.reader(text.splitlines()))
        if rows[0]!=EXPECTED_STARING_HEADER:
            raise SystemExit("F_PE_ELASTIC12A_FAIL Staringreeks header drift")
        data_rows=[r for r in rows[1:] if r]
        units=[r[2] for r in data_rows]
        expected=[f"B{i:02d}" for i in range(1,19)]+[f"O{i:02d}" for i in range(1,19)]
        if len(data_rows)!=36 or units!=expected:
            raise SystemExit("F_PE_ELASTIC12A_FAIL Staringreeks material set drift")
        result["staringreeks_2018"]={
          "member":EXPECTED_STARING_MEMBER,
          "bytes":len(raw),"sha256":sha(raw),"header":rows[0],"rows":len(data_rows),"units":units,
        }

    with zipfile.ZipFile(io.BytesIO(archives["bofek"])) as z:
        members=[]
        candidates=[]
        for info in z.infolist():
            if info.is_dir():
                continue
            rec={"name":info.filename,"bytes":info.file_size}
            if info.file_size<=20_000_000 and info.filename.lower().endswith((".csv",".txt",".tsv",".dat")):
                raw=z.read(info.filename)
                rec["sha256"]=sha(raw)
                scan=sniff_csv(info.filename,raw)
                if scan:
                    rec["table"]=scan
                    if scan["relevant"]:
                        candidates.append(scan)
            members.append(rec)
        result["bofek_archive"]={"members":members,"candidate_tables":candidates}
        print("F_PE_ELASTIC12A_BOFEK_CANDIDATES="+json.dumps(candidates,separators=(",",":"),sort_keys=True))

    (out/"source-audit.json").write_text(json.dumps(result,indent=2)+"\n")
    if not result["bofek_archive"]["candidate_tables"]:
        print("F_PE_ELASTIC12A_CLASSIFICATION=TRANSFER_SOURCE_INCOMPLETE")
    else:
        print("F_PE_ELASTIC12A_CLASSIFICATION=SOURCE_TABLE_CANDIDATES_IDENTIFIED")
    print("F_PE_ELASTIC12A=PASS")

if __name__=="__main__":
    raise SystemExit(main())
