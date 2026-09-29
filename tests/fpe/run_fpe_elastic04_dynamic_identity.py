#!/usr/bin/env python3
import csv,json,math,subprocess,sys
from pathlib import Path

legacy=Path(sys.argv[1]);typed=Path(sys.argv[2]);src=Path(sys.argv[3])
allrows={r["name"]:r for r in csv.DictReader(src.open())}
materials=["B01","B12","O05","O14"]
regimes={"WET":(-20.0,12.0,0.12),"POND":(-5.0,25.0,0.12)}
dtmin=0.001;dtmax=0.02;dt0=math.sqrt(dtmin*dtmax)

def args(r,reg,label):
 h0,rain,horizon=regimes[reg]
 return [f'{r["name"]}/{reg}',label,r["wcr"],r["wcs"],r["alpha"],r["npar"],r["ksfit"],r["lambda"],
 str(h0),str(rain),str(horizon),str(dtmin),str(dtmax),str(dt0),"4","8","8","2.0","0.5","2.0","1e-9","1e-6"]

def parse(cp,prefix):
 if cp.returncode:return {"ok":False,"fail":"dtmin" if "nonconvergence at dtmin" in cp.stdout else "other"}
 line=next((x for x in cp.stdout.splitlines() if x.startswith(prefix)),None)
 if line is None:return {"ok":False,"fail":"missing-result"}
 d={}
 for f in line.split("|")[1:]:
  if "=" in f:
   k,v=f.split("=",1);d[k]=v
 ints=["ATTEMPTS","ACCEPTED","REJECTED","GROWTHS","REDUCTIONS","NL","BACK","JAC","LIN"]
 floats=["CUM_RUNOFF","TOP_H","MID_H","BOTTOM_H","POND","STORAGE","MAX_LEDGER"]
 return {"ok":True,**{k:int(d[k]) for k in ints},**{k:float(d[k]) for k in floats}}

rows=[]
for m in materials:
 r=allrows[m]
 for reg in regimes:
  a=subprocess.run([str(legacy),*args(r,reg,"LEGACY")],text=True,capture_output=True)
  b=subprocess.run([str(typed),*args(r,reg,"TYPED")],text=True,capture_output=True)
  x=parse(a,"F_PE_ELASTIC01_RESULT|");y=parse(b,"F_PE_ELASTIC04_RESULT|")
  if x["ok"]!=y["ok"] or (not x["ok"] and x.get("fail")!=y.get("fail")):
   raise SystemExit(f"status mismatch {m}/{reg}: {x} vs {y}")
  if x["ok"]:
   for k in ["ATTEMPTS","ACCEPTED","REJECTED","GROWTHS","REDUCTIONS","NL","BACK","JAC","LIN"]:
    if x[k]!=y[k]: raise SystemExit(f"counter mismatch {m}/{reg}/{k}: {x[k]} vs {y[k]}")
   for k in ["CUM_RUNOFF","TOP_H","MID_H","BOTTOM_H","POND","STORAGE","MAX_LEDGER"]:
    if abs(x[k]-y[k])>1e-12: raise SystemExit(f"physical mismatch {m}/{reg}/{k}: {x[k]} vs {y[k]}")
  rows.append({"case":f"{m}/{reg}","ok":x["ok"],"failure":x.get("fail")})
print("F_PE_ELASTIC04_DYNAMIC_RESULTS="+json.dumps(rows,separators=(",",":"),sort_keys=True))
print("F_PE_ELASTIC04_DYNAMIC_SEED=PASS")
