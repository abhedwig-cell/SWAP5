#!/usr/bin/env python3
"""F-PE-ELASTIC10D2: offline source-bound descriptor audit on frozen Phase-D artifact."""
from __future__ import annotations
import argparse, collections, hashlib, json
from pathlib import Path
import xml.etree.ElementTree as ET

EXPECTED_CALIBRATION_COUNT=36
EXPECTED_CALIBRATION_SHA="7b42fee42b2b05e2f788e13317b90d574b1039cf240e57fb3f2c35fe994dd45e"
EXPECTED_HOLDOUT_COUNT=18
EXPECTED_HOLDOUT_SHA="bfbb1fdefaef57ea3e6a0d2e077fa8efee5b17f101a92da04f0f75603b94e5df"

FIELDS=(
 "dryVolumetricMassDensity",
 "volumetricMassDensity",
 "volumetricMassDensitySolids",
 "waterContent",
 "sampleMoistness",
 "saturated",
 "underLoad",
 "verticalStrain",
 "geotechnicalSoilName",
 "organicMatterContent",
 "organicMatterContentClass",
 "sandMedianClass",
 "specialMaterial",
)
CATEGORICAL=(
 "sampleMoistness","saturated","underLoad","geotechnicalSoilName",
 "organicMatterContentClass","sandMedianClass","specialMaterial",
)

def local(tag:str)->str:
    return tag.rsplit("}",1)[-1]

def serial_sha(values):
    return hashlib.sha256(("\n".join(values)+"\n").encode()).hexdigest()

def text_value(e):
    t=(e.text or "").strip()
    return t or None

def unit_of(e):
    for k,v in e.attrib.items():
        lk=local(k).lower()
        if lk in {"uom","unit","unitofmeasure"} and str(v).strip():
            return str(v).strip()
    for ch in list(e):
        if local(ch.tag).lower()=="uom":
            for key in ("code","href"):
                if key in ch.attrib and str(ch.attrib[key]).strip():
                    return str(ch.attrib[key]).strip()
            t=text_value(ch)
            if t: return t
    return None

def xml_id(e):
    for k,v in e.attrib.items():
        if local(k)=="id":
            return v
    return None

def direct_text(e,name):
    for ch in list(e):
        if local(ch.tag)==name:
            return text_value(ch)
    return None

def parse_num(s):
    try: return float(s) if s is not None else None
    except ValueError: return None

def find_artifact_root(start:Path):
    hits=list(start.rglob("calibration-corpus.json"))
    if len(hits)!=1:
        raise SystemExit(f"F_PE_ELASTIC10D2_FAIL calibration-corpus hits={len(hits)}")
    return hits[0].parent, hits[0]

def investigated_intervals(root):
    return [e for e in root.iter() if local(e.tag)=="investigatedInterval"]

def interval_match(root,begin,end):
    if begin is None or end is None: return None
    for iv in investigated_intervals(root):
        b=parse_num(direct_text(iv,"beginDepth")); z=parse_num(direct_text(iv,"endDepth"))
        if b is not None and z is not None and abs(b-begin)<=1e-9 and abs(z-end)<=1e-9:
            return iv
    return None

def determinations(iv):
    out=[]
    for wrap in list(iv):
        if local(wrap.tag)!="settlementCharacteristicsDetermination": continue
        det=next((x for x in list(wrap) if local(x.tag)=="SettlementCharacteristicsDetermination"),None)
        if det is not None: out.append(det)
    return out

def observations(node,name,bro_id,begin,end,scope,det_id):
    out=[]
    for e in node.iter():
        if local(e.tag)!=name: continue
        raw=text_value(e)
        if raw is None: continue
        out.append({
          "bro_id":bro_id,
          "begin_depth_m":begin,
          "end_depth_m":end,
          "determination_id":det_id,
          "scope":scope,
          "local_name":name,
          "raw_value":raw,
          "unit":unit_of(e),
        })
    return out

def bound_field(iv,det,name,bro_id,begin,end,det_id):
    vals=observations(det,name,bro_id,begin,end,"settlement_determination",det_id)
    if vals: return vals
    return observations(iv,name,bro_id,begin,end,"investigated_interval",det_id)

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--artifact-dir",required=True)
    ap.add_argument("--output",required=True)
    a=ap.parse_args()
    artifact=Path(a.artifact_dir)
    corpus_root, corpus_json_path=find_artifact_root(artifact)
    corpus=json.loads(corpus_json_path.read_text())
    calibration=tuple(corpus.get("calibration_ids",[]))
    holdout=tuple(corpus.get("holdout_ids",[]))
    if len(calibration)!=EXPECTED_CALIBRATION_COUNT or serial_sha(calibration)!=EXPECTED_CALIBRATION_SHA:
        raise SystemExit("F_PE_ELASTIC10D2_FAIL calibration authority drift")
    if len(holdout)!=EXPECTED_HOLDOUT_COUNT or serial_sha(holdout)!=EXPECTED_HOLDOUT_SHA:
        raise SystemExit("F_PE_ELASTIC10D2_FAIL holdout authority drift")
    if set(calibration)&set(holdout):
        raise SystemExit("F_PE_ELASTIC10D2_FAIL split overlap")

    # D2 is offline-only: any holdout XML in the downloaded artifact is a hard failure.
    all_xml=list(artifact.rglob("*.xml"))
    leaked=[p for p in all_xml if p.stem in set(holdout)]
    if leaked:
        raise SystemExit("F_PE_ELASTIC10D2_FAIL holdout object present in artifact")

    xml_by_id={}
    for broid in calibration:
        hits=[p for p in all_xml if p.stem==broid]
        if len(hits)!=1:
            raise SystemExit(f"F_PE_ELASTIC10D2_FAIL {broid} xml hits={len(hits)}")
        xml_by_id[broid]=hits[0]

    roots={b:ET.fromstring(p.read_bytes()) for b,p in xml_by_id.items()}
    global_inventory={}
    for name in FIELDS:
        occurrences=0; objects=[]
        for broid,root in roots.items():
            vals=[e for e in root.iter() if local(e.tag)==name and text_value(e) is not None]
            if vals:
                occurrences+=len(vals); objects.append(broid)
        global_inventory[name]={"occurrences":occurrences,"objects":len(objects),"object_ids":sorted(objects)}

    valid=[x for x in corpus.get("targets",[]) if x.get("classification")=="VALID"]
    unload=[x for x in valid if x.get("kind")=="unload"]
    reload=[x for x in valid if x.get("kind")=="reload"]
    if len(unload)!=77 or len(reload)!=92:
        raise SystemExit(f"F_PE_ELASTIC10D2_FAIL target authority drift unload={len(unload)} reload={len(reload)}")

    det_records=[]
    det_index={}
    for broid,root in roots.items():
        for iv in investigated_intervals(root):
            begin=parse_num(direct_text(iv,"beginDepth")); end=parse_num(direct_text(iv,"endDepth"))
            for det in determinations(iv):
                did=xml_id(det)
                rec={"bro_id":broid,"begin_depth_m":begin,"end_depth_m":end,"determination_id":did,"fields":{}}
                for name in FIELDS:
                    rec["fields"][name]=bound_field(iv,det,name,broid,begin,end,did)
                det_records.append(rec)
                det_index[(broid,begin,end,did)]=rec

    target_records=[]
    for t in valid:
        key=(t.get("bro_id"),t.get("begin_depth_m"),t.get("end_depth_m"),t.get("determination_id"))
        rec=det_index.get(key)
        if rec is None:
            raise SystemExit("F_PE_ELASTIC10D2_FAIL target determination binding missing "+repr(key))
        target_records.append({
          "bro_id":t["bro_id"],"kind":t["kind"],
          "begin_depth_m":t.get("begin_depth_m"),"end_depth_m":t.get("end_depth_m"),
          "determination_id":t.get("determination_id"),
          "ss_skeleton_cm_inv":t.get("ss_skeleton_cm_inv"),
          "fields":rec["fields"],
        })

    def covered_target(records,name):
        return [r for r in records if r["fields"].get(name)]
    def object_set(records,name):
        return sorted({r["bro_id"] for r in records if r["fields"].get(name)})
    def category_objects(name):
        cats=collections.defaultdict(set)
        for r in target_records:
            for obs in r["fields"].get(name,[]):
                cats[obs["raw_value"]].add(r["bro_id"])
        return {k:len(v) for k,v in sorted(cats.items())}

    coverage={}
    for name in FIELDS:
        u=[r for r in target_records if r["kind"]=="unload" and r["fields"].get(name)]
        rr=[r for r in target_records if r["kind"]=="reload" and r["fields"].get(name)]
        objs=object_set(target_records,name)
        coverage[name]={
          "unload_targets":len(u),"unload_fraction":len(u)/77.0,
          "reload_targets":len(rr),"reload_fraction":len(rr)/92.0,
          "objects":len(objs),"object_ids":objs,
        }

    dry=coverage["dryVolumetricMassDensity"]
    dry_eligible=dry["unload_fraction"]>=0.50 and dry["objects"]>=15
    joint_unload=[r for r in target_records if r["kind"]=="unload"
                  and r["fields"].get("dryVolumetricMassDensity")
                  and r["fields"].get("volumetricMassDensitySolids")]
    joint_objects=sorted({r["bro_id"] for r in joint_unload})
    porosity_research_eligible=(len(joint_unload)/77.0)>=0.25 and len(joint_objects)>=10

    categorical={}
    for name in CATEGORICAL:
        cats=category_objects(name)
        objects=coverage[name]["objects"]
        qualifying=sum(n>=5 for n in cats.values())
        categorical[name]={
          "objects":objects,"category_object_counts":cats,
          "eligible":objects>=15 and qualifying>=2,
        }

    result={
      "authority":{
        "calibration_count":len(calibration),"calibration_sha256":serial_sha(calibration),
        "holdout_count":len(holdout),"holdout_sha256":serial_sha(holdout),
        "holdout_xml_present":0,
        "valid_unload":77,"valid_reload":92,
      },
      "determinations_audited":len(det_records),
      "fields":list(FIELDS),
      "object_global_inventory":global_inventory,
      "coverage":coverage,
      "gates":{
        "dry_density_predictor_eligible":dry_eligible,
        "dry_plus_solids_joint_unload_targets":len(joint_unload),
        "dry_plus_solids_joint_unload_fraction":len(joint_unload)/77.0,
        "dry_plus_solids_joint_objects":len(joint_objects),
        "porosity_research_eligible":porosity_research_eligible,
        "categorical":categorical,
      },
      "determinations":det_records,
      "targets":target_records,
    }
    out=Path(a.output); out.parent.mkdir(parents=True,exist_ok=True)
    out.write_text(json.dumps(result,indent=2)+"\n")

    print("F_PE_ELASTIC10D2_SUMMARY="+json.dumps({
      "determinations":len(det_records),"object_global_inventory":global_inventory,"coverage":coverage,"gates":result["gates"]
    },separators=(",",":"),sort_keys=True))
    print("F_PE_ELASTIC10D2_HOLDOUT_FETCHED=0")
    print("F_PE_ELASTIC10D2=PASS")

if __name__=="__main__":
    raise SystemExit(main())
