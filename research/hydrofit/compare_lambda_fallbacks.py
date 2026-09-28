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
 tr=y[0]; f=1/(1+np.exp(-y[1])); return np.array([tr,tr+(0.9-tr)*f,y[2],y[3],y[4]])
def encode(x):
 tr,ts=x[0],x[1]; f=np.clip((ts-tr)/(0.9-tr),1e-9,1-1e-9); return np.array([tr,np.log(f/(1-f)),x[2],x[3],x[4]])
def parse(b):
 root=ET.fromstring(b); bid=next(((e.text or '').strip() for e in root.iter() if local(e.tag)=="broId"),None); out=[]
 for iv in (e for e in root.iter() if local(e.tag)=="InvestigatedInterval"):
  begin=next(((e.text or '').strip() for e in iv.iter() if local(e.tag)=="beginDepth"),None); end=next(((e.text or '').strip() for e in iv.iter() if local(e.tag)=="endDepth"),None)
  d={}
  for e in iv.iter():
   if local(e.tag) in ("residualVolumetricWaterContent","volumetricWaterContentAtSaturation","modelledSaturatedHydraulicConductivity"): d[local(e.tag)]=(e.text or '').strip()
  hyd=shape=None
  for da in (e for e in iv.iter() if local(e.tag)=="DataArray"):
   et=next((e.attrib.get("name") for e in da.iter() if local(e.tag)=="elementType"),None); v=next(((e.text or '').strip() for e in da.iter() if local(e.tag)=="values"),"")
   if et=="WaterContentAndConductivityAtSpecificSoilWaterPotential": hyd=v
   elif et=="ShapeHydraulicConductivityCurve": shape=v
  if hyd and shape and len(d)==3:
   sh=[float(q) for q in shape.split(",")]; obs=[]
   for q in hyd.split():
    h,t,k=map(float,q.split(",")); obs.append(Observation("theta",h,t,sigma=.01))
    if k>0: obs.append(Observation("K",h,k,sigma=.1))
   src=np.array([float(d["residualVolumetricWaterContent"]),float(d["volumetricWaterContentAtSaturation"]),sh[0],sh[1],float(d["modelledSaturatedHydraulicConductivity"])])
   out.append((bid,begin,end,src,sh[3],obs))
 return out
def solve(obs,src,lam):
 lo=np.array([0,-25,1e-8,1.000001,1e-12]); hi=np.array([.8,25,10,20,1e8]); y0=encode(src)
 def rr(y): return residual_vector(decode(y),obs,FitConfig(semantics="textbook_mvg",fixed_l=float(lam),fixed_h_entry=0,weighting_mode="family_mean"))
 z=least_squares(rr,y0,bounds=(lo,hi),method="trf",jac="3-point",x_scale="jac"); p=decode(z.x); sv=np.linalg.svd(z.jac,compute_uv=False); cond=float("inf") if sv[-1]==0 else float(sv[0]/sv[-1])
 blocks=[]
 for pi,name,lbi,hii in ((2,"ALPHA",1e-8,10),(4,"KS",1e-12,1e8)):
  lv=np.log(p[pi]); a=np.log(lbi); b=np.log(hii); dist=min((lv-a)/(b-a),(b-lv)/(b-a))
  if dist<=.001: blocks.append(name)
 dist=min((p[3]-1.000001)/(20-1.000001),(20-p[3])/(20-1.000001))
 if dist<=.001: blocks.append("N")
 return float(z.fun@z.fun),p,blocks,cond
def main():
 ap=argparse.ArgumentParser(); ap.add_argument("--corpus",required=True); a=ap.parse_args(); corp=json.load(open(a.corpus))
 ints=sorted(corp["intervals"],key=lambda r:(r["bro_id"],float(r["begin_depth"] or 0),float(r["end_depth"] or 0))); n=min(12,len(ints)); idx=sorted(set(np.linspace(0,len(ints)-1,n).round().astype(int))); chosen=[ints[i] for i in idx]
 lambdas=np.array([r["lambda"] for r in ints],float); med=float(np.median(lambdas)); bybro={}
 for r in chosen: bybro[r["bro_id"]]=1
 full={}
 for bid in bybro:
  st,ct,b=fetch(DEFAULT_BASE+"/objects/"+bid)
  for z in parse(b): full[(z[0],z[1],z[2])]=z
 grid=[-25,-20,-15,-10,-7.5,-5,-3,-2,-1,0,.5,1,2,5,10.]
 summaries={k:[] for k in ("FIXED_0P5","CORPUS_MEDIAN","LOO_MEDIAN","SOURCE_L")}
 for r in chosen:
  z=full[(r["bro_id"],str(r["begin_depth"]),str(r["end_depth"]))]; bid,begin,end,src,sl,obs=z
  others=[q["lambda"] for q in ints if q["bro_id"]!=bid]; loo=float(np.median(others))
  best=min(solve(obs,src,g)[0] for g in grid)
  for name,lam in (("FIXED_0P5",.5),("CORPUS_MEDIAN",med),("LOO_MEDIAN",loo),("SOURCE_L",sl)):
   j,p,blocks,cond=solve(obs,src,lam); ratio=j/best; summaries[name].append(ratio)
   print(f"BRO_FALLBACK|BRO={bid}|DEPTH={begin}:{end}|POLICY={name}|L={lam:.9g}|J={j:.9g}|JBEST={best:.9g}|RATIO={ratio:.9g}|BLOCKS={','.join(blocks) or 'NONE'}|COND={cond:.9g}|P="+",".join(f"{x:.9g}" for x in p))
 print(f"BRO_FALLBACK_CONSTANTS|CORPUS_MEDIAN={med:.9g}")
 for name,v in summaries.items():
  x=np.array(v); print(f"BRO_FALLBACK_SUMMARY|POLICY={name}|MEDIAN_RATIO={np.median(x):.9g}|MEAN_RATIO={x.mean():.9g}|MAX_RATIO={x.max():.9g}")
if __name__=="__main__": main()
