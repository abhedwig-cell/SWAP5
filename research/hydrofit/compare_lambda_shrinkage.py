#!/usr/bin/env python3
"""P-LSHRINK01: preregistered soft lambda shrinkage on frozen 12 cases."""
from __future__ import annotations
import argparse,json,math,sys
import numpy as np
from scipy.optimize import least_squares
sys.path.insert(0,"research/hydrofit")
from hydrofit import FitConfig,residual_vector
from compare_conditional_lambda_priors import parse_object,predict,encode,decode,solve
from bro_bhrp_fetch import fetch,DEFAULT_BASE
def cond(j):
 s=np.linalg.svd(j,compute_uv=False);return float("inf") if len(s)==0 or s[-1]==0 else float(s[0]/s[-1])
def cclass(c):
 if not np.isfinite(c) or c>=1e8:return "SEVERE"
 if c>=1e6:return "POOR"
 if c>=1e4:return "MODERATE"
 return "WELL_CONDITIONED"
def blocks(p):
 z=[]
 for i,nm,lo,hi in ((2,"ALPHA",1e-8,10),(4,"KS",1e-12,1e8)):
  d=min((np.log(p[i])-np.log(lo))/(np.log(hi)-np.log(lo)),(np.log(hi)-np.log(p[i]))/(np.log(hi)-np.log(lo)))
  if d<=.001:z.append(nm)
 if min((p[3]-1.000001)/(20-1.000001),(20-p[3])/(20-1.000001))<=.001:z.append("N")
 return z
def shrink(obs,src,target,sigma):
 lo=np.r_[np.array([0,-25,1e-8,1.000001,1e-12]),-25.];hi=np.r_[np.array([.8,25,10,20,1e8]),10.]
 x0=np.r_[encode(src),np.clip(target,-25,10)]
 def hyd(x):return residual_vector(decode(x[:5]),obs,FitConfig(semantics="textbook_mvg",fixed_l=float(x[5]),fixed_h_entry=0,weighting_mode="family_mean"))
 def allr(x):return np.r_[hyd(x),(x[5]-target)/sigma]
 z=least_squares(allr,x0,bounds=(lo,hi),method="trf",jac="3-point",x_scale="jac")
 p=decode(z.x[:5]);rh=hyd(z.x);jh=float(rh@rh)
 # hydraulic-only numerical Jacobian of residuals w.r.t all 6 fitted variables
 eps=np.sqrt(np.finfo(float).eps); cols=[]
 for k in range(6):
  h=eps*max(1,abs(z.x[k]));xp=z.x.copy();xm=z.x.copy();xp[k]=min(hi[k],z.x[k]+h);xm[k]=max(lo[k],z.x[k]-h)
  den=xp[k]-xm[k];cols.append((hyd(xp)-hyd(xm))/den)
 jhmat=np.column_stack(cols)
 return jh,float(z.x[5]),blocks(p),cond(jhmat),cond(z.jac)
def main():
 ap=argparse.ArgumentParser();ap.add_argument("--corpus",required=True);a=ap.parse_args();corp=json.load(open(a.corpus));rows=[];cache={}
 for r in corp["intervals"]:
  bid=r["bro_id"]
  if bid not in cache:
   st,ct,b=fetch(DEFAULT_BASE+"/objects/"+bid);cache[bid]=parse_object(b)
  z=cache[bid][(str(r["begin_depth"]),str(r["end_depth"]))];bd=float(r["begin_depth"]);ed=float(r["end_depth"])
  rows.append({**r,**z,"mid":.5*(bd+ed),"ln_n":math.log10(max(z["n_obs"],1)),"ln_h":math.log10(max(z["h_span"],1))})
 targets={"LOO":{},"KNN5K":{}}
 for i,t in enumerate(rows):
  tr=[r for r in rows if r["bro_id"]!=t["bro_id"]]
  targets["LOO"][i]=predict(tr,t,"LOO_MEDIAN");targets["KNN5K"][i]=predict(tr,t,"KNN5K")
 idx=sorted(set(np.linspace(0,len(rows)-1,min(12,len(rows))).round().astype(int)));grid=[-25,-20,-15,-10,-7.5,-5,-3,-2,-1,0,.5,1,2,5,10.]
 best={i:min(solve(rows[i]["obs"],rows[i]["src"],g)[0] for g in grid) for i in idx}
 for tp in ("LOO","KNN5K"):
  for sig in (.5,1.5,4.0):
   ratios=[];sev_h=sev_p=blocked=0
   for i in idx:
    r=rows[i];j,l,b,ch,cp=shrink(r["obs"],r["src"],targets[tp][i],sig);ratio=j/best[i];ratios.append(ratio);sev_h+=cclass(ch)=="SEVERE";sev_p+=cclass(cp)=="SEVERE";blocked+=bool(b)
    print(f"BRO_SHRINK|TARGET={tp}|SIGMA={sig:g}|BRO={r['bro_id']}|DEPTH={r['begin_depth']}:{r['end_depth']}|LTARGET={targets[tp][i]:.9g}|LFIT={l:.9g}|DELTA={l-targets[tp][i]:.9g}|RATIO={ratio:.9g}|BLOCKS={','.join(b) or 'NONE'}|COND_H={ch:.9g}|CLASS_H={cclass(ch)}|COND_P={cp:.9g}|CLASS_P={cclass(cp)}")
   x=np.array(ratios);print(f"BRO_SHRINK_SUMMARY|TARGET={tp}|SIGMA={sig:g}|MEDIAN_RATIO={np.median(x):.9g}|MEAN_RATIO={x.mean():.9g}|MAX_RATIO={x.max():.9g}|BOUND_BLOCKED={blocked}|SEVERE_H={sev_h}|SEVERE_P={sev_p}")
if __name__=="__main__":main()
