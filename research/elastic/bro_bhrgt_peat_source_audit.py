#!/usr/bin/env python3
"""F-PE-ELASTIC72A bounded BHR-GT peat/high-organic source audit."""
from __future__ import annotations
import argparse, hashlib, json, math, time
from pathlib import Path
from urllib.request import Request, urlopen
from urllib.error import HTTPError, URLError
import xml.etree.ElementTree as ET

BASE="https://publiek.broservices.nl/sr/bhrgt/v2"
QUERY={"area":{"boundingBox":{"lowerCorner":{"lat":50.70,"lon":3.20},
"upperCorner":{"lat":53.60,"lon":7.30}}},"analysisType":"zetting"}
EXPECTED_COUNT=692
EXPECTED_SHA="606a4785a5bea70e443a8729bfd132b9ddebe1ea799e78585ed3ba2f54f54667"
EXCLUDE=set("""
BHR000000339285 BHR000000339288 BHR000000351603
BHR000000424612 BHR000000462723 BHR000000462718 BHR000000380954
BHR000000458789 BHR000000380408 BHR000000365007 BHR000000377189
BHR000000377071 BHR000000369337 BHR000000361974 BHR000000380390
BHR000000374009 BHR000000360500 BHR000000377179 BHR000000470651
BHR000000381747 BHR000000369340
BHR000000450418 BHR000000451425 BHR000000369339 BHR000000354227
BHR000000373650 BHR000000367080 BHR000000354099 BHR000000455524
BHR000000377348 BHR000000362519 BHR000000359907 BHR000000469187
BHR000000365772 BHR000000462578 BHR000000431999 BHR000000448182
BHR000000351990 BHR000000353614 BHR000000380405 BHR000000374026
BHR000000360510 BHR000000467482 BHR000000380370 BHR000000380387
BHR000000469885 BHR000000377198 BHR000000374640 BHR000000376817
BHR000000424423 BHR000000367072 BHR000000469045 BHR000000374977
BHR000000455514 BHR000000458816 BHR000000377048 BHR000000362495
""".split())
FIELDS=("peatType","organicMatterContent","organicMatterContentClass",
"organicMatterContentClassNEN5104","organicSoilTexture","organicSoilConsistency",
"peatTensileStrength","volumetricMassDensity","volumetricMassDensitySolids",
"waterContent","geotechnicalSoilName","soilNameNEN5104")

def local(tag): return tag.rsplit("}",1)[-1]
def fetch(url,method="GET",body=None,attempts=3):
    last=None
    for i in range(attempts):
        req=Request(url,data=body,method=method,headers={
          "User-Agent":"SWAP5-F-PE-ELASTIC72/0.1",
          "Accept":"application/xml, application/json;q=0.9, */*;q=0.1",
          **({"Content-Type":"application/json"} if body else {})})
        try:
            with urlopen(req,timeout=30) as r: return r.read()
        except (HTTPError,URLError) as e:
            last=e
            if i+1<attempts: time.sleep(0.5*(i+1))
    raise RuntimeError(f"fetch failed {url}: {last}")

def sha_list(xs):
    return hashlib.sha256(("\n".join(xs)+"\n").encode()).hexdigest()
def texts(node,name):
    return [(e.text or "").strip() for e in node.iter()
            if local(e.tag)==name and (e.text or "").strip()]
def first_num(vals):
    for v in vals:
        try:
            x=float(v)
            if math.isfinite(x): return x
        except ValueError: pass
    return None
def collect_ids(raw):
    root=ET.fromstring(raw)
    return sorted(set((e.text or "").strip() for e in root.iter()
      if local(e.tag).lower()=="broid" and (e.text or "").strip()))

def settlement_rows(raw,broid):
    root=ET.fromstring(raw); out=[]
    for iv in (e for e in root.iter() if local(e.tag)=="investigatedInterval"):
        names={local(e.tag) for e in iv.iter()}
        if "SettlementCharacteristicsDetermination" not in names: continue
        f={name:texts(iv,name) for name in FIELDS}
        om=first_num(f["organicMatterContent"])
        peat=bool(f["peatType"])
        out.append({"broId":broid,"beginDepth":texts(iv,"beginDepth")[:1],
          "endDepth":texts(iv,"endDepth")[:1],"peat_evidence":peat,
          "high_organic_evidence":(not peat and om is not None and om>15.0),
          "fields":f})
    return out

def main():
    ap=argparse.ArgumentParser(); ap.add_argument("--output",required=True)
    ap.add_argument("--sample-size",type=int,default=160); a=ap.parse_args()
    body=json.dumps(QUERY,separators=(",",":")).encode()
    ids=collect_ids(fetch(BASE+"/characteristics/searches","POST",body))
    pop_sha=sha_list(ids)
    eligible=[x for x in ids if x not in EXCLUDE]
    ranked=sorted(eligible,key=lambda x:
      hashlib.sha256(("F-PE-ELASTIC72A|"+x).encode()).hexdigest())
    sample=ranked[:a.sample_size]; rows=[]
    for i,broid in enumerate(sample,1):
        rows.extend(settlement_rows(fetch(BASE+"/objects/"+broid),broid))
        if i%20==0: print(f"F_PE_ELASTIC72A_FETCHED={i}")
    peat=[r for r in rows if r["peat_evidence"]]
    high=[r for r in rows if r["high_organic_evidence"]]
    peat_objs=sorted({r["broId"] for r in peat})
    high_objs=sorted({r["broId"] for r in high})
    cov={}
    for f in FIELDS:
        n=sum(bool(r["fields"][f]) for r in peat)
        cov[f]={"count":n,"fraction":n/len(peat) if peat else 0.0}
    if len(peat_objs)>=10 and len(peat)>=20:
        route="DIRECT_BHRGT_PEAT_ROUTE_FEASIBLE"
    elif len(peat_objs)>=3 or len(peat)>=5:
        route="DIRECT_BHRGT_PEAT_ROUTE_SPARSE"
    else:
        route="DIRECT_BHRGT_PEAT_ROUTE_INSUFFICIENT"
    structural=max((cov[f]["fraction"] for f in
      ("peatType","organicSoilTexture","organicSoilConsistency")),default=0.0)
    ready=bool(peat) and cov["volumetricMassDensity"]["fraction"]>=0.8 and \
      cov["waterContent"]["fraction"]>=0.8 and structural>=0.8
    payload={"population":{"count":len(ids),"sha256":pop_sha,
      "matches_elastic10":len(ids)==EXPECTED_COUNT and pop_sha==EXPECTED_SHA},
      "excluded_previously_opened":len(EXCLUDE),"eligible_count":len(eligible),
      "discovery_sample":{"count":len(sample),"sha256":sha_list(sample),"ids":sample},
      "preserved_unopened_eligible_count":max(0,len(eligible)-len(sample)),
      "settlement_intervals":len(rows),
      "peat":{"objects":len(peat_objs),"intervals":len(peat),"object_ids":peat_objs},
      "high_organic_nonpeat":{"objects":len(high_objs),"intervals":len(high),
        "object_ids":high_objs},"peat_descriptor_coverage":cov,
      "route_classification":route,
      "descriptor_classification":"PEAT_DESCRIPTOR_READY" if ready else
        "PEAT_DESCRIPTOR_NOT_READY","interval_records":rows}
    Path(a.output).parent.mkdir(parents=True,exist_ok=True)
    Path(a.output).write_text(json.dumps(payload,indent=2)+"\n")
    print("F_PE_ELASTIC72A_POP="+json.dumps(payload["population"],sort_keys=True))
    print("F_PE_ELASTIC72A_PEAT_OBJECTS="+str(len(peat_objs)))
    print("F_PE_ELASTIC72A_PEAT_INTERVALS="+str(len(peat)))
    print("F_PE_ELASTIC72A_HIGH_ORG_INTERVALS="+str(len(high)))
    print("F_PE_ELASTIC72A_ROUTE="+route)
    print("F_PE_ELASTIC72A_DESCRIPTOR="+payload["descriptor_classification"])
    print("F_PE_ELASTIC72A=PASS")
if __name__=="__main__": raise SystemExit(main())
