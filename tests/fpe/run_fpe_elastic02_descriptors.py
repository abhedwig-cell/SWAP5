#!/usr/bin/env python3
import csv,json,math,sys
from pathlib import Path

src=Path(sys.argv[1])
rows=list(csv.DictReader(src.open()))
heads=[-20.0,-5.0,-1.0,-0.1,-0.01,-0.001]
elas=1.0e-6
HCRIT=-1.0e-2

def cap(c,h):
 tr,ts,a,n=c["wcr"],c["wcs"],c["alpha"],c["npar"]
 m=1.0-1.0/n
 c25=ts-tr
 c26=tr+c25/((1.0+abs(a*HCRIT)**n)**m)
 c27=(ts-c26)/(-HCRIT)
 if h>HCRIT:
  return c27
 ah=abs(a*h)
 t1=ah**(n-1.0)
 t2=c25/((1.0+t1*ah)**(m+1.0))
 return n*m*a*t2*t1

def kval(c,h):
 tr,ts,a,n,lam,ks=c["wcr"],c["wcs"],c["alpha"],c["npar"],c["lambda"],c["ksfit"]
 m=1.0-1.0/n
 if h>=0: return ks
 se=(1.0+abs(a*h)**n)**(-m)
 if se>1.0-1.0e-6: return ks
 term=(1.0-se**(1.0/m))**m
 return ks*(se**lam)*(1.0-term)**2

out=[]
for r in rows:
 c={k:float(r[k]) for k in ["wcr","wcs","alpha","npar","lambda","ksfit"]}
 d={"name":r["name"],**c,"m":1-1/c["npar"],"inv_alpha_cm":1/c["alpha"]}
 for h in heads:
  tag=str(abs(h)).replace(".","p")
  cv=cap(c,h)
  kv=kval(c,h)
  d[f"c_m{tag}"]=cv
  d[f"elas_over_c_m{tag}"]=elas/cv
  d[f"k_over_ks_m{tag}"]=kv/c["ksfit"]
 out.append(d)
print("F_PE_ELASTIC02A1_DESCRIPTORS="+json.dumps(out,separators=(",",":"),sort_keys=True))
rank=sorted(out,key=lambda x:x["elas_over_c_m0p001"],reverse=True)
print("F_PE_ELASTIC02A1_RANK="+json.dumps([{"name":x["name"],"r":x["elas_over_c_m0p001"]} for x in rank],separators=(",",":")))
print("F_PE_ELASTIC02A1=PASS")
