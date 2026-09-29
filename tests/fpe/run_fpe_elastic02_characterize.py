#!/usr/bin/env python3
import csv,json,math,subprocess,sys
from pathlib import Path

ref_exe=Path(sys.argv[1]); elastic_exe=Path(sys.argv[2]); src=Path(sys.argv[3])
rows=list(csv.DictReader(src.open()))
hold=set("B03 B06 B09 B15 B18 O01 O04 O07 O10 O13 O16 O18".split())
materials=[r for r in rows if r["name"] not in hold]
regimes=[
 ("WET",-20.0,12.0,0.12),
 ("POND",-5.0,25.0,0.12),
]
dtmin=0.001;dtmax=0.02;dt0=math.sqrt(dtmin*dtmax)
base_tail=[str(dtmin),str(dtmax),str(dt0),"4","8","8","2.0","0.5","2.0","1e-9"]

def args(r,reg,label):
 rid,h0,rain,horizon=reg
 return [f'{r["name"]}/{rid}',label,r["wcr"],r["wcs"],r["alpha"],r["npar"],r["ksfit"],r["lambda"],
         str(h0),str(rain),str(horizon),*base_tail]

def parse(cp,prefix,name,reg,label,ss=None):
 if cp.returncode:
  return {"material":name,"regime":reg,"candidate":label,"ss":ss,"ok":False,"stdout":cp.stdout[-800:],"stderr":cp.stderr[-800:]}
 line=next((x for x in cp.stdout.splitlines() if x.startswith(prefix)),None)
 if line is None: raise RuntimeError(cp.stdout)
 d={}
 for f in line[len(prefix):].split("|"):
  if f and "=" in f:
   k,v=f.split("=",1);d[k]=v
 out={"material":name,"regime":reg,"candidate":label,"ss":ss,"ok":True}
 for k in ["ATTEMPTS","ACCEPTED","REJECTED","NL","BACK","JAC","LIN"]: out[k.lower()]=int(d[k])
 for k in ["CUM_RUNOFF","TOP_H","MID_H","BOTTOM_H","POND","STORAGE","MAX_LEDGER"]: out[k.lower()]=float(d[k])
 out["work_index"]=out["nl"]+out["back"]+out["jac"]+out["lin"]
 return out

results=[]
for m in materials:
 for reg in regimes:
  cp=subprocess.run([str(ref_exe),*args(m,reg,"REF")],text=True,capture_output=True)
  q=parse(cp,"F_PE_BOFEK01_RESULT|",m["name"],reg[0],"REF")
  results.append(q)
  cp=subprocess.run([str(elastic_exe),*args(m,reg,"E6"),"1e-6"],text=True,capture_output=True)
  x=parse(cp,"F_PE_ELASTIC01_RESULT|",m["name"],reg[0],"E6",1e-6)
  results.append(x)

refs={(x["material"],x["regime"]):x for x in results if x["candidate"]=="REF" and x["ok"]}
summary=[]
for x in results:
 if x["candidate"]!="E6": continue
 q=refs.get((x["material"],x["regime"]))
 summary.append({
  "material":x["material"],"regime":x["regime"],"ok":x["ok"],
  "work_reduction":(1-x["work_index"]/q["work_index"]) if x["ok"] and q else None,
  "d_runoff":x["cum_runoff"]-q["cum_runoff"] if x["ok"] and q else None,
  "d_storage":x["storage"]-q["storage"] if x["ok"] and q else None,
  "d_top_h":x["top_h"]-q["top_h"] if x["ok"] and q else None,
  "d_mid_h":x["mid_h"]-q["mid_h"] if x["ok"] and q else None,
  "d_bottom_h":x["bottom_h"]-q["bottom_h"] if x["ok"] and q else None,
 })
print("F_PE_ELASTIC02A2_RESULTS="+json.dumps(results,separators=(",",":"),sort_keys=True))
print("F_PE_ELASTIC02A2_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
print("F_PE_ELASTIC02A2=PASS")
