#!/usr/bin/env python3
"""F-PE-ELASTIC11A: calibration-only, object-grouped physical ELAS predictor evaluation."""
from __future__ import annotations
import argparse, collections, hashlib, json, math, statistics
from pathlib import Path

EXPECTED_CALIBRATION_COUNT=36
EXPECTED_CALIBRATION_SHA="7b42fee42b2b05e2f788e13317b90d574b1039cf240e57fb3f2c35fe994dd45e"
EXPECTED_HOLDOUT_COUNT=18
EXPECTED_HOLDOUT_SHA="bfbb1fdefaef57ea3e6a0d2e077fa8efee5b17f101a92da04f0f75603b94e5df"
RIDGE_LAMBDA=1.0
FIELD_GATE_MAE=0.05
FIELD_GATE_MEDIAN=0.03
FIELD_GATE_WIN_FRAC=0.60
DEPTH_SIMPLICITY_DELTA=0.02
LAB_CONTEXT_DELTA=0.05

def serial_sha(values):
    return hashlib.sha256(("\n".join(values)+"\n").encode()).hexdigest()

def find_corpus(start:Path):
    hits=list(start.rglob("calibration-corpus.json"))
    if len(hits)!=1:
        raise SystemExit(f"F_PE_ELASTIC11_FAIL calibration-corpus hits={len(hits)}")
    return hits[0]

def one_numeric_descriptor(target,name):
    vals=target.get("descriptors",{}).get(name,[])
    if len(vals)!=1:
        raise RuntimeError(f"{target.get('bro_id')} {name} count={len(vals)}")
    try:
        x=float(vals[0])
    except ValueError as e:
        raise RuntimeError(f"{target.get('bro_id')} {name} nonnumeric={vals[0]!r}") from e
    if not math.isfinite(x):
        raise RuntimeError(f"{target.get('bro_id')} {name} nonfinite")
    return x

def target_row(t):
    ss=float(t["ss_skeleton_cm_inv"])
    if not (math.isfinite(ss) and ss>0):
        raise RuntimeError("invalid target Ss")
    rho=one_numeric_descriptor(t,"volumetricMassDensity")
    wc=one_numeric_descriptor(t,"waterContent")
    b=float(t["begin_depth_m"]); e=float(t["end_depth_m"])
    depth=0.5*(b+e)
    stress=abs(float(t["delta_sigma_pa"]))/1000.0
    if not (math.isfinite(depth) and math.isfinite(stress) and stress>0):
        raise RuntimeError("invalid depth/stress")
    method=t.get("method")
    if method=="samendrukkenBelastinggestuurd":
        method_rate=0.0
    elif method=="samendrukkenSnelheidgestuurd":
        method_rate=1.0
    else:
        raise RuntimeError(f"unregistered method {method!r}")
    return {
      "bro_id":t["bro_id"],
      "y":math.log10(ss),
      "rho":rho,
      "water":wc,
      "depth":depth,
      "log_stress":math.log10(stress),
      "method_rate":method_rate,
      "ss":ss,
    }

def solve_linear(a,b):
    n=len(b)
    m=[list(map(float,a[i]))+[float(b[i])] for i in range(n)]
    for col in range(n):
        pivot=max(range(col,n),key=lambda r:abs(m[r][col]))
        if abs(m[pivot][col])<1e-12:
            raise RuntimeError("singular normal system")
        m[col],m[pivot]=m[pivot],m[col]
        div=m[col][col]
        m[col]=[v/div for v in m[col]]
        for r in range(n):
            if r==col: continue
            fac=m[r][col]
            if fac==0: continue
            m[r]=[m[r][j]-fac*m[col][j] for j in range(n+1)]
    return [m[i][-1] for i in range(n)]

def object_weights(rows):
    count=collections.Counter(r["bro_id"] for r in rows)
    return [1.0/count[r["bro_id"]] for r in rows]

def fit_ridge(rows,features):
    weights=object_weights(rows)
    means={}; scales={}
    continuous=[f for f in features if f!="method_rate"]
    kept=[]
    for f in features:
        if f=="method_rate":
            kept.append(f); continue
        sw=sum(weights)
        mu=sum(w*r[f] for w,r in zip(weights,rows))/sw
        var=sum(w*(r[f]-mu)**2 for w,r in zip(weights,rows))/sw
        sd=math.sqrt(max(var,0.0))
        means[f]=mu; scales[f]=sd
        if sd>1e-12:
            kept.append(f)
    p=1+len(kept)
    xtwx=[[0.0]*p for _ in range(p)]
    xtwy=[0.0]*p
    for w,r in zip(weights,rows):
        x=[1.0]
        for f in kept:
            if f=="method_rate":
                x.append(r[f])
            else:
                x.append((r[f]-means[f])/scales[f])
        for i in range(p):
            xtwy[i]+=w*x[i]*r["y"]
            for j in range(p):
                xtwx[i][j]+=w*x[i]*x[j]
    for i in range(1,p):
        xtwx[i][i]+=RIDGE_LAMBDA
    beta=solve_linear(xtwx,xtwy)
    return {"features":kept,"means":means,"scales":scales,"beta":beta}

def predict(model,row):
    x=[1.0]
    for f in model["features"]:
        if f=="method_rate":
            x.append(row[f])
        else:
            x.append((row[f]-model["means"][f])/model["scales"][f])
    return sum(a*b for a,b in zip(model["beta"],x))

def baseline_value(rows):
    by=collections.defaultdict(list)
    for r in rows: by[r["bro_id"]].append(r["y"])
    meds=[statistics.median(v) for v in by.values()]
    return statistics.median(meds)

def score_predictions(records,baseline_records):
    by=collections.defaultdict(list)
    by0=collections.defaultdict(list)
    nonfinite=0
    for rec in records:
        if not math.isfinite(rec["pred"]): nonfinite+=1
        by[rec["bro_id"]].append(rec["pred"]-rec["y"])
    for rec in baseline_records:
        by0[rec["bro_id"]].append(rec["pred"]-rec["y"])
    maes={k:sum(abs(e) for e in v)/len(v) for k,v in by.items()}
    rmses={k:math.sqrt(sum(e*e for e in v)/len(v)) for k,v in by.items()}
    mae=sum(maes.values())/len(maes)
    rmse=math.sqrt(sum(r*r for r in rmses.values())/len(rmses))
    med=statistics.median(maes.values())
    max_mae=max(maes.values())
    wins=sum(maes[k] < (sum(abs(e) for e in by0[k])/len(by0[k])) for k in maes)/len(maes)
    return {
      "object_balanced_mae_log10":mae,
      "object_balanced_rmse_log10":rmse,
      "median_object_mae_log10":med,
      "max_object_mae_log10":max_mae,
      "fraction_objects_better_than_M0":wins,
      "multiplicative_error_from_mae":10.0**mae,
      "nonfinite_predictions":nonfinite,
      "object_mae":dict(sorted(maes.items())),
    }

def loo(rows,features=None):
    objects=sorted({r["bro_id"] for r in rows})
    records=[]; baseline=[]
    for held in objects:
        train=[r for r in rows if r["bro_id"]!=held]
        test=[r for r in rows if r["bro_id"]==held]
        b=baseline_value(train)
        model=fit_ridge(train,features) if features is not None else None
        for r in test:
            p=b if model is None else predict(model,r)
            records.append({"bro_id":held,"y":r["y"],"pred":p})
            baseline.append({"bro_id":held,"y":r["y"],"pred":b})
    return records,baseline

def full_fit(rows,features):
    m=fit_ridge(rows,features)
    return {
      "predictor_order":m["features"],
      "training_means":m["means"],
      "training_population_sd":m["scales"],
      "intercept":m["beta"][0],
      "coefficients":dict(zip(m["features"],m["beta"][1:])),
      "ridge_lambda":RIDGE_LAMBDA,
      "target_log10_min":min(r["y"] for r in rows),
      "target_log10_max":max(r["y"] for r in rows),
      "target_ss_cm_inv_min":min(r["ss"] for r in rows),
      "target_ss_cm_inv_max":max(r["ss"] for r in rows),
    }

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--artifact-dir",required=True)
    ap.add_argument("--output",required=True)
    a=ap.parse_args()
    root=Path(a.artifact_dir)
    corpus_path=find_corpus(root)
    corpus=json.loads(corpus_path.read_text())
    calibration=tuple(corpus.get("calibration_ids",[]))
    holdout=tuple(corpus.get("holdout_ids",[]))
    if len(calibration)!=EXPECTED_CALIBRATION_COUNT or serial_sha(calibration)!=EXPECTED_CALIBRATION_SHA:
        raise SystemExit("F_PE_ELASTIC11_FAIL calibration authority drift")
    if len(holdout)!=EXPECTED_HOLDOUT_COUNT or serial_sha(holdout)!=EXPECTED_HOLDOUT_SHA:
        raise SystemExit("F_PE_ELASTIC11_FAIL holdout authority drift")
    xmls=list(root.rglob("*.xml"))
    if any(p.stem in set(holdout) for p in xmls):
        raise SystemExit("F_PE_ELASTIC11_FAIL holdout XML present")

    targets=[t for t in corpus.get("targets",[]) if t.get("classification")=="VALID" and t.get("kind")=="unload"]
    if len(targets)!=77:
        raise SystemExit(f"F_PE_ELASTIC11_FAIL unload count={len(targets)}")
    rows=[target_row(t) for t in targets]
    objects=sorted({r["bro_id"] for r in rows})
    if len(objects)<2:
        raise SystemExit(f"F_PE_ELASTIC11_FAIL insufficient unload objects={len(objects)}")

    specs={
      "M0":None,
      "M1":["rho","water"],
      "M2":["rho","water","depth"],
      "M3":["rho","water","depth","log_stress","method_rate"],
    }
    scores={}; preds={}
    baseline_records=None
    for name,features in specs.items():
        rec,b0=loo(rows,features)
        if baseline_records is None: baseline_records=b0
        # M0 compares to itself; use its own records as baseline.
        ref=rec if name=="M0" else b0
        scores[name]=score_predictions(rec,ref)
        preds[name]=rec

    m0=scores["M0"]
    qualified=[]
    for name in ("M1","M2"):
        s=scores[name]
        gate=(
          m0["object_balanced_mae_log10"]-s["object_balanced_mae_log10"]>=FIELD_GATE_MAE and
          m0["median_object_mae_log10"]-s["median_object_mae_log10"]>=FIELD_GATE_MEDIAN and
          s["fraction_objects_better_than_M0"]>=FIELD_GATE_WIN_FRAC and
          s["nonfinite_predictions"]==0
        )
        s["deployment_gate_pass"]=gate
        if gate: qualified.append(name)

    selected=None
    if qualified==["M1"]:
        selected="M1"
    elif qualified==["M2"]:
        selected="M2"
    elif len(qualified)==2:
        if scores["M1"]["object_balanced_mae_log10"]-scores["M2"]["object_balanced_mae_log10"]>=DEPTH_SIMPLICITY_DELTA:
            selected="M2"
        else:
            selected="M1"

    best_field=selected
    if best_field is None:
        best_field=min(("M1","M2"),key=lambda n:scores[n]["object_balanced_mae_log10"])
    lab_gain=scores[best_field]["object_balanced_mae_log10"]-scores["M3"]["object_balanced_mae_log10"]
    lab_material=lab_gain>=LAB_CONTEXT_DELTA

    classification=("DEPLOYMENT_CANDIDATE_FROZEN_HOLDOUT_AUTHORIZED"
                    if selected else
                    "NO_ROBUST_FIELD_PREDICTOR_ON_CURRENT_CALIBRATION")
    result={
      "authority":{
        "calibration_count":len(calibration),
        "calibration_sha256":serial_sha(calibration),
        "holdout_count":len(holdout),
        "holdout_sha256":serial_sha(holdout),
        "holdout_xml_present":0,
        "unload_targets":len(rows),
        "unload_objects":len(objects),
      },
      "model_specifications":specs,
      "scores":scores,
      "selected_deployment_model":selected,
      "best_field_for_lab_comparison":best_field,
      "lab_context_mae_gain_log10":lab_gain,
      "lab_context_materially_improves_prediction":lab_material,
      "classification":classification,
      "full_calibration_fit":full_fit(rows,specs[selected]) if selected else None,
      "calibration_object_ids":objects,
    }
    out=Path(a.output); out.parent.mkdir(parents=True,exist_ok=True)
    out.write_text(json.dumps(result,indent=2)+"\n")
    print("F_PE_ELASTIC11_SUMMARY="+json.dumps({
      "scores":scores,
      "selected":selected,
      "lab_gain":lab_gain,
      "lab_material":lab_material,
      "classification":classification,
      "full_fit":result["full_calibration_fit"],
    },separators=(",",":"),sort_keys=True))
    print("F_PE_ELASTIC11_HOLDOUT_FETCHED=0")
    print("F_PE_ELASTIC11=PASS")

if __name__=="__main__":
    raise SystemExit(main())
