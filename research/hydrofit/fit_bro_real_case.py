#!/usr/bin/env python3
from __future__ import annotations
import csv, json, math, sys
import numpy as np
sys.path.insert(0,"research/hydrofit")
from hydrofit import FitConfig,MvGParameters,Observation,fit,multistart_fit,evaluate

# Uses the qualified F-HYDROFIT01 fitting kernel incorporated on this branch.
csv_path,meta_path=sys.argv[1:3]
rows=list(csv.DictReader(open(csv_path)))
meta=json.load(open(meta_path))
# first exported interval only
key=(rows[0]["begin_depth_m"],rows[0]["end_depth_m"])
r=[x for x in rows if (x["begin_depth_m"],x["end_depth_m"])==key]
obs=[]
for x in r:
 h=float(x["soil_water_potential"]); th=float(x["volumetric_water_content"]); k=float(x["hydraulic_conductivity_cm_d"])
 obs.append(Observation("theta",h,th,sigma=0.01))
 if math.isfinite(k) and k>0: obs.append(Observation("K",h,k,sigma=0.1))
cfg=FitConfig(semantics="textbook_mvg",fixed_l=0.5,fixed_h_entry=0.0,weighting_mode="family_mean")
starts=[
 MvGParameters(0.01,0.70,0.03,1.3,18.4),
 MvGParameters(0.05,0.68,0.01,1.8,15.0),
 MvGParameters(0.15,0.72,0.05,1.15,25.0),
]
best,allr=multistart_fit(obs,starts,cfg)
p=best.parameters
print(f"BRO_REAL_FIT|DEPTH={key[0]}:{key[1]}|SUCCESS={int(best.success)}|J={best.objective:.9g}|COND={best.condition_number:.9g}|NFEV={best.nfev}")
print(f"BRO_REAL_PARAMS|THR={p.theta_r:.9g}|THS={p.theta_s:.9g}|ALPHA={p.alpha:.9g}|N={p.n:.9g}|M={p.m:.9g}|KS={p.Ks:.9g}|L={p.l:.9g}")
for i,z in enumerate(allr):
 q=z.parameters
 print(f"BRO_REAL_START|I={i}|J={z.objective:.9g}|THR={q.theta_r:.9g}|THS={q.theta_s:.9g}|ALPHA={q.alpha:.9g}|N={q.n:.9g}|KS={q.Ks:.9g}")
# BRO model metadata, first interval. ShapeRetention is alpha,n,m? plus scale/constraint; compare direct stored values.
m0=meta["models"][0]
print("BRO_STORED_MODEL="+json.dumps(m0,sort_keys=True))
