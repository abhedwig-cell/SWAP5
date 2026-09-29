#!/usr/bin/env python3
from __future__ import annotations
import argparse,json,sys
import numpy as np
from scipy.optimize import least_squares
sys.path.insert(0,"research/hydrofit")
from hydrofit import FitConfig,residual_vector
from hydro_record_binding import bind_corpus_rows

def decode(y):
 tr=y[0]; frac=1/(1+np.exp(-y[1])); ts=tr+(0.9-tr)*frac
 return np.array([tr,ts,y[2],y[3],y[4]])

def encode(x):
 tr,ts=x[0],x[1]; f=np.clip((ts-tr)/(0.9-tr),1e-9,1-1e-9)
 return np.array([tr,np.log(f/(1-f)),x[2],x[3],x[4]])

def main():
 ap=argparse.ArgumentParser(); ap.add_argument("--corpus",required=True); a=ap.parse_args()
 corp=json.load(open(a.corpus))
 intervals=sorted(corp["intervals"],key=lambda r:(r["bro_id"],float(r["begin_depth"] or 0),float(r["end_depth"] or 0)))
 n=min(12,len(intervals)); idx=sorted(set(np.linspace(0,len(intervals)-1,n).round().astype(int).tolist()))
 chosen=bind_corpus_rows([intervals[i] for i in idx])
 grid=np.array([-25,-20,-15,-10,-7.5,-5,-3,-2,-1,0,.5,1,2,5,10.])
 counts={}
 for r in chosen:
  obs=r["obs"]; y0=encode(r["src"]); vals=[]; params=[]
  for lam in grid:
   def rr(y): return residual_vector(decode(y),obs,FitConfig(semantics="textbook_mvg",fixed_l=float(lam),fixed_h_entry=0,weighting_mode="family_mean"))
   fit=least_squares(rr,y0,bounds=([0,-25,1e-8,1.000001,1e-12],[.8,25,10,20,1e8]),method="trf",x_scale="jac")
   y0=fit.x; vals.append(float(fit.fun@fit.fun)); params.append(decode(fit.x))
  k=int(np.argmin(vals)); p=params[k]; lo=np.array([0,.05,1e-8,1.000001,1e-12]); hi=np.array([.8,.9,10,20,1e8])
  boundary=any(min((p[j]-lo[j])/(hi[j]-lo[j]),(hi[j]-p[j])/(hi[j]-lo[j]))<=.001 for j in (2,3,4))
  if k in (0,len(grid)-1): cls="EDGE_MINIMUM"
  elif boundary: cls="OTHER_PARAMETER_BOUNDARY"
  else:
   left=min(vals[:k]); right=min(vals[k+1:]); cls="INTERIOR_QUALIFIED" if left>=1.01*vals[k] and right>=1.01*vals[k] else "FLAT_OR_WEAK"
  counts[cls]=counts.get(cls,0)+1
  nearest=int(np.argmin(abs(grid-r["source_l"])))
  print(f"BRO_LPROFILE|BRO={r['bro_id']}|DEPTH={r['begin_depth']}:{r['end_depth']}|HASH={r['hyd_sha256']}|SOURCE_L={r['source_l']:.9g}|CLASS={cls}|MIN_L={grid[k]:.9g}|JMIN={vals[k]:.9g}|JSOURCEGRID={vals[nearest]:.9g}|PROFILE="+json.dumps(list(zip(grid.tolist(),vals))))
 print("BRO_LPROFILE_SUMMARY="+json.dumps(counts,sort_keys=True))

if __name__=="__main__": main()
