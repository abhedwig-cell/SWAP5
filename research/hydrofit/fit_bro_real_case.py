#!/usr/bin/env python3
from __future__ import annotations
import csv, json, math, sys
import numpy as np
sys.path.insert(0,"research/hydrofit")
from hydrofit import FitConfig,MvGParameters,Observation,fit,multistart_fit,evaluate,residual_vector,parameter_vector

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

# Apples-to-apples diagnostic using the conductivity exponent stored by BRO.
stored_shape=m0["shape_retention"]
stored_alpha,stored_n,stored_m,_=stored_shape
stored_l=-2.44937
stored=MvGParameters(float(m0["theta_r"]),float(m0["theta_s"]),stored_alpha,stored_n,float(m0["modelled_ksat_cm_d"]),stored_l,0.0)
cfg_stored_l=FitConfig(semantics="textbook_mvg",fixed_l=stored_l,fixed_h_entry=0.0,weighting_mode="family_mean")
rs=residual_vector(parameter_vector(stored),obs,cfg_stored_l)
jstored=float(np.dot(rs,rs))
starts_l=[
 MvGParameters(0.001,0.67,stored_alpha,stored_n,13.69,stored_l),
 MvGParameters(0.05,0.62,0.02,1.2,20.0,stored_l),
 MvGParameters(0.0,0.72,0.06,1.5,10.0,stored_l),
]
best_l,_=multistart_fit(obs,starts_l,cfg_stored_l)
q=best_l.parameters
print(f"BRO_STORED_OBJECTIVE_UNDER_HYDROFIT|J={jstored:.9g}|L={stored_l:.9g}")
print(f"BRO_REAL_REFIT_STORED_L|J={best_l.objective:.9g}|THR={q.theta_r:.9g}|THS={q.theta_s:.9g}|ALPHA={q.alpha:.9g}|N={q.n:.9g}|M={q.m:.9g}|KS={q.Ks:.9g}|L={q.l:.9g}")

from scipy.optimize import least_squares
def residual6(x):
 cfg6=FitConfig(semantics="textbook_mvg",fixed_l=float(x[5]),fixed_h_entry=0.0,weighting_mode="family_mean")
 return residual_vector(x[:5],obs,cfg6)
starts6=[
 [0.0,0.66683,0.03515,1.15043,13.69,-2.44937],
 [0.10,0.70,0.05,1.25,20.0,-1.0],
 [0.01,0.65,0.02,1.10,30.0,0.5],
]
fits6=[]
for x0 in starts6:
 rr=least_squares(residual6,x0,bounds=([0,0.05,1e-8,1.000001,1e-12,-10],[0.8,0.9,10,20,1e8,10]),method="trf",jac="3-point",x_scale="jac")
 fits6.append(rr)
best6=min(fits6,key=lambda z:float(np.dot(z.fun,z.fun)))
x=best6.x; j6=float(np.dot(best6.fun,best6.fun))
s6=np.linalg.svd(best6.jac,compute_uv=False); cond6=float("inf") if s6[-1]==0 else float(s6[0]/s6[-1])
print(f"BRO_REAL_FIT6|J={j6:.9g}|THR={x[0]:.9g}|THS={x[1]:.9g}|ALPHA={x[2]:.9g}|N={x[3]:.9g}|M={1-1/x[3]:.9g}|KS={x[4]:.9g}|L={x[5]:.9g}|COND={cond6:.9g}|NFEV={best6.nfev}")
for i,z in enumerate(fits6):
 print(f"BRO_REAL_FIT6_START|I={i}|J={float(np.dot(z.fun,z.fun)):.9g}|X="+",".join(f"{v:.9g}" for v in z.x))
