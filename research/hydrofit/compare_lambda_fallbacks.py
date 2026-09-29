#!/usr/bin/env python3
from __future__ import annotations
import argparse,json,sys
import numpy as np
from scipy.optimize import least_squares
sys.path.insert(0,"research/hydrofit")
from hydrofit import FitConfig,residual_vector
from hydro_record_binding import bind_corpus_rows

def decode(y):
 tr=y[0]; f=1/(1+np.exp(-y[1])); return np.array([tr,tr+(0.9-tr)*f,y[2],y[3],y[4]])

def encode(x):
 tr,ts=x[0],x[1]; f=np.clip((ts-tr)/(0.9-tr),1e-9,1-1e-9); return np.array([tr,np.log(f/(1-f)),x[2],x[3],x[4]])

def solve(obs,src,lam):
 lo=np.array([0,-25,1e-8,1.000001,1e-12]); hi=np.array([.8,25,10,20,1e8]); y0=encode(src)
 def rr(y): return residual_vector(decode(y),obs,FitConfig(semantics="textbook_mvg",fixed_l=float(lam),fixed_h_entry=0,weighting_mode="family_mean"))
 z=least_squares(rr,y0,bounds=(lo,hi),method="trf",jac="3-point",x_scale="jac"); p=decode(z.x); sv=np.linalg.svd(z.jac,compute_uv=False); cond=float("inf") if sv[-1]==0 else float(sv[0]/sv[-1])
 blocks=[]
 for pi,name,lbi,hii in ((2,"ALPHA",1e-8,10),(4,"KS",1e-12,1e8)):
  lv=np.log(p[pi]); aa=np.log(lbi); bb=np.log(hii); dist=min((lv-aa)/(bb-aa),(bb-lv)/(bb-aa))
  if dist<=.001: blocks.append(name)
 dist=min((p[3]-1.000001)/(20-1.000001),(20-p[3])/(20-1.000001))
 if dist<=.001: blocks.append("N")
 return float(z.fun@z.fun),p,blocks,cond

def main():
 ap=argparse.ArgumentParser(); ap.add_argument("--corpus",required=True); a=ap.parse_args(); corp=json.load(open(a.corpus))
 ints=sorted(corp["intervals"],key=lambda r:(r["bro_id"],float(r["begin_depth"] or 0),float(r["end_depth"] or 0)))
 n=min(12,len(ints)); idx=sorted(set(np.linspace(0,len(ints)-1,n).round().astype(int))); chosen=bind_corpus_rows([ints[i] for i in idx])
 lambdas=np.array([r["lambda"] for r in ints],float); med=float(np.median(lambdas))
 grid=[-25,-20,-15,-10,-7.5,-5,-3,-2,-1,0,.5,1,2,5,10.]
 summaries={k:[] for k in ("FIXED_0P5","CORPUS_MEDIAN","LOO_MEDIAN","SOURCE_L")}
 for r in chosen:
  others=[q["lambda"] for q in ints if q["bro_id"]!=r["bro_id"]]; loo=float(np.median(others))
  best=min(solve(r["obs"],r["src"],g)[0] for g in grid)
  for name,lam in (("FIXED_0P5",.5),("CORPUS_MEDIAN",med),("LOO_MEDIAN",loo),("SOURCE_L",r["source_l"])):
   j,p,blocks,cond=solve(r["obs"],r["src"],lam); ratio=j/best; summaries[name].append(ratio)
   print(f"BRO_FALLBACK|BRO={r['bro_id']}|DEPTH={r['begin_depth']}:{r['end_depth']}|HASH={r['hyd_sha256']}|POLICY={name}|L={lam:.9g}|J={j:.9g}|JBEST={best:.9g}|RATIO={ratio:.9g}|BLOCKS={','.join(blocks) or 'NONE'}|COND={cond:.9g}|P="+",".join(f"{x:.9g}" for x in p))
 print(f"BRO_FALLBACK_CONSTANTS|CORPUS_MEDIAN={med:.9g}")
 for name,v in summaries.items():
  x=np.array(v); print(f"BRO_FALLBACK_SUMMARY|POLICY={name}|MEDIAN_RATIO={np.median(x):.9g}|MEAN_RATIO={x.mean():.9g}|MAX_RATIO={x.max():.9g}")

if __name__=="__main__": main()
