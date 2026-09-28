#!/usr/bin/env python3
from __future__ import annotations
import csv,json,math,sys
import numpy as np
from scipy.optimize import least_squares
sys.path.insert(0,"research/hydrofit")
from hydrofit import FitConfig,Observation,residual_vector

def observations(rows,key):
 obs=[]
 for z in rows:
  if (z["begin_depth_m"],z["end_depth_m"])!=key: continue
  h=float(z["soil_water_potential"]); th=float(z["volumetric_water_content"]); k=float(z["hydraulic_conductivity_cm_d"])
  obs.append(Observation("theta",h,th,sigma=.01))
  if math.isfinite(k) and k>0: obs.append(Observation("K",h,k,sigma=.1))
 return obs
def decode(y):
 # optimizer coordinates: theta_r, logit fraction of remaining pore space, alpha, n, Ks, l
 tr=y[0]; frac=1/(1+np.exp(-y[1])); ts=tr+(0.9-tr)*frac
 return np.array([tr,ts,y[2],y[3],y[4],y[5]])
def encode(x):
 tr,ts=x[0],x[1]; frac=np.clip((ts-tr)/(0.9-tr),1e-9,1-1e-9)
 return np.array([tr,np.log(frac/(1-frac)),x[2],x[3],x[4],x[5]])
def rv6(x,obs):
 return residual_vector(x[:5],obs,FitConfig(semantics="textbook_mvg",fixed_l=float(x[5]),fixed_h_entry=0,weighting_mode="family_mean"))
def solve(obs,stored,policy):
 if policy=="STORED_L":
  l=stored[5]; y0=encode(stored); free0=y0[:5]
  def rr(y):
   q=np.r_[y,l]; return rv6(decode(q),obs)
  z=least_squares(rr,free0,bounds=([0,-25,1e-8,1.000001,1e-12],[.8,25,10,20,1e8]),method="trf",x_scale="jac")
  q=np.r_[z.x,l]; return decode(q),float(z.fun@z.fun),False
 lb_l,ub_l=(-4.,0.) if policy=="BOUNDED_L" else (-10.,10.)
 x0=encode(stored); x0[5]=min(ub_l,max(lb_l,x0[5]))
 lo=np.array([0,-25,1e-8,1.000001,1e-12,lb_l]); hi=np.array([.8,25,10,20,1e8,ub_l])
 z=least_squares(lambda y:rv6(decode(y),obs),x0,bounds=(lo,hi),method="trf",jac="3-point",x_scale="jac")
 x=decode(z.x)
 # boundary gate on interpretable alpha,n,Ks,l plus theta_r; transformed theta gap is separately physical by construction.
 near=np.any(np.minimum((z.x-lo)/np.maximum(hi-lo,1e-30),(hi-z.x)/np.maximum(hi-lo,1e-30))<=.001)
 return x,float(z.fun@z.fun),bool(near)

for pair in sys.argv[1:]:
 cp,mp=pair.split("::"); rows=list(csv.DictReader(open(cp))); meta=json.load(open(mp)); bro=meta["bro_id"]
 keys=[]
 for r in rows:
  k=(r["begin_depth_m"],r["end_depth_m"])
  if k not in keys: keys.append(k)
 for i,key in enumerate(keys):
  obs=observations(rows,key); m=meta["models"][i]; sh=m["shape_retention"]; l=m.get("l")
  if l is None: raise SystemExit(f"missing stored l {bro} {key}")
  stored=np.array([float(m["theta_r"]),float(m["theta_s"]),sh[0],sh[1],float(m["modelled_ksat_cm_d"]),float(l)])
  jstored=float(rv6(stored,obs)@rv6(stored,obs))
  ans={}
  for pol in ("STORED_L","BOUNDED_L","BROAD_L"): ans[pol]=solve(obs,stored,pol)
  jb=ans["BROAD_L"][1]; improvement=max(jstored-jb,0)
  for pol,(x,j,bound) in ans.items():
   retained=(jstored-j)/improvement if improvement>0 else float("nan")
   print(f"BRO_LPOL|BRO={bro}|I={i}|POLICY={pol}|J={j:.9g}|JSTORED={jstored:.9g}|RATIO={j/jstored:.9g}|RETAINED={retained:.9g}|BOUNDARY={int(bound)}|X="+",".join(f"{v:.9g}" for v in x))
