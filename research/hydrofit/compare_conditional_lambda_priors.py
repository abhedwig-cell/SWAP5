#!/usr/bin/env python3
"""Preregistered low-capacity leave-one-object-out lambda priors."""
from __future__ import annotations
import argparse,json,math,re,sys
import numpy as np
from scipy.optimize import least_squares
sys.path.insert(0,"research/hydrofit")
from hydrofit import FitConfig,residual_vector
from hydro_record_binding import bind_corpus_rows

def decode(y):
 tr=y[0]; q=1/(1+np.exp(-y[1])); return np.array([tr,tr+(0.9-tr)*q,y[2],y[3],y[4]])

def encode(x):
 tr,ts=x[:2]; q=np.clip((ts-tr)/(0.9-tr),1e-9,1-1e-9); return np.array([tr,np.log(q/(1-q)),x[2],x[3],x[4]])

def solve(obs,src,lam):
 lo=np.array([0,-25,1e-8,1.000001,1e-12]);hi=np.array([.8,25,10,20,1e8])
 def rr(y):return residual_vector(decode(y),obs,FitConfig(semantics="textbook_mvg",fixed_l=float(lam),fixed_h_entry=0,weighting_mode="family_mean"))
 z=least_squares(rr,encode(src),bounds=(lo,hi),method="trf",jac="3-point",x_scale="jac");p=decode(z.x);sv=np.linalg.svd(z.jac,compute_uv=False);cond=float("inf") if sv[-1]==0 else float(sv[0]/sv[-1])
 blocks=[]
 for i,nm,lo0,hi0 in ((2,"ALPHA",1e-8,10),(4,"KS",1e-12,1e8)):
  d=min((np.log(p[i])-np.log(lo0))/(np.log(hi0)-np.log(lo0)),(np.log(hi0)-np.log(p[i]))/(np.log(hi0)-np.log(lo0)))
  if d<=.001:blocks.append(nm)
 if min((p[3]-1.000001)/(20-1.000001),(20-p[3])/(20-1.000001))<=.001:blocks.append("N")
 return float(z.fun@z.fun),blocks,cond

def hgroup(s):
 m=re.search("[A-Za-z]",s or "");return m.group(0).upper() if m else "?"

def predict(train,target,policy):
 vals=np.array([r["lambda"] for r in train],float)
 if policy=="LOO_MEDIAN":return float(np.median(vals))
 if policy=="HORIZON":
  g=hgroup(target["horizon"]); z=[r["lambda"] for r in train if hgroup(r["horizon"])==g]
  return float(np.median(z)) if len(z)>=3 else float(np.median(vals))
 dims=["mid","ln_n","ln_h","theta_span"]+(["logk_span"] if policy=="KNN5K" else [])
 X=np.array([[r[d] for d in dims] for r in train],float); y=vals; q=np.array([target[d] for d in dims],float)
 mu=X.mean(0);sd=X.std(0);sd[sd==0]=1;dist=np.linalg.norm((X-mu)/sd-(q-mu)/sd,axis=1);ix=np.argsort(dist)[:5]
 return float(np.median(y[ix]))

def main():
 ap=argparse.ArgumentParser();ap.add_argument("--corpus",required=True);a=ap.parse_args();corp=json.load(open(a.corpus))
 rows=bind_corpus_rows(corp["intervals"])
 for r in rows:
  bd=float(r["begin_depth"]);ed=float(r["end_depth"])
  r["mid"]=.5*(bd+ed);r["ln_n"]=math.log10(max(r["n_obs"],1));r["ln_h"]=math.log10(max(r["h_span"],1))
 policies=["LOO_MEDIAN","HORIZON","KNN5","KNN5K"];pred={p:{} for p in policies}
 for i,t in enumerate(rows):
  train=[r for r in rows if r["bro_id"]!=t["bro_id"]]
  for p in policies:pred[p][i]=predict(train,t,p)
 for p in policies:
  err=np.array([pred[p][i]-r["lambda"] for i,r in enumerate(rows)])
  print(f"BRO_PRIOR_PREDICT|POLICY={p}|MEDAE={np.median(abs(err)):.9g}|MEDBIAS={np.median(err):.9g}|MAXAE={max(abs(err)):.9g}")
 idx=sorted(set(np.linspace(0,len(rows)-1,min(12,len(rows))).round().astype(int)));grid=[-25,-20,-15,-10,-7.5,-5,-3,-2,-1,0,.5,1,2,5,10.]
 for p in policies:
  ratios=[];blocked=0
  for i in idx:
   r=rows[i];best=min(solve(r["obs"],r["src"],g)[0] for g in grid);j,b,c=solve(r["obs"],r["src"],pred[p][i]);ratios.append(j/best);blocked+=bool(b)
   print(f"BRO_PRIOR_FIT|POLICY={p}|BRO={r['bro_id']}|DEPTH={r['begin_depth']}:{r['end_depth']}|HASH={r['hyd_sha256']}|L={pred[p][i]:.9g}|RATIO={j/best:.9g}|BLOCKS={','.join(b) or 'NONE'}|COND={c:.9g}")
  x=np.array(ratios);print(f"BRO_PRIOR_FIT_SUMMARY|POLICY={p}|MEDIAN_RATIO={np.median(x):.9g}|MEAN_RATIO={x.mean():.9g}|MAX_RATIO={x.max():.9g}|BLOCKED={blocked}")

if __name__=="__main__":main()
