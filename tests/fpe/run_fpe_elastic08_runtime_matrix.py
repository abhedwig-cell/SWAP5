#!/usr/bin/env python3
import csv, json, subprocess, sys
from pathlib import Path

exe=Path(sys.argv[1])
src=Path(sys.argv[2])
rows={r["name"]:r for r in csv.DictReader(src.open())}
materials=["B01","B12","O05","O14"]
regimes=[("WET",-20.0),("POND",2.0)]

results=[]
for name in materials:
    r=rows[name]
    args=[r["wcr"],r["wcs"],r["alpha"],r["npar"],r["ksfit"],r["lambda"]]
    for regime,h0 in regimes:
        case=f"{name}/{regime}"
        cp=subprocess.run([str(exe),case,*args,str(h0)],text=True,capture_output=True)
        if cp.returncode:
            print("F_PE_ELASTIC08_R3_FAIL="+case)
            print(cp.stdout); print(cp.stderr)
            raise SystemExit(1)
        if "F_PE_ELASTIC08_R3_RUNTIME_IDENTITY=PASS" not in cp.stdout:
            print("F_PE_ELASTIC08_R3_MISSING_PASS="+case)
            print(cp.stdout); print(cp.stderr)
            raise SystemExit(1)
        line=next((x for x in cp.stdout.splitlines() if x.startswith("F_PE_ELASTIC08_R3_RESULT|")),None)
        if line is None:
            raise SystemExit("F_PE_ELASTIC08_R3_MISSING_RESULT="+case)
        d={}
        for field in line.split("|")[1:]:
            k,v=field.split("=",1)
            d[k]=v
        if d.get("CASE")!=case:
            raise SystemExit("F_PE_ELASTIC08_R3_CASE_MISMATCH="+case)
        results.append({
            "case":case,
            "nl":int(d["NL"]),
            "back":int(d["BACK"]),
            "linear":int(d["LINEAR"]),
            "retries":int(d["RETRIES"]),
        })

print("F_PE_ELASTIC08_R3_RESULTS="+json.dumps(results,separators=(",",":"),sort_keys=True))
print("F_PE_ELASTIC08_R3_CASES=8")
print("F_PE_ELASTIC08_R3_SEED_MATRIX=PASS")
