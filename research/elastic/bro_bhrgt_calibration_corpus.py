#!/usr/bin/env python3
"""F-PE-ELASTIC10D: frozen BHR-GT calibration-corpus characterization."""
from __future__ import annotations
import argparse, collections, hashlib, json, math, statistics
from pathlib import Path
import xml.etree.ElementTree as ET

from bro_bhrgt_fetch import fetch, manifest
from bro_bhrgt_pilot import QUERY
from bro_bhrgt_extract_targets import extract_object, local, direct_text, parse_num

EXPECTED_ID_COUNT=692
EXPECTED_ID_SHA="606a4785a5bea70e443a8729bfd132b9ddebe1ea799e78585ed3ba2f54f54667"
PILOT_IDS={
 "BHR000000339285","BHR000000339288","BHR000000351603"
}
EXPECTED_HOLDOUT=(
 "BHR000000424612","BHR000000462723","BHR000000462718","BHR000000380954",
 "BHR000000458789","BHR000000380408","BHR000000365007","BHR000000377189",
 "BHR000000377071","BHR000000369337","BHR000000361974","BHR000000380390",
 "BHR000000374009","BHR000000360500","BHR000000377179","BHR000000470651",
 "BHR000000381747","BHR000000369340",
)
EXPECTED_CALIBRATION=(
 "BHR000000450418","BHR000000451425","BHR000000369339","BHR000000354227",
 "BHR000000373650","BHR000000367080","BHR000000354099","BHR000000455524",
 "BHR000000377348","BHR000000362519","BHR000000359907","BHR000000469187",
 "BHR000000365772","BHR000000462578","BHR000000431999","BHR000000448182",
 "BHR000000351990","BHR000000353614","BHR000000380405","BHR000000374026",
 "BHR000000360510","BHR000000467482","BHR000000380370","BHR000000380387",
 "BHR000000469885","BHR000000377198","BHR000000374640","BHR000000376817",
 "BHR000000424423","BHR000000367072","BHR000000469045","BHR000000374977",
 "BHR000000455514","BHR000000458816","BHR000000377048","BHR000000362495",
)
EXPECTED_HOLDOUT_SHA="bfbb1fdefaef57ea3e6a0d2e077fa8efee5b17f101a92da04f0f75603b94e5df"
EXPECTED_CALIBRATION_SHA="7b42fee42b2b05e2f788e13317b90d574b1039cf240e57fb3f2c35fe994dd45e"

DESCRIPTORS=(
 "volumetricMassDensity","volumetricMassDensitySolids","waterContent",
 "organicMatterContent","geotechnicalSoilName","specialMaterial",
 "organicMatterClass","sandMedianClass",
)

def serial_sha(values):
    return hashlib.sha256(("\n".join(values)+"\n").encode()).hexdigest()

def save(root:Path,name:str,url:str,status:int,ctype:str,data:bytes):
    p=root/name
    p.write_bytes(data)
    m=manifest(url,status,ctype,data)
    (root/(name+".manifest.json")).write_text(json.dumps(m,indent=2)+"\n")
    return m

def semantic_object_hash(data:bytes):
    root=ET.fromstring(data)
    hits=[e for e in root.iter() if local(e.tag)=="BHR_GT_O"]
    if len(hits)!=1:
        raise RuntimeError(f"expected one BHR_GT_O, got {len(hits)}")
    xml=ET.tostring(hits[0],encoding="unicode")
    canonical=ET.canonicalize(xml_data=xml)
    return hashlib.sha256(canonical.encode()).hexdigest()

def collect_ids(xml_bytes:bytes):
    root=ET.fromstring(xml_bytes)
    return sorted(set(
        (e.text or "").strip() for e in root.iter()
        if local(e.tag).lower()=="broid" and (e.text or "").strip()
    ))

def split_population(ids):
    remaining=[x for x in ids if x not in PILOT_IDS]
    ranked=sorted(
        remaining,
        key=lambda x: hashlib.sha256(("F-PE-ELASTIC10D|"+x).encode()).hexdigest()
    )
    return tuple(ranked[:18]),tuple(ranked[18:54])

def unique_texts(node,name):
    vals=[]
    for e in node.iter():
        if local(e.tag)==name:
            t=(e.text or "").strip()
            if t and t not in vals: vals.append(t)
    return vals

def interval_descriptors(root,target):
    begin=target.get("begin_depth_m"); end=target.get("end_depth_m")
    for iv in (e for e in root.iter() if local(e.tag)=="investigatedInterval"):
        b=parse_num(direct_text(iv,"beginDepth")); z=parse_num(direct_text(iv,"endDepth"))
        if b is None or z is None or begin is None or end is None: continue
        if abs(b-begin)>1e-9 or abs(z-end)>1e-9: continue
        out={name:unique_texts(iv,name) for name in DESCRIPTORS}
        out["sampleQuality"]=unique_texts(iv,"sampleQuality")
        out["analysisType"]=unique_texts(iv,"analysisType")
        return out
    return {name:[] for name in DESCRIPTORS}

def stat(values):
    vals=[float(x) for x in values if x is not None and math.isfinite(float(x))]
    if not vals: return None
    return {"n":len(vals),"min":min(vals),"median":statistics.median(vals),"max":max(vals)}

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--output-dir",required=True)
    ap.add_argument("--base",default="https://publiek.broservices.nl/sr/bhrgt/v2")
    a=ap.parse_args()
    root=Path(a.output_dir); root.mkdir(parents=True,exist_ok=True)
    corpus=root/"calibration"; corpus.mkdir(exist_ok=True)

    body=json.dumps(QUERY,separators=(",",":")).encode()
    search_url=a.base.rstrip("/")+"/characteristics/searches"
    status,ctype,data=fetch(search_url,method="POST",body=body)
    search_manifest=save(root,"calibration-search.xml",search_url,status,ctype,data)
    if not (200<=status<300):
        raise SystemExit("F_PE_ELASTIC10D_FAIL search HTTP")

    ids=collect_ids(data)
    idsha=serial_sha(ids)
    print(f"F_PE_ELASTIC10D_ID_COUNT={len(ids)}")
    print("F_PE_ELASTIC10D_ID_SHA="+idsha)
    if len(ids)!=EXPECTED_ID_COUNT or idsha!=EXPECTED_ID_SHA:
        raise SystemExit("F_PE_ELASTIC10D_POPULATION_DRIFT")

    holdout,calibration=split_population(ids)
    if holdout!=EXPECTED_HOLDOUT:
        raise SystemExit("F_PE_ELASTIC10D_HOLDOUT_SPLIT_DRIFT")
    if calibration!=EXPECTED_CALIBRATION:
        raise SystemExit("F_PE_ELASTIC10D_CALIBRATION_SPLIT_DRIFT")
    if serial_sha(holdout)!=EXPECTED_HOLDOUT_SHA:
        raise SystemExit("F_PE_ELASTIC10D_HOLDOUT_SHA_DRIFT")
    if serial_sha(calibration)!=EXPECTED_CALIBRATION_SHA:
        raise SystemExit("F_PE_ELASTIC10D_CALIBRATION_SHA_DRIFT")
    if set(holdout)&set(calibration) or set(holdout)&PILOT_IDS or set(calibration)&PILOT_IDS:
        raise SystemExit("F_PE_ELASTIC10D_SPLIT_OVERLAP")
    print("F_PE_ELASTIC10D_SPLIT=PASS")

    cache={}; object_records=[]; determinations=[]; targets=[]
    for broid in calibration:
        # Holdout IDs are never iterated here; assert again immediately before fetch.
        if broid in holdout:
            raise SystemExit("F_PE_ELASTIC10D_FAIL holdout fetch attempted")
        url=a.base.rstrip("/")+"/objects/"+broid
        st,ct,raw=fetch(url)
        m=save(corpus,broid+".xml",url,st,ct,raw)
        if not (200<=st<300):
            raise SystemExit(f"F_PE_ELASTIC10D_FAIL object HTTP {broid}")
        semantic=semantic_object_hash(raw)
        d,t=extract_object(corpus/(broid+".xml"),corpus,cache)
        xmlroot=ET.fromstring(raw)
        for target in t:
            target["semantic_object_sha256"]=semantic
            target["descriptors"]=interval_descriptors(xmlroot,target)
        determinations.extend(d); targets.extend(t)
        object_records.append({
          "broId":broid,"raw_sha256":m["sha256"],
          "semantic_object_sha256":semantic,
          "bytes":m["size_bytes"],
          "settlement_determinations":len(d),
          "targets":len(t),
          "valid_targets":sum(x.get("classification")=="VALID" for x in t),
        })

    valid=[x for x in targets if x.get("classification")=="VALID"]
    unload=[x for x in valid if x.get("kind")=="unload"]
    reload=[x for x in valid if x.get("kind")=="reload"]

    method=collections.defaultdict(list)
    for x in valid: method[x.get("method","UNKNOWN")].append(x["ss_skeleton_cm_inv"])

    target_coverage={}
    object_coverage={}
    for name in DESCRIPTORS:
        target_coverage[name]=sum(bool(x.get("descriptors",{}).get(name)) for x in valid)
        covered=set(x["bro_id"] for x in valid if x.get("descriptors",{}).get(name))
        object_coverage[name]=len(covered)

    depths=[0.5*(x["begin_depth_m"]+x["end_depth_m"]) for x in valid
            if x.get("begin_depth_m") is not None and x.get("end_depth_m") is not None]
    stress_range=[abs(x["delta_sigma_pa"])/1000.0 for x in valid if x.get("delta_sigma_pa") is not None]
    per_object=collections.Counter(x["bro_id"] for x in valid)

    summary={
      "population":{"count":len(ids),"sha256":idsha},
      "holdout":{"count":len(holdout),"sha256":serial_sha(holdout)},
      "calibration":{"count":len(calibration),"sha256":serial_sha(calibration)},
      "fetched_objects":len(object_records),
      "settlement_determinations":len(determinations),
      "targets_total":len(targets),
      "valid_unload":len(unload),
      "valid_reload":len(reload),
      "unload_ss_cm_inv":stat([x["ss_skeleton_cm_inv"] for x in unload]),
      "reload_ss_cm_inv":stat([x["ss_skeleton_cm_inv"] for x in reload]),
      "by_method":{k:stat(v) for k,v in sorted(method.items())},
      "descriptor_coverage_by_target":target_coverage,
      "descriptor_coverage_by_object":object_coverage,
      "target_depth_m":stat(depths),
      "target_stress_range_kpa":stat(stress_range),
      "objects_with_multiple_valid_targets":sum(n>1 for n in per_object.values()),
      "objects_with_valid_target":len(per_object),
    }
    payload={
      "query":QUERY,
      "search_manifest":search_manifest,
      "holdout_ids":list(holdout),
      "calibration_ids":list(calibration),
      "object_records":object_records,
      "schemas":list(cache.values()),
      "targets":targets,
      "summary":summary,
    }
    (root/"calibration-corpus.json").write_text(json.dumps(payload,indent=2)+"\n")

    print("F_PE_ELASTIC10D_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
    print("F_PE_ELASTIC10D_HOLDOUT_FETCHED=0")
    print("F_PE_ELASTIC10D=PASS")

if __name__=="__main__":
    raise SystemExit(main())
