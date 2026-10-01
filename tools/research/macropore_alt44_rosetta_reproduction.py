#!/usr/bin/env python3
"""F-MACRO-ALT44 — reproduce authors' Rosetta Ksat and emit full VG-Mualem parameters.

Research-only. This script deliberately gates parameter generation on reproducing
the authors' published ksat_T values from rosetta_new_model_updates.csv.
"""

from __future__ import annotations
import csv
import json
import math
import sys
from pathlib import Path
from statistics import median

from rosetta import rosesoil


def finite(x):
    try:
        y=float(x)
        return y if math.isfinite(y) else None
    except Exception:
        return None


def relerr(a,b):
    return abs(a-b)/max(abs(a),abs(b),1e-12)


def load_rows(path: Path):
    with path.open(newline="",encoding="utf-8-sig") as f:
        return list(csv.DictReader(f))


def predict(rows, estimate_type):
    inputs=[]
    idx=[]
    for i,r in enumerate(rows):
        sa,si,cl = finite(r.get("sandtotal")),finite(r.get("silttotal")),finite(r.get("claytotal"))
        if None in (sa,si,cl):
            continue
        if abs(sa+si+cl-100.0)>2.0:
            continue
        inputs.append([sa,si,cl])
        idx.append(i)
    result=rosesoil(3,inputs,estimate_type=estimate_type).asdicts()
    return idx,result


def main(src,out_csv,out_json):
    rows=load_rows(Path(src))
    variants={}
    for est in ("log","geo","linear"):
        idx,res=predict(rows,est)
        errs=[]
        std_errs=[]
        for i,p in zip(idx,res):
            target=finite(rows[i].get("ksat_T"))
            target_sd=finite(rows[i].get("ksat_T_std"))
            pred_k = float(p["ksat"])
            if est == "log":
                pred_k = 10.0**pred_k
            if target is not None and math.isfinite(pred_k):
                errs.append(relerr(pred_k,target))
            pred_sd = p.get("ksat_std")
            if target_sd is not None and pred_sd is not None and math.isfinite(float(pred_sd)):
                std_errs.append(relerr(float(pred_sd),target_sd))
        variants[est]={
            "n":len(errs),
            "median_relative_ksat_error":median(errs) if errs else None,
            "max_relative_ksat_error":max(errs) if errs else None,
            "median_relative_ksat_std_error":median(std_errs) if std_errs else None,
        }

    finite_variants=[
        k for k,v in variants.items()
        if v["median_relative_ksat_error"] is not None
        and math.isfinite(v["median_relative_ksat_error"])
    ]
    chosen=min(finite_variants,key=lambda k: variants[k]["median_relative_ksat_error"])

    # Authors' ksat_T is expected to be the geometric mean: either geo directly
    # or 10**(log-space ensemble mean). Require near-bit-level agreement.
    reproducible = variants[chosen]["median_relative_ksat_error"] <= 1e-6

    # Use log-space output as the authority for alpha/n/K distributions:
    # convert means geometrically, retain bootstrap SD in log10 space.
    idx,res=predict(rows,"log")
    pred_by_idx=dict(zip(idx,res))
    fields=[
        "siteid","hzname","hzndept","hzndepb","midpointcm",
        "sandtotal","silttotal","claytotal",
        "authors_ksat_T","authors_ksat_T_std",
        "rosetta_code","theta_r","theta_s","alpha_per_cm","n",
        "ksat_cm_day","k0_cm_day","l",
        "theta_r_std","theta_s_std","alpha_std","n_std",
        "ksat_std","k0_std","l_std",
        "relative_ksat_error"
    ]
    with Path(out_csv).open("w",newline="",encoding="utf-8") as f:
        w=csv.DictWriter(f,fieldnames=fields)
        w.writeheader()
        for i,r in enumerate(rows):
            if i not in pred_by_idx:
                continue
            p=pred_by_idx[i]
            target=finite(r.get("ksat_T"))
            ksat_geo=10.0**float(p["ksat"])
            alpha_geo=10.0**float(p["alpha"])
            n_geo=10.0**float(p["npar"])
            k0_geo=10.0**float(p["k0"])
            rec={
                "siteid":r.get("siteid"),"hzname":r.get("hzname"),
                "hzndept":r.get("hzndept"),"hzndepb":r.get("hzndepb"),
                "midpointcm":r.get("midpointcm"),
                "sandtotal":r.get("sandtotal"),"silttotal":r.get("silttotal"),"claytotal":r.get("claytotal"),
                "authors_ksat_T":r.get("ksat_T"),"authors_ksat_T_std":r.get("ksat_T_std"),
                "rosetta_code":p.get("code"),
                "theta_r":p.get("thr"),"theta_s":p.get("ths"),
                "alpha_per_cm":alpha_geo,"n":n_geo,
                "ksat_cm_day":ksat_geo,"k0_cm_day":k0_geo,"l":p.get("lpar"),
                "theta_r_std":p.get("thr_std"),"theta_s_std":p.get("ths_std"),
                "alpha_std":p.get("alpha_std"),"n_std":p.get("npar_std"),
                "ksat_std":p.get("ksat_std"),"k0_std":p.get("k0_std"),"l_std":p.get("lpar_std"),
                "relative_ksat_error":relerr(ksat_geo,target) if target is not None else None,
            }
            w.writerow(rec)

    summary={
        "schema":"swap5.f_macro_alt44.rosetta_reproduction.v1",
        "status":"PASS" if reproducible else "FAIL",
        "rosetta_version":3,
        "input_model":"SSC only (model code 2)",
        "estimate_variants":variants,
        "chosen_estimate_type_for_ksat_reproduction":chosen,
        "parameter_emission_basis":"Rosetta v3 log ensemble means; alpha/n/Ksat/K0 emitted as geometric means; *_std retained in log10 space",
        "authors_csv":str(src),
        "output_rows":len(res),
        "reproduction_gate":{
            "metric":"median relative error against authors ksat_T",
            "threshold":1e-6,
            "passed":reproducible,
        },
        "decision":(
            "Full VG-Mualem parameters may be used as an authors-workflow-consistent hydraulic sensitivity layer."
            if reproducible else
            "Do not use generated VG parameters; authors ksat_T was not reproduced by this Rosetta configuration."
        )
    }
    Path(out_json).write_text(json.dumps(summary,indent=2,sort_keys=True),encoding="utf-8")
    print(json.dumps(summary,indent=2,sort_keys=True))
    if not reproducible:
        raise SystemExit(2)


if __name__=="__main__":
    if len(sys.argv)!=4:
        raise SystemExit("usage: macropore_alt44_rosetta_reproduction.py AUTHORS.csv OUT.csv OUT.json")
    main(*sys.argv[1:])
