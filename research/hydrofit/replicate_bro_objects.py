#!/usr/bin/env python3
from __future__ import annotations
import csv,json,math,sys
import numpy as np
from scipy.optimize import least_squares
sys.path.insert(0,"research/hydrofit")
from hydrofit import FitConfig,MvGParameters,Observation,residual_vector

def fit_object(csv_path,meta_path):
 rows=list(csv.DictReader(open(csv_path))); meta=json.load(open(meta_path))
 keys=[]
 for r in rows:
  k=(r["begin_depth_m"],r["end_depth_m"])
  if k not in keys: keys.append(k)
 out=[]
 for ik,key in enumerate(keys):
  rr=[r for r in rows if (r["begin_depth_m"],r["end_depth_m"])==key]
  obs=[]
  for z in rr:
   h=float(z["soil_water_potential"]); th=float(z["volumetric_water_content"]); k=float(z["hydraulic_conductivity_cm_d"])
   obs.append(Observation("theta",h,th,sigma=.01))
   if math.isfinite(k) and k>0: obs.append(Observation("K",h,k,sigma=.1))
  m=meta["models"][ik]
  # stored l is supplied separately in extended metadata when available
  l=float(m.get("l",-2.0))
  shape=m["shape_retention"]
  stored=np.array([float(m["theta_r"]),float(m["theta_s"]),shape[0],shape[1],float(m["modelled_ksat_cm_d"]),l])
  def rv(x):
   cfg=FitConfig(semantics="textbook_mvg",fixed_l=float(x[5]),fixed_h_entry=0,weighting_mode="family_mean")
   return residual_vector(x[:5],obs,cfg)
  starts=[stored,[max(.001,stored[0]),min(.89,stored[1]*1.05),stored[2]*1.5,stored[3]*1.1,stored[4]*1.5,stored[5]],[.05,max(.4,stored[1]),.02,1.4,max(1,stored[4]),.5]]
  fits=[least_squares(rv,x0,bounds=([0,.05,1e-8,1.000001,1e-12,-10],[.8,.9,10,20,1e8,10]),method="trf",jac="3-point",x_scale="jac") for x0 in starts]
  b=min(fits,key=lambda z:float(z.fun@z.fun))
  js=float(rv(stored)@rv(stored)); jb=float(b.fun@b.fun)
  x=b.x
  out.append((key,len(obs),js,jb,x))
 return out

for pair in sys.argv[1:]:
 csvp,metap=pair.split("::",1)
 bro=json.load(open(metap))["bro_id"]
 for i,(key,n,js,jb,x) in enumerate(fit_object(csvp,metap)):
  print(f"BRO_REPLICATION|BRO={bro}|I={i}|DEPTH={key[0]}:{key[1]}|NOBS={n}|JSTORED={js:.9g}|J6={jb:.9g}|RATIO={jb/js:.9g}|THR={x[0]:.9g}|THS={x[1]:.9g}|ALPHA={x[2]:.9g}|N={x[3]:.9g}|KS={x[4]:.9g}|L={x[5]:.9g}")
