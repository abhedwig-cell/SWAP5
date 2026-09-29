#!/usr/bin/env python3
"""F-PE-ELASTIC11B: one-shot independent holdout qualification of frozen M1."""
from __future__ import annotations
import argparse, collections, hashlib, json, math, statistics
from pathlib import Path
import xml.etree.ElementTree as ET

from bro_bhrgt_fetch import fetch, manifest
from bro_bhrgt_extract_targets import extract_object, local, direct_text, parse_num
from bro_bhrgt_calibration_corpus import semantic_object_hash

HOLDOUT=(
 "BHR000000424612","BHR000000462723","BHR000000462718","BHR000000380954",
 "BHR000000458789","BHR000000380408","BHR000000365007","BHR000000377189",
 "BHR000000377071","BHR000000369337","BHR000000361974","BHR000000380390",
 "BHR000000374009","BHR000000360500","BHR000000377179","BHR000000470651",
 "BHR000000381747","BHR000000369340",
)
EXPECTED_HOLDOUT_SHA="bfbb1fdefaef57ea3e6a0d2e077fa8efee5b17f101a92da04f0f75603b94e5df"

M0_Y=-5.185127014665233
INTERCEPT=-5.144312248981006
RHO_COEF=-0.25581251314464676
WATER_COEF=0.15229775506831100
RHO_MEAN=1.4337873737373736
RHO_SD=0.34422692442216535
WATER_MEAN=191.8190909090909
WATER_SD=182.02868188688447

MIN_OBJECTS=10
MIN_TARGETS=20
REQ_MAE_GAIN=0.05
REQ_MEDIAN_GAIN=0.03
REQ_WIN_FRAC=0.60

def serial_sha(values):
    return hashlib.sha256(("\n".join(values)+"\n").encode()).hexdigest()

def save(root:Path,name:str,url:str,status:int,ctype:str,data:bytes):
    p=root/name
    p.write_bytes(data)
    m=manifest(url,status,ctype,data)
    (root/(name+".manifest.json")).write_text(json.dumps(m,indent=2)+"\n")
    return m

def xml_id(e):
    for k,v in e.attrib.items():
        if local(k)=="id":
            return v
    return None

def text_value(e):
    t=(e.text or "").strip()
    return t or None

def investigated_interval(root,begin,end):
    for iv in (e for e in root.iter() if local(e.tag)=="investigatedInterval"):
        b=parse_num(direct_text(iv,"beginDepth")); z=parse_num(direct_text(iv,"endDepth"))
        if b is None or z is None or begin is None or end is None:
            continue
        if abs(b-begin)<=1e-9 and abs(z-end)<=1e-9:
            return iv
    return None

def matching_determination(iv,det_id):
    if iv is None:
        return None
    for wrap in list(iv):
        if local(wrap.tag)!="settlementCharacteristicsDetermination":
            continue
        det=next((x for x in list(wrap) if local(x.tag)=="SettlementCharacteristicsDetermination"),None)
        if det is not None and xml_id(det)==det_id:
            return det
    return None

def raw_values(node,name):
    if node is None:
        return []
    vals=[]
    for e in node.iter():
        if local(e.tag)!=name:
            continue
        t=text_value(e)
        if t is not None:
            vals.append(t)
    return vals

def bound_numeric(root,target,name):
    iv=investigated_interval(root,target.get("begin_depth_m"),target.get("end_depth_m"))
    det=matching_determination(iv,target.get("determination_id"))
    vals=raw_values(det,name)
    scope="settlement_determination"
    if not vals:
        vals=raw_values(iv,name)
        scope="investigated_interval"
    unique=[]
    for v in vals:
        if v not in unique:
            unique.append(v)
    if len(unique)!=1:
        return None,{"scope":scope,"raw_values":unique,"classification":"MISSING_OR_AMBIGUOUS"}
    try:
        x=float(unique[0])
    except ValueError:
        return None,{"scope":scope,"raw_values":unique,"classification":"NONNUMERIC"}
    if not math.isfinite(x):
        return None,{"scope":scope,"raw_values":unique,"classification":"NONFINITE"}
    return x,{"scope":scope,"raw_values":unique,"classification":"VALID"}

def predict(rho,water):
    zr=(rho-RHO_MEAN)/RHO_SD
    zw=(water-WATER_MEAN)/WATER_SD
    return INTERCEPT + RHO_COEF*zr + WATER_COEF*zw

def score(records,key):
    by=collections.defaultdict(list)
    for r in records:
        by[r["bro_id"]].append(r[key]-r["y"])
    mae_by={k:sum(abs(e) for e in v)/len(v) for k,v in by.items()}
    mse_by={k:sum(e*e for e in v)/len(v) for k,v in by.items()}
    return {
      "object_balanced_mae_log10":sum(mae_by.values())/len(mae_by),
      "object_balanced_rmse_log10":math.sqrt(sum(mse_by.values())/len(mse_by)),
      "median_object_mae_log10":statistics.median(mae_by.values()),
      "max_object_mae_log10":max(mae_by.values()),
      "multiplicative_error_from_mae":10.0**(sum(mae_by.values())/len(mae_by)),
      "object_mae":dict(sorted(mae_by.items())),
    }

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--output-dir",required=True)
    ap.add_argument("--base",default="https://publiek.broservices.nl/sr/bhrgt/v2")
    a=ap.parse_args()
    out=Path(a.output_dir); out.mkdir(parents=True,exist_ok=True)
    rawdir=out/"objects"; rawdir.mkdir(exist_ok=True)

    if serial_sha(HOLDOUT)!=EXPECTED_HOLDOUT_SHA:
        raise SystemExit("F_PE_ELASTIC11B_FAIL holdout list hash")

    cache={}
    object_records=[]
    targets=[]
    reload_count=0
    for broid in HOLDOUT:
        url=a.base.rstrip("/")+"/objects/"+broid
        st,ct,raw=fetch(url)
        m=save(rawdir,broid+".xml",url,st,ct,raw)
        if not (200<=st<300):
            raise SystemExit(f"F_PE_ELASTIC11B_FAIL object HTTP {broid}")
        semantic=semantic_object_hash(raw)
        det,t=extract_object(rawdir/(broid+".xml"),rawdir,cache)
        root=ET.fromstring(raw)
        valid=[x for x in t if x.get("classification")=="VALID"]
        unload=[x for x in valid if x.get("kind")=="unload"]
        reload_count+=sum(x.get("kind")=="reload" for x in valid)
        object_records.append({
          "bro_id":broid,
          "raw_sha256":m["sha256"],
          "semantic_object_sha256":semantic,
          "bytes":m["size_bytes"],
          "settlement_determinations":len(det),
          "valid_unload_targets":len(unload),
          "valid_reload_targets":sum(x.get("kind")=="reload" for x in valid),
        })
        for t0 in unload:
            rho,rho_meta=bound_numeric(root,t0,"volumetricMassDensity")
            water,water_meta=bound_numeric(root,t0,"waterContent")
            rec={
              "bro_id":broid,
              "begin_depth_m":t0.get("begin_depth_m"),
              "end_depth_m":t0.get("end_depth_m"),
              "determination_id":t0.get("determination_id"),
              "ss_skeleton_cm_inv":t0.get("ss_skeleton_cm_inv"),
              "rho":rho,"water":water,
              "rho_binding":rho_meta,"water_binding":water_meta,
            }
            if rho is None or water is None:
                rec["scorable"]=False
            else:
                y=math.log10(float(t0["ss_skeleton_cm_inv"]))
                pred=predict(rho,water)
                rec.update({"scorable":True,"y":y,"pred_m1":pred,"pred_m0":M0_Y})
            targets.append(rec)

    valid_targets=len(targets)
    valid_objects=len({r["bro_id"] for r in targets})
    scorable=[r for r in targets if r["scorable"]]
    scorable_objects=len({r["bro_id"] for r in scorable})
    coverage=(len(scorable)/valid_targets) if valid_targets else 0.0
    yield_ok=valid_targets>=MIN_TARGETS and valid_objects>=MIN_OBJECTS

    result={
      "authority":{
        "holdout_ids":list(HOLDOUT),
        "holdout_sha256":serial_sha(HOLDOUT),
        "fetched_objects":len(object_records),
      },
      "object_records":object_records,
      "valid_unload_targets":valid_targets,
      "valid_unload_objects":valid_objects,
      "valid_reload_targets":reload_count,
      "scorable_unload_targets":len(scorable),
      "scorable_unload_objects":scorable_objects,
      "predictor_coverage":coverage,
      "yield_ok":yield_ok,
      "targets":targets,
    }

    if not yield_ok:
        classification="INSUFFICIENT_HOLDOUT_YIELD"
        result["classification"]=classification
        result["m0_score"]=None
        result["m1_score"]=None
    elif coverage<1.0:
        classification="INDEPENDENT_HOLDOUT_REJECTS_CURRENT_PREDICTOR"
        result["classification"]=classification
        result["m0_score"]=score(scorable,"pred_m0") if scorable else None
        result["m1_score"]=score(scorable,"pred_m1") if scorable else None
    else:
        m0=score(scorable,"pred_m0")
        m1=score(scorable,"pred_m1")
        m0_by=m0["object_mae"]; m1_by=m1["object_mae"]
        wins=sum(m1_by[k]<m0_by[k] for k in m1_by)/len(m1_by)
        m1["fraction_objects_better_than_M0"]=wins
        m1["nonfinite_predictions"]=sum(not math.isfinite(r["pred_m1"]) for r in scorable)
        mae_gain=m0["object_balanced_mae_log10"]-m1["object_balanced_mae_log10"]
        med_gain=m0["median_object_mae_log10"]-m1["median_object_mae_log10"]
        passed=(
          mae_gain>=REQ_MAE_GAIN and
          med_gain>=REQ_MEDIAN_GAIN and
          wins>=REQ_WIN_FRAC and
          m1["nonfinite_predictions"]==0
        )
        classification=("INDEPENDENT_HOLDOUT_QUALIFIED_PHYSICAL_PREDICTOR"
                        if passed else
                        "INDEPENDENT_HOLDOUT_REJECTS_CURRENT_PREDICTOR")
        result.update({
          "m0_score":m0,
          "m1_score":m1,
          "mae_gain_log10":mae_gain,
          "median_object_mae_gain_log10":med_gain,
          "classification":classification,
        })

    (out/"holdout-result.json").write_text(json.dumps(result,indent=2)+"\n")
    print("F_PE_ELASTIC11B_SUMMARY="+json.dumps({
      "valid_unload_targets":valid_targets,
      "valid_unload_objects":valid_objects,
      "valid_reload_targets":reload_count,
      "scorable_targets":len(scorable),
      "coverage":coverage,
      "yield_ok":yield_ok,
      "m0":result.get("m0_score"),
      "m1":result.get("m1_score"),
      "mae_gain":result.get("mae_gain_log10"),
      "median_gain":result.get("median_object_mae_gain_log10"),
      "classification":result["classification"],
    },separators=(",",":"),sort_keys=True))
    print("F_PE_ELASTIC11B_FETCHED_OBJECTS=18")
    print("F_PE_ELASTIC11B=PASS")

if __name__=="__main__":
    raise SystemExit(main())
