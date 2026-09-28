#!/usr/bin/env python3
"""Parse BRO BHR-P hydrophysical observations without depending on XML prefixes."""
from __future__ import annotations
import argparse,csv,json,xml.etree.ElementTree as ET
from pathlib import Path

def local(tag): return tag.rsplit('}',1)[-1]

def descendants_text(node):
    return [(local(e.tag),(e.text or '').strip(),dict(e.attrib)) for e in node.iter() if (e.text or '').strip()]

def main():
    ap=argparse.ArgumentParser(); ap.add_argument("xml"); ap.add_argument("--json-out"); ap.add_argument("--csv-out")
    a=ap.parse_args(); root=ET.fromstring(Path(a.xml).read_bytes())
    broid=next(((e.text or '').strip() for e in root.iter() if local(e.tag)=="broId"),None)
    intervals=[]
    for iv in root.iter():
        if local(iv.tag)!="InvestigatedInterval": continue
        fields=descendants_text(iv)
        begin=next((v for k,v,_ in fields if k=="beginDepth"),None)
        end=next((v for k,v,_ in fields if k=="endDepth"),None)
        modelled=next((v for k,v,_ in fields if k=="characteristicModelled"),None)
        arrays=[]
        for da in iv.iter():
            if local(da.tag)!="DataArray": continue
            names=[]
            element_type=None
            element_href=None
            encoding={}
            for e in da.iter():
                if local(e.tag) in ("field","component") and "name" in e.attrib: names.append(e.attrib["name"])
                if local(e.tag)=="elementType":
                    element_type=e.attrib.get("name")
                    element_href=next((v for k,v in e.attrib.items() if local(k)=="href"),None)
                if local(e.tag)=="TextEncoding":
                    encoding={local(k):v for k,v in e.attrib.items()}
            values=next(((e.text or '').strip() for e in da.iter() if local(e.tag)=="values"),"")
            arrays.append({"names":names,"element_type":element_type,"element_href":element_href,"encoding":encoding,"values":values})
        intervals.append({"begin_depth":begin,"end_depth":end,"characteristic_modelled":modelled,"arrays":arrays,"fields":fields})
    out={"bro_id":broid,"intervals":intervals}
    if a.json_out: Path(a.json_out).write_text(json.dumps(out,indent=2)+"\n")
    # Generic extraction: rows from arrays whose declared names mention the three hydraulic quantities.
    rows=[]
    for j,iv in enumerate(intervals):
        for ar in iv["arrays"]:
            names=ar["names"]
            et=(ar.get("element_type") or "")
            low=[n.lower() for n in names]+[et.lower()]
            if not any("water" in n or "hydraulic" in n or "conduct" in n or "potential" in n or "retention" in n for n in low): continue
            rows.append({"interval":j,"begin_depth":iv["begin_depth"],"end_depth":iv["end_depth"],"names":"|".join(names),"element_type":et,"values":ar["values"]})
    if a.csv_out:
        with open(a.csv_out,"w",newline="") as f:
            w=csv.DictWriter(f,fieldnames=["interval","begin_depth","end_depth","names","element_type","values"]); w.writeheader(); w.writerows(rows)
    print(f"BRO_PARSE|BRO_ID={broid}|INTERVALS={len(intervals)}|HYDRAULIC_ARRAYS={len(rows)}")
    for r in rows: print("BRO_PARSE_ARRAY|"+json.dumps(r,sort_keys=True))
if __name__=="__main__": main()
