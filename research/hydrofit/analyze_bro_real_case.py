#!/usr/bin/env python3
from __future__ import annotations
import csv,json,math,sys
import numpy as np
from scipy.optimize import least_squares
sys.path.insert(0,"research/hydrofit")
from hydrofit import FitConfig,MvGParameters,Observation,residual_vector,parameter_vector

rows=list(csv.DictReader(open(sys.argv[1]))); meta=json.load(open(sys.argv[2]))
keys=[]
for r in rows:
 k=(r["begin_depth_m"],r["end_depth_m"])
 if k not in keys: keys.append(k)

def make_obs(rs):
 out=[]
 for x in rs:
  h=float(x["soil_water_potential"]); th=float(x["volumetric_water_content"]); kval=float(x["hydraulic_conductivity_cm_d"])
  out.append(Observation("theta",h,th,sigma=0.01))
  if math.isfinite(kval) and kval>0: out.append(Observation("K",h,kval,sigma=0.1))
 return out

def res6(x,obs):
 cfg=FitConfig(semantics="textbook_mvg",fixed_l=float(x[5]),fixed_h_entry=0.0,weighting_mode="family_mean")
 return residual_vector(x[:5],obs,cfg)

def fit6(obs,starts):
 fits=[least_squares(lambda x:res6(x,obs),x0,bounds=([0,0.05,1e-8,1.000001,1e-12,-10],[0.8,0.9,10,20,1e8,10]),method="trf",jac="3-point",x_scale="jac") for x0 in starts]
 return min(fits,key=lambda z:float(z.fun@z.fun))

for ik,key in enumerate(keys):
 rs=[r for r in rows if (r["begin_depth_m"],r["end_depth_m"])==key]; obs=make_obs(rs); m=meta["models"][ik]
 shape=m["shape_retention"]; stored_l=[-2.44937,-1.64299,-1.32236][ik]
 stored=np.array([float(m["theta_r"]),float(m["theta_s"]),shape[0],shape[1],float(m["modelled_ksat_cm_d"]),stored_l])
 starts=[stored,[max(.001,stored[0]),min(.89,stored[1]*1.05),stored[2]*1.5,stored[3]*1.1,stored[4]*1.5,stored_l*.8],[.05,max(.4,stored[1]),.02,1.4,max(1,stored[4]),.5]]
 b=fit6(obs,starts); x=b.x; rbest=b.fun
 rstored=res6(stored,obs)
 # family_mean residual vector concatenates theta then K families, each scaled by sqrt family size.
 nt=sum(o.family=="theta" for o in obs); nk=sum(o.family=="K" for o in obs)
 def parts(rv):
  return float(rv[:nt]@rv[:nt]),float(rv[nt:]@rv[nt:])
 st,sk=parts(rstored); bt,bk=parts(rbest)
 print(f"BRO_INTERVAL|I={ik}|DEPTH={key[0]}:{key[1]}|NTH={nt}|NK={nk}|JSTORED={st+sk:.9g}|J6={bt+bk:.9g}|TH_STORED={st:.9g}|TH_6={bt:.9g}|K_STORED={sk:.9g}|K_6={bk:.9g}")
 print("BRO_INTERVAL_STORED|I=%d|X="%ik+",".join(f"{v:.9g}" for v in stored))
 print("BRO_INTERVAL_FIT6|I=%d|X="%ik+",".join(f"{v:.9g}" for v in x))
 # largest raw standardized residual locations for each family
 cfgx=FitConfig(semantics="textbook_mvg",fixed_l=float(x[5]),fixed_h_entry=0.0,weighting_mode="sum")
 raw=residual_vector(x[:5],obs,cfgx)
 pairs=list(zip(obs,raw))
 for fam in ("theta","K"):
  q=sorted(((abs(v),o.head_cm,v) for o,v in pairs if o.family==fam),reverse=True)[:3]
  print(f"BRO_RESIDUAL_TOP|I={ik}|FAMILY={fam}|VALUES="+json.dumps(q))
 # deterministic profile: fix one parameter, reoptimize other five.
 for pi,name,grid in [
  (0,"theta_r",np.linspace(max(0,x[0]-.15),min(.5,x[0]+.15),9)),
  (4,"Ks",np.geomspace(max(1e-4,x[4]/4),x[4]*4,9)),
  (5,"l",np.linspace(max(-10,x[5]-3),min(10,x[5]+3),9))]:
  vals=[]
  for fixed in grid:
   free=[j for j in range(6) if j!=pi]; y0=x[free]
   lo=np.array([0,.05,1e-8,1.000001,1e-12,-10.])[free]; hi=np.array([.8,.9,10,20,1e8,10.])[free]
   def rr(y):
    z=x.copy(); z[pi]=fixed; z[free]=y; return res6(z,obs)
   z=least_squares(rr,y0,bounds=(lo,hi),method="trf",x_scale="jac")
   vals.append((float(fixed),float(z.fun@z.fun)))
  print(f"BRO_PROFILE|I={ik}|PARAM={name}|VALUES="+json.dumps(vals))
