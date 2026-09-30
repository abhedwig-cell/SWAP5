#!/usr/bin/env python3
import json,subprocess,sys
from pathlib import Path

exe=Path(sys.argv[1])
bank=json.loads(Path(sys.argv[2]).read_text())
mats={x["id"]:x for x in bank["materials"]}
candidates=[
 (49,0.00125),(45,0.00125),(41,0.00125),(37,0.00125),
 (49,0.000625),(45,0.000625),(41,0.000625),(37,0.000625),
]
rows=[]
selected={}
for mid in ("O14","B12"):
    m=mats[mid]
    for idx,(tail,dt) in enumerate(candidates,1):
        cmd=[str(exe),mid,str(m["theta_r"]),str(m["theta_s"]),str(m["alpha"]),str(m["n"]),
             str(m["ksat"]),str(m["lambda"]),str(tail),str(dt)]
        cp=subprocess.run(cmd,text=True,capture_output=True)
        if cp.returncode:
            print(cp.stdout); print(cp.stderr,file=sys.stderr)
            print('F_PE_NLGLOB14Z44_RESULT={"aggregate":"Z44_REFERENCE_SELECTION_EXECUTION_INVALID"}')
            print("F_PE_NLGLOB14Z44=PASS")
            raise SystemExit
        line=next((x for x in cp.stdout.splitlines() if x.startswith("F_PE_NLGLOB14Z44_CASE|")),None)
        if not line:
            print(cp.stdout)
            print('F_PE_NLGLOB14Z44_RESULT={"aggregate":"Z44_REFERENCE_SELECTION_EXECUTION_INVALID"}')
            print("F_PE_NLGLOB14Z44=PASS")
            raise SystemExit
        d={k:v for k,v in (x.split("=",1) for x in line.split("|")[1:])}
        row={
          "material":mid,"candidate":idx,"tail_start":tail,"dt":dt,
          "valid":d["VALID"]=="1","accepted":int(d["ACCEPTED"]),
          "final_tail":int(d["FINAL_TAIL"]),"max_ledger":float(d["MAX_LEDGER"]),
          "origin_leak":float(d["ORIGIN_LEAK"]),"reason":d["REASON"]
        }
        rows.append(row)
        if row["valid"] and mid not in selected:
            selected[mid]=row.copy()

if "O14" in selected and "B12" in selected:
    agg="QUALIFIED_Z44_REFERENCE_FIXTURES_SELECTED"
elif "O14" not in selected and "B12" not in selected:
    agg="Z44_REFERENCE_FIXTURES_UNAVAILABLE"
elif "O14" not in selected:
    agg="Z44_O14_REFERENCE_FIXTURE_UNAVAILABLE"
else:
    agg="Z44_B12_REFERENCE_FIXTURE_UNAVAILABLE"

out={"aggregate":agg,"selected":selected,"rows":rows}
print("F_PE_NLGLOB14Z44_RESULT="+json.dumps(out,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB14Z44=PASS")
