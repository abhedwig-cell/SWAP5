#!/usr/bin/env python3
from __future__ import annotations
import argparse,csv,json,math,sys,xml.etree.ElementTree as ET
from pathlib import Path
import numpy as np
from scipy.optimize import least_squares
sys.path.insert(0,"research/hydrofit")
from hydrofit import FitConfig,Observation,residual_vector
from bro_bhrp_fetch import fetch,DEFAULT_BASE
def local(t): return t.rsplit('}',1)[-1]
def decode(y):
 tr=y[0]; frac=1/(1+np.exp(-y[1])); ts=tr+(0.9-tr)*frac
 return np.array([tr,ts,y[2],y[3],y[4]])
def encode(x):
 tr,ts=x[0],x[1]; f=np.clip((ts-tr)/(0.9-tr),1e-9,1-1e-9)
 return np.array([tr,np.log(f/(1-f)),x[2],x[3],x[4]])
def parse_object(b):
 root=ET.fromstring(b); bid=next(((e.text or '').strip() for e in root.iter() if local(e.tag)=="broId"),None); out=[]
 for iv in (e for e in root.iter() if local(e.tag)=="InvestigatedInterval"):
  begin=next(((e.text or '').strip() for e in iv.iter() if local(e.tag)=="beginDepth"),None); end=next(((e.text or '').strip() for e in iv.iter() if local(e.tag)=="endDepth"),None)
  hyd=shape=None; tr=ts=ks=None
  for e in iv.iter():
   if local(e.tag)=="residualVolumetricWaterContent": tr=(e.text or '').strip()
   elif local(e.tag)=="volumetricWaterContentAtSaturation": ts=(e.text or '').strip()
   elif local(e.tag)=="modelledSaturatedHydraulicConductivity": ks=(e.text or '').strip()
  for da in (e for e in iv.iter() if local(e.tag)=="DataArray"):
   et=next((e.attrib.get("name") for e in da.iter() if local(e.tag)=="elementType"),None); vals=next(((e.text or '').strip() for e in da.iter() if local(e.tag)=="values"),"")
   if et=="WaterContentAndConductivityAtSpecificSoilWaterPotential": hyd=vals
   elif et=="ShapeHydraulicConductivityCurve": shape=vals
  if hyd and shape and tr is not None and ts is not None and ks is not None:
   shp=[float(z) for z in shape.split(",")]; obs=[]
   for block in hyd.split():
    h,theta,k=map(float,block.split(","))
    obs.append(Observation("theta",h,theta,sigma=.01))
    if k>0: obs.append(Observation("K",h,k,sigma=.1))
   out.append({"bro":bid,"begin":begin,"end":end,"source":np.array([float(tr),float(ts),shp[0],shp[1],float(ks)]),"source_l":shp[3],"obs":obs})
 return out
def main():
 ap=argparse.ArgumentParser(); ap.add_argument("--corpus",required=True); a=ap.parse_args()
 corp=json.load(open(a.corpus)); intervals=sorted(corp["intervals"],key=lambda r:(r["bro_id"],float(r["begin_depth"] or 0),float(r["end_depth"] or 0)))
 n=min(12,len(intervals)); idx=sorted(set(np.linspace(0,len(intervals)-1,n).round().astype(int).tolist()))
 chosen=[intervals[i] for i in idx]
 bybro={}
 for r in chosen: bybro.setdefault(r["bro_id"],[]).append(r)
 full={}
 for bid in bybro:
  st,ct,b=fetch(DEFAULT_BASE+"/objects/"+bid)
  if st//100!=2: raise SystemExit(f"fetch {bid} {st}")
  for z in parse_object(b): full[(z["bro"],z["begin"],z["end"])]=z
 grid=np.array([-25,-20,-15,-10,-7.5,-5,-3,-2,-1,0,.5,1,2,5,10.])
 counts={}
 for r in chosen:
  z=full[(r["bro_id"],str(r["begin_depth"]),str(r["end_depth"]))]; obs=z["obs"]; y0=encode(z["source"]); vals=[]; params=[]
  for lam in grid:
   def rr(y): return residual_vector(decode(y),obs,FitConfig(semantics="textbook_mvg",fixed_l=float(lam),fixed_h_entry=0,weighting_mode="family_mean"))
   fit=least_squares(rr,y0,bounds=([0,-25,1e-8,1.000001,1e-12],[.8,25,10,20,1e8]),method="trf",x_scale="jac")
   y0=fit.x; vals.append(float(fit.fun@fit.fun)); params.append(decode(fit.x))
  k=int(np.argmin(vals)); p=params[k]; lo=np.array([0,.05,1e-8,1.000001,1e-12]); hi=np.array([.8,.9,10,20,1e8])
  # theta_s bound is not used for qualification; alpha,n,Ks only.
  boundary=any(min((p[j]-lo[j])/(hi[j]-lo[j]),(hi[j]-p[j])/(hi[j]-lo[j]))<=.001 for j in (2,3,4))
  if k in (0,len(grid)-1): cls="EDGE_MINIMUM"
  elif boundary: cls="OTHER_PARAMETER_BOUNDARY"
  else:
   left=min(vals[:k]); right=min(vals[k+1:]); cls="INTERIOR_QUALIFIED" if left>=1.01*vals[k] and right>=1.01*vals[k] else "FLAT_OR_WEAK"
  counts[cls]=counts.get(cls,0)+1
  nearest=int(np.argmin(abs(grid-z["source_l"])))
  print(f"BRO_LPROFILE|BRO={z['bro']}|DEPTH={z['begin']}:{z['end']}|SOURCE_L={z['source_l']:.9g}|CLASS={cls}|MIN_L={grid[k]:.9g}|JMIN={vals[k]:.9g}|JSOURCEGRID={vals[nearest]:.9g}|PROFILE="+json.dumps(list(zip(grid.tolist(),vals))))
 print("BRO_LPROFILE_SUMMARY="+json.dumps(counts,sort_keys=True))
if __name__=="__main__": main()
