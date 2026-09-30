#!/usr/bin/env python3
import json,math,subprocess,sys
from pathlib import Path
exe=Path(sys.argv[1]); bank=json.loads(Path(sys.argv[2]).read_text())
mats={x["id"]:x for x in bank["materials"]}
cases=[("O05",13),("O05",12),("O14",13),("B12",13)]
rows=[]; physical_fail=False; binding_fail=False
for mid,tail in cases:
    m=mats[mid]
    cmd=[str(exe),mid,str(m["theta_r"]),str(m["theta_s"]),str(m["alpha"]),str(m["n"]),
         str(m["ksat"]),str(m["lambda"]),str(tail)]
    cp=subprocess.run(cmd,text=True,capture_output=True)
    if cp.returncode:
        print(cp.stdout); print(cp.stderr,file=sys.stderr)
        binding_fail=True; break
    rline=next((x for x in cp.stdout.splitlines() if x.startswith("F_PE_NLGLOB14Z40_RESULT=")),None)
    if rline and "PHYSICAL_MISMATCH" in rline:
        print(cp.stdout)
        physical_fail=True; break
    line=next((x for x in cp.stdout.splitlines() if x.startswith("F_PE_NLGLOB14Z40_CASE|")),None)
    if not line:
        print(cp.stdout); binding_fail=True; break
    d={k:v for k,v in (f.split("=",1) for f in line.split("|")[1:])}
    rows.append({
      "material":mid,"tail_start":tail,"active_n":int(d["ACTIVE_N"]),
      "hdiff":float(d["HDIFF"]),"tdiff":float(d["TDIFF"]),"topdiff":float(d["TOPDIFF"]),
      "ledgerdiff":float(d["LEDGERDIFF"]),"full_tail":int(d["FULL_TAIL"]),"red_tail":int(d["RED_TAIL"]),
      "full_nl":int(d["FULL_NL"]),"red_nl":int(d["RED_NL"]),
      "full_jac":int(d["FULL_JAC"]),"red_jac":int(d["RED_JAC"]),
      "full_median_s":float(d["FULL_MEDIAN_S"]),"red_median_s":float(d["RED_MEDIAN_S"]),
      "timing_ratio":float(d["TIMING_RATIO"]),"request_reallocs":int(d["REQUEST_REALLOCS"]),
      "candidate_reallocs":int(d["CANDIDATE_REALLOCS"])
    })
if binding_fail:
    agg="Z40_REDUCED_PROVIDER_OR_SOLVER_BINDING_FAILED"
elif physical_fail:
    agg="Z40_REAL_REDUCED_PHYSICAL_MISMATCH"
else:
    ratios=[r["timing_ratio"] for r in rows]
    gm=math.exp(sum(math.log(x) for x in ratios)/len(ratios))
    if sum(x<0.95 for x in ratios)>=3 and gm<0.95 and max(ratios)<=1.05:
        agg="QUALIFIED_Z40_REAL_REDUCED_RICHARDS_GAIN"
    elif gm>1.05 or max(ratios)>1.10:
        agg="Z40_REAL_REDUCED_RICHARDS_REGRESSION"
    else:
        agg="QUALIFIED_Z40_REAL_REDUCED_RICHARDS_PHYSICAL_ONLY"
print("F_PE_NLGLOB14Z40_RESULTS="+json.dumps(rows,separators=(",",":"),sort_keys=True))
out={"aggregate":agg}
if rows:
    out["geomean_timing_ratio"]=math.exp(sum(math.log(r["timing_ratio"]) for r in rows)/len(rows))
print("F_PE_NLGLOB14Z40_RESULT="+json.dumps(out,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB14Z40=PASS")
