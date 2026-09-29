#!/usr/bin/env python3
import csv, json, math, subprocess, sys
from pathlib import Path

prod=Path(sys.argv[1]); legacy=Path(sys.argv[2]); src=Path(sys.argv[3])
materials={r["name"]:r for r in csv.DictReader(src.open())}
seed=["B01","B12","O05","O14"]
regimes={"WET":(-20.0,12.0,0.12),"POND":(-5.0,25.0,0.12)}
dtmin=0.001; dtmax=0.02; dt0=math.sqrt(dtmin*dtmax)

def args(r,reg,label):
    h0,rain,horizon=regimes[reg]
    return [f'{r["name"]}/{reg}',label,r["wcr"],r["wcs"],r["alpha"],r["npar"],r["ksfit"],r["lambda"],
            str(h0),str(rain),str(horizon),str(dtmin),str(dtmax),str(dt0),
            "4","8","8","2.0","0.5","2.0","1e-9","1e-6"]

def parse(cp,prefix):
    if cp.returncode:
        return {"ok":False,"failure":"dtmin" if "nonconvergence at dtmin" in cp.stdout else "other",
                "stdout":cp.stdout[-1000:],"stderr":cp.stderr[-1000:]}
    line=next((x for x in cp.stdout.splitlines() if x.startswith(prefix)),None)
    if line is None:
        return {"ok":False,"failure":"missing-result","stdout":cp.stdout[-1000:],"stderr":cp.stderr[-1000:]}
    d={}
    for field in line.split("|")[1:]:
        if "=" in field:
            k,v=field.split("=",1); d[k]=v
    ints=["ATTEMPTS","ACCEPTED","REJECTED","GROWTHS","REDUCTIONS","NL","BACK","JAC","LIN"]
    floats=["CUM_RUNOFF","TOP_H","MID_H","BOTTOM_H","POND","STORAGE","MAX_LEDGER"]
    return {"ok":True,**{k:int(d[k]) for k in ints},**{k:float(d[k]) for k in floats}}

out=[]
for name in seed:
    r=materials[name]
    for reg in regimes:
        a=subprocess.run([str(prod),*args(r,reg,"PROD")],text=True,capture_output=True)
        b=subprocess.run([str(legacy),*args(r,reg,"LEGACY")],text=True,capture_output=True)
        x=parse(a,"F_PE_ELASTIC05_RESULT|")
        y=parse(b,"F_PE_ELASTIC05_LEGACY_RESULT|")
        if x["ok"] != y["ok"]:
            raise SystemExit(f"F_PE_ELASTIC05_FAIL status mismatch {name}/{reg}: {x} vs {y}")
        if not x["ok"]:
            if x["failure"] != y["failure"]:
                raise SystemExit(f"F_PE_ELASTIC05_FAIL failure-class mismatch {name}/{reg}: {x} vs {y}")
            out.append({"case":f"{name}/{reg}","ok":False,"failure":x["failure"]})
            continue
        for k in ["ATTEMPTS","ACCEPTED","REJECTED","GROWTHS","REDUCTIONS","NL","BACK","JAC","LIN"]:
            if x[k] != y[k]:
                raise SystemExit(f"F_PE_ELASTIC05_FAIL counter mismatch {name}/{reg}/{k}: {x[k]} vs {y[k]}")
        for k in ["CUM_RUNOFF","TOP_H","MID_H","BOTTOM_H","POND","STORAGE","MAX_LEDGER"]:
            if abs(x[k]-y[k]) > 1e-12:
                raise SystemExit(f"F_PE_ELASTIC05_FAIL physical mismatch {name}/{reg}/{k}: {x[k]} vs {y[k]}")
        out.append({"case":f"{name}/{reg}","ok":True,"accepted":x["ACCEPTED"],"nl":x["NL"],"back":x["BACK"]})

print("F_PE_ELASTIC05_DYNAMIC_RESULTS="+json.dumps(out,separators=(",",":"),sort_keys=True))
print("F_PE_ELASTIC05_DYNAMIC_IDENTITY=PASS")
