#!/usr/bin/env python3
"""F-PE-ELASTIC11B target-blind BHR-GT predictor-corpus extractor."""
from __future__ import annotations
import argparse, csv, hashlib, json, math
import xml.etree.ElementTree as ET
from collections import Counter
from pathlib import Path

CALIBRATION = {
    "BHR000000462600","BHR000000456021","BHR000000356939","BHR000000453770",
    "BHR000000380280","BHR000000466468","BHR000000353613","BHR000000470062",
}
HOLDOUT = {
    "BHR000000462646","BHR000000456023","BHR000000356940","BHR000000453775",
    "BHR000000380281","BHR000000466469","BHR000000353614","BHR000000470064",
}
FORBIDDEN_TARGET_KEYS = {
    "mv_pa_inv","ssk_m_inv","ssk_cm_inv","delta_strain_signed",
    "strain_start_pct","strain_end_pct",
}

FIELDS = {
    "begin_depth_m": ("interval","beginDepth","m","numeric"),
    "end_depth_m": ("interval","endDepth","m","numeric"),
    "volumetric_mass_density_g_cm3": ("interval","volumetricMassDensity","g/cm3","numeric"),
    "solids_density_g_cm3": ("interval","volumetricMassDensitySolids","g/cm3","numeric"),
    "water_content_pct": ("interval","waterContent","%","numeric"),
    "organic_matter_pct": ("interval","organicMatterContent","%","numeric"),
    "sample_quality": ("interval","sampleQuality",None,"text"),
    "sample_moistness": ("interval","sampleMoistness",None,"text"),
    "geotechnical_soil_name": ("interval","geotechnicalSoilName",None,"text"),
    "organic_matter_class": ("interval","organicMatterContentClass",None,"text"),
    "determination_method": ("determination","determinationMethod",None,"text"),
    "determination_procedure": ("determination","determinationProcedure",None,"text"),
}

def local(tag: str) -> str:
    return tag.rsplit("}",1)[-1]

def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()

def unique_source_values(scope, name):
    values=[]
    for e in scope.iter():
        if local(e.tag)!=name:
            continue
        raw=(e.text or "").strip()
        if not raw:
            continue
        unit=e.attrib.get("uom")
        code_space=next((v for k,v in e.attrib.items() if local(k)=="codeSpace"),None)
        item=(raw,unit,code_space)
        if item not in values:
            values.append(item)
    return values

def bind_value(scope,name,required_unit,kind):
    values=unique_source_values(scope,name)
    if not values:
        return {"status":"MISSING","value":None,"raw_values":[],"unit":required_unit}
    if len(values)!=1:
        return {"status":"AMBIGUOUS","value":None,
                "raw_values":[{"raw":r,"unit":u,"code_space":c} for r,u,c in values],
                "unit":required_unit}
    raw,unit,code_space=values[0]
    if required_unit is not None and unit!=required_unit:
        return {"status":"AMBIGUOUS","value":None,
                "raw_values":[{"raw":raw,"unit":unit,"code_space":code_space}],
                "unit":required_unit,"reason":"UNIT_MISMATCH"}
    if kind=="numeric":
        try:value=float(raw)
        except ValueError:value=float("nan")
        if not math.isfinite(value):
            return {"status":"AMBIGUOUS","value":None,
                    "raw_values":[{"raw":raw,"unit":unit,"code_space":code_space}],
                    "unit":required_unit,"reason":"NONFINITE"}
    else:
        value=raw
    return {"status":"ASSIGNED","value":value,"raw_values":[{"raw":raw,"unit":unit,"code_space":code_space}],
            "unit":unit,"code_space":code_space}

def ancestor(parent,node,wanted):
    x=node
    while x is not None:
        if local(x.tag)==wanted:
            return x
        x=parent.get(x)
    return None

def split_for(bro_id):
    if bro_id in CALIBRATION:return "CALIBRATION"
    if bro_id in HOLDOUT:return "HOLDOUT"
    raise RuntimeError(f"unfrozen BRO object {bro_id}")

def target_identity_rows(path: Path):
    raw=json.loads(path.read_text())
    if not isinstance(raw,list):
        raise RuntimeError("target identity input must be a list")
    out=[]
    for r in raw:
        missing={"bro_id","determination_index","step_index","route","stress_start_kpa","stress_end_kpa"}-set(r)
        if missing:
            raise RuntimeError(f"target identity missing {sorted(missing)}")
        # Hard target-blind gate: never retain or inspect target magnitudes.
        ident={k:r[k] for k in ("bro_id","determination_index","step_index","route",
                                "stress_start_kpa","stress_end_kpa","schema_record")}
        out.append(ident)
    return out

def extract(objects: Path, authority: dict, target_ids):
    auth_by={x["bro_id"]:x for x in authority["objects"]}
    rows=[]
    object_cache={}
    for t in target_ids:
        bro=t["bro_id"]
        if bro not in auth_by:
            raise RuntimeError(f"target BRO object outside frozen authority {bro}")
        if bro not in object_cache:
            a=auth_by[bro]
            p=objects/f"object-{bro}.response"
            if not p.exists():raise RuntimeError(f"missing frozen object {bro}")
            if sha256(p)!=a["sha256"] or p.stat().st_size!=a["size_bytes"]:
                raise RuntimeError(f"object identity mismatch {bro}")
            root=ET.fromstring(p.read_bytes())
            parent={c:q for q in root.iter() for c in q}
            dets=[e for e in root.iter() if local(e.tag)=="SettlementCharacteristicsDetermination"]
            object_cache[bro]=(root,parent,dets,a)
        _,parent,dets,a=object_cache[bro]
        di=int(t["determination_index"])
        if not (1<=di<=len(dets)):
            raise RuntimeError(f"determination index out of bounds {bro}/{di}")
        det=dets[di-1]
        interval=ancestor(parent,det,"investigatedInterval")
        if interval is None:
            raise RuntimeError(f"settlement determination without investigatedInterval {bro}/{di}")

        rec={
            "bro_id":bro,
            "group":split_for(bro),
            "owning_cell":a["owning_cell"],
            "object_sha256":a["sha256"],
            "determination_index":di,
            "step_index":int(t["step_index"]),
            "route":t["route"],
            "schema_record":t["schema_record"],
            "stress_start_kpa":float(t["stress_start_kpa"]),
            "stress_end_kpa":float(t["stress_end_kpa"]),
        }
        rec["stress_midpoint_kpa"]=0.5*(rec["stress_start_kpa"]+rec["stress_end_kpa"])
        rec["stress_span_kpa"]=abs(rec["stress_end_kpa"]-rec["stress_start_kpa"])

        provenance={}
        for out_name,(scope_kind,xml_name,unit,kind) in FIELDS.items():
            bound=bind_value(det if scope_kind=="determination" else interval,xml_name,unit,kind)
            rec[out_name]=bound["value"]
            rec[out_name+"_status"]=bound["status"]
            provenance[out_name]={
                "scope":scope_kind,
                "xml_element":xml_name,
                "unit":bound.get("unit"),
                "code_space":bound.get("code_space"),
                "status":bound["status"],
                "raw_values":bound["raw_values"],
            }

        if rec["begin_depth_m_status"]=="ASSIGNED" and rec["end_depth_m_status"]=="ASSIGNED":
            rec["midpoint_depth_m"]=0.5*(rec["begin_depth_m"]+rec["end_depth_m"])
            rec["midpoint_depth_m_status"]="DERIVED_SOURCE_BOUND"
        else:
            rec["midpoint_depth_m"]=None
            rec["midpoint_depth_m_status"]="MISSING"

        rec["source_provenance"]=provenance
        rows.append(rec)

    rows.sort(key=lambda r:(r["bro_id"],r["determination_index"],r["step_index"],r["route"]))
    return rows

def coverage(rows):
    fields=list(FIELDS)+["midpoint_depth_m"]
    out={}
    for group in ("CALIBRATION","HOLDOUT","ALL"):
        subset=rows if group=="ALL" else [r for r in rows if r["group"]==group]
        by_object=sorted({r["bro_id"] for r in subset})
        out[group]={"rows":len(subset),"objects":len(by_object),"fields":{}}
        for f in fields:
            cnt=Counter(r[f+"_status"] for r in subset)
            out[group]["fields"][f]=dict(sorted(cnt.items()))
    return out

def write_csv(path,rows):
    omit={"source_provenance"}
    keys=sorted({k for r in rows for k in r if k not in omit})
    with path.open("w",newline="") as f:
        w=csv.DictWriter(f,fieldnames=keys);w.writeheader()
        for r in rows:
            w.writerow({k:r.get(k) for k in keys})

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--objects",required=True)
    ap.add_argument("--object-authority",required=True)
    ap.add_argument("--target-identities",required=True)
    ap.add_argument("--out",required=True)
    a=ap.parse_args()
    out=Path(a.out);out.mkdir(parents=True,exist_ok=True)
    authority=json.loads(Path(a.object_authority).read_text())
    targets=target_identity_rows(Path(a.target_identities))
    if len(targets)!=47:
        raise RuntimeError(f"expected 47 reconciled target identities, got {len(targets)}")
    rows=extract(Path(a.objects),authority,targets)
    cov=coverage(rows)

    # Explicit no-target-leakage gate on output names.
    names={k.lower() for r in rows for k in r}
    forbidden=[k for k in names if any(token in k for token in ("ssk","mv_pa","delta_strain","strain_start","strain_end"))]
    if forbidden:
        raise RuntimeError(f"target magnitude leaked into predictor rows: {forbidden}")

    (out/"predictors.json").write_text(json.dumps(rows,indent=2,sort_keys=True)+"\n")
    (out/"coverage.json").write_text(json.dumps(cov,indent=2,sort_keys=True)+"\n")
    write_csv(out/"predictors.csv",rows)

    print(f"F_PE_ELASTIC11B_ROWS={len(rows)}")
    print(f"F_PE_ELASTIC11B_CALIBRATION_OBJECTS={len(CALIBRATION)}")
    print(f"F_PE_ELASTIC11B_HOLDOUT_OBJECTS={len(HOLDOUT)}")
    print("F_PE_ELASTIC11B_COVERAGE="+json.dumps(cov,separators=(",",":"),sort_keys=True))
    print("F_PE_ELASTIC11B_NO_TARGET_LEAKAGE=PASS")
    print("F_PE_ELASTIC11B_PREDICTOR_CORPUS=PASS")

if __name__=="__main__":
    main()
