#!/usr/bin/env python3
"""F-PE-ELASTIC10B frozen BHR-GT settlement-object pilot."""
from __future__ import annotations
import argparse, hashlib, json, re
from pathlib import Path
import xml.etree.ElementTree as ET
from bro_bhrgt_fetch import DEFAULT_BASE, fetch, manifest

QUERY={
  "area":{
    "boundingBox":{
      "lowerCorner":{"lat":50.70,"lon":3.20},
      "upperCorner":{"lat":53.60,"lon":7.30}
    }
  },
  "analysisType":"zetting"
}
TARGET_TAGS={
 "SettlementCharacteristicsDetermination","stepType","verticalStress",
 "heightChangeDuringSettlement","verticalStrain","verticalEffectiveStress",
 "verticalGrainStress","effectivePressure","elapsedTime","time",
 "volumetricMassDensity","volumetricMassDensitySolids","waterContent",
 "organicMatterContent","startDepth","endDepth","samplingQuality",
 "determinationMethod","determinationProcedure"
}

def local(tag:str)->str:
    return tag.rsplit("}",1)[-1]

def save(root:Path,name:str,url:str,status:int,ctype:str,data:bytes):
    p=root/name
    p.write_bytes(data)
    m=manifest(url,status,ctype,data)
    (root/(name+".manifest.json")).write_text(json.dumps(m,indent=2)+"\n")
    return m

def xml_values(root):
    vals={}
    for e in root.iter():
        k=local(e.tag)
        t=(e.text or "").strip()
        if t:
            vals.setdefault(k,[]).append(t)
    return vals

def dataarrays(root):
    out=[]
    for i,da in enumerate(e for e in root.iter() if local(e.tag)=="DataArray"):
        fields=[]; units=[]; values_len=0; count=None
        for e in da.iter():
            k=local(e.tag)
            if k=="field" and e.attrib.get("name"):
                fields.append(e.attrib["name"])
            if k=="uom" and e.attrib.get("code"):
                units.append(e.attrib["code"])
            if k.lower() in {"elementcount","count"} and (e.text or "").strip():
                count=(e.text or "").strip()
            if k.lower()=="values" and (e.text or "").strip():
                values_len=len((e.text or "").strip())
        out.append({"index":i,"fields":fields,"units":units,"count":count,"values_length":values_len})
    return out

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--output-dir",required=True)
    ap.add_argument("--base",default=DEFAULT_BASE)
    a=ap.parse_args()
    root=Path(a.output_dir); root.mkdir(parents=True,exist_ok=True)

    body=json.dumps(QUERY,separators=(",",":")).encode()
    search_url=a.base.rstrip("/")+"/characteristics/searches"
    status,ctype,data=fetch(search_url,method="POST",body=body)
    sm=save(root,"search.xml",search_url,status,ctype,data)
    print("F_PE_ELASTIC10B_SEARCH|"+ "|".join(f"{k}={v}" for k,v in sm.items()))
    if not (200<=status<300):
        raise SystemExit("F_PE_ELASTIC10B_FAIL search HTTP")

    x=ET.fromstring(data)
    ids=sorted(set(
        (e.text or "").strip() for e in x.iter()
        if local(e.tag).lower()=="broid" and (e.text or "").strip()
    ))
    print("F_PE_ELASTIC10B_IDS="+json.dumps(ids[:20]))
    print(f"F_PE_ELASTIC10B_ID_COUNT={len(ids)}")
    if not ids:
        print("F_PE_ELASTIC10B_CLASS=NO_OBJECTS_FOR_FROZEN_QUERY")
        return 0

    selected=ids[:3]
    if len(selected)<3:
        print("F_PE_ELASTIC10B_COVERAGE=LOW_COVERAGE")
    print("F_PE_ELASTIC10B_SELECTED="+json.dumps(selected))

    summaries=[]
    confirmed=False
    for broid in selected:
        url=a.base.rstrip("/")+"/objects/"+broid
        st,ct,b=fetch(url)
        m=save(root,f"{broid}.xml",url,st,ct,b)
        if not (200<=st<300):
            raise SystemExit(f"F_PE_ELASTIC10B_FAIL object HTTP {broid}")
        xr=ET.fromstring(b)
        vals=xml_values(xr)
        names={local(e.tag) for e in xr.iter()}
        target={k:vals.get(k,[])[:20] for k in sorted(TARGET_TAGS) if k in names or k in vals}
        arrays=dataarrays(xr)
        settlement="SettlementCharacteristicsDetermination" in names
        has_step=bool(vals.get("stepType"))
        has_stress=bool(vals.get("verticalStress"))
        has_response=("heightChangeDuringSettlement" in names) or bool(vals.get("verticalStrain"))
        eff=bool(vals.get("verticalEffectiveStress") or vals.get("verticalGrainStress") or vals.get("effectivePressure"))
        if settlement and ((has_step and has_stress and has_response) or (eff and has_response)):
            confirmed=True
        s={
          "broId":broid,"manifest":m,"settlement":settlement,
          "has_step":has_step,"has_vertical_stress":has_stress,
          "has_response":has_response,"has_effective_stress":eff,
          "target_values":target,"dataarrays":arrays
        }
        summaries.append(s)
        print("F_PE_ELASTIC10B_OBJECT="+json.dumps(s,separators=(",",":"),sort_keys=True))

    (root/"pilot-summary.json").write_text(json.dumps({
      "query":QUERY,"selected":selected,"objects":summaries
    },indent=2)+"\n")

    if confirmed:
        cls="TARGET_PATH_CONFIRMED"
    elif any(s["settlement"] for s in summaries):
        cls="TARGET_PATH_PARTIAL"
    else:
        cls="TARGET_PATH_NOT_POPULATED"
    print("F_PE_ELASTIC10B_CLASS="+cls)
    print("F_PE_ELASTIC10B=PASS")

if __name__=="__main__":
    raise SystemExit(main())
