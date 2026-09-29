#!/usr/bin/env python3
from __future__ import annotations
import argparse,json,sys
import numpy as np
from scipy.optimize import least_squares
sys.path.insert(0,"research/hydrofit")
from hydrofit import FitConfig,residual_vector
from hydro_record_binding import bind_corpus_rows
def decode(y):
 tr=y[0]; f=1/(1+np.exp(-y[1])); ts=tr+(0.9-tr)*f
 return np.array([tr,ts,y[2],y[3],y[4]])
def encode(x):
 tr,ts=x[0],x[1]; f=np.clip((ts-tr)/(0.9-tr),1e-9,1-1e-9)
 return np.array([tr,np.log(f/(1-f)),x[2],x[3],x[4]])
def main():
 ap=argparse.ArgumentParser(); ap.add_argument("--corpus",required=True); a=ap.parse_args()
 corp=json.load(open(a.corpus)); ints=sorted(corp["intervals"],key=lambda r:(r["bro_id"],float(r["begin_depth"] or 0),float(r["end_depth"] or 0)))
 idx=sorted(set(np.linspace(0,len(ints)-1,min(12,len(ints))).round().astype(int).tolist())); chosen=bind_corpus_rows([ints[i] for i in idx])
 grid=np.array([-25,-20,-15,-10,-7.5,-5,-3,-2,-1,0,.5,1,2,5,10.])
 lo=np.array([0,-25,1e-8,1.000001,1e-12]); hi=np.array([.8,25,10,20,1e8])
 counts={}
 for r in chosen:
  bid=r["bro_id"]; begin=r["begin_depth"]; end=r["end_depth"]; src=np.r_[r["src"],r["source_l"]]; obs=r["obs"]; y0=encode(src[:5]); fits=[]
  for lam in grid:
   def rr(y): return residual_vector(decode(y),obs,FitConfig(semantics="textbook_mvg",fixed_l=float(lam),fixed_h_entry=0,weighting_mode="family_mean"))
   z=least_squares(rr,y0,bounds=(lo,hi),method="trf",jac="3-point",x_scale="jac"); y0=z.x
   fits.append((float(z.fun@z.fun),z))
  k=min(range(len(fits)),key=lambda i:fits[i][0]); j,z=fits[k]; p=decode(z.x)
  blocks=[]
  # alpha and Ks are positive scale parameters: assess proximity in log domain.
  for pi,name in ((2,"ALPHA"),(4,"KS")):
   lv=np.log(z.x[pi]); llo=np.log(lo[pi]); lhi=np.log(hi[pi])
   d=min((lv-llo)/(lhi-llo),(lhi-lv)/(lhi-llo))
   if d<=.001: blocks.append(name)
  pi=3; d=min((z.x[pi]-lo[pi])/(hi[pi]-lo[pi]),(hi[pi]-z.x[pi])/(hi[pi]-lo[pi]))
  if d<=.001: blocks.append("N")
  cls="QUALIFIED_SCALE_AWARE" if not blocks else ((blocks[0]+"_BOUND") if len(blocks)==1 else "MULTIPLE_BOUNDS")
  counts[cls]=counts.get(cls,0)+1
  sv=np.linalg.svd(z.jac,compute_uv=False); cond=float("inf") if sv[-1]==0 else float(sv[0]/sv[-1])
  src_near=[]
  for pi,name,lbi,hii in ((2,"ALPHA",1e-8,10),(4,"KS",1e-12,1e8)):
   lv=np.log(src[pi]); llo=np.log(lbi); lhi=np.log(hii); d=min((lv-llo)/(lhi-llo),(lhi-lv)/(lhi-llo))
   if d<=.001: src_near.append(name)
  d=min((src[3]-1.000001)/(20-1.000001),(20-src[3])/(20-1.000001))
  if d<=.001: src_near.append("N")
  print(f"BRO_BOUND|BRO={bid}|DEPTH={begin}:{end}|HASH={r['hyd_sha256']}|CLASS={cls}|BLOCKS={','.join(blocks)}|LAMBDA={grid[k]:.9g}|J={j:.9g}|FIT="+",".join(f"{x:.9g}" for x in p)+f"|SOURCE="+",".join(f"{x:.9g}" for x in src[:5])+f"|ALPHA_RATIO={p[2]/src[2]:.9g}|N_DELTA={p[3]-src[3]:.9g}|KS_RATIO={p[4]/src[4]:.9g}|SOURCE_NEAR={','.join(src_near) or 'NONE'}|COND={cond:.9g}|SINGULAR="+",".join(f"{x:.6g}" for x in sv))
 print("BRO_BOUND_SUMMARY="+json.dumps(counts,sort_keys=True))
if __name__=="__main__": main()
