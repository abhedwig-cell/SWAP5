#!/usr/bin/env python3
"""F-PE-ELASTIC11C calibration-only, object-grouped model selection."""
from __future__ import annotations
import argparse, json, math
from collections import Counter, defaultdict
from pathlib import Path
import numpy as np

CALIBRATION = {
    "BHR000000462600","BHR000000456021","BHR000000356939","BHR000000453770",
    "BHR000000380280","BHR000000466468","BHR000000353613","BHR000000470062",
}
HOLDOUT = {
    "BHR000000462646","BHR000000456023","BHR000000356940","BHR000000453775",
    "BHR000000380281","BHR000000466469","BHR000000353614","BHR000000470064",
}
TARGET_KEYS=("bro_id","determination_index","step_index","route")

MODELS={
    "M0":{"coef":["intercept"],"offset":"zero"},
    "M1":{"coef":["intercept","route_r3"],"offset":"zero"},
    "M2":{"coef":["intercept"],"offset":"minus_log_stress"},
    "M3":{"coef":["intercept","route_r3"],"offset":"minus_log_stress"},
    "M4":{"coef":["intercept","density"],"offset":"minus_log_stress"},
    "M5":{"coef":["intercept","log_water"],"offset":"minus_log_stress"},
    "M6":{"coef":["intercept","route_r3","density"],"offset":"minus_log_stress"},
}

def key(r):
    return tuple(r[k] for k in TARGET_KEYS)

def load_calibration(predictor_path: Path,target_path: Path):
    predictors=json.loads(predictor_path.read_text())
    if {r["bro_id"] for r in predictors if r["group"]=="CALIBRATION"} != CALIBRATION:
        raise RuntimeError("calibration object set drift")
    if {r["bro_id"] for r in predictors if r["group"]=="HOLDOUT"} != HOLDOUT:
        raise RuntimeError("holdout object set drift")
    pcal={key(r):r for r in predictors if r["group"]=="CALIBRATION"}

    # Target-blind holdout gate: branch on object identity before ever touching target magnitude.
    tcal={}
    raw=json.loads(target_path.read_text())
    for r in raw:
        bro=r["bro_id"]
        if bro in HOLDOUT:
            continue
        if bro not in CALIBRATION:
            raise RuntimeError(f"unknown target object {bro}")
        y=float(r["ssk_cm_inv"])
        if not math.isfinite(y) or y<=0:
            raise RuntimeError("invalid calibration target")
        tcal[key(r)]=y
    if set(pcal)!=set(tcal):
        raise RuntimeError(f"calibration predictor/target identity mismatch p={len(pcal)} t={len(tcal)}")

    rows=[]
    for k in sorted(pcal):
        p=pcal[k]
        s=float(p["stress_midpoint_kpa"])
        span=float(p["stress_span_kpa"])
        d=float(p["volumetric_mass_density_g_cm3"])
        w=float(p["water_content_pct"])
        if min(s,span,d,w)<=0 or not all(math.isfinite(x) for x in (s,span,d,w)):
            raise RuntimeError(f"invalid complete predictor {k}")
        rows.append({
            "key":k,"bro_id":p["bro_id"],"route":p["route"],
            "log_stress":math.log10(s),"log_span":math.log10(span),
            "density":d,"log_water":math.log10(w),
            "midpoint_depth_m":float(p["midpoint_depth_m"]),
            "y":math.log10(tcal[k]),
        })
    if len(rows)!=22 or len({r["bro_id"] for r in rows})!=8:
        raise RuntimeError("calibration population drift")
    return rows

def offset(row,spec):
    return -row["log_stress"] if spec["offset"]=="minus_log_stress" else 0.0

def features(row,names):
    vals=[]
    for n in names:
        if n=="intercept":vals.append(1.0)
        elif n=="route_r3":vals.append(1.0 if row["route"]=="R3" else 0.0)
        elif n=="density":vals.append(row["density"])
        elif n=="log_water":vals.append(row["log_water"])
        else:raise RuntimeError(n)
    return vals

def fit(train,spec):
    counts=Counter(r["bro_id"] for r in train)
    X=np.asarray([features(r,spec["coef"]) for r in train],float)
    y=np.asarray([r["y"]-offset(r,spec) for r in train],float)
    w=np.asarray([1.0/counts[r["bro_id"]] for r in train],float)
    Xw=X*np.sqrt(w)[:,None]; yw=y*np.sqrt(w)
    coef,resid,rank,svals=np.linalg.lstsq(Xw,yw,rcond=None)
    if rank<len(spec["coef"]) or not np.all(np.isfinite(coef)):
        raise RuntimeError(f"rank deficient fit rank={rank} p={len(spec['coef'])}")
    return coef.tolist()

def predict(row,spec,coef):
    return offset(row,spec)+sum(a*b for a,b in zip(features(row,spec["coef"]),coef))

def obj_metrics(rows,preds):
    errors=np.asarray([p-r["y"] for r,p in zip(rows,preds)],float)
    ae=np.abs(errors)
    return {
        "n":len(rows),
        "mae":float(np.mean(ae)),
        "median_abs_error":float(np.median(ae)),
        "median_signed_error":float(np.median(errors)),
        "max_abs_error":float(np.max(ae)),
    }

def cv(rows,name,spec):
    objects=sorted({r["bro_id"] for r in rows})
    folds=[]
    for hold in objects:
        train=[r for r in rows if r["bro_id"]!=hold]
        test=[r for r in rows if r["bro_id"]==hold]
        try:
            coef=fit(train,spec)
            pred=[predict(r,spec,coef) for r in test]
            if not all(math.isfinite(x) for x in pred):
                raise RuntimeError("nonfinite prediction")
            m=obj_metrics(test,pred)
            folds.append({"held_out_object":hold,"coefficients":coef,"metrics":m,"failed":False})
        except Exception as e:
            folds.append({"held_out_object":hold,"failed":True,"error":str(e)})
    good=[f for f in folds if not f["failed"]]
    if len(good)!=len(objects):
        agg={"fold_failures":len(objects)-len(good)}
    else:
        maes=[f["metrics"]["mae"] for f in good]
        medabs=[f["metrics"]["median_abs_error"] for f in good]
        agg={
            "fold_failures":0,
            "mean_object_mae":float(np.mean(maes)),
            "median_object_mae":float(np.median(maes)),
            "median_object_median_abs_error":float(np.median(medabs)),
            "max_object_mae":float(np.max(maes)),
        }
    return {"model":name,"free_coefficients":len(spec["coef"]),"spec":spec,"folds":folds,"aggregate":agg}

def can_replace(current,candidate):
    ca=current["aggregate"]; cb=candidate["aggregate"]
    if cb.get("fold_failures",1)!=0:return False
    if cb["mean_object_mae"] >= ca["mean_object_mae"]-0.05:return False
    if cb["median_object_mae"] > ca["median_object_mae"]+0.02:return False
    return True

def select(results):
    by={r["model"]:r for r in results}
    current=by["M0"]
    # First test the equally parsimonious physics-offset model.
    if can_replace(current,by["M2"]):
        current=by["M2"]
    # Then allow exactly one best two-parameter candidate to challenge it.
    two=[by[m] for m in ("M1","M3","M4","M5") if by[m]["aggregate"].get("fold_failures",1)==0]
    two.sort(key=lambda r:(r["aggregate"]["mean_object_mae"],r["model"]))
    if two and two[0]["aggregate"]["mean_object_mae"] < by["M0"]["aggregate"]["mean_object_mae"]:
        if can_replace(current,two[0]):
            current=two[0]
    # Only then can the bounded three-parameter model enter.
    if can_replace(current,by["M6"]):
        current=by["M6"]
    return current["model"]

def characterization(rows):
    def rng(name):
        a=[r[name] for r in rows]
        return {"min":min(a),"median":float(np.median(a)),"max":max(a)}
    return {
        "rows":len(rows),"objects":len({r["bro_id"] for r in rows}),
        "route_counts":dict(Counter(r["route"] for r in rows)),
        "target_log10_ssk_cm_inv":rng("y"),
        "midpoint_depth_m":rng("midpoint_depth_m"),
        "density_g_cm3":rng("density"),
        "water_content_log10_pct":rng("log_water"),
        "stress_midpoint_log10_kpa":rng("log_stress"),
        "stress_span_log10_kpa":rng("log_span"),
    }

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--predictors",required=True)
    ap.add_argument("--targets",required=True)
    ap.add_argument("--out",required=True)
    a=ap.parse_args()
    rows=load_calibration(Path(a.predictors),Path(a.targets))
    results=[cv(rows,name,spec) for name,spec in MODELS.items()]
    selected=select(results)
    full_coef=fit(rows,MODELS[selected])
    out={
        "population":characterization(rows),
        "models":results,
        "selected_model":selected,
        "selected_full_calibration_coefficients":full_coef,
        "selected_spec":MODELS[selected],
        "selection_thresholds":{"mean_mae_improvement":0.05,"median_mae_max_worsening":0.02},
    }
    p=Path(a.out);p.parent.mkdir(parents=True,exist_ok=True)
    p.write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print("F_PE_ELASTIC11C_CALIBRATION_ROWS=22")
    print("F_PE_ELASTIC11C_CALIBRATION_OBJECTS=8")
    for r in results:
        print("F_PE_ELASTIC11C_MODEL="+r["model"]+"|METRICS="+json.dumps(r["aggregate"],separators=(",",":"),sort_keys=True))
    print("F_PE_ELASTIC11C_SELECTED="+selected)
    print("F_PE_ELASTIC11C_HOLDOUT_TARGETS_ACCESSED=0")
    print("F_PE_ELASTIC11C=PASS")

if __name__=="__main__":
    main()
