#!/usr/bin/env python3
from __future__ import annotations
import argparse,json,sys,xml.etree.ElementTree as ET
import numpy as np
from scipy.optimize import least_squares
sys.path.insert(0,"research/hydrofit")
from hydrofit import FitConfig,Observation,residual_vector
from bro_bhrp_fetch import fetch,DEFAULT_BASE
def local(t): return t.rsplit('}',1)[-1]
def decode(y):
 tr=y[0]; f=1/(1+np.exp(-y[1])); ts=tr+(0.9-tr)*f
 return np.array([tr,ts,y[2],y[3],y[4]])
def encode(x):
 tr,ts=x[0],x[1]; f=np.clip((ts-tr)/(0.9-tr),1e-9,1-1e-9)
 return np.array([tr,np.log(f/(1-f)),x[2],x[3],x[4]])
def parse(b):
 root=ET.fromstring(b); bid=next(((e.text or '').strip() for e in root.iter() if local(e.tag)=="broId"),None); out=[]
 for iv in (e for e in root.iter() if local(e.tag)=="InvestigatedInterval"):
  begin=next(((e.text or '').strip() for e in iv.iter() if local(e.tag)=="beginDepth"),None); end=next(((e.text or '').strip() for e in iv.iter() if local(e.tag)=="endDepth"),None)
  vals={}
  for e in iv.iter():
   if local(e.tag) in ("residualVolumetricWaterContent","volumetricWaterContentAtSaturation","modelledSaturatedHydraulicConductivity"): vals[local(e.tag)]=(e.text or '').strip()
  hyd=shape=None
  for da in (e for e in iv.iter() if local(e.tag)=="DataArray"):
   et=next((e.attrib.get("name") for e in da.iter() if local(e.tag)=="elementType"),None); v=next(((e.text or '').strip() for e in da.iter() if local(e.tag)=="values"),"")
   if et=="WaterContentAndConductivityAtSpecificSoilWaterPotential": hyd=v
   elif et=="ShapeHydraulicConductivityCurve": shape=v
  if hyd and shape and len(vals)==3:
   sh=[float(x) for x in shape.split(",")]; obs=[]
   for q in hyd.split():
    h,t,k=map(float,q.split(",")); obs.append(Observation("theta",h,t,sigma=.01))
    if k>0: obs.append(Observation("K",h,k,sigma=.1))
   src=np.array([float(vals["residualVolumetricWaterContent"]),float(vals["volumetricWaterContentAtSaturation"]),sh[0],sh[1],float(vals["modelledSaturatedHydraulicConductivity"]),sh[3]])
   out.append((bid,begin,end,src,obs))
 return out
def main():
 ap=argparse.ArgumentParser(); ap.add_argument("--corpus",required=True); a=ap.parse_args()
 corp=json.load(open(a.corpus)); ints=sorted(corp["intervals"],key=lambda r:(r["bro_id"],float(r["begin_depth"] or 0),float(r["end_depth"] or 0)))
 idx=sorted(set(np.linspace(0,len(ints)-1,min(12,len(ints))).round().astype(int).tolist())); chosen=[ints[i] for i in idx]
 by={}; full={}
 for r in chosen: by.setdefault(r["bro_id"],1)
 for bid in by:
  st,ct,b=fetch(DEFAULT_BASE+"/objects/"+bid)
  if st//100!=2: raise SystemExit(f"fetch {bid}: {st}")
  for z in parse(b): full[(z[0],z[1],z[2])]=z
 grid=np.array([-25,-20,-15,-10,-7.5,-5,-3,-2,-1,0,.5,1,2,5,10.])
 lo=np.array([0,-25,1e-8,1.000001,1e-12]); hi=np.array([.8,25,10,20,1e8])
 counts={}
 for r in chosen:
  bid,begin,end,src,obs=full[(r["bro_id"],str(r["begin_depth"]),str(r["end_depth"]))]; y0=encode(src[:5]); fits=[]
  for lam in grid:
   def rr(y): return residual_vector(decode(y),obs,FitConfig(semantics="textbook_mvg",fixed_l=float(lam),fixed_h_entry=0,weighting_mode="family_mean"))
   z=least_squares(rr,y0,bounds=(lo,hi),method="trf",jac="3-point",x_scale="jac"); y0=z.x
   fits.append((float(z.fun@z.fun),z))
  k=min(range(len(fits)),key=lambda i:fits[i][0]); j,z=fits[k]; p=decode(z.x)
  blocks=[]
  for pi,name in ((2,"ALPHA"),(3,"N"),(4,"KS")):
   d=min((z.x[pi]-lo[pi])/(hi[pi]-lo[pi]),(hi[pi]-z.x[pi])/(hi[pi]-lo[pi]))
   if d<=.001: blocks.append(name)
  cls=(blocks[0]+"_BOUND") if len(blocks)==1 else "MULTIPLE_BOUNDS"
  counts[cls]=counts.get(cls,0)+1
  sv=np.linalg.svd(z.jac,compute_uv=False); cond=float("inf") if sv[-1]==0 else float(sv[0]/sv[-1])
  src_near=[]
  for pi,name,lbi,hii in ((2,"ALPHA",1e-8,10),(3,"N",1.000001,20),(4,"KS",1e-12,1e8)):
   d=min((src[pi]-lbi)/(hii-lbi),(hii-src[pi])/(hii-lbi))
   if d<=.001: src_near.append(name)
  print(f"BRO_BOUND|BRO={bid}|DEPTH={begin}:{end}|CLASS={cls}|BLOCKS={','.join(blocks)}|LAMBDA={grid[k]:.9g}|J={j:.9g}|FIT="+",".join(f"{x:.9g}" for x in p)+f"|SOURCE="+",".join(f"{x:.9g}" for x in src[:5])+f"|ALPHA_RATIO={p[2]/src[2]:.9g}|N_DELTA={p[3]-src[3]:.9g}|KS_RATIO={p[4]/src[4]:.9g}|SOURCE_NEAR={','.join(src_near) or 'NONE'}|COND={cond:.9g}|SINGULAR="+",".join(f"{x:.6g}" for x in sv))
 print("BRO_BOUND_SUMMARY="+json.dumps(counts,sort_keys=True))
if __name__=="__main__": main()
