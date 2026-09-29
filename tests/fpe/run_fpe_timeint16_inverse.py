#!/usr/bin/env python3
import json,subprocess,sys
from pathlib import Path
exe=Path(sys.argv[1]); bank=json.loads(Path(sys.argv[2]).read_text()); mats={x["id"]:x for x in bank["materials"]}
rows=[]
for mid in ("B01","O05"):
 m=mats[mid]
 cp=subprocess.run([str(exe),mid,str(m["theta_r"]),str(m["theta_s"]),str(m["alpha"]),str(m["n"]),str(m["lambda"])],text=True,capture_output=True)
 row={"material":mid,"ok":cp.returncode==0,"stdout":cp.stdout[-1000:],"stderr":cp.stderr[-500:]}
 if row["ok"]:
  line=next((x for x in cp.stdout.splitlines() if x.startswith("F_PE_TIMEINT16_INVERSE_RESULT|")),None)
  if line:
   d={k:v for k,v in (f.split("=",1) for f in line.split("|")[1:])}
   row["max_head_err"]=float(d["MAX_HEAD_ERR"])
   row["max_theta_err"]=float(d["MAX_THETA_ERR"])
 rows.append(row)
print("F_PE_TIMEINT16_INVERSE_RESULTS="+json.dumps(rows,separators=(",",":"),sort_keys=True))
print("F_PE_TIMEINT16_INVERSE="+("PASS" if all(x["ok"] for x in rows) else "FAIL"))
if not all(x["ok"] for x in rows): raise SystemExit(1)
